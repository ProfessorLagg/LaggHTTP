cls
$url = "127.0.0.1"
$port = 8080
$uri = "http://$($url):$($port)"
$count = 1024;

$responses = @()
for($i = 0; $i -lt $count; $i++){
    $data = @{
        Timestamp = [DateTime]::Now.ToString('yyyy-MM-dd HH:mm:ss.fffffffzzz');
        Sentfrom = $env:COMPUTERNAME;
        Sentby = $env:USERNAME;
    }
    $body = "$($data | ConvertTo-Xml -As String)"
    $responses += Invoke-WebRequest -Uri $uri -Method 'POST' -Body $body -ContentType 'application/json' -DisableKeepAlive -
}

#$responses | ft -AutoSize
$responses | Select-Object -ExpandProperty StatusCode | ft -AutoSize