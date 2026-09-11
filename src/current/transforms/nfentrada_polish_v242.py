from pathlib import Path

ROOT = Path('.')
UI = ROOT / 'src/generated/Modulos/Controle-NF-Entrada/Controle NF Entrada.ps1'
CENTRAL = ROOT / 'src/generated/Central de Trabalho.ps1'


def read(path):
    return path.read_text(encoding='utf-8-sig')


def write(path, text):
    path.write_text(text, encoding='utf-8')


def rep(text, old, new, label, expected=1):
    count = text.count(old)
    if count != expected:
        raise SystemExit(f'Polimento 2.4.2: marcador inesperado em {label}: {count} (esperado {expected})')
    return text.replace(old, new)


ui = read(UI)
central = read(CENTRAL)

ui = rep(ui, '$script:ModuleVersion = "2.4.1"', '$script:ModuleVersion = "2.4.2"', 'versão do módulo')
central = rep(central, '$script:AppVersion = "0.21.17"', '$script:AppVersion = "0.21.18"', 'versão da Central')
central = rep(central, '$script:NFEntradaVersion = "2.4.1"', '$script:NFEntradaVersion = "2.4.2"', 'versão NF Entrada na Central')

old_rows = '''[void]$root.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 78)))
[void]$root.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 112)))
[void]$root.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 100)))
[void]$root.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 46)))'''
new_rows = '''[void]$root.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 92)))
[void]$root.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 108)))
[void]$root.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 100)))
[void]$root.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 58)))'''
ui = rep(ui, old_rows, new_rows, 'alturas principais')

old_heading = '''[void]$heading.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 62)))
[void]$heading.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 38)))'''
new_heading = '''[void]$heading.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 54)))
[void]$heading.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 100)))'''
ui = rep(ui, old_heading, new_heading, 'área do título e subtítulo')

ui = rep(
    ui,
    '$actionPanel.Padding = [Windows.Forms.Padding]::new(0, 3, 0, 0)',
    '$actionPanel.Padding = [Windows.Forms.Padding]::new(0, 1, 0, 1)\n$actionPanel.Margin = [Windows.Forms.Padding]::new(0)',
    'margem da barra de ações'
)
ui = rep(
    ui,
    '$footerHost.Padding = [Windows.Forms.Padding]::new(8, 3, 8, 3)',
    '$footerHost.Padding = [Windows.Forms.Padding]::new(8, 8, 8, 8)\n$footerHost.Margin = [Windows.Forms.Padding]::new(0)',
    'respiro do rodapé'
)

# Alinha o acento do módulo com a própria paleta da Central; elimina a faixa roxa remanescente.
old_accent = '''    if ($Module -eq "NFEntrada") {
        if ($theme -eq "Claro corporativo") { return [Drawing.Color]::FromArgb(117, 90, 200) }
        if ($theme -eq "Técnico industrial") { return [Drawing.Color]::FromArgb(155, 120, 255) }
        if ($theme -eq "Alto contraste") { return [Drawing.Color]::Fuchsia }
        return [Drawing.Color]::FromArgb(139, 92, 246)
    }'''
new_accent = '''    if ($Module -eq "NFEntrada") {
        if ($theme -eq "Claro corporativo") { return [Drawing.Color]::FromArgb(47, 112, 230) }
        if ($theme -eq "Técnico industrial") { return [Drawing.Color]::FromArgb(35, 179, 158) }
        if ($theme -eq "Alto contraste") { return [Drawing.Color]::Yellow }
        return [Drawing.Color]::FromArgb(39, 196, 125)
    }'''
central = rep(central, old_accent, new_accent, 'acento visual NF Entrada')

# A Central já sincronizava Gerenciador e Manutenção; passa a sincronizar também NF Entrada.
old_sync = '''            $generatorCmd = Get-Command -Name Set-HostedGeneratorTheme -ErrorAction SilentlyContinue
            if ($null -ne $generatorCmd) { Set-HostedGeneratorTheme $hostTheme }
        } $theme'''
new_sync = '''            $generatorCmd = Get-Command -Name Set-HostedGeneratorTheme -ErrorAction SilentlyContinue
            if ($null -ne $generatorCmd) { Set-HostedGeneratorTheme $hostTheme; return }
            $nfEntradaCmd = Get-Command -Name Set-HostedNFEntradaTheme -ErrorAction SilentlyContinue
            if ($null -ne $nfEntradaCmd) { Set-HostedNFEntradaTheme $hostTheme }
        } $theme'''
central = rep(central, old_sync, new_sync, 'sincronização de tema do módulo')

live_theme = r'''function Set-HostedNFEntradaTheme {
    param([string]$Theme)
    if ([string]::IsNullOrWhiteSpace($Theme)) { return }

    $oldPalette = $script:CurrentPalette
    $newPalette = Get-NFEntradaPalette $Theme
    if ($null -eq $newPalette) { return }

    $mapColor = {
        param([Drawing.Color]$Color)
        if ($null -eq $oldPalette) { return $Color }
        $pairs = @(
            @($oldPalette.Background, $newPalette.Background),
            @($oldPalette.Surface, $newPalette.Surface),
            @($oldPalette.Card, $newPalette.Card),
            @($oldPalette.Input, $newPalette.Input),
            @($oldPalette.Text, $newPalette.Text),
            @($oldPalette.Muted, $newPalette.Muted),
            @($oldPalette.Border, $newPalette.Border),
            @($oldPalette.Accent, $newPalette.Accent),
            @($oldPalette.AccentStrong, $newPalette.AccentStrong),
            @($oldPalette.AccentText, $newPalette.AccentText),
            @($oldPalette.Success, $newPalette.Success),
            @($oldPalette.SuccessBack, $newPalette.SuccessBack),
            @($oldPalette.Warning, $newPalette.Warning),
            @($oldPalette.WarningBack, $newPalette.WarningBack),
            @($oldPalette.Danger, $newPalette.Danger),
            @($oldPalette.DangerBack, $newPalette.DangerBack)
        )
        foreach ($pair in $pairs) {
            try {
                if ($Color.ToArgb() -eq $pair[0].ToArgb()) { return $pair[1] }
            } catch {}
        }
        return $Color
    }.GetNewClosure()

    $script:CurrentPalette = $newPalette

    if ($null -ne $form -and -not $form.IsDisposed) {
        $stack = New-Object System.Collections.Stack
        $stack.Push($form)
        while ($stack.Count -gt 0) {
            $control = $stack.Pop()
            try { $control.BackColor = & $mapColor $control.BackColor } catch {}
            try { $control.ForeColor = & $mapColor $control.ForeColor } catch {}

            if ($control -is [Windows.Forms.Button]) {
                try { $control.FlatAppearance.BorderColor = & $mapColor $control.FlatAppearance.BorderColor } catch {}
            }
            elseif ($control -is [Windows.Forms.DataGridView]) {
                try {
                    $control.BackgroundColor = $newPalette.Surface
                    $control.GridColor = $newPalette.Border
                    $control.ColumnHeadersDefaultCellStyle.BackColor = $newPalette.Surface
                    $control.ColumnHeadersDefaultCellStyle.ForeColor = $newPalette.Text
                    $control.DefaultCellStyle.BackColor = $newPalette.Surface
                    $control.DefaultCellStyle.ForeColor = $newPalette.Text
                    $control.DefaultCellStyle.SelectionBackColor = $newPalette.AccentStrong
                    $control.DefaultCellStyle.SelectionForeColor = $newPalette.AccentText
                } catch {}
            }
            elseif ($control -is [Windows.Forms.TextBoxBase] -or
                    $control -is [Windows.Forms.ComboBox] -or
                    $control -is [Windows.Forms.NumericUpDown] -or
                    $control -is [Windows.Forms.DateTimePicker]) {
                try { $control.BackColor = $newPalette.Input; $control.ForeColor = $newPalette.Text } catch {}
            }

            try {
                foreach ($child in @($control.Controls)) { $stack.Push($child) }
            } catch {}
        }
    }

    foreach ($backgroundControl in @(
        $form, $root, $header, $heading, $cards,
        $computerTab, $keyboardTab, $movementTab, $historyTab, $securityTab, $summaryTab,
        $summaryLayout, $movementLayout, $historyLayout, $securityLayout
    )) {
        try { if ($null -ne $backgroundControl) { $backgroundControl.BackColor = $newPalette.Background; $backgroundControl.ForeColor = $newPalette.Text } } catch {}
    }

    try { $footerHost.BackColor = $newPalette.Surface } catch {}
    try { $actionPanel.BackColor = $newPalette.Surface } catch {}
    try { $lastPanel.BackColor = $newPalette.Card } catch {}
    try { $summaryActionPanel.BackColor = $newPalette.Card } catch {}
    try {
        foreach ($card in @($cards.Controls)) {
            if ($card -is [Windows.Forms.Panel]) { $card.BackColor = $newPalette.Card; $card.ForeColor = $newPalette.Text }
        }
    } catch {}

    # Recria as linhas para reaplicar cores de status e destaques com a paleta nova.
    try { Refresh-NFAll } catch {}
    try { Update-NFActions } catch {}
    try { $form.PerformLayout() } catch {}
    try { $form.Invalidate($true); $form.Refresh() } catch {}
}

'''
anchor = '''if ($script:IsInProcessHosted) {
    $script:HostedControlExport = $form
    $script:HostedFormExport = $null
}'''
ui = rep(ui, anchor, live_theme + anchor, 'tema ao vivo NF Entrada')

required_ui = [
    '$script:ModuleVersion = "2.4.2"',
    'Absolute, 92',
    'Absolute, 58',
    'function Set-HostedNFEntradaTheme',
    '$footerHost.Padding = [Windows.Forms.Padding]::new(8, 8, 8, 8)',
    '$actionPanel.Margin = [Windows.Forms.Padding]::new(0)',
    'Refresh-NFAll',
]
for marker in required_ui:
    if marker not in ui:
        raise SystemExit(f'Polimento 2.4.2: marcador final ausente na UI: {marker}')

required_central = [
    '$script:AppVersion = "0.21.18"',
    '$script:NFEntradaVersion = "2.4.2"',
    'Set-HostedNFEntradaTheme $hostTheme',
    '[Drawing.Color]::FromArgb(47, 112, 230)',
]
for marker in required_central:
    if marker not in central:
        raise SystemExit(f'Polimento 2.4.2: marcador final ausente na Central: {marker}')

write(UI, ui)
write(CENTRAL, central)
print('POLIMENTO NF 2.4.2: OK - rodape elevado, subtitulo liberado, tema ao vivo e acento visual alinhado; Central 0.21.18.')
