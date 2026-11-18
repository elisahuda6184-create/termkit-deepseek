# Runs install.ps1 the way a user does (irm | iex style: the script text is evaluated in
# this session) against a zip: either a local one (TERMKIT_ZIP, before publishing) or the
# latest GitHub release (after publishing). Expects a machine without termkit-deepseek.
param(
  [string]$Script = '',
  [string]$Zip = '',
  [string]$Url = 'https://raw.githubusercontent.com/elisahuda6184-create/termkit-deepseek/main/install.ps1',
  [string]$Version = ''
)

$ErrorActionPreference = 'Stop'
$installDir = Join-Path $env:LOCALAPPDATA 'Programs\termkit-deepseek'
$exe = Join-Path $installDir 'kimi.exe'

function Check([bool]$Condition, [string]$What) {
  if (-not $Condition) { throw "FAILED: $What" }
  Write-Host "ok - $What"
}

if (Test-Path -LiteralPath $installDir) { throw "termkit-deepseek is already installed in $installDir" }

$env:TERMKIT_NO_PROMPT = '1'
if ($Zip) { $env:TERMKIT_ZIP = $Zip } else { Remove-Item Env:TERMKIT_ZIP -ErrorAction SilentlyContinue }
[Environment]::SetEnvironmentVariable('SEVENAPI_API_KEY', 'ci-oneliner-7api-key', 'User')

if ($Script) {
  $text = [IO.File]::ReadAllText($Script)
} else {
  [Net.ServicePointManager]::SecurityProtocol = 'Tls12'
  $text = Invoke-RestMethod -Uri $Url -UseBasicParsing
}
Invoke-Expression $text

Check (Test-Path -LiteralPath $exe) 'kimi.exe installed by the one-liner'
Check (@($env:Path -split ';') -contains $installDir) 'kimi is on PATH in the same session'
Check ($env:SEVENAPI_API_KEY -eq 'ci-oneliner-7api-key') 'saved key is loaded into the same session'
$env:KIMI_CODE_NO_AUTO_UPDATE = '1'
$previous = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
$printed = (& kimi --version 2>&1 | Out-String).Trim()
$ErrorActionPreference = $previous
Write-Host "kimi --version: $printed"
if ($Version) { Check ($printed -eq $Version) "kimi --version prints $Version" } else { Check ($printed.Length -gt 0) 'kimi --version prints a version' }

& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $installDir 'setup.ps1') -Uninstall -NoPrompt -RemoveKeys
Check ($LASTEXITCODE -eq 0) 'uninstall succeeded'
Check (-not (Test-Path -LiteralPath $installDir)) 'install dir removed'

Write-Host ''
Write-Host 'One-line installer test passed.'
