from pathlib import Path

central_path = Path('src/generated/Central de Trabalho.ps1')
generator_path = Path('src/generated/Modulos/Gerador-de-Planilhas-CB5-TV5/Gerador Planilhas.ps1')
central = central_path.read_text(encoding='utf-8-sig')
generator = generator_path.read_text(encoding='utf-8-sig')


def one(text, old, new, label):
    if text.count(old) != 1:
        raise SystemExit(f'{label}: marcador inesperado ({text.count(old)})')
    return text.replace(old, new, 1)


def first(text, old, new, label):
    if old not in text:
        raise SystemExit(f'{label}: marcador ausente')
    return text.replace(old, new, 1)


central = one(central, '$script:AppVersion = "0.21.41"', '$script:AppVersion = "0.21.42"', 'versao Central')
central = one(central, '$script:GeneratorVersion = "3.7.13"', '$script:GeneratorVersion = "3.7.14"', 'versao Gerenciador Central')
generator = one(generator, '$script:AppVersion = "3.7.13"', '$script:AppVersion = "3.7.14"', 'versao Gerenciador')

# CB5 conserva o ciano; TV5 usa um verde técnico próximo da mesma família.
generator = one(
    generator,
    '$accent = [Drawing.Color]::FromArgb(44, 189, 197)\n            return [pscustomobject]@{',
    '$accent = if ($Product -eq "TV5") { [Drawing.Color]::FromArgb(72, 202, 143) } else { [Drawing.Color]::FromArgb(44, 189, 197) }\n            return [pscustomobject]@{',
    'acento por produto'
)

# A troca de produto repinta imediatamente os cabeçalhos owner-draw.
generator = one(
    generator,
    'if (-not $script:IsInProcessHosted -or $script:UiReady) { Apply-AppTheme }\n    Update-LiveSummary',
    'if (-not $script:IsInProcessHosted -or $script:UiReady) { Apply-AppTheme; if ($null -ne $tabs) { $tabs.Invalidate() } }\n    Update-LiveSummary',
    'repaint por produto'
)

# Mesma altura e respiro visual dos botões da Central de Manutenção.
generator = one(generator, '$tabs.ItemSize = New-Object Drawing.Size(0, 31)', '$tabs.ItemSize = New-Object Drawing.Size(0, 52)', 'altura inicial')
generator = one(generator, '$tabs.Padding = New-Object Drawing.Point(14, 5)', '$tabs.Padding = New-Object Drawing.Point(0, 0)', 'padding hospedado')
generator = one(generator, '$tabs.ItemSize = [Drawing.Size]::new($tabWidth, $tabHeaderHeight)', '$tabs.ItemSize = [Drawing.Size]::new($tabWidth, 52)', 'altura responsiva')

# Substitui somente o desenho da navegação principal. As páginas e eventos do
# TabControl continuam nativos; muda apenas a geometria visual dos cinco itens.
start = generator.find('$tabs.Add_DrawItem({')
if start < 0:
    raise SystemExit('desenho principal das abas não encontrado')
end = generator.find('\n})', start)
if end < 0:
    raise SystemExit('fim do desenho principal das abas não encontrado')
end += 3

new_draw = r'''$tabs.Add_DrawItem({
    param($sender, $eventArgs)
    $page = $sender.TabPages[$eventArgs.Index]
    $selected = ($eventArgs.Index -eq $sender.SelectedIndex)

    if ($script:IsInProcessHosted) {
        $rect = [Drawing.Rectangle]::new(
            ($eventArgs.Bounds.Left + 5),
            ($eventArgs.Bounds.Top + 5),
            [Math]::Max(1, ($eventArgs.Bounds.Width - 10)),
            [Math]::Max(1, ($eventArgs.Bounds.Height - 9))
        )
        $background = if ($selected) { $script:CurrentPalette.Accent } else { $script:CurrentPalette.Surface }
        $foreground = if ($selected) { $script:CurrentPalette.AccentText } else { $script:CurrentPalette.Text }
        $border = if ($selected) { $script:CurrentPalette.Accent } else { $script:CurrentPalette.Border }

        $d = 14
        $path = New-Object Drawing.Drawing2D.GraphicsPath
        $path.AddArc($rect.Left, $rect.Top, $d, $d, 180, 90)
        $path.AddArc(($rect.Right - $d - 1), $rect.Top, $d, $d, 270, 90)
        $path.AddArc(($rect.Right - $d - 1), ($rect.Bottom - $d - 1), $d, $d, 0, 90)
        $path.AddArc($rect.Left, ($rect.Bottom - $d - 1), $d, $d, 90, 90)
        $path.CloseFigure()
        $brush = New-Object Drawing.SolidBrush($background)
        $pen = New-Object Drawing.Pen($border, 1)
        $font = New-Object Drawing.Font("Segoe UI Semibold", 9)
        try {
            $eventArgs.Graphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
            $eventArgs.Graphics.FillPath($brush, $path)
            $eventArgs.Graphics.DrawPath($pen, $path)
            [Windows.Forms.TextRenderer]::DrawText(
                $eventArgs.Graphics, $page.Text, $font, $rect, $foreground,
                ([Windows.Forms.TextFormatFlags]::HorizontalCenter -bor [Windows.Forms.TextFormatFlags]::VerticalCenter -bor [Windows.Forms.TextFormatFlags]::EndEllipsis)
            )
        }
        finally {
            $font.Dispose(); $pen.Dispose(); $brush.Dispose(); $path.Dispose()
        }
    }
    else {
        $background = if ($selected) { $script:CurrentPalette.Accent } else { $script:CurrentPalette.Panel }
        $foreground = if ($selected) { $script:CurrentPalette.AccentText } else { $script:CurrentPalette.Text }
        $brush = New-Object Drawing.SolidBrush($background)
        try {
            $eventArgs.Graphics.FillRectangle($brush, $eventArgs.Bounds)
            [Windows.Forms.TextRenderer]::DrawText(
                $eventArgs.Graphics, $page.Text, $form.Font, $eventArgs.Bounds, $foreground,
                ([Windows.Forms.TextFormatFlags]::HorizontalCenter -bor [Windows.Forms.TextFormatFlags]::VerticalCenter -bor [Windows.Forms.TextFormatFlags]::EndEllipsis)
            )
        }
        finally { $brush.Dispose() }
    }
})'''

generator = generator[:start] + new_draw + generator[end:]
generator += '\n# GENERATOR_PRODUCT_NAV_REFINE_V03714\n'

for marker in ('$script:AppVersion = "0.21.42"', '$script:GeneratorVersion = "3.7.14"'):
    if marker not in central:
        raise SystemExit('versao final ausente: ' + marker)
for marker in ('$script:AppVersion = "3.7.14"', 'GENERATOR_PRODUCT_NAV_REFINE_V03714', '[Drawing.Color]::FromArgb(72, 202, 143)', '[Drawing.Size]::new($tabWidth, 52)'):
    if marker not in generator:
        raise SystemExit('marcador final ausente: ' + marker)

central_path.write_text(central, encoding='utf-8')
generator_path.write_text(generator, encoding='utf-8')
print('REFINO GERENCIADOR: OK - CB5 ciano, TV5 verde e navegação arredondada/espacada no padrão da Manutenção.')
