function Convert-RazerProfileForUser {
    param(
        [Parameter(Mandatory = $true)][string]$ProfileFilePath,
        [Parameter(Mandatory = $true)][string]$TargetAhkDirectory
    )

    $outerProfile = Get-Content -LiteralPath $ProfileFilePath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($null -eq $outerProfile.productId -or @($outerProfile.profiles).Count -eq 0) {
        throw 'The Synapse profile does not contain a productId and at least one profile.'
    }

    $wasUpdated = $false
    foreach ($profile in @($outerProfile.profiles)) {
        try {
            $payloadBytes = [Convert]::FromBase64String([string]$profile.payload)
            $payloadJson = [Text.Encoding]::UTF8.GetString($payloadBytes)
        }
        catch {
            throw "The payload for Synapse profile '$($profile.name)' is not valid base64."
        }

        $originalPayloadJson = $payloadJson
        $ahkPathPattern = '[A-Za-z]:\\\\[^"\r\n]*?\\\\(?<FileName>[^"\\]+\.ahk)'
        $payloadJson = [regex]::Replace(
            $payloadJson,
            $ahkPathPattern,
            {
                param($match)
                $targetPath = Join-Path $TargetAhkDirectory $match.Groups['FileName'].Value
                return $targetPath.Replace('\', '\\')
            },
            [Text.RegularExpressions.RegexOptions]::IgnoreCase
        )
        $profileWasUpdated = $payloadJson -cne $originalPayloadJson
        if ($profileWasUpdated) {
            $wasUpdated = $true
        }

        if ($profileWasUpdated) {
            $newPayload = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($payloadJson))
            $md5 = [Security.Cryptography.MD5]::Create()
            try {
                $hashBytes = $md5.ComputeHash([Text.Encoding]::UTF8.GetBytes($newPayload))
                $newHash = ($hashBytes | ForEach-Object { $_.ToString('x2') }) -join ''
            }
            finally { $md5.Dispose() }
            $profile.payload = $newPayload
            $profile.hash = $newHash
        }
    }

    return [pscustomobject]@{
        Content = $outerProfile | ConvertTo-Json -Depth 100
        ProductId = [string]$outerProfile.productId
        WasUpdated = $wasUpdated
    }
}

function Get-RazerProfileImportDirectory {
    param([Parameter(Mandatory = $true)][string]$ProductId)

    $synapse4Base = Join-Path $env:LOCALAPPDATA 'Razer\Synapse4'
    $synapse3Base = Join-Path $env:LOCALAPPDATA 'Razer\Synapse3'
    if (Test-Path -LiteralPath $synapse4Base) {
        return Join-Path $synapse4Base "ProductProfiles\$ProductId"
    }
    if (Test-Path -LiteralPath $synapse3Base) {
        return Join-Path $synapse3Base 'Profiles'
    }
    return Join-Path $synapse4Base "ProductProfiles\$ProductId"
}

function Test-TartarusProfilePrepared {
    if (-not (Test-Path -LiteralPath $SourceFolder)) { return $false }

    try {
        $profileFile = Get-ChildItem -LiteralPath $SourceFolder -Filter '*.synapse4' -File |
            Sort-Object Name | Select-Object -First 1
        if ($null -eq $profileFile) { return $false }
        $outerProfile = Get-Content -LiteralPath $profileFile.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
        $importDirectory = Get-RazerProfileImportDirectory -ProductId ([string]$outerProfile.productId)
        return Test-Path -LiteralPath (Join-Path $importDirectory $profileFile.Name)
    }
    catch { return $false }
}

function Install-TartarusProfileFromFolder {
    param([Parameter(Mandatory = $true)][string]$ProfileSourceFolder)

    $profileFile = Get-ChildItem -LiteralPath $ProfileSourceFolder -Filter '*.synapse4' -File |
        Sort-Object Name | Select-Object -First 1
    if ($null -eq $profileFile) {
        throw 'No .synapse4 profile was found in the Tartarus source folder.'
    }

    $preparedProfile = Convert-RazerProfileForUser `
        -ProfileFilePath $profileFile.FullName -TargetAhkDirectory $TartarusDestination
    $utf8WithoutBom = New-Object Text.UTF8Encoding($false)

    New-Item -ItemType Directory -Path $TartarusDestination -Force | Out-Null
    Copy-Item -Path (Join-Path $ProfileSourceFolder '*') `
        -Destination $TartarusDestination -Recurse -Force
    $technicianProfilePath = Join-Path $TartarusDestination $profileFile.Name
    [IO.File]::WriteAllText($technicianProfilePath, [string]$preparedProfile.Content, $utf8WithoutBom)

    $synapseImportDirectory = Get-RazerProfileImportDirectory -ProductId $preparedProfile.ProductId
    New-Item -ItemType Directory -Path $synapseImportDirectory -Force | Out-Null
    $synapseProfilePath = Join-Path $synapseImportDirectory $profileFile.Name
    [IO.File]::WriteAllText($synapseProfilePath, [string]$preparedProfile.Content, $utf8WithoutBom)

    return [pscustomobject]@{
        ImportPath = $synapseProfilePath
        TechnicianCopy = $technicianProfilePath
        UsernamePatched = [bool]$preparedProfile.WasUpdated
    }
}

function Copy-TartarusKeybindings {
    if (Test-Path -LiteralPath $SourceFolder) {
        return Install-TartarusProfileFromFolder -ProfileSourceFolder $SourceFolder
    }
    if (Test-Path -LiteralPath $SourceZip) {
        $tempFolder = Join-Path ([IO.Path]::GetTempPath()) ('Tartarus_' + [guid]::NewGuid().ToString('N'))
        try {
            Expand-Archive -LiteralPath $SourceZip -DestinationPath $tempFolder -Force
            $nestedSource = Join-Path $tempFolder 'Tartarus_Keybindings'
            if (-not (Test-Path -LiteralPath $nestedSource)) { $nestedSource = $tempFolder }
            return Install-TartarusProfileFromFolder -ProfileSourceFolder $nestedSource
        }
        finally {
            if (Test-Path -LiteralPath $tempFolder) {
                Remove-Item -LiteralPath $tempFolder -Recurse -Force
            }
        }
    }
    throw 'Neither the Tartarus_Keybindings folder nor Tartarus_Keybindings.zip was found.'
}
