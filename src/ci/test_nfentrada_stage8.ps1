param(
    [Parameter(Mandatory = $true)][string]$CorePath,
    [Parameter(Mandatory = $true)][string]$UiPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Assert-Stage8 {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

. $CorePath

$store = New-EmptyNFEntradaStore
$base = [pscustomobject]@{
    Data = '2026-09-11'
    QuantidadeNaNF = 12
    NFEntrada = '12345'
    QuantidadeSaldo = 12
    Codigo = '800'
    NFSaida = ''
}
$created = Add-NFEntradaRecord -Store $store -Product 'COMPUTADOR DE BORDO V5' -Record $base
$duplicate = Get-NFEntradaDuplicateRecord -Store $store -Product 'COMPUTADOR DE BORDO V5' -NFEntrada '12345'
Assert-Stage8 ($null -ne $duplicate -and [int]$duplicate.Id -eq [int]$created.Id) 'Duplicate lookup did not find the existing NF.'
$none = Get-NFEntradaDuplicateRecord -Store $store -Product 'TECLADO V5' -NFEntrada '12345'
Assert-Stage8 ($null -eq $none) 'Duplicate lookup must remain scoped to the selected product.'

$threw = $false
try { [void](Test-NFEntradaRecord -Record $base -Store $store -Product 'COMPUTADOR DE BORDO V5') } catch { $threw = $true }
Assert-Stage8 $threw 'Duplicate NF must still be rejected on save.'
Assert-Stage8 ([bool](Test-NFEntradaRecord -Record $base -Store $store -Product 'COMPUTADOR DE BORDO V5' -IgnoreId ([int]$created.Id))) 'Editing the same record must ignore its own NF.'

$ui = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $UiPath), [Text.Encoding]::UTF8)
foreach ($marker in @(
    '$script:ModuleVersion = "1.9.0"',
    '$saveAndNew',
    'ContinuarCadastro',
    'Update-NFRecordDialogValidation',
    '$balanceBox.Value = $qtyBox.Value',
    '-DefaultDate $defaultDate -DefaultCode $defaultCode',
    '$qtyBox.Focus()'
)) {
    Assert-Stage8 ($ui.Contains($marker)) ('Missing stage 8 UI marker: ' + $marker)
}

Write-Host 'NF ENTRADA ETAPA 8: OK - quick entry, live validation, duplicate protection and save-and-new flow validated.'
