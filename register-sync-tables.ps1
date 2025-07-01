param(
    [string]$ResourceGroupName = "rg-23-6",
    [string]$ServerName = "studentserver9",
    [string]$HubDatabase = "studentsdb1",
    [string]$MemberDatabase = "studentdb2",
    [string]$SyncGroupName = "StudentSyncGroup",
    [int]$SyncIntervalSeconds = 300
)

Write-Host "🔐 Setting up Azure context..."

# Set credentials for member DB
$memberDbUsername = "ram"
$memberDbPassword = ConvertTo-SecureString "Shree@123" -AsPlainText -Force
$memberCredential = New-Object System.Management.Automation.PSCredential ($memberDbUsername, $memberDbPassword)

# Create sync group if not exists
$existingGroup = Get-AzSqlSyncGroup -ResourceGroupName $ResourceGroupName -ServerName $ServerName -DatabaseName $HubDatabase -Name $SyncGroupName -ErrorAction SilentlyContinue
if (-not $existingGroup) {
    Write-Host "🆕 Creating Sync Group: $SyncGroupName"
    New-AzSqlSyncGroup `
        -ResourceGroupName $ResourceGroupName `
        -ServerName $ServerName `
        -DatabaseName $HubDatabase `
        -Name $SyncGroupName `
        -ConflictResolutionPolicy HubWin `
        -IntervalInSeconds $SyncIntervalSeconds `
        -UsePrivateLinkConnection $false `
        -SchemaTrackingEnabled $false
} else {
    Write-Host "✅ Sync Group $SyncGroupName already exists."
}

# Add sync member if not exists
$syncMemberName = "Member-$MemberDatabase"
$existingMember = Get-AzSqlSyncMember -ResourceGroupName $ResourceGroupName -ServerName $ServerName -DatabaseName $HubDatabase -SyncGroupName $SyncGroupName -Name $syncMemberName -ErrorAction SilentlyContinue

if (-not $existingMember) {
    Write-Host "➕ Adding Sync Member: $MemberDatabase"
    New-AzSqlSyncMember `
        -ResourceGroupName $ResourceGroupName `
        -ServerName $ServerName `
        -DatabaseName $HubDatabase `
        -SyncGroupName $SyncGroupName `
        -SyncMemberName $syncMemberName `
        -MemberServerName "$ServerName.database.windows.net" `
        -MemberDatabaseName $MemberDatabase `
        -MemberDatabaseType "AzureSqlDatabase" `
        -MemberDatabaseCredential $memberCredential `
        -SyncDirection "OneWayHubToMember"
} else {
    Write-Host "✅ Sync Member $MemberDatabase already exists."
}

# 🔄 Schema discovery happens automatically; wait a moment
Write-Host "🔄 Waiting briefly to allow schema refresh..."
Start-Sleep -Seconds 10

# 📋 Display discovered tables and columns
Write-Host "`n📋 Verifying registered tables in Sync Group..."
$registeredSchema = Get-AzSqlSyncSchema `
    -ResourceGroupName $ResourceGroupName `
    -ServerName $ServerName `
    -DatabaseName $HubDatabase `
    -SyncGroupName $SyncGroupName `
    -SyncMemberName $syncMemberName

foreach ($tbl in $registeredSchema.Tables) {
    Write-Host "🗂️ Table: $($tbl.QuotedName)"
    foreach ($col in $tbl.Columns) {
        Write-Host "   ➤ Column: $($col.QuotedName)"
    }
}

# 🔁 Trigger sync if sync group is in a good state
$groupStatus = Get-AzSqlSyncGroup `
    -ResourceGroupName $ResourceGroupName `
    -ServerName $ServerName `
    -DatabaseName $HubDatabase `
    -Name $SyncGroupName

if ($groupStatus.SyncState -eq "Good" -or $groupStatus.SyncState -eq "Ready") {
    Write-Host "🚀 Triggering sync for group '$SyncGroupName' in database '$HubDatabase'..."

    try {
        $result = Start-AzSqlSyncGroupSync `
            -ResourceGroupName $ResourceGroupName `
            -ServerName $ServerName `
            -DatabaseName $HubDatabase `
            -SyncGroupName $SyncGroupName

        Write-Host "✅ Sync triggered successfully."
    }
    catch {
        Write-Error "❌ Sync trigger failed: $($_.Exception.Message)"
        exit 1
    }

} else {
    Write-Warning "⚠️ Sync Group is not in an active state (current state: $($groupStatus.SyncState)). Sync not triggered."
}
