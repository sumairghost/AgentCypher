$root = "C:\Users\Hp\Downloads\AgentCypher_latest_complete_project\agent_"
$out = @()
$files = @(
  "lib\core\ui\cypher_voice_orb.dart",
  "lib\widgets\overlay\assistant_orb.dart",
  "lib\overlay_main.dart",
  "lib\services\voice_service.dart",
  "lib\widgets\message_bubble.dart",
  "lib\core\theme\color_tokens.dart",
  "lib\core\theme\gradient_tokens.dart",
  "lib\core\theme\cypher_theme.dart",
  "lib\core\theme\theme_controller.dart",
  "lib\screens\settings\appearance_settings.dart"
)
foreach ($f in $files) {
  $t = Get-Content (Join-Path $root $f) -Raw
  $ob = ([regex]::Matches($t, '\{')).Count
  $cb = ([regex]::Matches($t, '\}')).Count
  $op = ([regex]::Matches($t, '\(')).Count
  $cp = ([regex]::Matches($t, '\)')).Count
  $obr = ([regex]::Matches($t, '\[')).Count
  $cbr = ([regex]::Matches($t, '\]')).Count
  $bal = "OK"
  if ($ob -ne $cb -or $op -ne $cp -or $obr -ne $cbr) { $bal = "MISMATCH" }
  $hex = ([regex]::Matches($t, '0xFF[0-9A-Fa-f]{6}')).Count
  $out += ("{0} | {1} | b {2}/{3} p {4}/{5} k {6}/{7} | hexColors {8}" -f $f, $bal, $ob, $cb, $op, $cp, $obr, $cbr, $hex)
}
# Ensure no stale references to removed private renderer symbols
$out += "=== STALE REF CHECK ==="
$overlayText = Get-Content (Join-Path $root "lib\overlay_main.dart") -Raw
if ($overlayText -match 'compact: true') { $out += "overlay: compact:true OK" } else { $out += "overlay: NO compact usage (check)" }
Get-ChildItem -Recurse (Join-Path $root "lib") -Filter *.dart | Select-String -Pattern 'CypherVoiceOrb|CypherVoiceOrbState' | ForEach-Object { $out += ("{0}: {1}" -f $_.Filename, $_.LineNumber) } | Select-Object -First 20
$out | Set-Content "C:\Users\Hp\Downloads\AgentCypher_latest_complete_project\_final_audit.txt"
Write-Output "done"