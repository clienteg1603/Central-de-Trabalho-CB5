from pathlib import Path

ROOT = Path('.')
UI = ROOT / 'src/generated/Modulos/Controle-NF-Entrada/Controle NF Entrada.ps1'
CENTRAL = ROOT / 'src/generated/Central de Trabalho.ps1'


def read(path):
    return path.read_text(encoding='utf-8-sig')


def write(path, text):
    path.write_text(text, encoding='utf-8')


def rep(text, old, new, label):
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'Etapa 13: marcador inesperado em {label}: {count}')
    return text.replace(old, new, 1)


ui = read(UI)
central = read(CENTRAL)

if '$script:ModuleVersion = "2.4.0"' in ui:
    raise SystemExit('Etapa 13 já aplicada; abortando para evitar duplicação.')

ui = rep(ui, '$script:ModuleVersion = "2.3.0"', '$script:ModuleVersion = "2.4.0"', 'versão do módulo')

export_current = r'''function Export-NFCurrentProductViewToCsv {
    $product = Get-SelectedProduct
    if ([string]::IsNullOrWhiteSpace($product)) { return }
    $grid = if ($product -eq $script:ComputerProduct) { $computerGrid } else { $keyboardGrid }
    $baseName = if ($product -eq $script:ComputerProduct) { "Estoque-CB5" } else { "Estoque-Teclado-V5" }
    $title = if ($product -eq $script:ComputerProduct) { "Lista de Computador de Bordo CB5" } else { "Lista de Teclado V5" }
    Export-NFGridViewToCsv -Grid $grid -BaseName $baseName -Title $title
}

'''
ui = rep(ui, 'function Format-NFDate {', export_current + 'function Format-NFDate {', 'função de exportação da aba atual')

old_actions = '''$clearFiltersButton = New-Object Windows.Forms.Button
$clearFiltersButton.Text = "LIMPAR FILTROS"; $clearFiltersButton.Width = 120; $clearFiltersButton.Height = 34; Set-NFButtonStyle $clearFiltersButton "Secondary"
$deleteButton = New-Object Windows.Forms.Button
$deleteButton.Text = "EXCLUIR"; $deleteButton.Width = 95; $deleteButton.Height = 34; Set-NFButtonStyle $deleteButton "Danger"
$actionPanel.Controls.Add($newButton); $actionPanel.Controls.Add($editButton); $actionPanel.Controls.Add($outputButton); $actionPanel.Controls.Add($clearFiltersButton); $actionPanel.Controls.Add($deleteButton)'''
new_actions = '''$clearFiltersButton = New-Object Windows.Forms.Button
$clearFiltersButton.Text = "LIMPAR FILTROS"; $clearFiltersButton.Width = 120; $clearFiltersButton.Height = 34; Set-NFButtonStyle $clearFiltersButton "Secondary"
$exportListButton = New-Object Windows.Forms.Button
$exportListButton.Text = "EXPORTAR LISTA"; $exportListButton.Width = 120; $exportListButton.Height = 34; Set-NFButtonStyle $exportListButton "Secondary"
$deleteButton = New-Object Windows.Forms.Button
$deleteButton.Text = "EXCLUIR"; $deleteButton.Width = 95; $deleteButton.Height = 34; Set-NFButtonStyle $deleteButton "Danger"
$actionPanel.Controls.Add($newButton); $actionPanel.Controls.Add($editButton); $actionPanel.Controls.Add($outputButton); $actionPanel.Controls.Add($clearFiltersButton); $actionPanel.Controls.Add($exportListButton); $actionPanel.Controls.Add($deleteButton)'''
ui = rep(ui, old_actions, new_actions, 'botão exportar lista')

ui = rep(
    ui,
    '$newButton.Enabled = $enabled\n    $hasSelection = $false',
    '$newButton.Enabled = $enabled\n    $exportListButton.Enabled = $enabled\n    $hasSelection = $false',
    'estado do botão exportar lista'
)

ui = rep(
    ui,
    '$toolTip.SetToolTip($clearFiltersButton, "Limpa a pesquisa e volta para Em estoque / Todos os códigos.")\n$toolTip.SetToolTip($deleteButton, "Excluir o registro selecionado; o Histórico é preservado.")',
    '$toolTip.SetToolTip($clearFiltersButton, "Limpa a pesquisa e volta para Em estoque / Todos os códigos.")\n$toolTip.SetToolTip($exportListButton, "Exporta somente as linhas visíveis da aba atual, respeitando pesquisa, status e código (Ctrl+E).")\n$toolTip.SetToolTip($deleteButton, "Excluir o registro selecionado; o Histórico é preservado.")',
    'tooltip do botão exportar lista'
)

old_computer_keys = '$computerGrid.Add_KeyDown({ if ($_.Control -and $_.KeyCode -eq [Windows.Forms.Keys]::N) { $_.SuppressKeyPress=$true; Add-NFRecordFromUI } elseif ($_.Control -and $_.KeyCode -eq [Windows.Forms.Keys]::S) { $_.SuppressKeyPress=$true; Register-NFOutputFromUI } elseif ($_.KeyCode -eq [Windows.Forms.Keys]::Enter) { $_.SuppressKeyPress=$true; Edit-NFRecordFromUI } elseif ($_.Control -and $_.KeyCode -eq [Windows.Forms.Keys]::F) { $_.SuppressKeyPress=$true; $computerFilter.Focus() } })'
new_computer_keys = '$computerGrid.Add_KeyDown({ if ($_.Control -and $_.KeyCode -eq [Windows.Forms.Keys]::N) { $_.SuppressKeyPress=$true; Add-NFRecordFromUI } elseif ($_.Control -and $_.KeyCode -eq [Windows.Forms.Keys]::S) { $_.SuppressKeyPress=$true; Register-NFOutputFromUI } elseif ($_.Control -and $_.KeyCode -eq [Windows.Forms.Keys]::E) { $_.SuppressKeyPress=$true; Export-NFCurrentProductViewToCsv } elseif ($_.KeyCode -eq [Windows.Forms.Keys]::Enter) { $_.SuppressKeyPress=$true; Edit-NFRecordFromUI } elseif ($_.Control -and $_.KeyCode -eq [Windows.Forms.Keys]::F) { $_.SuppressKeyPress=$true; $computerFilter.Focus() } })'
ui = rep(ui, old_computer_keys, new_computer_keys, 'atalho Ctrl+E CB5')

old_keyboard_keys = '$keyboardGrid.Add_KeyDown({ if ($_.Control -and $_.KeyCode -eq [Windows.Forms.Keys]::N) { $_.SuppressKeyPress=$true; Add-NFRecordFromUI } elseif ($_.Control -and $_.KeyCode -eq [Windows.Forms.Keys]::S) { $_.SuppressKeyPress=$true; Register-NFOutputFromUI } elseif ($_.KeyCode -eq [Windows.Forms.Keys]::Enter) { $_.SuppressKeyPress=$true; Edit-NFRecordFromUI } elseif ($_.Control -and $_.KeyCode -eq [Windows.Forms.Keys]::F) { $_.SuppressKeyPress=$true; $keyboardFilter.Focus() } })'
new_keyboard_keys = '$keyboardGrid.Add_KeyDown({ if ($_.Control -and $_.KeyCode -eq [Windows.Forms.Keys]::N) { $_.SuppressKeyPress=$true; Add-NFRecordFromUI } elseif ($_.Control -and $_.KeyCode -eq [Windows.Forms.Keys]::S) { $_.SuppressKeyPress=$true; Register-NFOutputFromUI } elseif ($_.Control -and $_.KeyCode -eq [Windows.Forms.Keys]::E) { $_.SuppressKeyPress=$true; Export-NFCurrentProductViewToCsv } elseif ($_.KeyCode -eq [Windows.Forms.Keys]::Enter) { $_.SuppressKeyPress=$true; Edit-NFRecordFromUI } elseif ($_.Control -and $_.KeyCode -eq [Windows.Forms.Keys]::F) { $_.SuppressKeyPress=$true; $keyboardFilter.Focus() } })'
ui = rep(ui, old_keyboard_keys, new_keyboard_keys, 'atalho Ctrl+E Teclado')

ui = rep(
    ui,
    '$clearFiltersButton.Add_Click({ Clear-NFCurrentProductFilters })\n$deleteButton.Add_Click({ Remove-NFRecordFromUI })',
    '$clearFiltersButton.Add_Click({ Clear-NFCurrentProductFilters })\n$exportListButton.Add_Click({ Export-NFCurrentProductViewToCsv })\n$deleteButton.Add_Click({ Remove-NFRecordFromUI })',
    'evento exportar lista'
)

ui = rep(
    ui,
    'Set-NFStatus ("Pronto • " + $totalRecords + " registro(s) • Em estoque por padrão • Ctrl+N novo • Enter editar • Ctrl+S saída • Ctrl+F pesquisar") "Normal"',
    'Set-NFStatus ("Pronto • " + $totalRecords + " registro(s) • Em estoque por padrão • Ctrl+N novo • Enter editar • Ctrl+S saída • Ctrl+E exportar • Ctrl+F pesquisar") "Normal"',
    'status com atalho de exportação'
)

central = rep(central, '$script:AppVersion = "0.21.15"', '$script:AppVersion = "0.21.16"', 'versão da Central')
central = rep(central, '$script:NFEntradaVersion = "2.3.0"', '$script:NFEntradaVersion = "2.4.0"', 'versão NF Entrada na Central')

required_ui = [
    '$script:ModuleVersion = "2.4.0"',
    'function Export-NFCurrentProductViewToCsv',
    '$exportListButton.Text = "EXPORTAR LISTA"',
    'Estoque-CB5',
    'Estoque-Teclado-V5',
    'Ctrl+E exportar',
    '$exportListButton.Add_Click({ Export-NFCurrentProductViewToCsv })'
]
for marker in required_ui:
    if marker not in ui:
        raise SystemExit(f'Etapa 13: marcador final ausente na UI: {marker}')
if '$script:AppVersion = "0.21.16"' not in central or '$script:NFEntradaVersion = "2.4.0"' not in central:
    raise SystemExit('Etapa 13: versões finais não foram aplicadas na Central.')

write(UI, ui)
write(CENTRAL, central)
print('ETAPA 13: OK - exportação filtrada das abas CB5 e Teclado adicionada; Central 0.21.16 / NF Entrada 2.4.0.')
