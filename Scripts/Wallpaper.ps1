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
    catch { return $false }
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

    if (-not (Test-Path -LiteralPath $WindowsPersonalizationPolicyPath)) {
        New-Item -Path $WindowsPersonalizationPolicyPath -Force | Out-Null
    }
    New-ItemProperty -LiteralPath $WindowsPersonalizationPolicyPath -Name 'LockScreenImage' `
        -Value $WallpaperDestination -PropertyType String -Force | Out-Null

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
