$ErrorActionPreference = 'Continue'
$port = 8777
$outDir = 'C:\Users\citha\Documents\PrisonESP\studio'
$log = Join-Path $outDir 'pe_http_log.txt'
[IO.File]::WriteAllText($log, '')
$tl = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Loopback, $port)
$tl.Start()
$deadline = (Get-Date).AddMinutes(15)
while ((Get-Date) -lt $deadline) {
    if (-not $tl.Pending()) { Start-Sleep -Milliseconds 200; continue }
    $c = $tl.AcceptTcpClient()
    $s = $c.GetStream()
    $buf = New-Object System.Byte[] 65536
    $ms = New-Object System.IO.MemoryStream
    $s.ReadTimeout = 3000
    try {
        while ($true) {
            $n = $s.Read($buf, 0, $buf.Length)
            if ($n -le 0) { break }
            $ms.Write($buf, 0, $n)
            if (-not $s.DataAvailable) {
                Start-Sleep -Milliseconds 150
                if (-not $s.DataAvailable) { break }
            }
        }
    } catch {}
    $bytes = $ms.ToArray()
    $text = [System.Text.Encoding]::UTF8.GetString($bytes)
    $idx = $text.IndexOf("`r`n`r`n")
    $body = ''
    if ($idx -ge 0) { $body = $text.Substring($idx + 4) }
    try {
        $resp = [System.Text.Encoding]::ASCII.GetBytes("HTTP/1.1 200 OK`r`nContent-Length: 2`r`nConnection: close`r`n`r`nOK")
        $s.Write($resp, 0, $resp.Length)
    } catch {}
    $c.Close()
    if ($body -eq 'PE_DONE') {
        [IO.File]::WriteAllText((Join-Path $outDir 'pe_done.txt'), 'ok-http')
        break
    }
    [IO.File]::AppendAllText($log, $body, (New-Object System.Text.UTF8Encoding($false)))
}
$tl.Stop()
