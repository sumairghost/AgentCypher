# Mojibake root-cause fixer: reverses UTF-8 -> CP1252 mis-decode.
# Finds runs (2+) of chars representable in CP1252, re-encodes them to the
# original bytes, and if those bytes form valid UTF-8, restores the true text.
$ErrorActionPreference = 'Stop'

function Get-Cp1252Byte {
  param([int]$Code)
  # Latin-1 style decode: bytes 0x80-0x9F surface as C1 controls, 0xA0-0xFF as U+00A0-U+00FF.
  if ($Code -ge 128 -and $Code -le 255) { return $Code }
  # CP1252-style decode: bytes 0x80-0x9F surface as printable specials.
  switch ($Code) {
    0x20AC { 0x80 } 0x201A { 0x82 } 0x0192 { 0x83 } 0x201E { 0x84 }
    0x2026 { 0x85 } 0x2020 { 0x86 } 0x2021 { 0x87 } 0x02C6 { 0x88 }
    0x2030 { 0x89 } 0x0160 { 0x8A } 0x2039 { 0x8B } 0x0152 { 0x8C }
    0x017D { 0x8E } 0x2018 { 0x91 } 0x2019 { 0x92 } 0x201C { 0x93 }
    0x201D { 0x94 } 0x2022 { 0x95 } 0x2013 { 0x96 } 0x2014 { 0x97 }
    0x02DC { 0x98 } 0x2122 { 0x99 } 0x0161 { 0x9A } 0x203A { 0x9B }
    0x0153 { 0x9C } 0x017E { 0x9E } 0x0178 { 0x9F }
    default { -1 }
  }
}

$strictUtf8 = [System.Text.UTF8Encoding]::new($false, $true)
$runRegex = [regex]'[\u0080-\u00FF\u20AC\u201A\u0192\u201E\u2026\u2020\u2021\u02C6\u2030\u0160\u2039\u0152\u017D\u2018\u2019\u201C\u201D\u2022\u2013\u2014\u02DC\u2122\u0161\u203A\u0153\u017E\u0178]{2,}'

$files = Get-ChildItem 'C:/Users/Hp/Downloads/AgentCypher_latest_complete_project/agent_/lib' -Recurse -Filter '*.dart'
$total = 0
foreach ($file in $files) {
  $bytes = [IO.File]::ReadAllBytes($file.FullName)
  $hasBom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
  $text = [IO.File]::ReadAllText($file.FullName)
  $count = 0
  $newText = $runRegex.Replace($text, {
    param($m)
    $bs = New-Object System.Collections.Generic.List[byte]
    $ok = $true
    foreach ($ch in $m.Value.ToCharArray()) {
      $b = Get-Cp1252Byte ([int]$ch)
      if ($b -lt 0) { $ok = $false; break }
      $bs.Add([byte]$b)
    }
    if (-not $ok) { return $m.Value }
    try {
      $decoded = $strictUtf8.GetString($bs.ToArray())
    } catch {
      return $m.Value
    }
    if ($decoded -eq $m.Value) { return $m.Value }
    $script:count++
    return $decoded
  })
  if ($count -gt 0) {
    $enc = [System.Text.UTF8Encoding]::new($hasBom)
    [IO.File]::WriteAllText($file.FullName, $newText, $enc)
    $rel = $file.FullName.Replace('C:/Users/Hp/Downloads/AgentCypher_latest_complete_project/agent_/', '')
    Write-Output ("FIXED {0}: {1} run(s)" -f $rel, $count)
    $total += $count
  }
}
Write-Output ("TOTAL RUNS FIXED: " + $total)
