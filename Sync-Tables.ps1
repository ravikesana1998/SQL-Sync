param (
    [string]$ResourceGroupName,
    [string]$ServerName,
    [string]$SyncGroupName,
    [string]$HubDatabase,
    [string]$MemberDatabase,
    [string]$TablesList = "EmployeeDetails,DepartmentBudget,CustomerContact"
)

# Get access token
$token = (az account get-access-token --query accessToken -o tsv)
$headers = @{
    "Authorization" = "Bearer $token"
    "Content-Type"  = "application/json"
}

# Base URL
$subscriptionId = $env:AZURE_SUBSCRIPTION_ID
$baseUrl = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Sql/servers/$ServerName/databases/$HubDatabase/syncGroups/$SyncGroupName"

# Split tables
$tables = $TablesList -split ','

foreach ($tableName in $tables) {
    Write-Host "`n⏳ Syncing table: $tableName"

    # Construct table schema payload
    $syncSchema = @{
        properties = @{
            tables = @(@{
                name = $tableName
            })
        }
    } | ConvertTo-Json -Depth 3

    # Update schema
    $schemaUrl = "$baseUrl/syncMembers/$MemberDatabase/syncSchema?api-version=2021-11-01-preview"
    $updateSchemaResponse = Invoke-RestMethod -Method POST -Uri $schemaUrl -Headers $headers -Body $syncSchema

    Write-Host "✅ Updated schema for $tableName"

    # Trigger sync
    $syncUrl = "$baseUrl/syncMembers/$MemberDatabase/sync?api-version=2021-11-01-preview"
    $syncResponse = Invoke-RestMethod -Method POST -Uri $syncUrl -Headers $headers

    Write-Host "🚀 Sync triggered for $tableName"
}
