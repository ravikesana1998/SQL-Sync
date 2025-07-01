param(
    [string]$ResourceGroupName,
    [string]$ServerName,
    [string]$DatabaseName,
    [string]$SyncGroupName
)

function ThrowIf($Condition, $Message) {
    if ($Condition) {
        Write-Error "❌ Sync trigger failed: $Message"
        exit 1
    }
}

Write-Host "[🧪] Checking sync group '$SyncGroupName' on DB '$DatabaseName'..."

# 1. Ensure Sync Group is Ready
$syncGroup = Get-AzSqlSyncGroup -ResourceGroupName $ResourceGroupName `
                                -ServerName $ServerName `
                                -DatabaseName $DatabaseName `
                                -SyncGroupName $SyncGroupName

$validStates = @("Ready", "Good")
ThrowIf ($syncGroup.ProvisioningState -ne "Succeeded" -or ($validStates -notcontains $syncGroup.SyncState)) `
    "⚠️ Sync Group '$SyncGroupName' is not in a valid state: $($syncGroup.SyncState)"


# 2. Check if member has tables registered
$members = Get-AzSqlSyncMember -ResourceGroupName $ResourceGroupName `
                               -ServerName $ServerName `
                               -DatabaseName $DatabaseName `
                               -SyncGroupName $SyncGroupName

foreach ($member in $members) {
    $schema = Get-AzSqlSyncSchema -ResourceGroupName $ResourceGroupName `
                                  -ServerName $ServerName `
                                  -DatabaseName $DatabaseName `
                                  -SyncGroupName $SyncGroupName `
                                  -SyncMemberName $member.Name

    ThrowIf (-not $schema.Tables -or $schema.Tables.Count -eq 0) `
        "❌ No tables registered for sync member '$($member.Name)'. Cannot trigger sync."
}

# 3. Trigger the Sync
Write-Host "[🚀] Triggering sync for group '$SyncGroupName' in database '$DatabaseName'..."
Start-AzSqlSyncGroupSync -ResourceGroupName $ResourceGroupName `
                         -ServerName $ServerName `
                         -DatabaseName $DatabaseName `
                         -SyncGroupName $SyncGroupName

Write-Host "✅ Sync triggered successfully."
