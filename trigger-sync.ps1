param(
    [string]$ResourceGroupName,
    [string]$ServerName,
    [string]$DatabaseName,
    [string]$SyncGroupName
)

try {
    Write-Host "🔍 Checking sync group '$SyncGroupName'..."

    $syncGroup = Get-AzSqlSyncGroup -ResourceGroupName $ResourceGroupName `
                                    -ServerName $ServerName `
                                    -DatabaseName $DatabaseName `
                                    -Name $SyncGroupName `
                                    -ErrorAction Stop

    if (-not $syncGroup) {
        throw "❌ Sync group '$SyncGroupName' not found in database '$DatabaseName'."
    }

    # Check if any tables are registered
    $members = Get-AzSqlSyncMember -ResourceGroupName $ResourceGroupName `
                                   -ServerName $ServerName `
                                   -DatabaseName $DatabaseName `
                                   -SyncGroupName $SyncGroupName

    foreach ($member in $members) {
        Write-Host "🔄 Checking schema for member '$($member.Name)'..."
        $schema = Get-AzSqlSyncSchema -ResourceGroupName $ResourceGroupName `
                                      -ServerName $ServerName `
                                      -DatabaseName $DatabaseName `
                                      -SyncGroupName $SyncGroupName `
                                      -SyncMemberName $member.Name `
                                      -ErrorAction SilentlyContinue

        if ($schema -and $schema.Count -gt 0) {
            Write-Host "✅ Schema is active with $($schema.Count) table(s) for '$($member.Name)'."
        } else {
            throw "❌ No schema/tables found for sync member '$($member.Name)'. Cannot trigger sync."
        }
    }

    Write-Host "🚀 Triggering sync for group '$SyncGroupName' in database '$DatabaseName'..."
    Start-AzSqlSyncGroupSync -ResourceGroupName $ResourceGroupName `
                             -ServerName $ServerName `
                             -DatabaseName $DatabaseName `
                             -Name $SyncGroupName

    Write-Host "✅ Sync triggered successfully."

} catch {
    Write-Error "❌ Sync trigger failed: $($_.Exception.Message)"
    exit 1
}
