param(
    [string]$ResourceGroupName = "your-resource-group",
    [string]$ServerName = "studentserver9",
    [string]$DatabaseName = "studentDB1",
    [string]$SyncGroupName = "StudentSyncGroup"
)

Write-Host "Logging into Azure..."
Connect-AzAccount

Write-Host "Triggering sync..."
Start-AzSqlSyncGroupSync `
    -ResourceGroupName $ResourceGroupName `
    -ServerName $ServerName `
    -DatabaseName $DatabaseName `
    -SyncGroupName $SyncGroupName

Write-Host "Sync triggered successfully."
