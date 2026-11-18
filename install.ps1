# termkit-deepseek one-line installer for Windows 10 / 11.
#
# Paste into PowerShell (no admin needed):
#
#   [Net.ServicePointManager]::SecurityProtocol='Tls12'; irm https://raw.githubusercontent.com/elisahuda6184-create/termkit-deepseek/main/install.ps1 | iex
#
# It works on a brand-new PC: it only uses Windows PowerShell, which every Windows 10/11
# has, and needs no Node.js, git, bash, winget or other package manager. It downloads the
# latest release zip from GitHub, checks its SHA-256, and runs the setup.ps1 inside it,
# which installs kimi.exe for this user, saves the API keys and prepares ~/.kimi-code.
#
# Keys: when SEVENAPI_API_KEY, CLOSEROUTER_API_KEY or OPENROUTER_API_KEY is already saved
# as a user environment variable (see the README), the install keeps the saved keys and
# asks nothing. Otherwise it asks for them (Enter skips one).
#
# Optional environment variables:
#   TERMKIT_ASK_KEYS=1       ask for the keys even when some are saved
#   TERMKIT_NO_PROMPT=1      never ask (unattended installs, CI)
#   TERMKIT_ZIP=<path|url>   install this zip instead of the latest release

function Install-TermkitDeepseek {
  $ErrorActionPreference = 'Stop'
  $ProgressPreference = 'SilentlyContinue'

  $repo = 'elisahuda6184-create/termkit-deepseek'
  $asset = 'termkit-deepseek-windows-x64.zip'
  $keyNames = @('SEVENAPI_API_KEY', 'CLOSEROUTER_API_KEY', 'OPENROUTER_API_KEY')
  $extraEnvNames = @('OPENROUTER_MANAGEMENT_KEY', 'KIMI_CODE_NO_AUTO_UPDATE')

  function Say([string]$Text) { Write-Host "   $Text" }
  function Ok([string]$Text) { Write-Host "   $Text" -ForegroundColor Green }
  function Warn([string]$Text) { Write-Host "   ! $Text" -ForegroundColor Yellow }

  function Get-HttpStatus($ErrorRecord) {
    $response = $ErrorRecord.Exception.Response
    if ($null -eq $response) { return $null }
    try { return [int]$response.StatusCode } catch { return $null }
  }

  function Save-Url([string]$Url, [string]$Path) {
    $lastError = $null
    for ($attempt = 1; $attempt -le 4; $attempt++) {
      try {
        Invoke-WebRequest -Uri $Url -OutFile $Path -UseBasicParsing -TimeoutSec 900 -Headers @{ 'User-Agent' = 'termkit-deepseek-installer' }
        if ((Test-Path -LiteralPath $Path) -and (Get-Item -LiteralPath $Path).Length -gt 0) { return }
        $lastError = 'the download was empty'
      } catch {
        $status = Get-HttpStatus $_
        if ($status -eq 404) { throw "Not found (HTTP 404): $Url" }
        $lastError = $_.Exception.Message
      }
      if ($attempt -lt 4) {
        Warn "Download failed ($lastError), retrying ($($attempt + 1)/4)..."
        Start-Sleep -Seconds (3 * $attempt)
      }
    }
    throw "Could not download $Url ($lastError). Check the internet connection (or proxy/firewall) and run the line again."
  }

  function Expand-Zip([string]$Zip, [string]$Destination) {
    if (Get-Command Expand-Archive -ErrorAction SilentlyContinue) {
      Expand-Archive -LiteralPath $Zip -DestinationPath $Destination -Force
    } else {
      Add-Type -AssemblyName System.IO.Compression.FileSystem
      [IO.Compression.ZipFile]::ExtractToDirectory($Zip, $Destination)
    }
  }

  Write-Host ''
  Write-Host 'termkit-deepseek installer' -ForegroundColor Cyan

  if ([Environment]::OSVersion.Platform -ne 'Win32NT') { throw 'This installer is for Windows.' }
  $os = [Environment]::OSVersion.Version
  if ($os.Major -lt 10) { throw "Windows 10 or 11 is required (this PC runs Windows $os)." }
  if (-not [Environment]::Is64BitOperatingSystem) { throw 'A 64-bit Windows is required.' }
  $arch = $env:PROCESSOR_ARCHITEW6432
  if (-not $arch) { $arch = $env:PROCESSOR_ARCHITECTURE }
  if ($arch -eq 'ARM64') {
    if ($os.Build -lt 22000) { throw 'This is an ARM PC with Windows 10, which cannot run the x64 kimi.exe. Windows 11 can.' }
    Warn 'ARM PC: kimi.exe runs through Windows x64 emulation.'
  }
  if (-not $env:LOCALAPPDATA -or -not $env:USERPROFILE) { throw 'LOCALAPPDATA / USERPROFILE are not set. Run this in a normal PowerShell window of your own user.' }

  foreach ($protocol in @('Tls12', 'Tls13')) {
    try {
      [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::$protocol
    } catch {
    }
  }

  $work = Join-Path ([IO.Path]::GetTempPath()) ('termkit-deepseek-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
  New-Item -ItemType Directory -Force -Path $work | Out-Null
  try {
    $zip = Join-Path $work $asset
    $checksum = "$zip.sha256"
    $source = $env:TERMKIT_ZIP
    if ($source -and (Test-Path -LiteralPath $source)) {
      Say "Using $source"
      Copy-Item -LiteralPath $source -Destination $zip
      if (Test-Path -LiteralPath "$source.sha256") { Copy-Item -LiteralPath "$source.sha256" -Destination $checksum }
    } else {
      if (-not $source) { $source = "https://github.com/$repo/releases/latest/download/$asset" }
      Say "Downloading $source"
      try {
        Save-Url $source $zip
      } catch {
        if ($_.Exception.Message -like 'Not found*') {
          throw "No release is published yet at https://github.com/$repo/releases (or it has no $asset)."
        }
        throw
      }
      try {
        Save-Url "$source.sha256" $checksum
      } catch {
        Warn "No checksum file next to the download ($($_.Exception.Message)); continuing without the SHA-256 check."
      }
    }
    $sizeMb = [Math]::Round((Get-Item -LiteralPath $zip).Length / 1MB, 1)
    Ok "Downloaded $sizeMb MB."

    if (Test-Path -LiteralPath $checksum) {
      $expected = (([IO.File]::ReadAllText($checksum)).Trim() -split '\s+')[0]
      $actual = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash
      if ($actual -ine $expected) {
        throw "The download is damaged (SHA-256 $actual, expected $expected). Run the line again."
      }
      Ok 'SHA-256 checksum matches.'
    }

    $extracted = Join-Path $work 'files'
    Expand-Zip $zip $extracted
    $setup = Get-ChildItem -LiteralPath $extracted -Recurse -Filter 'setup.ps1' | Select-Object -First 1
    if ($null -eq $setup) { throw 'The download does not contain setup.ps1.' }
    Get-ChildItem -LiteralPath $setup.DirectoryName -File | ForEach-Object {
      try { Unblock-File -LiteralPath $_.FullName } catch { }
    }

    $setupArgs = @()
    $saved = @($keyNames | Where-Object { [Environment]::GetEnvironmentVariable($_, 'User') })
    $interactive = [Environment]::UserInteractive
    try { if ([Console]::IsInputRedirected) { $interactive = $false } } catch { }
    if ($env:TERMKIT_NO_PROMPT -eq '1' -or -not $interactive) {
      $setupArgs += '-NoPrompt'
    } elseif ($saved.Count -gt 0 -and $env:TERMKIT_ASK_KEYS -ne '1') {
      $setupArgs += '-NoPrompt'
      Ok "Using your saved keys: $($saved -join ', ')"
    }

    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $setup.FullName @setupArgs
    $code = $LASTEXITCODE
    if ($code -ne 0) { throw "setup.ps1 stopped with exit code $code; see its message above." }
  } finally {
    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
  }

  $installDir = Join-Path $env:LOCALAPPDATA 'Programs\termkit-deepseek'
  if (Test-Path -LiteralPath (Join-Path $installDir 'kimi.exe')) {
    if (@($env:Path -split ';') -notcontains $installDir) { $env:Path = "$installDir;$env:Path" }
  }
  foreach ($name in $keyNames + $extraEnvNames) {
    $value = [Environment]::GetEnvironmentVariable($name, 'User')
    if ($value) { Set-Item -LiteralPath "Env:$name" -Value $value }
  }
  Write-Host ''
  Ok 'Ready. Go to your project folder and type:  kimi   (this window works too)'
}

try {
  Install-TermkitDeepseek
} catch {
  Write-Host ''
  Write-Host "termkit-deepseek install failed: $($_.Exception.Message)" -ForegroundColor Red
  Write-Host '   If antivirus or Smart App Control blocked kimi.exe, allow it and paste the line again.' -ForegroundColor Yellow
  Write-Host '   On a company PC, a policy may block PowerShell scripts; ask IT or use the zip from the Releases page.' -ForegroundColor Yellow
}
