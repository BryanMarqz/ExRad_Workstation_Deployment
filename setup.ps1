#Requires -Version 5.1

$ErrorActionPreference = 'Stop'

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)) {
    Write-Error 'This script must be run as Administrator.'
    exit 1
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$ScriptDir = $PSScriptRoot
$InstallerDir = Join-Path $ScriptDir 'Installers'
$InstallerSearchRoots = @($InstallerDir, $ScriptDir)
$PrivateDir = Join-Path $ScriptDir 'Private'
$M365ConfigurationFile = Join-Path $ScriptDir 'Config\Microsoft365-Configuration.xml'
$SourceFolder = Join-Path $ScriptDir 'Tartarus_Keybindings'
$SourceZip = Join-Path $ScriptDir 'Tartarus_Keybindings.zip'
$TartarusDestination = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Tartarus Keybindings'
$preferredGcpwTokenFile = Join-Path $PrivateDir 'set_gcpw_token.reg'
$legacyGcpwTokenFile = Join-Path $ScriptDir 'set_gcpw_token.reg'
$GcpwTokenFile = if (Test-Path -LiteralPath $preferredGcpwTokenFile) {
    $preferredGcpwTokenFile
}
else {
    $legacyGcpwTokenFile
}
$GcpwCloudManagementPath = 'HKLM:\SOFTWARE\Policies\Google\CloudManagement'
$WallpaperSource = Join-Path $ScriptDir 'Branding\Expert-Radiology-ExRad-Wallpaper-3840x2160.png'
$WallpaperDestination = Join-Path $env:ProgramData 'ExpertRadiology\Branding\ExRad-Wallpaper-3840x2160.png'
$WindowsPersonalizationPolicyPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization'
$script:RazerProfileImportPath = $null
$DoneMark = [char]0x2713

$scriptFiles = @(
    'InstallerEngine.ps1',
    'Gcpw.ps1',
    'Wallpaper.ps1',
    'WindowsSupport.ps1',
    'UnattendedImage.ps1',
    'Tartarus.ps1',
    'ChromePolicies.ps1',
    'AppCatalog.ps1',
    'DeploymentUI.ps1'
)

foreach ($scriptFile in $scriptFiles) {
    $scriptPath = Join-Path $ScriptDir "Scripts\$scriptFile"
    if (-not (Test-Path -LiteralPath $scriptPath)) {
        throw "Required deployment component is missing: Scripts\$scriptFile"
    }
    . $scriptPath
}
