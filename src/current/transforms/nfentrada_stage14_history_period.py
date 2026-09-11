from pathlib import Path

UI = Path('src/generated/Modulos/Controle-NF-Entrada/Controle NF Entrada.ps1')
CENTRAL = Path('src/generated/Central de Trabalho.ps1')


def read(path):
    return path.read_text(encoding='utf-8-sig')


def write(path, text):
    path.write_text(text, encoding='utf-8')


def rep(text, old, new, label):
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'Etapa 14: marcador inesperado em {label}: {count}')
    return text.replace(old, new, 1)


ui = read(UI)
central = read(CENTRAL)

ui = rep(ui, '$script:ModuleVersion = "2.4.2"', '$script:ModuleVersion = "2.5.0"', 'versão módulo')
central = rep(central, '$script:AppVersion = "0.21.18"', '$script:AppVersion = "0.21.19"', 'versão central')
central = rep(central, '$script:NFEntradaVersion = "2.4.2"', '$script:NFEntradaVersion = "2.5.0"', 'versão NF na central')

old_refresh = '''function Refresh-NFHistory {
    if ($null -eq $historyGrid) { return }
    $filter = if ($null -ne $historyFilter) { ([string]$historyFilter.Text).Trim().ToLowerInvariant() } else { "" }
    $type = if ($null -ne $historyTypeFilter -and $historyTypeFilter.SelectedIndex -gt 0) { [string]$historyTypeFilter.SelectedItem } else { "Todos" }
    $events = @(Get-NFEntradaHistory -Store $script:Store)
    $shown = 0
    $historyGrid.Rows.Clear()
    foreach ($event in $events) {
        $label = switch ([string]$event.Tipo) {
            "Adicao" { "Adição" }
            "Edicao" { "Edição" }
            "Exclusao" { "Exclusão" }
            "Importacao" { "Importação" }
            "RestauracaoBackup" { "Restauração" }
            "Saida" { "Saída" }
            "EstornoSaida" { "Estorno de saída" }
            "Exportacao" { "Exportação" }
            default { [string]$event.Tipo }
        }
        if ($type -ne "Todos" -and $label -ne $type) { continue }
        $search = (($label + " " + (Get-NFEntradaProductDisplayName ([string]$event.Produto)) + " " + [string]$event.NFEntrada + " " + [string]$event.Detalhes)).ToLowerInvariant()
        if (-not [string]::IsNullOrWhiteSpace($filter) -and -not $search.Contains($filter)) { continue }
        [void]$historyGrid.Rows.Add([string]$event.Id, (Format-NFHistoryDate ([string]$event.DataHora)), $label, (Get-NFEntradaProductDisplayName ([string]$event.Produto)), [string]$event.NFEntrada, [string]$event.Detalhes)
        $shown++
    }
    $historyCountLabel.Text = "$shown de $($events.Count)"
    $historyGrid.ClearSelection()
    $historyDetailsButton.Enabled = $false
}'''

new_refresh = '''function Refresh-NFHistory {
    if ($null -eq $historyGrid) { return }
    $filter = if ($null -ne $historyFilter) { ([string]$historyFilter.Text).Trim().ToLowerInvariant() } else { "" }
    $type = if ($null -ne $historyTypeFilter -and $historyTypeFilter.SelectedIndex -gt 0) { [string]$historyTypeFilter.SelectedItem } else { "Todos" }
    $period = if ($null -ne $historyPeriodFilter -and $historyPeriodFilter.SelectedIndex -gt 0) { [string]$historyPeriodFilter.SelectedItem } else { "Todos" }
    $events = @(Get-NFEntradaHistory -Store $script:Store)
    $shown = 0
    $today = [DateTime]::Today
    $historyGrid.Rows.Clear()
    foreach ($event in $events) {
        $when = [DateTime]::MinValue
        $hasDate = [DateTime]::TryParse([string]$event.DataHora, [ref]$when)
        if ($period -ne "Todos") {
            if (-not $hasDate) { continue }
            if ($period -eq "Hoje" -and $when -lt $today) { continue }
            if ($period -eq "Últimos 7 dias" -and $when -lt $today.AddDays(-6)) { continue }
            if ($period -eq "Últimos 30 dias" -and $when -lt $today.AddDays(-29)) { continue }
        }
        $label = switch ([string]$event.Tipo) {
            "Adicao" { "Adição" }
            "Edicao" { "Edição" }
            "Exclusao" { "Exclusão" }
            "Importacao" { "Importação" }
            "RestauracaoBackup" { "Restauração" }
            "Saida" { "Saída" }
            "EstornoSaida" { "Estorno de saída" }
            "Exportacao" { "Exportação" }
            default { [string]$event.Tipo }
        }
        if ($type -ne "Todos" -and $label -ne $type) { continue }
        $search = (($label + " " + (Get-NFEntradaProductDisplayName ([string]$event.Produto)) + " " + [string]$event.NFEntrada + " " + [string]$event.Detalhes)).ToLowerInvariant()
        if (-not [string]::IsNullOrWhiteSpace($filter) -and -not $search.Contains($filter)) { continue }
        [void]$historyGrid.Rows.Add([string]$event.Id, (Format-NFHistoryDate ([string]$event.DataHora)), $label, (Get-NFEntradaProductDisplayName ([string]$event.Produto)), [string]$event.NFEntrada, [string]$event.Detalhes)
        $shown++
    }
    $historyCountLabel.Text = "$shown de $($events.Count) • $period"
    $historyGrid.ClearSelection()
    $historyDetailsButton.Enabled = $false
}'''
ui = rep(ui, old_refresh, new_refresh, 'Refresh-NFHistory')

old_filters = '''$historyFilters.ColumnCount = 5
[void]$historyFilters.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Absolute, 74)))
[void]$historyFilters.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 100)))
[void]$historyFilters.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Absolute, 52)))
[void]$historyFilters.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Absolute, 142)))
[void]$historyFilters.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Absolute, 108)))'''
new_filters = '''$historyFilters.ColumnCount = 7
[void]$historyFilters.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Absolute, 74)))
[void]$historyFilters.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 100)))
[void]$historyFilters.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Absolute, 52)))
[void]$historyFilters.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Absolute, 142)))
[void]$historyFilters.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Absolute, 62)))
[void]$historyFilters.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Absolute, 155)))
[void]$historyFilters.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Absolute, 120)))'''
ui = rep(ui, old_filters, new_filters, 'colunas dos filtros do Histórico')

old_count = '''$historyFilters.Controls.Add($historyTypeFilter, 3, 0)
$historyCountLabel = New-Object Windows.Forms.Label
$historyCountLabel.Text = "0 de 0"; $historyCountLabel.Dock = [Windows.Forms.DockStyle]::Fill; $historyCountLabel.TextAlign = [Drawing.ContentAlignment]::MiddleRight; $historyCountLabel.ForeColor = $script:CurrentPalette.Muted
$historyFilters.Controls.Add($historyCountLabel, 4, 0)'''
new_count = '''$historyFilters.Controls.Add($historyTypeFilter, 3, 0)
$historyPeriodLabel = New-Object Windows.Forms.Label
$historyPeriodLabel.Text = "Período"; $historyPeriodLabel.Dock = [Windows.Forms.DockStyle]::Fill; $historyPeriodLabel.TextAlign = [Drawing.ContentAlignment]::MiddleLeft; $historyPeriodLabel.ForeColor = $script:CurrentPalette.Muted
$historyFilters.Controls.Add($historyPeriodLabel, 4, 0)
$historyPeriodFilter = New-Object Windows.Forms.ComboBox
$historyPeriodFilter.DropDownStyle = [Windows.Forms.ComboBoxStyle]::DropDownList
[void]$historyPeriodFilter.Items.AddRange(@("Todos", "Hoje", "Últimos 7 dias", "Últimos 30 dias"))
$historyPeriodFilter.SelectedIndex = 0; $historyPeriodFilter.Dock = [Windows.Forms.DockStyle]::Fill; $historyPeriodFilter.Margin = [Windows.Forms.Padding]::new(0, 8, 8, 8); $historyPeriodFilter.BackColor = $script:CurrentPalette.Input; $historyPeriodFilter.ForeColor = $script:CurrentPalette.Text
$historyFilters.Controls.Add($historyPeriodFilter, 5, 0)
$historyCountLabel = New-Object Windows.Forms.Label
$historyCountLabel.Text = "0 de 0"; $historyCountLabel.Dock = [Windows.Forms.DockStyle]::Fill; $historyCountLabel.TextAlign = [Drawing.ContentAlignment]::MiddleRight; $historyCountLabel.ForeColor = $script:CurrentPalette.Muted
$historyFilters.Controls.Add($historyCountLabel, 6, 0)'''
ui = rep(ui, old_count, new_count, 'controle Período do Histórico')

ui = rep(
    ui,
    '$historyTypeFilter.Add_SelectedIndexChanged({ Refresh-NFHistory })',
    '$historyTypeFilter.Add_SelectedIndexChanged({ Refresh-NFHistory })\n$historyPeriodFilter.Add_SelectedIndexChanged({ Refresh-NFHistory })',
    'evento do período do Histórico'
)

# O tema ao vivo também precisa incluir o novo combo e rótulo.
ui = rep(
    ui,
    '$movementPeriodFilter, $historyTypeFilter, $historyFilter, $backupGrid',
    '$movementPeriodFilter, $historyTypeFilter, $historyPeriodFilter, $historyFilter, $backupGrid',
    'combo do período na atualização de tema'
)
ui = rep(
    ui,
    '$movementPeriodLabel, $historySearchLabel, $historyTypeLabel, $historyCountLabel, $securityInfo',
    '$movementPeriodLabel, $historySearchLabel, $historyTypeLabel, $historyPeriodLabel, $historyCountLabel, $securityInfo',
    'rótulo do período na atualização de tema'
)

for marker in (
    '$script:ModuleVersion = "2.5.0"',
    '$historyPeriodFilter',
    '"Últimos 7 dias"',
    '"Últimos 30 dias"',
    '$historyPeriodFilter.Add_SelectedIndexChanged({ Refresh-NFHistory })',
    '$historyCountLabel.Text = "$shown de $($events.Count) • $period"'
):
    if marker not in ui:
        raise SystemExit('Etapa 14: marcador final ausente: ' + marker)
if '$script:AppVersion = "0.21.19"' not in central or '$script:NFEntradaVersion = "2.5.0"' not in central:
    raise SystemExit('Etapa 14: versões finais não aplicadas na Central.')

write(UI, ui)
write(CENTRAL, central)
print('ETAPA 14: OK - filtro de período no Histórico; Central 0.21.19 / NF Entrada 2.5.0.')
