param(
    [Parameter(Mandatory = $true)][string]$CorePath,
    [Parameter(Mandatory = $true)][string]$UiPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Assert-Stage7 {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

. $CorePath

function New-TestStore {
    param([object[]]$Computer = @(), [object[]]$Keyboard = @())
    return [pscustomobject]@{
        SchemaVersion = 1
        Produtos = [pscustomobject]@{
            'COMPUTADOR DE BORDO V5' = @($Computer)
            'TECLADO V5' = @($Keyboard)
        }
        Historico = @()
        Movimentacoes = @()
        Meta = [pscustomobject]@{
            CriadoEm = [DateTime]::Now.ToString('o')
            UltimaAlteracaoEm = [DateTime]::Now.ToString('o')
        }
    }
}

function New-TestRecord {
    param(
        [int]$Id,
        [string]$Data = '2026-09-11',
        [int]$QuantidadeNaNF = 10,
        [int]$QuantidadeSaldo = 10,
        [string]$NFEntrada = '1000'
    )
    return [pscustomobject]@{
        Id = $Id
        Ordem = $Id
        Data = $Data
        QuantidadeNaNF = $QuantidadeNaNF
        NFEntrada = $NFEntrada
        QuantidadeSaldo = $QuantidadeSaldo
        Codigo = '800'
        NFSaida = ''
    }
}

$temp = Join-Path ([IO.Path]::GetTempPath()) ('nfentrada-stage7-' + [guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($temp)
try {
    $template = Get-NFEntradaTemplatePath -DataDirectory $temp
    [IO.File]::WriteAllBytes($template, [byte[]](1,2,3))

    $store = New-TestStore -Computer @((New-TestRecord -Id 1 -NFEntrada 'CB5-1')) -Keyboard @((New-TestRecord -Id 1 -NFEntrada 'TV5-1'))
    $ready = Get-NFEntradaExportReadiness -Store $store -DataDirectory $temp
    Assert-Stage7 ([bool]$ready.PodeExportar) 'Base válida com modelo deveria permitir exportação.'
    Assert-Stage7 ([string]$ready.Situacao -eq 'PRONTO') 'Base válida deveria ficar PRONTO.'
    Assert-Stage7 ([int]$ready.CapacidadePorProduto -eq 296) 'Capacidade do modelo deve permanecer em 296 linhas por produto.'
    Assert-Stage7 ([int]$ready.RegistrosComputador -eq 1 -and [int]$ready.RegistrosTeclado -eq 1) 'Contagem de registros da conferência está incorreta.'

    $reviewStore = New-TestStore -Computer @((New-TestRecord -Id 1 -Data '' -QuantidadeNaNF 1 -QuantidadeSaldo 2 -NFEntrada 'REVISAR-1'))
    $review = Get-NFEntradaExportReadiness -Store $reviewStore -DataDirectory $temp
    Assert-Stage7 ([bool]$review.PodeExportar) 'Pendência de conferência deve avisar, mas não bloquear exportação quando o modelo comporta os dados.'
    Assert-Stage7 ([string]$review.Situacao -eq 'REVISAR') 'Registro inconsistente deveria marcar exportação como REVISAR.'
    Assert-Stage7 ([int]$review.Pendencias -eq 1) 'A conferência deveria apontar uma NF pendente.'

    $many = [Collections.Generic.List[object]]::new()
    foreach ($i in 1..297) { [void]$many.Add((New-TestRecord -Id $i -NFEntrada ('NF-' + $i))) }
    $blockedStore = New-TestStore -Computer @($many)
    $blocked = Get-NFEntradaExportReadiness -Store $blockedStore -DataDirectory $temp
    Assert-Stage7 (-not [bool]$blocked.PodeExportar) 'Mais de 296 registros de um produto deve bloquear exportação para preservar o formato oficial.'
    Assert-Stage7 ([string]$blocked.Situacao -eq 'BLOQUEADO') 'Excesso de linhas deveria marcar BLOQUEADO.'
    Assert-Stage7 ([int]$blocked.ExcessoComputador -eq 1) 'Excesso calculado para CB5 deveria ser 1.'

    [IO.File]::Delete($template)
    $missingTemplate = Get-NFEntradaExportReadiness -Store $store -DataDirectory $temp
    Assert-Stage7 (-not [bool]$missingTemplate.PodeExportar) 'Sem modelo oficial a exportação deve permanecer bloqueada.'

    [void](Add-NFEntradaHistoryEvent -Store $store -Tipo 'Exportacao' -Detalhes 'Arquivo: teste.xlsx')
    $last = Get-NFEntradaLastExport -Store $store
    Assert-Stage7 ($null -ne $last -and [string]$last.Tipo -eq 'Exportacao') 'Última exportação não foi recuperada do histórico.'

    $ui = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $UiPath), [Text.Encoding]::UTF8)
    foreach ($marker in @('CONFERIR EXPORTAÇÃO', 'Exportação Excel', 'Show-NFExportReadiness', '-Tipo "Exportacao"', '"Exportacao" { "Exportação" }', '$script:ModuleVersion = "1.8.0"')) {
        Assert-Stage7 ($ui.Contains($marker)) ('Marcador de interface ausente: ' + $marker)
    }

    Write-Host 'NF ENTRADA ETAPA 7: OK — pré-conferência, capacidade, pendências, auditoria de exportação e interface validadas.'
}
finally {
    if ([IO.Directory]::Exists($temp)) { [IO.Directory]::Delete($temp, $true) }
}
