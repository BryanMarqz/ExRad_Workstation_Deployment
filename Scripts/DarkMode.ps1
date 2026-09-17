$DarkModePersonalizeSubKey = 'Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
$DarkModeMarkerPath = 'HKLM:\SOFTWARE\ExpertRadiology\Deployment'

function Set-DarkModeRegistryValues {
    param([Parameter(Mandatory = $true)][string]$RegistryPath)

    if (-not (Test-Path -LiteralPath $RegistryPath)) {
        New-Item -Path $RegistryPath -Force | Out-Null
    }
    New-ItemProperty -LiteralPath $RegistryPath -Name 'AppsUseLightTheme' `
        -Value 0 -PropertyType DWord -Force | Out-Null
    New-ItemProperty -LiteralPath $RegistryPath -Name 'SystemUsesLightTheme' `
        -Value 0 -PropertyType DWord -Force | Out-Null
}

function Test-ExRadDarkModeConfigured {
    try {
        $personalize = Get-ItemProperty `
            -LiteralPath "HKCU:\$DarkModePersonalizeSubKey" -ErrorAction Stop
        $marker = Get-ItemProperty -LiteralPath $DarkModeMarkerPath `
            -Name 'DarkModeDefaultConfigured' -ErrorAction Stop
        return [int]$personalize.AppsUseLightTheme -eq 0 -and
            [int]$personalize.SystemUsesLightTheme -eq 0 -and
            [int]$marker.DarkModeDefaultConfigured -eq 1
    }
    catch { return $false }
}

function Set-ExRadDarkMode {
    Set-DarkModeRegistryValues -RegistryPath "HKCU:\$DarkModePersonalizeSubKey"

    $defaultUserHive = Join-Path $env:SystemDrive 'Users\Default\NTUSER.DAT'
    if (-not (Test-Path -LiteralPath $defaultUserHive)) {
        throw 'The Default User registry profile was not found.'
    }

    $defaultUserHiveName = 'ExRadDarkModeDefaultUser'
    & reg.exe load "HKU\$defaultUserHiveName" $defaultUserHive | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw 'Windows could not load the Default User profile to configure dark mode.'
    }
    try {
        Set-DarkModeRegistryValues -RegistryPath `
            "Registry::HKEY_USERS\$defaultUserHiveName\$DarkModePersonalizeSubKey"
    }
    finally {
        [GC]::Collect()
        [GC]::WaitForPendingFinalizers()
        & reg.exe unload "HKU\$defaultUserHiveName" | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw 'The Default User registry profile could not be unloaded.'
        }
    }

    if (-not (Test-Path -LiteralPath $DarkModeMarkerPath)) {
        New-Item -Path $DarkModeMarkerPath -Force | Out-Null
    }
    New-ItemProperty -LiteralPath $DarkModeMarkerPath `
        -Name 'DarkModeDefaultConfigured' -Value 1 -PropertyType DWord -Force | Out-Null

    if (-not ('ExRadDarkMode.NativeMethods' -as [type])) {
        Add-Type -TypeDefinition @'
namespace ExRadDarkMode {
    using System;
    using System.Runtime.InteropServices;
    public static class NativeMethods {
        [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        public static extern IntPtr SendMessageTimeout(
            IntPtr window, uint message, UIntPtr wParam, string lParam,
            uint flags, uint timeout, out UIntPtr result);
    }
}
'@
    }
    $broadcastResult = [UIntPtr]::Zero
    [void][ExRadDarkMode.NativeMethods]::SendMessageTimeout(
        [IntPtr]0xffff, 0x001A, [UIntPtr]::Zero, 'ImmersiveColorSet',
        0x0002, 1000, [ref]$broadcastResult
    )

    if (-not (Test-ExRadDarkModeConfigured)) {
        throw 'Windows dark mode could not be verified after it was applied.'
    }
}
