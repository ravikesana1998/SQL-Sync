param(
    [string]$ResourceGroupName,
    [string]$ServerName,
    [string]$HubDatabase,
    [string]$SyncGroupName,
    [string[]]$TableNames
)

# Connect is handled by DevOps automatically

foreach ($table in $TableNames) {
    Write-Host "🔍 Processing table: $table"

    # Get table schema (default to dbo)
    $schema = "dbo"

    # Get column metadata from hub DB
    $columns = Get-AzSqlSyncSchema `
        -ResourceGroupName $ResourceGroupName `
        -ServerName $ServerName `
        -DatabaseName $HubDatabase `
        -SyncGroupName $SyncGroupName `
        | Where-Object { $_.TableName -eq $table -and $_.SchemaName -eq $schema }

    if (-not $columns) {
        Write-Warning "⚠️ Table $table not found in schema metadata"
        continue
    }

    # Register the table
    New-AzSqlSyncMemberSchemaTable `
        -ResourceGroupName $ResourceGroupName `
        -ServerName $ServerName `
        -DatabaseName $HubDatabase `
        -SyncGroupName $SyncGroupName `
        -SyncMemberName "Member-studentDB2" `
        -SchemaName $schema `
        -TableName $table

    Write-Host "✅ Table $table registered for sync"
}
