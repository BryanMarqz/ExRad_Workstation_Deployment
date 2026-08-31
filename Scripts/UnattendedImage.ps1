$UnattendTemplateFile = Join-Path $ScriptDir 'Config\Unattend-OOBE-Template.xml'
$SetupCompleteTemplateFile = Join-Path $ScriptDir 'Config\SetupComplete-Template.cmd'
$SysprepExecutable = Join-Path $env:WINDIR 'System32\Sysprep\Sysprep.exe'
$GeneratedUnattendFile = Join-Path $env:WINDIR 'Panther\ExRad-Unattend.xml'

function Test-WindowsAuditMode {
    try {
        $auditInProgress = (Get-ItemProperty -LiteralPath 'HKLM:\SYSTEM\Setup' `
            -Name 'AuditInProgress' -ErrorAction Stop).AuditInProgress
        return [int]$auditInProgress -eq 1
    }
    catch { return $false }
}

function Test-LocalUserExists {
    param([Parameter(Mandatory = $true)][string]$UserName)

    try {
        $user = [ADSI]("WinNT://$env:COMPUTERNAME/$UserName,user")
        return -not [string]::IsNullOrWhiteSpace([string]$user.Name)
    }
    catch { return $false }
}

function ConvertTo-UnattendPasswordValue {
    param([Parameter(Mandatory = $true)][string]$Password)

    # Windows SIM's hidden-password format is reversible obfuscation, not encryption.
    return [Convert]::ToBase64String(
        [Text.Encoding]::Unicode.GetBytes($Password + 'Password')
    )
}

function Show-UnattendAdminPasswordDialog {
    $dialog = New-Object System.Windows.Forms.Form
    $dialog.Text = 'Local Admin password for deployed images'
    $dialog.Size = New-Object System.Drawing.Size(470, 245)
    $dialog.StartPosition = 'CenterParent'
    $dialog.FormBorderStyle = 'FixedDialog'
    $dialog.MaximizeBox = $false
    $dialog.MinimizeBox = $false

    $warning = New-Object System.Windows.Forms.Label
    $warning.Text = 'Enter the password for the local Admin account. It is not saved in Git.'
    $warning.Size = New-Object System.Drawing.Size(420, 35)
    $warning.Location = New-Object System.Drawing.Point(20, 15)
    $dialog.Controls.Add($warning)

    $passwordLabel = New-Object System.Windows.Forms.Label
    $passwordLabel.Text = 'Password:'
    $passwordLabel.Size = New-Object System.Drawing.Size(120, 25)
    $passwordLabel.Location = New-Object System.Drawing.Point(20, 62)
    $dialog.Controls.Add($passwordLabel)

    $passwordBox = New-Object System.Windows.Forms.TextBox
    $passwordBox.UseSystemPasswordChar = $true
    $passwordBox.Size = New-Object System.Drawing.Size(285, 25)
    $passwordBox.Location = New-Object System.Drawing.Point(145, 60)
    $dialog.Controls.Add($passwordBox)

    $confirmLabel = New-Object System.Windows.Forms.Label
    $confirmLabel.Text = 'Confirm password:'
    $confirmLabel.Size = New-Object System.Drawing.Size(120, 25)
    $confirmLabel.Location = New-Object System.Drawing.Point(20, 102)
    $dialog.Controls.Add($confirmLabel)

    $confirmBox = New-Object System.Windows.Forms.TextBox
    $confirmBox.UseSystemPasswordChar = $true
    $confirmBox.Size = New-Object System.Drawing.Size(285, 25)
    $confirmBox.Location = New-Object System.Drawing.Point(145, 100)
    $dialog.Controls.Add($confirmBox)

    $validationLabel = New-Object System.Windows.Forms.Label
    $validationLabel.ForeColor = [System.Drawing.Color]::Red
    $validationLabel.Size = New-Object System.Drawing.Size(410, 25)
    $validationLabel.Location = New-Object System.Drawing.Point(20, 132)
    $dialog.Controls.Add($validationLabel)

    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Text = 'Continue'
    $okButton.Size = New-Object System.Drawing.Size(100, 30)
    $okButton.Location = New-Object System.Drawing.Point(225, 165)
    $okButton.Add_Click({
        if ($passwordBox.Text.Length -lt 12) {
            $validationLabel.Text = 'Use a password with at least 12 characters.'
            return
        }
        if ($passwordBox.Text -ne $confirmBox.Text) {
            $validationLabel.Text = 'The passwords do not match.'
            return
        }
        $dialog.Tag = $passwordBox.Text
        $dialog.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $dialog.Close()
    })
    $dialog.Controls.Add($okButton)

    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Text = 'Cancel'
    $cancelButton.Size = New-Object System.Drawing.Size(100, 30)
    $cancelButton.Location = New-Object System.Drawing.Point(330, 165)
    $cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $dialog.Controls.Add($cancelButton)

    $dialog.AcceptButton = $okButton
    $dialog.CancelButton = $cancelButton
    $result = $dialog.ShowDialog()
    $password = if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        [string]$dialog.Tag
    }
    else {
        $null
    }
    $passwordBox.Clear()
    $confirmBox.Clear()
    $dialog.Dispose()
    return $password
}

function New-ExRadUnattendFile {
    param(
        [Parameter(Mandatory = $true)][string]$Password,
        [Parameter(Mandatory = $true)][string]$DestinationPath
    )

    if (-not (Test-Path -LiteralPath $UnattendTemplateFile)) {
        throw 'Config\Unattend-OOBE-Template.xml is missing.'
    }
    $template = Get-Content -LiteralPath $UnattendTemplateFile -Raw -Encoding UTF8
    if ($template -notmatch '__ADMIN_PASSWORD_VALUE__') {
        throw 'The unattended template password placeholder is missing.'
    }
    $passwordValue = ConvertTo-UnattendPasswordValue -Password $Password
    $answerFile = $template.Replace('__ADMIN_PASSWORD_VALUE__', $passwordValue)

    $destinationFolder = Split-Path -Parent $DestinationPath
    New-Item -ItemType Directory -Path $destinationFolder -Force | Out-Null
    [IO.File]::WriteAllText(
        $DestinationPath,
        $answerFile,
        (New-Object Text.UTF8Encoding($false))
    )

    try { [xml](Get-Content -LiteralPath $DestinationPath -Raw -Encoding UTF8) | Out-Null }
    catch {
        Remove-Item -LiteralPath $DestinationPath -Force -ErrorAction SilentlyContinue
        throw 'The generated unattended answer file is not valid XML.'
    }
    return $DestinationPath
}

function Install-UnattendCleanupScript {
    if (-not (Test-Path -LiteralPath $SetupCompleteTemplateFile)) {
        throw 'Config\SetupComplete-Template.cmd is missing.'
    }
    $setupScriptsFolder = Join-Path $env:WINDIR 'Setup\Scripts'
    $setupCompletePath = Join-Path $setupScriptsFolder 'SetupComplete.cmd'
    New-Item -ItemType Directory -Path $setupScriptsFolder -Force | Out-Null
    $cleanupBlock = Get-Content -LiteralPath $SetupCompleteTemplateFile -Raw -Encoding UTF8

    if (Test-Path -LiteralPath $setupCompletePath) {
        $existing = Get-Content -LiteralPath $setupCompletePath -Raw -Encoding Default
        if ($existing -notmatch 'ExRad unattended-answer cleanup') {
            Add-Content -LiteralPath $setupCompletePath `
                -Value ([Environment]::NewLine + $cleanupBlock) -Encoding Default
        }
    }
    else {
        Set-Content -LiteralPath $setupCompletePath -Value $cleanupBlock -Encoding Default
    }
}

function Start-ExRadImageGeneralization {
    param([Parameter(Mandatory = $true)][string]$Password)

    if (-not (Test-WindowsAuditMode)) {
        throw 'Windows is not in Audit Mode. Enter Audit Mode before preparing an image.'
    }
    if (-not (Test-Path -LiteralPath $SysprepExecutable)) {
        throw 'Sysprep.exe was not found.'
    }
    if (Test-LocalUserExists -UserName 'Admin') {
        throw "A local account named 'Admin' already exists. Remove or rename it before generalizing so Windows Setup can create the deployment account cleanly."
    }
    if (-not (Test-Path -LiteralPath $M365ConfigurationFile)) {
        throw 'The Microsoft 365 configuration file is missing.'
    }

    $confirmation = [System.Windows.Forms.MessageBox]::Show(
        'This will generalize Windows, remove machine-specific information, and shut down the PC. After shutdown, capture the image while it is offline. Continue?',
        'Generalize and shut down reference image',
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    )
    if ($confirmation -ne [System.Windows.Forms.DialogResult]::Yes) {
        throw 'Image generalization was canceled.'
    }

    Install-UnattendCleanupScript
    $answerFilePath = New-ExRadUnattendFile `
        -Password $Password -DestinationPath $GeneratedUnattendFile
    $arguments = "/generalize /oobe /shutdown /unattend:`"$answerFilePath`""
    $process = Start-Process -FilePath $SysprepExecutable `
        -ArgumentList $arguments -Wait -PassThru
    if ($process.ExitCode -ne 0) {
        Remove-Item -LiteralPath $answerFilePath -Force -ErrorAction SilentlyContinue
        throw "Sysprep exited with code $($process.ExitCode)."
    }
}
