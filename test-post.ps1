cls
$url = "127.0.0.1"
$port = 8080

$uri = "http://$($url):$($port)"

$webclient = [System.Net.WebClient]::new()

$responses = @()
for($i = 0; $i -lt 100; $i++){
    $data = @{
        Timestamp = [DateTime]::Now.ToString('yyyy-MM-dd HH:mm:ss.fffffffzzz');
        Sentfrom = $env:COMPUTERNAME;
        Sentby = $env:USERNAME;
    }

    $responses += Invoke-WebRequest -Uri $uri -Method 'POST' -Body "$($data | ConvertTo-Json -Compress)" -ContentType 'application/json'
}

$responses | ft -AutoSize