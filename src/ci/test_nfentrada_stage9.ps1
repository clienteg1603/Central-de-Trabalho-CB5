param([Parameter(Mandatory = $true)][string]$CorePath)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
. $CorePath

function Assert-S9 { param([bool]$Ok,[string]$Message) if (-not $Ok) { throw $Message } }

$store = New-EmptyNFEntradaStore
$record = [pscustomobject]@{
    Data = "2026-09-11"
    QuantidadeNaNF = 10
    NFEntrada = "NF-TESTE"
    QuantidadeSaldo = 10
    Codigo = "800"
    NFSaida = ""
}
$created = Add-NFEntradaRecord -Store $store -Product "COMPUTADOR DE BORDO V5" -Record $record
[void](Register-NFEntradaOutput -Store $store -Product "COMPUTADOR DE BORDO V5" -Id ([int]$created.Id) -Quantidade 4 -NFSaida "SAIDA-TESTE")
$movement = @(Get-NFEntradaMovements -Store $store)[0]
Assert-S9 ((Get-NFEntradaMovementStatus -Movement $movement) -eq "Ativa") "Movimento deveria iniciar ativo."
$result = Register-NFEntradaReversal -Store $store -MovementId ([string]$movement.Id) -Motivo "Teste automatizado"
Assert-S9 ([int]$result.Record.QuantidadeSaldo -eq 10) "Reversao nao devolveu o saldo."
Assert-S9 ([bool]$result.Movement.Estornada) "Movimento nao foi marcado como estornado."
Assert-S9 (@(Get-NFEntradaHistory -Store $store | Where-Object { $_.Tipo -eq "EstornoSaida" }).Count -eq 1) "Historico de estorno ausente."
$metrics = Get-NFEntradaOperationalMetrics -Store $store
Assert-S9 ([int]$metrics.MovimentacoesTotal -eq 0) "Movimento estornado ainda conta nos indicadores."
$blocked = $false
try { [void](Register-NFEntradaReversal -Store $store -MovementId ([string]$movement.Id) -Motivo "Repeticao") } catch { $blocked = $true }
Assert-S9 $blocked "Segundo estorno deveria ser bloqueado."
Write-Host "NF ENTRADA ETAPA 9: OK"
