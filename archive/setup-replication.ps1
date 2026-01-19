$BabyNasIP = "192.168.215.2"
$MainNasIP = "10.0.0.89"
$auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes('root:74108520'))
$headers = @{
    'Authorization' = "Basic $auth"
    'Content-Type' = 'application/json'
}

Write-Host "Setting up replication from BabyNAS to Main NAS..." -ForegroundColor Cyan

# Create SSH Connection to Main NAS
Write-Host "Creating SSH connection to Main NAS..."
$sshConnection = @{
    name = "MainNAS-Replication"
    setup_type = "MANUAL"
    connection_type = "SSH"
    host = $MainNasIP
    port = 22
    username = "baby-nas"
    private_key = 1  # ID of the keypair we created
    cipher = "STANDARD"
} | ConvertTo-Json

try {
    $response = Invoke-RestMethod -Uri "http://$BabyNasIP/api/v2.0/keychaincredential" -Method Post -Headers $headers -Body @"
{
    "name": "MainNAS-SSH-Connection",
    "type": "SSH_CREDENTIALS",
    "attributes": {
        "host": "$MainNasIP",
        "port": 22,
        "username": "baby-nas",
        "private_key": 1,
        "cipher": "STANDARD",
        "connect_timeout": 10
    }
}
"@
    Write-Host "SSH Connection created: ID $($response.id)" -ForegroundColor Green
    $sshCredId = $response.id
} catch {
    Write-Host "Error creating SSH connection: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Create replication tasks for each dataset
$datasets = @(
    @{ source = "tank/backups"; target = "tank/rag-system/backups"; schedule = "0 2 30 * * *" },
    @{ source = "tank/veeam"; target = "tank/rag-system/veeam"; schedule = "0 3 0 * * *" },
    @{ source = "tank/wsl-backups"; target = "tank/rag-system/wsl-backups"; schedule = "0 3 30 * * *" },
    @{ source = "tank/phone"; target = "tank/rag-system/phone"; schedule = "0 4 0 * * *" },
    @{ source = "tank/media"; target = "tank/rag-system/media"; schedule = "0 4 30 * * *" }
)

foreach ($ds in $datasets) {
    Write-Host "Creating replication task for $($ds.source)..."

    $replTask = @{
        name = "Replicate-$($ds.source -replace '/', '-')"
        direction = "PUSH"
        transport = "SSH"
        ssh_credentials = $sshCredId
        source_datasets = @($ds.source)
        target_dataset = $ds.target
        recursive = $true
        auto = $true
        retention_policy = "SOURCE"
        compression = "LZ4"
        large_block = $true
        compressed = $true
        enabled = $true
        schedule = @{
            minute = "30"
            hour = "2"
            dom = "*"
            month = "*"
            dow = "*"
        }
    } | ConvertTo-Json -Depth 3

    try {
        $response = Invoke-RestMethod -Uri "http://$BabyNasIP/api/v2.0/replication" -Method Post -Headers $headers -Body $replTask
        Write-Host "Created replication task: $($response.name)" -ForegroundColor Green
    } catch {
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

Write-Host "`nReplication setup complete!" -ForegroundColor Green
