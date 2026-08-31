function Test-GcpwEnrollmentTokenConfigured {
    try {
        $configuredToken = (Get-ItemProperty -LiteralPath $GcpwCloudManagementPath `
            -Name 'EnrollmentToken' -ErrorAction Stop).EnrollmentToken
        return -not [string]::IsNullOrWhiteSpace($configuredToken)
    }
    catch { return $false }
}

function Get-GcpwEnrollmentTokenFromFile {
    if (-not (Test-Path -LiteralPath $GcpwTokenFile)) {
        throw 'set_gcpw_token.reg was not found in Private or beside setup.ps1.'
    }

    $raw = Get-Content -LiteralPath $GcpwTokenFile -Raw -Encoding Unicode
    if ($raw -notmatch 'Windows Registry Editor Version 5\.00') {
        $raw = Get-Content -LiteralPath $GcpwTokenFile -Raw -Encoding UTF8
    }
    $sections = [regex]::Matches($raw, '(?m)^\s*\[[^\]]+\]\s*$')
    if ($sections.Count -ne 1 -or
        $sections[0].Value -notmatch '^\s*\[HKEY_LOCAL_MACHINE\\SOFTWARE\\Policies\\Google\\CloudManagement\]\s*$') {
        throw 'The registry file must contain only the approved GCPW CloudManagement key.'
    }
    $assignments = [regex]::Matches($raw, '(?m)^\s*(?:@|"[^"]+")\s*=.*$')
    if ($assignments.Count -ne 1 -or $assignments[0].Value -notmatch '^\s*"EnrollmentToken"\s*=') {
        throw 'The registry file must contain only one EnrollmentToken value.'
    }
    $tokenMatch = [regex]::Match($raw, '(?m)^\s*"EnrollmentToken"\s*=\s*"(?<Token>[^"\r\n]+)"\s*$')
    if (-not $tokenMatch.Success -or [string]::IsNullOrWhiteSpace($tokenMatch.Groups['Token'].Value)) {
        throw 'A valid GCPW EnrollmentToken value was not found.'
    }
    return $tokenMatch.Groups['Token'].Value
}

function Set-GcpwEnrollmentToken {
    $token = Get-GcpwEnrollmentTokenFromFile
    if (-not (Test-Path -LiteralPath $GcpwCloudManagementPath)) {
        New-Item -Path $GcpwCloudManagementPath -Force | Out-Null
    }
    New-ItemProperty -LiteralPath $GcpwCloudManagementPath -Name 'EnrollmentToken' `
        -Value $token -PropertyType String -Force | Out-Null
    $storedToken = (Get-ItemProperty -LiteralPath $GcpwCloudManagementPath `
        -Name 'EnrollmentToken' -ErrorAction Stop).EnrollmentToken
    if ($storedToken -ne $token) {
        throw 'The GCPW enrollment token could not be verified after writing it.'
    }
}
