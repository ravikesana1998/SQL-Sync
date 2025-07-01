param (
    [string]$SqlServerName = "studentserver9.database.windows.net",
    [string]$DatabaseName = "studentsdb1",
    [string]$Username = "ram",
    [string]$Password = "Shree@123"
)

# Load required .NET assembly
Add-Type -AssemblyName System.Data

# Build SQL connection
$connString = "Server=tcp:$SqlServerName,1433;Initial Catalog=$DatabaseName;Persist Security Info=False;User ID=$Username;Password=$Password;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
$conn = New-Object System.Data.SqlClient.SqlConnection $connString
$conn.Open()

# Query FK dependencies
$cmd = $conn.CreateCommand()
$cmd.CommandText = @"
WITH FK_Dependencies AS (
    SELECT 
        fk.name AS FK_Name,
        OBJECT_SCHEMA_NAME(fk.parent_object_id) + '.' + OBJECT_NAME(fk.parent_object_id) AS ChildTable,
        OBJECT_SCHEMA_NAME(fk.referenced_object_id) + '.' + OBJECT_NAME(fk.referenced_object_id) AS ParentTable
    FROM sys.foreign_keys fk
)
SELECT DISTINCT ChildTable, ParentTable FROM FK_Dependencies
"@

$reader = $cmd.ExecuteReader()
$edges = @()
while ($reader.Read()) {
    $edges += [PSCustomObject]@{
        Child  = $reader["ChildTable"]
        Parent = $reader["ParentTable"]
    }
}
$reader.Close()

# Topological sort (to order by FK-safe hierarchy)
function TopoSort {
    param ([array]$Edges)

    $graph = @{}
    $indegree = @{}

    foreach ($edge in $Edges) {
        $graph[$edge.Parent] = $graph[$edge.Parent] + @($edge.Child)
        $indegree[$edge.Child] = $indegree[$edge.Child] + 1
        if (-not $indegree.ContainsKey($edge.Parent)) { $indegree[$edge.Parent] = 0 }
    }

    $queue = New-Object System.Collections.Queue
    $indegree.Keys | Where-Object { $indegree[$_] -eq 0 } | ForEach-Object { $queue.Enqueue($_) }

    $sorted = @()
    while ($queue.Count -gt 0) {
        $table = $queue.Dequeue()
        $sorted += $table
        if ($graph[$table]) {
            foreach ($child in $graph[$table]) {
                $indegree[$child]--
                if ($indegree[$child] -eq 0) {
                    $queue.Enqueue($child)
                }
            }
        }
    }

    return $sorted
}

$orderedTables = TopoSort -Edges $edges

# Save output to file (for next pipeline steps to consume)
param (
    [string]$SqlServerName = "studentserver9.database.windows.net",
    [string]$DatabaseName = "studentsdb1",
    [string]$Username = "ram",
    [string]$Password = "Shree@123",
    [string]$OutputFile = "./sync-table-order.txt"
)

$orderedTables | Out-File -FilePath $outputFile -Encoding UTF8
Write-Host "✅ FK table sync order saved to: $outputFile"

$conn.Close()
