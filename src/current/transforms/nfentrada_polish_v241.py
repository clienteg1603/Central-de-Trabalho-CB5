from pathlib import Path

UI = Path('src/generated/Modulos/Controle-NF-Entrada/Controle NF Entrada.ps1')
CENTRAL = Path('src/generated/Central de Trabalho.ps1')


def read(p):
    return p.read_text(encoding='utf-8-sig')


def rep(text, old, new, label):
    if text.count(old) != 1:
        raise SystemExit(f'Polimento NF: marcador inesperado em {label}: {text.count(old)}')
    return text.replace(old, new, 1)

ui = read(UI)
central = read(CENTRAL)
ui = rep(ui, '$script:ModuleVersion = "2.4.0"', '$script:ModuleVersion = "2.4.1"', 'versao modulo')
central = rep(central, '$script:AppVersion = "0.21.16"', '$script:AppVersion = "0.21.17"', 'versao central')
central = rep(central, '$script:NFEntradaVersion = "2.4.0"', '$script:NFEntradaVersion = "2.4.1"', 'versao nf central')

# Paletas alinhadas com a Central de Trabalho.
for old, new in [
    ('Accent = [Drawing.Color]::FromArgb(96, 86, 196)', 'Accent = [Drawing.Color]::FromArgb(47, 112, 230)'),
    ('AccentStrong = [Drawing.Color]::FromArgb(76, 67, 174)', 'AccentStrong = [Drawing.Color]::FromArgb(34, 93, 205)'),
    ('Accent = [Drawing.Color]::FromArgb(151, 112, 255)', 'Accent = [Drawing.Color]::FromArgb(35, 179, 158)'),
    ('AccentStrong = [Drawing.Color]::FromArgb(122, 88, 226)', 'AccentStrong = [Drawing.Color]::FromArgb(27, 151, 134)'),
    ('Accent = [Drawing.Color]::Fuchsia', 'Accent = [Drawing.Color]::Yellow'),
    ('AccentStrong = [Drawing.Color]::Fuchsia', 'AccentStrong = [Drawing.Color]::Yellow'),
    ('Accent = [Drawing.Color]::FromArgb(139, 111, 255)', 'Accent = [Drawing.Color]::FromArgb(39, 196, 125)'),
    ('AccentStrong = [Drawing.Color]::FromArgb(111, 82, 226)', 'AccentStrong = [Drawing.Color]::FromArgb(29, 166, 105)'),
]:
    if old not in ui:
        raise SystemExit('Polimento NF: cor esperada ausente: ' + old)
    ui = ui.replace(old, new, 1)

ui = rep(ui, '$Button.BackColor = $script:CurrentPalette.Surface\n            $Button.ForeColor = $script:CurrentPalette.Text', '$Button.BackColor = $script:CurrentPalette.Card\n            $Button.ForeColor = $script:CurrentPalette.Text', 'secundario')
ui = rep(ui, '$grid.ColumnHeadersDefaultCellStyle.BackColor = $script:CurrentPalette.Surface', '$grid.ColumnHeadersDefaultCellStyle.BackColor = $script:CurrentPalette.Card', 'cabecalho grade')

# Nomes mais claros e curtos.
repls = [
    ('$importButton.Text = "IMPORTAR PLANILHA"', '$importButton.Text = "IMPORTAR EXCEL"'),
    ('$exportButton.Text = "EXPORTAR EXCEL"', '$exportButton.Text = "EXCEL OFICIAL"'),
    ('$reviewIssuesButton.Text = "VER PENDÊNCIAS"', '$reviewIssuesButton.Text = "PENDÊNCIAS"'),
    ('$exportCheckButton.Text = "CONFERIR EXPORTAÇÃO"', '$exportCheckButton.Text = "VALIDAR EXCEL"'),
    ('$newButton.Text = "+ NOVO REGISTRO"; $newButton.Width = 145', '$newButton.Text = "+ NOVA NF"; $newButton.Width = 105'),
    ('$editButton.Text = "EDITAR SELEÇÃO"; $editButton.Width = 125', '$editButton.Text = "EDITAR"; $editButton.Width = 82'),
    ('$outputButton.Text = "REGISTRAR SAÍDA"; $outputButton.Width = 135', '$outputButton.Text = "SAÍDA"; $outputButton.Width = 78'),
    ('$clearFiltersButton.Text = "LIMPAR FILTROS"; $clearFiltersButton.Width = 120', '$clearFiltersButton.Text = "FILTROS"; $clearFiltersButton.Width = 82'),
    ('$exportListButton.Text = "EXPORTAR LISTA"; $exportListButton.Width = 120', '$exportListButton.Text = "CSV"; $exportListButton.Width = 68'),
    ('$deleteButton.Text = "EXCLUIR"; $deleteButton.Width = 95', '$deleteButton.Text = "EXCLUIR"; $deleteButton.Width = 82'),
    ('$movementExportButton.Text="EXPORTAR CSV"; $movementExportButton.Width=115', '$movementExportButton.Text="CSV"; $movementExportButton.Width=72'),
    ('$movementOpenButton.Text="ABRIR NF"; $movementOpenButton.Width=110', '$movementOpenButton.Text="IR PARA NF"; $movementOpenButton.Width=92'),
    ('$movementReverseButton.Text="ESTORNAR SAÍDA"; $movementReverseButton.Width=135', '$movementReverseButton.Text="ESTORNAR"; $movementReverseButton.Width=96'),
    ('$historyDetailsButton.Text = "VER DETALHES"; $historyDetailsButton.Width = 125', '$historyDetailsButton.Text = "DETALHES"; $historyDetailsButton.Width = 96'),
    ('$historyExportButton.Text = "EXPORTAR CSV"; $historyExportButton.Width = 115', '$historyExportButton.Text = "CSV"; $historyExportButton.Width = 72'),
    ('$integrityButton.Text = "VERIFICAR INTEGRIDADE"; $integrityButton.Width = 165', '$integrityButton.Text = "VERIFICAR"; $integrityButton.Width = 100'),
    ('$manualBackupButton.Text = "CRIAR BACKUP AGORA"; $manualBackupButton.Width = 150', '$manualBackupButton.Text = "NOVO BACKUP"; $manualBackupButton.Width = 108'),
    ('$restoreBackupButton.Text = "RESTAURAR SELECIONADO"; $restoreBackupButton.Width = 175', '$restoreBackupButton.Text = "RESTAURAR"; $restoreBackupButton.Width = 105'),
]
for old, new in repls:
    if old not in ui:
        raise SystemExit('Polimento NF: rotulo esperado ausente: ' + old)
    ui = ui.replace(old, new, 1)

# Rodape mais limpo para nao cortar texto.
old_status = 'Set-NFStatus ("Pronto • " + $totalRecords + " registro(s) • Em estoque por padrão • Ctrl+N novo • Enter editar • Ctrl+S saída • Ctrl+E exportar • Ctrl+F pesquisar") "Normal"'
new_status = 'Set-NFStatus ("Pronto • " + $totalRecords + " registro(s) • Em estoque por padrão") "Normal"'
ui = rep(ui, old_status, new_status, 'status compacto')

# Tooltips deixam claro o que os rotulos curtos fazem.
ui = rep(ui, '$toolTip.SetToolTip($newButton, "Novo registro (Ctrl+N).")', '$toolTip.SetToolTip($newButton, "Nova NF (Ctrl+N).")', 'tooltip novo')
ui = rep(ui, '$toolTip.SetToolTip($clearFiltersButton, "Limpa a pesquisa e volta para Em estoque / Todos os códigos.")', '$toolTip.SetToolTip($clearFiltersButton, "Limpa pesquisa, status e código; volta para Em estoque.")', 'tooltip filtros')
ui = rep(ui, '$toolTip.SetToolTip($exportListButton, "Exporta somente as linhas visíveis da aba atual, respeitando pesquisa, status e código (Ctrl+E).")', '$toolTip.SetToolTip($exportListButton, "Exporta a visão atual em CSV (Ctrl+E). Diferente do Excel oficial completo.")', 'tooltip csv')

for marker in ('$script:ModuleVersion = "2.4.1"', 'EXCEL OFICIAL', '$newButton.Text = "+ NOVA NF"', '$exportListButton.Text = "CSV"', '$integrityButton.Text = "VERIFICAR"', 'Accent = [Drawing.Color]::FromArgb(39, 196, 125)'):
    if marker not in ui:
        raise SystemExit('Polimento NF: marcador final ausente: ' + marker)

UI.write_text(ui, encoding='utf-8')
CENTRAL.write_text(central, encoding='utf-8')
print('POLIMENTO NF: OK - cores, rotulos, larguras e rodape revisados; Central 0.21.17 / NF Entrada 2.4.1.')
