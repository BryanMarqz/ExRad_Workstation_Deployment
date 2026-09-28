function Remove-LegacyExRadWindowsSupport {
    $registryPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation'
    if (-not (Test-Path -LiteralPath $registryPath)) { return }

    $values = Get-ItemProperty -LiteralPath $registryPath -ErrorAction Stop
    if ($values.Manufacturer -eq 'Expert Radiology') {
        Remove-ItemProperty -LiteralPath $registryPath -Name 'Manufacturer' -ErrorAction Stop
    }

    $legacyProviders = @(
        'Email: support@expertradiology.com',
        'expertradiology.com',
        'support@expertradiology.com | expertradiology.com'
    )
    if ($values.SupportProvider -in $legacyProviders) {
        Remove-ItemProperty -LiteralPath $registryPath -Name 'SupportProvider' -ErrorAction Stop
    }
    if ($values.SupportURL -eq 'https://expertradiology.com') {
        Remove-ItemProperty -LiteralPath $registryPath -Name 'SupportURL' -ErrorAction Stop
    }
}
