param(
    [string]$CorePath = ".\src\generated\Modulos\Controle-NF-Entrada\NFEntrada.Core.ps1"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

if (-not (Test-Path -LiteralPath $CorePath -PathType Leaf)) {
    throw "NFEntrada.Core.ps1 não encontrado: $CorePath"
}

. $CorePath

$cases = @(
    [pscustomobject]@{ QuantidadeNaNF = 10; QuantidadeSaldo = 8; Expected = "Em estoque" },
    [pscustomobject]@{ QuantidadeNaNF = 10; QuantidadeSaldo = 0; Expected = "Encerrada" },
    [pscustomobject]@{ QuantidadeNaNF = 10; QuantidadeSaldo = -1; Expected = "Revisar" },
    [pscustomobject]@{ QuantidadeNaNF = 10; QuantidadeSaldo = 11; Expected = "Revisar" }
)

foreach ($case in $cases) {
    $status = Get-NFEntradaRecordStatus -Record $case
    if ($status -ne $case.Expected) {
        throw "Status incorreto para quantidade=$($case.QuantidadeNaNF), saldo=$($case.QuantidadeSaldo): esperado '$($case.Expected)', obtido '$status'."
    }
}

Write-Host "NF ENTRADA ETAPA 2: OK - classificação Em estoque / Encerrada / Revisar validada."
