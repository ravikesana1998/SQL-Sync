param(
    [string]$ResourceGroupName = "rg-23-6",
    [string]$ServerName = "studentserver9",
    [string]$HubDatabase = "studentsdb1",
    [string]$MemberDatabase = "studentdb2",
    [string]$SyncGroupName = "StudentSyncGroup",
    [int]$SyncIntervalSeconds = 300  # 5 mins
)

# Authenticate using DevOps service connection context
Write-Host "🔐 Setting up Azure context..."

# Create Sync Group if not exists
$existingGroup = Get-AzSqlSyncGroup -ResourceGroupName $ResourceGroupName -ServerName $ServerName -DatabaseName $HubDatabase -Name $SyncGroupName -ErrorAction SilentlyContinue

if (-not $existingGroup) {
    Write-Host "🆕 Creating Sync Group: $SyncGroupName"
    New-AzSqlSyncGroup `
        -ResourceGroupName $ResourceGroupName `
        -ServerName $ServerName `
        -DatabaseName $HubDatabase `
        -Name $SyncGroupName `
        -ConflictResolutionPolicy "HubWin" `
        -IntervalInSeconds $SyncIntervalSeconds `
        -SchemaTrackingEnabled $true
} else {
    Write-Host "✅ Sync Group $SyncGroupName already exists."
}

# Add member database
$existingMember = Get-AzSqlSyncMember -ResourceGroupName $ResourceGroupName -ServerName $ServerName -DatabaseName $HubDatabase -SyncGroupName $SyncGroupName -Name "Member-$MemberDatabase" -ErrorAction SilentlyContinue

if (-not $existingMember) {
    Write-Host "➕ Adding Sync Member: $MemberDatabase"

    New-AzSqlSyncMember `
        -ResourceGroupName $ResourceGroupName `
        -ServerName $ServerName `
        -DatabaseName $HubDatabase `
        -SyncGroupName $SyncGroupName `
        -SyncMemberName "Member-$MemberDatabase" `
        -MemberDatabaseName $MemberDatabase `
        -MemberServerName $ServerName `
        -DatabaseType "AzureSqlDatabase" `
        -SyncDirection "ToMember" `
        -UsePrivateLinkConnection $false
} else {
    Write-Host "✅ Sync Member $MemberDatabase already exists."
}
