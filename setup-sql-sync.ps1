param(
    [string]$ResourceGroupName = "rg-23-6",
    [string]$ServerName = "studentserver9",
    [string]$HubDatabase = "studentsdb1",
    [string]$MemberDatabase = "studentdb2",
    [string]$SyncGroupName = "StudentSyncGroup",
    [int]$SyncIntervalSeconds = 300
)

Write-Host "🔐 Setting up Azure context..."

# Create Sync Group if it doesn't exist
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
        -SyncDatabaseName $HubDatabase `
        -SyncDatabaseServerName $ServerName `
        -SyncDatabaseResourceGroupName $ResourceGroupName
} else {
    Write-Host "✅ Sync Group $SyncGroupName already exists."
}

# Create Sync Member if it doesn't exist
$syncMemberName = "Member-$MemberDatabase"
$existingMember = Get-AzSqlSyncMember -ResourceGroupName $ResourceGroupName -ServerName $ServerName -DatabaseName $HubDatabase -SyncGroupName $SyncGroupName -Name $syncMemberName -ErrorAction SilentlyContinue

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
        -SyncMemberName $syncMemberName `
        -MemberServerName "$ServerName.database.windows.net" `
        -MemberDatabaseName $MemberDatabase `
        -DatabaseType "AzureSqlDatabase" `
        -SyncDirection "ToMember" `
        -MemberDatabaseCredential $cred
} else {
    Write-Host "✅ Sync Member $MemberDatabase already exists."
}

# Refresh schema
Write-Host "🔄 Refreshing sync schema..."
Start-AzSqlSyncSchemaRefresh `
    -ResourceGroupName $ResourceGroupName `
    -ServerName $ServerName `
    -DatabaseName $HubDatabase `
    -SyncGroupName $SyncGroupName `
    -SyncMemberName $syncMemberName

Start-Sleep -Seconds 10

# Register specific tables
$tablesToRegister = @(
    @{ Schema = "dbo"; Name = "Courses"; Columns = @("CourseID", "CourseName", "DeptID") },
    @{ Schema = "dbo"; Name = "Departments"; Columns = @("DeptID", "DeptName") },
    @{ Schema = "dbo"; Name = "Subjects"; Columns = @("SubjectID", "SubjectName", "CourseID") }
)

foreach ($table in $tablesToRegister) {
    try {
        New-AzSqlSyncMemberSchemaTable `
            -ResourceGroupName $ResourceGroupName `
            -ServerName $ServerName `
            -DatabaseName $HubDatabase `
            -SyncGroupName $SyncGroupName `
            -SyncMemberName $syncMemberName `
            -SchemaName $table.Schema `
            -TableName $table.Name `
            -Columns $table.Columns

        Write-Host "✅ Registered table: $($table.Name)"
    } catch {
        Write-Warning "⚠️ Failed to register table $($table.Name): $($_.Exception.Message)"
    }
}

# Trigger sync if ready
$groupStatus = Get-AzSqlSyncGroup -ResourceGroupName $ResourceGroupName -ServerName $ServerName -DatabaseName $HubDatabase -Name $SyncGroupName
if ($groupStatus.SyncState -in @("Good", "Ready")) {
    Write-Host "🚀 Triggering sync for group '$SyncGroupName' in database '$HubDatabase'..."
    Start-AzSqlSyncGroupSync `
        -ResourceGroupName $ResourceGroupName `
        -ServerName $ServerName `
        -DatabaseName $HubDatabase `
        -Name $SyncGroupName
} else {
    Write-Warning "⚠️ Sync Group is not in an active state: $($groupStatus.SyncState). Sync not triggered."
}
