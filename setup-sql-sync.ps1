# scripts/setup-sql-sync.ps1
param(
    [string]$ResourceGroupName,
    [string]$ServerName,
    [string]$HubDatabase,
    [string]$MemberDatabase,
    [string]$SyncGroupName,
    [int]$SyncIntervalSeconds = 300
)

$syncMemberName = "Member-$MemberDatabase"
$securePassword = ConvertTo-SecureString "Shree@123" -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential ("ram", $securePassword)

if (-not (Get-AzSqlSyncGroup -ResourceGroupName $ResourceGroupName -ServerName $ServerName -DatabaseName $HubDatabase -Name $SyncGroupName -ErrorAction SilentlyContinue)) {
    New-AzSqlSyncGroup -ResourceGroupName $ResourceGroupName -ServerName $ServerName -DatabaseName $HubDatabase -Name $SyncGroupName -ConflictResolutionPolicy HubWin -IntervalInSeconds $SyncIntervalSeconds
}

if (-not (Get-AzSqlSyncMember -ResourceGroupName $ResourceGroupName -ServerName $ServerName -DatabaseName $HubDatabase -SyncGroupName $SyncGroupName -Name $syncMemberName -ErrorAction SilentlyContinue)) {
    New-AzSqlSyncMember -ResourceGroupName $ResourceGroupName -ServerName $ServerName -DatabaseName $HubDatabase -SyncGroupName $SyncGroupName -SyncMemberName $syncMemberName -MemberServerName "$ServerName.database.windows.net" -MemberDatabaseName $MemberDatabase -MemberDatabaseCredential $cred -SyncDirection OneWayHubToMember
} else {
    Write-Host "✅ Sync Member already exists."
}
