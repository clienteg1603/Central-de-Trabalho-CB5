Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$script:CentralUpdateAppId = "central-de-trabalho"
$script:CentralUpdaterVersion = "1.0.0"
$script:CentralUpdateSchemaVersion = 1
$script:CentralUpdateStateDirectoryOverride = ""
$script:CentralUpdateApplicationDataRootOverride = ""

function ConvertTo-UpdateText {
    param([object]$Value)
    if ($null -eq $Value) { return "" }
    return ([string]$Value).Trim()
}

function ConvertTo-UpdateVersion {
    param([Parameter(Mandatory = $true)][string]$Value)

    $normalized = $Value.Trim()
    if ($normalized.StartsWith("v", [StringComparison]::OrdinalIgnoreCase)) {
        $normalized = $normalized.Substring(1)
    }
    $version = $null
    if (-not [Version]::TryParse($normalized, [ref]$version)) {
        throw "Versão inválida: $Value"
    }
    return $version
}

function Test-NewerUpdateVersion {
    param(
        [Parameter(Mandatory = $true)][string]$CurrentVersion,
        [Parameter(Mandatory = $true)][string]$AvailableVersion
    )

    $current = ConvertTo-UpdateVersion $CurrentVersion
    $available = ConvertTo-UpdateVersion $AvailableVersion
    return $available -gt $current
}

function Get-CentralUpdaterDataDirectory {
    if (-not [string]::IsNullOrWhiteSpace($script:CentralUpdateStateDirectoryOverride)) {
        return [IO.Path]::GetFullPath($script:CentralUpdateStateDirectoryOverride)
    }
    $local = [Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData)
    return [IO.Path]::Combine($local, "CentralDeTrabalhoUpdater")
}

function Get-CentralUpdateApplicationDataRoot {
    if (-not [string]::IsNullOrWhiteSpace($script:CentralUpdateApplicationDataRootOverride)) {
        return [IO.Path]::GetFullPath($script:CentralUpdateApplicationDataRootOverride)
    }
    return [Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData)
}

function Assert-CentralUpdateInstallRoot {
    param([Parameter(Mandatory = $true)][string]$InstallRoot)

    $fullPath = [IO.Path]::GetFullPath($InstallRoot).TrimEnd(
        [IO.Path]::DirectorySeparatorChar,
        [IO.Path]::AltDirectorySeparatorChar
    )
    $driveRoot = [IO.Path]::GetPathRoot($fullPath).TrimEnd(
        [IO.Path]::DirectorySeparatorChar,
        [IO.Path]::AltDirectorySeparatorChar
    )
    if ([string]::IsNullOrWhiteSpace($fullPath) -or $fullPath -eq $driveRoot) {
        throw "A pasta informada não pode ser a raiz de uma unidade."
    }

    foreach ($required in @(
        "Central de Trabalho.ps1",
        "Atualizador\Update.Core.ps1"
    )) {
        $requiredRelative = $required.Replace('\', [IO.Path]::DirectorySeparatorChar)
        $requiredPath = [IO.Path]::Combine($fullPath, $requiredRelative)
        if (-not [IO.File]::Exists($requiredPath)) {
            throw "A pasta selecionada não contém uma instalação válida da Central de Trabalho."
        }
    }
    return $fullPath
}

function Write-UpdateJsonAtomic {
    param(
        [Parameter(Mandatory = $true)][object]$Value,
        [Parameter(Mandatory = $true)][string]$Path,
        [int]$Depth = 10
    )

    $directory = [IO.Path]::GetDirectoryName($Path)
    if (-not [IO.Directory]::Exists($directory)) {
        [void][IO.Directory]::CreateDirectory($directory)
    }

    $json = $Value | ConvertTo-Json -Depth $Depth
    $tempPath = $Path + ".tmp"
    $recoveryPath = $Path + ".swap-backup"
    $encoding = [Text.UTF8Encoding]::new($true)

    try {
        [IO.File]::WriteAllText($tempPath, $json, $encoding)
        if ([IO.File]::Exists($Path)) {
            if ([IO.File]::Exists($recoveryPath)) { [IO.File]::Delete($recoveryPath) }
            [IO.File]::Replace($tempPath, $Path, $recoveryPath)
            if ([IO.File]::Exists($recoveryPath)) { [IO.File]::Delete($recoveryPath) }
        }
        else {
            [IO.File]::Move($tempPath, $Path)
        }
    }
    catch {
        if (-not [IO.File]::Exists($Path) -and [IO.File]::Exists($recoveryPath)) {
            [IO.File]::Move($recoveryPath, $Path)
        }
        if ([IO.File]::Exists($tempPath)) { [IO.File]::Delete($tempPath) }
        throw
    }
}

function Get-UpdateUserSettings {
    $stateDirectory = Get-CentralUpdaterDataDirectory
    $settingsPath = [IO.Path]::Combine($stateDirectory, "preferencias.json")
    $settings = [pscustomobject]@{
        SchemaVersion = 1
        Channel = "stable"
        StableUrl = ""
        TestUrl = ""
        LastCheck = ""
        LastBackupPath = ""
    }

    try {
        if ([IO.File]::Exists($settingsPath)) {
            $saved = [IO.File]::ReadAllText($settingsPath, [Text.Encoding]::UTF8) | ConvertFrom-Json
            foreach ($name in @("Channel", "StableUrl", "TestUrl", "LastCheck", "LastBackupPath")) {
                if ($saved.PSObject.Properties.Name -contains $name) {
                    $settings.$name = ConvertTo-UpdateText $saved.$name
                }
            }
        }
    }
    catch {}

    if (@("stable", "test") -notcontains $settings.Channel) { $settings.Channel = "stable" }
    return $settings
}

function Save-UpdateUserSettings {
    param([Parameter(Mandatory = $true)][object]$Settings)

    $path = [IO.Path]::Combine((Get-CentralUpdaterDataDirectory), "preferencias.json")
    $Settings.SchemaVersion = 1
    Write-UpdateJsonAtomic -Value $Settings -Path $path -Depth 6
}

function Get-PackagedUpdateConfiguration {
    param([Parameter(Mandatory = $true)][string]$InstallRoot)

    $path = [IO.Path]::Combine($InstallRoot, "Atualizador", "CANAIS.json")
    if (-not [IO.File]::Exists($path)) {
        return [pscustomobject]@{
            SchemaVersion = 1
            AppId = $script:CentralUpdateAppId
            DefaultChannel = "stable"
            Channels = @()
        }
    }
    $configuration = [IO.File]::ReadAllText($path, [Text.Encoding]::UTF8) | ConvertFrom-Json
    if ([int]$configuration.SchemaVersion -ne 1 -or (ConvertTo-UpdateText $configuration.AppId) -ne $script:CentralUpdateAppId) {
        throw "A configuração dos canais de atualização é inválida."
    }
    return $configuration
}

function Get-ConfiguredUpdateUrl {
    param(
        [Parameter(Mandatory = $true)][string]$InstallRoot,
        [Parameter(Mandatory = $true)][ValidateSet("stable", "test")][string]$Channel,
        [Parameter(Mandatory = $true)][object]$UserSettings
    )

    $override = if ($Channel -eq "test") {
        ConvertTo-UpdateText $UserSettings.TestUrl
    }
    else {
        ConvertTo-UpdateText $UserSettings.StableUrl
    }
    if (-not [string]::IsNullOrWhiteSpace($override)) { return $override }

    $configuration = Get-PackagedUpdateConfiguration -InstallRoot $InstallRoot
    foreach ($item in @($configuration.Channels)) {
        if ((ConvertTo-UpdateText $item.Id) -eq $Channel) {
            return ConvertTo-UpdateText $item.ManifestUrl
        }
    }
    return ""
}

function Test-SecureUpdateUri {
    param([string]$Value)

    $uri = $null
    if (-not [Uri]::TryCreate($Value, [UriKind]::Absolute, [ref]$uri)) { return $false }
    return $uri.Scheme -eq [Uri]::UriSchemeHttps
}

function Assert-RemoteUpdateManifest {
    param(
        [Parameter(Mandatory = $true)][object]$Manifest,
        [Parameter(Mandatory = $true)][ValidateSet("stable", "test")][string]$ExpectedChannel
    )

    if ($null -eq $Manifest) { throw "O manifesto de atualização está vazio." }
    if ([int]$Manifest.SchemaVersion -ne $script:CentralUpdateSchemaVersion) {
        throw "A versão do manifesto de atualização não é compatível."
    }
    if ((ConvertTo-UpdateText $Manifest.AppId) -ne $script:CentralUpdateAppId) {
        throw "O manifesto não pertence à Central de Trabalho."
    }
    if ((ConvertTo-UpdateText $Manifest.Channel) -ne $ExpectedChannel) {
        throw "O manifesto recebido pertence a outro canal de atualização."
    }

    [void](ConvertTo-UpdateVersion (ConvertTo-UpdateText $Manifest.Version))
    $minimumUpdater = ConvertTo-UpdateText $Manifest.MinimumUpdaterVersion
    if (-not [string]::IsNullOrWhiteSpace($minimumUpdater)) {
        if ((ConvertTo-UpdateVersion $minimumUpdater) -gt (ConvertTo-UpdateVersion $script:CentralUpdaterVersion)) {
            throw "Esta atualização exige um Atualizador mais recente."
        }
    }

    if (-not (Test-SecureUpdateUri (ConvertTo-UpdateText $Manifest.PackageUrl))) {
        throw "O endereço do pacote precisa usar HTTPS."
    }
    $sha256 = (ConvertTo-UpdateText $Manifest.PackageSha256).ToUpperInvariant()
    if ($sha256 -notmatch '^[A-F0-9]{64}$') {
        throw "O manifesto não possui um SHA-256 válido."
    }
    if ([long]$Manifest.PackageSize -le 0) {
        throw "O manifesto não informa um tamanho de pacote válido."
    }
    $packageRoot = ConvertTo-UpdateText $Manifest.PackageRoot
    if ([string]::IsNullOrWhiteSpace($packageRoot)) {
        throw "O manifesto não informa a pasta principal do pacote."
    }
    if ($packageRoot -in @(".", "..") -or $packageRoot.IndexOfAny([char[]]@('/', '\')) -ge 0) {
        throw "A pasta principal informada no manifesto é inválida."
    }
    return $true
}

function Test-TransientUpdateWebFailure {
    param([Parameter(Mandatory = $true)][System.Exception]$Exception)

    try {
        if ($Exception -is [Net.WebException]) {
            if ($Exception.Status -in @(
                [Net.WebExceptionStatus]::Timeout,
                [Net.WebExceptionStatus]::ConnectFailure,
                [Net.WebExceptionStatus]::ConnectionClosed,
                [Net.WebExceptionStatus]::NameResolutionFailure,
                [Net.WebExceptionStatus]::ReceiveFailure,
                [Net.WebExceptionStatus]::SendFailure
            )) { return $true }
            if ($null -ne $Exception.Response) {
                $statusCode = [int]$Exception.Response.StatusCode
                if ($statusCode -in @(408, 429, 500, 502, 503, 504)) { return $true }
            }
        }
        if ($Exception.PSObject.Properties.Name -contains "Response" -and $null -ne $Exception.Response) {
            $status = $Exception.Response.StatusCode
            if ($null -ne $status -and [int]$status -in @(408, 429, 500, 502, 503, 504)) { return $true }
        }
    }
    catch {}
    return $false
}

function Invoke-UpdateWebRequestWithRetry {
    param(
        [Parameter(Mandatory = $true)][string]$Uri,
        [Parameter(Mandatory = $true)][int]$TimeoutSec,
        [hashtable]$Headers = $null,
        [string]$OutFile = ""
    )

    $lastError = $null
    for ($attempt = 1; $attempt -le 3; $attempt++) {
        try {
            $parameters = @{
                Uri = $Uri
                UseBasicParsing = $true
                TimeoutSec = $TimeoutSec
            }
            if ($null -ne $Headers) { $parameters.Headers = $Headers }
            if (-not [string]::IsNullOrWhiteSpace($OutFile)) { $parameters.OutFile = $OutFile }
            return Invoke-WebRequest @parameters
        }
        catch {
            $lastError = $_
            if (-not [string]::IsNullOrWhiteSpace($OutFile) -and [IO.File]::Exists($OutFile)) {
                try { [IO.File]::Delete($OutFile) } catch {}
            }
            if ($attempt -ge 3 -or -not (Test-TransientUpdateWebFailure -Exception $_.Exception)) { throw }
            Start-Sleep -Seconds (2 * $attempt)
        }
    }
    if ($null -ne $lastError) { throw $lastError }
}

function Get-RemoteUpdateManifest {
    param(
        [Parameter(Mandatory = $true)][string]$ManifestUrl,
        [Parameter(Mandatory = $true)][ValidateSet("stable", "test")][string]$Channel
    )

    if (-not (Test-SecureUpdateUri $ManifestUrl)) {
        throw "O endereço do canal precisa usar HTTPS."
    }
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $response = Invoke-UpdateWebRequestWithRetry -Uri $ManifestUrl -TimeoutSec 30 -Headers @{ "Cache-Control" = "no-cache" }
    $manifest = $response.Content | ConvertFrom-Json
    [void](Assert-RemoteUpdateManifest -Manifest $manifest -ExpectedChannel $Channel)
    return $manifest
}

function Get-UpdateFileSha256 {
    param([Parameter(Mandatory = $true)][string]$Path)

    $stream = [IO.File]::OpenRead($Path)
    $algorithm = [Security.Cryptography.SHA256]::Create()
    try {
        $bytes = $algorithm.ComputeHash($stream)
        return ([BitConverter]::ToString($bytes) -replace '-', '').ToUpperInvariant()
    }
    finally {
        $algorithm.Dispose()
        $stream.Dispose()
    }
}

function Receive-UpdatePackage {
    param(
        [Parameter(Mandatory = $true)][object]$Manifest,
        [Parameter(Mandatory = $true)][string]$DestinationPath
    )

    $url = ConvertTo-UpdateText $Manifest.PackageUrl
    if (-not (Test-SecureUpdateUri $url)) { throw "O pacote precisa usar HTTPS." }
    $directory = [IO.Path]::GetDirectoryName($DestinationPath)
    if (-not [IO.Directory]::Exists($directory)) { [void][IO.Directory]::CreateDirectory($directory) }

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    [void](Invoke-UpdateWebRequestWithRetry -Uri $url -TimeoutSec 180 -OutFile $DestinationPath)

    $actualSize = (Get-Item -LiteralPath $DestinationPath).Length
    if ($actualSize -ne [long]$Manifest.PackageSize) {
        throw "O tamanho do pacote baixado não corresponde ao manifesto."
    }
    $actualHash = Get-UpdateFileSha256 -Path $DestinationPath
    if ($actualHash -ne (ConvertTo-UpdateText $Manifest.PackageSha256).ToUpperInvariant()) {
        throw "O SHA-256 do pacote baixado não corresponde ao manifesto."
    }
    return $DestinationPath
}

function Resolve-SafeUpdateChildPath {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$RelativePath
    )

    if ([IO.Path]::IsPathRooted($RelativePath)) { throw "Caminho absoluto não permitido no pacote." }
    $rootFull = [IO.Path]::GetFullPath($Root).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
    $rootPrefix = $rootFull + [IO.Path]::DirectorySeparatorChar
    $candidate = [IO.Path]::GetFullPath([IO.Path]::Combine($rootFull, $RelativePath))
    if (-not $candidate.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Caminho fora da pasta permitida: $RelativePath"
    }
    return $candidate
}

function Expand-UpdatePackageSafely {
    param(
        [Parameter(Mandatory = $true)][string]$ArchivePath,
        [Parameter(Mandatory = $true)][string]$DestinationDirectory
    )

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    if ([IO.Directory]::Exists($DestinationDirectory)) {
        [IO.Directory]::Delete($DestinationDirectory, $true)
    }
    [void][IO.Directory]::CreateDirectory($DestinationDirectory)

    $archive = [IO.Compression.ZipFile]::OpenRead($ArchivePath)
    try {
        foreach ($entry in $archive.Entries) {
            $entryPath = Resolve-SafeUpdateChildPath -Root $DestinationDirectory -RelativePath $entry.FullName
            if ([string]::IsNullOrEmpty($entry.Name)) {
                if (-not [IO.Directory]::Exists($entryPath)) { [void][IO.Directory]::CreateDirectory($entryPath) }
                continue
            }
            $parent = [IO.Path]::GetDirectoryName($entryPath)
            if (-not [IO.Directory]::Exists($parent)) { [void][IO.Directory]::CreateDirectory($parent) }
            [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $entryPath, $true)
        }
    }
    finally { $archive.Dispose() }
    return $DestinationDirectory
}

function Read-LocalPackageManifest {
    param([Parameter(Mandatory = $true)][string]$PackageRoot)

    $path = [IO.Path]::Combine($PackageRoot, "PACOTE-MANIFESTO.json")
    if (-not [IO.File]::Exists($path)) { throw "PACOTE-MANIFESTO.json não foi encontrado." }
    $manifest = [IO.File]::ReadAllText($path, [Text.Encoding]::UTF8) | ConvertFrom-Json
    if ([int]$manifest.SchemaVersion -ne 1) { throw "Manifesto interno incompatível." }
    if ((ConvertTo-UpdateText $manifest.AppId) -ne $script:CentralUpdateAppId) {
        throw "O pacote interno não pertence à Central de Trabalho."
    }
    [void](ConvertTo-UpdateVersion (ConvertTo-UpdateText $manifest.Version))
    return $manifest
}

function Test-UpdatePackagePayload {
    param(
        [Parameter(Mandatory = $true)][string]$PackageRoot,
        [string]$ExpectedVersion = "",
        [switch]$AllowExtraFiles
    )

    $manifest = Read-LocalPackageManifest -PackageRoot $PackageRoot
    if (-not [string]::IsNullOrWhiteSpace($ExpectedVersion)) {
        if ((ConvertTo-UpdateVersion (ConvertTo-UpdateText $manifest.Version)) -ne (ConvertTo-UpdateVersion $ExpectedVersion)) {
            throw "A versão do pacote interno não corresponde ao manifesto remoto."
        }
    }

    $listed = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($file in @($manifest.Files)) {
        $relative = (ConvertTo-UpdateText $file.Path).Replace('/', [IO.Path]::DirectorySeparatorChar)
        if ([string]::IsNullOrWhiteSpace($relative)) { throw "O manifesto interno contém um caminho vazio." }
        if (-not $listed.Add($relative)) { throw "Arquivo duplicado no manifesto interno: $relative" }
        $path = Resolve-SafeUpdateChildPath -Root $PackageRoot -RelativePath $relative
        if (-not [IO.File]::Exists($path)) { throw "Arquivo ausente no pacote: $relative" }
        if ((Get-Item -LiteralPath $path).Length -ne [long]$file.Size) { throw "Tamanho divergente: $relative" }
        if ((Get-UpdateFileSha256 -Path $path) -ne (ConvertTo-UpdateText $file.Sha256).ToUpperInvariant()) {
            throw "SHA-256 divergente: $relative"
        }
    }

    foreach ($requiredItem in @(
        "Central de Trabalho.exe",
        "Central de Trabalho.ps1",
        "Atualizador\Central de Trabalho Updater.exe",
        "Atualizador\Central de Trabalho Updater.ps1",
        "Modulos\Gerador-de-Planilhas-CB5-TV5\Gerador Planilhas.ps1",
        "Modulos\Central-de-Manutencao-CB5\Central Manutencao CB5.ps1"
    )) {
        $required = $requiredItem.Replace('\', [IO.Path]::DirectorySeparatorChar)
        if (-not $listed.Contains($required)) { throw "Arquivo obrigatório não listado: $required" }
    }

    if (-not $AllowExtraFiles) {
        $manifestPath = [IO.Path]::Combine($PackageRoot, "PACOTE-MANIFESTO.json")
        foreach ($actualPath in [IO.Directory]::EnumerateFiles($PackageRoot, "*", [IO.SearchOption]::AllDirectories)) {
            if ($actualPath -eq $manifestPath) { continue }
            $rootPrefix = [IO.Path]::GetFullPath($PackageRoot).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
            $relative = $actualPath.Substring($rootPrefix.Length)
            if (-not $listed.Contains($relative)) { throw "Arquivo não declarado no pacote: $relative" }
        }
    }
    return $true
}

function Copy-UpdateDirectoryContents {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Destination
    )

    $sourceFull = [IO.Path]::GetFullPath($Source).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    if (-not [IO.Directory]::Exists($Destination)) { [void][IO.Directory]::CreateDirectory($Destination) }
    foreach ($directory in [IO.Directory]::EnumerateDirectories($Source, "*", [IO.SearchOption]::AllDirectories)) {
        $relative = $directory.Substring($sourceFull.Length)
        $target = Resolve-SafeUpdateChildPath -Root $Destination -RelativePath $relative
        if (-not [IO.Directory]::Exists($target)) { [void][IO.Directory]::CreateDirectory($target) }
    }
    foreach ($file in [IO.Directory]::EnumerateFiles($Source, "*", [IO.SearchOption]::AllDirectories)) {
        $relative = $file.Substring($sourceFull.Length)
        $target = Resolve-SafeUpdateChildPath -Root $Destination -RelativePath $relative
        $parent = [IO.Path]::GetDirectoryName($target)
        if (-not [IO.Directory]::Exists($parent)) { [void][IO.Directory]::CreateDirectory($parent) }
        [IO.File]::Copy($file, $target, $true)
    }
}

function New-CentralUpdateBackup {
    param(
        [Parameter(Mandatory = $true)][string]$InstallRoot,
        [Parameter(Mandatory = $true)][string]$CurrentVersion,
        [Parameter(Mandatory = $true)][string]$TargetVersion
    )

    $InstallRoot = Assert-CentralUpdateInstallRoot -InstallRoot $InstallRoot
    $backupParent = [IO.Path]::Combine((Get-CentralUpdaterDataDirectory), "Backups")
    if (-not [IO.Directory]::Exists($backupParent)) { [void][IO.Directory]::CreateDirectory($backupParent) }
    $stamp = [DateTime]::Now.ToString("yyyyMMdd-HHmmss-fff")
    $backupRoot = [IO.Path]::Combine($backupParent, "$stamp-v$CurrentVersion")
    if ([IO.Directory]::Exists($backupRoot)) { throw "Já existe um backup com o mesmo horário." }
    [void][IO.Directory]::CreateDirectory($backupRoot)

    $programSnapshot = [IO.Path]::Combine($backupRoot, "Programa")
    Copy-UpdateDirectoryContents -Source $InstallRoot -Destination $programSnapshot

    $dataSnapshot = [IO.Path]::Combine($backupRoot, "Dados")
    [void][IO.Directory]::CreateDirectory($dataSnapshot)
    $local = Get-CentralUpdateApplicationDataRoot
    foreach ($name in @("CentralDeTrabalho", "GeradorPlanilhasCB5TV5")) {
        $source = [IO.Path]::Combine($local, $name)
        if ([IO.Directory]::Exists($source)) {
            Copy-UpdateDirectoryContents -Source $source -Destination ([IO.Path]::Combine($dataSnapshot, $name))
        }
    }

    $info = [pscustomobject]@{
        SchemaVersion = 1
        CreatedAt = [DateTime]::Now.ToString("s")
        CurrentVersion = $CurrentVersion
        TargetVersion = $TargetVersion
        InstallRoot = [IO.Path]::GetFullPath($InstallRoot)
        ProgramSnapshot = $programSnapshot
        DataSnapshot = $dataSnapshot
    }
    Write-UpdateJsonAtomic -Value $info -Path ([IO.Path]::Combine($backupRoot, "backup.json")) -Depth 6

    $backups = @([IO.Directory]::EnumerateDirectories($backupParent) | Sort-Object -Descending)
    if ($backups.Count -gt 5) {
        foreach ($old in @($backups | Select-Object -Skip 5)) {
            [IO.Directory]::Delete($old, $true)
        }
    }
    return $info
}

function Get-CentralUpdateBackups {
    $parent = [IO.Path]::Combine((Get-CentralUpdaterDataDirectory), "Backups")
    if (-not [IO.Directory]::Exists($parent)) { return @() }
    $result = @()
    foreach ($directory in @([IO.Directory]::EnumerateDirectories($parent) | Sort-Object -Descending)) {
        $infoPath = [IO.Path]::Combine($directory, "backup.json")
        try {
            if ([IO.File]::Exists($infoPath)) {
                $result += ,([IO.File]::ReadAllText($infoPath, [Text.Encoding]::UTF8) | ConvertFrom-Json)
            }
        }
        catch {}
    }
    return @($result)
}

function Remove-ManagedPackageFiles {
    param([Parameter(Mandatory = $true)][string]$InstallRoot)

    $manifestPath = [IO.Path]::Combine($InstallRoot, "PACOTE-MANIFESTO.json")
    if (-not [IO.File]::Exists($manifestPath)) { return }
    try { $manifest = Read-LocalPackageManifest -PackageRoot $InstallRoot }
    catch { return }

    foreach ($file in @($manifest.Files)) {
        $relative = ConvertTo-UpdateText $file.Path
        try {
            $path = Resolve-SafeUpdateChildPath -Root $InstallRoot -RelativePath $relative
            if ([IO.File]::Exists($path)) { [IO.File]::Delete($path) }
        }
        catch {}
    }
    if ([IO.File]::Exists($manifestPath)) { [IO.File]::Delete($manifestPath) }
}

function Restore-CentralUpdateBackup {
    param(
        [Parameter(Mandatory = $true)][object]$Backup,
        [Parameter(Mandatory = $true)][string]$InstallRoot,
        [switch]$RestoreData
    )

    $InstallRoot = Assert-CentralUpdateInstallRoot -InstallRoot $InstallRoot
    $programSnapshot = ConvertTo-UpdateText $Backup.ProgramSnapshot
    if (-not [IO.Directory]::Exists($programSnapshot)) { throw "A cópia do programa não foi encontrada." }
    [void](Test-UpdatePackagePayload -PackageRoot $programSnapshot -ExpectedVersion (ConvertTo-UpdateText $Backup.CurrentVersion) -AllowExtraFiles)
    Remove-ManagedPackageFiles -InstallRoot $InstallRoot
    Copy-UpdateDirectoryContents -Source $programSnapshot -Destination $InstallRoot

    if ($RestoreData) {
        $dataSnapshot = ConvertTo-UpdateText $Backup.DataSnapshot
        if ([IO.Directory]::Exists($dataSnapshot)) {
            $local = Get-CentralUpdateApplicationDataRoot
            foreach ($name in @("CentralDeTrabalho", "GeradorPlanilhasCB5TV5")) {
                $source = [IO.Path]::Combine($dataSnapshot, $name)
                if ([IO.Directory]::Exists($source)) {
                    Copy-UpdateDirectoryContents -Source $source -Destination ([IO.Path]::Combine($local, $name))
                }
            }
        }
    }
    return $true
}

function Install-CentralUpdatePayload {
    param(
        [Parameter(Mandatory = $true)][string]$PayloadRoot,
        [Parameter(Mandatory = $true)][string]$InstallRoot,
        [Parameter(Mandatory = $true)][string]$CurrentVersion,
        [Parameter(Mandatory = $true)][string]$TargetVersion
    )

    $InstallRoot = Assert-CentralUpdateInstallRoot -InstallRoot $InstallRoot
    [void](Test-UpdatePackagePayload -PackageRoot $PayloadRoot -ExpectedVersion $TargetVersion)
    $newManifest = Read-LocalPackageManifest -PackageRoot $PayloadRoot
    $oldPaths = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $oldManifestPath = [IO.Path]::Combine($InstallRoot, "PACOTE-MANIFESTO.json")
    if ([IO.File]::Exists($oldManifestPath)) {
        try {
            $oldManifest = Read-LocalPackageManifest -PackageRoot $InstallRoot
            foreach ($item in @($oldManifest.Files)) { [void]$oldPaths.Add((ConvertTo-UpdateText $item.Path)) }
            [void]$oldPaths.Add("PACOTE-MANIFESTO.json")
        }
        catch {}
    }

    $backup = New-CentralUpdateBackup -InstallRoot $InstallRoot -CurrentVersion $CurrentVersion -TargetVersion $TargetVersion
    try {
        foreach ($file in @($newManifest.Files)) {
            $relative = ConvertTo-UpdateText $file.Path
            $source = Resolve-SafeUpdateChildPath -Root $PayloadRoot -RelativePath $relative
            $destination = Resolve-SafeUpdateChildPath -Root $InstallRoot -RelativePath $relative
            $parent = [IO.Path]::GetDirectoryName($destination)
            if (-not [IO.Directory]::Exists($parent)) { [void][IO.Directory]::CreateDirectory($parent) }
            [IO.File]::Copy($source, $destination, $true)
        }
        [IO.File]::Copy(
            ([IO.Path]::Combine($PayloadRoot, "PACOTE-MANIFESTO.json")),
            ([IO.Path]::Combine($InstallRoot, "PACOTE-MANIFESTO.json")),
            $true
        )
        [void](Test-UpdatePackagePayload -PackageRoot $InstallRoot -ExpectedVersion $TargetVersion -AllowExtraFiles)

        $newPaths = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        foreach ($item in @($newManifest.Files)) { [void]$newPaths.Add((ConvertTo-UpdateText $item.Path)) }
        [void]$newPaths.Add("PACOTE-MANIFESTO.json")
        foreach ($relative in $oldPaths) {
            if (-not $newPaths.Contains($relative)) {
                $oldPath = Resolve-SafeUpdateChildPath -Root $InstallRoot -RelativePath $relative
                if ([IO.File]::Exists($oldPath)) { [IO.File]::Delete($oldPath) }
            }
        }

        $settings = Get-UpdateUserSettings
        $settings.LastBackupPath = ConvertTo-UpdateText $backup.ProgramSnapshot
        Save-UpdateUserSettings -Settings $settings
        return $backup
    }
    catch {
        foreach ($file in @($newManifest.Files)) {
            try {
                $newPath = Resolve-SafeUpdateChildPath -Root $InstallRoot -RelativePath (ConvertTo-UpdateText $file.Path)
                if ([IO.File]::Exists($newPath)) { [IO.File]::Delete($newPath) }
            }
            catch {}
        }
        try { [void](Restore-CentralUpdateBackup -Backup $backup -InstallRoot $InstallRoot -RestoreData) }
        catch {}
        throw
    }
}

function Enter-CentralUpdateApplicationLocks {
    $locks = @()
    try {
        foreach ($name in @(
            "CentralDeTrabalho_Central",
            "CentralDeTrabalho_GeradorPlanilhas",
            "CentralDeTrabalho_ManutencaoCB5"
        )) {
            $mutex = New-Object Threading.Mutex($false, $name)
            $acquired = $false
            try { $acquired = $mutex.WaitOne(0, $false) }
            catch [Threading.AbandonedMutexException] { $acquired = $true }
            if (-not $acquired) {
                $mutex.Dispose()
                throw "Um módulo da Central foi aberto durante a preparação da atualização."
            }
            $locks += ,$mutex
        }
        return @($locks)
    }
    catch {
        Exit-CentralUpdateApplicationLocks -Locks $locks
        throw
    }
}

function Exit-CentralUpdateApplicationLocks {
    param([object[]]$Locks)

    foreach ($mutex in @($Locks)) {
        if ($null -eq $mutex) { continue }
        try { $mutex.ReleaseMutex() }
        catch {}
        try { $mutex.Dispose() }
        catch {}
    }
}

function Test-CentralComponentRunning {
    param([Parameter(Mandatory = $true)][ValidateSet("Central", "Gerenciador", "Manutencao")][string]$Component)

    $mutexName = switch ($Component) {
        "Central" { "CentralDeTrabalho_Central" }
        "Gerenciador" { "CentralDeTrabalho_GeradorPlanilhas" }
        "Manutencao" { "CentralDeTrabalho_ManutencaoCB5" }
    }
    $mutex = New-Object Threading.Mutex($false, $mutexName)
    $acquired = $false
    try {
        try { $acquired = $mutex.WaitOne(0, $false) }
        catch [Threading.AbandonedMutexException] { $acquired = $true }
        if ($acquired) {
            $mutex.ReleaseMutex()
            return $false
        }
        return $true
    }
    finally { $mutex.Dispose() }
}

function Close-UpdateParentProcess {
    param([int]$ParentProcessId)

    if ($ParentProcessId -le 0) { return $true }
    try { $process = [Diagnostics.Process]::GetProcessById($ParentProcessId) }
    catch { return $true }
    try {
        [void]$process.CloseMainWindow()
        if (-not $process.WaitForExit(10000)) { return $false }
        return $true
    }
    finally { $process.Dispose() }
}

function Start-CentralAfterUpdate {
    param([Parameter(Mandatory = $true)][string]$InstallRoot)

    $candidates = @(
        [pscustomobject]@{ Path = [IO.Path]::Combine($InstallRoot, "Central de Trabalho.exe"); Kind = "exe" },
        [pscustomobject]@{ Path = [IO.Path]::Combine($InstallRoot, "ABRIR CENTRAL DE TRABALHO.vbs"); Kind = "vbs" }
    )

    foreach ($candidate in $candidates) {
        if (-not [IO.File]::Exists($candidate.Path)) { continue }
        try {
            $startInfo = New-Object Diagnostics.ProcessStartInfo
            $startInfo.FileName = $candidate.Path
            $startInfo.WorkingDirectory = $InstallRoot
            $startInfo.UseShellExecute = $true
            $process = [Diagnostics.Process]::Start($startInfo)
            if ($null -ne $process) { $process.Dispose() }

            for ($attempt = 0; $attempt -lt 24; $attempt++) {
                Start-Sleep -Milliseconds 250
                if (Test-CentralComponentRunning -Component "Central") { return $true }
            }
        }
        catch {
            # Tenta o próximo launcher disponível.
        }
    }
    return $false
}
