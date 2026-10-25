$t = [IO.File]::ReadAllText('C:\Users\citha\Documents\PrisonESP\PrisonESP.lua')
$sb = New-Object System.Text.StringBuilder

# PE_RU ключи
$ruStart = $t.IndexOf('local PE_RU = {')
$ruEnd = $t.IndexOf('local function peTr')
$ruBlock = $t.Substring($ruStart, $ruEnd - $ruStart)
$ruKeys = @{}
foreach ($m in [regex]::Matches($ruBlock, '\["([^"]+)"\]')) { $ruKeys[$m.Groups[1].Value] = 1 }

# GUI-блок: от создания окна до guiOK = true
$guiStart = $t.IndexOf('safeNewTab(W, "ESP"')
$guiEnd = $t.IndexOf('PE_GUI_READY = true')
$gui = $t.Substring($guiStart, $guiEnd - $guiStart)

$guiStrings = @{}
foreach ($m in [regex]::Matches($gui, 'Name = "([^"]+)"')) { $guiStrings[$m.Groups[1].Value] = 1 }
foreach ($m in [regex]::Matches($gui, 'CreateSection\("([^"]+)"\)')) { $guiStrings[$m.Groups[1].Value] = 1 }
foreach ($m in [regex]::Matches($gui, 'Title = "([^"]+)"')) { $guiStrings[$m.Groups[1].Value] = 1 }

[void]$sb.AppendLine('=== GUI strings NOT in PE_RU (stay EN in RU mode) ===')
foreach ($k in ($guiStrings.Keys | Sort-Object)) {
    if (-not $ruKeys.ContainsKey($k)) { [void]$sb.AppendLine('MISS: ' + $k) }
}
[void]$sb.AppendLine('')
[void]$sb.AppendLine('=== Dead RU keys (no matching GUI string) ===')
foreach ($k in ($ruKeys.Keys | Sort-Object)) {
    if (-not $guiStrings.ContainsKey($k)) { [void]$sb.AppendLine('DEAD: ' + $k) }
}
[void]$sb.AppendLine('')
[void]$sb.AppendLine('gui strings: ' + $guiStrings.Count + ' | ru keys: ' + $ruKeys.Count)
[IO.File]::WriteAllText('C:\Users\citha\Documents\PrisonESP\studio\pe_tr.txt', $sb.ToString())
Write-Output ('gui=' + $guiStrings.Count + ' ru=' + $ruKeys.Count)
