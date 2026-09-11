param([string]$CorePath = ".\src\generated\Modulos\Controle-NF-Entrada\NFEntrada.Core.ps1")
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
. $CorePath
$root = Join-Path $env:RUNNER_TEMP ("nfentrada-stage5-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $root | Out-Null
try {
    $store = New-EmptyNFEntradaStore
    $record = [pscustomobject]@{ Data="2026-09-11"; QuantidadeNaNF=10; NFEntrada="5001"; QuantidadeSaldo=10; Codigo="800"; NFSaida="" }
    $created = Add-NFEntradaRecord -Store $store -Product "COMPUTADOR DE BORDO V5" -Record $record
    [void](Register-NFEntradaOutput -Store $store -Product "COMPUTADOR DE BORDO V5" -Id ([int]$created.Id) -Quantidade 3 -NFSaida "9001")
    $moves = @(Get-NFEntradaMovements -Store $store)
    if ($moves.Count -ne 1) { throw "A saída não criou uma movimentação estruturada." }
    if ([int]$moves[0].Quantidade -ne 3 -or [int]$moves[0].SaldoAntes -ne 10 -or [int]$moves[0].SaldoDepois -ne 7) { throw "Saldos da movimentação estão incorretos." }
    if ([string]$moves[0].Referencia -ne "9001") { throw "Referência da saída não foi preservada." }
    $path = Get-NFEntradaStorePath -DataDirectory $root
    Write-NFEntradaStore -Store $store -Path $path
    $loaded = Read-NFEntradaStore -Path $path
    if (@(Get-NFEntradaMovements -Store $loaded).Count -ne 1) { throw "Movimentação não sobreviveu à gravação da base." }
    $loaded.PSObject.Properties.Remove("Movimentacoes")
    [void](Ensure-NFEntradaStoreShape -Store $loaded)
    $legacy = @(Get-NFEntradaMovements -Store $loaded)
    if ($legacy.Count -ne 1 -or [int]$legacy[0].Quantidade -ne 3) { throw "Migração do histórico anterior para movimentações falhou." }
    Write-Host "NF ENTRADA ETAPA 5: OK - saída estruturada, persistência e migração compatível validadas."
}
finally {
    if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
}
