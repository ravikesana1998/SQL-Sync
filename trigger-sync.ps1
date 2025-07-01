#  trigger-sync.ps1

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
$syncMemberName = "Member-studentdb2"
$schema = Get-AzSqlSyncSchema `
    -ResourceGroupName $ResourceGroupName `
    -ServerName $ServerName `
    -DatabaseName $DatabaseName `
    -SyncGroupName $SyncGroupName `
    -SyncMemberName $syncMemberName


    foreach ($member in $members) {
    if (-not $member.Name) {
        Write-Warning "⚠️ Skipping sync member with no name."
        continue
    }

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
