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

# Generated NinjaOne installers contain an enrollment token. Keep them local.
$NinjaFile = Get-FirstFileName -Filter 'NinjaOne-Agent*-Auto-*.msi' -Fallback 'NinjaOne-Agent-Auto-x86-64.msi'
$SlackFile = Get-FirstFileName -Filter 'Slack*.msix*' -Fallback 'Slack.msix'

$Apps = @(
    @{ Name = 'Google Chrome'; CheckPath = "$env:ProgramFiles\Google\Chrome\Application\chrome.exe"; Type = 'MSI'; File = 'googlechromestandaloneenterprise64.msi'; Args = '/qn /norestart' },
    @{ Name = 'Microsoft Word (M365)'; CheckPath = "$env:ProgramFiles\Microsoft Office\root\Office16\WINWORD.EXE"; Type = 'EXE'; File = 'OfficeSetup.exe'; Args = "/configure `"$ScriptDir\configuration.xml`"" },
    @{ Name = 'Slack'; CheckPath = "$env:ProgramFiles\WindowsApps\*Slack*"; Type = 'MSIX'; File = $SlackFile; Args = '' },
    @{ Name = 'NinjaOne Agent'; CheckPath = "${env:ProgramFiles(x86)}\NinjaOne\NinjaRMMAgent.exe"; Type = 'MSI'; File = $NinjaFile; Args = '/qn /norestart' },
    @{ Name = 'RamSoft Client'; CheckPath = "${env:ProgramFiles(x86)}\RamSoft\Apps\rsapplauncher.exe"; Type = 'EXE'; File = 'RamSoftLauncherSetup.exe'; Args = '/S /v"/qn /norestart"'; InteractiveFallback = $true },
    @{ Name = 'AutoHotkey v2'; CheckPath = "$env:ProgramFiles\AutoHotkey\v2\AutoHotkey64.exe"; Type = 'EXE'; File = 'AutoHotkey_2.0.26_setup.exe'; Args = '/silent /Elevate' },
    @{ Name = 'GCPW (Google Credential)'; CheckPath = "$env:ProgramFiles\Google\Credential Provider"; Type = 'EXE'; File = 'gcpwstandaloneenterprise64.exe'; Args = '/silent' },
    @{ Name = 'Razer Synapse (Interactive)'; CheckPath = "$env:ProgramFiles\Razer\RazerAppEngine\RazerAppEngine.exe"; Type = 'EXE'; File = 'RazerSynapseInstaller.exe'; Args = '' }
)

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
            $successfulExit = $process.ExitCode -in @(0, 1641, 3010)
            $installed = Test-Path -Path $App.CheckPath

            if ($App.InteractiveFallback -and (-not $successfulExit -or -not $installed)) {
                [System.Windows.Forms.MessageBox]::Show(
                    "$($App.Name) could not be confirmed after the silent attempt. Complete the installer manually, then close it to continue.",
                    'Manual installation required',
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Information
                ) | Out-Null
                $process = Start-InstallerProcess -FilePath $FilePath
                $successfulExit = $process.ExitCode -in @(0, 1641, 3010)
                $installed = Test-Path -Path $App.CheckPath
            }

            if (-not $successfulExit) {
                throw "Installer exited with code $($process.ExitCode)."
            }
            if ($App.InteractiveFallback -and -not $installed) {
                throw 'The installer closed, but the RamSoft application was not found.'
            }
        }
        default {
            throw "Unsupported installer type '$($App.Type)'."
        }
    }
}

function Copy-TartarusKeybindings {
    $destination = $TartarusDestination

    if (Test-Path -LiteralPath $destination) { return }

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
$form.Text = 'Automated Workstation Deployment'
$form.Size = New-Object System.Drawing.Size(520, 520)
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false

$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Text = 'Select Software to Install'
$titleLabel.Font = New-Object System.Drawing.Font('Segoe UI', 12, [System.Drawing.FontStyle]::Bold)
$titleLabel.Size = New-Object System.Drawing.Size(450, 25)
$titleLabel.Location = New-Object System.Drawing.Point(20, 15)
$form.Controls.Add($titleLabel)

$selectAllCB = New-Object System.Windows.Forms.CheckBox
$selectAllCB.Text = 'Select All / Deselect All'
$selectAllCB.Font = New-Object System.Drawing.Font('Segoe UI', 9.5, [System.Drawing.FontStyle]::Bold)
$selectAllCB.Size = New-Object System.Drawing.Size(430, 25)
$selectAllCB.Location = New-Object System.Drawing.Point(25, 45)
$selectAllCB.Checked = $true
$form.Controls.Add($selectAllCB)

$checkBoxes = @{}
$installedApps = @{}
$yPos = 75

foreach ($app in $Apps) {
    $cb = New-Object System.Windows.Forms.CheckBox
    $isInstalled = Test-Path -Path $app.CheckPath
    $installedApps[$app.Name] = $isInstalled

    if ($isInstalled) {
        $cb.Text = "$($app.Name) (Already Installed)"
        $cb.ForeColor = [System.Drawing.Color]::Gray
        $cb.Checked = $false
    }
    else {
        $cb.Text = $app.Name
        $cb.Checked = $true
    }

    $cb.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)
    $cb.Size = New-Object System.Drawing.Size(450, 25)
    $cb.Location = New-Object System.Drawing.Point(25, $yPos)
    $form.Controls.Add($cb)
    $checkBoxes[$app.Name] = $cb
    $yPos += 28
}

$copyTartarusCB = New-Object System.Windows.Forms.CheckBox
$tartarusAlreadyExists = Test-Path -LiteralPath $TartarusDestination
if ($tartarusAlreadyExists) {
    $copyTartarusCB.Text = 'Copy Tartarus Keybindings to Documents (Already Exists)'
    $copyTartarusCB.ForeColor = [System.Drawing.Color]::Gray
    $copyTartarusCB.Checked = $false
}
else {
    $copyTartarusCB.Text = 'Copy Tartarus Keybindings to Documents'
    $copyTartarusCB.Checked = $true
}
$copyTartarusCB.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)
$copyTartarusCB.Size = New-Object System.Drawing.Size(450, 25)
$copyTartarusCB.Location = New-Object System.Drawing.Point(25, $yPos)
$form.Controls.Add($copyTartarusCB)
$yPos += 28

$selectAllCB.Add_CheckedChanged({
    foreach ($app in $Apps) {
        $checkBoxes[$app.Name].Checked = $selectAllCB.Checked -and -not $installedApps[$app.Name]
    }
    $copyTartarusCB.Checked = $selectAllCB.Checked -and -not $tartarusAlreadyExists
})

$statusText = New-Object System.Windows.Forms.Label
$statusText.Text = 'Ready to deploy.'
$statusText.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Italic)
$statusText.Size = New-Object System.Drawing.Size(460, 45)
$statusText.Location = New-Object System.Drawing.Point(25, ($yPos + 10))
$form.Controls.Add($statusText)

$btnStart = New-Object System.Windows.Forms.Button
$btnStart.Text = 'Start Installation'
$btnStart.Font = New-Object System.Drawing.Font('Segoe UI', 9.5, [System.Drawing.FontStyle]::Bold)
$btnStart.Size = New-Object System.Drawing.Size(150, 32)
$btnStart.Location = New-Object System.Drawing.Point(320, ($yPos + 55))
$form.Controls.Add($btnStart)

$btnStart.Add_Click({
    $btnStart.Enabled = $false
    $selectAllCB.Enabled = $false
    $copyTartarusCB.Enabled = $false
    $failures = New-Object System.Collections.Generic.List[string]

    foreach ($app in $Apps) {
        $cb = $checkBoxes[$app.Name]
        if (-not $cb.Checked) { continue }

        $filePath = Join-Path $ScriptDir $app.File
        if (-not (Test-Path -LiteralPath $filePath)) {
            $cb.Text = "$($app.Name) - File missing"
            $cb.ForeColor = [System.Drawing.Color]::Red
            $failures.Add("$($app.Name): installer file not found")
            continue
        }

        $cb.Text = "$($app.Name) - Installing..."
        $cb.ForeColor = [System.Drawing.Color]::DarkBlue
        $statusText.Text = "Installing $($app.Name)..."
        [System.Windows.Forms.Application]::DoEvents()

        try {
            Invoke-Installer -App $app -FilePath $filePath
            $cb.Text = "$($app.Name) - [$DoneMark Done]"
            $cb.ForeColor = [System.Drawing.Color]::Green
        }
        catch {
            $cb.Text = "$($app.Name) - Failed"
            $cb.ForeColor = [System.Drawing.Color]::Red
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
        $statusText.Text = 'Deployment complete.'
        [System.Windows.Forms.MessageBox]::Show(
            'Installation completed successfully.', 'Done',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
        $form.Close()
    }
    else {
        $statusText.Text = "Deployment finished with $($failures.Count) error(s)."
        [System.Windows.Forms.MessageBox]::Show(
            ($failures -join [Environment]::NewLine), 'Deployment errors',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
        $btnStart.Enabled = $true
        $copyTartarusCB.Enabled = $true
    }
})

[void]$form.ShowDialog()
