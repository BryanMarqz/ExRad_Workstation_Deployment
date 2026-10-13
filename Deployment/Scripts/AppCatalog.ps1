# Generated NinjaOne installers contain an enrollment token. Keep them local.
$NinjaFile = Get-FirstFileNameFromFilters -Filters @('installer.msi', 'NinjaOne*.msi') -Fallback 'installer.msi'
$SlackFile = Get-FirstFileName -Filter 'Slack*.msix*' -Fallback 'Slack.msix'
$AutoHotkeyFile = Get-NewestVersionedFileName `
    -Filter 'AutoHotkey_*_setup.exe' `
    -VersionPattern '^AutoHotkey_(?<Version>2(?:\.\d+)+)_setup\.exe$' `
    -Fallback 'AutoHotkey_2_setup.exe'

$Apps = @(
    @{ Name = 'Google Chrome'; CheckPath = "$env:ProgramFiles\Google\Chrome\Application\chrome.exe"; Type = 'MSI'; File = 'googlechromestandaloneenterprise64.msi'; Args = '/qn /norestart'; DownloadAvailable = $true },
    @{ Name = 'Microsoft Word (M365)'; CheckPath = "$env:ProgramFiles\Microsoft Office\root\Office16\WINWORD.EXE"; Type = 'EXE'; File = 'OfficeSetup.exe'; Args = "/configure `"$M365ConfigurationFile`""; DownloadAvailable = $true },
    @{ Name = 'Slack'; CheckPath = "$env:ProgramFiles\WindowsApps\*Slack*"; Type = 'MSIX'; File = $SlackFile; Args = ''; DownloadAvailable = $true },
    @{
        Name = 'NinjaOne Agent'
        CheckPath = "${env:ProgramFiles(x86)}\NinjaOne\NinjaRMMAgent.exe"
        Type = 'MSI'
        File = $NinjaFile
        Args = '/qn /norestart'
        DownloadAvailable = $false
    },
    @{ Name = 'RamSoft Client'; CheckPath = "${env:ProgramFiles(x86)}\RamSoft\Apps\rsapplauncher.exe"; Type = 'EXE'; File = 'RamSoftLauncherSetup.exe'; Args = '/S /v"/qn /norestart"'; InteractiveFallback = $true; ManualInstall = $true },
    @{
        Name = 'AutoHotkey v2'
        Type = 'EXE'
        File = $AutoHotkeyFile
        Args = '/silent /Elevate'
        DownloadAvailable = $true
        InstalledTest = { Test-AutoHotkeyV2Installed }
    },
    @{ Name = 'Razer Synapse'; CheckPath = "$env:ProgramFiles\Razer\RazerAppEngine\RazerAppEngine.exe"; Type = 'EXE'; File = 'RazerSynapseInstaller.exe'; Args = ''; DownloadAvailable = $true; ManualInstall = $true }
)
