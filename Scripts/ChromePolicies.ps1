function Set-ExRadChromePolicies {
    $chromeRegistryPath = 'HKLM:\SOFTWARE\Policies\Google\Chrome'
    if (-not (Test-Path -LiteralPath $chromeRegistryPath)) {
        New-Item -Path $chromeRegistryPath -Force | Out-Null
    }
    New-ItemProperty -Path $chromeRegistryPath -Name 'BookmarkBarEnabled' `
        -Value 1 -PropertyType DWord -Force | Out-Null

    $bookmarks = @(
        @{ name = 'RamSoft Login'; url = 'https://expertradiology.ramsoftpacs.com/powerreader/Login.aspx' },
        @{ name = 'Login (Zetta Health)'; url = 'https://portal.zettahealth.co/' },
        @{ name = 'Gmail'; url = 'https://gmail.com' }
    ) | ConvertTo-Json -Compress
    New-ItemProperty -Path $chromeRegistryPath -Name 'ManagedBookmarks' `
        -Value $bookmarks -PropertyType String -Force | Out-Null
}
