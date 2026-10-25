$t = [IO.File]::ReadAllText('C:\Users\citha\AppData\Local\Real\workspace\save.rbxlx')
$sb = New-Object System.Text.StringBuilder
# У скриптов Source идёт ПЕРЕД Name — ищем Source, имя берём после него.
$rx = [regex]'(?s)<ProtectedString name="Source"><!\[CDATA\[(.*?)\]\]></ProtectedString>'
$swept = 0
foreach ($m in $rx.Matches($t)) {
    $swept++
    $src = $m.Groups[1].Value
    if ($src.Length -lt 100) { continue }
    $after = $t.Substring($m.Index + $m.Length, [Math]::Min(3000, $t.Length - $m.Index - $m.Length))
    $nmM = [regex]::Match($after, '<string name="Name">([^<]{1,60})</string>')
    $nm = if ($nmM.Success) { $nmM.Groups[1].Value } else { '?' }
    foreach ($kw in @('require(', 'HttpGet', 'loadstring', 'TeleportService',
        'DataStore', 'MarketplaceService', 'HttpService', 'getfenv',
        'PromptGamePassPurchase', 'PromptProductPurchase')) {
        $idx = $src.IndexOf($kw, [System.StringComparison]::OrdinalIgnoreCase)
        if ($idx -ge 0) {
            $st = [Math]::Max(0, $idx - 60)
            $snip = $src.Substring($st, [Math]::Min(160, $src.Length - $st))
            $snip = $snip -replace "\s+", " "
            [void]$sb.AppendLine("[$kw] $nm :: ...$snip")
        }
    }
}
[void]$sb.AppendLine("swept sources: $swept")
[IO.File]::WriteAllText('C:\Users\citha\Documents\PrisonESP\studio\pe_sweep.txt', $sb.ToString())
Write-Output "done, sources swept: $swept"
