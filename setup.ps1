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
$SourceFolder = Join-Path $ScriptDir 'Tartarus_Keybindings'
$SourceZip = Join-Path $ScriptDir 'Tartarus_Keybindings.zip'
$TartarusDestination = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Tartarus Keybindings'
$GcpwTokenFile = Join-Path $ScriptDir 'set_gcpw_token.reg'
$GcpwCloudManagementPath = 'HKLM:\SOFTWARE\Policies\Google\CloudManagement'
$WallpaperSource = Join-Path $ScriptDir 'Branding\Expert-Radiology-ExRad-Wallpaper-3840x2160.png'
$WallpaperDestination = Join-Path $env:ProgramData 'ExpertRadiology\Branding\ExRad-Wallpaper-3840x2160.png'
$WindowsPersonalizationPolicyPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization'
$DoneMark = [char]0x2713

function Get-FirstFileName {
    param(
        [Parameter(Mandatory = $true)][string]$Filter,
        [Parameter(Mandatory = $true)][string]$Fallback
    )

    $match = Get-ChildItem -LiteralPath $ScriptDir -Filter $Filter -File |
        Sort-Object Name |
        Select-Object -First 1

    if ($null -eq $match) { return $Fallback }
    return $match.Name
}

function Get-FirstFileNameFromFilters {
    param(
        [Parameter(Mandatory = $true)][string[]]$Filters,
        [Parameter(Mandatory = $true)][string]$Fallback
    )

    foreach ($filter in $Filters) {
        $match = Get-ChildItem -LiteralPath $ScriptDir -Filter $filter -File |
            Sort-Object Name |
            Select-Object -First 1
        if ($null -ne $match) { return $match.Name }
    }

    return $Fallback
}

function Get-DisplayDriverRecords {
    try {
        return @(Get-CimInstance -ClassName Win32_PnPSignedDriver `
            -Filter "DeviceClass='DISPLAY'" -ErrorAction Stop)
    }
    catch {
        return @()
    }
}

function Test-DisplayHardwarePresent {
    param([Parameter(Mandatory = $true)][string]$VendorId)

    return $null -ne (Get-DisplayDriverRecords |
        Where-Object { $_.DeviceID -match $VendorId } |
        Select-Object -First 1)
}

function Test-DisplayDriverInstalled {
    param(
        [Parameter(Mandatory = $true)][string]$VendorId,
        [Parameter(Mandatory = $true)][string]$ProviderPattern
    )

    return $null -ne (Get-DisplayDriverRecords |
        Where-Object {
            $_.DeviceID -match $VendorId -and
            $_.DriverProviderName -match $ProviderPattern -and
            -not [string]::IsNullOrWhiteSpace($_.DriverVersion)
        } |
        Select-Object -First 1)
}

function Test-AppInstalled {
    param([Parameter(Mandatory = $true)][hashtable]$App)

    if ($App.InstalledTest) {
        return [bool](& $App.InstalledTest)
    }
    return Test-Path -Path $App.CheckPath
}

function Test-AppHardwarePresent {
    param([Parameter(Mandatory = $true)][hashtable]$App)

    if ($App.HardwareTest) {
        return [bool](& $App.HardwareTest)
    }
    return $true
}

function Test-AutoHotkeyV2Installed {
    $candidatePaths = @(
        "$env:ProgramFiles\AutoHotkey\v2\AutoHotkey64.exe",
        "$env:ProgramFiles\AutoHotkey\v2\AutoHotkey32.exe",
        "$env:ProgramFiles\AutoHotkey\UX\AutoHotkeyUX.exe",
        "${env:ProgramFiles(x86)}\AutoHotkey\v2\AutoHotkey32.exe",
        "${env:ProgramFiles(x86)}\AutoHotkey\UX\AutoHotkeyUX.exe",
        "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe",
        "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey32.exe",
        "$env:LOCALAPPDATA\Programs\AutoHotkey\UX\AutoHotkeyUX.exe"
    )
    if ($candidatePaths | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1) {
        return $true
    }

    $uninstallRoots = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    $registered = Get-ItemProperty -Path $uninstallRoots -ErrorAction SilentlyContinue |
        Where-Object {
            $_.DisplayName -match '^AutoHotkey' -and
            ($_.DisplayVersion -match '^2(?:\.|$)' -or $_.DisplayName -match '(?:^|\s)v?2(?:\.|\s|$)')
        } |
        Select-Object -First 1
    if ($null -ne $registered) { return $true }

    foreach ($commandName in @('AutoHotkey.exe', 'AutoHotkey64.exe', 'AutoHotkey32.exe')) {
        $commands = @(Get-Command $commandName -CommandType Application -All -ErrorAction SilentlyContinue)
        foreach ($command in $commands) {
            $version = [Diagnostics.FileVersionInfo]::GetVersionInfo($command.Source).ProductVersion
            if ($version -match '^2(?:\.|$)') { return $true }
        }
    }

    return $false
}

function Test-GcpwEnrollmentTokenConfigured {
    try {
        $configuredToken = (Get-ItemProperty -LiteralPath $GcpwCloudManagementPath `
            -Name 'EnrollmentToken' -ErrorAction Stop).EnrollmentToken
        return -not [string]::IsNullOrWhiteSpace($configuredToken)
    }
    catch {
        return $false
    }
}

function Get-GcpwEnrollmentTokenFromFile {
    if (-not (Test-Path -LiteralPath $GcpwTokenFile)) {
        throw 'set_gcpw_token.reg was not found beside setup.ps1.'
    }

    $raw = Get-Content -LiteralPath $GcpwTokenFile -Raw -Encoding Unicode
    if ($raw -notmatch 'Windows Registry Editor Version 5\.00') {
        # Some editors save .reg files as UTF-8 rather than UTF-16 LE.
        $raw = Get-Content -LiteralPath $GcpwTokenFile -Raw -Encoding UTF8
    }

    $sections = [regex]::Matches($raw, '(?m)^\s*\[[^\]]+\]\s*$')
    if ($sections.Count -ne 1 -or
        $sections[0].Value -notmatch '^\s*\[HKEY_LOCAL_MACHINE\\SOFTWARE\\Policies\\Google\\CloudManagement\]\s*$') {
        throw 'The registry file must contain only the approved GCPW CloudManagement key.'
    }

    $assignments = [regex]::Matches($raw, '(?m)^\s*(?:@|"[^"]+")\s*=.*$')
    if ($assignments.Count -ne 1 -or $assignments[0].Value -notmatch '^\s*"EnrollmentToken"\s*=') {
        throw 'The registry file must contain only one EnrollmentToken value.'
    }

    $tokenMatch = [regex]::Match(
        $raw,
        '(?m)^\s*"EnrollmentToken"\s*=\s*"(?<Token>[^"\r\n]+)"\s*$'
    )
    if (-not $tokenMatch.Success -or [string]::IsNullOrWhiteSpace($tokenMatch.Groups['Token'].Value)) {
        throw 'A valid GCPW EnrollmentToken value was not found.'
    }

    return $tokenMatch.Groups['Token'].Value
}

function Set-GcpwEnrollmentToken {
    $token = Get-GcpwEnrollmentTokenFromFile

    if (-not (Test-Path -LiteralPath $GcpwCloudManagementPath)) {
        New-Item -Path $GcpwCloudManagementPath -Force | Out-Null
    }
    New-ItemProperty -LiteralPath $GcpwCloudManagementPath -Name 'EnrollmentToken' `
        -Value $token -PropertyType String -Force | Out-Null

    $storedToken = (Get-ItemProperty -LiteralPath $GcpwCloudManagementPath `
        -Name 'EnrollmentToken' -ErrorAction Stop).EnrollmentToken
    if ($storedToken -ne $token) {
        throw 'The GCPW enrollment token could not be verified after writing it.'
    }
}

function Test-ExRadWallpaperConfigured {
    if (-not (Test-Path -LiteralPath $WallpaperSource) -or
        -not (Test-Path -LiteralPath $WallpaperDestination)) {
        return $false
    }

    try {
        $sourceHash = (Get-FileHash -LiteralPath $WallpaperSource -Algorithm SHA256).Hash
        $destinationHash = (Get-FileHash -LiteralPath $WallpaperDestination -Algorithm SHA256).Hash
        $desktopWallpaper = (Get-ItemProperty -LiteralPath 'HKCU:\Control Panel\Desktop' `
            -Name 'Wallpaper' -ErrorAction Stop).Wallpaper
        $lockScreenWallpaper = (Get-ItemProperty -LiteralPath $WindowsPersonalizationPolicyPath `
            -Name 'LockScreenImage' -ErrorAction Stop).LockScreenImage
        return $sourceHash -eq $destinationHash -and
            $desktopWallpaper -eq $WallpaperDestination -and
            $lockScreenWallpaper -eq $WallpaperDestination
    }
    catch {
        return $false
    }
}

function Set-DesktopWallpaperRegistry {
    param([Parameter(Mandatory = $true)][string]$RegistryPath)

    if (-not (Test-Path -LiteralPath $RegistryPath)) {
        New-Item -Path $RegistryPath -Force | Out-Null
    }
    New-ItemProperty -LiteralPath $RegistryPath -Name 'Wallpaper' `
        -Value $WallpaperDestination -PropertyType String -Force | Out-Null
    New-ItemProperty -LiteralPath $RegistryPath -Name 'WallpaperStyle' `
        -Value '10' -PropertyType String -Force | Out-Null
    New-ItemProperty -LiteralPath $RegistryPath -Name 'TileWallpaper' `
        -Value '0' -PropertyType String -Force | Out-Null
}

function Set-ExRadWallpaper {
    if (-not (Test-Path -LiteralPath $WallpaperSource)) {
        throw 'The ExRad wallpaper image was not found in the Branding folder.'
    }

    $brandingFolder = Split-Path -Parent $WallpaperDestination
    New-Item -ItemType Directory -Path $brandingFolder -Force | Out-Null
    Copy-Item -LiteralPath $WallpaperSource -Destination $WallpaperDestination -Force

    # Apply immediately for the technician/current user.
    Set-DesktopWallpaperRegistry -RegistryPath 'HKCU:\Control Panel\Desktop'
    if (-not ('ExRadWallpaper.NativeMethods' -as [type])) {
        Add-Type -TypeDefinition @'
namespace ExRadWallpaper {
    using System.Runtime.InteropServices;
    public static class NativeMethods {
        [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        public static extern bool SystemParametersInfo(
            int action, int parameter, string value, int flags);
    }
}
'@
    }
    $wallpaperApplied = [ExRadWallpaper.NativeMethods]::SystemParametersInfo(
        20, 0, $WallpaperDestination, 3
    )
    if (-not $wallpaperApplied) {
        throw "Windows could not refresh the current desktop wallpaper (Win32 error $([Runtime.InteropServices.Marshal]::GetLastWin32Error()))."
    }

    # Windows uses this managed image for both the lock and sign-in screens.
    if (-not (Test-Path -LiteralPath $WindowsPersonalizationPolicyPath)) {
        New-Item -Path $WindowsPersonalizationPolicyPath -Force | Out-Null
    }
    New-ItemProperty -LiteralPath $WindowsPersonalizationPolicyPath -Name 'LockScreenImage' `
        -Value $WallpaperDestination -PropertyType String -Force | Out-Null

    # Seed the desktop wallpaper for accounts created after deployment.
    $defaultUserHive = Join-Path $env:SystemDrive 'Users\Default\NTUSER.DAT'
    $defaultUserHiveName = 'ExRadDeploymentDefaultUser'
    if (Test-Path -LiteralPath $defaultUserHive) {
        & reg.exe load "HKU\$defaultUserHiveName" $defaultUserHive | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw 'Windows could not load the default user profile to set its wallpaper.'
        }
        try {
            Set-DesktopWallpaperRegistry -RegistryPath `
                "Registry::HKEY_USERS\$defaultUserHiveName\Control Panel\Desktop"
        }
        finally {
            [GC]::Collect()
            [GC]::WaitForPendingFinalizers()
            & reg.exe unload "HKU\$defaultUserHiveName" | Out-Null
            if ($LASTEXITCODE -ne 0) {
                throw 'The default user registry profile could not be unloaded.'
            }
        }
    }

    if (-not (Test-ExRadWallpaperConfigured)) {
        throw 'The wallpaper settings could not be verified after they were applied.'
    }
}

# Generated NinjaOne installers contain an enrollment token. Keep them local.
$NinjaFile = Get-FirstFileName -Filter 'NinjaOne-Agent*-Auto-*.msi' -Fallback 'NinjaOne-Agent-Auto-x86-64.msi'
$SlackFile = Get-FirstFileName -Filter 'Slack*.msix*' -Fallback 'Slack.msix'
$NvidiaDriverFile = Get-FirstFileNameFromFilters `
    -Filters @('NVIDIA-Driver*.exe', '*-desktop-win10-win11-64bit-*-dch-whql.exe') `
    -Fallback 'NVIDIA-Driver.exe'
$AmdDriverFile = Get-FirstFileNameFromFilters `
    -Filters @('AMD-Driver*.exe', '*amd-software-adrenalin-edition-*.exe') `
    -Fallback 'AMD-Driver.exe'
$AmdDriverIsWebBootstrapper = $AmdDriverFile -match '(?i)minimalsetup.*_web\.exe$'
$AmdDriverArgs = if ($AmdDriverIsWebBootstrapper) { '' } else { '-install' }

$Apps = @(
    @{ Name = 'Google Chrome'; CheckPath = "$env:ProgramFiles\Google\Chrome\Application\chrome.exe"; Type = 'MSI'; File = 'googlechromestandaloneenterprise64.msi'; Args = '/qn /norestart'; DownloadAvailable = $true },
    @{ Name = 'Microsoft Word (M365)'; CheckPath = "$env:ProgramFiles\Microsoft Office\root\Office16\WINWORD.EXE"; Type = 'EXE'; File = 'OfficeSetup.exe'; Args = "/configure `"$ScriptDir\configuration.xml`""; DownloadAvailable = $true },
    @{ Name = 'Slack'; CheckPath = "$env:ProgramFiles\WindowsApps\*Slack*"; Type = 'MSIX'; File = $SlackFile; Args = ''; DownloadAvailable = $true },
    @{ Name = 'NinjaOne Agent'; CheckPath = "${env:ProgramFiles(x86)}\NinjaOne\NinjaRMMAgent.exe"; Type = 'MSI'; File = $NinjaFile; Args = '/qn /norestart'; DownloadAvailable = $true },
    @{ Name = 'RamSoft Client'; CheckPath = "${env:ProgramFiles(x86)}\RamSoft\Apps\rsapplauncher.exe"; Type = 'EXE'; File = 'RamSoftLauncherSetup.exe'; Args = '/S /v"/qn /norestart"'; InteractiveFallback = $true; ManualInstall = $true },
    @{ Name = 'AutoHotkey v2'; Type = 'EXE'; File = 'AutoHotkey_2.0.26_setup.exe'; Args = '/silent /Elevate'; DownloadAvailable = $true; InstalledTest = { Test-AutoHotkeyV2Installed } },
    @{ Name = 'GCPW (Google Credential)'; CheckPath = "$env:ProgramFiles\Google\Credential Provider"; Type = 'EXE'; File = 'gcpwstandaloneenterprise64.exe'; Args = '/silent'; DownloadAvailable = $true },
    @{ Name = 'Razer Synapse'; CheckPath = "$env:ProgramFiles\Razer\RazerAppEngine\RazerAppEngine.exe"; Type = 'EXE'; File = 'RazerSynapseInstaller.exe'; Args = ''; DownloadAvailable = $true; ManualInstall = $true },
    @{
        Name = 'NVIDIA Graphics Driver'
        Type = 'EXE'
        File = $NvidiaDriverFile
        Args = '-s -n Display.Driver'
        InstalledTest = { Test-DisplayDriverInstalled -VendorId 'VEN_10DE' -ProviderPattern 'NVIDIA' }
        HardwareTest = { Test-DisplayHardwarePresent -VendorId 'VEN_10DE' }
        SuccessExitCodes = @(0, 1, 1641, 3010)
    },
    @{
        Name = 'AMD Graphics Driver (Optional)'
        Type = 'EXE'
        File = $AmdDriverFile
        Args = $AmdDriverArgs
        InstalledTest = { Test-DisplayDriverInstalled -VendorId 'VEN_1002' -ProviderPattern 'AMD|Advanced Micro Devices' }
        HardwareTest = { Test-DisplayHardwarePresent -VendorId 'VEN_1002' }
        DefaultSelected = $false
        IncludeInSelectAll = $false
        InteractiveFallback = -not $AmdDriverIsWebBootstrapper
        ManualInstall = $AmdDriverIsWebBootstrapper
        SuccessExitCodes = @(0, 1641, 3010)
    }
)

function Get-PreflightStatus {
    param([Parameter(Mandatory = $true)][hashtable]$App)

    if (-not (Test-AppHardwarePresent -App $App)) {
        return @{ Text = 'GPU not detected'; Color = [System.Drawing.Color]::Gray; Installed = $false; Selectable = $false }
    }

    if (Test-AppInstalled -App $App) {
        return @{ Text = 'Installed'; Color = [System.Drawing.Color]::Green; Installed = $true }
    }

    $installerPath = Join-Path $ScriptDir $App.File
    if (Test-Path -LiteralPath $installerPath) {
        if ($App.ManualInstall) {
            return @{ Text = 'Manual installation required'; Color = [System.Drawing.Color]::DarkOrange; Installed = $false }
        }
        return @{ Text = 'Installer ready'; Color = [System.Drawing.Color]::DarkGreen; Installed = $false }
    }

    if ($App.DownloadAvailable) {
        return @{ Text = 'Download required'; Color = [System.Drawing.Color]::DarkGoldenrod; Installed = $false }
    }

    return @{ Text = 'Installer missing'; Color = [System.Drawing.Color]::Red; Installed = $false }
}

function Start-InstallerProcess {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [AllowEmptyString()][string]$Arguments = ''
    )

    if ([string]::IsNullOrWhiteSpace($Arguments)) {
        return Start-Process -FilePath $FilePath -Wait -PassThru
    }
    return Start-Process -FilePath $FilePath -ArgumentList $Arguments -Wait -PassThru
}

function Invoke-Installer {
    param(
        [Parameter(Mandatory = $true)][hashtable]$App,
        [Parameter(Mandatory = $true)][string]$FilePath
    )

    switch ($App.Type) {
        'MSI' {
            $process = Start-Process -FilePath 'msiexec.exe' `
                -ArgumentList "/i `"$FilePath`" $($App.Args)" `
                -Wait -PassThru

            if ($process.ExitCode -notin @(0, 1641, 3010)) {
                throw "msiexec exited with code $($process.ExitCode)."
            }
        }
        'MSIX' {
            Add-AppxProvisionedPackage -Online -PackagePath $FilePath -SkipLicense -ErrorAction Stop | Out-Null
        }
        'EXE' {
            $process = Start-InstallerProcess -FilePath $FilePath -Arguments $App.Args
            $successExitCodes = if ($App.SuccessExitCodes) {
                @($App.SuccessExitCodes)
            }
            else {
                @(0, 1641, 3010)
            }
            $successfulExit = $process.ExitCode -in $successExitCodes
            $installed = Test-AppInstalled -App $App

            if ($App.InteractiveFallback -and (-not $successfulExit -or -not $installed)) {
                [System.Windows.Forms.MessageBox]::Show(
                    "$($App.Name) could not be confirmed after the silent attempt. Complete the installer manually, then close it to continue.",
                    'Manual installation required',
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Information
                ) | Out-Null
                $process = Start-InstallerProcess -FilePath $FilePath
                $successfulExit = $process.ExitCode -in @(0, 1641, 3010)
                $installed = Test-AppInstalled -App $App
            }

            if (-not $successfulExit) {
                throw "Installer exited with code $($process.ExitCode)."
            }
            if ($App.InteractiveFallback -and -not $installed) {
                throw "The installer closed, but $($App.Name) could not be confirmed."
            }
        }
        default {
            throw "Unsupported installer type '$($App.Type)'."
        }
    }
}

function Copy-TartarusKeybindings {
    $destination = $TartarusDestination

    if (Test-Path -LiteralPath $SourceFolder) {
        New-Item -ItemType Directory -Path $destination -Force | Out-Null
        Copy-Item -Path (Join-Path $SourceFolder '*') -Destination $destination -Recurse -Force
        return
    }

    if (Test-Path -LiteralPath $SourceZip) {
        $tempFolder = Join-Path ([IO.Path]::GetTempPath()) ("Tartarus_" + [guid]::NewGuid().ToString('N'))
        try {
            Expand-Archive -LiteralPath $SourceZip -DestinationPath $tempFolder -Force
            $nestedSource = Join-Path $tempFolder 'Tartarus_Keybindings'
            if (-not (Test-Path -LiteralPath $nestedSource)) { $nestedSource = $tempFolder }
            New-Item -ItemType Directory -Path $destination -Force | Out-Null
            Copy-Item -Path (Join-Path $nestedSource '*') -Destination $destination -Recurse -Force
        }
        finally {
            if (Test-Path -LiteralPath $tempFolder) {
                Remove-Item -LiteralPath $tempFolder -Recurse -Force
            }
        }
        return
    }

    throw 'Neither the Tartarus_Keybindings folder nor Tartarus_Keybindings.zip was found.'
}

$form = New-Object System.Windows.Forms.Form
$form.Text = 'Automated Workstation Deployment - Preflight'
$form.Size = New-Object System.Drawing.Size(720, 610)
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false

$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Text = 'Deployment Preflight'
$titleLabel.Font = New-Object System.Drawing.Font('Segoe UI', 12, [System.Drawing.FontStyle]::Bold)
$titleLabel.Size = New-Object System.Drawing.Size(650, 25)
$titleLabel.Location = New-Object System.Drawing.Point(20, 15)
$form.Controls.Add($titleLabel)

$selectAllCB = New-Object System.Windows.Forms.CheckBox
$selectAllCB.Text = 'Select All / Deselect All'
$selectAllCB.Font = New-Object System.Drawing.Font('Segoe UI', 9.5, [System.Drawing.FontStyle]::Bold)
$selectAllCB.Size = New-Object System.Drawing.Size(300, 25)
$selectAllCB.Location = New-Object System.Drawing.Point(25, 45)
$selectAllCB.Checked = $true
$form.Controls.Add($selectAllCB)

$statusHeader = New-Object System.Windows.Forms.Label
$statusHeader.Text = 'Preflight status'
$statusHeader.Font = New-Object System.Drawing.Font('Segoe UI', 9.5, [System.Drawing.FontStyle]::Bold)
$statusHeader.Size = New-Object System.Drawing.Size(300, 25)
$statusHeader.Location = New-Object System.Drawing.Point(360, 45)
$form.Controls.Add($statusHeader)

$checkBoxes = @{}
$preflightLabels = @{}
$installedApps = @{}
$selectAllEligibleApps = @{}
$yPos = 75

foreach ($app in $Apps) {
    $cb = New-Object System.Windows.Forms.CheckBox
    $preflight = Get-PreflightStatus -App $app
    $isInstalled = $preflight.Installed
    $isSelectable = $preflight.Selectable -ne $false
    $defaultSelected = if ($null -ne $app.DefaultSelected) { [bool]$app.DefaultSelected } else { $true }
    $includeInSelectAll = if ($null -ne $app.IncludeInSelectAll) { [bool]$app.IncludeInSelectAll } else { $true }
    $installedApps[$app.Name] = $isInstalled
    $selectAllEligibleApps[$app.Name] = $isSelectable -and -not $isInstalled -and $includeInSelectAll

    if ($isInstalled) {
        $cb.Text = $app.Name
        $cb.ForeColor = [System.Drawing.Color]::Gray
        $cb.Checked = $false
    }
    elseif (-not $isSelectable) {
        $cb.Text = $app.Name
        $cb.ForeColor = [System.Drawing.Color]::Gray
        $cb.Checked = $false
        $cb.Enabled = $false
    }
    else {
        $cb.Text = $app.Name
        $cb.Checked = $defaultSelected
    }

    $cb.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)
    $cb.Size = New-Object System.Drawing.Size(320, 25)
    $cb.Location = New-Object System.Drawing.Point(25, $yPos)
    $form.Controls.Add($cb)
    $checkBoxes[$app.Name] = $cb

    $preflightLabel = New-Object System.Windows.Forms.Label
    $preflightLabel.Text = $preflight.Text
    $preflightLabel.ForeColor = $preflight.Color
    $preflightLabel.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)
    $preflightLabel.Size = New-Object System.Drawing.Size(315, 25)
    $preflightLabel.Location = New-Object System.Drawing.Point(360, ($yPos + 3))
    $form.Controls.Add($preflightLabel)
    $preflightLabels[$app.Name] = $preflightLabel
    $yPos += 28
}

$copyTartarusCB = New-Object System.Windows.Forms.CheckBox
$tartarusAlreadyExists = Test-Path -LiteralPath $TartarusDestination
if ($tartarusAlreadyExists) {
    $copyTartarusCB.Text = 'Update Tartarus Keybindings in Documents (Folder Exists)'
    $copyTartarusCB.ForeColor = [System.Drawing.Color]::Gray
    $copyTartarusCB.Checked = $false
}
else {
    $copyTartarusCB.Text = 'Copy Tartarus Keybindings to Documents'
    $copyTartarusCB.Checked = $true
}
$copyTartarusCB.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)
$copyTartarusCB.Size = New-Object System.Drawing.Size(650, 25)
$copyTartarusCB.Location = New-Object System.Drawing.Point(25, $yPos)
$form.Controls.Add($copyTartarusCB)
$yPos += 28

$applyGcpwTokenCB = New-Object System.Windows.Forms.CheckBox
$applyGcpwTokenCB.Text = 'Apply GCPW enrollment token'
$applyGcpwTokenCB.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)
$applyGcpwTokenCB.Size = New-Object System.Drawing.Size(320, 25)
$applyGcpwTokenCB.Location = New-Object System.Drawing.Point(25, $yPos)

$gcpwTokenStatus = New-Object System.Windows.Forms.Label
$gcpwTokenStatus.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)
$gcpwTokenStatus.Size = New-Object System.Drawing.Size(315, 25)
$gcpwTokenStatus.Location = New-Object System.Drawing.Point(360, ($yPos + 3))

$gcpwTokenAlreadyConfigured = Test-GcpwEnrollmentTokenConfigured
$gcpwTokenFileExists = Test-Path -LiteralPath $GcpwTokenFile
if ($gcpwTokenAlreadyConfigured) {
    $applyGcpwTokenCB.Checked = $false
    $applyGcpwTokenCB.Enabled = $gcpwTokenFileExists
    $gcpwTokenStatus.Text = 'Already configured'
    $gcpwTokenStatus.ForeColor = [System.Drawing.Color]::Green
}
elseif ($gcpwTokenFileExists) {
    $applyGcpwTokenCB.Checked = $true
    $gcpwTokenStatus.Text = 'Token file ready'
    $gcpwTokenStatus.ForeColor = [System.Drawing.Color]::DarkGreen
}
else {
    $applyGcpwTokenCB.Checked = $false
    $applyGcpwTokenCB.Enabled = $false
    $gcpwTokenStatus.Text = 'Token file missing'
    $gcpwTokenStatus.ForeColor = [System.Drawing.Color]::Red
}
$form.Controls.Add($applyGcpwTokenCB)
$form.Controls.Add($gcpwTokenStatus)
$yPos += 28

$applyWallpaperCB = New-Object System.Windows.Forms.CheckBox
$applyWallpaperCB.Text = 'Apply ExRad desktop and lock/sign-in wallpaper'
$applyWallpaperCB.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)
$applyWallpaperCB.Size = New-Object System.Drawing.Size(320, 25)
$applyWallpaperCB.Location = New-Object System.Drawing.Point(25, $yPos)

$wallpaperStatus = New-Object System.Windows.Forms.Label
$wallpaperStatus.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)
$wallpaperStatus.Size = New-Object System.Drawing.Size(315, 25)
$wallpaperStatus.Location = New-Object System.Drawing.Point(360, ($yPos + 3))

$wallpaperAlreadyConfigured = Test-ExRadWallpaperConfigured
$wallpaperSourceExists = Test-Path -LiteralPath $WallpaperSource
if ($wallpaperAlreadyConfigured) {
    $applyWallpaperCB.Checked = $false
    $wallpaperStatus.Text = 'Already configured'
    $wallpaperStatus.ForeColor = [System.Drawing.Color]::Green
}
elseif ($wallpaperSourceExists) {
    $applyWallpaperCB.Checked = $true
    $wallpaperStatus.Text = 'Wallpaper ready'
    $wallpaperStatus.ForeColor = [System.Drawing.Color]::DarkGreen
}
else {
    $applyWallpaperCB.Checked = $false
    $applyWallpaperCB.Enabled = $false
    $wallpaperStatus.Text = 'Image missing'
    $wallpaperStatus.ForeColor = [System.Drawing.Color]::Red
}
$form.Controls.Add($applyWallpaperCB)
$form.Controls.Add($wallpaperStatus)
$yPos += 28

$selectAllCB.Add_CheckedChanged({
    foreach ($app in $Apps) {
        $checkBoxes[$app.Name].Checked = $selectAllCB.Checked -and $selectAllEligibleApps[$app.Name]
    }
    $copyTartarusCB.Checked = $selectAllCB.Checked -and -not $tartarusAlreadyExists
    $applyGcpwTokenCB.Checked = $selectAllCB.Checked -and `
        $gcpwTokenFileExists -and -not $gcpwTokenAlreadyConfigured
    $applyWallpaperCB.Checked = $selectAllCB.Checked -and `
        $wallpaperSourceExists -and -not $wallpaperAlreadyConfigured
})

$statusText = New-Object System.Windows.Forms.Label
$statusText.Text = 'Ready to deploy.'
$statusText.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Italic)
$statusText.Size = New-Object System.Drawing.Size(650, 45)
$statusText.Location = New-Object System.Drawing.Point(25, ($yPos + 10))
$form.Controls.Add($statusText)

$btnStart = New-Object System.Windows.Forms.Button
$btnStart.Text = 'Start Installation'
$btnStart.Font = New-Object System.Drawing.Font('Segoe UI', 9.5, [System.Drawing.FontStyle]::Bold)
$btnStart.Size = New-Object System.Drawing.Size(150, 32)
$btnStart.Location = New-Object System.Drawing.Point(525, ($yPos + 55))
$form.Controls.Add($btnStart)

$btnStart.Add_Click({
    $btnStart.Enabled = $false
    $selectAllCB.Enabled = $false
    $copyTartarusCB.Enabled = $false
    $applyGcpwTokenCB.Enabled = $false
    $applyWallpaperCB.Enabled = $false
    $failures = New-Object System.Collections.Generic.List[string]
    $restartRequired = $false

    foreach ($app in $Apps) {
        $cb = $checkBoxes[$app.Name]
        if (-not $cb.Checked) { continue }

        $filePath = Join-Path $ScriptDir $app.File
        if (-not (Test-Path -LiteralPath $filePath)) {
            $preflightLabels[$app.Name].Text = 'Installer missing'
            $preflightLabels[$app.Name].ForeColor = [System.Drawing.Color]::Red
            $failures.Add("$($app.Name): installer file not found")
            continue
        }

        $preflightLabels[$app.Name].Text = 'Installing...'
        $preflightLabels[$app.Name].ForeColor = [System.Drawing.Color]::DarkBlue
        $statusText.Text = "Installing $($app.Name)..."
        [System.Windows.Forms.Application]::DoEvents()

        try {
            Invoke-Installer -App $app -FilePath $filePath
            $preflightLabels[$app.Name].Text = "[$DoneMark Done] Installed"
            $preflightLabels[$app.Name].ForeColor = [System.Drawing.Color]::Green
        }
        catch {
            $preflightLabels[$app.Name].Text = 'Failed'
            $preflightLabels[$app.Name].ForeColor = [System.Drawing.Color]::Red
            $failures.Add("$($app.Name): $($_.Exception.Message)")
        }
        [System.Windows.Forms.Application]::DoEvents()
    }

    if ($copyTartarusCB.Checked) {
        try {
            $copyTartarusCB.Text = 'Copy Tartarus Keybindings - Copying...'
            $statusText.Text = 'Copying Tartarus keybindings...'
            [System.Windows.Forms.Application]::DoEvents()
            Copy-TartarusKeybindings
            $copyTartarusCB.Text = "Copy Tartarus Keybindings - [$DoneMark Done]"
            $copyTartarusCB.ForeColor = [System.Drawing.Color]::Green
        }
        catch {
            $copyTartarusCB.Text = 'Copy Tartarus Keybindings - Failed'
            $copyTartarusCB.ForeColor = [System.Drawing.Color]::Red
            $failures.Add("Tartarus keybindings: $($_.Exception.Message)")
        }
    }

    if ($applyGcpwTokenCB.Checked) {
        try {
            $gcpwTokenStatus.Text = 'Applying...'
            $gcpwTokenStatus.ForeColor = [System.Drawing.Color]::DarkBlue
            $statusText.Text = 'Applying GCPW enrollment token...'
            [System.Windows.Forms.Application]::DoEvents()
            Set-GcpwEnrollmentToken
            $gcpwTokenStatus.Text = "[$DoneMark Done] Restart required"
            $gcpwTokenStatus.ForeColor = [System.Drawing.Color]::Green
            $restartRequired = $true
        }
        catch {
            $gcpwTokenStatus.Text = 'Failed'
            $gcpwTokenStatus.ForeColor = [System.Drawing.Color]::Red
            $failures.Add("GCPW enrollment token: $($_.Exception.Message)")
        }
    }

    if ($applyWallpaperCB.Checked) {
        try {
            $wallpaperStatus.Text = 'Applying...'
            $wallpaperStatus.ForeColor = [System.Drawing.Color]::DarkBlue
            $statusText.Text = 'Applying ExRad wallpaper...'
            [System.Windows.Forms.Application]::DoEvents()
            Set-ExRadWallpaper
            $wallpaperStatus.Text = "[$DoneMark Done] Applied"
            $wallpaperStatus.ForeColor = [System.Drawing.Color]::Green
        }
        catch {
            $wallpaperStatus.Text = 'Failed'
            $wallpaperStatus.ForeColor = [System.Drawing.Color]::Red
            $failures.Add("ExRad wallpaper: $($_.Exception.Message)")
        }
    }

    try {
        $statusText.Text = 'Applying Chrome policies...'
        [System.Windows.Forms.Application]::DoEvents()

        $chromeRegistryPath = 'HKLM:\SOFTWARE\Policies\Google\Chrome'
        if (-not (Test-Path -LiteralPath $chromeRegistryPath)) {
            New-Item -Path $chromeRegistryPath -Force | Out-Null
        }
        New-ItemProperty -Path $chromeRegistryPath -Name 'BookmarkBarEnabled' -Value 1 -PropertyType DWord -Force | Out-Null

        $bookmarks = @(
            @{ name = 'RamSoft Login'; url = 'https://expertradiology.ramsoftpacs.com/powerreader/Login.aspx' },
            @{ name = 'Login (Zetta Health)'; url = 'https://portal.zettahealth.co/' },
            @{ name = 'Gmail'; url = 'https://gmail.com' }
        ) | ConvertTo-Json -Compress
        New-ItemProperty -Path $chromeRegistryPath -Name 'ManagedBookmarks' -Value $bookmarks -PropertyType String -Force | Out-Null
    }
    catch {
        $failures.Add("Chrome policies: $($_.Exception.Message)")
    }

    if ($failures.Count -eq 0) {
        $completionMessage = 'Installation completed successfully.'
        if ($restartRequired) {
            $statusText.Text = 'Deployment complete - restart required.'
            $completionMessage += [Environment]::NewLine + [Environment]::NewLine +
                'Restart Windows before the first GCPW sign-in.'
        }
        else {
            $statusText.Text = 'Deployment complete.'
        }
        [System.Windows.Forms.MessageBox]::Show(
            $completionMessage, 'Done',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
        $form.Close()
    }
    else {
        $statusText.Text = "Deployment finished with $($failures.Count) error(s)."
        $failureMessage = $failures -join [Environment]::NewLine
        if ($restartRequired) {
            $failureMessage += [Environment]::NewLine + [Environment]::NewLine +
                'The GCPW token was applied. Restart Windows before the first GCPW sign-in.'
        }
        [System.Windows.Forms.MessageBox]::Show(
            $failureMessage, 'Deployment errors',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
        $btnStart.Enabled = $true
        $copyTartarusCB.Enabled = $true
        $applyGcpwTokenCB.Enabled = $gcpwTokenFileExists -and -not $gcpwTokenAlreadyConfigured
        $applyWallpaperCB.Enabled = $wallpaperSourceExists -and -not $wallpaperAlreadyConfigured
    }
})

[void]$form.ShowDialog()
