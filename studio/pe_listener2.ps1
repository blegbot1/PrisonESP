$ErrorActionPreference = 'Continue'
$port = 8777
$outDir = 'C:\Users\citha\Documents\PrisonESP\studio'
$log = Join-Path $outDir 'pe_http_log.txt'
$inject = [IO.File]::ReadAllText((Join-Path $outDir 'pe_dump2.lua'))
$tl = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Loopback, $port)
$tl.Start()
$deadline = (Get-Date).AddMinutes(30)
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
    $head = $text
    $body = ''
    $idx = $text.IndexOf("`r`n`r`n")
    if ($idx -ge 0) { $head = $text.Substring(0, $idx); $body = $text.Substring($idx + 4) }
    $isGet = $head.StartsWith('GET')
    try {
        $respBytes = $null
        if ($isGet) {
            $payload = [System.Text.Encoding]::UTF8.GetBytes($inject)
            $hdr = [System.Text.Encoding]::ASCII.GetBytes("HTTP/1.1 200 OK`r`nContent-Type: text/plain`r`nContent-Length: " + $payload.Length + "`r`nConnection: close`r`n`r`n")
            $respBytes = New-Object System.Byte[] ($hdr.Length + $payload.Length)
            [Array]::Copy($hdr, $respBytes, $hdr.Length)
            [Array]::Copy($payload, 0, $respBytes, $hdr.Length, $payload.Length)
            [IO.File]::WriteAllText((Join-Path $outDir 'pe_inject_served.txt'), 'ok')
        } else {
            $pl = [System.Text.Encoding]::ASCII.GetBytes("HTTP/1.1 200 OK`r`nContent-Length: 2`r`nConnection: close`r`n`r`nOK")
            $respBytes = $pl
        }
        $s.Write($respBytes, 0, $respBytes.Length)
    } catch {}
    $c.Close()
    if ($isGet) { continue }
    if ($body.StartsWith('PE_BEGIN:')) {
        [IO.File]::WriteAllText($log, '', (New-Object System.Text.UTF8Encoding($false)))
        [IO.File]::WriteAllText((Join-Path $outDir 'pe_run.txt'), $body.Substring(9))
        [IO.File]::AppendAllText($log, $body + "`n", (New-Object System.Text.UTF8Encoding($false)))
        continue
    }
    if ($body.StartsWith('PE_DONE:')) {
        [IO.File]::WriteAllText((Join-Path $outDir 'pe_done.txt'), $body.Substring(8))
        [IO.File]::AppendAllText($log, "`n" + $body + "`n", (New-Object System.Text.UTF8Encoding($false)))
        continue
    }
    [IO.File]::AppendAllText($log, $body, (New-Object System.Text.UTF8Encoding($false)))
}
$tl.Stop()
