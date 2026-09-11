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
        raise SystemExit(f'Etapa 16: marcador inesperado em {label}: {count}')
    return text.replace(old, new, 1)


ui = read(UI)
central = read(CENTRAL)

ui = rep(ui, '$script:ModuleVersion = "2.5.0"', '$script:ModuleVersion = "2.6.0"', 'versão módulo')
central = rep(central, '$script:AppVersion = "0.21.19"', '$script:AppVersion = "0.21.20"', 'versão central')
central = rep(central, '$script:NFEntradaVersion = "2.5.0"', '$script:NFEntradaVersion = "2.6.0"', 'versão NF na central')

# Um único tradutor para os nomes de ações do Histórico evita rótulos técnicos vazarem na interface.
old_anchor = '''function Refresh-NFHistory {
    if ($null -eq $historyGrid) { return }'''
new_anchor = '''function Get-NFHistoryActionLabel {
    param([string]$Type)
    $label = switch ($Type) {
        "Adicao" { "Adição" }
        "Edicao" { "Edição" }
        "Exclusao" { "Exclusão" }
        "Importacao" { "Importação" }
        "RestauracaoBackup" { "Restauração" }
        "Saida" { "Saída" }
        "EstornoSaida" { "Estorno de saída" }
        "Exportacao" { "Exportação" }
        default { $Type }
    }
    return $label
}

function Refresh-NFHistory {
    if ($null -eq $historyGrid) { return }'''
ui = rep(ui, old_anchor, new_anchor, 'tradutor de ação do Histórico')

old_switch = '''        $label = switch ([string]$event.Tipo) {
            "Adicao" { "Adição" }
            "Edicao" { "Edição" }
            "Exclusao" { "Exclusão" }
            "Importacao" { "Importação" }
            "RestauracaoBackup" { "Restauração" }
            "Saida" { "Saída" }
            "EstornoSaida" { "Estorno de saída" }
            "Exportacao" { "Exportação" }
            default { [string]$event.Tipo }
        }'''
ui = rep(ui, old_switch, '        $label = Get-NFHistoryActionLabel ([string]$event.Tipo)', 'rótulo amigável na grade do Histórico')

ui = rep(
    ui,
    '$headerText.Text = (Format-NFHistoryDate ([string]$event.DataHora)) + "  •  " + [string]$event.Tipo + "`r`nNF: " + [string]$event.NFEntrada + "    Produto: " + (Get-NFEntradaProductDisplayName ([string]$event.Produto)) + $(if ([string]::IsNullOrWhiteSpace([string]$event.Detalhes)) { "" } else { "`r`n" + [string]$event.Detalhes })',
    '$headerText.Text = (Format-NFHistoryDate ([string]$event.DataHora)) + "  •  " + (Get-NFHistoryActionLabel ([string]$event.Tipo)) + "`r`nNF: " + [string]$event.NFEntrada + "    Produto: " + (Get-NFEntradaProductDisplayName ([string]$event.Produto)) + $(if ([string]::IsNullOrWhiteSpace([string]$event.Detalhes)) { "" } else { "`r`n" + [string]$event.Detalhes })',
    'rótulo amigável nos detalhes do Histórico'
)

# O botão dizia FILTROS, mas sua ação real sempre foi limpar/restaurar os filtros.
ui = rep(
    ui,
    '$clearFiltersButton.Text = "FILTROS"; $clearFiltersButton.Width = 82; $clearFiltersButton.Height = 34; Set-NFButtonStyle $clearFiltersButton "Secondary"',
    '$clearFiltersButton.Text = "LIMPAR"; $clearFiltersButton.Width = 82; $clearFiltersButton.Height = 34; Set-NFButtonStyle $clearFiltersButton "Secondary"',
    'nome do botão limpar filtros'
)

# Saídas estruturadas devem passar pelo botão SAÍDA. O campo no cadastro fica apenas para consulta do legado/importação.
ui = rep(
    ui,
    'Add-DialogLabel "NF de Saída / movimentações" 5\n    $outBox = New-Object Windows.Forms.TextBox\n    $outBox.Multiline = $true\n    $outBox.ScrollBars = [Windows.Forms.ScrollBars]::Vertical\n    $outBox.Dock = [Windows.Forms.DockStyle]::Fill\n    $layout.Controls.Add($outBox, 1, 5)',
    'Add-DialogLabel "NF de Saída / movimentações (automático)" 5\n    $outBox = New-Object Windows.Forms.TextBox\n    $outBox.Multiline = $true\n    $outBox.ScrollBars = [Windows.Forms.ScrollBars]::Vertical\n    $outBox.Dock = [Windows.Forms.DockStyle]::Fill\n    $outBox.ReadOnly = $true\n    $outBox.TabStop = $false\n    $outBox.BackColor = $script:CurrentPalette.Surface\n    $layout.Controls.Add($outBox, 1, 5)',
    'campo automático de saídas'
)
ui = rep(ui, '    $outBox.Add_TextChanged($validateDialog)\n', '', 'evento redundante do campo automático')

# VALIDAR EXCEL duplicava a conferência que já existe na própria ação EXCEL OFICIAL.
old_summary_buttons = '''$reviewIssuesButton = New-Object Windows.Forms.Button
$reviewIssuesButton.Text = "PENDÊNCIAS"
$reviewIssuesButton.Width = 145
$reviewIssuesButton.Height = 32
$reviewIssuesButton.Margin = [Windows.Forms.Padding]::new(2, 2, 2, 5)
Set-NFButtonStyle $reviewIssuesButton "Secondary"
$exportCheckButton = New-Object Windows.Forms.Button
$exportCheckButton.Text = "VALIDAR EXCEL"
$exportCheckButton.Width = 145
$exportCheckButton.Height = 32
$exportCheckButton.Margin = [Windows.Forms.Padding]::new(2)
Set-NFButtonStyle $exportCheckButton "Secondary"
$summaryActionPanel.Controls.Add($reviewIssuesButton)
$summaryActionPanel.Controls.Add($exportCheckButton)'''
new_summary_buttons = '''$reviewIssuesButton = New-Object Windows.Forms.Button
$reviewIssuesButton.Text = "PENDÊNCIAS"
$reviewIssuesButton.Width = 145
$reviewIssuesButton.Height = 32
$reviewIssuesButton.Margin = [Windows.Forms.Padding]::new(2)
Set-NFButtonStyle $reviewIssuesButton "Secondary"
$summaryActionPanel.Controls.Add($reviewIssuesButton)'''
ui = rep(ui, old_summary_buttons, new_summary_buttons, 'remoção do botão redundante VALIDAR EXCEL')
ui = rep(ui, '$exportCheckButton.Add_Click({ Show-NFExportReadiness })\n', '', 'evento do botão redundante')

# Se não há pendências, não faz sentido abrir uma janela vazia.
ui = rep(
    ui,
    '$reviewIssuesValue.Text = ([int]$operational.Pendencias).ToString("N0")\n    $reviewIssuesValue.ForeColor = if ([int]$operational.Pendencias -eq 0) { $script:CurrentPalette.Success } else { $script:CurrentPalette.Danger }',
    '$reviewIssuesValue.Text = ([int]$operational.Pendencias).ToString("N0")\n    $reviewIssuesValue.ForeColor = if ([int]$operational.Pendencias -eq 0) { $script:CurrentPalette.Success } else { $script:CurrentPalette.Danger }\n    $reviewIssuesButton.Enabled = ([int]$operational.Pendencias -gt 0)',
    'estado do botão Pendências'
)

# EXCEL OFICIAL fica clicável: quando houver bloqueio, a própria rotina explica o motivo.
ui = rep(
    ui,
    '    $exportReadiness = Get-NFEntradaExportReadiness -Store $script:Store -DataDirectory $script:DataDirectory\n    $exportButton.Enabled = [bool]$exportReadiness.PodeExportar',
    '    $exportReadiness = Get-NFEntradaExportReadiness -Store $script:Store -DataDirectory $script:DataDirectory\n    $exportButton.Enabled = $true',
    'comportamento do Excel oficial bloqueado'
)

# Rodapé deve informar estado, não repetir uma regra padrão que pode não corresponder ao filtro atual.
ui = rep(
    ui,
    '    Set-NFStatus ("Pronto • " + $totalRecords + " registro(s) • Em estoque por padrão") "Normal"',
    '    Set-NFStatus ("Pronto • " + $totalRecords + " registro(s)") "Normal"',
    'status principal sem informação enganosa'
)

# Tooltips dos pontos revisados.
ui = rep(
    ui,
    '$toolTip.SetToolTip($clearFiltersButton, "Limpa pesquisa, status e código; volta para Em estoque.")',
    '$toolTip.SetToolTip($clearFiltersButton, "Limpa pesquisa, status e código; volta para Em estoque.")\n$toolTip.SetToolTip($exportButton, "Exporta o Excel oficial. Se houver algum bloqueio, o motivo será mostrado antes de gerar o arquivo.")\n$toolTip.SetToolTip($reviewIssuesButton, "Abre somente os registros que precisam de conferência.")',
    'tooltips da auditoria'
)

# O painel de ações do Resumo agora tem uma única ação útil e fica centralizado verticalmente.
ui = rep(
    ui,
    '$summaryActionPanel.Padding = [Windows.Forms.Padding]::new(4, 7, 4, 4)',
    '$summaryActionPanel.Padding = [Windows.Forms.Padding]::new(4, 22, 4, 4)',
    'alinhamento da ação do Resumo'
)

required = (
    '$script:ModuleVersion = "2.6.0"',
    'function Get-NFHistoryActionLabel',
    '$clearFiltersButton.Text = "LIMPAR"',
    'NF de Saída / movimentações (automático)',
    '$outBox.ReadOnly = $true',
    '$reviewIssuesButton.Enabled = ([int]$operational.Pendencias -gt 0)',
    '$exportButton.Enabled = $true',
    'Get-NFHistoryActionLabel ([string]$event.Tipo)',
)
for marker in required:
    if marker not in ui:
        raise SystemExit('Etapa 16: marcador final ausente: ' + marker)
if '$exportCheckButton = New-Object Windows.Forms.Button' in ui or '$exportCheckButton.Add_Click' in ui:
    raise SystemExit('Etapa 16: o botão redundante VALIDAR EXCEL ainda está ativo na interface.')
if '$script:AppVersion = "0.21.20"' not in central or '$script:NFEntradaVersion = "2.6.0"' not in central:
    raise SystemExit('Etapa 16: versões finais não aplicadas na Central.')

write(UI, ui)
write(CENTRAL, central)
print('ETAPA 16: OK - auditoria de redundâncias, rótulos e comportamento concluída; Central 0.21.20 / NF Entrada 2.6.0.')
