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
    @{ Name = 'Microsoft Word (M365)'; CheckPath = "$env:ProgramFiles\Microsoft Office\root\Office16\WINWORD.EXE"; Type = 'EXE'; File = 'OfficeSetup.exe'; Args = "/configure `"$M365ConfigurationFile`""; DownloadAvailable = $true },
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
