Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function ConvertTo-NFEntradaText {
    param($Value)
    if ($null -eq $Value) { return "" }
    return ([string]$Value).Trim()
}

function Get-NFEntradaDefaultDataDirectory {
    return [IO.Path]::Combine(
        [Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData),
        "CentralDeTrabalho",
        "NFEntrada"
    )
}

function Get-NFEntradaStorePath {
    param([string]$DataDirectory = (Get-NFEntradaDefaultDataDirectory))
    return [IO.Path]::Combine($DataDirectory, "nf-entrada.json")
}

function Get-NFEntradaTemplatePath {
    param([string]$DataDirectory = (Get-NFEntradaDefaultDataDirectory))
    return [IO.Path]::Combine($DataDirectory, "modelo-nf-entrada.xlsx")
}


function Get-NFEntradaBackupsDirectory {
    param([string]$DataDirectory = (Get-NFEntradaDefaultDataDirectory))
    return [IO.Path]::Combine($DataDirectory, "Backups")
}

function Ensure-NFEntradaStoreShape {
    param([Parameter(Mandatory = $true)]$Store)
    if ($null -eq $Store.PSObject.Properties["Historico"]) {
        $Store | Add-Member -NotePropertyName Historico -NotePropertyValue @()
    }
    elseif ($null -eq $Store.Historico) {
        $Store.Historico = @()
    }
    if ($null -eq $Store.PSObject.Properties["Meta"]) {
        $Store | Add-Member -NotePropertyName Meta -NotePropertyValue ([pscustomobject]@{
            CriadoEm = [DateTime]::Now.ToString("o")
            UltimaAlteracaoEm = [DateTime]::Now.ToString("o")
        })
    }
    else {
        if ($null -eq $Store.Meta.PSObject.Properties["CriadoEm"]) {
            $Store.Meta | Add-Member -NotePropertyName CriadoEm -NotePropertyValue ([DateTime]::Now.ToString("o"))
        }
        if ($null -eq $Store.Meta.PSObject.Properties["UltimaAlteracaoEm"]) {
            $Store.Meta | Add-Member -NotePropertyName UltimaAlteracaoEm -NotePropertyValue ([DateTime]::Now.ToString("o"))
        }
    }
    return $Store
}

function Copy-NFEntradaRecordSnapshot {
    param($Record)
    if ($null -eq $Record) { return $null }
    return [pscustomobject]@{
        Id = [int]$Record.Id
        Ordem = [int]$Record.Ordem
        Data = ConvertTo-NFEntradaText $Record.Data
        QuantidadeNaNF = [int]$Record.QuantidadeNaNF
        NFEntrada = ConvertTo-NFEntradaText $Record.NFEntrada
        QuantidadeSaldo = [int]$Record.QuantidadeSaldo
        Codigo = ConvertTo-NFEntradaText $Record.Codigo
        NFSaida = ConvertTo-NFEntradaText $Record.NFSaida
    }
}

function Add-NFEntradaHistoryEvent {
    param(
        [Parameter(Mandatory = $true)]$Store,
        [Parameter(Mandatory = $true)][string]$Tipo,
        [string]$Produto = "",
        [int]$RegistroId = 0,
        [string]$NFEntrada = "",
        $Antes = $null,
        $Depois = $null,
        [string]$Detalhes = ""
    )
    [void](Ensure-NFEntradaStoreShape -Store $Store)
    $event = [pscustomobject]@{
        Id = [guid]::NewGuid().ToString("N")
        DataHora = [DateTime]::Now.ToString("o")
        Tipo = $Tipo
        Produto = $Produto
        RegistroId = $RegistroId
        NFEntrada = $NFEntrada
        Detalhes = $Detalhes
        Antes = $Antes
        Depois = $Depois
    }
    $Store.Historico = @($Store.Historico) + $event
    $Store.Meta.UltimaAlteracaoEm = $event.DataHora
    return $event
}

function Get-NFEntradaHistory {
    param([Parameter(Mandatory = $true)]$Store)
    [void](Ensure-NFEntradaStoreShape -Store $Store)
    return @($Store.Historico | Sort-Object { [DateTime]$_.DataHora } -Descending)
}

function New-NFEntradaSafetyBackup {
    param(
        [string]$DataDirectory = (Get-NFEntradaDefaultDataDirectory),
        [string]$Reason = "Automático"
    )
    $storePath = Get-NFEntradaStorePath -DataDirectory $DataDirectory
    $templatePath = Get-NFEntradaTemplatePath -DataDirectory $DataDirectory
    $storeExists = [IO.File]::Exists($storePath)
    $templateExists = [IO.File]::Exists($templatePath)
    if (-not $storeExists -and -not $templateExists) { return $null }

    $backupRoot = Get-NFEntradaBackupsDirectory -DataDirectory $DataDirectory
    if (-not [IO.Directory]::Exists($backupRoot)) { [void][IO.Directory]::CreateDirectory($backupRoot) }
    $stamp = [DateTime]::Now.ToString("yyyyMMdd-HHmmss-fff")
    $backupDirectory = [IO.Path]::Combine($backupRoot, $stamp)
    [void][IO.Directory]::CreateDirectory($backupDirectory)
    if ($storeExists) { [IO.File]::Copy($storePath, [IO.Path]::Combine($backupDirectory, "nf-entrada.json"), $true) }
    if ($templateExists) { [IO.File]::Copy($templatePath, [IO.Path]::Combine($backupDirectory, "modelo-nf-entrada.xlsx"), $true) }
    $info = [pscustomobject]@{
        SchemaVersion = 1
        DataHora = [DateTime]::Now.ToString("o")
        Motivo = $Reason
        StoreExisted = $storeExists
        TemplateExisted = $templateExists
    }
    [IO.File]::WriteAllText(
        [IO.Path]::Combine($backupDirectory, "backup-info.json"),
        ($info | ConvertTo-Json -Depth 4),
        ([Text.UTF8Encoding]::new($true))
    )
    return [pscustomobject]@{
        Directory = $backupDirectory
        StoreExisted = $storeExists
        TemplateExisted = $templateExists
        Reason = $Reason
    }
}

function Restore-NFEntradaSafetyBackup {
    param(
        [Parameter(Mandatory = $true)]$Backup,
        [string]$DataDirectory = (Get-NFEntradaDefaultDataDirectory)
    )
    $storePath = Get-NFEntradaStorePath -DataDirectory $DataDirectory
    $templatePath = Get-NFEntradaTemplatePath -DataDirectory $DataDirectory
    $backupStore = [IO.Path]::Combine([string]$Backup.Directory, "nf-entrada.json")
    $backupTemplate = [IO.Path]::Combine([string]$Backup.Directory, "modelo-nf-entrada.xlsx")
    if ([bool]$Backup.StoreExisted -and [IO.File]::Exists($backupStore)) { [IO.File]::Copy($backupStore, $storePath, $true) }
    elseif (-not [bool]$Backup.StoreExisted -and [IO.File]::Exists($storePath)) { [IO.File]::Delete($storePath) }
    if ([bool]$Backup.TemplateExisted -and [IO.File]::Exists($backupTemplate)) { [IO.File]::Copy($backupTemplate, $templatePath, $true) }
    elseif (-not [bool]$Backup.TemplateExisted -and [IO.File]::Exists($templatePath)) { [IO.File]::Delete($templatePath) }
}

function Get-NFEntradaSafetyBackups {
    param([string]$DataDirectory = (Get-NFEntradaDefaultDataDirectory))
    $backupRoot = Get-NFEntradaBackupsDirectory -DataDirectory $DataDirectory
    if (-not [IO.Directory]::Exists($backupRoot)) { return @() }
    $result = [Collections.Generic.List[object]]::new()
    foreach ($directory in [IO.Directory]::GetDirectories($backupRoot)) {
        $storePath = [IO.Path]::Combine($directory, "nf-entrada.json")
        $templatePath = [IO.Path]::Combine($directory, "modelo-nf-entrada.xlsx")
        $infoPath = [IO.Path]::Combine($directory, "backup-info.json")
        $hasStore = [IO.File]::Exists($storePath)
        $hasTemplate = [IO.File]::Exists($templatePath)
        $validStore = $false
        $recordCount = 0
        if ($hasStore) {
            try {
                $stored = Read-NFEntradaStore -Path $storePath
                $recordCount = @(Get-NFEntradaProductRecords -Store $stored -Product "COMPUTADOR DE BORDO V5").Count + @(Get-NFEntradaProductRecords -Store $stored -Product "TECLADO V5").Count
                $validStore = $true
            }
            catch { $validStore = $false }
        }
        $date = [IO.DirectoryInfo]::new($directory).CreationTime
        $reason = "Automático / legado"
        if ([IO.File]::Exists($infoPath)) {
            try {
                $info = [IO.File]::ReadAllText($infoPath, [Text.Encoding]::UTF8) | ConvertFrom-Json
                $parsed = [DateTime]::MinValue
                if ([DateTime]::TryParse([string]$info.DataHora, [ref]$parsed)) { $date = $parsed }
                if (-not [string]::IsNullOrWhiteSpace([string]$info.Motivo)) { $reason = [string]$info.Motivo }
            }
            catch {}
        }
        else {
            $name = [IO.Path]::GetFileName($directory)
            $parsedName = [DateTime]::MinValue
            if ([DateTime]::TryParseExact($name, "yyyyMMdd-HHmmss-fff", [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::None, [ref]$parsedName)) { $date = $parsedName }
        }
        [void]$result.Add([pscustomobject]@{
            Directory = $directory
            DataHora = $date
            Motivo = $reason
            TemBase = $hasStore
            TemModelo = $hasTemplate
            BaseValida = $validStore
            Registros = $recordCount
            Situacao = if ($hasStore -and $validStore) { "Pronto" } else { "Inválido" }
        })
    }
    return @($result | Sort-Object DataHora -Descending)
}

function Restore-NFEntradaBackupSet {
    param(
        [Parameter(Mandatory = $true)][string]$BackupDirectory,
        [string]$DataDirectory = (Get-NFEntradaDefaultDataDirectory)
    )
    $backupRoot = [IO.Path]::GetFullPath((Get-NFEntradaBackupsDirectory -DataDirectory $DataDirectory)).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
    $selected = [IO.Path]::GetFullPath($BackupDirectory).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
    if (-not $selected.StartsWith($backupRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw "O backup selecionado não pertence ao Controle de NF de Entrada."
    }
    if (-not [IO.Directory]::Exists($selected)) { throw "O backup selecionado não foi encontrado." }
    $backupStore = [IO.Path]::Combine($selected, "nf-entrada.json")
    $backupTemplate = [IO.Path]::Combine($selected, "modelo-nf-entrada.xlsx")
    if (-not [IO.File]::Exists($backupStore)) { throw "O backup não contém a base de NF de Entrada." }
    [void](Read-NFEntradaStore -Path $backupStore)
    if ([IO.File]::Exists($backupTemplate) -and ([IO.FileInfo]::new($backupTemplate)).Length -le 0) { throw "O modelo Excel do backup está vazio." }

    $recovery = New-NFEntradaSafetyBackup -DataDirectory $DataDirectory -Reason "Antes de restaurar backup"
    $storePath = Get-NFEntradaStorePath -DataDirectory $DataDirectory
    $templatePath = Get-NFEntradaTemplatePath -DataDirectory $DataDirectory
    $token = [guid]::NewGuid().ToString("N")
    $tempStore = $storePath + ".restore-" + $token + ".tmp"
    $tempTemplate = $templatePath + ".restore-" + $token + ".tmp"
    try {
        [IO.File]::Copy($backupStore, $tempStore, $true)
        [void](Read-NFEntradaStore -Path $tempStore)
        $restoreTemplate = [IO.File]::Exists($backupTemplate)
        if ($restoreTemplate) { [IO.File]::Copy($backupTemplate, $tempTemplate, $true) }
        [IO.File]::Copy($tempStore, $storePath, $true)
        if ($restoreTemplate) { [IO.File]::Copy($tempTemplate, $templatePath, $true) }
        elseif ([IO.File]::Exists($templatePath)) { [IO.File]::Delete($templatePath) }
        $restored = Read-NFEntradaStore -Path $storePath
        [void](Add-NFEntradaHistoryEvent -Store $restored -Tipo "RestauracaoBackup" -Detalhes ("Backup restaurado: " + [IO.Path]::GetFileName($selected)))
        Write-NFEntradaStore -Store $restored -Path $storePath
        return [pscustomobject]@{
            Store = $restored
            StorePath = $storePath
            TemplatePath = $templatePath
            RecoveryBackupDirectory = if ($null -ne $recovery) { [string]$recovery.Directory } else { "" }
        }
    }
    catch {
        if ($null -ne $recovery) { try { Restore-NFEntradaSafetyBackup -Backup $recovery -DataDirectory $DataDirectory } catch {} }
        throw
    }
    finally {
        if ([IO.File]::Exists($tempStore)) { try { [IO.File]::Delete($tempStore) } catch {} }
        if ([IO.File]::Exists($tempTemplate)) { try { [IO.File]::Delete($tempTemplate) } catch {} }
    }
}

function Get-NFEntradaZipEntryText {
    param(
        [Parameter(Mandatory = $true)][IO.Compression.ZipArchive]$Archive,
        [Parameter(Mandatory = $true)][string]$Name
    )
    $entry = $Archive.GetEntry($Name)
    if ($null -eq $entry) { throw "Estrutura do modelo inválida: $Name não encontrado." }
    $stream = $entry.Open()
    $reader = $null
    try {
        $reader = [IO.StreamReader]::new($stream, [Text.Encoding]::UTF8, $true)
        return $reader.ReadToEnd()
    }
    finally {
        if ($null -ne $reader) { $reader.Dispose() }
        else { $stream.Dispose() }
    }
}

function Get-NFEntradaSharedStrings {
    param([Parameter(Mandatory = $true)][IO.Compression.ZipArchive]$Archive)
    $entry = $Archive.GetEntry("xl/sharedStrings.xml")
    if ($null -eq $entry) { return @() }
    [xml]$doc = Get-NFEntradaZipEntryText -Archive $Archive -Name "xl/sharedStrings.xml"
    $ns = [Xml.XmlNamespaceManager]::new($doc.NameTable)
    $ns.AddNamespace("x", "http://schemas.openxmlformats.org/spreadsheetml/2006/main")
    $items = [Collections.Generic.List[string]]::new()
    foreach ($si in @($doc.SelectNodes("//x:si", $ns))) {
        $parts = [Collections.Generic.List[string]]::new()
        foreach ($t in @($si.SelectNodes(".//x:t", $ns))) { [void]$parts.Add([string]$t.InnerText) }
        [void]$items.Add(($parts -join ""))
    }
    return @($items)
}

function Get-NFEntradaCellValue {
    param(
        [Parameter(Mandatory = $true)][Xml.XmlElement]$Cell,
        [string[]]$SharedStrings = @(),
        [Parameter(Mandatory = $true)][Xml.XmlNamespaceManager]$Ns
    )
    $type = [string]$Cell.GetAttribute("t")
    if ($type -eq "inlineStr") {
        $nodes = @($Cell.SelectNodes(".//x:is//x:t", $Ns))
        return (($nodes | ForEach-Object { [string]$_.InnerText }) -join "")
    }
    $v = $Cell.SelectSingleNode("./x:v", $Ns)
    if ($null -eq $v) { return "" }
    $raw = [string]$v.InnerText
    if ($type -eq "s") {
        $index = 0
        if ([int]::TryParse($raw, [ref]$index) -and $index -ge 0 -and $index -lt $SharedStrings.Count) {
            return [string]$SharedStrings[$index]
        }
        return ""
    }
    return $raw
}

function Import-NFEntradaSheetRecords {
    param(
        [Parameter(Mandatory = $true)][IO.Compression.ZipArchive]$Archive,
        [Parameter(Mandatory = $true)][string]$EntryName,
        [Parameter(Mandatory = $true)][string]$ProductName,
        [string[]]$SharedStrings = @(),
        [Parameter(Mandatory = $true)][ref]$NextId
    )
    [xml]$doc = Get-NFEntradaZipEntryText -Archive $Archive -Name $EntryName
    $ns = [Xml.XmlNamespaceManager]::new($doc.NameTable)
    $ns.AddNamespace("x", "http://schemas.openxmlformats.org/spreadsheetml/2006/main")
    $records = [Collections.Generic.List[object]]::new()
    $order = 0

    foreach ($row in @($doc.SelectNodes("//x:sheetData/x:row", $ns))) {
        $rowNumber = 0
        [void][int]::TryParse([string]$row.GetAttribute("r"), [ref]$rowNumber)
        if ($rowNumber -lt 3 -or $rowNumber -gt 298) { continue }

        $values = @{ A = ""; B = ""; C = ""; D = ""; E = ""; F = "" }
        foreach ($cell in @($row.SelectNodes("./x:c", $ns))) {
            $reference = [string]$cell.GetAttribute("r")
            if ($reference -notmatch '^([A-F])\d+$') { continue }
            $column = $matches[1]
            $values[$column] = Get-NFEntradaCellValue -Cell $cell -SharedStrings $SharedStrings -Ns $ns
        }

        if ([string]::IsNullOrWhiteSpace([string]$values.C) -and [string]::IsNullOrWhiteSpace([string]$values.B) -and [string]::IsNullOrWhiteSpace([string]$values.D)) { continue }
        $order++

        $dateText = ""
        $oa = 0.0
        if ([double]::TryParse(([string]$values.A), [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$oa)) {
            try { $dateText = [DateTime]::FromOADate($oa).ToString("yyyy-MM-dd") } catch { $dateText = "" }
        }

        $qty = 0
        $saldo = 0
        [void][int]::TryParse(([string]$values.B), [ref]$qty)
        [void][int]::TryParse(([string]$values.D), [ref]$saldo)
        $nfEntrada = ConvertTo-NFEntradaText $values.C
        if ($nfEntrada -match '^\d+\.0+$') { $nfEntrada = $nfEntrada.Split('.')[0] }
        $codigo = ConvertTo-NFEntradaText $values.E
        if ($codigo -match '^\d+\.0+$') { $codigo = $codigo.Split('.')[0] }

        [void]$records.Add([pscustomobject]@{
            Id = [int]$NextId.Value
            Ordem = $order
            Data = $dateText
            QuantidadeNaNF = $qty
            NFEntrada = $nfEntrada
            QuantidadeSaldo = $saldo
            Codigo = $codigo
            NFSaida = ConvertTo-NFEntradaText $values.F
        })
        $NextId.Value = [int]$NextId.Value + 1
    }
    return @($records)
}

function New-NFEntradaStoreFromWorkbook {
    param([Parameter(Mandatory = $true)][string]$WorkbookPath)
    Add-Type -AssemblyName System.IO.Compression
    if (-not [IO.File]::Exists($WorkbookPath)) { throw "A planilha informada não foi encontrada." }
    $stream = [IO.File]::Open($WorkbookPath, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
    $archive = $null
    try {
        $archive = [IO.Compression.ZipArchive]::new($stream, [IO.Compression.ZipArchiveMode]::Read, $false)
        $shared = Get-NFEntradaSharedStrings -Archive $archive
        $next = 1
        $cb = Import-NFEntradaSheetRecords -Archive $archive -EntryName "xl/worksheets/sheet1.xml" -ProductName "COMPUTADOR DE BORDO V5" -SharedStrings $shared -NextId ([ref]$next)
        $tk = Import-NFEntradaSheetRecords -Archive $archive -EntryName "xl/worksheets/sheet2.xml" -ProductName "TECLADO V5" -SharedStrings $shared -NextId ([ref]$next)
        if (@($cb).Count -eq 0 -and @($tk).Count -eq 0) { throw "A planilha não contém os registros esperados de Computador de Bordo V5 e Teclado V5." }
        $store = [pscustomobject]@{
            SchemaVersion = 1
            NextId = $next
            Produtos = [pscustomobject]@{
                'COMPUTADOR DE BORDO V5' = @($cb)
                'TECLADO V5' = @($tk)
            }
            Historico = @()
            Meta = [pscustomobject]@{
                CriadoEm = [DateTime]::Now.ToString("o")
                UltimaAlteracaoEm = [DateTime]::Now.ToString("o")
            }
        }
        return $store
    }
    finally {
        if ($null -ne $archive) { $archive.Dispose() }
        $stream.Dispose()
    }
}

function New-EmptyNFEntradaStore {
    return [pscustomobject]@{
        SchemaVersion = 1
        NextId = 1
        Produtos = [pscustomobject]@{
            'COMPUTADOR DE BORDO V5' = @()
            'TECLADO V5' = @()
        }
        Historico = @()
        Meta = [pscustomobject]@{
            CriadoEm = [DateTime]::Now.ToString("o")
            UltimaAlteracaoEm = [DateTime]::Now.ToString("o")
        }
    }
}

function Import-NFEntradaSourceWorkbook {
    param(
        [Parameter(Mandatory = $true)][string]$SourcePath,
        [string]$DataDirectory = (Get-NFEntradaDefaultDataDirectory)
    )
    if (-not [IO.File]::Exists($SourcePath)) { throw "A planilha selecionada não foi encontrada." }
    if ([IO.Path]::GetExtension($SourcePath) -ne ".xlsx") { throw "Selecione a planilha original no formato .xlsx." }
    if (-not [IO.Directory]::Exists($DataDirectory)) { [void][IO.Directory]::CreateDirectory($DataDirectory) }

    $storePath = Get-NFEntradaStorePath -DataDirectory $DataDirectory
    $templatePath = Get-NFEntradaTemplatePath -DataDirectory $DataDirectory
    $store = New-NFEntradaStoreFromWorkbook -WorkbookPath $SourcePath
    if ([IO.File]::Exists($storePath)) {
        try {
            $previous = Read-NFEntradaStore -Path $storePath
            [void](Ensure-NFEntradaStoreShape -Store $previous)
            $store.Historico = @($previous.Historico)
        }
        catch {}
    }
    [void](Add-NFEntradaHistoryEvent -Store $store -Tipo "Importacao" -Detalhes ("Planilha importada: " + [IO.Path]::GetFileName($SourcePath)))

    $backup = New-NFEntradaSafetyBackup -DataDirectory $DataDirectory
    $token = [guid]::NewGuid().ToString("N")
    $tempTemplate = $templatePath + "." + $token + ".tmp"
    $tempStore = $storePath + "." + $token + ".tmp"
    try {
        [IO.File]::Copy($SourcePath, $tempTemplate, $true)
        Write-NFEntradaStore -Store $store -Path $tempStore
        [void](Read-NFEntradaStore -Path $tempStore)
        [IO.File]::Copy($tempTemplate, $templatePath, $true)
        [IO.File]::Copy($tempStore, $storePath, $true)
    }
    catch {
        if ($null -ne $backup) {
            try { Restore-NFEntradaSafetyBackup -Backup $backup -DataDirectory $DataDirectory } catch {}
        }
        throw
    }
    finally {
        if ([IO.File]::Exists($tempTemplate)) { try { [IO.File]::Delete($tempTemplate) } catch {} }
        if ([IO.File]::Exists($tempStore)) { try { [IO.File]::Delete($tempStore) } catch {} }
        $tempBak = $tempStore + ".bak"
        if ([IO.File]::Exists($tempBak)) { try { [IO.File]::Delete($tempBak) } catch {} }
    }
    return [pscustomobject]@{
        Store = $store
        StorePath = $storePath
        TemplatePath = $templatePath
        BackupDirectory = if ($null -ne $backup) { [string]$backup.Directory } else { "" }
    }
}

function Write-NFEntradaStore {
    param(
        [Parameter(Mandatory = $true)]$Store,
        [string]$Path = (Get-NFEntradaStorePath)
    )
    [void](Ensure-NFEntradaStoreShape -Store $Store)
    $Store.Meta.UltimaAlteracaoEm = [DateTime]::Now.ToString("o")
    $directory = [IO.Path]::GetDirectoryName($Path)
    if (-not [IO.Directory]::Exists($directory)) { [void][IO.Directory]::CreateDirectory($directory) }
    $temp = $Path + ".tmp"
    $json = $Store | ConvertTo-Json -Depth 20
    [IO.File]::WriteAllText($temp, $json, ([Text.UTF8Encoding]::new($true)))
    if ([IO.File]::Exists($Path)) {
        $backup = $Path + ".bak"
        [IO.File]::Copy($Path, $backup, $true)
    }
    [IO.File]::Copy($temp, $Path, $true)
    [IO.File]::Delete($temp)
}

function Read-NFEntradaStore {
    param([string]$Path = (Get-NFEntradaStorePath))
    if (-not [IO.File]::Exists($Path)) { throw "A base de NF de Entrada não foi encontrada." }
    $store = ([IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8) | ConvertFrom-Json)
    if ($null -eq $store -or [int]$store.SchemaVersion -ne 1) { throw "A base de NF de Entrada possui formato incompatível." }
    [void](Ensure-NFEntradaStoreShape -Store $store)
    return $store
}

function Initialize-NFEntradaDataStore {
    param([string]$DataDirectory = (Get-NFEntradaDefaultDataDirectory))
    if (-not [IO.Directory]::Exists($DataDirectory)) { [void][IO.Directory]::CreateDirectory($DataDirectory) }
    $path = Get-NFEntradaStorePath -DataDirectory $DataDirectory
    if (-not [IO.File]::Exists($path)) {
        Write-NFEntradaStore -Store (New-EmptyNFEntradaStore) -Path $path
    }
    [void](Read-NFEntradaStore -Path $path)
    return $path
}

function Get-NFEntradaRecordStatus {
    param([Parameter(Mandatory = $true)]$Record)
    $qty = [int]$Record.QuantidadeNaNF
    $saldo = [int]$Record.QuantidadeSaldo
    if ($saldo -lt 0 -or $saldo -gt $qty) { return "Revisar" }
    if ($saldo -eq 0) { return "Encerrada" }
    return "Em estoque"
}

function Get-NFEntradaProductRecords {
    param(
        [Parameter(Mandatory = $true)]$Store,
        [Parameter(Mandatory = $true)][ValidateSet("COMPUTADOR DE BORDO V5", "TECLADO V5")][string]$Product
    )
    $property = $Store.Produtos.PSObject.Properties[$Product]
    if ($null -eq $property -or $null -eq $property.Value) { return @() }
    return @($property.Value | Sort-Object { [int]$_.Ordem }, { [int]$_.Id })
}

function Test-NFEntradaRecord {
    param(
        [Parameter(Mandatory = $true)]$Record,
        [Parameter(Mandatory = $true)]$Store,
        [Parameter(Mandatory = $true)][ValidateSet("COMPUTADOR DE BORDO V5", "TECLADO V5")][string]$Product,
        [int]$IgnoreId = 0
    )
    $dateText = ConvertTo-NFEntradaText $Record.Data
    $date = [DateTime]::MinValue
    if (-not [DateTime]::TryParseExact($dateText, "yyyy-MM-dd", [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::None, [ref]$date)) {
        throw "Informe uma data válida."
    }
    $qty = [int]$Record.QuantidadeNaNF
    $saldo = [int]$Record.QuantidadeSaldo
    if ($qty -le 0) { throw "A quantidade na NF deve ser maior que zero." }
    if ($saldo -lt 0) { throw "A quantidade no saldo não pode ser negativa." }
    if ($saldo -gt $qty) { throw "A quantidade no saldo não pode ser maior que a quantidade da NF." }
    $nf = ConvertTo-NFEntradaText $Record.NFEntrada
    if ([string]::IsNullOrWhiteSpace($nf)) { throw "Informe a NF de Entrada." }
    $code = ConvertTo-NFEntradaText $Record.Codigo
    if (@("800", "100", "850", "Garantia") -notcontains $code) { throw "Selecione um código válido: 800, 100, 850 ou Garantia." }
    foreach ($existing in Get-NFEntradaProductRecords -Store $Store -Product $Product) {
        if ([int]$existing.Id -eq $IgnoreId) { continue }
        if ([string]::Equals((ConvertTo-NFEntradaText $existing.NFEntrada), $nf, [StringComparison]::OrdinalIgnoreCase)) {
            throw "A NF de Entrada $nf já está cadastrada em $Product."
        }
    }
    return $true
}

function Add-NFEntradaRecord {
    param(
        [Parameter(Mandatory = $true)]$Store,
        [Parameter(Mandatory = $true)][ValidateSet("COMPUTADOR DE BORDO V5", "TECLADO V5")][string]$Product,
        [Parameter(Mandatory = $true)]$Record
    )
    [void](Test-NFEntradaRecord -Record $Record -Store $Store -Product $Product)
    $records = @(Get-NFEntradaProductRecords -Store $Store -Product $Product)
    $maxOrder = 0
    if ($records.Count -gt 0) { $maxOrder = [int](($records | Measure-Object -Property Ordem -Maximum).Maximum) }
    $id = [int]$Store.NextId
    $newRecord = [pscustomobject]@{
        Id = $id
        Ordem = $maxOrder + 1
        Data = ConvertTo-NFEntradaText $Record.Data
        QuantidadeNaNF = [int]$Record.QuantidadeNaNF
        NFEntrada = ConvertTo-NFEntradaText $Record.NFEntrada
        QuantidadeSaldo = [int]$Record.QuantidadeSaldo
        Codigo = ConvertTo-NFEntradaText $Record.Codigo
        NFSaida = ConvertTo-NFEntradaText $Record.NFSaida
    }
    $property = $Store.Produtos.PSObject.Properties[$Product]
    $property.Value = @($records + $newRecord)
    $Store.NextId = $id + 1
    [void](Add-NFEntradaHistoryEvent -Store $Store -Tipo "Adicao" -Produto $Product -RegistroId $id -NFEntrada $newRecord.NFEntrada -Depois (Copy-NFEntradaRecordSnapshot $newRecord))
    return $newRecord
}

function Update-NFEntradaRecord {
    param(
        [Parameter(Mandatory = $true)]$Store,
        [Parameter(Mandatory = $true)][ValidateSet("COMPUTADOR DE BORDO V5", "TECLADO V5")][string]$Product,
        [Parameter(Mandatory = $true)][int]$Id,
        [Parameter(Mandatory = $true)]$Record
    )
    [void](Test-NFEntradaRecord -Record $Record -Store $Store -Product $Product -IgnoreId $Id)
    $records = @(Get-NFEntradaProductRecords -Store $Store -Product $Product)
    $found = $false
    $before = $null
    $after = $null
    foreach ($existing in $records) {
        if ([int]$existing.Id -ne $Id) { continue }
        $before = Copy-NFEntradaRecordSnapshot $existing
        $existing.Data = ConvertTo-NFEntradaText $Record.Data
        $existing.QuantidadeNaNF = [int]$Record.QuantidadeNaNF
        $existing.NFEntrada = ConvertTo-NFEntradaText $Record.NFEntrada
        $existing.QuantidadeSaldo = [int]$Record.QuantidadeSaldo
        $existing.Codigo = ConvertTo-NFEntradaText $Record.Codigo
        $existing.NFSaida = ConvertTo-NFEntradaText $Record.NFSaida
        $after = Copy-NFEntradaRecordSnapshot $existing
        $found = $true
        break
    }
    if (-not $found) { throw "O registro selecionado não foi encontrado." }
    $Store.Produtos.PSObject.Properties[$Product].Value = @($records)
    [void](Add-NFEntradaHistoryEvent -Store $Store -Tipo "Edicao" -Produto $Product -RegistroId $Id -NFEntrada $after.NFEntrada -Antes $before -Depois $after)
}

function Remove-NFEntradaRecord {
    param(
        [Parameter(Mandatory = $true)]$Store,
        [Parameter(Mandatory = $true)][ValidateSet("COMPUTADOR DE BORDO V5", "TECLADO V5")][string]$Product,
        [Parameter(Mandatory = $true)][int]$Id
    )
    $records = @(Get-NFEntradaProductRecords -Store $Store -Product $Product)
    $removed = @($records | Where-Object { [int]$_.Id -eq $Id } | Select-Object -First 1)
    $remaining = @($records | Where-Object { [int]$_.Id -ne $Id })
    if ($remaining.Count -eq $records.Count) { throw "O registro selecionado não foi encontrado." }
    $Store.Produtos.PSObject.Properties[$Product].Value = @($remaining)
    $snapshot = if ($removed.Count -gt 0) { Copy-NFEntradaRecordSnapshot $removed[0] } else { $null }
    $nf = if ($null -ne $snapshot) { [string]$snapshot.NFEntrada } else { "" }
    [void](Add-NFEntradaHistoryEvent -Store $Store -Tipo "Exclusao" -Produto $Product -RegistroId $Id -NFEntrada $nf -Antes $snapshot)
}

function Get-NFEntradaSummary {
    param([Parameter(Mandatory = $true)]$Store)
    $products = @("COMPUTADOR DE BORDO V5", "TECLADO V5")
    $productSummary = [ordered]@{}
    $codeSummary = [ordered]@{
        "800" = [ordered]@{ Computador = 0; Teclado = 0; Total = 0 }
        "100" = [ordered]@{ Computador = 0; Teclado = 0; Total = 0 }
        "850" = [ordered]@{ Computador = 0; Teclado = 0; Total = 0 }
        "Garantia" = [ordered]@{ Computador = 0; Teclado = 0; Total = 0 }
    }
    $missingDates = 0
    $negative = 0
    $overEntry = 0
    $totalBalance = 0
    $totalOpen = 0

    foreach ($product in $products) {
        $records = @(Get-NFEntradaProductRecords -Store $Store -Product $product)
        $balance = 0
        $open = 0
        foreach ($r in $records) {
            $qty = [int]$r.QuantidadeNaNF
            $saldo = [int]$r.QuantidadeSaldo
            $balance += $saldo
            if ($saldo -gt 0) { $open++ }
            if ([string]::IsNullOrWhiteSpace((ConvertTo-NFEntradaText $r.Data))) { $missingDates++ }
            if ($saldo -lt 0) { $negative++ }
            if ($saldo -gt $qty) { $overEntry++ }
            $code = ConvertTo-NFEntradaText $r.Codigo
            if ($codeSummary.Contains($code)) {
                if ($product -eq "COMPUTADOR DE BORDO V5") { $codeSummary[$code].Computador += $saldo }
                else { $codeSummary[$code].Teclado += $saldo }
                $codeSummary[$code].Total += $saldo
            }
        }
        $productSummary[$product] = [pscustomobject]@{ Registros = $records.Count; NFsAbertas = $open; Saldo = $balance }
        $totalBalance += $balance
        $totalOpen += $open
    }

    return [pscustomobject]@{
        SaldoTotal = $totalBalance
        NFsAbertas = $totalOpen
        Produtos = $productSummary
        Codigos = $codeSummary
        DatasAusentes = $missingDates
        SaldosNegativos = $negative
        SaldoMaiorQueEntrada = $overEntry
        Situacao = if (($missingDates + $negative + $overEntry) -eq 0) { "OK" } else { "REVISAR" }
    }
}

function Export-NFEntradaWorkbook {
    param(
        [Parameter(Mandatory = $true)]$Store,
        [Parameter(Mandatory = $true)][string]$DestinationPath
    )
    $products = @(
        [pscustomobject]@{ Name = "COMPUTADOR DE BORDO V5"; Sheet = "COMPUTADOR DE BORDO V5" },
        [pscustomobject]@{ Name = "TECLADO V5"; Sheet = "TECLADO V5" }
    )
    foreach ($p in $products) {
        $count = @(Get-NFEntradaProductRecords -Store $Store -Product $p.Name).Count
        if ($count -gt 296) {
            throw "$($p.Name) possui $count registros. O modelo original comporta até 296 linhas sem alterar o formato."
        }
    }

    $destinationFull = [IO.Path]::GetFullPath($DestinationPath)
    $parent = [IO.Path]::GetDirectoryName($destinationFull)
    if (-not [IO.Directory]::Exists($parent)) { [void][IO.Directory]::CreateDirectory($parent) }
    $templatePath = Get-NFEntradaTemplatePath
    if (-not [IO.File]::Exists($templatePath)) { throw "Importe a planilha original uma vez antes de exportar." }
    [IO.File]::Copy($templatePath, $destinationFull, $true)

    $excel = $null
    $workbook = $null
    try {
        try { $excel = New-Object -ComObject Excel.Application }
        catch { throw "O Microsoft Excel é necessário para exportar mantendo exatamente o modelo original." }
        $excel.Visible = $false
        $excel.DisplayAlerts = $false
        $excel.ScreenUpdating = $false
        $workbook = $excel.Workbooks.Open($destinationFull, 0, $false)

        foreach ($p in $products) {
            $sheet = $null
            try {
                $sheet = $workbook.Worksheets.Item($p.Sheet)
                $sheet.Range("A3:F298").ClearContents() | Out-Null
                $rowNumber = 3
                foreach ($record in @(Get-NFEntradaProductRecords -Store $Store -Product $p.Name)) {
                    $date = [DateTime]::ParseExact([string]$record.Data, "yyyy-MM-dd", [Globalization.CultureInfo]::InvariantCulture)
                    $sheet.Cells.Item($rowNumber, 1).Value2 = $date.ToOADate()
                    $sheet.Cells.Item($rowNumber, 2).Value2 = [int]$record.QuantidadeNaNF
                    $sheet.Cells.Item($rowNumber, 3).Value2 = [string]$record.NFEntrada
                    $sheet.Cells.Item($rowNumber, 4).Value2 = [int]$record.QuantidadeSaldo
                    $sheet.Cells.Item($rowNumber, 5).Value2 = [string]$record.Codigo
                    $sheet.Cells.Item($rowNumber, 6).Value2 = [string]$record.NFSaida
                    $rowNumber++
                }
            }
            finally {
                if ($null -ne $sheet) { [void][Runtime.InteropServices.Marshal]::ReleaseComObject($sheet) }
            }
        }

        try { $excel.CalculateFullRebuild() } catch { try { $excel.CalculateFull() } catch {} }
        $workbook.Save()
        $workbook.Close($true)
        [void][Runtime.InteropServices.Marshal]::ReleaseComObject($workbook)
        $workbook = $null
        $excel.Quit()
        [void][Runtime.InteropServices.Marshal]::ReleaseComObject($excel)
        $excel = $null
        [GC]::Collect(); [GC]::WaitForPendingFinalizers(); [GC]::Collect(); [GC]::WaitForPendingFinalizers()
        return $destinationFull
    }
    catch {
        try { if ($null -ne $workbook) { $workbook.Close($false) } } catch {}
        try { if ($null -ne $workbook) { [void][Runtime.InteropServices.Marshal]::ReleaseComObject($workbook) } } catch {}
        try { if ($null -ne $excel) { $excel.Quit() } } catch {}
        try { if ($null -ne $excel) { [void][Runtime.InteropServices.Marshal]::ReleaseComObject($excel) } } catch {}
        [GC]::Collect(); [GC]::WaitForPendingFinalizers()
        throw
    }
}
