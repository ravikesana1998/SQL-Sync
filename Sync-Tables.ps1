param(
    [string]$ResourceGroupName,
    [string]$ServerName,
    [string]$SyncGroupName,
    [string]$HubDatabase,
    [string]$MemberDatabase,
    [string]$SqlUser,
    [string]$SqlPassword
)

# === Authenticate with Azure REST ===
$token = (Get-AzAccessToken).Token
$headers = @{
    "Authorization" = "Bearer $token"
    "Content-Type"  = "application/json"
}

# === Table list to sync ===
$tablesToSync = @("EmployeeDetails", "DepartmentBudget", "CustomerContact")

foreach ($table in $tablesToSync) {
    Write-Host "`n🔄 Syncing table: $table"

    # === Get columns from hub database ===
    $connectionString = "Server=tcp:$ServerName.database.windows.net,1433;Initial Catalog=$HubDatabase;Persist Security Info=False;User ID=$SqlUser;Password=$SqlPassword;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
    $query = "SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = '$table'"

    $columns = Invoke-Sqlcmd -ConnectionString $connectionString -Query $query | Select-Object -ExpandProperty COLUMN_NAME

    if (!$columns) {
        Write-Warning "⚠️ Table $table not found or has no columns. Skipping."
        continue
    }

    # === Construct sync schema payload ===
    $columnList = @()
    foreach ($col in $columns) {
        $columnList += @{
            name = $col
        }
    }

    $schemaPayload = @{
        properties = @{
            columns = $columnList
        }
    } | ConvertTo-Json -Depth 5

    # === PUT schema to Azure Data Sync API ===
    $syncTableUrl = "https://management.azure.com/subscriptions/$($env:AZURE_SUBSCRIPTION_ID)/resourceGroups/$ResourceGroupName/providers/Microsoft.Sql/servers/$ServerName/databases/$HubDatabase/syncGroups/$SyncGroupName/syncMembers/$MemberDatabase/tables/$table?api-version=2021-11-01-preview"

    $putResp = Invoke-RestMethod -Method PUT -Uri $syncTableUrl -Headers $headers -Body $schemaPayload

    Write-Host "✅ Schema updated for: $table"

    # === Trigger a manual sync ===
    $triggerUrl = "https://management.azure.com/subscriptions/$($env:AZURE_SUBSCRIPTION_ID)/resourceGroups/$ResourceGroupName/providers/Microsoft.Sql/servers/$ServerName/databases/$HubDatabase/syncGroups/$SyncGroupName/syncMembers/$MemberDatabase/sync?api-version=2021-11-01-preview"

    $syncResp = Invoke-RestMethod -Method POST -Uri $triggerUrl -Headers $headers
    Write-Host "🚀 Sync triggered for: $table"

    Start-Sleep -Seconds 10  # Optional delay between tables
}
