param (
    [string]$ResourceGroupName,
    [string]$ServerName,
    [string]$DatabaseName,
    [string]$SyncGroupName
)

# Import Az module if not already imported
Import-Module Az.Sql -Force -ErrorAction Stop

Write-Host "[🔍] Retrieving sync group '$SyncGroupName' on database '$DatabaseName'..."

$syncGroup = Get-AzSqlSyncGroup -ResourceGroupName $ResourceGroupName `
                                -ServerName $ServerName `
                                -DatabaseName $DatabaseName `
                                -Name $SyncGroupName

# ✅ Define valid states
$validStates = @("Ready", "Good")

Write-Host "[ℹ️] Sync Group ProvisioningState: $($syncGroup.ProvisioningState)"
Write-Host "[ℹ️] Sync Group SyncState: $($syncGroup.SyncState)"

# ❌ Validate that the sync group is fully ready before triggering
if (-not $syncGroup.ProvisioningState -or $syncGroup.ProvisioningState -ne "Succeeded") {
    $stateText = if ($syncGroup.ProvisioningState) { $syncGroup.ProvisioningState } else { "NULL or empty" }
    throw "❌ Sync Group provisioning is not completed. State: $stateText"
}


if ($validStates -notcontains $syncGroup.SyncState) {
    throw "❌ Sync Group is not in a valid sync state. Current state: $($syncGroup.SyncState)"
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
