cls
$url = "127.0.0.1"
$port = 8080
$uri = "http://$($url):$($port)"
$count = 1;

$responses = @()
for($i = 0; $i -lt $count; $i++){
    $data = @{
        Timestamp = [DateTime]::Now.ToString('yyyy-MM-dd HH:mm:ss.fffffffzzz');
        Sentfrom = $env:COMPUTERNAME;
        Sentby = $env:USERNAME;
    }

    $responses += Invoke-WebRequest -Uri $uri -Method 'POST' -Body "$($data | ConvertTo-Xml -As String)" -ContentType 'application/json'
}

#$responses | ft -AutoSize
$responses | Select-Object -ExpandProperty StatusCode | ft -AutoSize