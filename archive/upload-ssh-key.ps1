$privateKey = (Get-Content 'D:\workspace\Baby_Nas\keys\baby-nas-replication' -Raw) -replace "`r`n", "`n"
$publicKey = (Get-Content 'D:\workspace\Baby_Nas\keys\baby-nas-replication.pub' -Raw).Trim()

$body = @{
    name = 'BabyNAS-Replication-Key'
    type = 'SSH_KEY_PAIR'
    attributes = @{
        private_key = $privateKey
        public_key = $publicKey
    }
} | ConvertTo-Json -Depth 3

$auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes('root:74108520'))
$headers = @{
    'Authorization' = "Basic $auth"
    'Content-Type' = 'application/json'
}

try {
    $response = Invoke-RestMethod -Uri 'http://192.168.215.2/api/v2.0/keychaincredential' -Method Post -Headers $headers -Body $body
    Write-Output "Created keypair ID: $($response.id)"
    Write-Output "Name: $($response.name)"
} catch {
    Write-Output "Error: $($_.Exception.Message)"
}
