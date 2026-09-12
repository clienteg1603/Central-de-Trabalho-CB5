from pathlib import Path

central_path = Path('src/generated/Central de Trabalho.ps1')
generator_path = Path('src/generated/Modulos/Gerador-de-Planilhas-CB5-TV5/Gerador Planilhas.ps1')

central = central_path.read_text(encoding='utf-8-sig')
generator = generator_path.read_text(encoding='utf-8-sig')


def one(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: esperado 1 marcador, encontrado {count}')
    return text.replace(old, new, 1)


# Versões da CURA 5.
central = one(central, '$script:AppVersion = "0.21.38"', '$script:AppVersion = "0.21.39"', 'versao Central')
central = one(central, '$script:GeneratorVersion = "3.7.11"', '$script:GeneratorVersion = "3.7.12"', 'versao Gerenciador na Central')
generator = one(generator, '$script:AppVersion = "3.7.11"', '$script:AppVersion = "3.7.12"', 'versao Gerenciador')

# Um pouco mais de respiro entre a casca da Central e o TabControl do Gerenciador.
generator = one(
    generator,
    '$tabs.Margin = New-Object Windows.Forms.Padding(6, 4, 6, 3)',
    '$tabs.Margin = New-Object Windows.Forms.Padding(8, 6, 8, 4)',
    'margem das abas hospedadas'
)

# A barra inferior passa a ter uma divisoria discreta, sem alterar botoes ou eventos.
generator = one(
    generator,
    '''$footerPanel.Anchor = "None"\n$footerPanel.Dock = [Windows.Forms.DockStyle]::Bottom\n$form.Controls.Add($footerPanel)''',
    '''$footerPanel.Anchor = "None"\n$footerPanel.Dock = [Windows.Forms.DockStyle]::Bottom\n$form.Controls.Add($footerPanel)\n\n$footerDivider = $null\nif ($script:IsInProcessHosted) {\n    $footerDivider = New-Object Windows.Forms.Panel\n    $footerDivider.Dock = [Windows.Forms.DockStyle]::Top\n    $footerDivider.Height = 1\n    $footerDivider.Margin = New-Object Windows.Forms.Padding(0)\n    $footerPanel.Controls.Add($footerDivider)\n    $footerDivider.BringToFront()\n}''',
    'divisoria do rodape'
)

generator = one(
    generator,
    '''    $headerPanel.BackColor = $palette.Surface\n    $footerPanel.BackColor = $palette.Surface\n    $tabs.BackColor = $palette.Background''',
    '''    $headerPanel.BackColor = $palette.Surface\n    $footerPanel.BackColor = $palette.Surface\n    if ($null -ne $footerDivider) { $footerDivider.BackColor = $palette.Border }\n    $tabs.BackColor = $palette.Background''',
    'tema da divisoria do rodape'
)

# Titulos de acao recebem a cor de destaque; textos explicativos continuam neutros.
generator = one(
    generator,
    '''    $summaryProductValue.ForeColor = $palette.Accent\n    foreach ($label in @($componentActiveValue, $componentPendingValue, $componentOperationsValue)) { $label.ForeColor = $palette.Accent }''',
    '''    $summaryProductValue.ForeColor = $palette.Accent\n    foreach ($label in @($masterLabel, $outputLabel, $summaryTitle, $statusLabel, $combineStatusLabel)) {\n        if ($null -ne $label) { $label.ForeColor = $palette.Accent }\n    }\n    foreach ($label in @($componentActiveValue, $componentPendingValue, $componentOperationsValue)) { $label.ForeColor = $palette.Accent }''',
    'hierarquia dos titulos'
)

# Navegacao principal: no modo integrado o item ativo deixa de ser um bloco inteiro
# ciano/verde e passa a usar superficie + texto/acento inferior. Standalone permanece igual.
old_main_draw = '''$tabs.Add_DrawItem({\n    param($sender, $eventArgs)\n    $page = $sender.TabPages[$eventArgs.Index]\n    $selected = ($eventArgs.Index -eq $sender.SelectedIndex)\n    $background = if ($selected) { $script:CurrentPalette.Accent } else { $script:CurrentPalette.Panel }\n    $foreground = if ($selected) { $script:CurrentPalette.AccentText } else { $script:CurrentPalette.Text }\n    $brush = New-Object Drawing.SolidBrush($background)\n    try {\n        $eventArgs.Graphics.FillRectangle($brush, $eventArgs.Bounds)\n        [Windows.Forms.TextRenderer]::DrawText(\n            $eventArgs.Graphics,\n            $page.Text,\n            $form.Font,\n            $eventArgs.Bounds,\n            $foreground,\n            ([Windows.Forms.TextFormatFlags]::HorizontalCenter -bor [Windows.Forms.TextFormatFlags]::VerticalCenter -bor [Windows.Forms.TextFormatFlags]::EndEllipsis)\n        )\n    }\n    finally { $brush.Dispose() }\n})'''
new_main_draw = '''$tabs.Add_DrawItem({\n    param($sender, $eventArgs)\n    $page = $sender.TabPages[$eventArgs.Index]\n    $selected = ($eventArgs.Index -eq $sender.SelectedIndex)\n    if ($script:IsInProcessHosted) {\n        $background = if ($selected) { $script:CurrentPalette.Surface } else { $script:CurrentPalette.Background }\n        $foreground = if ($selected) { $script:CurrentPalette.Accent } else { $script:CurrentPalette.Muted }\n    }\n    else {\n        $background = if ($selected) { $script:CurrentPalette.Accent } else { $script:CurrentPalette.Panel }\n        $foreground = if ($selected) { $script:CurrentPalette.AccentText } else { $script:CurrentPalette.Text }\n    }\n    $brush = New-Object Drawing.SolidBrush($background)\n    try {\n        $eventArgs.Graphics.FillRectangle($brush, $eventArgs.Bounds)\n        [Windows.Forms.TextRenderer]::DrawText(\n            $eventArgs.Graphics,\n            $page.Text,\n            $form.Font,\n            $eventArgs.Bounds,\n            $foreground,\n            ([Windows.Forms.TextFormatFlags]::HorizontalCenter -bor [Windows.Forms.TextFormatFlags]::VerticalCenter -bor [Windows.Forms.TextFormatFlags]::EndEllipsis)\n        )\n        if ($script:IsInProcessHosted) {\n            $lineColor = if ($selected) { $script:CurrentPalette.Accent } else { $script:CurrentPalette.Border }\n            $lineHeight = if ($selected) { 3 } else { 1 }\n            $lineBrush = New-Object Drawing.SolidBrush($lineColor)\n            try {\n                $eventArgs.Graphics.FillRectangle($lineBrush, $eventArgs.Bounds.Left, ($eventArgs.Bounds.Bottom - $lineHeight), $eventArgs.Bounds.Width, $lineHeight)\n            }\n            finally { $lineBrush.Dispose() }\n        }\n    }\n    finally { $brush.Dispose() }\n})'''
generator = one(generator, old_main_draw, new_main_draw, 'desenho das abas principais')

old_component_draw = '''$componentTabs.Add_DrawItem({\n    param($sender, $eventArgs)\n    $page = $sender.TabPages[$eventArgs.Index]\n    $selected = ($eventArgs.Index -eq $sender.SelectedIndex)\n    $background = if ($selected) { $script:CurrentPalette.Accent } else { $script:CurrentPalette.Panel }\n    $foreground = if ($selected) { $script:CurrentPalette.AccentText } else { $script:CurrentPalette.Text }\n    $brush = New-Object Drawing.SolidBrush($background)\n    try {\n        $eventArgs.Graphics.FillRectangle($brush, $eventArgs.Bounds)\n        [Windows.Forms.TextRenderer]::DrawText(\n            $eventArgs.Graphics,\n            $page.Text,\n            $form.Font,\n            $eventArgs.Bounds,\n            $foreground,\n            ([Windows.Forms.TextFormatFlags]::HorizontalCenter -bor [Windows.Forms.TextFormatFlags]::VerticalCenter -bor [Windows.Forms.TextFormatFlags]::EndEllipsis)\n        )\n    }\n    finally { $brush.Dispose() }\n})'''
new_component_draw = '''$componentTabs.Add_DrawItem({\n    param($sender, $eventArgs)\n    $page = $sender.TabPages[$eventArgs.Index]\n    $selected = ($eventArgs.Index -eq $sender.SelectedIndex)\n    if ($script:IsInProcessHosted) {\n        $background = if ($selected) { $script:CurrentPalette.Surface } else { $script:CurrentPalette.Background }\n        $foreground = if ($selected) { $script:CurrentPalette.Accent } else { $script:CurrentPalette.Muted }\n    }\n    else {\n        $background = if ($selected) { $script:CurrentPalette.Accent } else { $script:CurrentPalette.Panel }\n        $foreground = if ($selected) { $script:CurrentPalette.AccentText } else { $script:CurrentPalette.Text }\n    }\n    $brush = New-Object Drawing.SolidBrush($background)\n    try {\n        $eventArgs.Graphics.FillRectangle($brush, $eventArgs.Bounds)\n        [Windows.Forms.TextRenderer]::DrawText(\n            $eventArgs.Graphics,\n            $page.Text,\n            $form.Font,\n            $eventArgs.Bounds,\n            $foreground,\n            ([Windows.Forms.TextFormatFlags]::HorizontalCenter -bor [Windows.Forms.TextFormatFlags]::VerticalCenter -bor [Windows.Forms.TextFormatFlags]::EndEllipsis)\n        )\n        if ($script:IsInProcessHosted) {\n            $lineColor = if ($selected) { $script:CurrentPalette.Accent } else { $script:CurrentPalette.Border }\n            $lineHeight = if ($selected) { 3 } else { 1 }\n            $lineBrush = New-Object Drawing.SolidBrush($lineColor)\n            try {\n                $eventArgs.Graphics.FillRectangle($lineBrush, $eventArgs.Bounds.Left, ($eventArgs.Bounds.Bottom - $lineHeight), $eventArgs.Bounds.Width, $lineHeight)\n            }\n            finally { $lineBrush.Dispose() }\n        }\n    }\n    finally { $brush.Dispose() }\n})'''
generator = one(generator, old_component_draw, new_component_draw, 'desenho das abas de componentes')

# Marcador para auditoria humana e contratos futuros.
generator += '\n# CURA5_GENERATOR_VISUAL_V03712\n'

for marker in (
    '$script:AppVersion = "0.21.39"',
    '$script:GeneratorVersion = "3.7.12"',
):
    if marker not in central:
        raise SystemExit('marcador ausente na Central: ' + marker)

for marker in (
    '$script:AppVersion = "3.7.12"',
    'CURA5_GENERATOR_VISUAL_V03712',
    '$footerDivider.BackColor = $palette.Border',
    '$foreground = if ($selected) { $script:CurrentPalette.Accent } else { $script:CurrentPalette.Muted }',
):
    if marker not in generator:
        raise SystemExit('marcador ausente no Gerenciador: ' + marker)

central_path.write_text(central, encoding='utf-8')
generator_path.write_text(generator, encoding='utf-8')
print('CURA 5 GERENCIADOR: OK - navegacao integrada, hierarquia visual e rodape refinados sem alterar fluxos operacionais.')
