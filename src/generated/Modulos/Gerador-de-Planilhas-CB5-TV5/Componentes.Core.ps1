Set-StrictMode -Version Latest

$script:BillingComponentsCoreVersion = "1.3.0"

function ConvertTo-BillingText {
    param([AllowNull()][object]$Value)
    if ($null -eq $Value) { return "" }
    return ([string]$Value).Trim()
}

function ConvertTo-BillingBoolean {
    param([AllowNull()][object]$Value)
    if ($null -eq $Value) { return $false }
    if ($Value -is [bool]) { return [bool]$Value }
    return ([string]$Value).Trim().ToLowerInvariant() -eq "true"
}

function ConvertTo-BillingInteger {
    param([AllowNull()][object]$Value, [int]$DefaultValue = 0)
    if ($null -eq $Value) { return $DefaultValue }
    $parsed = 0
    if ([int]::TryParse(([string]$Value).Trim(), [ref]$parsed)) { return $parsed }
    return $DefaultValue
}

function ConvertTo-BillingNormalizedText {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return "" }
    $formD = $Text.ToUpperInvariant().Normalize([Text.NormalizationForm]::FormD)
    $builder = New-Object Text.StringBuilder
    foreach ($character in $formD.ToCharArray()) {
        $category = [Globalization.CharUnicodeInfo]::GetUnicodeCategory($character)
        if ($category -ne [Globalization.UnicodeCategory]::NonSpacingMark) {
            [void]$builder.Append($character)
        }
    }
    return ([regex]::Replace($builder.ToString(), '[^A-Z0-9]+', ' ')).Trim()
}

function Get-BillingDefaultDataDirectory {
    $local = [Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData)
    return [IO.Path]::Combine($local, "GeradorPlanilhasCB5TV5")
}

function New-BillingSeedComponent {
    param(
        [string]$Id,
        [ValidateSet("CB5", "TV5")][string]$Product,
        [string]$Component,
        [string]$Name,
        [int]$Balance,
        [string]$OutputCode,
        [string]$RepairText,
        [string[]]$Aliases
    )
    $now = [DateTime]::Now.ToString("s")
    return [pscustomobject]@{
        Id = $Id
        Produto = $Product
        Componente = $Component
        Nome = $Name
        Saldo = $Balance
        CodigoPlanilha = $OutputCode
        TextoReparo = $RepairText
        Apelidos = @($Aliases)
        Ativo = $true
        CriadoEm = $now
        AtualizadoEm = $now
    }
}

function Get-BillingSeedComponents {
    return @(
        (New-BillingSeedComponent "cb5-cn3" "CB5" "CN3" "SICMA" 10 "TSCM" "SICMA" @("CN3")),
        (New-BillingSeedComponent "cb5-cn4" "CB5" "CN4" "CONECTOR USB" 40 "TRCUS" "CONECTOR USB" @("CN4")),
        (New-BillingSeedComponent "cb5-u10" "CB5" "U10" "PROCESSADOR" 33 "TPCSS" "PROCESSADOR" @("U10")),
        (New-BillingSeedComponent "cb5-u4" "CB5" "U4" "MEMÓRIA" 15 "TMF" "MEMÓRIA FLASH" @("U4", "MEMORIA")),
        (New-BillingSeedComponent "cb5-u46-u52" "CB5" "U46/U52" "RS485" 13 "TRS485" "RS485" @("U46", "U52", "U46 U52")),
        (New-BillingSeedComponent "cb5-u31" "CB5" "U31" "RS232" 17 "TRS232" "RS232" @("U31")),
        (New-BillingSeedComponent "cb5-u20" "CB5" "U20" "FONTE" 8 "TRU20" "U20" @("FONTE")),
        (New-BillingSeedComponent "cb5-u40" "CB5" "U40" "NOME NÃO INFORMADO" 3 "" "U40" @()),
        (New-BillingSeedComponent "tv5-cn1" "TV5" "CN1" "CONECTOR LCD" 5 "TRCNL" "CN1" @("CONECTOR LCD", "CONECTOR DO LCD")),
        (New-BillingSeedComponent "tv5-r25" "TV5" "R25" "RESISTOR" 0 "TR" "R25" @("R", "RESISTOR")),
        (New-BillingSeedComponent "tv5-u4" "TV5" "U4" "PROCESSADOR" 0 "TPRC" "U4" @("PROCESSADOR")),
        (New-BillingSeedComponent "tv5-u15" "TV5" "U15" "FONTE" 0 "TCI" "U15" @("U", "FONTE")),
        (New-BillingSeedComponent "tv5-cn8" "TV5" "CN8" "CONECTOR DO CABO" 50 "TRCNC" "CN8" @("CONECTOR DO CABO")),
        (New-BillingSeedComponent "tv5-cn5-cn6" "TV5" "CN5/CN6" "CONECTOR SPEAKER" 6 "ADCS" "CN5 CN6" @("CN5", "CN6", "CONECTOR SPEAKER", "CONECTOR DO SPEAKER")),
        (New-BillingSeedComponent "tv5-u13" "TV5" "U13" "RS485" 4 "TRS485" "U13" @("RS485")),
        (New-BillingSeedComponent "tv5-x2" "TV5" "X2" "CLOCK" 2 "TRCTL" "X2" @("X", "CLOCK", "CRISTAL")),
        (New-BillingSeedComponent "tv5-q1" "TV5" "Q1" "BUZZER" 0 "TBZ" "Q1" @("BUZZER")),
        (New-BillingSeedComponent "tv5-cn2" "TV5" "CN2" "CONECTOR USB" 0 "TRCUS" "CN2" @("CONECTOR USB"))
    )
}

function New-BillingComponentStore {
    $now = [DateTime]::Now.ToString("s")
    $store = [pscustomobject]@{
        SchemaVersion = 3
        AppVersion = $script:BillingComponentsCoreVersion
        CriadoEm = $now
        AtualizadoEm = $now
        Componentes = @(Get-BillingSeedComponents)
        Movimentos = @()
        Operacoes = @()
    }
    foreach ($component in @($store.Componentes | Where-Object { (ConvertTo-BillingInteger $_.Saldo) -gt 0 })) {
        $balance = ConvertTo-BillingInteger $component.Saldo
        [void](Add-BillingMovement $store $component "Saldo inicial" $balance 0 $balance -Observation "Saldo inicial importado da planilha MANUTENÇÃO CB5 - TV5.")
    }
    return $store
}

function Add-BillingMissingProperty {
    param([object]$Object, [string]$Name, [AllowNull()][object]$Value)
    if (-not ($Object.PSObject.Properties.Name -contains $Name)) {
        $Object | Add-Member -NotePropertyName $Name -NotePropertyValue $Value
    }
}

function Normalize-BillingComponentStore {
    param([AllowNull()][object]$Store)
    if ($null -eq $Store) { return New-BillingComponentStore }

    Add-BillingMissingProperty $Store "SchemaVersion" 1
    Add-BillingMissingProperty $Store "AppVersion" $script:BillingComponentsCoreVersion
    Add-BillingMissingProperty $Store "CriadoEm" ([DateTime]::Now.ToString("s"))
    Add-BillingMissingProperty $Store "AtualizadoEm" ([DateTime]::Now.ToString("s"))
    Add-BillingMissingProperty $Store "Componentes" @()
    Add-BillingMissingProperty $Store "Movimentos" @()
    Add-BillingMissingProperty $Store "Operacoes" @()

    $Store.Componentes = @($Store.Componentes)
    $Store.Movimentos = @($Store.Movimentos)
    $Store.Operacoes = @($Store.Operacoes)
    foreach ($component in @($Store.Componentes)) {
        Add-BillingMissingProperty $component "Id" ([Guid]::NewGuid().ToString("N"))
        Add-BillingMissingProperty $component "Produto" "CB5"
        Add-BillingMissingProperty $component "Componente" ""
        Add-BillingMissingProperty $component "Nome" ""
        Add-BillingMissingProperty $component "Saldo" 0
        Add-BillingMissingProperty $component "CodigoPlanilha" ""
        Add-BillingMissingProperty $component "TextoReparo" ([string]$component.Componente)
        Add-BillingMissingProperty $component "Apelidos" @()
        Add-BillingMissingProperty $component "Ativo" $true
        Add-BillingMissingProperty $component "CriadoEm" ([DateTime]::Now.ToString("s"))
        Add-BillingMissingProperty $component "AtualizadoEm" ([DateTime]::Now.ToString("s"))
        $component.Produto = (ConvertTo-BillingText $component.Produto).ToUpperInvariant()
        $component.Componente = (ConvertTo-BillingText $component.Componente).ToUpperInvariant()
        $component.Nome = ConvertTo-BillingText $component.Nome
        $component.Saldo = ConvertTo-BillingInteger $component.Saldo
        $component.CodigoPlanilha = (ConvertTo-BillingText $component.CodigoPlanilha).ToUpperInvariant()
        $component.TextoReparo = ConvertTo-BillingText $component.TextoReparo
        $component.Apelidos = @($component.Apelidos | ForEach-Object { ConvertTo-BillingText $_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        $component.Ativo = ConvertTo-BillingBoolean $component.Ativo
    }
    foreach ($operation in @($Store.Operacoes)) {
        Add-BillingMissingProperty $operation "Id" ([Guid]::NewGuid().ToString("N"))
        Add-BillingMissingProperty $operation "Em" ([DateTime]::Now.ToString("s"))
        Add-BillingMissingProperty $operation "Produto" "CB5"
        Add-BillingMissingProperty $operation "ChaveOperacao" ""
        Add-BillingMissingProperty $operation "NF" ""
        Add-BillingMissingProperty $operation "Lotes" @()
        Add-BillingMissingProperty $operation "Baixas" @()
        Add-BillingMissingProperty $operation "QuantidadeTotal" 0
        # Operações gravadas antes da v1.3.0 sempre usavam a baixa automática.
        Add-BillingMissingProperty $operation "ConsumirSaldo" $true
        $operation.Produto = (ConvertTo-BillingText $operation.Produto).ToUpperInvariant()
        $operation.Lotes = @($operation.Lotes | ForEach-Object { ConvertTo-BillingText $_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        $operation.Baixas = @($operation.Baixas)
        $operation.QuantidadeTotal = ConvertTo-BillingInteger $operation.QuantidadeTotal
        $operation.ConsumirSaldo = ConvertTo-BillingBoolean $operation.ConsumirSaldo
    }
    $Store.SchemaVersion = 3
    $Store.AppVersion = $script:BillingComponentsCoreVersion
    return $Store
}

function Write-BillingComponentStore {
    param(
        [Parameter(Mandatory = $true)][object]$Store,
        [Parameter(Mandatory = $true)][string]$Path
    )
    $directory = [IO.Path]::GetDirectoryName($Path)
    if (-not [IO.Directory]::Exists($directory)) { [void][IO.Directory]::CreateDirectory($directory) }
    $Store.SchemaVersion = 3
    $Store.AppVersion = $script:BillingComponentsCoreVersion
    $Store.AtualizadoEm = [DateTime]::Now.ToString("s")
    $json = $Store | ConvertTo-Json -Depth 12
    $tempPath = $Path + ".tmp"
    $backupPath = $Path + ".swap-backup"
    $encoding = [Text.UTF8Encoding]::new($true)
    try {
        [IO.File]::WriteAllText($tempPath, $json, $encoding)
        if ([IO.File]::Exists($Path)) {
            if ([IO.File]::Exists($backupPath)) { [IO.File]::Delete($backupPath) }
            [IO.File]::Replace($tempPath, $Path, $backupPath)
            if ([IO.File]::Exists($backupPath)) { [IO.File]::Delete($backupPath) }
        }
        else {
            [IO.File]::Move($tempPath, $Path)
        }
    }
    catch {
        if (-not [IO.File]::Exists($Path) -and [IO.File]::Exists($backupPath)) { [IO.File]::Move($backupPath, $Path) }
        if ([IO.File]::Exists($tempPath)) { [IO.File]::Delete($tempPath) }
        throw
    }
}

function Initialize-BillingComponentStore {
    param(
        [string]$DataDirectory = (Get-BillingDefaultDataDirectory),
        [string]$FileName = "componentes-a-faturar.json"
    )
    if (-not [IO.Directory]::Exists($DataDirectory)) { [void][IO.Directory]::CreateDirectory($DataDirectory) }
    $path = [IO.Path]::Combine($DataDirectory, $FileName)
    if (-not [IO.File]::Exists($path)) { Write-BillingComponentStore -Store (New-BillingComponentStore) -Path $path }
    return $path
}

function Read-BillingComponentStore {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not [IO.File]::Exists($Path)) { throw "A base de componentes a faturar não foi encontrada: $Path" }
    try {
        $raw = [IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8)
        if ([string]::IsNullOrWhiteSpace($raw)) { return New-BillingComponentStore }
        return Normalize-BillingComponentStore ($raw | ConvertFrom-Json)
    }
    catch {
        throw "Não foi possível ler a base de componentes a faturar. O arquivo foi preservado. Detalhe: $($_.Exception.Message)"
    }
}

function Copy-BillingComponentStore {
    param([Parameter(Mandatory = $true)][object]$Store)
    return Normalize-BillingComponentStore (($Store | ConvertTo-Json -Depth 12) | ConvertFrom-Json)
}

function Get-BillingComponents {
    param(
        [Parameter(Mandatory = $true)][object]$Store,
        [ValidateSet("", "CB5", "TV5")][string]$Product = "",
        [switch]$IncludeInactive
    )
    $items = @($Store.Componentes)
    if (-not [string]::IsNullOrWhiteSpace($Product)) { $items = @($items | Where-Object { [string]$_.Produto -eq $Product }) }
    if (-not $IncludeInactive) { $items = @($items | Where-Object { ConvertTo-BillingBoolean $_.Ativo }) }
    return @($items | Sort-Object Produto, Componente)
}

function Test-BillingComponentMatchesSearch {
    param(
        [Parameter(Mandatory = $true)][object]$Component,
        [string]$SearchText = ""
    )
    $query = ConvertTo-BillingNormalizedText $SearchText
    if ([string]::IsNullOrWhiteSpace($query)) { return $true }

    $fieldTokens = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($field in @(
        [string]$Component.Componente,
        [string]$Component.Nome,
        [string]$Component.CodigoPlanilha,
        [string]$Component.TextoReparo
    ) + @($Component.Apelidos)) {
        foreach ($token in @((ConvertTo-BillingNormalizedText ([string]$field)) -split '\s+' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })) {
            [void]$fieldTokens.Add($token)
        }
    }

    foreach ($queryToken in @($query -split '\s+' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })) {
        $matched = $false
        foreach ($fieldToken in $fieldTokens) {
            if ([string]::Equals($fieldToken, $queryToken, [StringComparison]::OrdinalIgnoreCase) -or
                ($queryToken.Length -ge 3 -and $fieldToken.StartsWith($queryToken, [StringComparison]::OrdinalIgnoreCase))) {
                $matched = $true
                break
            }
        }
        if (-not $matched) { return $false }
    }
    return $true
}

function Get-BillingDashboardSummary {
    param(
        [Parameter(Mandatory = $true)][object]$Store,
        [ValidateSet("", "CB5", "TV5")][string]$Product = ""
    )
    $components = @(Get-BillingComponents $Store $Product -IncludeInactive)
    $activeCount = @($components | Where-Object { ConvertTo-BillingBoolean $_.Ativo }).Count
    $pendingUnits = 0
    foreach ($component in $components) { $pendingUnits += ConvertTo-BillingInteger $component.Saldo }
    $operations = @($Store.Operacoes)
    if (-not [string]::IsNullOrWhiteSpace($Product)) {
        $operations = @($operations | Where-Object { [string]$_.Produto -eq $Product })
    }
    return [pscustomobject]@{
        Componentes = $components.Count
        Ativos = $activeCount
        Inativos = ($components.Count - $activeCount)
        UnidadesPendentes = $pendingUnits
        UnioesProcessadas = $operations.Count
    }
}

function Get-BillingComponentById {
    param([Parameter(Mandatory = $true)][object]$Store, [Parameter(Mandatory = $true)][string]$Id)
    return $Store.Componentes | Where-Object { [string]$_.Id -eq $Id } | Select-Object -First 1
}

function Add-BillingMovement {
    param(
        [Parameter(Mandatory = $true)][object]$Store,
        [Parameter(Mandatory = $true)][object]$Component,
        [Parameter(Mandatory = $true)][string]$Type,
        [Parameter(Mandatory = $true)][int]$Change,
        [Parameter(Mandatory = $true)][int]$PreviousBalance,
        [Parameter(Mandatory = $true)][int]$NewBalance,
        [string]$OperationKey = "",
        [string]$Invoice = "",
        [string[]]$Lots = @(),
        [string]$Observation = ""
    )
    $movement = [pscustomobject]@{
        Id = [Guid]::NewGuid().ToString("N")
        Em = [DateTime]::Now.ToString("s")
        Produto = [string]$Component.Produto
        ComponenteId = [string]$Component.Id
        Componente = [string]$Component.Componente
        Nome = [string]$Component.Nome
        Tipo = $Type
        Variacao = $Change
        SaldoAnterior = $PreviousBalance
        SaldoPosterior = $NewBalance
        ChaveOperacao = $OperationKey
        NF = $Invoice
        Lotes = @($Lots)
        Observacao = $Observation
    }
    $Store.Movimentos = @($Store.Movimentos) + @($movement)
    return $movement
}

function Add-BillingComponent {
    param(
        [Parameter(Mandatory = $true)][object]$Store,
        [ValidateSet("CB5", "TV5")][string]$Product,
        [Parameter(Mandatory = $true)][string]$Component,
        [Parameter(Mandatory = $true)][string]$Name,
        [int]$InitialBalance = 0,
        [string]$OutputCode = "",
        [string]$RepairText = "",
        [string[]]$Aliases = @()
    )
    $componentText = (ConvertTo-BillingText $Component).ToUpperInvariant()
    $nameText = ConvertTo-BillingText $Name
    if ([string]::IsNullOrWhiteSpace($componentText)) { throw "Informe o componente." }
    if ([string]::IsNullOrWhiteSpace($nameText)) { throw "Informe o nome do componente." }
    if ($InitialBalance -lt 0) { throw "O saldo inicial não pode ser negativo." }
    $duplicate = $Store.Componentes | Where-Object { [string]$_.Produto -eq $Product -and [string]$_.Componente -eq $componentText } | Select-Object -First 1
    if ($null -ne $duplicate) { throw "O componente $componentText já está cadastrado para $Product." }
    if ([string]::IsNullOrWhiteSpace($RepairText)) { $RepairText = $componentText }
    $now = [DateTime]::Now.ToString("s")
    $record = [pscustomobject]@{
        Id = [Guid]::NewGuid().ToString("N")
        Produto = $Product
        Componente = $componentText
        Nome = $nameText
        Saldo = $InitialBalance
        CodigoPlanilha = (ConvertTo-BillingText $OutputCode).ToUpperInvariant()
        TextoReparo = ConvertTo-BillingText $RepairText
        Apelidos = @($Aliases | ForEach-Object { ConvertTo-BillingText $_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        Ativo = $true
        CriadoEm = $now
        AtualizadoEm = $now
    }
    $Store.Componentes = @($Store.Componentes) + @($record)
    if ($InitialBalance -gt 0) {
        [void](Add-BillingMovement $Store $record "Saldo inicial" $InitialBalance 0 $InitialBalance -Observation "Componente cadastrado manualmente.")
    }
    return $record
}

function Update-BillingComponent {
    param(
        [Parameter(Mandatory = $true)][object]$Store,
        [Parameter(Mandatory = $true)][string]$Id,
        [Parameter(Mandatory = $true)][string]$Name,
        [string]$OutputCode = "",
        [string]$RepairText = "",
        [string[]]$Aliases = @(),
        [bool]$Active = $true
    )
    $component = Get-BillingComponentById $Store $Id
    if ($null -eq $component) { throw "O componente selecionado não existe mais." }
    $nameText = ConvertTo-BillingText $Name
    if ([string]::IsNullOrWhiteSpace($nameText)) { throw "Informe o nome do componente." }
    if ([string]::IsNullOrWhiteSpace($RepairText)) { $RepairText = [string]$component.Componente }
    $component.Nome = $nameText
    $component.CodigoPlanilha = (ConvertTo-BillingText $OutputCode).ToUpperInvariant()
    $component.TextoReparo = ConvertTo-BillingText $RepairText
    $component.Apelidos = @($Aliases | ForEach-Object { ConvertTo-BillingText $_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $component.Ativo = $Active
    $component.AtualizadoEm = [DateTime]::Now.ToString("s")
    return $component
}

function Add-BillingManualQuantity {
    param(
        [Parameter(Mandatory = $true)][object]$Store,
        [Parameter(Mandatory = $true)][string]$Id,
        [Parameter(Mandatory = $true)][int]$Quantity,
        [string]$Observation = ""
    )
    if ($Quantity -le 0) { throw "A quantidade lançada deve ser maior que zero." }
    $component = Get-BillingComponentById $Store $Id
    if ($null -eq $component) { throw "O componente selecionado não existe mais." }
    $before = ConvertTo-BillingInteger $component.Saldo
    $after = $before + $Quantity
    $component.Saldo = $after
    $component.AtualizadoEm = [DateTime]::Now.ToString("s")
    return Add-BillingMovement $Store $component "Lançamento manual" $Quantity $before $after -Observation $Observation
}

function Set-BillingManualBalance {
    param(
        [Parameter(Mandatory = $true)][object]$Store,
        [Parameter(Mandatory = $true)][string]$Id,
        [Parameter(Mandatory = $true)][int]$NewBalance,
        [string]$Observation = ""
    )
    if ($NewBalance -lt 0) { throw "O saldo não pode ser negativo." }
    $component = Get-BillingComponentById $Store $Id
    if ($null -eq $component) { throw "O componente selecionado não existe mais." }
    $before = ConvertTo-BillingInteger $component.Saldo
    $change = $NewBalance - $before
    $component.Saldo = $NewBalance
    $component.AtualizadoEm = [DateTime]::Now.ToString("s")
    return Add-BillingMovement $Store $component "Ajuste manual" $change $before $NewBalance -Observation $Observation
}

function Test-BillingComponentInRepair {
    param([Parameter(Mandatory = $true)][object]$Component, [string]$Repair)
    $normalizedRepair = ConvertTo-BillingNormalizedText $Repair
    if ([string]::IsNullOrWhiteSpace($normalizedRepair)) { return $false }
    $candidates = [Collections.Generic.List[string]]::new()
    foreach ($candidate in @($Component.Componente, $Component.TextoReparo, $Component.Nome) + @($Component.Apelidos)) {
        $normalized = ConvertTo-BillingNormalizedText ([string]$candidate)
        if (-not [string]::IsNullOrWhiteSpace($normalized) -and -not $candidates.Contains($normalized)) { $candidates.Add($normalized) }
    }
    foreach ($candidate in $candidates) {
        $escaped = [regex]::Escape($candidate) -replace '\\ ', '\s+'
        if ($normalizedRepair -match "(?<![A-Z0-9])$escaped(?![A-Z0-9])") { return $true }
    }
    return $false
}

function ConvertTo-BillingRepairPart {
    param([string]$RepairPart)
    $text = ConvertTo-BillingNormalizedText $RepairPart
    foreach ($prefix in @("TROCA DE", "TROCADO", "TROCADA", "TROCA", "ADICIONADO", "ADICIONADA")) {
        if ($text -eq $prefix) { return "" }
        if ($text.StartsWith($prefix + " ", [StringComparison]::Ordinal)) {
            return $text.Substring($prefix.Length).Trim()
        }
    }
    return $text
}

function Get-BillingComponentForRepairPart {
    param(
        [Parameter(Mandatory = $true)][object]$Store,
        [ValidateSet("CB5", "TV5")][string]$Product,
        [Parameter(Mandatory = $true)][string]$RepairPart
    )
    $part = (ConvertTo-BillingRepairPart $RepairPart) -replace ' ', ''
    if ([string]::IsNullOrWhiteSpace($part)) { return $null }

    $matches = [Collections.Generic.List[object]]::new()
    foreach ($component in @(Get-BillingComponents $Store $Product)) {
        $score = 0
        $componentKey = (ConvertTo-BillingNormalizedText ([string]$component.Componente)) -replace ' ', ''
        $repairKey = (ConvertTo-BillingNormalizedText ([string]$component.TextoReparo)) -replace ' ', ''
        $nameKey = (ConvertTo-BillingNormalizedText ([string]$component.Nome)) -replace ' ', ''
        if ($componentKey -eq $part) { $score = 4 }
        elseif ($repairKey -eq $part) { $score = 3 }
        else {
            foreach ($alias in @($component.Apelidos)) {
                if (((ConvertTo-BillingNormalizedText ([string]$alias)) -replace ' ', '') -eq $part) {
                    $score = 2
                    break
                }
            }
            if ($score -eq 0 -and $nameKey -eq $part) { $score = 1 }
        }
        if ($score -gt 0) { $matches.Add([pscustomobject]@{ Score = $score; Component = $component }) }
    }
    if ($matches.Count -eq 0) { return $null }
    $bestScore = [int](($matches | Measure-Object Score -Maximum).Maximum)
    $best = @($matches | Where-Object { $_.Score -eq $bestScore })
    if ($best.Count -gt 1) {
        $components = @($best | ForEach-Object { [string]$_.Component.Componente }) -join ", "
        throw "A indicação '$RepairPart' corresponde a mais de um componente $Product ($components). Edite o texto ou os apelidos em Componentes a faturar."
    }
    return $best[0].Component
}

function Get-BillingOperationKey {
    param(
        [ValidateSet("CB5", "TV5")][string]$Product,
        [Parameter(Mandatory = $true)][string]$Invoice,
        [Parameter(Mandatory = $true)][string[]]$Lots
    )
    $normalizedLots = @($Lots | ForEach-Object { (ConvertTo-BillingNormalizedText $_) -replace ' ', '' } | Sort-Object -Unique)
    if ($normalizedLots.Count -eq 0) { throw "Informe pelo menos um lote para identificar a união." }
    # A NF não participa da chave: os mesmos lotes não podem baixar o saldo outra
    # vez apenas porque o arquivo foi renomeado ou a NF foi corrigida.
    $source = "$Product|$($normalizedLots -join ',')"
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [Text.Encoding]::UTF8.GetBytes($source)
        return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace("-", "").ToLowerInvariant()
    }
    finally { $sha.Dispose() }
}

function Test-BillingOperationApplied {
    param([Parameter(Mandatory = $true)][object]$Store, [Parameter(Mandatory = $true)][string]$OperationKey)
    if (@($Store.Operacoes | Where-Object { [string]$_.ChaveOperacao -eq $OperationKey }).Count -gt 0) { return $true }
    # Compatibilidade com uma base experimental anterior, que registrava a chave
    # somente nas linhas individuais de baixa.
    return @($Store.Movimentos | Where-Object { [string]$_.Tipo -eq "Baixa automática" -and [string]$_.ChaveOperacao -eq $OperationKey }).Count -gt 0
}

function Get-BillingDeductionPlan {
    param(
        [Parameter(Mandatory = $true)][object]$Store,
        [ValidateSet("CB5", "TV5")][string]$Product,
        [Parameter(Mandatory = $true)][object[]]$Items,
        [Parameter(Mandatory = $true)][string]$OperationKey
    )
    if (Test-BillingOperationApplied $Store $OperationKey) {
        return [pscustomobject]@{ Produto = $Product; Valido = $true; JaAplicada = $true; ConsumirSaldo = $true; Linhas = @(); Erros = @() }
    }
    $quantities = @{}
    foreach ($item in @($Items)) {
        $seenOnItem = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        foreach ($part in @(([string]$item.Repair).Split(','))) {
            $component = Get-BillingComponentForRepairPart -Store $Store -Product $Product -RepairPart $part
            if ($null -eq $component) { continue }
            $componentId = [string]$component.Id
            if (-not $seenOnItem.Add($componentId)) { continue }
            if (-not $quantities.ContainsKey($componentId)) { $quantities[$componentId] = 0 }
            $quantities[$componentId] = [int]$quantities[$componentId] + 1
        }
    }

    $rows = [Collections.Generic.List[object]]::new()
    $errors = [Collections.Generic.List[string]]::new()
    foreach ($component in @(Get-BillingComponents $Store $Product)) {
        $quantity = if ($quantities.ContainsKey([string]$component.Id)) { [int]$quantities[[string]$component.Id] } else { 0 }
        if ($quantity -le 0) { continue }
        $before = ConvertTo-BillingInteger $component.Saldo
        $after = $before - $quantity
        if ($after -lt 0) {
            $errors.Add("$Product $($component.Componente) — $($component.Nome): precisa baixar $quantity, mas o saldo a faturar é $before.")
        }
        $rows.Add([pscustomobject]@{
            ComponenteId = [string]$component.Id
            Produto = [string]$component.Produto
            Componente = [string]$component.Componente
            Nome = [string]$component.Nome
            Quantidade = $quantity
            SaldoAnterior = $before
            SaldoPosterior = $after
        })
    }
    return [pscustomobject]@{ Produto = $Product; Valido = ($errors.Count -eq 0); JaAplicada = $false; ConsumirSaldo = $true; Linhas = $rows.ToArray(); Erros = $errors.ToArray() }
}

function Get-BillingNoDeductionPlan {
    param(
        [Parameter(Mandatory = $true)][object]$Store,
        [ValidateSet("CB5", "TV5")][string]$Product,
        [Parameter(Mandatory = $true)][string]$OperationKey
    )
    return [pscustomobject]@{
        Produto = $Product
        Valido = $true
        JaAplicada = (Test-BillingOperationApplied $Store $OperationKey)
        ConsumirSaldo = $false
        Linhas = @()
        Erros = @()
    }
}

function Add-BillingCompletedOperation {
    param(
        [Parameter(Mandatory = $true)][object]$Store,
        [Parameter(Mandatory = $true)][object]$Plan,
        [Parameter(Mandatory = $true)][string]$OperationKey,
        [Parameter(Mandatory = $true)][string]$Invoice,
        [Parameter(Mandatory = $true)][string[]]$Lots
    )
    $consumeBalance = $true
    if ($Plan.PSObject.Properties.Name -contains "ConsumirSaldo") {
        $consumeBalance = ConvertTo-BillingBoolean $Plan.ConsumirSaldo
    }
    $deductions = @()
    if ($consumeBalance) {
        $deductions = @($Plan.Linhas | ForEach-Object {
            [pscustomobject]@{
                ComponenteId = [string]$_.ComponenteId
                Componente = [string]$_.Componente
                Nome = [string]$_.Nome
                Quantidade = ConvertTo-BillingInteger $_.Quantidade
            }
        })
    }
    $quantityTotal = 0
    foreach ($deduction in $deductions) { $quantityTotal += ConvertTo-BillingInteger $deduction.Quantidade }
    $operation = [pscustomobject]@{
        Id = [Guid]::NewGuid().ToString("N")
        Em = [DateTime]::Now.ToString("s")
        Produto = [string]$Plan.Produto
        ChaveOperacao = $OperationKey
        NF = $Invoice
        Lotes = @($Lots | Sort-Object -Unique)
        Baixas = $deductions
        QuantidadeTotal = $quantityTotal
        ConsumirSaldo = $consumeBalance
    }
    $Store.Operacoes = @($Store.Operacoes) + @($operation)
    return $operation
}

function Apply-BillingDeductionPlan {
    param(
        [Parameter(Mandatory = $true)][object]$Store,
        [Parameter(Mandatory = $true)][object]$Plan,
        [Parameter(Mandatory = $true)][string]$OperationKey,
        [Parameter(Mandatory = $true)][string]$Invoice,
        [Parameter(Mandatory = $true)][string[]]$Lots
    )
    if (-not [bool]$Plan.Valido) { throw "A baixa não pode ser aplicada porque há saldo insuficiente." }
    if ([bool]$Plan.JaAplicada -or (Test-BillingOperationApplied $Store $OperationKey)) { return $Store }
    $consumeBalance = $true
    if ($Plan.PSObject.Properties.Name -contains "ConsumirSaldo") {
        $consumeBalance = ConvertTo-BillingBoolean $Plan.ConsumirSaldo
    }
    if ($consumeBalance) {
        foreach ($row in @($Plan.Linhas)) {
            $component = Get-BillingComponentById $Store ([string]$row.ComponenteId)
            if ($null -eq $component) { throw "O componente $($row.Componente) não existe mais no cadastro." }
            $before = ConvertTo-BillingInteger $component.Saldo
            $quantity = ConvertTo-BillingInteger $row.Quantidade
            $after = $before - $quantity
            if ($after -lt 0) { throw "O saldo do componente $($component.Componente) ficou insuficiente antes da gravação." }
            $component.Saldo = $after
            $component.AtualizadoEm = [DateTime]::Now.ToString("s")
            [void](Add-BillingMovement $Store $component "Baixa automática" (-1 * $quantity) $before $after $OperationKey $Invoice $Lots "Baixa realizada após a união dos lotes.")
        }
    }
    [void](Add-BillingCompletedOperation -Store $Store -Plan $Plan -OperationKey $OperationKey -Invoice $Invoice -Lots $Lots)
    return $Store
}

function Get-BillingMovementRows {
    param(
        [Parameter(Mandatory = $true)][object]$Store,
        [ValidateSet("", "CB5", "TV5")][string]$Product = "",
        [int]$Limit = 200
    )
    $items = @($Store.Movimentos)
    if (-not [string]::IsNullOrWhiteSpace($Product)) { $items = @($items | Where-Object { [string]$_.Produto -eq $Product }) }
    $items = @($items | Sort-Object @{ Expression = "Em"; Descending = $true })
    if ($Limit -gt 0) { $items = @($items | Select-Object -First $Limit) }
    return $items
}

function Get-BillingOperationRows {
    param(
        [Parameter(Mandatory = $true)][object]$Store,
        [ValidateSet("", "CB5", "TV5")][string]$Product = "",
        [int]$Limit = 200
    )
    $items = @($Store.Operacoes)
    if (-not [string]::IsNullOrWhiteSpace($Product)) {
        $items = @($items | Where-Object { [string]$_.Produto -eq $Product })
    }
    $items = @($items | Sort-Object @{ Expression = "Em"; Descending = $true })
    if ($Limit -gt 0) { $items = @($items | Select-Object -First $Limit) }
    return $items
}

function Get-BillingOperationDetailText {
    param([Parameter(Mandatory = $true)][object]$Operation)
    if (($Operation.PSObject.Properties.Name -contains "ConsumirSaldo") -and -not (ConvertTo-BillingBoolean $Operation.ConsumirSaldo)) {
        return "Sem consumo por escolha"
    }
    $deductions = @($Operation.Baixas)
    if ($deductions.Count -eq 0) { return "Sem componentes controlados" }
    return (@($deductions | ForEach-Object {
        "$([string]$_.Componente): -$(ConvertTo-BillingInteger $_.Quantidade)"
    }) -join "; ")
}
