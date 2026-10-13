#Requires -Version 5.1
#Requires -RunAsAdministrator

# Intune Win32 app: run as System in 64-bit PowerShell before user provisioning.
# Include wallpaper.png and lockscreen.png beside this script in the package.
# Existing user profiles are not modified.

$ErrorActionPreference = 'Stop'
$baselineVersion = '2'
$markerPath = 'HKLM:\SOFTWARE\ER\Baseline'

if (-not [Environment]::Is64BitProcess) {
    throw 'Run this script in 64-bit PowerShell.'
}

$wallpaperSource = Join-Path $PSScriptRoot 'wallpaper.png'
$lockScreenSource = Join-Path $PSScriptRoot 'lockscreen.png'
$destination = Join-Path $env:ProgramData 'ER'
$wallpaper = Join-Path $destination 'wallpaper.png'
$lockScreen = Join-Path $destination 'lockscreen.png'

foreach ($source in @($wallpaperSource, $lockScreenSource)) {
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
        throw "Required image is missing from the package: $source"
    }
}

# Resolve the Default User profile location rather than assuming C:\Users.
$profileList = Get-ItemProperty -LiteralPath `
    'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList'
$defaultProfile = [Environment]::ExpandEnvironmentVariables([string]$profileList.Default)
if ([string]::IsNullOrWhiteSpace($defaultProfile)) {
    throw 'Windows did not provide a Default User profile path.'
}
$defaultHive = Join-Path $defaultProfile 'NTUSER.DAT'
if (-not (Test-Path -LiteralPath $defaultHive -PathType Leaf)) {
    throw "Default User registry hive is missing: $defaultHive"
}

# Remove a previous success marker so a failed rerun cannot appear successful.
if (Test-Path -LiteralPath $markerPath) {
    Remove-ItemProperty -LiteralPath $markerPath -Name 'Version' `
        -ErrorAction SilentlyContinue
}

New-Item -Path $destination -ItemType Directory -Force | Out-Null
Copy-Item -LiteralPath $wallpaperSource -Destination $wallpaper -Force
Copy-Item -LiteralPath $lockScreenSource -Destination $lockScreen -Force

# OEM support information.
$oem = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation'
New-Item -Path $oem -Force | Out-Null
New-ItemProperty -LiteralPath $oem -Name 'Manufacturer' `
    -Value 'Expert Radiology' -PropertyType String -Force | Out-Null
New-ItemProperty -LiteralPath $oem -Name 'SupportPhone' `
    -Value '(415) 900-2000' -PropertyType String -Force | Out-Null
New-ItemProperty -LiteralPath $oem -Name 'SupportURL' `
    -Value 'https://www.expertradiology.com/' -PropertyType String -Force | Out-Null

$oldProvider = (Get-ItemProperty -LiteralPath $oem).SupportProvider
if ($oldProvider -in @(
    'Email: support@expertradiology.com',
    'expertradiology.com',
    'support@expertradiology.com | expertradiology.com'
)) {
    Remove-ItemProperty -LiteralPath $oem -Name 'SupportProvider'
}

# Seed wallpaper and dark mode for users created after this baseline runs.
$hiveName = 'ERDefault_' + [guid]::NewGuid().ToString('N')
& reg.exe load "HKU\$hiveName" $defaultHive | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "Could not load the Default User hive (exit code $LASTEXITCODE)."
}

try {
    $desktop = "Registry::HKEY_USERS\$hiveName\Control Panel\Desktop"
    New-Item -Path $desktop -Force | Out-Null
    New-ItemProperty -LiteralPath $desktop -Name 'Wallpaper' `
        -Value $wallpaper -PropertyType String -Force | Out-Null
    New-ItemProperty -LiteralPath $desktop -Name 'WallpaperStyle' `
        -Value '10' -PropertyType String -Force | Out-Null
    New-ItemProperty -LiteralPath $desktop -Name 'TileWallpaper' `
        -Value '0' -PropertyType String -Force | Out-Null

    $theme = "Registry::HKEY_USERS\$hiveName\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
    New-Item -Path $theme -Force | Out-Null
    New-ItemProperty -LiteralPath $theme -Name 'AppsUseLightTheme' `
        -Value 0 -PropertyType DWord -Force | Out-Null
    New-ItemProperty -LiteralPath $theme -Name 'SystemUsesLightTheme' `
        -Value 0 -PropertyType DWord -Force | Out-Null
}
finally {
    [GC]::Collect()
    [GC]::WaitForPendingFinalizers()
    & reg.exe unload "HKU\$hiveName" | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Could not unload the Default User hive (exit code $LASTEXITCODE)."
    }
}

# The Group Policy lock-screen setting is supported on Enterprise/Education,
# not ordinary Windows Pro. Pro retains the copied image for a separate policy.
$edition = (Get-ItemProperty -LiteralPath `
    'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').EditionID
if ($edition -match '^(Enterprise|Education|IoTEnterprise)') {
    $personalization = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization'
    New-Item -Path $personalization -Force | Out-Null
    New-ItemProperty -LiteralPath $personalization -Name 'LockScreenImage' `
        -Value $lockScreen -PropertyType String -Force | Out-Null
}
else {
    Write-Output "Lock-screen image copied; enforcement skipped on Windows edition '$edition'."
}

# Write success only after the image, support, and Default User steps complete.
# For updates, publish the updated package AND require this version in detection.
New-Item -Path $markerPath -Force | Out-Null
New-ItemProperty -LiteralPath $markerPath -Name 'Version' `
    -Value $baselineVersion -PropertyType String -Force | Out-Null
Write-Output "Expert Radiology baseline $baselineVersion installed successfully."
