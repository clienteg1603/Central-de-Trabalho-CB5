param(
    [Parameter(Mandatory = $true)][string]$UiPath,
    [Parameter(Mandatory = $true)][string]$CentralPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Assert-S13 {
    param([bool]$Condition,[string]$Message)
    if (-not $Condition) { throw $Message }
}

$ui = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $UiPath),[Text.Encoding]::UTF8)
$central = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $CentralPath),[Text.Encoding]::UTF8)

$markers = @(
    '$script:ModuleVersion = "2.4.0"',
    'function Export-NFCurrentProductViewToCsv',
    '$exportListButton.Text = "EXPORTAR LISTA"',
    'Estoque-CB5',
    'Estoque-Teclado-V5',
    'Ctrl+E exportar',
    '$exportListButton.Add_Click({ Export-NFCurrentProductViewToCsv })'
)
foreach ($marker in $markers) {
    Assert-S13 ($ui.Contains($marker)) ('Marcador da Etapa 13 ausente: ' + $marker)
}

Assert-S13 ($central.Contains('$script:AppVersion = "0.21.16"')) 'Central não foi atualizada para 0.21.16.'
Assert-S13 ($central.Contains('$script:NFEntradaVersion = "2.4.0"')) 'NF Entrada na Central não foi atualizada para 2.4.0.'
Assert-S13 ($ui.Contains('Export-NFGridViewToCsv -Grid $grid')) 'A exportação da aba atual não reutiliza o exportador filtrado da Etapa 12.'

Write-Host 'NF ENTRADA ETAPA 13: OK - exportação filtrada das abas de produto validada.'
