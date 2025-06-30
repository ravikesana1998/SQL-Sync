param(
    [string]$ResourceGroupName,
    [string]$ServerName,
    [string]$HubDatabase,
    [string]$SyncGroupName,
    [string[]]$TableNames
)

foreach ($table in $TableNames) {
    $schema = "dbo"

    Write-Host "🔍 Registering table: $schema.$table"

    try {
        New-AzSqlSyncMemberSchemaTable `
            -ResourceGroupName $ResourceGroupName `
            -ServerName $ServerName `
            -DatabaseName $HubDatabase `
            -SyncGroupName $SyncGroupName `
            -SyncMemberName "Member-studentDB2" `
            -SchemaName $schema `
            -TableName $table

        Write-Host "✅ Table $schema.$table registered"
    }
    catch {
        Write-Warning "⚠️ Could not register table $table: $_"
    }
}
