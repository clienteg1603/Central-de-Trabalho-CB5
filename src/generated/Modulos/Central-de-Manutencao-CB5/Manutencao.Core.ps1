Set-StrictMode -Version Latest

$script:CB5CoreVersion = "0.4.0"

function ConvertTo-CB5Text {
    param([object]$Value)
    if ($null -eq $Value) { return "" }
    return [string]$Value
}

function ConvertTo-CB5Boolean {
    param([object]$Value)
    if ($null -eq $Value) { return $false }
    if ($Value -is [bool]) { return [bool]$Value }
    return ([string]$Value).Trim().ToLowerInvariant() -eq "true"
}

function ConvertTo-CB5VersionFamily {
    param([string]$Version)

    $value = (ConvertTo-CB5Text $Version).Trim()
    switch ($value) {
        { @("5.00", "5.01", "5.02", "5.03", "5.04", "5.05", "5.00/5.05") -contains $_ } { return "5.00/5.05" }
        { @("5.10", "5.11", "5.10/5.11") -contains $_ } { return "5.10/5.11" }
        { @("5.30", "5.31", "5.32", "5.30/31/32", "5.30/5.31/5.32") -contains $_ } { return "5.30/31/32" }
        { @("5.40", "5.41", "5.40/5.41") -contains $_ } { return "5.40/5.41" }
        default { return $value }
    }
}

function Get-CB5Value {
    param(
        [hashtable]$Values,
        [string]$Name,
        [object]$DefaultValue = $null
    )
    if ($Values.ContainsKey($Name)) { return $Values[$Name] }
    return $DefaultValue
}

function Get-CB5VersionCatalog {
    return @(
        "5.00/5.05", "5.06",
        "5.10/5.11", "5.12",
        "5.20", "5.22",
        "5.30/31/32",
        "5.40/5.41",
        "5.50", "5.52", "5.53", "5.54",
        "5.60", "5.62", "5.70", "5.72", "5.80", "5.82"
    )
}

function Get-CB5CodeCatalog {
    return @("800", "850", "100")
}

function Get-CB5StatusCatalog {
    return @(
        "Em aberto",
        "Aprovado",
        "PT"
    )
}

function Get-CB5FinalResultCatalog {
    return @("Aprovado", "PT")
}

function Get-CB5ForwardCatalog {
    return @(
        "Não necessário",
        "Setor responsável — modem 4G",
        "Setor responsável — modem 4G + Bluetooth",
        "Setor responsável — modem 4G + Bluetooth + LoRa",
        "Empresa garantidora",
        "Outro encaminhamento"
    )
}

function Get-CB5UpdateRules {
    $rules = New-Object System.Collections.Generic.List[object]

    $rules.Add([pscustomobject]@{
        Origem = "5.00/5.05"
        Destino = "5.06"
        Componentes = "modem 4G"
        Encaminhamento = "Setor responsável — modem 4G"
        CondicionalAoModem = $false
        Observacao = "Família 5.00 até 5.05: atualização com troca de modem 4G em outro setor."
    })

    $rules.Add([pscustomobject]@{
        Origem = "5.10/5.11"
        Destino = "5.12"
        Componentes = "modem 4G"
        Encaminhamento = "Setor responsável — modem 4G"
        CondicionalAoModem = $false
        Observacao = "Atualização com troca de modem 4G em outro setor."
    })

    $rules.Add([pscustomobject]@{
        Origem = "5.20"
        Destino = "5.22"
        Componentes = "modem 4G"
        Encaminhamento = "Setor responsável — modem 4G"
        CondicionalAoModem = $false
        Observacao = "Atualização com troca de modem 4G em outro setor."
    })

    $rules.Add([pscustomobject]@{
        Origem = "5.30/31/32"
        Destino = "5.53"
        Componentes = "modem 4G + Bluetooth + LoRa"
        Encaminhamento = "Setor responsável — modem 4G + Bluetooth + LoRa"
        CondicionalAoModem = $false
        Observacao = "Atualização completa executada pelo setor responsável."
    })

    $rules.Add([pscustomobject]@{
        Origem = "5.40/5.41"
        Destino = "5.54"
        Componentes = "modem 4G + Bluetooth"
        Encaminhamento = "Setor responsável — modem 4G + Bluetooth"
        CondicionalAoModem = $false
        Observacao = "Atualização com modem 4G e Bluetooth em outro setor."
    })

    $rules.Add([pscustomobject]@{
        Origem = "5.50"
        Destino = "5.52"
        Componentes = "modem 4G"
        Encaminhamento = "Setor responsável — modem 4G"
        CondicionalAoModem = $false
        Observacao = "Atualização com troca de modem 4G em outro setor."
    })

    foreach ($pair in @(
        @("5.60", "5.62"),
        @("5.70", "5.72"),
        @("5.80", "5.82")
    )) {
        $rules.Add([pscustomobject]@{
            Origem = $pair[0]
            Destino = $pair[1]
            Componentes = "modem 4G"
            Encaminhamento = "Setor responsável — modem 4G"
            CondicionalAoModem = $true
            Observacao = "Aplicar somente quando o defeito no modem estiver confirmado; esta versão já sai com modem 4G."
        })
    }

    return $rules.ToArray()
}

function Get-CB5UpdateRule {
    param(
        [string]$Version,
        [bool]$ModemDefectConfirmed = $false
    )

    $normalizedVersion = ConvertTo-CB5VersionFamily $Version
    $rule = Get-CB5UpdateRules | Where-Object { $_.Origem -eq $normalizedVersion } | Select-Object -First 1
    if ($null -eq $rule) {
        return [pscustomobject]@{
            Encontrada = $false
            AplicavelAgora = $false
            Origem = $normalizedVersion
            Destino = $normalizedVersion
            Componentes = ""
            Encaminhamento = "Não necessário"
            CondicionalAoModem = $false
            Observacao = "Nenhuma atualização automática cadastrada para esta versão."
        }
    }

    $applies = (-not [bool]$rule.CondicionalAoModem) -or $ModemDefectConfirmed
    return [pscustomobject]@{
        Encontrada = $true
        AplicavelAgora = $applies
        Origem = [string]$rule.Origem
        Destino = [string]$rule.Destino
        Componentes = [string]$rule.Componentes
        Encaminhamento = [string]$rule.Encaminhamento
        CondicionalAoModem = [bool]$rule.CondicionalAoModem
        Observacao = [string]$rule.Observacao
    }
}

function Test-CB5Serial {
    param([string]$Serial)
    return (-not [string]::IsNullOrWhiteSpace($Serial)) -and ($Serial -match '^\d{8}$')
}

function Test-CB5WorkDate {
    param(
        [string]$Code,
        [datetime]$Date
    )
    if ($Code -eq "800") { return $true }
    if (@("850", "100") -contains $Code) {
        return $Date.Day -ge 1 -and $Date.Day -le 20
    }
    return $false
}

function Get-CB5DefaultDataDirectory {
    $local = [Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData)
    return [IO.Path]::Combine($local, "CentralDeTrabalho", "ManutencaoCB5")
}

function New-CB5Store {
    return [pscustomobject]@{
        SchemaVersion = 4
        AppVersion = $script:CB5CoreVersion
        CriadoEm = [DateTime]::Now.ToString("s")
        AtualizadoEm = [DateTime]::Now.ToString("s")
        Passagens = @()
        Esquematicos = @()
    }
}

function Normalize-CB5Store {
    param([object]$Store)

    if ($null -eq $Store) { return New-CB5Store }
    if (-not ($Store.PSObject.Properties.Name -contains "SchemaVersion")) {
        $Store | Add-Member -NotePropertyName SchemaVersion -NotePropertyValue 4
    }
    if (-not ($Store.PSObject.Properties.Name -contains "AppVersion")) {
        $Store | Add-Member -NotePropertyName AppVersion -NotePropertyValue $script:CB5CoreVersion
    }
    if (-not ($Store.PSObject.Properties.Name -contains "CriadoEm")) {
        $Store | Add-Member -NotePropertyName CriadoEm -NotePropertyValue ([DateTime]::Now.ToString("s"))
    }
    if (-not ($Store.PSObject.Properties.Name -contains "AtualizadoEm")) {
        $Store | Add-Member -NotePropertyName AtualizadoEm -NotePropertyValue ([DateTime]::Now.ToString("s"))
    }
    if (-not ($Store.PSObject.Properties.Name -contains "Passagens") -or $null -eq $Store.Passagens) {
        if ($Store.PSObject.Properties.Name -contains "Passagens") { $Store.Passagens = @() }
        else { $Store | Add-Member -NotePropertyName Passagens -NotePropertyValue @() }
    }
    if (-not ($Store.PSObject.Properties.Name -contains "Esquematicos") -or $null -eq $Store.Esquematicos) {
        if ($Store.PSObject.Properties.Name -contains "Esquematicos") { $Store.Esquematicos = @() }
        else { $Store | Add-Member -NotePropertyName Esquematicos -NotePropertyValue @() }
    }

    $Store.Passagens = @($Store.Passagens)
    $Store.Esquematicos = @($Store.Esquematicos)
    foreach ($record in @($Store.Passagens)) {
        if ($record.PSObject.Properties.Name -contains "VersaoEntrada") {
            $record.VersaoEntrada = ConvertTo-CB5VersionFamily ([string]$record.VersaoEntrada)
        }
        if ($record.PSObject.Properties.Name -contains "VersaoSaida") {
            $record.VersaoSaida = ConvertTo-CB5VersionFamily ([string]$record.VersaoSaida)
        }
        if (-not ($record.PSObject.Properties.Name -contains "ResultadoFinal")) {
            $record | Add-Member -NotePropertyName ResultadoFinal -NotePropertyValue ""
        }
        if (-not ($record.PSObject.Properties.Name -contains "Concluida")) {
            $record | Add-Member -NotePropertyName Concluida -NotePropertyValue $false
        }
        if (-not ($record.PSObject.Properties.Name -contains "Status")) {
            $record | Add-Member -NotePropertyName Status -NotePropertyValue "Em aberto"
        }
        if (-not ($record.PSObject.Properties.Name -contains "Eventos") -or $null -eq $record.Eventos) {
            if ($record.PSObject.Properties.Name -contains "Eventos") { $record.Eventos = @() }
            else { $record | Add-Member -NotePropertyName Eventos -NotePropertyValue @() }
        }
        $record.Eventos = @($record.Eventos)
        foreach ($event in @($record.Eventos)) {
            if (-not ($event.PSObject.Properties.Name -contains "Alteracoes")) {
                $event | Add-Member -NotePropertyName Alteracoes -NotePropertyValue @()
            }
            $event.Alteracoes = @($event.Alteracoes)
        }
        if (ConvertTo-CB5Boolean $record.Concluida) {
            if ([string]$record.ResultadoFinal -eq "Aprovado" -or @("Aprovado — próximo setor", "Aprovado — retornar ao fluxo do CQR") -contains [string]$record.Status) {
                $record.Status = "Aprovado"
            }
        }
        else {
            # Os estados manuais antigos passam a uma única situação automática.
            $record.Status = "Em aberto"
        }
    }
    foreach ($entry in @($Store.Esquematicos)) {
        if ($entry.PSObject.Properties.Name -contains "Versao") {
            $entry.Versao = ConvertTo-CB5VersionFamily ([string]$entry.Versao)
        }
    }
    $Store.SchemaVersion = 4
    $Store.AppVersion = $script:CB5CoreVersion
    return $Store
}

function Initialize-CB5DataStore {
    param(
        [string]$DataDirectory = (Get-CB5DefaultDataDirectory),
        [string]$DatabaseName = "manutencao-cb5.json"
    )

    if (-not [IO.Directory]::Exists($DataDirectory)) {
        [void][IO.Directory]::CreateDirectory($DataDirectory)
    }
    $path = [IO.Path]::Combine($DataDirectory, $DatabaseName)
    $recoveryPath = $path + ".swap-backup"
    if (-not [IO.File]::Exists($path) -and [IO.File]::Exists($recoveryPath)) {
        [IO.File]::Move($recoveryPath, $path)
    }
    if (-not [IO.File]::Exists($path)) {
        Write-CB5Store -Store (New-CB5Store) -Path $path
    }
    return $path
}

function Read-CB5Store {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not [IO.File]::Exists($Path)) {
        throw "O arquivo de dados não foi encontrado: $Path"
    }
    try {
        $raw = [IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8)
        if ([string]::IsNullOrWhiteSpace($raw)) { return New-CB5Store }
        return Normalize-CB5Store ($raw | ConvertFrom-Json)
    }
    catch {
        throw "Não foi possível ler a base da Central de Manutenção. O arquivo foi preservado sem alterações. Detalhe: $($_.Exception.Message)"
    }
}

function Write-CB5Store {
    param(
        [Parameter(Mandatory = $true)][object]$Store,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $directory = [IO.Path]::GetDirectoryName($Path)
    if (-not [IO.Directory]::Exists($directory)) {
        [void][IO.Directory]::CreateDirectory($directory)
    }

    $Store.SchemaVersion = 4
    $Store.AppVersion = $script:CB5CoreVersion
    $Store.AtualizadoEm = [DateTime]::Now.ToString("s")
    $json = $Store | ConvertTo-Json -Depth 15
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

function Get-CB5PassagesBySerial {
    param(
        [object]$Store,
        [string]$Serial
    )
    if (-not (Test-CB5Serial $Serial)) { return @() }
    $matches = $Store.Passagens | Where-Object { [string]$_.Serie -eq $Serial } | Sort-Object -Property @("Passagem", "CriadoEm")
    return @($matches)
}

function Get-CB5PassageById {
    param(
        [object]$Store,
        [string]$Id
    )
    return $Store.Passagens | Where-Object { [string]$_.Id -eq $Id } | Select-Object -First 1
}

function Get-CB5OpenPassageBySerial {
    param(
        [object]$Store,
        [string]$Serial
    )
    return (Get-CB5PassagesBySerial -Store $Store -Serial $Serial |
        Where-Object { -not (ConvertTo-CB5Boolean $_.Concluida) } |
        Select-Object -Last 1)
}

function New-CB5Event {
    param(
        [string]$Type,
        [string]$Description,
        [object[]]$Changes = @()
    )
    return [pscustomobject]@{
        Em = [DateTime]::Now.ToString("s")
        Tipo = $Type
        Descricao = $Description
        Alteracoes = @($Changes)
    }
}

function Get-CB5ValidationResult {
    param(
        [hashtable]$Values,
        [bool]$ForCompletion = $false
    )

    $errors = New-Object System.Collections.Generic.List[string]
    $warnings = New-Object System.Collections.Generic.List[string]
    $serial = ConvertTo-CB5Text (Get-CB5Value $Values "Serie" "")
    $code = ConvertTo-CB5Text (Get-CB5Value $Values "Codigo" "")
    $version = ConvertTo-CB5VersionFamily (ConvertTo-CB5Text (Get-CB5Value $Values "VersaoEntrada" ""))
    $dateValue = Get-CB5Value $Values "DataEntrada" ([DateTime]::Today)
    if ($dateValue -isnot [datetime]) {
        try { $dateValue = [DateTime]::Parse([string]$dateValue) }
        catch { $dateValue = [DateTime]::MinValue }
    }

    if (-not (Test-CB5Serial $serial)) {
        $errors.Add("A série deve conter exatamente 8 dígitos numéricos.")
    }
    if (-not ((Get-CB5CodeCatalog) -contains $code)) {
        $errors.Add("Selecione um código válido: 800, 850 ou 100.")
    }
    elseif (-not (Test-CB5WorkDate -Code $code -Date $dateValue)) {
        $errors.Add("O código $code só pode ser trabalhado entre os dias 1 e 20. A data informada está fora desse período.")
    }
    if (-not ((Get-CB5VersionCatalog) -contains $version)) {
        $errors.Add("Selecione uma versão válida do CB5.")
    }
    if ([string]::IsNullOrWhiteSpace((ConvertTo-CB5Text (Get-CB5Value $Values "DefeitoReportado" "")))) {
        $errors.Add("Informe o defeito reportado.")
    }

    $maintenance = ConvertTo-CB5Text (Get-CB5Value $Values "ManutencaoRealizada" "")
    $finalResult = ConvertTo-CB5Text (Get-CB5Value $Values "ResultadoFinal" "")
    if (-not [string]::IsNullOrWhiteSpace($finalResult) -and -not ((Get-CB5FinalResultCatalog) -contains $finalResult)) {
        $errors.Add("Selecione um resultado final válido.")
    }

    if ($ForCompletion) {
        if ([string]::IsNullOrWhiteSpace($finalResult)) {
            $errors.Add("Selecione o resultado final: Aprovado ou PT.")
        }
        if ([string]::IsNullOrWhiteSpace((ConvertTo-CB5Text (Get-CB5Value $Values "DefeitoEncontrado" "")))) {
            $errors.Add("Informe o defeito encontrado antes de concluir.")
        }
        if ($finalResult -eq "Aprovado" -and [string]::IsNullOrWhiteSpace($maintenance)) {
            $errors.Add("Informe a manutenção realizada antes de concluir como Aprovado.")
        }
    }

    return [pscustomobject]@{
        Valido = ($errors.Count -eq 0)
        Erros = $errors.ToArray()
        Avisos = $warnings.ToArray()
    }
}

function New-CB5Passage {
    param(
        [Parameter(Mandatory = $true)][object]$Store,
        [Parameter(Mandatory = $true)][hashtable]$Values
    )

    $serial = ConvertTo-CB5Text (Get-CB5Value $Values "Serie" "")
    $previous = @(Get-CB5PassagesBySerial -Store $Store -Serial $serial)
    $now = [DateTime]::Now.ToString("s")
    $passageNumber = $previous.Count + 1

    $record = [pscustomobject]@{
        Id = [Guid]::NewGuid().ToString("N")
        Serie = $serial
        Passagem = $passageNumber
        EhRetorno = ($passageNumber -gt 1)
        Codigo = ConvertTo-CB5Text (Get-CB5Value $Values "Codigo" "")
        VersaoEntrada = ConvertTo-CB5VersionFamily (ConvertTo-CB5Text (Get-CB5Value $Values "VersaoEntrada" ""))
        VersaoSaida = ConvertTo-CB5VersionFamily (ConvertTo-CB5Text (Get-CB5Value $Values "VersaoSaida" ""))
        DataEntrada = ([datetime](Get-CB5Value $Values "DataEntrada" ([DateTime]::Today))).ToString("yyyy-MM-dd")
        Status = "Em aberto"
        DefeitoReportado = ConvertTo-CB5Text (Get-CB5Value $Values "DefeitoReportado" "")
        DefeitoEncontrado = ConvertTo-CB5Text (Get-CB5Value $Values "DefeitoEncontrado" "")
        OutrosDefeitos = ConvertTo-CB5Text (Get-CB5Value $Values "OutrosDefeitos" "")
        ManutencaoRealizada = ConvertTo-CB5Text (Get-CB5Value $Values "ManutencaoRealizada" "")
        ResultadoFinal = ConvertTo-CB5Text (Get-CB5Value $Values "ResultadoFinal" "")
        DefeitoModemConfirmado = ConvertTo-CB5Boolean (Get-CB5Value $Values "DefeitoModemConfirmado" $false)
        AtualizacaoIndicada = ConvertTo-CB5Text (Get-CB5Value $Values "AtualizacaoIndicada" "")
        ComponentesExternos = ConvertTo-CB5Text (Get-CB5Value $Values "ComponentesExternos" "")
        Encaminhamento = ConvertTo-CB5Text (Get-CB5Value $Values "Encaminhamento" "Não necessário")
        DataEncaminhamento = ConvertTo-CB5Text (Get-CB5Value $Values "DataEncaminhamento" "")
        DataRetornoSetor = ConvertTo-CB5Text (Get-CB5Value $Values "DataRetornoSetor" "")
        InspecaoVisual = ConvertTo-CB5Boolean (Get-CB5Value $Values "InspecaoVisual" $false)
        TesteAlimentacao = ConvertTo-CB5Boolean (Get-CB5Value $Values "TesteAlimentacao" $false)
        TesteComunicacao = ConvertTo-CB5Boolean (Get-CB5Value $Values "TesteComunicacao" $false)
        PingResultado = ConvertTo-CB5Text (Get-CB5Value $Values "PingResultado" "Não informado")
        PTResultado = ConvertTo-CB5Text (Get-CB5Value $Values "PTResultado" "Não informado")
        OutrosTestes = ConvertTo-CB5Text (Get-CB5Value $Values "OutrosTestes" "")
        Observacoes = ConvertTo-CB5Text (Get-CB5Value $Values "Observacoes" "")
        Concluida = $false
        DataConclusao = ""
        CriadoEm = $now
        AtualizadoEm = $now
        Eventos = @((New-CB5Event -Type "Entrada" -Description "Passagem $passageNumber registrada."))
    }

    $Store.Passagens = @($Store.Passagens) + @($record)
    return $record
}

function Update-CB5Passage {
    param(
        [Parameter(Mandatory = $true)][object]$Store,
        [Parameter(Mandatory = $true)][string]$Id,
        [Parameter(Mandatory = $true)][hashtable]$Values,
        [string]$EventType = "Atualização",
        [string]$EventDescription = "Dados da passagem atualizados."
    )

    $record = Get-CB5PassageById -Store $Store -Id $Id
    if ($null -eq $record) { throw "A passagem selecionada não existe mais na base." }
    if (ConvertTo-CB5Boolean $record.Concluida) { throw "Uma passagem concluída não pode ser sobrescrita. Registre um novo retorno." }

    $fields = @(
        "Codigo", "VersaoEntrada", "VersaoSaida", "DefeitoReportado",
        "DefeitoEncontrado", "OutrosDefeitos", "ManutencaoRealizada", "ResultadoFinal",
        "DefeitoModemConfirmado", "AtualizacaoIndicada", "ComponentesExternos",
        "Encaminhamento", "DataEncaminhamento", "DataRetornoSetor", "InspecaoVisual",
        "TesteAlimentacao", "TesteComunicacao", "PingResultado", "PTResultado",
        "OutrosTestes", "Observacoes"
    )
    $changes = [Collections.Generic.List[object]]::new()
    foreach ($field in $fields) {
        if ($Values.ContainsKey($field)) {
            if (@("VersaoEntrada", "VersaoSaida") -contains $field) {
                $newValue = ConvertTo-CB5VersionFamily ([string]$Values[$field])
            }
            else {
                $newValue = $Values[$field]
            }
            $oldValue = if ($record.PSObject.Properties.Name -contains $field) { $record.$field } else { "" }
            if ((ConvertTo-CB5Text $oldValue) -cne (ConvertTo-CB5Text $newValue)) {
                $changes.Add([pscustomobject]@{ Campo = $field; Antes = ConvertTo-CB5Text $oldValue; Depois = ConvertTo-CB5Text $newValue })
                if ($record.PSObject.Properties.Name -contains $field) { $record.$field = $newValue }
                else { $record | Add-Member -NotePropertyName $field -NotePropertyValue $newValue }
            }
        }
    }
    if ($Values.ContainsKey("DataEntrada")) {
        $newDate = ([datetime]$Values.DataEntrada).ToString("yyyy-MM-dd")
        if ([string]$record.DataEntrada -cne $newDate) {
            $changes.Add([pscustomobject]@{ Campo = "DataEntrada"; Antes = [string]$record.DataEntrada; Depois = $newDate })
            $record.DataEntrada = $newDate
        }
    }
    $record.Status = "Em aberto"

    $record.AtualizadoEm = [DateTime]::Now.ToString("s")
    $events = @($record.Eventos)
    $description = $EventDescription
    if ($changes.Count -gt 0) { $description += " $($changes.Count) campo(s) alterado(s), com valores preservados no evento." }
    else { $description += " Nenhum campo foi modificado." }
    $record.Eventos = $events + @((New-CB5Event -Type $EventType -Description $description -Changes $changes.ToArray()))
    return $record
}

function Get-CB5CompletionStatus {
    param([string]$FinalResult)
    switch ($FinalResult) {
        "Aprovado" { return "Aprovado" }
        "PT" { return "PT" }
        # Compatibilidade exclusiva com registros antigos de Garantia.
        "Defeito de fábrica" { return "Defeito de fábrica" }
        default { return "Concluído" }
    }
}

function Correct-CB5Passage {
    param(
        [Parameter(Mandatory = $true)][object]$Store,
        [Parameter(Mandatory = $true)][string]$Id,
        [Parameter(Mandatory = $true)][hashtable]$Values
    )

    $record = Get-CB5PassageById -Store $Store -Id $Id
    if ($null -eq $record) { throw "A passagem selecionada não existe mais na base." }

    # A série e o número da passagem são a identidade histórica e nunca são
    # reescritos. Os demais dados operacionais podem ser corrigidos com trilha.
    $validationValues = @{}
    foreach ($key in $Values.Keys) { $validationValues[$key] = $Values[$key] }
    $validationValues["Serie"] = [string]$record.Serie
    $validation = Get-CB5ValidationResult -Values $validationValues -ForCompletion:(ConvertTo-CB5Boolean $record.Concluida)
    if (-not [bool]$validation.Valido) {
        throw (@($validation.Erros) -join "`r`n")
    }

    $fieldLabels = @{
        Codigo = "Código"
        VersaoEntrada = "Versão de entrada"
        VersaoSaida = "Versão de saída"
        DataEntrada = "Data de entrada"
        DefeitoReportado = "Defeito reportado"
        DefeitoEncontrado = "Defeito encontrado"
        OutrosDefeitos = "Outros defeitos"
        ManutencaoRealizada = "Manutenção realizada"
        ResultadoFinal = "Resultado final"
        AtualizacaoIndicada = "Atualização indicada"
        ComponentesExternos = "Componentes externos"
        Observacoes = "Observações"
    }
    $fields = @(
        "Codigo", "VersaoEntrada", "VersaoSaida", "DataEntrada",
        "DefeitoReportado", "DefeitoEncontrado", "OutrosDefeitos",
        "ManutencaoRealizada", "ResultadoFinal", "AtualizacaoIndicada",
        "ComponentesExternos", "Observacoes"
    )
    $changes = [Collections.Generic.List[object]]::new()
    foreach ($field in $fields) {
        if (-not $Values.ContainsKey($field)) { continue }
        $newValue = $Values[$field]
        if (@("VersaoEntrada", "VersaoSaida") -contains $field) {
            $newValue = ConvertTo-CB5VersionFamily ([string]$newValue)
        }
        elseif ($field -eq "DataEntrada") {
            $newValue = ([datetime]$newValue).ToString("yyyy-MM-dd")
        }
        else {
            $newValue = ConvertTo-CB5Text $newValue
        }
        $oldValue = ConvertTo-CB5Text $record.$field
        if ($oldValue -ceq (ConvertTo-CB5Text $newValue)) { continue }
        $changes.Add([pscustomobject]@{
            Campo = [string]$fieldLabels[$field]
            Antes = $oldValue
            Depois = ConvertTo-CB5Text $newValue
        })
        $record.$field = $newValue
    }

    if ($changes.Count -eq 0) { throw "Nenhuma alteração foi feita no registro." }
    if (ConvertTo-CB5Boolean $record.Concluida) {
        $record.Status = Get-CB5CompletionStatus ([string]$record.ResultadoFinal)
    }
    else {
        $record.Status = "Em aberto"
    }
    $record.AtualizadoEm = [DateTime]::Now.ToString("s")
    $changeSummary = @($changes | ForEach-Object {
        $before = if ([string]::IsNullOrWhiteSpace([string]$_.Antes)) { "(vazio)" } else { [string]$_.Antes }
        $after = if ([string]::IsNullOrWhiteSpace([string]$_.Depois)) { "(vazio)" } else { [string]$_.Depois }
        "$($_.Campo): $before → $after"
    }) -join "; "
    $record.Eventos = @($record.Eventos) + @((New-CB5Event -Type "Correção" -Description "Registro corrigido sem apagar o histórico: $changeSummary" -Changes $changes.ToArray()))
    return $record
}

function Complete-CB5Passage {
    param(
        [Parameter(Mandatory = $true)][object]$Store,
        [Parameter(Mandatory = $true)][string]$Id,
        [Parameter(Mandatory = $true)][hashtable]$Values
    )

    $record = Update-CB5Passage -Store $Store -Id $Id -Values $Values -EventType "Conclusão" -EventDescription "Passagem concluída e preservada no histórico."
    $record.Concluida = $true
    $record.DataConclusao = [DateTime]::Now.ToString("s")
    $record.Status = Get-CB5CompletionStatus ([string]$record.ResultadoFinal)
    $record.AtualizadoEm = [DateTime]::Now.ToString("s")
    return $record
}

function ConvertTo-CB5NormalizedText {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return "" }

    $formD = $Text.ToLowerInvariant().Normalize([Text.NormalizationForm]::FormD)
    $builder = New-Object Text.StringBuilder
    foreach ($character in $formD.ToCharArray()) {
        $category = [Globalization.CharUnicodeInfo]::GetUnicodeCategory($character)
        if ($category -ne [Globalization.UnicodeCategory]::NonSpacingMark) {
            [void]$builder.Append($character)
        }
    }
    return ([regex]::Replace($builder.ToString(), '[^a-z0-9]+', ' ')).Trim()
}

function Get-CB5Keywords {
    param([string]$Text)
    $ignored = @("para", "com", "sem", "uma", "que", "dos", "das", "por", "nao", "foi", "esta", "esse", "essa", "cb5")
    $normalized = ConvertTo-CB5NormalizedText $Text
    if ([string]::IsNullOrWhiteSpace($normalized)) { return @() }
    return @($normalized.Split(' ') | Where-Object { $_.Length -ge 3 -and $ignored -notcontains $_ } | Select-Object -Unique)
}

function Get-CB5DiagnosticSuggestions {
    param(
        [Parameter(Mandatory = $true)][object]$Store,
        [string]$Version,
        [string]$ReportedDefect,
        [string]$FoundDefect = ""
    )

    $queryWords = @(Get-CB5Keywords ($ReportedDefect + " " + $FoundDefect))
    $buckets = @{}

    foreach ($record in @($Store.Passagens)) {
        if (-not (ConvertTo-CB5Boolean $record.Concluida)) { continue }
        $repair = ConvertTo-CB5Text $record.ManutencaoRealizada
        if ([string]::IsNullOrWhiteSpace($repair)) { continue }

        $score = 0
        $evidence = New-Object System.Collections.Generic.List[string]
        if ((ConvertTo-CB5Text $record.VersaoEntrada) -eq $Version -or (ConvertTo-CB5Text $record.VersaoSaida) -eq $Version) {
            $score += 4
            $evidence.Add("mesma versão")
        }

        $historyWords = @(Get-CB5Keywords ((ConvertTo-CB5Text $record.DefeitoReportado) + " " + (ConvertTo-CB5Text $record.DefeitoEncontrado)))
        $common = @($queryWords | Where-Object { $historyWords -contains $_ } | Select-Object -Unique)
        if ($common.Count -gt 0) {
            $score += [Math]::Min(6, $common.Count * 2)
            $evidence.Add("termos em comum: " + ($common -join ", "))
        }
        if ($score -lt 4) { continue }

        $key = ConvertTo-CB5NormalizedText $repair
        if (-not $buckets.ContainsKey($key)) {
            $buckets[$key] = [pscustomobject]@{
                Reparo = $repair
                DefeitoAssociado = ConvertTo-CB5Text $record.DefeitoEncontrado
                Casos = 0
                Pontos = 0
                Evidencias = New-Object System.Collections.Generic.List[string]
            }
        }
        $bucket = $buckets[$key]
        $bucket.Casos++
        $bucket.Pontos += $score
        foreach ($item in $evidence) {
            if (-not $bucket.Evidencias.Contains($item)) { $bucket.Evidencias.Add($item) }
        }
    }

    $result = New-Object System.Collections.Generic.List[object]
    $ordered = @($buckets.Values | Sort-Object @{Expression = "Casos"; Descending = $true}, @{Expression = "Pontos"; Descending = $true} | Select-Object -First 5)
    foreach ($bucket in $ordered) {
        $level = "amostra inicial"
        if ($bucket.Casos -ge 5) { $level = "recorrência forte no histórico" }
        elseif ($bucket.Casos -ge 3) { $level = "recorrência moderada no histórico" }
        elseif ($bucket.Casos -ge 2) { $level = "mais de um caso semelhante" }

        $result.Add([pscustomobject]@{
            Tipo = "HIPÓTESE"
            ReparoSugerido = [string]$bucket.Reparo
            DefeitoAssociado = [string]$bucket.DefeitoAssociado
            Casos = [int]$bucket.Casos
            Evidencia = (($bucket.Evidencias.ToArray()) -join "; ")
            Nivel = $level
        })
    }
    return $result.ToArray()
}

function Get-CB5Summary {
    param([Parameter(Mandatory = $true)][object]$Store)
    $passages = @($Store.Passagens)
    $uniqueSeries = @($passages | Select-Object -ExpandProperty Serie -Unique)
    $open = @($passages | Where-Object { -not (ConvertTo-CB5Boolean $_.Concluida) })
    $completed = @($passages | Where-Object { ConvertTo-CB5Boolean $_.Concluida })
    $returns = @($passages | Where-Object { ConvertTo-CB5Boolean $_.EhRetorno })
    return [pscustomobject]@{
        Series = $uniqueSeries.Count
        Passagens = $passages.Count
        EmAndamento = $open.Count
        Concluidas = $completed.Count
        Retornos = $returns.Count
    }
}

function Get-CB5StatisticsRows {
    param(
        [Parameter(Mandatory = $true)][object]$Store,
        [ValidateSet("VersaoEntrada", "Codigo", "Status", "ResultadoFinal", "DefeitoEncontrado", "ManutencaoRealizada")][string]$Field
    )

    $passages = @($Store.Passagens)
    $total = $passages.Count
    if ($total -eq 0) { return @() }
    $rows = New-Object System.Collections.Generic.List[object]
    $groups = $passages | Group-Object -Property $Field | Sort-Object @{
        Expression = "Count"
        Descending = $true
    }, @{
        Expression = "Name"
        Descending = $false
    }
    foreach ($group in $groups) {
        $name = [string]$group.Name
        if ([string]::IsNullOrWhiteSpace($name)) { $name = "Não informado" }
        $rows.Add([pscustomobject]@{
            Item = $name
            Quantidade = [int]$group.Count
            Percentual = [Math]::Round(($group.Count * 100.0) / $total, 1)
        })
    }
    return $rows.ToArray()
}

function Add-CB5SchematicEntry {
    param(
        [Parameter(Mandatory = $true)][object]$Store,
        [Parameter(Mandatory = $true)][string]$Version,
        [string]$Designator,
        [Parameter(Mandatory = $true)][string]$FilePath,
        [string]$Page,
        [string]$Area,
        [string]$Notes
    )

    $normalizedVersion = ConvertTo-CB5VersionFamily $Version
    if (-not ((Get-CB5VersionCatalog) -contains $normalizedVersion)) { throw "Selecione uma versão válida." }
    if ([string]::IsNullOrWhiteSpace($FilePath)) { throw "Selecione o arquivo do esquemático." }
    $entry = [pscustomobject]@{
        Id = [Guid]::NewGuid().ToString("N")
        Versao = $normalizedVersion
        Designador = $Designator.Trim().ToUpperInvariant()
        Arquivo = $FilePath
        Pagina = $Page.Trim()
        Area = $Area.Trim()
        Observacoes = $Notes.Trim()
        CriadoEm = [DateTime]::Now.ToString("s")
    }
    $Store.Esquematicos = @($Store.Esquematicos) + @($entry)
    return $entry
}

function Remove-CB5SchematicEntry {
    param(
        [Parameter(Mandatory = $true)][object]$Store,
        [Parameter(Mandatory = $true)][string]$Id
    )
    $before = @($Store.Esquematicos).Count
    $Store.Esquematicos = @($Store.Esquematicos | Where-Object { [string]$_.Id -ne $Id })
    return (@($Store.Esquematicos).Count -lt $before)
}

function Search-CB5SchematicEntries {
    param(
        [Parameter(Mandatory = $true)][object]$Store,
        [string]$Version,
        [string]$Designator
    )
    $needle = $Designator.Trim().ToUpperInvariant()
    $normalizedVersion = ConvertTo-CB5VersionFamily $Version
    $matches = $Store.Esquematicos | Where-Object { ([string]::IsNullOrWhiteSpace($normalizedVersion) -or [string]$_.Versao -eq $normalizedVersion) -and ([string]::IsNullOrWhiteSpace($needle) -or [string]$_.Designador -like "*$needle*") } | Sort-Object -Property @("Versao", "Designador")
    return @($matches)
}

function Export-CB5PassagesCsv {
    param(
        [Parameter(Mandatory = $true)][object[]]$Passages,
        [Parameter(Mandatory = $true)][string]$Path
    )
    $rows = foreach ($record in @($Passages)) {
        [pscustomobject]@{
            Serie = ConvertTo-CB5Text $record.Serie
            Passagem = $record.Passagem
            Retorno = if (ConvertTo-CB5Boolean $record.EhRetorno) { "Sim" } else { "Não" }
            Codigo = ConvertTo-CB5Text $record.Codigo
            VersaoEntrada = ConvertTo-CB5Text $record.VersaoEntrada
            VersaoSaida = ConvertTo-CB5Text $record.VersaoSaida
            DataEntrada = ConvertTo-CB5Text $record.DataEntrada
            Status = ConvertTo-CB5Text $record.Status
            DefeitoReportado = ConvertTo-CB5Text $record.DefeitoReportado
            DefeitoEncontrado = ConvertTo-CB5Text $record.DefeitoEncontrado
            OutrosDefeitos = ConvertTo-CB5Text $record.OutrosDefeitos
            ManutencaoRealizada = ConvertTo-CB5Text $record.ManutencaoRealizada
            ResultadoFinal = ConvertTo-CB5Text $record.ResultadoFinal
            AtualizacaoExternaPrevista = ConvertTo-CB5Text $record.AtualizacaoIndicada
            ComponentesExternos = ConvertTo-CB5Text $record.ComponentesExternos
            Observacoes = ConvertTo-CB5Text $record.Observacoes
            Concluida = if (ConvertTo-CB5Boolean $record.Concluida) { "Sim" } else { "Não" }
            DataConclusao = ConvertTo-CB5Text $record.DataConclusao
        }
    }
    $lines = @($rows | ConvertTo-Csv -NoTypeInformation -Delimiter ';')
    [IO.File]::WriteAllLines($Path, $lines, ([Text.UTF8Encoding]::new($true)))
}
