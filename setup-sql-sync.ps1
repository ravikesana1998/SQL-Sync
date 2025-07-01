param(
    [string]$ResourceGroupName = "rg-23-6",
    [string]$ServerName = "studentserver9",
    [string]$HubDatabase = "studentsdb1",
    [string]$MemberDatabase = "studentdb2",
    [string]$SyncGroupName = "StudentSyncGroup",
    [int]$SyncIntervalSeconds = 300
)

Write-Host "🔐 Setting up Azure context..."

# Create Sync Group
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
        -UsePrivateLinkConnection $false
} else {
    Write-Host "✅ Sync Group $SyncGroupName already exists."
}

# Add Sync Member
$existingMember = Get-AzSqlSyncMember -ResourceGroupName $ResourceGroupName -ServerName $ServerName -DatabaseName $HubDatabase -SyncGroupName $SyncGroupName -Name "Member-$MemberDatabase" -ErrorAction SilentlyContinue

if (-not $existingMember) {
    Write-Host "➕ Adding Sync Member: $MemberDatabase"

    $username = "ram"
    $password = ConvertTo-SecureString "Shree@123" -AsPlainText -Force
    $cred = New-Object System.Management.Automation.PSCredential ($username, $password)

    New-AzSqlSyncMember `
        -ResourceGroupName $ResourceGroupName `
        -ServerName $ServerName `
        -DatabaseName $HubDatabase `
        -SyncGroupName $SyncGroupName `
        -SyncMemberName "Member-$MemberDatabase" `
        -MemberServerName "$ServerName.database.windows.net" `
        -MemberDatabaseName $MemberDatabase `
        -DatabaseType "AzureSqlDatabase" `
        -SyncDirection "ToMember" `
        -MemberDatabaseCredential $cred
} else {
    Write-Host "✅ Sync Member $MemberDatabase already exists."
}
