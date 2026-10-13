function Set-ExRadWindowsSupportInformation {
    $registryPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation'
    if (-not (Test-Path -LiteralPath $registryPath)) {
        New-Item -Path $registryPath -Force | Out-Null
    }

    New-ItemProperty -LiteralPath $registryPath -Name 'Manufacturer' `
        -Value 'Expert Radiology' -PropertyType String -Force | Out-Null
    New-ItemProperty -LiteralPath $registryPath -Name 'SupportPhone' `
        -Value '(415) 900-2000' -PropertyType String -Force | Out-Null
    New-ItemProperty -LiteralPath $registryPath -Name 'SupportURL' `
        -Value 'https://www.expertradiology.com/' -PropertyType String -Force | Out-Null

    $values = Get-ItemProperty -LiteralPath $registryPath -ErrorAction Stop
    $legacyProviders = @(
        'Email: support@expertradiology.com',
        'expertradiology.com',
        'support@expertradiology.com | expertradiology.com'
    )
    if ($values.SupportProvider -in $legacyProviders) {
        Remove-ItemProperty -LiteralPath $registryPath -Name 'SupportProvider' -ErrorAction Stop
    }
    $updatedValues = Get-ItemProperty -LiteralPath $registryPath -ErrorAction Stop
    if ($updatedValues.Manufacturer -ne 'Expert Radiology' -or
        $updatedValues.SupportPhone -ne '(415) 900-2000' -or
        $updatedValues.SupportURL -ne 'https://www.expertradiology.com/') {
        throw 'Windows support information could not be verified after writing it.'
    }
}
