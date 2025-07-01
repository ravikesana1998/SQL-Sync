param(
    [string]$ResourceGroupName,
    [string]$ServerName,
    [string]$DatabaseName,
    [string]$SyncGroupName
)

function Write-Log {
    param([string]$Message)
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $Message"
}

try {
    Write-Log "🔍 Checking sync group '$SyncGroupName' on DB '$DatabaseName'..."

    $syncGroup = Get-AzSqlSyncGroup `
        -ResourceGroupName $ResourceGroupName `
        -ServerName $ServerName `
        -DatabaseName $DatabaseName `
        -Name $SyncGroupName -ErrorAction Stop

    if (-not $syncGroup) {
        throw "❌ Sync Group '$SyncGroupName' not found in database '$DatabaseName'."
    }

    if ($syncGroup.SyncState -notin @("Ready", "Good")) {
        throw "⚠️ Sync Group '$SyncGroupName' is not in a valid state: $($syncGroup.SyncState)."
    }

    Write-Log "🧪 Verifying schema is registered for all members..."

    $members = Get-AzSqlSyncMember `
        -ResourceGroupName $ResourceGroupName `
        -ServerName $ServerName `
        -DatabaseName $DatabaseName `
        -SyncGroupName $SyncGroupName

    foreach ($member in $members) {
        $schema = Get-AzSqlSyncSchema `
            -ResourceGroupName $ResourceGroupName `
            -ServerName $ServerName `
            -DatabaseName $DatabaseName `
            -SyncGroupName $SyncGroupName `
            -SyncMemberName $member.Name `
            -ErrorAction SilentlyContinue

        if (-not $schema -or $schema.Tables.Count -eq 0) {
            throw "❌ No tables registered for sync member '$($member.Name)'. Cannot trigger sync."
        }

        Write-Log "✅ Member '$($member.Name)' has $($schema.Tables.Count) table(s) registered."
    }

    Write-Log "🚀 Triggering sync for group '$SyncGroupName'..."

    $operation = Start-AzSqlSyncGroupSync `
        -ResourceGroupName $ResourceGroupName `
        -ServerName $ServerName `
        -DatabaseName $DatabaseName `
        -SyncGroupName $SyncGroupName `
        -ErrorAction Stop

    Write-Log "✅ Sync triggered successfully. Operation ID: $($operation.SyncGroupLogId)"
}
catch {
    Write-Error "❌ Sync trigger failed: $($_.Exception.Message)"
    exit 1
}
