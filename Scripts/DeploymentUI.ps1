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
$selectAllEligibleApps = @{}
$appToolTip = New-Object System.Windows.Forms.ToolTip
$yPos = 75

foreach ($app in $Apps) {
    $cb = New-Object System.Windows.Forms.CheckBox
    $preflight = Get-PreflightStatus -App $app
    $isInstalled = $preflight.Installed
    $isSelectable = $preflight.Selectable -ne $false
    $defaultSelected = if ($null -ne $app.DefaultSelected) { [bool]$app.DefaultSelected } else { $true }
    $includeInSelectAll = if ($null -ne $app.IncludeInSelectAll) { [bool]$app.IncludeInSelectAll } else { $true }
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

    if (-not [string]::IsNullOrWhiteSpace([string]$app.DisplayNote)) {
        $cb.Text = "$($app.Name) ($($app.DisplayNote))"
    }
    if (-not [string]::IsNullOrWhiteSpace([string]$app.HelpText)) {
        $appToolTip.SetToolTip($cb, [string]$app.HelpText)
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
$tartarusAlreadyPrepared = Test-TartarusProfilePrepared
if ($tartarusAlreadyPrepared) {
    $copyTartarusCB.Text = 'Refresh Tartarus profile for Synapse import (Already Staged)'
    $copyTartarusCB.ForeColor = [System.Drawing.Color]::Gray
    $copyTartarusCB.Checked = $false
}
else {
    $copyTartarusCB.Text = 'Prepare Tartarus profile for Synapse import'
    $copyTartarusCB.Checked = $true
}
$copyTartarusCB.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)
$copyTartarusCB.Size = New-Object System.Drawing.Size(650, 25)
$copyTartarusCB.Location = New-Object System.Drawing.Point(25, $yPos)
$form.Controls.Add($copyTartarusCB)
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

$applyDarkModeCB = New-Object System.Windows.Forms.CheckBox
$applyDarkModeCB.Text = 'Apply Windows dark mode'
$applyDarkModeCB.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)
$applyDarkModeCB.Size = New-Object System.Drawing.Size(320, 25)
$applyDarkModeCB.Location = New-Object System.Drawing.Point(25, $yPos)

$darkModeStatus = New-Object System.Windows.Forms.Label
$darkModeStatus.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)
$darkModeStatus.Size = New-Object System.Drawing.Size(315, 25)
$darkModeStatus.Location = New-Object System.Drawing.Point(360, ($yPos + 3))

$darkModeAlreadyConfigured = Test-ExRadDarkModeConfigured
if ($darkModeAlreadyConfigured) {
    $applyDarkModeCB.Checked = $false
    $darkModeStatus.Text = 'Already configured'
    $darkModeStatus.ForeColor = [System.Drawing.Color]::Green
}
else {
    $applyDarkModeCB.Checked = $true
    $darkModeStatus.Text = 'Dark mode ready'
    $darkModeStatus.ForeColor = [System.Drawing.Color]::DarkGreen
}
$form.Controls.Add($applyDarkModeCB)
$form.Controls.Add($darkModeStatus)
$yPos += 28

$applyWindowsSupportCB = New-Object System.Windows.Forms.CheckBox
$applyWindowsSupportCB.Text = 'Apply ExRad Windows support information'
$applyWindowsSupportCB.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)
$applyWindowsSupportCB.Size = New-Object System.Drawing.Size(320, 25)
$applyWindowsSupportCB.Location = New-Object System.Drawing.Point(25, $yPos)

$windowsSupportStatus = New-Object System.Windows.Forms.Label
$windowsSupportStatus.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)
$windowsSupportStatus.Size = New-Object System.Drawing.Size(315, 25)
$windowsSupportStatus.Location = New-Object System.Drawing.Point(360, ($yPos + 3))

$windowsSupportAlreadyConfigured = Test-ExRadWindowsSupportConfigured
if ($windowsSupportAlreadyConfigured) {
    $applyWindowsSupportCB.Checked = $false
    $windowsSupportStatus.Text = 'Already configured'
    $windowsSupportStatus.ForeColor = [System.Drawing.Color]::Green
}
else {
    $applyWindowsSupportCB.Checked = $true
    $windowsSupportStatus.Text = 'Support details ready'
    $windowsSupportStatus.ForeColor = [System.Drawing.Color]::DarkGreen
}
$form.Controls.Add($applyWindowsSupportCB)
$form.Controls.Add($windowsSupportStatus)
$yPos += 28

$selectAllCB.Add_CheckedChanged({
    foreach ($app in $Apps) {
        $checkBoxes[$app.Name].Checked = $selectAllCB.Checked -and $selectAllEligibleApps[$app.Name]
    }
    $copyTartarusCB.Checked = $selectAllCB.Checked -and -not $tartarusAlreadyPrepared
    $applyWallpaperCB.Checked = $selectAllCB.Checked -and `
        $wallpaperSourceExists -and -not $wallpaperAlreadyConfigured
    $applyDarkModeCB.Checked = $selectAllCB.Checked -and `
        -not $darkModeAlreadyConfigured
    $applyWindowsSupportCB.Checked = $selectAllCB.Checked -and `
        -not $windowsSupportAlreadyConfigured
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
    $applyWallpaperCB.Enabled = $false
    $applyDarkModeCB.Enabled = $false
    $applyWindowsSupportCB.Enabled = $false
    $failures = New-Object System.Collections.Generic.List[string]

    foreach ($app in $Apps) {
        $cb = $checkBoxes[$app.Name]
        if (-not $cb.Checked) { continue }

        $filePath = Resolve-InstallerPath -FileName $app.File
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
            $copyTartarusCB.Text = 'Tartarus profile - Preparing...'
            $statusText.Text = 'Preparing Tartarus profile for Synapse...'
            [System.Windows.Forms.Application]::DoEvents()
            $tartarusResult = Copy-TartarusKeybindings
            $script:RazerProfileImportPath = $tartarusResult.ImportPath
            $copyTartarusCB.Text = "Tartarus profile - [$DoneMark Ready to import]"
            $copyTartarusCB.ForeColor = [System.Drawing.Color]::Green
        }
        catch {
            $copyTartarusCB.Text = 'Tartarus profile - Failed'
            $copyTartarusCB.ForeColor = [System.Drawing.Color]::Red
            $failures.Add("Tartarus profile: $($_.Exception.Message)")
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

    if ($applyDarkModeCB.Checked) {
        try {
            $darkModeStatus.Text = 'Applying...'
            $darkModeStatus.ForeColor = [System.Drawing.Color]::DarkBlue
            $statusText.Text = 'Applying Windows dark mode...'
            [System.Windows.Forms.Application]::DoEvents()
            Set-ExRadDarkMode
            $darkModeStatus.Text = "[$DoneMark Done] Applied"
            $darkModeStatus.ForeColor = [System.Drawing.Color]::Green
        }
        catch {
            $darkModeStatus.Text = 'Failed'
            $darkModeStatus.ForeColor = [System.Drawing.Color]::Red
            $failures.Add("Windows dark mode: $($_.Exception.Message)")
        }
    }

    if ($applyWindowsSupportCB.Checked) {
        try {
            $windowsSupportStatus.Text = 'Applying...'
            $windowsSupportStatus.ForeColor = [System.Drawing.Color]::DarkBlue
            $statusText.Text = 'Applying Windows support information...'
            [System.Windows.Forms.Application]::DoEvents()
            Set-ExRadWindowsSupport
            $windowsSupportStatus.Text = "[$DoneMark Done] Applied"
            $windowsSupportStatus.ForeColor = [System.Drawing.Color]::Green
        }
        catch {
            $windowsSupportStatus.Text = 'Failed'
            $windowsSupportStatus.ForeColor = [System.Drawing.Color]::Red
            $failures.Add("Windows support information: $($_.Exception.Message)")
        }
    }

    try {
        $statusText.Text = 'Applying Chrome policies...'
        [System.Windows.Forms.Application]::DoEvents()
        Set-ExRadChromePolicies
    }
    catch {
        $failures.Add("Chrome policies: $($_.Exception.Message)")
    }

    if ($failures.Count -eq 0) {
        $completionMessage = 'Installation completed successfully.'
        $statusText.Text = 'Deployment complete.'
        if (-not [string]::IsNullOrWhiteSpace($script:RazerProfileImportPath)) {
            $completionMessage += [Environment]::NewLine + [Environment]::NewLine +
                'Tartarus profile prepared. In Razer Synapse, choose Use without account, ' +
                'open the profile Import screen, and select:' + [Environment]::NewLine +
                $script:RazerProfileImportPath
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
        if (-not [string]::IsNullOrWhiteSpace($script:RazerProfileImportPath)) {
            $failureMessage += [Environment]::NewLine + [Environment]::NewLine +
                'The Tartarus profile is ready for manual import from:' +
                [Environment]::NewLine + $script:RazerProfileImportPath
        }
        [System.Windows.Forms.MessageBox]::Show(
            $failureMessage, 'Deployment errors',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
        $btnStart.Enabled = $true
        $copyTartarusCB.Enabled = $true
        $applyWallpaperCB.Enabled = $wallpaperSourceExists -and -not $wallpaperAlreadyConfigured
        $applyDarkModeCB.Enabled = -not $darkModeAlreadyConfigured
        $applyWindowsSupportCB.Enabled = -not $windowsSupportAlreadyConfigured
    }
})

[void]$form.ShowDialog()
