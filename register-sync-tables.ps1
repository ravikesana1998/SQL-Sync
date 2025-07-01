param(
    [string]$ResourceGroupName,
    [string]$ServerName,
    [string]$HubDatabase,
    [string]$MemberDatabase,
    [string]$SyncGroupName
)

# Ensure Az.Sql is loaded
Import-Module Az.Sql -Force

# SQL auth for querying metadata
$SqlConnectionString = "Server=$ServerName.database.windows.net;Database=$HubDatabase;User ID=ram;Password=Shree@123;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"

# Get FK-aware dependency order
function Get-TableDependencyOrder {
    $query = @"
    WITH FK_Dependencies AS (
        SELECT DISTINCT
            FK_Table = fk_tab.name,
            PK_Table = pk_tab.name
        FROM sys.foreign_keys fk
        JOIN sys.tables fk_tab ON fk.parent_object_id = fk_tab.object_id
        JOIN sys.tables pk_tab ON fk.referenced_object_id = pk_tab.object_id
    )
    SELECT name
    FROM sys.tables
    ORDER BY 
        (SELECT COUNT(*) 
         FROM FK_Dependencies d 
         WHERE d.FK_Table = t.name) ASC
FROM sys.tables t
"@

    $conn = New-Object System.Data.SqlClient.SqlConnection $SqlConnectionString
    $cmd = $conn.CreateCommand()
    $cmd.CommandText = $query
    $conn.Open()
    $reader = $cmd.ExecuteReader()

    $tableList = @()
    while ($reader.Read()) {
        $tableList += $reader["name"]
    }

    $conn.Close()
    return $tableList
}

$tableOrder = Get-TableDependencyOrder

if (-not $tableOrder -or $tableOrder.Count -eq 0) {
    Write-Warning "⚠️ No tables found to register. Aborting registration."
    exit 0
}

$syncMemberName = "Member-$MemberDatabase"

foreach ($tableName in $tableOrder) {
    try {
        # Get column names for the table
        $query = "SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = '$tableName'"
        $conn = New-Object System.Data.SqlClient.SqlConnection $SqlConnectionString
        $cmd = $conn.CreateCommand()
        $cmd.CommandText = $query
        $conn.Open()
        $reader = $cmd.ExecuteReader()
        $columns = @()
        while ($reader.Read()) {
            $columns += $reader["COLUMN_NAME"]
        }
        $conn.Close()

        if ($columns.Count -eq 0) {
            Write-Warning "⚠️ Skipping $tableName: No columns found."
            continue
        }

        # Register the table
        New-AzSqlSyncMemberSchemaTable `
            -ResourceGroupName $ResourceGroupName `
            -ServerName $ServerName `
            -DatabaseName $HubDatabase `
            -SyncGroupName $SyncGroupName `
            -SyncMemberName $syncMemberName `
            -SchemaName "dbo" `
            -TableName $tableName `
            -Columns $columns

        Write-Host "✅ Registered table: $tableName"

    } catch {
        Write-Warning "❌ Failed to register table $tableName: $($_.Exception.Message)"
    }
}
