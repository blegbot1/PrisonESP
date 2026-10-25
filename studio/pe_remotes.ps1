$p = 'C:\Users\citha\AppData\Local\Real\workspace\save.rbxlx'
$t = [IO.File]::ReadAllText($p)
$out = 'C:\Users\citha\Documents\PrisonESP\studio\pe_remotes.txt'
$sb = New-Object System.Text.StringBuilder

$rx = [regex]'<Item class="(RemoteEvent|RemoteFunction|BindableEvent|BindableFunction|UnreliableRemoteEvent)" referent="[^"]*">(?s).{0,800}?<string name="Name">([^<]*)</string>'
$ms = $rx.Matches($t)
[void]$sb.AppendLine('total: ' + $ms.Count)
$i = 0
foreach ($m in $ms) {
    $i++
    $cls = $m.Groups[1].Value
    $nm = $m.Groups[2].Value
    # ancestry: nearest preceding service-ish or Item names before this match
    $pre = $t.Substring([Math]::Max(0, $m.Index - 4000), 4000)
    $names = [regex]::Matches($pre, '<string name="Name">([^<]{1,40})</string>')
    $ctx = @()
    for ($k = [Math]::Max(0, $names.Count - 4); $k -lt $names.Count; $k++) {
        $ctx += $names[$k].Groups[1].Value
    }
    [void]$sb.AppendLine($i.ToString() + '. ' + $cls + ' | ' + $nm + ' | ctx: ' + ($ctx -join ' < '))
}
[IO.File]::WriteAllText($out, $sb.ToString())
Write-Output ('saved, total ' + $ms.Count)
