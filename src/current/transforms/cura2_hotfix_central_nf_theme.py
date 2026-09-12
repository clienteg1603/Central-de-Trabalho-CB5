from pathlib import Path

R = Path('src/generated')


def load(path):
    return path.read_text(encoding='utf-8-sig')


def save(path, text):
    path.write_text(text, encoding='utf-8')


def one(text, old, new, label):
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'HOTFIX CURA2 {label}: esperado 1, encontrado {count}')
    return text.replace(old, new, 1)


# ---------------------------------------------------------------------------
# CENTRAL — a própria Central precisa repintar antes de sincronizar o módulo.
# Um erro no módulo aberto nunca mais pode impedir a aparência da Central.
# ---------------------------------------------------------------------------
p = R / 'Central de Trabalho.ps1'
s = load(p)
s = one(s, '$script:AppVersion = "0.21.25"', '$script:AppVersion = "0.21.26"', 'versão Central')
s = one(s, '$script:NFEntradaVersion = "2.6.4"', '$script:NFEntradaVersion = "2.6.5"', 'versão NF na Central')

old_event = '''$themeCombo.Add_SelectedIndexChanged({
    try {
        Apply-AppTheme
        Save-AppSettings
        $synced = Sync-HostedModuleTheme
        $form.PerformLayout()
        $form.Invalidate($true)
        $form.Update()

        if ($synced) {
            Set-StatusMessage ("Aparência aplicada: " + [string]$themeCombo.SelectedItem + ".") "Success"
        }
        else {
            $detail = if ([string]::IsNullOrWhiteSpace($script:LastThemeSyncError)) { "falha desconhecida" } else { $script:LastThemeSyncError }
            Set-StatusMessage ("Aparência aplicada na Central, mas o módulo aberto não atualizou: " + $detail) "Warning"
        }
    }
    catch {
        Set-StatusMessage ("Não foi possível aplicar a aparência: " + $_.Exception.Message) "Error"
    }
})'''

new_event = '''$themeCombo.Add_SelectedIndexChanged({
    $centralApplied = $false
    try {
        # A Central muda primeiro e repinta imediatamente. A sincronização de um
        # módulo nunca pode bloquear ou desfazer a aparência da janela principal.
        Apply-AppTheme
        $form.PerformLayout()
        $form.Invalidate($true)
        $form.Update()
        $form.Refresh()
        $centralApplied = $true
    }
    catch {
        Set-StatusMessage ("Não foi possível aplicar a aparência da Central: " + $_.Exception.Message) "Error"
    }

    try { Save-AppSettings } catch {}

    $synced = $true
    try { $synced = [bool](Sync-HostedModuleTheme) }
    catch {
        $synced = $false
        $script:LastThemeSyncError = $_.Exception.Message
    }

    # Reafirma a aparência da Central depois da sincronização. Alguns módulos
    # possuem eventos internos de ComboBox e não podem influenciar o repaint da
    # janela hospedeira.
    if ($centralApplied) {
        try {
            Apply-AppTheme
            $form.PerformLayout()
            $form.Invalidate($true)
            $form.Update()
            $form.Refresh()
        } catch {}
    }

    if ($centralApplied -and $synced) {
        Set-StatusMessage ("Aparência aplicada: " + [string]$themeCombo.SelectedItem + ".") "Success"
    }
    elseif ($centralApplied) {
        $detail = if ([string]::IsNullOrWhiteSpace($script:LastThemeSyncError)) { "falha desconhecida" } else { $script:LastThemeSyncError }
        Set-StatusMessage ("A Central mudou de aparência, mas o módulo aberto não atualizou: " + $detail) "Warning"
    }
})'''
s = one(s, old_event, new_event, 'evento de aparência da Central')
save(p, s)


# ---------------------------------------------------------------------------
# NF ENTRADA — aplicação determinística por fila de controles.
# A versão anterior dependia de uma scriptblock recursiva e de correspondência
# de cores. Agora a árvore visual inteira é percorrida de forma explícita e
# repintada, sem tocar em dados, filtros, grids ou regras de negócio.
# ---------------------------------------------------------------------------
p = R / 'Modulos/Controle-NF-Entrada/Controle NF Entrada.ps1'
s = load(p)
s = one(s, '$script:ModuleVersion = "2.6.4"', '$script:ModuleVersion = "2.6.5"', 'versão NF módulo')

start_marker = 'function Set-HostedNFEntradaTheme {'
end_marker = '\nfunction Invoke-NFThemeBoundaryMarker'
start = s.find(start_marker)
end = s.find(end_marker, start)
if start < 0 or end < 0:
    raise SystemExit('HOTFIX CURA2: limites de Set-HostedNFEntradaTheme não encontrados')

nf_setter = r'''function Set-HostedNFEntradaTheme {
    param([string]$Theme)
    if ([string]::IsNullOrWhiteSpace($Theme)) { $Theme = "Escuro profissional" }

    $oldPalette = $script:CurrentPalette
    $newPalette = Get-NFEntradaPalette $Theme
    if ($null -eq $newPalette -or $null -eq $form -or $form.IsDisposed) { return $false }

    # Monta um mapa das cores da paleta anterior. Ele preserva os papéis visuais
    # (fundo, card, texto, aviso, perigo etc.) sem depender de recursão por
    # scriptblock. Controles que não pertenciam à paleta recebem um fallback
    # semântico de acordo com o tipo.
    $colorMap = @{}
    if ($null -ne $oldPalette) {
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
            try { $colorMap[[int]$pair[0].ToArgb()] = $pair[1] } catch {}
        }
    }

    $script:CurrentPalette = $newPalette
    $queue = New-Object 'System.Collections.Generic.Queue[System.Windows.Forms.Control]'
    $queue.Enqueue($form)

    while ($queue.Count -gt 0) {
        $control = $queue.Dequeue()
        if ($null -eq $control -or $control.IsDisposed) { continue }

        foreach ($child in @($control.Controls)) {
            if ($null -ne $child -and -not $child.IsDisposed) { $queue.Enqueue($child) }
        }

        try {
            $oldBackArgb = [int]$control.BackColor.ToArgb()
            $oldForeArgb = [int]$control.ForeColor.ToArgb()
            $mappedBack = if ($colorMap.ContainsKey($oldBackArgb)) { $colorMap[$oldBackArgb] } else { $null }
            $mappedFore = if ($colorMap.ContainsKey($oldForeArgb)) { $colorMap[$oldForeArgb] } else { $null }

            if ($null -ne $mappedBack) { $control.BackColor = $mappedBack }
            if ($null -ne $mappedFore) { $control.ForeColor = $mappedFore }

            if ($control -is [Windows.Forms.DataGridView]) {
                $control.BackgroundColor = $newPalette.Surface
                $control.GridColor = $newPalette.Border
                $control.EnableHeadersVisualStyles = $false
                $control.ColumnHeadersDefaultCellStyle.BackColor = $newPalette.Card
                $control.ColumnHeadersDefaultCellStyle.ForeColor = $newPalette.Text
                $control.DefaultCellStyle.BackColor = $newPalette.Surface
                $control.DefaultCellStyle.ForeColor = $newPalette.Text
                $control.DefaultCellStyle.SelectionBackColor = $newPalette.AccentStrong
                $control.DefaultCellStyle.SelectionForeColor = $newPalette.AccentText
                $control.AlternatingRowsDefaultCellStyle.BackColor = $newPalette.Surface
                $control.AlternatingRowsDefaultCellStyle.ForeColor = $newPalette.Text
            }
            elseif ($control -is [Windows.Forms.TextBox] -or
                    $control -is [Windows.Forms.ComboBox] -or
                    $control -is [Windows.Forms.NumericUpDown] -or
                    $control -is [Windows.Forms.DateTimePicker]) {
                $control.BackColor = $newPalette.Input
                $control.ForeColor = $newPalette.Text
            }
            elseif ($control -is [Windows.Forms.Button]) {
                $text = ([string]$control.Text).Trim().ToUpperInvariant()
                $wasDanger = $false
                $wasPrimary = $false
                if ($null -ne $oldPalette) {
                    try { $wasDanger = ($oldBackArgb -eq [int]$oldPalette.DangerBack.ToArgb()) } catch {}
                    try { $wasPrimary = ($oldBackArgb -eq [int]$oldPalette.AccentStrong.ToArgb() -or $oldBackArgb -eq [int]$oldPalette.Accent.ToArgb()) } catch {}
                }
                if ($text -match 'EXCLUIR|ESTORNAR') { $wasDanger = $true }
                if ($text -match 'NOVA NF|EXCEL OFICIAL|REGISTRAR SAÍDA') { $wasPrimary = $true }

                if ($wasDanger) { Set-NFButtonStyle $control "Danger" }
                elseif ($wasPrimary) { Set-NFButtonStyle $control "Primary" }
                else { Set-NFButtonStyle $control "Secondary" }
            }
            elseif ($control -is [Windows.Forms.GroupBox]) {
                $control.ForeColor = $newPalette.Text
                if ($null -eq $mappedBack) { $control.BackColor = $newPalette.Background }
            }
            elseif ($control -is [Windows.Forms.TabPage]) {
                $control.BackColor = $newPalette.Background
                $control.ForeColor = $newPalette.Text
            }
            elseif ($control -is [Windows.Forms.Label]) {
                if ($null -eq $mappedFore) { $control.ForeColor = $newPalette.Text }
            }
            elseif (($control -is [Windows.Forms.Panel]) -or
                    ($control -is [Windows.Forms.TableLayoutPanel]) -or
                    ($control -is [Windows.Forms.FlowLayoutPanel])) {
                if ($null -eq $mappedBack) { $control.BackColor = $newPalette.Background }
            }
        }
        catch {
            # Um controle visual isolado não deve impedir o restante da árvore de
            # receber a aparência selecionada.
        }
    }

    # Elementos estruturais e textos principais recebem cores explícitas.
    try { $form.BackColor = $newPalette.Background; $form.ForeColor = $newPalette.Text } catch {}
    foreach ($panel in @($root,$header,$heading,$cards)) {
        try { if ($null -ne $panel) { $panel.BackColor = $newPalette.Background } } catch {}
    }
    foreach ($tab in @($computerTab,$keyboardTab,$movementTab,$historyTab,$securityTab,$summaryTab)) {
        try { if ($null -ne $tab) { $tab.BackColor = $newPalette.Background; $tab.ForeColor = $newPalette.Text } } catch {}
    }
    try { $title.ForeColor = $newPalette.Text } catch {}
    try { $subtitle.ForeColor = $newPalette.Muted } catch {}
    try { $footerStatus.ForeColor = $newPalette.Muted } catch {}

    # Reaplica os papéis dos botões principais, independente da cor que tinham
    # antes da troca.
    try { Set-NFButtonStyle $importButton "Secondary" } catch {}
    try { Set-NFButtonStyle $exportButton "Primary" } catch {}
    try { Set-NFButtonStyle $newButton "Primary" } catch {}
    try { Set-NFButtonStyle $editButton "Secondary" } catch {}
    try { Set-NFButtonStyle $outputButton "Secondary" } catch {}
    try { Set-NFButtonStyle $clearFiltersButton "Secondary" } catch {}
    try { Set-NFButtonStyle $exportListButton "Secondary" } catch {}
    try { Set-NFButtonStyle $deleteButton "Danger" } catch {}
    try { Set-NFButtonStyle $movementReverseButton "Danger" } catch {}

    try {
        $form.PerformLayout()
        $form.Invalidate($true)
        $form.Update()
        $form.Refresh()
    }
    catch {}
    return $true
}'''

s = s[:start] + nf_setter.rstrip() + '\n' + s[end:]
save(p, s)


# Build-time contracts for this hotfix.
central = load(R / 'Central de Trabalho.ps1')
nf = load(R / 'Modulos/Controle-NF-Entrada/Controle NF Entrada.ps1')
checks = [
    (central, '0.21.26', 'versão Central final'),
    (central, '$form.Refresh()', 'repaint imediato da Central'),
    (central, 'A Central muda primeiro e repinta imediatamente.', 'isolamento Central/módulo'),
    (nf, '2.6.5', 'versão NF final'),
    (nf, 'Queue[System.Windows.Forms.Control]', 'fila de controles NF'),
    (nf, 'Reaplica os papéis dos botões principais', 'papéis visuais NF'),
    (nf, '$form.Refresh()', 'repaint NF'),
]
for text, marker, label in checks:
    if marker not in text:
        raise SystemExit(f'HOTFIX CURA2 contrato ausente: {label}')

print('HOTFIX CURA 2 Central/NF aplicado: OK')
