#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$Force,
    [string]$NinjaOneUrl
)

$ErrorActionPreference = 'Stop'
$DestinationRoot = Join-Path $PSScriptRoot 'Installers'
$PrivateRoot = Join-Path $PSScriptRoot 'Private'
New-Item -ItemType Directory -Path $DestinationRoot -Force | Out-Null
New-Item -ItemType Directory -Path $PrivateRoot -Force | Out-Null
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Move-LegacyInstaller {
    param([Parameter(Mandatory = $true)][string]$FileName)

    $legacyPath = Join-Path $PSScriptRoot $FileName
    $organizedPath = Join-Path $DestinationRoot $FileName
    if ((Test-Path -LiteralPath $legacyPath) -and
        -not (Test-Path -LiteralPath $organizedPath)) {
        Move-Item -LiteralPath $legacyPath -Destination $organizedPath
        Write-Host "[MOVED] $FileName -> Installers" -ForegroundColor DarkCyan
    }
}

function Test-ExpectedSignature {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$PublisherPattern
    )

    $signature = Get-AuthenticodeSignature -LiteralPath $Path
    if ($signature.Status -ne 'Valid') {
        throw "Signature validation failed for '$Path': $($signature.Status)."
    }
    if ($signature.SignerCertificate.Subject -notmatch $PublisherPattern) {
        throw "Unexpected publisher for '$Path': $($signature.SignerCertificate.Subject)."
    }
}

function Get-SignedInstaller {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Uri,
        [Parameter(Mandatory = $true)][string]$FileName,
        [Parameter(Mandatory = $true)][string]$PublisherPattern
    )

    Move-LegacyInstaller -FileName $FileName
    $destination = Join-Path $DestinationRoot $FileName
    if ((Test-Path -LiteralPath $destination) -and -not $Force) {
        Write-Host "[SKIP] $Name already exists: $FileName" -ForegroundColor Yellow
        return
    }

    $partial = "$destination.download"
    try {
        Write-Host "[DOWNLOAD] $Name" -ForegroundColor Cyan
        Invoke-WebRequest -Uri $Uri -OutFile $partial -UseBasicParsing -MaximumRedirection 10
        Test-ExpectedSignature -Path $partial -PublisherPattern $PublisherPattern
        Move-Item -LiteralPath $partial -Destination $destination -Force
        Write-Host "[OK] $FileName" -ForegroundColor Green
    }
    finally {
        if (Test-Path -LiteralPath $partial) {
            Remove-Item -LiteralPath $partial -Force
        }
    }
}

function Get-LatestAutoHotkeyInstaller {
    $versionUri = 'https://www.autohotkey.com/download/2.0/version.txt'
    $version = (Invoke-WebRequest -Uri $versionUri -UseBasicParsing).Content.Trim()
    if ($version -notmatch '^2(?:\.\d+)+$') {
        throw "AutoHotkey returned an unexpected v2 version value: '$version'."
    }

    $fileName = "AutoHotkey_${version}_setup.exe"
    $downloadUri = "https://www.autohotkey.com/download/2.0/$fileName"
    $checksumResponse = Invoke-WebRequest -Uri "$downloadUri.sha256" -UseBasicParsing
    $checksumText = if ($checksumResponse.Content -is [byte[]]) {
        [Text.Encoding]::UTF8.GetString($checksumResponse.Content)
    }
    else {
        [string]$checksumResponse.Content
    }
    $sha256 = $checksumText.Trim()
    if ($sha256 -notmatch '^[A-Fa-f0-9]{64}$') {
        throw "AutoHotkey returned an invalid SHA256 value for '$fileName'."
    }

    Move-LegacyInstaller -FileName $fileName
    $destination = Join-Path $DestinationRoot $fileName
    if ((Test-Path -LiteralPath $destination) -and -not $Force) {
        Write-Host "[SKIP] AutoHotkey v$version already exists: $fileName" -ForegroundColor Yellow
        return
    }

    $partial = "$destination.download"
    try {
        Write-Host "[DOWNLOAD] AutoHotkey v$version" -ForegroundColor Cyan
        Invoke-WebRequest -Uri $downloadUri -OutFile $partial -UseBasicParsing -MaximumRedirection 10
        $actualHash = (Get-FileHash -LiteralPath $partial -Algorithm SHA256).Hash
        if ($actualHash -ne $sha256) {
            throw "SHA256 validation failed for '$fileName'."
        }
        Move-Item -LiteralPath $partial -Destination $destination -Force
        Write-Host "[OK] $fileName" -ForegroundColor Green
    }
    finally {
        if (Test-Path -LiteralPath $partial) {
            Remove-Item -LiteralPath $partial -Force
        }
    }
}

$downloads = @(
    @{
        Name = 'Google Chrome Enterprise'
        Uri = 'https://dl.google.com/dl/chrome/install/googlechromestandaloneenterprise64.msi'
        FileName = 'googlechromestandaloneenterprise64.msi'
        Publisher = 'CN=Google LLC'
    },
    @{
        Name = 'Microsoft Office Deployment Tool'
        Uri = 'https://officecdn.microsoft.com/pr/wsus/setup.exe'
        FileName = 'OfficeSetup.exe'
        Publisher = 'CN=Microsoft Corporation'
    },
    @{
        Name = 'Slack MSIX (64-bit)'
        Uri = 'https://slack.com/downloads/instructions/windows?build=win64_msix&ddl=1'
        FileName = 'Slack.msix'
        Publisher = 'CN="Slack Technologies, LLC"'
    },
    @{
        Name = 'Razer Synapse'
        Uri = 'https://rzr.to/synapse-4-pc-download'
        FileName = 'RazerSynapseInstaller.exe'
        Publisher = 'CN=Razer USA Ltd\.'
    }
)

foreach ($download in $downloads) {
    try {
        Get-SignedInstaller -Name $download.Name -Uri $download.Uri `
            -FileName $download.FileName -PublisherPattern $download.Publisher
    }
    catch {
        Write-Warning "$($download.Name): $($_.Exception.Message)"
    }
}

try {
    Get-LatestAutoHotkeyInstaller
}
catch {
    Write-Warning "AutoHotkey: $($_.Exception.Message)"
}

if ([string]::IsNullOrWhiteSpace($NinjaOneUrl)) {
    $NinjaOneUrl = $env:NINJAONE_INSTALLER_URL
}

$ninjaUrlFile = Join-Path $PrivateRoot 'ninjaone-url.txt'
if (-not (Test-Path -LiteralPath $ninjaUrlFile)) {
    $ninjaUrlFile = Join-Path $PSScriptRoot 'ninjaone-url.txt'
}
if ([string]::IsNullOrWhiteSpace($NinjaOneUrl) -and (Test-Path -LiteralPath $ninjaUrlFile)) {
    $NinjaOneUrl = (Get-Content -LiteralPath $ninjaUrlFile -Raw).Trim()
}

if ([string]::IsNullOrWhiteSpace($NinjaOneUrl)) {
    Write-Warning 'NinjaOne skipped. Add the private installer URL to Private\ninjaone-url.txt.'
}
else {
    try {
        $ninjaUri = [uri]$NinjaOneUrl
        if ($ninjaUri.Scheme -ne 'https' -or $ninjaUri.Host -ne 'app.ninjarmm.com') {
            throw 'The NinjaOne URL must use HTTPS on app.ninjarmm.com.'
        }

        $ninjaFileName = [IO.Path]::GetFileName($ninjaUri.AbsolutePath)
        if ($ninjaFileName -notmatch '^NinjaOne-Agent.*-Auto-.*\.msi$') {
            throw 'The URL does not point to an expected NinjaOne Auto MSI.'
        }

        Get-SignedInstaller -Name 'NinjaOne Auto Agent' -Uri $NinjaOneUrl `
            -FileName $ninjaFileName -PublisherPattern 'CN=NinjaOne LLC'
    }
    catch {
        Write-Warning "NinjaOne: $($_.Exception.Message)"
    }
}

Write-Host ''
Write-Host 'Download step complete.' -ForegroundColor Green
Write-Host "Installers folder: $DestinationRoot" -ForegroundColor Green
Write-Host 'RamSoftLauncherSetup.exe must still be added manually to the Installers folder.' -ForegroundColor Yellow
