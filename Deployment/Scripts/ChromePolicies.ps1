function Set-ExRadChromePolicies {
    $chromeRegistryPath = 'HKLM:\SOFTWARE\Policies\Google\Chrome'
    if (-not (Test-Path -LiteralPath $chromeRegistryPath)) {
        New-Item -Path $chromeRegistryPath -Force | Out-Null
    }
    New-ItemProperty -Path $chromeRegistryPath -Name 'BookmarkBarEnabled' `
        -Value 1 -PropertyType DWord -Force | Out-Null

    $bookmarks = @(
        @{ name = 'RamSoft Login'; url = 'https://expertradiology.ramsoftpacs.com/powerreader/Login.aspx' },
        @{ name = 'RADAware'; url = 'https://portal.zettahealth.co/' },
        @{ name = 'RADWorx'; url = 'https://portal.zettahealth.co/radworx/Page/Home' },
        @{ name = 'Gmail'; url = 'https://gmail.com' },
        @{ name = 'Ramsoft Templates'; url = 'https://www.dropbox.com/home/Team/Radiology/2nd%20Radiology/Templates%20Reviewed%20by%20AK/Ramsoft%20Templates' },
        @{ name = 'Blurps'; url = 'https://app.notion.com/p/Find-and-copy-blurbs-searchable-library-40cdd5e7ae8981d1af22c745e2fae185' }
    ) | ConvertTo-Json -Compress
    New-ItemProperty -Path $chromeRegistryPath -Name 'ManagedBookmarks' `
        -Value $bookmarks -PropertyType String -Force | Out-Null
}
