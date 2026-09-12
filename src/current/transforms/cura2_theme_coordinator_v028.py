from pathlib import Path

R = Path('src/generated')


def load(path):
    return path.read_text(encoding='utf-8-sig')


def save(path, text):
    path.write_text(text, encoding='utf-8')


def one(text, old, new, label):
    n = text.count(old)
    if n != 1:
        raise SystemExit(f'CURA2 COORD {label}: esperado 1, encontrado {n}')
    return text.replace(old, new, 1)


def replace_function(text, name, new_body):
    marker = f'function {name} {{'
    start = text.find(marker)
    if start < 0:
        raise SystemExit(f'CURA2 COORD: função {name} não encontrada')
    nxt = text.find('\nfunction ', start + len(marker))
    if nxt < 0:
        raise SystemExit(f'CURA2 COORD: limite de {name} não encontrado')
    return text[:start] + new_body.rstrip() + '\n\n' + text[nxt + 1:]


def append_before_function_end(text, name, insertion):
    marker = f'function {name} {{'
    start = text.find(marker)
    if start < 0:
        raise SystemExit(f'CURA2 COORD: função {name} não encontrada para append')
    nxt = text.find('\nfunction ', start + len(marker))
    if nxt < 0:
        raise SystemExit(f'CURA2 COORD: limite de {name} não encontrado para append')
    block = text[start:nxt]
    end = block.rfind('\n}')
    if end < 0:
        raise SystemExit(f'CURA2 COORD: fechamento de {name} não encontrado')
    block = block[:end] + '\n' + insertion.rstrip() + block[end:]
    return text[:start] + block + text[nxt:]


# ---------------------------------------------------------------------------
# CENTRAL — separa definitivamente o tema da Central do tema dos módulos.
# ---------------------------------------------------------------------------
p = R / 'Central de Trabalho.ps1'
s = load(p)
s = one(s, '$script:AppVersion = "0.21.27"', '$script:AppVersion = "0.21.28"', 'versão Central')
s = one(s, '$script:NFEntradaVersion = "2.6.6"', '$script:NFEntradaVersion = "2.6.7"', 'versão NF na Central')

s = one(
    s,
    '$script:LastThemeSyncError = ""',
    '$script:LastThemeSyncError = ""\n$script:CentralThemeCombo = $null\n$script:CentralThemeChanging = $false',
    'estado do coordenador de tema'
)

# A Central e o Gerenciador possuíam uma função com o mesmo nome Apply-AppTheme.
# Mesmo com o módulo dinâmico isolado, callbacks WinForms não devem depender de
# resolução de nomes genéricos. A função da Central passa a ter nome exclusivo.
if 'function Apply-AppTheme {' not in s:
    raise SystemExit('CURA2 COORD: Apply-AppTheme central não encontrada')
s = s.replace('Apply-AppTheme', 'Apply-CentralTheme')

# Guarda uma referência inequívoca ao ComboBox da Central.
s = one(
    s,
    'if ($themeCombo.SelectedIndex -lt 0) { $themeCombo.SelectedIndex = 0 }\n$sidebarBottom.Controls.Add($themeCombo)',
    'if ($themeCombo.SelectedIndex -lt 0) { $themeCombo.SelectedIndex = 0 }\n$script:CentralThemeCombo = $themeCombo\n$sidebarBottom.Controls.Add($themeCombo)',
    'referência do seletor central'
)

# Get-SidebarColor continua responsável somente pela cor. Logo abaixo entra o
# resolvedor único do tema selecionado da Central.
old_sidebar = '''function Get-SidebarColor {
    param([string]$Theme)
    switch ($Theme) {
        "Claro corporativo" { return [Drawing.Color]::FromArgb(234, 240, 247) }
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
}

function Get-CentralSelectedTheme {
    $theme = ""
    try {
        if ($null -ne $script:CentralThemeCombo -and -not $script:CentralThemeCombo.IsDisposed) {
            $theme = [string]$script:CentralThemeCombo.SelectedItem
        }
    } catch {}
    if (-not (@("Escuro profissional", "Técnico industrial", "Claro corporativo", "Alto contraste") -contains $theme)) {
        $theme = "Escuro profissional"
    }
    return $theme
}'''
s = one(s, old_sidebar, new_sidebar, 'resolvedor do tema central')

# Toda leitura do tema da Central usa o resolvedor exclusivo. Não toca nos
# ComboBoxes internos dos módulos.
s = s.replace('[string]$themeCombo.SelectedItem', '(Get-CentralSelectedTheme)')

# Navegação também passa a usar cores semânticas. O hard-code claro antigo era
# justamente o que fazia as letras sumirem numa lateral clara.
new_nav = r'''function Set-NavButtonStyle {
    param(
        [Windows.Forms.Button]$Button,
        [bool]$Active = $false
    )
    if ($null -eq $Button -or $Button.IsDisposed) { return }
    $Button.FlatStyle = [Windows.Forms.FlatStyle]::Flat
    $Button.FlatAppearance.BorderSize = 0
    $Button.TextAlign = [Drawing.ContentAlignment]::MiddleLeft
    $Button.Cursor = [Windows.Forms.Cursors]::Hand
    $Button.Font = [Drawing.Font]::new("Segoe UI Semibold", 9.5)
    if ($Active) {
        $Button.BackColor = $script:CurrentPalette.AccentStrong
        $Button.ForeColor = $script:CurrentPalette.AccentText
    }
    else {
        $Button.BackColor = Get-SidebarColor (Get-CentralSelectedTheme)
        $Button.ForeColor = $script:CurrentPalette.Text
    }
}'''
s = replace_function(s, 'Set-NavButtonStyle', new_nav)

# O aplicador existente mantém os estilos de cartões/botões. No final dele,
# aplicamos novamente o núcleo visível sem catch silencioso e confirmamos RGB.
central_enforcement = r'''    # CURA 2 — núcleo visual obrigatório da Central.
    # Este bloco não usa catch silencioso: se a casca não receber a cor escolhida,
    # o evento saberá que houve falha e não informará sucesso falso.
    $centralTheme = Get-CentralSelectedTheme
    $script:CurrentPalette = Get-ThemePalette $centralTheme
    if ($null -eq $script:CurrentPalette) { throw "A paleta da Central não foi encontrada." }
    $centralSidebarColor = Get-SidebarColor $centralTheme

    $form.BackColor = $script:CurrentPalette.Background
    $rootLayout.BackColor = $script:CurrentPalette.Background
    $sidebar.BackColor = $centralSidebarColor
    $brandPanel.BackColor = $centralSidebarColor
    $navPanel.BackColor = $centralSidebarColor
    $sidebarBottom.BackColor = $centralSidebarColor
    $mainPanel.BackColor = $script:CurrentPalette.Background
    $mainLayout.BackColor = $script:CurrentPalette.Background
    $embeddedHost.BackColor = $script:CurrentPalette.Background
    $embeddedLayout.BackColor = $script:CurrentPalette.Background
    $embeddedToolbar.BackColor = $script:CurrentPalette.Surface
    $embeddedContent.BackColor = $script:CurrentPalette.Background
    $headerPanel.BackColor = $script:CurrentPalette.Background
    $modulesHost.BackColor = $script:CurrentPalette.Background
    $modulesLayout.BackColor = $script:CurrentPalette.Background
    $programsHeader.BackColor = $script:CurrentPalette.Background
    $modulesFlow.BackColor = $script:CurrentPalette.Background
    $footerPanel.BackColor = $script:CurrentPalette.Footer
    $footerLayout.BackColor = $script:CurrentPalette.Footer

    foreach ($label in @($brandTitle,$sidebarSection,$sidebarThemeLabel,$sidebarVersion,$embeddedTitle,$pageTitle,$programsTitle,$todayLabel)) {
        if ($null -ne $label -and -not $label.IsDisposed) { $label.ForeColor = $script:CurrentPalette.Text }
    }
    foreach ($label in @($brandSub,$sidebarStatusSub,$embeddedSubtitle,$embeddedLoading,$pageSubtitle,$programsSubtitle)) {
        if ($null -ne $label -and -not $label.IsDisposed) { $label.ForeColor = $script:CurrentPalette.Muted }
    }
    $themeCombo.BackColor = $script:CurrentPalette.Input
    $themeCombo.ForeColor = $script:CurrentPalette.Text

    Set-ActiveNavigation $script:ActiveNavName
    if ($null -ne $embeddedBackButton) { Set-SecondaryButtonStyle $embeddedBackButton }
    if ($null -ne $embeddedFolderButton) { Set-SecondaryButtonStyle $embeddedFolderButton }

    # Validação real. O screenshot do usuário mostrou módulo correto + Central
    # antiga; esta checagem impede essa combinação de ser aceita como sucesso.
    if ([int]$sidebar.BackColor.ToArgb() -ne [int]$centralSidebarColor.ToArgb()) {
        throw "A barra lateral não recebeu a aparência $centralTheme."
    }
    if ([int]$embeddedToolbar.BackColor.ToArgb() -ne [int]$script:CurrentPalette.Surface.ToArgb()) {
        throw "A barra superior integrada não recebeu a aparência $centralTheme."
    }
    if ([int]$form.BackColor.ToArgb() -ne [int]$script:CurrentPalette.Background.ToArgb()) {
        throw "A janela principal não recebeu a aparência $centralTheme."
    }

    foreach ($control in @($sidebar,$brandPanel,$navPanel,$sidebarBottom,$embeddedToolbar,$embeddedHost,$mainPanel,$form)) {
        if ($null -ne $control -and -not $control.IsDisposed) {
            $control.Invalidate($true)
            $control.Update()
            $control.Refresh()
        }
    }
    [Windows.Forms.Application]::DoEvents()'''
s = append_before_function_end(s, 'Apply-CentralTheme', central_enforcement)

# Evento antigo era SelectedIndexChanged e dependia de resolução genérica. Agora
# reage somente a uma escolha efetiva do usuário, possui trava de reentrada e
# reafirma a casca depois que o módulo terminou seu repaint.
start = s.find('$themeCombo.Add_SelectedIndexChanged({')
end = s.find('\n$openGeneratorButton.Add_Click', start)
if start < 0 or end < 0:
    raise SystemExit('CURA2 COORD: evento antigo da aparência não encontrado')
new_event = r'''$themeCombo.Add_SelectionChangeCommitted({
    if ($script:CentralThemeChanging) { return }
    $script:CentralThemeChanging = $true
    $theme = Get-CentralSelectedTheme
    try {
        Apply-CentralTheme
        Save-AppSettings

        $synced = [bool](Sync-HostedModuleTheme)
        if (-not $synced) {
            $detail = if ([string]::IsNullOrWhiteSpace($script:LastThemeSyncError)) { "falha desconhecida" } else { $script:LastThemeSyncError }
            throw ("O módulo aberto não atualizou: " + $detail)
        }

        # O módulo pode provocar invalidates no mesmo ciclo de mensagens. A casca
        # da Central é reafirmada depois dele e mais uma vez no próximo ciclo UI.
        Apply-CentralTheme
        Set-StatusMessage ("Aparência aplicada: " + $theme + ".") "Success"

        $themeForDeferred = $theme
        $deferredApply = [Action]{
            try {
                if ((Get-CentralSelectedTheme) -eq $themeForDeferred) {
                    Apply-CentralTheme
                }
            } catch {}
        }.GetNewClosure()
        [void]$form.BeginInvoke($deferredApply)
    }
    catch {
        Set-StatusMessage ("Falha na aparência: " + $_.Exception.Message) "Error"
        try {
            $diagPath = [IO.Path]::Combine($script:SettingsDirectory, "tema-diagnostico.log")
            if (-not [IO.Directory]::Exists($script:SettingsDirectory)) { [void][IO.Directory]::CreateDirectory($script:SettingsDirectory) }
            $line = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss") + " | " + $theme + " | " + $_.Exception.Message
            [IO.File]::AppendAllText($diagPath, $line + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
        } catch {}
    }
    finally {
        $script:CentralThemeChanging = $false
    }
})'''
s = s[:start] + new_event + s[end:]

# Startup e Shown já foram renomeados para Apply-CentralTheme pelo replace global.
save(p, s)


# ---------------------------------------------------------------------------
# CONTROLE DE NF — confirmação mais forte da aparência aplicada.
# ---------------------------------------------------------------------------
p = R / 'Modulos/Controle-NF-Entrada/Controle NF Entrada.ps1'
nf = load(p)
nf = one(nf, '$script:ModuleVersion = "2.6.6"', '$script:ModuleVersion = "2.6.7"', 'versão NF')

nf_enforcement = r'''    # CURA 2 — reforço explícito dos elementos mais visíveis do NF.
    $form.BackColor = $newPalette.Background
    $form.ForeColor = $newPalette.Text
    $root.BackColor = $newPalette.Background
    $header.BackColor = $newPalette.Background
    $heading.BackColor = $newPalette.Background
    $cards.BackColor = $newPalette.Background
    $mainTabs.ForeColor = $newPalette.Text

    foreach ($tab in @($computerTab,$keyboardTab,$movementTab,$historyTab,$securityTab,$summaryTab)) {
        if ($null -ne $tab -and -not $tab.IsDisposed) {
            $tab.BackColor = $newPalette.Background
            $tab.ForeColor = $newPalette.Text
        }
    }

    foreach ($grid in @($computerGrid,$keyboardGrid,$movementGrid,$historyGrid,$backupGrid,$productSummaryGrid,$codeSummaryGrid)) {
        if ($null -eq $grid -or $grid.IsDisposed) { continue }
        $grid.BackgroundColor = $newPalette.Surface
        $grid.GridColor = $newPalette.Border
        $grid.EnableHeadersVisualStyles = $false
        $grid.ColumnHeadersDefaultCellStyle.BackColor = $newPalette.Card
        $grid.ColumnHeadersDefaultCellStyle.ForeColor = $newPalette.Text
        $grid.DefaultCellStyle.BackColor = $newPalette.Surface
        $grid.DefaultCellStyle.ForeColor = $newPalette.Text
        $grid.DefaultCellStyle.SelectionBackColor = $newPalette.AccentStrong
        $grid.DefaultCellStyle.SelectionForeColor = $newPalette.AccentText
        $grid.Invalidate()
    }

    try { $title.ForeColor = $newPalette.Text } catch {}
    try { $subtitle.ForeColor = $newPalette.Muted } catch {}
    try { Set-NFButtonStyle $importButton "Secondary" } catch {}
    try { Set-NFButtonStyle $exportButton "Primary" } catch {}
    try { Set-NFButtonStyle $newButton "Primary" } catch {}
    try { Set-NFButtonStyle $editButton "Secondary" } catch {}
    try { Set-NFButtonStyle $outputButton "Secondary" } catch {}
    try { Set-NFButtonStyle $clearFiltersButton "Secondary" } catch {}
    try { Set-NFButtonStyle $exportListButton "Secondary" } catch {}
    try { Set-NFButtonStyle $deleteButton "Danger" } catch {}
    try { Set-NFButtonStyle $movementReverseButton "Danger" } catch {}

    # Não basta a raiz mudar: confirma também aba, grade e ação principal.
    if ([int]$computerTab.BackColor.ToArgb() -ne [int]$newPalette.Background.ToArgb()) {
        throw "A aba principal do Controle de NF não recebeu o tema $Theme."
    }
    if ([int]$computerGrid.DefaultCellStyle.BackColor.ToArgb() -ne [int]$newPalette.Surface.ToArgb()) {
        throw "A grade do Controle de NF não recebeu o tema $Theme."
    }
    if ([int]$newButton.BackColor.ToArgb() -ne [int]$newPalette.AccentStrong.ToArgb()) {
        throw "Os botões do Controle de NF não receberam o tema $Theme."
    }'''

# Insere antes do bloco final PerformLayout/validação já existente.
needle = '''    try {
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
replacement = nf_enforcement.rstrip() + '''

    try {
        $form.PerformLayout()
        $form.Invalidate($true)
        $form.Update()
        $form.Refresh()
        [Windows.Forms.Application]::DoEvents()
    }
    catch { throw "Falha ao redesenhar o Controle de NF: $($_.Exception.Message)" }

    if ([int]$form.BackColor.ToArgb() -ne [int]$newPalette.Background.ToArgb()) {
        throw "A raiz do Controle de NF não recebeu o tema $Theme."
    }
    if ([int]$form.ForeColor.ToArgb() -ne [int]$newPalette.Text.ToArgb()) {
        throw "O texto raiz do Controle de NF não recebeu o tema $Theme."
    }
    return $true
}'''
nf = one(nf, needle, replacement, 'verificação visual NF')
save(p, nf)


# Contratos do coordenador.
central = load(R / 'Central de Trabalho.ps1')
nf = load(R / 'Modulos/Controle-NF-Entrada/Controle NF Entrada.ps1')
checks = [
    (central, '$script:AppVersion = "0.21.28"', 'versão Central'),
    (central, 'function Apply-CentralTheme {', 'nome exclusivo Central'),
    (central, 'function Get-CentralSelectedTheme {', 'seletor exclusivo Central'),
    (central, '$themeCombo.Add_SelectionChangeCommitted({', 'evento comprometido pelo usuário'),
    (central, 'tema-diagnostico.log', 'diagnóstico de falha'),
    (central, 'A barra lateral não recebeu a aparência', 'verificação shell'),
    (central, '$Button.ForeColor = $script:CurrentPalette.Text', 'navegação sem cor fixa'),
    (nf, '$script:ModuleVersion = "2.6.7"', 'versão NF'),
    (nf, 'A grade do Controle de NF não recebeu o tema', 'verificação NF'),
    (nf, '[Windows.Forms.Application]::DoEvents()', 'repaint NF'),
]
for text, marker, label in checks:
    if marker not in text:
        raise SystemExit(f'CURA2 COORD contrato ausente: {label}')

if 'function Apply-AppTheme {' in central:
    raise SystemExit('CURA2 COORD: nome genérico Apply-AppTheme ainda existe na Central')

print('CURA 2 coordenador exclusivo de aparência aplicado: OK')
