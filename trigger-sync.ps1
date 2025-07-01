 trigger-sync.ps1

param(
    [string]$ResourceGroupName,
    [string]$ServerName,
    [string]$DatabaseName,
    [string]$SyncGroupName
)

Write-Host "🚀 Triggering sync for group '$SyncGroupName' in database '$DatabaseName'..."

try {
    Start-AzSqlSyncGroupSync `
        -ResourceGroupName $ResourceGroupName `
        -ServerName $ServerName `
        -DatabaseName $DatabaseName `
        -SyncGroupName $SyncGroupName

    Write-Host "✅ Sync triggered successfully."
}
catch {
    Write-Error "❌ Sync trigger failed: $_"
    exit 1
}
