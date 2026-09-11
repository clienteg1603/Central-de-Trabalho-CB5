param(
    [string]$CorePath = ".\src\generated\Modulos\Controle-NF-Entrada\NFEntrada.Core.ps1"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

if (-not (Test-Path -LiteralPath $CorePath -PathType Leaf)) {
    throw "NFEntrada.Core.ps1 não encontrado: $CorePath"
}

. $CorePath

$store = New-EmptyNFEntradaStore
$computer = "COMPUTADOR DE BORDO V5"
$keyboard = "TECLADO V5"

$store.Produtos.PSObject.Properties[$computer].Value = @(
    [pscustomobject]@{ Id=1; Ordem=1; Data=[DateTime]::Today.ToString("yyyy-MM-dd"); QuantidadeNaNF=10; NFEntrada="1001"; QuantidadeSaldo=5; Codigo="800"; NFSaida="" },
    [pscustomobject]@{ Id=2; Ordem=2; Data=""; QuantidadeNaNF=10; NFEntrada="1002"; QuantidadeSaldo=12; Codigo="850"; NFSaida="" }
)
$store.Produtos.PSObject.Properties[$keyboard].Value = @(
    [pscustomobject]@{ Id=3; Ordem=1; Data=[DateTime]::Today.ToString("yyyy-MM-dd"); QuantidadeNaNF=4; NFEntrada="2001"; QuantidadeSaldo=0; Codigo="100"; NFSaida="S-1" }
)
$store.NextId = 4

$m1 = Add-NFEntradaMovement -Store $store -Produto $computer -RegistroId 1 -NFEntrada "1001" -Quantidade 2 -Referencia "S-100" -SaldoAntes 7 -SaldoDepois 5
$m1.DataHora = [DateTime]::Now.ToString("o")
$m2 = Add-NFEntradaMovement -Store $store -Produto $computer -RegistroId 1 -NFEntrada "1001" -Quantidade 1 -Referencia "S-099" -SaldoAntes 8 -SaldoDepois 7
$m2.DataHora = [DateTime]::Now.AddDays(-3).ToString("o")
$m3 = Add-NFEntradaMovement -Store $store -Produto $keyboard -RegistroId 3 -NFEntrada "2001" -Quantidade 4 -Referencia "S-050" -SaldoAntes 4 -SaldoDepois 0
$m3.DataHora = [DateTime]::Now.AddDays(-10).ToString("o")

$review = @(Get-NFEntradaReviewItems -Store $store)
if ($review.Count -ne 1) { throw "Quantidade de pendências inesperada: $($review.Count)" }
if ([string]$review[0].NFEntrada -ne "1002") { throw "NF pendente incorreta." }
if ([string]$review[0].Problema -notlike "*Data ausente*" -or [string]$review[0].Problema -notlike "*Saldo maior que a entrada*") {
    throw "Motivos de pendência incompletos: $($review[0].Problema)"
}

$metrics = Get-NFEntradaOperationalMetrics -Store $store
if ([int]$metrics.MovimentacoesHoje -ne 1) { throw "Movimentações de hoje incorretas." }
if ([int]$metrics.PecasSaidaHoje -ne 2) { throw "Peças de hoje incorretas." }
if ([int]$metrics.Movimentacoes7Dias -ne 2) { throw "Movimentações dos últimos 7 dias incorretas." }
if ([int]$metrics.PecasSaida7Dias -ne 3) { throw "Peças dos últimos 7 dias incorretas." }
if ([int]$metrics.PecasMovimentadasTotal -ne 7) { throw "Total movimentado incorreto." }
if ([int]$metrics.NFsEmEstoque -ne 1) { throw "NFs em estoque incorretas." }
if ([int]$metrics.NFsEncerradas -ne 1) { throw "NFs encerradas incorretas." }
if ([int]$metrics.Pendencias -ne 1) { throw "Total de pendências incorreto." }
if ([string]$metrics.UltimaMovimentacaoNF -ne "1001") { throw "Última movimentação não foi identificada corretamente." }

Write-Host "NF ENTRADA ETAPA 6: OK - métricas operacionais e conferência validadas."
