param(
    [string]$ResourceGroupName,
    [string]$ServerName,
    [string]$HubDatabase,
    [string]$MemberDatabase,
    [string]$SyncGroupName,
    [int]$SyncIntervalSeconds = 300
)

Write-Host "🔐 Setting up Azure SQL Data Sync..."

# Set credentials
$memberUsername = "ram"
$memberPassword = ConvertTo-SecureString "Shree@123" -AsPlainText -Force
$memberCredential = New-Object System.Management.Automation.PSCredential ($memberUsername, $memberPassword)

# Create Sync Group if not exists
$existingGroup = Get-AzSqlSyncGroup `
    -ResourceGroupName $ResourceGroupName `
    -ServerName $ServerName `
    -DatabaseName $HubDatabase `
    -Name $SyncGroupName -ErrorAction SilentlyContinue

if (-not $existingGroup) {
    Write-Host "🆕 Creating Sync Group: $SyncGroupName"

    New-AzSqlSyncGroup `
        -ResourceGroupName $ResourceGroupName `
        -ServerName $ServerName `
        -DatabaseName $HubDatabase `
        -Name $SyncGroupName `
        -ConflictResolutionPolicy "HubWin" `
        -IntervalInSeconds $SyncIntervalSeconds `
        -SyncDatabaseName $HubDatabase `
        -SyncDatabaseServerName $ServerName `
        -SyncDatabaseResourceGroupName $ResourceGroupName
} else {
    Write-Host "✅ Sync Group '$SyncGroupName' already exists."
}

# Add Sync Member if not exists
$syncMemberName = "Member-$MemberDatabase"
$existingMember = Get-AzSqlSyncMember `
    -ResourceGroupName $ResourceGroupName `
    -ServerName $ServerName `
    -DatabaseName $HubDatabase `
    -SyncGroupName $SyncGroupName `
    -Name $syncMemberName -ErrorAction SilentlyContinue

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
    Write-Host "✅ Sync Member '$MemberDatabase' already exists."
}

Write-Host "✅ SQL Data Sync setup complete."
