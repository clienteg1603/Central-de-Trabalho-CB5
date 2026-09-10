from pathlib import Path

repo = Path('.')
central_path = repo / 'src/generated/Central de Trabalho.ps1'
maint_path = repo / 'src/generated/Modulos/Central-de-Manutencao-CB5/Central Manutencao CB5.ps1'

central = central_path.read_text(encoding='utf-8-sig')
text = maint_path.read_text(encoding='utf-8-sig')
marker = '# TECH_PAGES_V0114'

if marker in text:
    print('Polimento técnico v0.11.4 já aplicado.')
    raise SystemExit(0)

def rep(source, old, new, label):
    count = source.count(old)
    if count != 1:
        raise RuntimeError(f'{label}: esperado 1 trecho, encontrado {count}')
    return source.replace(old, new, 1)

# Versões.
central = rep(central, '$script:AppVersion = "0.11.3"', '$script:AppVersion = "0.11.4"', 'versão Central')
central = rep(central, '$script:MaintenanceVersion = "0.5.3"', '$script:MaintenanceVersion = "0.5.4"', 'versão Manutenção na Central')
text = rep(text, '$script:AppVersion = "0.5.3"', '$script:AppVersion = "0.5.4"', 'versão interna Manutenção')

# Estatísticas: cabeçalho com hierarquia mais limpa, sem acrescentar nova navegação.
old_stats_header = '''$statisticsRoot = New-Object Windows.Forms.TableLayoutPanel
$statisticsRoot.Dock = [Windows.Forms.DockStyle]::Fill
$statisticsRoot.Padding = [Windows.Forms.Padding]::new(16)
$statisticsRoot.RowCount = 2
[void]$statisticsRoot.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 66)))
[void]$statisticsRoot.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 100)))
$statisticsTab.Controls.Add($statisticsRoot)
$statisticsTitle = New-Object Windows.Forms.Label
$statisticsTitle.Text = "Distribuições calculadas com o histórico real acumulado"
$statisticsTitle.Dock = [Windows.Forms.DockStyle]::Fill
$statisticsTitle.TextAlign = [Drawing.ContentAlignment]::MiddleLeft
$statisticsTitle.Font = [Drawing.Font]::new("Segoe UI Semibold", 17)
$statisticsRoot.Controls.Add($statisticsTitle, 0, 0)
$statsTabs = New-Object Windows.Forms.TabControl
$statsTabs.Dock = [Windows.Forms.DockStyle]::Fill
$statisticsRoot.Controls.Add($statsTabs, 0, 1)'''
new_stats_header = '''$statisticsRoot = New-Object Windows.Forms.TableLayoutPanel
$statisticsRoot.Dock = [Windows.Forms.DockStyle]::Fill
$statisticsRoot.Padding = [Windows.Forms.Padding]::new(16)
$statisticsRoot.RowCount = 2
[void]$statisticsRoot.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 66)))
[void]$statisticsRoot.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 100)))
$statisticsTab.Controls.Add($statisticsRoot)

$statisticsHeader = New-Object Windows.Forms.TableLayoutPanel
$statisticsHeader.Dock = [Windows.Forms.DockStyle]::Fill
$statisticsHeader.Margin = [Windows.Forms.Padding]::new(0)
$statisticsHeader.RowCount = 2
$statisticsHeader.ColumnCount = 1
[void]$statisticsHeader.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 58)))
[void]$statisticsHeader.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 42)))
$statisticsRoot.Controls.Add($statisticsHeader, 0, 0)

$statisticsTitle = New-Object Windows.Forms.Label
$statisticsTitle.Text = "Estatísticas da manutenção"
$statisticsTitle.Dock = [Windows.Forms.DockStyle]::Fill
$statisticsTitle.TextAlign = [Drawing.ContentAlignment]::BottomLeft
$statisticsTitle.Font = [Drawing.Font]::new("Segoe UI Semibold", 15)
$statisticsHeader.Controls.Add($statisticsTitle, 0, 0)

$statisticsSubtitle = New-Object Windows.Forms.Label
$statisticsSubtitle.Text = "Distribuições calculadas somente com o histórico real acumulado."
$statisticsSubtitle.Dock = [Windows.Forms.DockStyle]::Fill
$statisticsSubtitle.TextAlign = [Drawing.ContentAlignment]::TopLeft
$statisticsSubtitle.Font = [Drawing.Font]::new("Segoe UI", 8.8)
$statisticsHeader.Controls.Add($statisticsSubtitle, 0, 1)

$statsTabs = New-Object Windows.Forms.TabControl
$statsTabs.Dock = [Windows.Forms.DockStyle]::Fill
$statsTabs.DrawMode = [Windows.Forms.TabDrawMode]::OwnerDrawFixed
$statsTabs.SizeMode = [Windows.Forms.TabSizeMode]::Fixed
$statsTabs.ItemSize = [Drawing.Size]::new(132, 28)
$statsTabs.Multiline = $true
$statsTabs.HotTrack = $true
$statsTabs.Padding = [Drawing.Point]::new(5, 2)
$statisticsRoot.Controls.Add($statsTabs, 0, 1)'''
text = rep(text, old_stats_header, new_stats_header, 'cabeçalho Estatísticas')

# Histórico: remove de verdade o botão FILTRAR invisível e redistribui o espaço.
text = rep(text, '$historyFilterLayout.ColumnCount = 6', '$historyFilterLayout.ColumnCount = 5', 'colunas Histórico')
old_history_cols = '''[void]$historyFilterLayout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 24)))
[void]$historyFilterLayout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 17)))
[void]$historyFilterLayout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 22)))
[void]$historyFilterLayout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 17)))
[void]$historyFilterLayout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 10)))
[void]$historyFilterLayout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 10)))'''
new_history_cols = '''[void]$historyFilterLayout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 24)))
[void]$historyFilterLayout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 17)))
[void]$historyFilterLayout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 22)))
[void]$historyFilterLayout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 17)))
[void]$historyFilterLayout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 20)))'''
text = rep(text, old_history_cols, new_history_cols, 'larguras Histórico')
old_filter_button = '''$historyFilterButton = New-Object Windows.Forms.Button
$historyFilterButton.Text = "FILTRAR"
$historyFilterButton.Dock = [Windows.Forms.DockStyle]::Fill
$historyFilterButton.Tag = "Primary"
$historyFilterLayout.Controls.Add($historyFilterButton, 4, 0)
$historyFilterButton.Visible = $false
$historyFilterLayout.ColumnStyles[4].Width = 0
$historyFilterLayout.ColumnStyles[5].Width = 20
'''
text = rep(text, old_filter_button, '', 'botão FILTRAR')
text = rep(text, '$historyFilterLayout.Controls.Add($historyClearButton, 5, 0)', '$historyFilterLayout.Controls.Add($historyClearButton, 4, 0)', 'posição Limpar filtros')
text = rep(text, '$historyFilterButton.Add_Click({ Refresh-HistoryGrid })\n', '', 'evento FILTRAR')

# Diagnóstico: cartões informativos mais legíveis.
old_hypothesis = '''$hypothesisNotice.Dock = [Windows.Forms.DockStyle]::Fill
$hypothesisNotice.Padding = [Windows.Forms.Padding]::new(14)
$hypothesisNotice.TextAlign = [Drawing.ContentAlignment]::MiddleLeft
$hypothesisNotice.Font = [Drawing.Font]::new("Segoe UI Semibold", 10)
$diagnosisRoot.Controls.Add($hypothesisNotice, 0, 0)'''
new_hypothesis = '''$hypothesisNotice.Dock = [Windows.Forms.DockStyle]::Fill
$hypothesisNotice.Margin = [Windows.Forms.Padding]::new(2, 2, 2, 8)
$hypothesisNotice.Padding = [Windows.Forms.Padding]::new(14, 10, 14, 10)
$hypothesisNotice.TextAlign = [Drawing.ContentAlignment]::MiddleLeft
$hypothesisNotice.Font = [Drawing.Font]::new("Segoe UI Semibold", 9.4)
$hypothesisNotice.Add_SizeChanged({ Set-MaintenanceRoundedRegion $this 10 })
$diagnosisRoot.Controls.Add($hypothesisNotice, 0, 0)'''
text = rep(text, old_hypothesis, new_hypothesis, 'aviso Diagnóstico')
old_diag_result = '''$diagnosisResultLabel.Text = "Preencha a versão e o defeito para consultar o histórico."
$diagnosisResultLabel.Dock = [Windows.Forms.DockStyle]::Fill
$diagnosisResultLabel.TextAlign = [Drawing.ContentAlignment]::MiddleLeft
$diagnosisRoot.Controls.Add($diagnosisResultLabel, 0, 2)'''
new_diag_result = '''$diagnosisResultLabel.Text = "Preencha a versão e o defeito para consultar o histórico."
$diagnosisResultLabel.Dock = [Windows.Forms.DockStyle]::Fill
$diagnosisResultLabel.Margin = [Windows.Forms.Padding]::new(2, 5, 2, 5)
$diagnosisResultLabel.Padding = [Windows.Forms.Padding]::new(10, 4, 10, 4)
$diagnosisResultLabel.TextAlign = [Drawing.ContentAlignment]::MiddleLeft
$diagnosisResultLabel.Add_SizeChanged({ Set-MaintenanceRoundedRegion $this 8 })
$diagnosisRoot.Controls.Add($diagnosisResultLabel, 0, 2)'''
text = rep(text, old_diag_result, new_diag_result, 'resultado Diagnóstico')

# Esquemáticos: remove de verdade BUSCAR (a busca já é instantânea) e devolve espaço ao campo de pesquisa.
text = rep(text, '$schemaSearchLayout.ColumnCount = 5', '$schemaSearchLayout.ColumnCount = 4', 'colunas Esquemáticos')
old_schema_cols = '''[void]$schemaSearchLayout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Absolute, 180)))
[void]$schemaSearchLayout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 100)))
[void]$schemaSearchLayout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Absolute, 140)))
[void]$schemaSearchLayout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Absolute, 190)))
[void]$schemaSearchLayout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Absolute, 150)))'''
new_schema_cols = '''[void]$schemaSearchLayout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Absolute, 180)))
[void]$schemaSearchLayout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 100)))
[void]$schemaSearchLayout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Absolute, 190)))
[void]$schemaSearchLayout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Absolute, 150)))'''
text = rep(text, old_schema_cols, new_schema_cols, 'larguras Esquemáticos')
old_schema_button = '''$schemaSearchButton = New-Object Windows.Forms.Button
$schemaSearchButton.Text = "BUSCAR"
$schemaSearchButton.Dock = [Windows.Forms.DockStyle]::Fill
$schemaSearchButton.Margin = [Windows.Forms.Padding]::new(8, 10, 8, 10)
$schemaSearchButton.Tag = "Primary"
$schemaSearchLayout.Controls.Add($schemaSearchButton, 2, 0)
$schemaSearchButton.Visible = $false
$schemaSearchLayout.ColumnStyles[2].Width = 0
'''
text = rep(text, old_schema_button, '', 'botão BUSCAR Esquemáticos')
text = rep(text, '$schemaSearchLayout.Controls.Add($schemaOpenButton, 3, 0)', '$schemaSearchLayout.Controls.Add($schemaOpenButton, 2, 0)', 'posição Abrir esquemático')
text = rep(text, '$schemaSearchLayout.Controls.Add($schemaRemoveButton, 4, 0)', '$schemaSearchLayout.Controls.Add($schemaRemoveButton, 3, 0)', 'posição Remover esquemático')
text = rep(text, '$schemaSearchButton.Add_Click({ Refresh-SchematicGrid })\n', '', 'evento BUSCAR Esquemáticos')

old_schema_notice = '''$schemaNotice.Dock = [Windows.Forms.DockStyle]::Fill
$schemaNotice.Padding = [Windows.Forms.Padding]::new(14)
$schemaNotice.TextAlign = [Drawing.ContentAlignment]::MiddleLeft
$schemaRoot.Controls.Add($schemaNotice, 0, 0)'''
new_schema_notice = '''$schemaNotice.Dock = [Windows.Forms.DockStyle]::Fill
$schemaNotice.Margin = [Windows.Forms.Padding]::new(2, 2, 2, 8)
$schemaNotice.Padding = [Windows.Forms.Padding]::new(14, 10, 14, 10)
$schemaNotice.TextAlign = [Drawing.ContentAlignment]::MiddleLeft
$schemaNotice.Font = [Drawing.Font]::new("Segoe UI", 8.8)
$schemaNotice.Add_SizeChanged({ Set-MaintenanceRoundedRegion $this 10 })
$schemaRoot.Controls.Add($schemaNotice, 0, 0)'''
text = rep(text, old_schema_notice, new_schema_notice, 'aviso Esquemáticos')

# Tema: subtítulo e painéis técnicos respeitam a paleta.
old_theme_tail = '''    if ($null -ne $dashboardSubtitle) { $dashboardSubtitle.ForeColor = $script:CurrentPalette.Muted }
    $versionBadge.BackColor = $script:CurrentPalette.SuccessBack'''
new_theme_tail = '''    if ($null -ne $dashboardSubtitle) { $dashboardSubtitle.ForeColor = $script:CurrentPalette.Muted }
    if ($null -ne $statisticsSubtitle) { $statisticsSubtitle.ForeColor = $script:CurrentPalette.Muted }
    $versionBadge.BackColor = $script:CurrentPalette.SuccessBack'''
text = rep(text, old_theme_tail, new_theme_tail, 'tema subtítulo Estatísticas')
old_theme_notices = '''    $hypothesisNotice.BackColor = $script:CurrentPalette.WarningBack
    $hypothesisNotice.ForeColor = $script:CurrentPalette.Warning
    $schemaNotice.BackColor = $script:CurrentPalette.SuccessBack
    $schemaNotice.ForeColor = $script:CurrentPalette.Success
    $statusLabel.ForeColor = $script:CurrentPalette.Muted'''
new_theme_notices = '''    $hypothesisNotice.BackColor = $script:CurrentPalette.WarningBack
    $hypothesisNotice.ForeColor = $script:CurrentPalette.Warning
    Set-MaintenanceRoundedRegion $hypothesisNotice 10
    $diagnosisResultLabel.BackColor = $script:CurrentPalette.Surface
    $diagnosisResultLabel.ForeColor = $script:CurrentPalette.Muted
    Set-MaintenanceRoundedRegion $diagnosisResultLabel 8
    $schemaNotice.BackColor = $script:CurrentPalette.SuccessBack
    $schemaNotice.ForeColor = $script:CurrentPalette.Success
    Set-MaintenanceRoundedRegion $schemaNotice 10
    $codeRulesText.BackColor = $script:CurrentPalette.Card
    $codeRulesText.ForeColor = $script:CurrentPalette.Text
    $codeRulesText.BorderStyle = [Windows.Forms.BorderStyle]::None
    $statusLabel.ForeColor = $script:CurrentPalette.Muted
    $statsTabs.Invalidate()'''
text = rep(text, old_theme_notices, new_theme_notices, 'tema telas técnicas')

# Responsividade das páginas técnicas: alturas e densidade acompanham o perfil real do módulo.
responsive_anchor = '''        # Dashboard: 4 cards só quando realmente há largura. Nos tamanhos mais comuns
        # da Central integrada, vira 2x2 para evitar cartão truncado.'''
responsive_insert = '''        # Telas técnicas também acompanham o perfil da área real hospedada.
        $technicalPadding = if ($profile -eq "Tight") { 7 } elseif ($profile -eq "Compact") { 10 } else { 14 }
        $historyRoot.Padding = [Windows.Forms.Padding]::new($technicalPadding)
        $statisticsRoot.Padding = [Windows.Forms.Padding]::new($technicalPadding)
        $diagnosisRoot.Padding = [Windows.Forms.Padding]::new($technicalPadding)
        $schemaRoot.Padding = [Windows.Forms.Padding]::new($technicalPadding)
        $rulesRoot.Padding = [Windows.Forms.Padding]::new($technicalPadding)
        $statisticsRoot.RowStyles[0].Height = if ($profile -eq "Tight") { 50 } elseif ($profile -eq "Compact") { 58 } else { 66 }
        $diagnosisRoot.RowStyles[0].Height = if ($profile -eq "Tight") { 64 } elseif ($profile -eq "Compact") { 72 } else { 82 }
        $diagnosisRoot.RowStyles[1].Height = if ($profile -eq "Tight") { 128 } elseif ($profile -eq "Compact") { 145 } else { 165 }
        $diagnosisRoot.RowStyles[2].Height = if ($profile -eq "Tight") { 42 } elseif ($profile -eq "Compact") { 46 } else { 50 }
        $schemaRoot.RowStyles[0].Height = if ($profile -eq "Tight") { 58 } elseif ($profile -eq "Compact") { 66 } else { 76 }
        $schemaRoot.RowStyles[1].Height = if ($profile -eq "Tight") { 52 } elseif ($profile -eq "Compact") { 60 } else { 70 }
        $schemaRoot.RowStyles[3].Height = if ($profile -eq "Tight") { 168 } elseif ($profile -eq "Compact") { 188 } else { 210 }
        $rulesRoot.RowStyles[1].Height = if ($profile -eq "Tight") { 70 } elseif ($profile -eq "Compact") { 80 } else { 92 }
        $statisticsTitle.Font = [Drawing.Font]::new("Segoe UI Semibold", $(if ($profile -eq "Tight") { 11.5 } elseif ($profile -eq "Compact") { 12.5 } else { 14.0 }))
        $statisticsSubtitle.Font = [Drawing.Font]::new("Segoe UI", $(if ($profile -eq "Tight") { 7.4 } elseif ($profile -eq "Compact") { 7.9 } else { 8.5 }))
        $statsTabs.ItemSize = [Drawing.Size]::new($(if ($profile -eq "Tight") { 108 } elseif ($profile -eq "Compact") { 120 } else { 132 }), $(if ($profile -eq "Tight") { 24 } elseif ($profile -eq "Compact") { 26 } else { 28 }))

''' + responsive_anchor
text = rep(text, responsive_anchor, responsive_insert, 'responsividade técnica')

# Desenho das abas internas de Estatísticas no mesmo padrão da Manutenção.
draw_anchor = '$mainTabs.Add_DrawItem({\n'
stats_draw = '''$statsTabs.Add_DrawItem({
    param($sender, $eventArgs)
    if ($null -eq $script:CurrentPalette) { return }
    $page = $sender.TabPages[$eventArgs.Index]
    $selected = ($eventArgs.Index -eq $sender.SelectedIndex)
    $background = if ($selected) { $script:CurrentPalette.Card } else { $script:CurrentPalette.Surface }
    $foreground = if ($selected) { $script:CurrentPalette.Text } else { $script:CurrentPalette.Muted }
    $brush = New-Object Drawing.SolidBrush($background)
    $lineBrush = New-Object Drawing.SolidBrush($(if ($selected) { $script:CurrentPalette.Accent } else { $script:CurrentPalette.Border }))
    try {
        $eventArgs.Graphics.FillRectangle($brush, $eventArgs.Bounds)
        $lineHeight = if ($selected) { 3 } else { 1 }
        $lineRect = [Drawing.Rectangle]::new($eventArgs.Bounds.Left + 4, $eventArgs.Bounds.Bottom - $lineHeight, [Math]::Max(1,$eventArgs.Bounds.Width - 8), $lineHeight)
        $eventArgs.Graphics.FillRectangle($lineBrush, $lineRect)
        [Windows.Forms.TextRenderer]::DrawText(
            $eventArgs.Graphics,
            $page.Text,
            $form.Font,
            $eventArgs.Bounds,
            $foreground,
            ([Windows.Forms.TextFormatFlags]::HorizontalCenter -bor [Windows.Forms.TextFormatFlags]::VerticalCenter -bor [Windows.Forms.TextFormatFlags]::EndEllipsis)
        )
    }
    finally { $brush.Dispose(); $lineBrush.Dispose() }
})

''' + draw_anchor
text = rep(text, draw_anchor, stats_draw, 'desenho abas Estatísticas')

# Marca idempotente antes da inicialização final.
final_anchor = '# UI_DEDUP_V0113\n'
if final_anchor not in text:
    raise RuntimeError('marcador UI_DEDUP_V0113 não encontrado')
text = text.replace(final_anchor, final_anchor + marker + '\n', 1)

central_path.write_text(central, encoding='utf-8', newline='')
maint_path.write_text(text, encoding='utf-8', newline='')
print('Polimento técnico v0.11.4 aplicado com sucesso.')
