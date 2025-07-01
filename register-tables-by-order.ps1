param (
    [string]$ResourceGroupName,
    [string]$ServerName,
    [string]$HubDatabase,
    [string]$SyncGroupName,
    [string]$SyncMemberName,
    [string]$TableListPath
)

Write-Host "📄 Reading table order from: $TableListPath"
$tables = Get-Content $TableListPath

foreach ($table in $tables) {
    if (-not $table.Trim()) {
        continue
    }

    $parts = $table.Split('.')
    if ($parts.Length -ne 2) {
        Write-Warning "⚠️ Invalid table name format: $table"
        continue
    }

    $schema = $parts[0].Trim('[', ']')
    $tableName = $parts[1].Trim('[', ']')

    Write-Host "🔄 Registering table: $schema.$tableName"

    try {
        Register-AzSqlSyncMemberSchemaTable `
            -ResourceGroupName $ResourceGroupName `
            -ServerName $ServerName `
            -DatabaseName $HubDatabase `
            -SyncGroupName $SyncGroupName `
            -SyncMemberName $SyncMemberName `
            -SchemaName $schema `
            -TableName $tableName
        Write-Host "✅ Registered: $schema.$tableName"
    }
    catch {
        Write-Warning "❌ Failed to register: $schema.$tableName"
        Write-Warning $_.Exception.Message
    }
}
