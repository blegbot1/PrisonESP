$f='C:\Users\citha\AppData\Local\Real\workspace\save.rbxlx'
$t=[IO.File]::ReadAllText($f)
$sb=New-Object System.Text.StringBuilder
$rx=[regex]'(?s)<ProtectedString name="Source"><!\[CDATA\[(.*?)\]\]></ProtectedString>'
foreach($m in $rx.Matches($t)){
  $src=$m.Groups[1].Value
  if($src.Length -lt 200){ continue }
  $after=$t.Substring($m.Index+$m.Length,[Math]::Min(3000,$t.Length-$m.Index-$m.Length))
  $nmM=[regex]::Match($after,'<string name="Name">([^<]{1,60})</string>')
  $nm=if($nmM.Success){$nmM.Groups[1].Value}else{'?'}
  if($nm -match 'sprint|Announcement'){
    [void]$sb.AppendLine('===== '+$nm)
    foreach($line in ($src -split "`n")){
      if($line -match 'WalkSpeed|JumpPower|FieldOfView|GetAttribute|IsInGroup|UserId|KeyCode'){
        [void]$sb.AppendLine('  '+$line.Trim())
      }
    }
  }
}
[IO.File]::WriteAllText('C:\Users\citha\Documents\PrisonESP\studio\pe_ui.txt',$sb.ToString())
Write-Output done
