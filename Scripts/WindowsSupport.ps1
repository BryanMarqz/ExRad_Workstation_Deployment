$WindowsSupportRegistryPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation'
$ExRadSupportProvider = 'support@expertradiology.com | expertradiology.com'
$ExRadSupportUrl = 'https://expertradiology.com'

function Test-ExRadWindowsSupportConfigured {
    try {
        $support = Get-ItemProperty -LiteralPath $WindowsSupportRegistryPath -ErrorAction Stop
        return $support.Manufacturer -eq 'Expert Radiology' -and
            $support.SupportProvider -eq $ExRadSupportProvider -and
            $support.SupportURL -eq $ExRadSupportUrl
    }
    catch { return $false }
}

function Set-ExRadWindowsSupport {
    if (-not (Test-Path -LiteralPath $WindowsSupportRegistryPath)) {
        New-Item -Path $WindowsSupportRegistryPath -Force | Out-Null
    }
    New-ItemProperty -LiteralPath $WindowsSupportRegistryPath -Name 'Manufacturer' `
        -Value 'Expert Radiology' -PropertyType String -Force | Out-Null
    New-ItemProperty -LiteralPath $WindowsSupportRegistryPath -Name 'SupportProvider' `
        -Value $ExRadSupportProvider -PropertyType String -Force | Out-Null
    New-ItemProperty -LiteralPath $WindowsSupportRegistryPath -Name 'SupportURL' `
        -Value $ExRadSupportUrl -PropertyType String -Force | Out-Null

    if (-not (Test-ExRadWindowsSupportConfigured)) {
        throw 'Windows support information could not be verified after writing it.'
    }
}
