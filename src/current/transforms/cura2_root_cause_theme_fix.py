from pathlib import Path

R = Path('src/generated')


def load(path):
    return path.read_text(encoding='utf-8-sig')


def save(path, text):
    path.write_text(text, encoding='utf-8')


def replace_once(text, old, new, label):
    n = text.count(old)
    if n != 1:
        raise SystemExit(f'CURA2 ROOT {label}: esperado 1, encontrado {n}')
    return text.replace(old, new, 1)


def replace_function(text, name, new_body):
    marker = f'function {name} {{'
    start = text.find(marker)
    if start < 0:
        raise SystemExit(f'CURA2 ROOT: função {name} não encontrada')
    nxt = text.find('\nfunction ', start + len(marker))
    if nxt < 0:
        raise SystemExit(f'CURA2 ROOT: limite da função {name} não encontrado')
    return text[:start] + new_body.rstrip() + '\n\n' + text[nxt + 1:]


# ---------------------------------------------------------------------------
# CENTRAL
# ---------------------------------------------------------------------------
p = R / 'Central de Trabalho.ps1'
s = load(p)
s = replace_once(s, '$script:AppVersion = "0.21.26"', '$script:AppVersion = "0.21.27"', 'versão Central')
s = replace_once(s, '$script:NFEntradaVersion = "2.6.5"', '$script:NFEntradaVersion = "2.6.6"', 'versão NF na Central')

# No tema claro a lateral continuava escura de propósito. Isso fazia a Central
# parecer não trocar de aparência quando um módulo ocupava o conteúdo principal.
old_sidebar = '''function Get-SidebarColor {
    param([string]$Theme)
    switch ($Theme) {
        "Claro corporativo" { return [Drawing.Color]::FromArgb(22, 37, 59) }
        "Alto contraste" { return [Drawing.Color]::Black }
        "Técnico industrial" { return [Drawing.Color]::FromArgb(18, 23, 25) }
        default { return [Drawing.Color]::FromArgb(9, 24, 41) }
    }
}'''
new_sidebar = '''function Get-SidebarColor {
    param([string]$Theme)
    switch ($Theme) {
        "Claro corporativo" { return [Drawing.Color]::FromArgb(234, 240, 247) }
        "Alto contraste" { return [Drawing.Color]::Black }
        "Técnico industrial" { return [Drawing.Color]::FromArgb(18, 23, 25) }
        default { return [Drawing.Color]::FromArgb(9, 24, 41) }
    }
}'''
s = replace_once(s, old_sidebar, new_sidebar, 'sidebar claro')

# O sincronizador antigo procurava qualquer uma das três funções e ignorava o
# retorno do módulo. Assim, Set-HostedNFEntradaTheme podia retornar $false e a
# Central registrava sucesso. O roteamento passa a ser explícito pelo módulo
# realmente aberto e um retorno booleano falso vira falha real.
new_sync = r'''function Sync-HostedModuleTheme {
    $script:LastThemeSyncError = ""
    if ($null -eq $script:HostedModule -or [string]::IsNullOrWhiteSpace($script:EmbeddedModule)) { return $true }
    if ($null -eq $script:HostedForm -or $script:HostedForm.IsDisposed) { return $true }

    $theme = [string]$themeCombo.SelectedItem
    if ([string]::IsNullOrWhiteSpace($theme)) { $theme = "Escuro profissional" }
    $moduleName = [string]$script:EmbeddedModule

    try {
        $handled = & $script:HostedModule {
            param($targetModule, $hostTheme)

            switch ($targetModule) {
                "Maintenance" {
                    $cmd = Get-Command -Name Set-HostedMaintenanceTheme -CommandType Function -ErrorAction SilentlyContinue
                    if ($null -eq $cmd) { throw "A função de aparência da Manutenção não foi encontrada." }
                    $result = Set-HostedMaintenanceTheme $hostTheme
                    if ($result -is [bool] -and -not $result) { throw "A Manutenção recusou a aparência selecionada." }
                    return $true
                }
                "Generator" {
                    $cmd = Get-Command -Name Set-HostedGeneratorTheme -CommandType Function -ErrorAction SilentlyContinue
                    if ($null -eq $cmd) { throw "A função de aparência do Gerenciador não foi encontrada." }
                    $result = Set-HostedGeneratorTheme $hostTheme
                    if ($result -is [bool] -and -not $result) { throw "O Gerenciador recusou a aparência selecionada." }
                    return $true
                }
                "NFEntrada" {
                    $cmd = Get-Command -Name Set-HostedNFEntradaTheme -CommandType Function -ErrorAction SilentlyContinue
                    if ($null -eq $cmd) { throw "A função de aparência do Controle de NF não foi encontrada." }
                    $result = Set-HostedNFEntradaTheme $hostTheme
                    if ($result -is [bool] -and -not $result) { throw "O Controle de NF não conseguiu aplicar a aparência selecionada." }
                    return $true
                }
                default { throw "Módulo integrado desconhecido: $targetModule" }
            }
        } $moduleName $theme

        if (-not [bool]$handled) {
            $script:LastThemeSyncError = "O módulo não confirmou a aplicação da aparência."
            return $false
        }

        try {
            $script:HostedForm.PerformLayout()
            $script:HostedForm.Invalidate($true)
            $script:HostedForm.Update()
            $script:HostedForm.Refresh()
        } catch {}
        return $true
    }
    catch {
        $script:LastThemeSyncError = $_.Exception.Message
        return $false
    }
}'''
s = replace_function(s, 'Sync-HostedModuleTheme', new_sync)

# Central: todos os painéis estruturais passam a receber cor explícita. Antes
# vários deles dependiam de herança de BackColor; isso deixa restos do tema
# anterior em WinForms e dá a impressão de que a Central não trocou.
old_struct = '''        $form.BackColor = $script:CurrentPalette.Background
        $rootLayout.BackColor = $script:CurrentPalette.Background
        $sidebar.BackColor = $sidebarColor
        $mainPanel.BackColor = $script:CurrentPalette.Background
        $headerPanel.BackColor = $script:CurrentPalette.Background
        $modulesHost.BackColor = $script:CurrentPalette.Background
        $footerPanel.BackColor = $script:CurrentPalette.Footer'''
new_struct = '''        $form.BackColor = $script:CurrentPalette.Background
        $rootLayout.BackColor = $script:CurrentPalette.Background
        $sidebar.BackColor = $sidebarColor
        $brandPanel.BackColor = $sidebarColor
        $navPanel.BackColor = $sidebarColor
        $sidebarBottom.BackColor = $sidebarColor
        $mainPanel.BackColor = $script:CurrentPalette.Background
        $mainLayout.BackColor = $script:CurrentPalette.Background
        $headerPanel.BackColor = $script:CurrentPalette.Background
        $modulesHost.BackColor = $script:CurrentPalette.Background
        $modulesLayout.BackColor = $script:CurrentPalette.Background
        $programsHeader.BackColor = $script:CurrentPalette.Background
        $modulesFlow.BackColor = $script:CurrentPalette.Background
        $footerPanel.BackColor = $script:CurrentPalette.Footer
        $footerLayout.BackColor = $script:CurrentPalette.Footer'''
s = replace_once(s, old_struct, new_struct, 'painéis estruturais Central')

old_sidebar_text = '''        foreach ($label in @($brandTitle, $brandSub, $sidebarSection, $sidebarThemeLabel, $sidebarVersion)) {
            if ($null -ne $label) { $label.ForeColor = [Drawing.Color]::FromArgb(225, 235, 245) }
        }
        $sidebarStatus.ForeColor = $script:CurrentPalette.Success
        $sidebarStatusSub.ForeColor = [Drawing.Color]::FromArgb(161, 179, 197)'''
new_sidebar_text = '''        foreach ($label in @($brandTitle, $sidebarSection, $sidebarThemeLabel, $sidebarVersion)) {
            if ($null -ne $label) { $label.ForeColor = $script:CurrentPalette.Text }
        }
        foreach ($label in @($brandSub, $sidebarStatusSub)) {
            if ($null -ne $label) { $label.ForeColor = $script:CurrentPalette.Muted }
        }
        $sidebarStatus.ForeColor = $script:CurrentPalette.Success'''
s = replace_once(s, old_sidebar_text, new_sidebar_text, 'texto semântico lateral')

# Um único ciclo por mudança de tema. A reaplicação duplicada escondia a origem
# de falhas e tornava o comportamento diferente entre dashboard e módulo aberto.
start = s.find('$themeCombo.Add_SelectedIndexChanged({')
end = s.find('\n$openGeneratorButton.Add_Click', start)
if start < 0 or end < 0:
    raise SystemExit('CURA2 ROOT: evento de aparência da Central não encontrado')
new_event = r'''$themeCombo.Add_SelectedIndexChanged({
    $centralApplied = $false
    try {
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
    if ($centralApplied) {
        try { $synced = [bool](Sync-HostedModuleTheme) }
        catch {
            $synced = $false
            $script:LastThemeSyncError = $_.Exception.Message
        }
    }

    if ($centralApplied -and $synced) {
        Set-StatusMessage ("Aparência aplicada: " + [string]$themeCombo.SelectedItem + ".") "Success"
    }
    elseif ($centralApplied) {
        $detail = if ([string]::IsNullOrWhiteSpace($script:LastThemeSyncError)) { "falha desconhecida" } else { $script:LastThemeSyncError }
        Set-StatusMessage ("A Central mudou, mas o módulo aberto não atualizou: " + $detail) "Warning"
    }
})'''
s = s[:start] + new_event + s[end:]
save(p, s)


# ---------------------------------------------------------------------------
# CONTROLE DE NF
# ---------------------------------------------------------------------------
p = R / 'Modulos/Controle-NF-Entrada/Controle NF Entrada.ps1'
s = load(p)
s = replace_once(s, '$script:ModuleVersion = "2.6.5"', '$script:ModuleVersion = "2.6.6"', 'versão NF')

# A causa concreta encontrada na aplicação anterior: a fila genérica criada por
# nome de tipo é desnecessariamente frágil no Windows PowerShell 5.1. Usa-se a
# Queue não genérica do próprio .NET, compatível com todas as versões suportadas.
s = replace_once(
    s,
    "$queue = New-Object 'System.Collections.Generic.Queue[System.Windows.Forms.Control]'",
    '$queue = New-Object System.Collections.Queue',
    'fila compatível NF'
)

# O setter passa a confirmar que a raiz realmente terminou com a cor do tema.
# Se algo impedir a aplicação, ele retorna falso e a Central agora respeita isso.
old_tail = '''    try {
        $form.PerformLayout()
        $form.Invalidate($true)
        $form.Update()
        $form.Refresh()
    }
    catch {}
    return $true
}'''
new_tail = '''    try {
        $form.PerformLayout()
        $form.Invalidate($true)
        $form.Update()
        $form.Refresh()
    }
    catch { return $false }

    try {
        if ([int]$form.BackColor.ToArgb() -ne [int]$newPalette.Background.ToArgb()) { return $false }
        if ([int]$form.ForeColor.ToArgb() -ne [int]$newPalette.Text.ToArgb()) { return $false }
    }
    catch { return $false }
    return $true
}'''
# Restrito à função de tema: o padrão aparece uma vez no setter atual.
s = replace_once(s, old_tail, new_tail, 'verificação final NF')
save(p, s)


# Contratos desta correção.
central = load(R / 'Central de Trabalho.ps1')
nf = load(R / 'Modulos/Controle-NF-Entrada/Controle NF Entrada.ps1')
checks = [
    (central, '0.21.27', 'Central 0.21.27'),
    (central, 'switch ($targetModule)', 'roteamento explícito de tema'),
    (central, 'A Central mudou, mas o módulo aberto não atualizou', 'erro visível de sincronização'),
    (central, '[Drawing.Color]::FromArgb(234, 240, 247)', 'sidebar clara real'),
    (central, '$modulesFlow.BackColor = $script:CurrentPalette.Background', 'estrutura Central repintada'),
    (nf, '2.6.6', 'NF 2.6.6'),
    (nf, '$queue = New-Object System.Collections.Queue', 'fila PowerShell 5.1 segura'),
    (nf, 'form.BackColor.ToArgb()', 'verificação de aplicação NF'),
]
for text, marker, label in checks:
    if marker not in text:
        raise SystemExit(f'CURA2 ROOT contrato ausente: {label}')

if 'System.Collections.Generic.Queue[System.Windows.Forms.Control]' in nf:
    raise SystemExit('CURA2 ROOT: fila genérica antiga ainda presente')

print('CURA 2 causa raiz Central/NF corrigida: OK')
