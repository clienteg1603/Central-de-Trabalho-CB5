from pathlib import Path

R = Path('src/generated')


def load(path):
    return path.read_text(encoding='utf-8-sig')


def save(path, text):
    path.write_text(text, encoding='utf-8')


def one(text, old, new, label):
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'CURA2 {label}: esperado 1, encontrado {count}')
    return text.replace(old, new, 1)


def replace_function(text, name, replacement):
    marker = f'function {name} {{'
    start = text.find(marker)
    if start < 0:
        raise SystemExit(f'CURA2 função ausente: {name}')
    next_start = text.find('\nfunction ', start + len(marker))
    if next_start < 0:
        raise SystemExit(f'CURA2 não encontrou função seguinte a {name}')
    return text[:start] + replacement.rstrip() + '\n\n' + text[next_start + 1:]


# ---------------------------------------------------------------------------
# CENTRAL — a Central passa a ser a autoridade da aparência enquanto um
# módulo estiver hospedado. Falhas de sincronização deixam de ser silenciosas.
# ---------------------------------------------------------------------------
p = R / 'Central de Trabalho.ps1'
s = load(p)
s = one(s, '$script:AppVersion = "0.21.23"', '$script:AppVersion = "0.21.24"', 'versão Central')
s = one(s, '$script:GeneratorVersion = "3.7.5"', '$script:GeneratorVersion = "3.7.6"', 'versão Gerenciador')
s = one(s, '$script:MaintenanceVersion = "0.6.4"', '$script:MaintenanceVersion = "0.6.5"', 'versão Manutenção')
s = one(s, '$script:NFEntradaVersion = "2.6.3"', '$script:NFEntradaVersion = "2.6.4"', 'versão NF')
s = one(
    s,
    '$script:LastAvailabilitySignature = ""',
    '$script:LastAvailabilitySignature = ""\n$script:LastThemeSyncError = ""',
    'estado de sincronização visual'
)

sync_fn = r'''function Sync-HostedModuleTheme {
    $script:LastThemeSyncError = ""
    if ($null -eq $script:HostedModule -or [string]::IsNullOrWhiteSpace($script:EmbeddedModule)) { return $true }
    if ($null -eq $script:HostedForm) { return $true }

    try {
        if ($script:HostedForm.IsDisposed -or $script:HostedForm.Disposing -or $null -eq $script:HostedForm.Parent) { return $true }
    }
    catch {
        $script:LastThemeSyncError = $_.Exception.Message
        return $false
    }

    $theme = [string]$themeCombo.SelectedItem
    if ([string]::IsNullOrWhiteSpace($theme)) { $theme = "Escuro profissional" }

    try {
        $handled = & $script:HostedModule {
            param($hostTheme)

            $maintenanceCmd = Get-Command -Name Set-HostedMaintenanceTheme -ErrorAction SilentlyContinue
            if ($null -ne $maintenanceCmd) {
                [void](Set-HostedMaintenanceTheme $hostTheme)
                return $true
            }

            $generatorCmd = Get-Command -Name Set-HostedGeneratorTheme -ErrorAction SilentlyContinue
            if ($null -ne $generatorCmd) {
                [void](Set-HostedGeneratorTheme $hostTheme)
                return $true
            }

            $nfEntradaCmd = Get-Command -Name Set-HostedNFEntradaTheme -ErrorAction SilentlyContinue
            if ($null -ne $nfEntradaCmd) {
                [void](Set-HostedNFEntradaTheme $hostTheme)
                return $true
            }

            return $false
        } $theme

        if (-not [bool]$handled) {
            throw "O módulo aberto não expôs um aplicador de aparência compatível."
        }

        # CURA 2: depois que o módulo reaplica sua aparência, a Central força um
        # ciclo completo de layout e pintura no controle já hospedado. Não é
        # necessário fechar e abrir novamente para a mudança aparecer.
        $script:HostedForm.SuspendLayout()
        try {
            $script:HostedForm.PerformLayout()
            $script:HostedForm.Invalidate($true)
        }
        finally {
            $script:HostedForm.ResumeLayout($true)
        }
        $script:HostedForm.Update()
        return $true
    }
    catch {
        $script:LastThemeSyncError = $_.Exception.Message
        return $false
    }
}'''
s = replace_function(s, 'Sync-HostedModuleTheme', sync_fn)

old_event = '''$themeCombo.Add_SelectedIndexChanged({
    try { Apply-AppTheme } catch {}
    try { Save-AppSettings } catch {}
    try { Sync-HostedModuleTheme } catch {}
    try { Set-StatusMessage ("Aparência aplicada: " + [string]$themeCombo.SelectedItem + ".") "Success" } catch {}
})'''
new_event = '''$themeCombo.Add_SelectedIndexChanged({
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
s = one(s, old_event, new_event, 'evento de aparência da Central')
save(p, s)


# ---------------------------------------------------------------------------
# MANUTENÇÃO — mantém compatibilidade dos nomes internos em modo standalone,
# mas, hospedada, obedece sempre ao tema canônico enviado pela Central.
# ---------------------------------------------------------------------------
p = R / 'Modulos/Central-de-Manutencao-CB5/Central Manutencao CB5.ps1'
s = load(p)
s = one(s, '$script:AppVersion = "0.6.4"', '$script:AppVersion = "0.6.5"', 'versão Manutenção módulo')
s = one(
    s,
    '$script:HostedShell = $null',
    '$script:HostedShell = $null\n$script:HostedCentralTheme = ""',
    'estado tema Manutenção'
)

maintenance_setter = r'''function Set-HostedMaintenanceTheme {
    param([string]$CentralTheme)
    if (-not $script:IsInProcessHosted) { return $false }
    if ([string]::IsNullOrWhiteSpace($CentralTheme)) { $CentralTheme = "Escuro profissional" }

    $mapped = Get-MaintenanceThemeFromHost $CentralTheme
    if (-not $themeCombo.Items.Contains($mapped)) { $mapped = "Escuro grafite" }

    $script:HostedCentralTheme = $CentralTheme
    if ([string]$themeCombo.SelectedItem -ne $mapped) {
        $themeCombo.SelectedItem = $mapped
    }

    Apply-MaintenanceTheme
    Update-MaintenanceResponsiveLayout
    $form.PerformLayout()
    $form.Invalidate($true)
    $form.Update()
    return $true
}'''
s = replace_function(s, 'Set-HostedMaintenanceTheme', maintenance_setter)
save(p, s)


# ---------------------------------------------------------------------------
# GERENCIADOR — mesma autoridade central e repaint determinístico.
# ---------------------------------------------------------------------------
p = R / 'Modulos/Gerador-de-Planilhas-CB5-TV5/Gerador Planilhas.ps1'
s = load(p)
s = one(s, '$script:AppVersion = "3.7.5"', '$script:AppVersion = "3.7.6"', 'versão Gerenciador módulo')
s = one(
    s,
    '$script:GeneratorHostedShell = $null',
    '$script:GeneratorHostedShell = $null\n$script:HostedCentralTheme = ""',
    'estado tema Gerenciador'
)

generator_setter = r'''function Set-HostedGeneratorTheme {
    param([string]$CentralTheme)
    if (-not $script:IsInProcessHosted) { return $false }
    if ([string]::IsNullOrWhiteSpace($CentralTheme)) { $CentralTheme = "Escuro profissional" }

    $mapped = Get-GeneratorThemeFromHost $CentralTheme
    if (-not $themeCombo.Items.Contains($mapped)) { $mapped = "Escuro grafite" }

    $script:HostedCentralTheme = $CentralTheme
    if ([string]$themeCombo.SelectedItem -ne $mapped) {
        $themeCombo.SelectedItem = $mapped
    }

    Apply-AppTheme
    Update-GeneratorResponsiveLayout
    Update-RootLayout
    $form.PerformLayout()
    $form.Invalidate($true)
    $form.Update()
    return $true
}'''
s = replace_function(s, 'Set-HostedGeneratorTheme', generator_setter)
save(p, s)


# ---------------------------------------------------------------------------
# NF ENTRADA — deixa de depender apenas da comparação da cor anterior.
# A primeira camada mantém os papéis visuais já existentes; a segunda camada
# normaliza controles de entrada, labels e grids que eventualmente tenham uma
# cor fora da paleta anterior. Isso evita texto escuro em fundo escuro e vice-
# versa depois de várias trocas de aparência ao vivo.
# ---------------------------------------------------------------------------
p = R / 'Modulos/Controle-NF-Entrada/Controle NF Entrada.ps1'
s = load(p)
s = one(s, '$script:ModuleVersion = "2.6.3"', '$script:ModuleVersion = "2.6.4"', 'versão NF módulo')

nf_setter = r'''function Set-HostedNFEntradaTheme {
    param([string]$Theme)
    if ([string]::IsNullOrWhiteSpace($Theme)) { $Theme = "Escuro profissional" }

    $oldPalette = $script:CurrentPalette
    $newPalette = Get-NFEntradaPalette $Theme
    if ($null -eq $newPalette) { return $false }

    $mapColor = {
        param([Drawing.Color]$Color)
        if ($null -eq $oldPalette -or $null -eq $Color) { return $Color }
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
            }
            catch {}
        }
        return $Color
    }

    $applyControl = $null
    $applyControl = {
        param([Windows.Forms.Control]$Control)
        if ($null -eq $Control -or $Control.IsDisposed) { return }

        try {
            $originalBack = $Control.BackColor
            $originalFore = $Control.ForeColor
            $mappedBack = & $mapColor $originalBack
            $mappedFore = & $mapColor $originalFore
            if ($null -ne $mappedBack) { $Control.BackColor = $mappedBack }
            if ($null -ne $mappedFore) { $Control.ForeColor = $mappedFore }

            # Controles de entrada e texto precisam ser sempre legíveis. Se uma
            # cor não pertencia à paleta antiga, não a carregamos cegamente para
            # o próximo tema.
            if ($Control -is [Windows.Forms.TextBox] -or
                $Control -is [Windows.Forms.ComboBox] -or
                $Control -is [Windows.Forms.NumericUpDown] -or
                $Control -is [Windows.Forms.DateTimePicker]) {
                $Control.BackColor = $newPalette.Input
                $Control.ForeColor = $newPalette.Text
            }
            elseif ($Control -is [Windows.Forms.Label]) {
                if ($mappedFore.ToArgb() -eq $originalFore.ToArgb()) {
                    $Control.ForeColor = $newPalette.Text
                }
            }
            elseif ($Control -is [Windows.Forms.Button]) {
                $Control.UseVisualStyleBackColor = $false
                if (-not $Control.Enabled -and $mappedFore.ToArgb() -eq $originalFore.ToArgb()) {
                    $Control.ForeColor = $newPalette.Muted
                }
            }

            if ($Control -is [Windows.Forms.DataGridView]) {
                $Control.BackgroundColor = $newPalette.Surface
                $Control.GridColor = $newPalette.Border
                $Control.EnableHeadersVisualStyles = $false
                $Control.ColumnHeadersDefaultCellStyle.BackColor = $newPalette.Card
                $Control.ColumnHeadersDefaultCellStyle.ForeColor = $newPalette.Text
                $Control.DefaultCellStyle.BackColor = $newPalette.Surface
                $Control.DefaultCellStyle.ForeColor = $newPalette.Text
                $Control.DefaultCellStyle.SelectionBackColor = $newPalette.AccentStrong
                $Control.DefaultCellStyle.SelectionForeColor = $newPalette.AccentText
                $Control.AlternatingRowsDefaultCellStyle.BackColor = $newPalette.Surface
                $Control.AlternatingRowsDefaultCellStyle.ForeColor = $newPalette.Text
            }
        }
        catch {}

        foreach ($child in @($Control.Controls)) {
            & $applyControl $child
        }
    }

    $script:CurrentPalette = $newPalette
    & $applyControl $form
    $form.PerformLayout()
    $form.Invalidate($true)
    $form.Update()
    return $true
}'''
s = replace_function(s, 'Set-HostedNFEntradaTheme', nf_setter)
save(p, s)


# ---------------------------------------------------------------------------
# Contratos desta cura: falha o build se o sincronismo voltar a ser silencioso
# ou se o NF voltar ao aplicador antigo sem normalização dos controles.
# ---------------------------------------------------------------------------
central = load(R / 'Central de Trabalho.ps1')
maintenance = load(R / 'Modulos/Central-de-Manutencao-CB5/Central Manutencao CB5.ps1')
generator = load(R / 'Modulos/Gerador-de-Planilhas-CB5-TV5/Gerador Planilhas.ps1')
nf = load(R / 'Modulos/Controle-NF-Entrada/Controle NF Entrada.ps1')

checks = [
    (central, '0.21.24', 'versão Central final'),
    (central, '$script:LastThemeSyncError', 'diagnóstico de sync'),
    (central, 'O módulo aberto não expôs um aplicador de aparência compatível.', 'contrato do módulo'),
    (central, '$script:HostedForm.Invalidate($true)', 'repaint hospedado'),
    (maintenance, '0.6.5', 'versão Manutenção final'),
    (maintenance, '$script:HostedCentralTheme = $CentralTheme', 'autoridade Central Manutenção'),
    (generator, '3.7.6', 'versão Gerenciador final'),
    (generator, '$script:HostedCentralTheme = $CentralTheme', 'autoridade Central Gerenciador'),
    (nf, '2.6.4', 'versão NF final'),
    (nf, 'Controles de entrada e texto precisam ser sempre legíveis.', 'normalização NF'),
    (nf, '$Control.DefaultCellStyle.SelectionBackColor = $newPalette.AccentStrong', 'grid NF'),
]
for text, mark, label in checks:
    if mark not in text:
        raise SystemExit(f'CURA2 contrato ausente: {label} :: {mark}')

print('CURA 2 OK: Central autoritativa, sincronização visível e repaint determinístico; Central 0.21.24 / Manutenção 0.6.5 / Gerenciador 3.7.6 / NF 2.6.4')
