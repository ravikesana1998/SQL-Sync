param(
    [string]$ResourceGroupName = "rg-23-6",
    [string]$ServerName = "studentserver9",
    [string]$DatabaseName = "studentDB1",
    [string]$SyncGroupName = "StudentSyncGroup"
)

Write-Host "⚙️ Triggering Azure SQL Data Sync..."
try {
    Start-AzSqlSyncGroupSync `
        -ResourceGroupName $ResourceGroupName `
        -ServerName $ServerName `
        -DatabaseName $DatabaseName `
        -SyncGroupName $SyncGroupName

    Write-Host "✅ Sync triggered successfully."
}
catch {
    Write-Error "❌ Failed to trigger sync: $_"
    exit 1
}
