function Get-FirstFileName {
    param(
        [Parameter(Mandatory = $true)][string]$Filter,
        [Parameter(Mandatory = $true)][string]$Fallback
    )

    foreach ($searchRoot in $InstallerSearchRoots) {
        if (-not (Test-Path -LiteralPath $searchRoot)) { continue }
        $match = Get-ChildItem -LiteralPath $searchRoot -Filter $Filter -File |
            Sort-Object Name |
            Select-Object -First 1
        if ($null -ne $match) { return $match.Name }
    }

    return $Fallback
}

function Get-FirstFileNameFromFilters {
    param(
        [Parameter(Mandatory = $true)][string[]]$Filters,
        [Parameter(Mandatory = $true)][string]$Fallback
    )

    foreach ($searchRoot in $InstallerSearchRoots) {
        if (-not (Test-Path -LiteralPath $searchRoot)) { continue }
        foreach ($filter in $Filters) {
            $match = Get-ChildItem -LiteralPath $searchRoot -Filter $filter -File |
                Sort-Object Name |
                Select-Object -First 1
            if ($null -ne $match) { return $match.Name }
        }
    }

    return $Fallback
}

function Resolve-InstallerPath {
    param([Parameter(Mandatory = $true)][string]$FileName)

    foreach ($searchRoot in $InstallerSearchRoots) {
        $candidate = Join-Path $searchRoot $FileName
        if (Test-Path -LiteralPath $candidate) { return $candidate }
    }

    return Join-Path $InstallerDir $FileName
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

function Get-PreflightStatus {
    param([Parameter(Mandatory = $true)][hashtable]$App)

    if (-not (Test-AppHardwarePresent -App $App)) {
        return @{ Text = 'GPU not detected'; Color = [System.Drawing.Color]::Gray; Installed = $false; Selectable = $false }
    }
    if (Test-AppInstalled -App $App) {
        return @{ Text = 'Installed'; Color = [System.Drawing.Color]::Green; Installed = $true }
    }

    $installerPath = Resolve-InstallerPath -FileName $App.File
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
            $successExitCodes = if ($App.SuccessExitCodes) { @($App.SuccessExitCodes) } else { @(0, 1641, 3010) }
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

            if (-not $successfulExit) { throw "Installer exited with code $($process.ExitCode)." }
            if ($App.InteractiveFallback -and -not $installed) {
                throw "The installer closed, but $($App.Name) could not be confirmed."
            }
        }
        default { throw "Unsupported installer type '$($App.Type)'." }
    }
}
