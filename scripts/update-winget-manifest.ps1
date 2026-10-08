<#
.SYNOPSIS
  Updates the winget/ manifest files for a new OutaSpace release.

.DESCRIPTION
  Fills in PackageVersion (all 3 manifests), the release download URL, and the
  SHA256 of the NSIS installer exe that WinGet installs from. Run this AFTER
  the GitHub Release for the tag has been published with its assets attached
  (the hash must match the file that is actually downloadable at InstallerUrl).

.PARAMETER Version
  The release tag, e.g. "v1.2.0" or "1.2.0".

.PARAMETER InstallerPath
  Local path to the built NSIS installer exe (e.g. dist\OutaSpace-windows-amd64-installer.exe)
  used to compute InstallerSha256. If omitted, the hash is left untouched.

.EXAMPLE
  pwsh scripts/update-winget-manifest.ps1 -Version v1.2.0 -InstallerPath dist\OutaSpace-windows-amd64-installer.exe
#>
param(
  [Parameter(Mandatory=$true)]
  [string]$Version,
  [Parameter(Mandatory=$false)]
  [string]$InstallerPath
)

$ErrorActionPreference = "Stop"

$CleanVersion = ($Version -replace '^v', '').Trim()
$RootDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$WingetDir = Join-Path $RootDir "winget"

Write-Host "Updating WinGet manifests in $WingetDir to version $CleanVersion..." -ForegroundColor Cyan

# 1. Version manifest
$versionFile = Join-Path $WingetDir "Plumbago.OutaSpace.yaml"
(Get-Content $versionFile -Raw) -replace 'PackageVersion: .*', "PackageVersion: $CleanVersion" |
  Set-Content -Path $versionFile -NoNewline

# 2. Locale manifest
$localeFile = Join-Path $WingetDir "Plumbago.OutaSpace.locale.en-US.yaml"
(Get-Content $localeFile -Raw) -replace 'PackageVersion: .*', "PackageVersion: $CleanVersion" |
  Set-Content -Path $localeFile -NoNewline

# 3. Installer manifest: version, download URL, and (if provided) the SHA256
$installerFile = Join-Path $WingetDir "Plumbago.OutaSpace.installer.yaml"
$installerContent = Get-Content $installerFile -Raw
$installerContent = $installerContent -replace 'PackageVersion: .*', "PackageVersion: $CleanVersion"
$installerContent = $installerContent -replace 'download/v[^/]+/', "download/v$CleanVersion/"

if ($InstallerPath) {
  if (-not (Test-Path $InstallerPath)) {
    throw "InstallerPath '$InstallerPath' does not exist."
  }
  $hash = (Get-FileHash -Path $InstallerPath -Algorithm SHA256).Hash
  Write-Host "Calculated SHA256: $hash" -ForegroundColor Green
  $installerContent = $installerContent -replace 'InstallerSha256: .*', "InstallerSha256: $hash"
} else {
  Write-Warning "No -InstallerPath given; InstallerSha256 left unchanged. Fill it in before submitting."
}

Set-Content -Path $installerFile -Value $installerContent -NoNewline

# 4. Validate with the winget CLI if it's available locally
$wingetCmd = Get-Command "winget" -ErrorAction SilentlyContinue
if ($wingetCmd) {
  Write-Host "Validating manifests with winget CLI..." -ForegroundColor Cyan
  winget validate --manifest $WingetDir
  if ($LASTEXITCODE -ne 0) {
    Write-Warning "winget validate returned a non-zero exit code — review the manifests above."
  }
} else {
  Write-Warning "winget CLI not found; skipping local validation. Install the App Installer package or run 'winget validate' on Windows before submitting."
}

Write-Host "Done. Review winget/*.yaml, then submit with 'wingetcreate submit winget\' or a PR to microsoft/winget-pkgs." -ForegroundColor Green
