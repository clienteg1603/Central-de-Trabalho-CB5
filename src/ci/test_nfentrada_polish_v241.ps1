param(
    [Parameter(Mandatory = $true)][string]$UiPath,
    [Parameter(Mandatory = $true)][string]$CentralPath
)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
function Assert-Polish([bool]$Condition,[string]$Message) { if (-not $Condition) { throw $Message } }
$ui = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $UiPath),[Text.Encoding]::UTF8)
$central = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $CentralPath),[Text.Encoding]::UTF8)
foreach ($marker in @(
    '$script:ModuleVersion = "2.4.1"',
    '$importButton.Text = "IMPORTAR EXCEL"',
    '$exportButton.Text = "EXCEL OFICIAL"',
    '$newButton.Text = "+ NOVA NF"',
    '$editButton.Text = "EDITAR"',
    '$outputButton.Text = "SAÍDA"',
    '$clearFiltersButton.Text = "FILTROS"',
    '$exportListButton.Text = "CSV"',
    '$integrityButton.Text = "VERIFICAR"',
    'Accent = [Drawing.Color]::FromArgb(39, 196, 125)'
)) { Assert-Polish ($ui.Contains($marker)) ('Marcador do polimento ausente: ' + $marker) }
Assert-Polish ($central.Contains('$script:AppVersion = "0.21.17"')) 'Central não está em 0.21.17.'
Assert-Polish ($central.Contains('$script:NFEntradaVersion = "2.4.1"')) 'NF Entrada não está em 2.4.1 na Central.'
Assert-Polish (-not $ui.Contains('Ctrl+N novo • Enter editar • Ctrl+S saída • Ctrl+E exportar • Ctrl+F pesquisar')) 'Rodapé antigo e comprido ainda está presente.'
Write-Host 'NF ENTRADA POLIMENTO 2.4.1: OK - cores, rótulos e larguras validados.'
