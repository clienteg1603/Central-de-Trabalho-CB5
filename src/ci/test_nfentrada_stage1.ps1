param(
    [string]$CorePath = ".\src\generated\Modulos\Controle-NF-Entrada\NFEntrada.Core.ps1"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

if (-not (Test-Path -LiteralPath $CorePath -PathType Leaf)) {
    throw "NFEntrada.Core.ps1 não encontrado: $CorePath"
}

. $CorePath

$root = Join-Path $env:RUNNER_TEMP ("nfentrada-stage1-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $root | Out-Null

try {
    $store = New-EmptyNFEntradaStore
    if ($null -eq $store.PSObject.Properties["Historico"]) { throw "Store novo sem histórico." }
    if ($null -eq $store.PSObject.Properties["Meta"]) { throw "Store novo sem metadados." }

    $record = [pscustomobject]@{
        Data = "2026-09-11"
        QuantidadeNaNF = 10
        NFEntrada = "12345"
        QuantidadeSaldo = 8
        Codigo = "800"
        NFSaida = ""
    }
    $created = Add-NFEntradaRecord -Store $store -Product "COMPUTADOR DE BORDO V5" -Record $record
    if (@(Get-NFEntradaHistory -Store $store).Count -ne 1) { throw "Adição não gerou um evento de histórico." }
    if ([string](Get-NFEntradaHistory -Store $store)[0].Tipo -ne "Adicao") { throw "Tipo do evento de adição incorreto." }

    $edited = [pscustomobject]@{
        Data = "2026-09-11"
        QuantidadeNaNF = 10
        NFEntrada = "12345"
        QuantidadeSaldo = 4
        Codigo = "800"
        NFSaida = "54321"
    }
    Update-NFEntradaRecord -Store $store -Product "COMPUTADOR DE BORDO V5" -Id ([int]$created.Id) -Record $edited
    $history = @(Get-NFEntradaHistory -Store $store)
    if ($history.Count -ne 2) { throw "Edição não gerou um evento de histórico." }
    if ([string]$history[0].Tipo -ne "Edicao") { throw "Tipo do evento de edição incorreto." }
    if ([int]$history[0].Antes.QuantidadeSaldo -ne 8 -or [int]$history[0].Depois.QuantidadeSaldo -ne 4) {
        throw "Histórico de edição não preservou antes/depois corretamente."
    }

    Remove-NFEntradaRecord -Store $store -Product "COMPUTADOR DE BORDO V5" -Id ([int]$created.Id)
    $history = @(Get-NFEntradaHistory -Store $store)
    if ($history.Count -ne 3) { throw "Exclusão não gerou um evento de histórico." }
    if ([string]$history[0].Tipo -ne "Exclusao") { throw "Tipo do evento de exclusão incorreto." }
    if ([string]$history[0].Antes.NFEntrada -ne "12345") { throw "Exclusão não preservou o registro removido no histórico." }

    $storePath = Get-NFEntradaStorePath -DataDirectory $root
    Write-NFEntradaStore -Store $store -Path $storePath
    $reloaded = Read-NFEntradaStore -Path $storePath
    if (@(Get-NFEntradaHistory -Store $reloaded).Count -ne 3) { throw "Histórico não sobreviveu à gravação/leitura." }

    $templatePath = Get-NFEntradaTemplatePath -DataDirectory $root
    [IO.File]::WriteAllText($templatePath, "modelo-teste", [Text.Encoding]::UTF8)
    $backup = New-NFEntradaSafetyBackup -DataDirectory $root
    if ($null -eq $backup) { throw "Backup de segurança não foi criado." }
    if (-not (Test-Path -LiteralPath (Join-Path $backup.Directory "nf-entrada.json") -PathType Leaf)) { throw "Backup da base não foi criado." }
    if (-not (Test-Path -LiteralPath (Join-Path $backup.Directory "modelo-nf-entrada.xlsx") -PathType Leaf)) { throw "Backup do modelo não foi criado." }

    [IO.File]::WriteAllText($storePath, "alterado", [Text.Encoding]::UTF8)
    [IO.File]::WriteAllText($templatePath, "alterado", [Text.Encoding]::UTF8)
    Restore-NFEntradaSafetyBackup -Backup $backup -DataDirectory $root
    $restored = Read-NFEntradaStore -Path $storePath
    if (@(Get-NFEntradaHistory -Store $restored).Count -ne 3) { throw "Restauração do backup não recuperou a base original." }
    if ([IO.File]::ReadAllText($templatePath, [Text.Encoding]::UTF8) -ne "modelo-teste") { throw "Restauração do backup não recuperou o modelo original." }

    Write-Host "NF ENTRADA ETAPA 1: OK - histórico auditável, backup e restauração validados."
}
finally {
    if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
}
