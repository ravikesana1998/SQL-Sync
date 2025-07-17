# Parameters
param (
    [string]$ServerName,
    [string]$DatabaseName,
    [string]$Username,
    [string]$Password,
    [string]$OutputFile
)

Write-Host "🔐 Connecting to SQL: $ServerName..."

# Build connection string
$connectionString = "Server=tcp:$ServerName,1433;Initial Catalog=$DatabaseName;Persist Security Info=False;User ID=$Username;Password=$Password;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
Write-Host "📡 Connection string: $connectionString"

# Attempt to connect
$connection = New-Object System.Data.SqlClient.SqlConnection
$connection.ConnectionString = $connectionString

try {
    $connection.Open()
    Write-Host "✅ Connected to SQL. Scanning foreign keys..."
}
catch {
    Write-Error "❌ Failed to connect to SQL Server. $_"
    exit 1
}

# Query foreign key relationships
$query = @"
SELECT 
    fk.name AS ForeignKeyName,
    tp.name AS ParentTable,
    tr.name AS ReferencedTable
FROM sys.foreign_keys AS fk
INNER JOIN sys.tables AS tp ON fk.parent_object_id = tp.object_id
INNER JOIN sys.tables AS tr ON fk.referenced_object_id = tr.object_id
"@

$command = $connection.CreateCommand()
$command.CommandText = $query
$reader = $command.ExecuteReader()

$edges = @()
while ($reader.Read()) {
    $edges += [PSCustomObject]@{
        From = $reader["ReferencedTable"]
        To   = $reader["ParentTable"]
    }
}
$reader.Close()

$tables = $edges.From + $edges.To | Sort-Object -Unique

# Perform topological sort
function TopoSort($edges, $allNodes) {
    $graph = @{}
    $inDegree = @{}
    foreach ($node in $allNodes) {
        $graph[$node] = @()
        $inDegree[$node] = 0
    }

    foreach ($e in $edges) {
        $graph[$e.From] += $e.To
        $inDegree[$e.To]++
    }

    $queue = New-Object System.Collections.Queue
    foreach ($node in $allNodes) {
        if ($inDegree[$node] -eq 0) {
            $queue.Enqueue($node)
        }
    }

    $sorted = @()
    while ($queue.Count -gt 0) {
        $node = $queue.Dequeue()
        $sorted += $node
        foreach ($neighbor in $graph[$node]) {
            $inDegree[$neighbor]--
            if ($inDegree[$neighbor] -eq 0) {
                $queue.Enqueue($neighbor)
            }
        }
    }

    return $sorted
}

$sortedTables = TopoSort -edges $edges -allNodes $tables

# Output
$OutputFile = $OutputFile.Trim()
Write-Host "📝 Writing FK-aware sync order to: $OutputFile"
Set-Content -Path $OutputFile -Value ($sortedTables -join "`n")

$connection.Close()
Write-Host "🏁 Script completed successfully."
