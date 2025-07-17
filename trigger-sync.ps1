param (
    [string]$ResourceGroupName,
    [string]$ServerName,
    [string]$DatabaseName,
    [string]$SyncGroupName
)

# Import Az module if not already imported
Import-Module Az.Sql -Force -ErrorAction Stop

Write-Host "[🔍] Checking sync group '$SyncGroupName' on database '$DatabaseName'..."

# Retry logic in case sync group is not yet ready
$maxRetries = 10
$retryDelay = 30 # seconds
$attempt = 0

do {
    $syncGroup = Get-AzSqlSyncGroup -ResourceGroupName $ResourceGroupName `
                                    -ServerName $ServerName `
                                    -DatabaseName $DatabaseName `
                                    -Name $SyncGroupName

    $provisioningState = $syncGroup.ProvisioningState
    $syncState = $syncGroup.SyncState

    Write-Host "[🔁] Attempt $($attempt + 1): ProvisioningState = $provisioningState, SyncState = $syncState"

    if ($provisioningState -eq "Succeeded" -and $syncState -ne "NotReady") {
        Write-Host "[✅] Sync Group is ready."
        break
    }

    Start-Sleep -Seconds $retryDelay
    $attempt++
} while ($attempt -lt $maxRetries)

if ($provisioningState -ne "Succeeded" -or $syncState -eq "NotReady") {
    throw "❌ Sync Group is not ready. Final state: $provisioningState / $syncState"
}

# ✅ Ensure tables are registered
Write-Host "[🧪] Verifying schema is registered for all members..."

$schema = Get-AzSqlSyncSchema -ResourceGroupName $ResourceGroupName `
                              -ServerName $ServerName `
                              -DatabaseName $DatabaseName `
                              -SyncGroupName $SyncGroupName

if (-not $schema.Tables -or $schema.Tables.Count -eq 0) {
    throw "❌ No tables registered for sync group '$SyncGroupName'. Cannot trigger sync."
}

# ✅ All checks passed – Trigger Sync
Write-Host "🚀 Triggering sync for group '$SyncGroupName' in database '$DatabaseName'..."
Start-AzSqlSyncGroupSync -ResourceGroupName $ResourceGroupName `
                         -ServerName $ServerName `
                         -DatabaseName $DatabaseName `
                         -Name $SyncGroupName

Write-Host "✅ Sync triggered successfully."
