$ErrorActionPreference = 'Continue'
$b = 'C:/Users/Hp/Downloads/AgentCypher_latest_complete_project/agent_'
$out = 'C:/Users/Hp/Downloads/AgentCypher_latest_complete_project/agent_/.audit_grep.txt'
Remove-Item $out -ErrorAction SilentlyContinue
Get-ChildItem "$b/lib" -Recurse -Include *.dart -File |
  Select-String -Pattern 'BiometricService|app_lock|AppLock|authenticateWithFallback' |
  ForEach-Object { Add-Content -Path $out -Value ("{0}:{1}: {2}" -f $_.Path.Substring($b.Length+1), $_.LineNumber, $_.Line.Trim()) }
Add-Content -Path $out -Value '--- DONE ---'