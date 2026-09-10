from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CENTRAL = ROOT / "generated" / "Central de Trabalho.ps1"
MAINT = ROOT / "generated" / "Modulos" / "Central-de-Manutencao-CB5" / "Central Manutencao CB5.ps1"


def read(path):
    return path.read_text(encoding="utf-8-sig")


def write(path, text):
    path.write_text(text, encoding="utf-8-sig")


def replace_once(text, old, new, label):
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: esperado 1 trecho, encontrado {count}")
    return text.replace(old, new, 1)


# ---------------------------------------------------------------------------
# CENTRAL DE TRABALHO
# ---------------------------------------------------------------------------
central = read(CENTRAL)
central = replace_once(central, '$script:AppVersion = "0.14.4"', '$script:AppVersion = "0.14.5"', "versao Central")
central = replace_once(central, '$script:MaintenanceVersion = "0.6.0"', '$script:MaintenanceVersion = "0.6.1"', "versao Manutencao na Central")

# Remove o OwnerDraw que podia pintar o campo de Aparência sem conseguir desenhar
# o texto em alguns ambientes WinForms. O controle nativo é mais previsível.
combo_start = central.index('$themeCombo = New-Object Windows.Forms.ComboBox\n')
combo_end_marker = '$sidebarBottom.Controls.Add($themeCombo)\n'
combo_end = central.index(combo_end_marker, combo_start) + len(combo_end_marker)
new_combo = '''$themeCombo = New-Object Windows.Forms.ComboBox
$themeCombo.Location = [Drawing.Point]::new(4, 27)
$themeCombo.Size = [Drawing.Size]::new(184, 30)
$themeCombo.DropDownStyle = [Windows.Forms.ComboBoxStyle]::DropDownList
$themeCombo.DrawMode = [Windows.Forms.DrawMode]::Normal
$themeCombo.FlatStyle = [Windows.Forms.FlatStyle]::Popup
$themeCombo.IntegralHeight = $true
[void]$themeCombo.Items.AddRange(@("Escuro profissional", "Técnico industrial", "Claro corporativo", "Alto contraste"))
$themeCombo.SelectedItem = $settings.Theme
if ($themeCombo.SelectedIndex -lt 0) { $themeCombo.SelectedIndex = 0 }
$sidebarBottom.Controls.Add($themeCombo)
'''
central = central[:combo_start] + new_combo + central[combo_end:]

# Elimina estados internos de rotas que já não existem visualmente.
central = replace_once(
    central,
    '''    $map = @{
        Home = $navHome
        Programs = $navPrograms
        Updates = $navUpdates
        Backup = $navBackup
        Folder = $navFolder
        About = $navAbout
    }''',
    '''    $map = @{
        Home = $navHome
        Updates = $navUpdates
        Folder = $navFolder
        About = $navAbout
    }''',
    "mapa de navegacao"
)
central = replace_once(central, '$openGeneratorButton.Add_Click({ Set-ActiveNavigation "Programs"; Start-GeneratorModule })', '$openGeneratorButton.Add_Click({ Start-GeneratorModule })', "abrir Gerenciador")
central = replace_once(central, '$openMaintenanceButton.Add_Click({ Set-ActiveNavigation "Programs"; Start-MaintenanceModule })', '$openMaintenanceButton.Add_Click({ Start-MaintenanceModule })', "abrir Manutencao")

# A última definição é a ativa. Ela passa a cuidar apenas do que realmente está
# visível, com cada grupo isolado para um detalhe opcional nunca abortar o tema.
theme_start = central.rfind('function Apply-AppTheme {')
theme_end = central.find('\nfunction Update-ResponsiveLayout', theme_start)
if theme_start < 0 or theme_end < 0:
    raise RuntimeError('Apply-AppTheme ativo nao localizado')
new_theme = r'''function Apply-AppTheme {
    $selectedTheme = [string]$themeCombo.SelectedItem
    if ([string]::IsNullOrWhiteSpace($selectedTheme) -or -not (@("Escuro profissional", "Técnico industrial", "Claro corporativo", "Alto contraste") -contains $selectedTheme)) {
        $selectedTheme = "Escuro profissional"
    }
    $script:CurrentPalette = Get-ThemePalette $selectedTheme
    $sidebarColor = Get-SidebarColor $selectedTheme
    $generatorAccent = Get-ModuleAccent "Generator"
    $maintenanceAccent = Get-ModuleAccent "Maintenance"

    try { Set-CentralTitleBarTheme ($selectedTheme -ne "Claro corporativo") } catch {}
    try {
        $form.BackColor = $script:CurrentPalette.Background
        $rootLayout.BackColor = $script:CurrentPalette.Background
        $sidebar.BackColor = $sidebarColor
        $mainPanel.BackColor = $script:CurrentPalette.Background
        $headerPanel.BackColor = $script:CurrentPalette.Background
        $modulesHost.BackColor = $script:CurrentPalette.Background
        $footerPanel.BackColor = $script:CurrentPalette.Footer
    } catch {}
    try {
        if ($null -ne $embeddedHost) { $embeddedHost.BackColor = $script:CurrentPalette.Background }
        if ($null -ne $embeddedToolbar) { $embeddedToolbar.BackColor = $script:CurrentPalette.Surface }
        if ($null -ne $embeddedContent) { $embeddedContent.BackColor = $script:CurrentPalette.Background }
    } catch {}
    try {
        foreach ($label in @($brandTitle, $brandSub, $sidebarSection, $sidebarThemeLabel, $sidebarVersion)) {
            if ($null -ne $label) { $label.ForeColor = [Drawing.Color]::FromArgb(225, 235, 245) }
        }
        $sidebarStatus.ForeColor = $script:CurrentPalette.Success
        $sidebarStatusSub.ForeColor = [Drawing.Color]::FromArgb(161, 179, 197)
    } catch {}
    try {
        foreach ($label in @($pageTitle, $programsTitle, $generatorTitle, $maintenanceTitle, $todayLabel, $embeddedTitle)) {
            if ($null -ne $label) { $label.ForeColor = $script:CurrentPalette.Text }
        }
        foreach ($label in @($pageSubtitle, $programsSubtitle, $generatorDescription, $generatorDetail, $maintenanceDescription, $maintenanceDetail, $embeddedSubtitle, $embeddedLoading)) {
            if ($null -ne $label) { $label.ForeColor = $script:CurrentPalette.Muted }
        }
    } catch {}
    try {
        foreach ($panel in @($generatorCard, $maintenanceCard)) {
            if ($null -ne $panel) {
                $panel.BackColor = $script:CurrentPalette.Card
                $panel.BorderStyle = [Windows.Forms.BorderStyle]::FixedSingle
            }
        }
        foreach ($layout in @($generatorLayout, $maintenanceLayout)) {
            if ($null -ne $layout) { $layout.BackColor = $script:CurrentPalette.Card }
        }
        $generatorAccentBar.BackColor = $generatorAccent
        $generatorIcon.BackColor = $generatorAccent
        $generatorIcon.ForeColor = [Drawing.Color]::White
        $maintenanceAccentBar.BackColor = $maintenanceAccent
        $maintenanceIcon.BackColor = $maintenanceAccent
        $maintenanceIcon.ForeColor = [Drawing.Color]::White
        $generatorStatus.BackColor = $script:CurrentPalette.SuccessBack
        $generatorStatus.ForeColor = $script:CurrentPalette.Success
        $maintenanceStatus.BackColor = $script:CurrentPalette.SuccessBack
        $maintenanceStatus.ForeColor = $script:CurrentPalette.Success
    } catch {}
    try {
        $themeCombo.BackColor = $script:CurrentPalette.Input
        $themeCombo.ForeColor = $script:CurrentPalette.Text
        $themeCombo.Refresh()
    } catch {}
    try { Set-ActiveNavigation $script:ActiveNavName } catch {}
    try {
        Set-PrimaryButtonStyle $openGeneratorButton
        $openGeneratorButton.BackColor = $generatorAccent
        Set-PrimaryButtonStyle $openMaintenanceButton
        $openMaintenanceButton.BackColor = $maintenanceAccent
        $openMaintenanceButton.ForeColor = [Drawing.Color]::White
        Set-SecondaryButtonStyle $openGeneratorFolderButton
        Set-SecondaryButtonStyle $openMaintenanceFolderButton
        if ($null -ne $embeddedBackButton) { Set-SecondaryButtonStyle $embeddedBackButton }
        if ($null -ne $embeddedFolderButton) { Set-SecondaryButtonStyle $embeddedFolderButton }
    } catch {}
    try {
        $headerAccent.BackColor = $script:CurrentPalette.Accent
        if ($null -ne $embeddedAccentLine) {
            $embeddedAccentLine.BackColor = if ($script:EmbeddedModule -eq "Generator") { $generatorAccent } elseif ($script:EmbeddedModule -eq "Maintenance") { $maintenanceAccent } else { $script:CurrentPalette.Accent }
        }
        $headerStatusPill.BackColor = $script:CurrentPalette.SuccessBack
        $headerStatusPill.ForeColor = $script:CurrentPalette.Success
    } catch {}
    try {
        if ([IO.File]::Exists($script:GeneratorScript) -and [IO.File]::Exists($script:MaintenanceScript) -and [IO.File]::Exists($script:UpdaterScript)) {
            $sidebarStatus.Text = "●  Sistema pronto"
            $sidebarStatusSub.Text = "2 módulos disponíveis"
        }
        elseif (-not [IO.File]::Exists($script:UpdaterScript)) {
            Set-StatusMessage "O Atualizador da Central de Trabalho não foi encontrado." "Error"
            $sidebarStatus.Text = "●  Atenção"
            $sidebarStatusSub.Text = "Atualizador não localizado"
        }
        elseif (-not [IO.File]::Exists($script:MaintenanceScript)) {
            Set-StatusMessage "O módulo Central de Manutenção CB5 não foi encontrado." "Error"
            $sidebarStatus.Text = "●  Atenção"
            $sidebarStatusSub.Text = "Manutenção não localizada"
        }
        else {
            Set-StatusMessage "O módulo Gerenciador de Planilhas não foi encontrado." "Error"
            $sidebarStatus.Text = "●  Atenção"
            $sidebarStatusSub.Text = "Gerenciador não localizado"
        }
    } catch {}
    try {
        foreach ($rounded in @($generatorCard,$maintenanceCard,$brandMark,$generatorIcon,$maintenanceIcon,$openGeneratorButton,$openMaintenanceButton,$openGeneratorFolderButton,$openMaintenanceFolderButton)) {
            if ($null -ne $rounded) { Set-RoundedRegion $rounded 10 }
        }
    } catch {}
    try { $form.Invalidate($true) } catch {}
}
'''
central = central[:theme_start] + new_theme + central[theme_end:]

# Somente a área realmente visível participa do recálculo responsivo principal.
resp_start = central.rfind('function Update-ResponsiveLayout {')
resp_end = central.find('\n\n$script:CentralAdaptiveBusy', resp_start)
if resp_start < 0 or resp_end < 0:
    raise RuntimeError('Update-ResponsiveLayout ativo nao localizado')
new_resp = r'''function Update-ResponsiveLayout {
    if ($null -eq $modulesFlow -or $modulesFlow.ClientSize.Width -le 0) { return }
    try {
        $available = $modulesFlow.ClientSize.Width - $modulesFlow.Padding.Horizontal - 34
        if ($available -lt 420) { $available = 420 }
        $moduleWidth = $available
        if ($available -ge 860) { $moduleWidth = [int](($available - 22) / 2) }
        foreach ($card in @($generatorCard, $maintenanceCard)) {
            if ($null -ne $card) {
                $card.Width = $moduleWidth
                $card.Height = 252
            }
        }
    } catch {}
}
'''
central = central[:resp_start] + new_resp + central[resp_end:]

central = replace_once(
    central,
    '''$themeCombo.Add_SelectedIndexChanged({
    # A aparência da Central deve sempre mudar mesmo que um módulo hospedado
    # esteja em processo de fechamento. Erro de tema de módulo não pode abrir
    # a caixa de exceção do WinForms nem interromper a troca de aparência.
    try {
        Apply-AppTheme
        Save-AppSettings
    }
    catch {
        try { Set-StatusMessage "Não foi possível aplicar completamente a aparência da Central." "Error" } catch {}
        return
    }
    try { Sync-HostedModuleTheme }
    catch {
        try { Set-StatusMessage "A aparência da Central foi aplicada; o módulo aberto será atualizado ao reabrir." "Warning" } catch {}
    }
})''',
    '''$themeCombo.Add_SelectedIndexChanged({
    try { Apply-AppTheme } catch {}
    try { Save-AppSettings } catch {}
    try { Sync-HostedModuleTheme } catch {}
    try { Set-StatusMessage ("Aparência aplicada: " + [string]$themeCombo.SelectedItem + ".") "Success" } catch {}
})''',
    "evento de aparencia"
)
central = replace_once(
    central,
    '''$summaryFlow.Add_SizeChanged({ Update-ResponsiveLayout })
$modulesFlow.Add_SizeChanged({ Update-ResponsiveLayout })
$quickFlow.Add_SizeChanged({ Update-ResponsiveLayout })
$quickHost.Add_SizeChanged({
    $quickFlow.Width = [Math]::Max(300, $quickHost.ClientSize.Width - 36)
    $quickFlow.Height = [Math]::Max(62, $quickHost.ClientSize.Height - 53)
    Update-ResponsiveLayout
})''',
    '''$modulesFlow.Add_SizeChanged({ Update-ResponsiveLayout })''',
    "eventos responsivos antigos"
)
write(CENTRAL, central)


# ---------------------------------------------------------------------------
# CENTRAL DE MANUTENÇÃO CB5
# ---------------------------------------------------------------------------
maint = read(MAINT)
maint = replace_once(maint, '$script:AppVersion = "0.6.0"', '$script:AppVersion = "0.6.1"', "versao Manutencao")
maint = replace_once(maint, '$script:HostedSectionNavPanel = $null\n', '$script:HostedSectionNavPanel = $null\n$script:HostedShell = $null\n', "estado do shell")

# O modo integrado passa a ter três linhas físicas: cartões, navegação e conteúdo.
# Não há mais sobreposição absoluta entre essas regiões.
block_start = maint.index('if ($script:IsInProcessHosted) {\n    $tabsViewport = New-Object Windows.Forms.Panel\n')
block_end_marker = '''else {
    $rootLayout.Controls.Add($mainTabs, 0, 1)
}

$dashboardTab = New-Object Windows.Forms.TabPage'''
block_end = maint.index(block_end_marker, block_start)
new_host_block = r'''if ($script:IsInProcessHosted) {
    $script:HostedShell = New-Object Windows.Forms.TableLayoutPanel
    $script:HostedShell.Dock = [Windows.Forms.DockStyle]::Fill
    $script:HostedShell.Margin = [Windows.Forms.Padding]::new(0)
    $script:HostedShell.Padding = [Windows.Forms.Padding]::new(0)
    $script:HostedShell.ColumnCount = 1
    $script:HostedShell.RowCount = 3
    [void]$script:HostedShell.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 100)))
    [void]$script:HostedShell.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 0)))
    [void]$script:HostedShell.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 42)))
    [void]$script:HostedShell.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 100)))
    $rootLayout.Controls.Add($script:HostedShell, 0, 1)

    $tabsViewport = New-Object Windows.Forms.Panel
    $tabsViewport.Dock = [Windows.Forms.DockStyle]::Fill
    $tabsViewport.Margin = [Windows.Forms.Padding]::new(0)
    $tabsViewport.Padding = [Windows.Forms.Padding]::new(0)
    $tabsViewport.AutoScroll = $false
    $script:HostedShell.Controls.Add($tabsViewport, 0, 2)

    $mainTabs.Dock = [Windows.Forms.DockStyle]::None
    $mainTabs.Anchor = [Windows.Forms.AnchorStyles]::Top -bor [Windows.Forms.AnchorStyles]::Bottom -bor [Windows.Forms.AnchorStyles]::Left -bor [Windows.Forms.AnchorStyles]::Right
    $tabsViewport.Controls.Add($mainTabs)

    function Update-MaintenanceHostedViewport {
        if (-not $script:IsInProcessHosted) { return }
        try {
            $hiddenTabStrip = 31
            $shellW = [Math]::Max(1, $script:HostedShell.ClientSize.Width)
            $shellH = [Math]::Max(1, $script:HostedShell.ClientSize.Height)

            $isPassage = $false
            $passageVar = Get-Variable -Name passageTab -ErrorAction SilentlyContinue
            if ($null -ne $passageVar -and $null -ne $passageVar.Value -and $mainTabs.SelectedTab -eq $passageVar.Value) { $isPassage = $true }

            $overviewHeight = 0
            if (-not $isPassage -and $shellH -ge 650) {
                if ($shellW -ge 1380) {
                    $overviewHeight = if ($shellH -lt 760) { 92 } elseif ($shellH -lt 940) { 102 } else { 110 }
                }
                elseif ($shellW -ge 720 -and $shellH -ge 760) {
                    $overviewHeight = if ($shellH -lt 900) { 158 } else { 174 }
                }
                elseif ($shellH -ge 980) {
                    $overviewHeight = 300
                }
            }
            $navHeight = if ($shellH -lt 600) { 38 } else { 42 }
            $script:HostedShell.RowStyles[0].Height = $overviewHeight
            $script:HostedShell.RowStyles[1].Height = $navHeight

            if ($null -ne $script:HostedOverviewPanel) { $script:HostedOverviewPanel.Visible = ($overviewHeight -gt 0) }
            if ($null -ne $script:HostedSectionNavPanel) { $script:HostedSectionNavPanel.Visible = $true }

            $compactNav = ($shellW -lt 1120)
            if ($compactNav) {
                $dashboardNewButton.Text = "+ PASSAGEM"
                $dashboardHistoryButton.Text = "HISTÓRICO"
                $dashboardStatsButton.Text = "ESTAT."
                $dashboardDiagnosisButton.Text = "DIAGNÓST."
                $dashboardSchematicsButton.Text = "ESQUEM."
                $dashboardRulesButton.Text = "REGRAS"
            }
            else {
                $dashboardNewButton.Text = "+ NOVA PASSAGEM"
                $dashboardHistoryButton.Text = "HISTÓRICO"
                $dashboardStatsButton.Text = "ESTATÍSTICAS"
                $dashboardDiagnosisButton.Text = "DIAGNÓSTICO"
                $dashboardSchematicsButton.Text = "ESQUEMÁTICOS"
                $dashboardRulesButton.Text = "REGRAS / DADOS"
            }
            $navFont = if ($compactNav) { 7.3 } else { 8.0 }
            foreach ($button in @($dashboardNewButton, $dashboardHistoryButton, $dashboardStatsButton, $dashboardDiagnosisButton, $dashboardSchematicsButton, $dashboardRulesButton)) {
                if ($null -ne $button) {
                    $button.Font = [Drawing.Font]::new("Segoe UI Semibold", $navFont)
                    $button.Margin = [Windows.Forms.Padding]::new(2, 2, 2, 2)
                    $button.AutoEllipsis = $true
                }
            }

            $viewportW = [Math]::Max(1, $tabsViewport.ClientSize.Width)
            $viewportH = [Math]::Max(1, $tabsViewport.ClientSize.Height)
            $mainTabs.Location = [Drawing.Point]::new(0, -$hiddenTabStrip)
            $mainTabs.Size = [Drawing.Size]::new($viewportW, [Math]::Max(1, $viewportH + $hiddenTabStrip))
            $mainTabs.BringToFront()
        } catch {}
    }

    $tabsViewport.Add_SizeChanged({ Update-MaintenanceHostedViewport })
    $script:HostedShell.Add_SizeChanged({ Update-MaintenanceHostedViewport })
}
else {
    $rootLayout.Controls.Add($mainTabs, 0, 1)
}

$dashboardTab = New-Object Windows.Forms.TabPage'''
maint = maint[:block_start] + new_host_block + maint[block_end + len(block_end_marker):]

maint = replace_once(
    maint,
    '''    $script:HostedOverviewPanel.Margin = [Windows.Forms.Padding]::new(0)
    $script:HostedOverviewPanel.Padding = [Windows.Forms.Padding]::new(8, 5, 8, 5)
    $tabsViewport.Controls.Add($script:HostedOverviewPanel)''',
    '''    $script:HostedOverviewPanel.Dock = [Windows.Forms.DockStyle]::Fill
    $script:HostedOverviewPanel.Margin = [Windows.Forms.Padding]::new(0)
    $script:HostedOverviewPanel.Padding = [Windows.Forms.Padding]::new(8, 4, 8, 2)
    $script:HostedShell.Controls.Add($script:HostedOverviewPanel, 0, 0)''',
    "overview no shell"
)
maint = replace_once(
    maint,
    '''    $script:HostedSectionNavPanel.Margin = [Windows.Forms.Padding]::new(0)
    $script:HostedSectionNavPanel.Padding = [Windows.Forms.Padding]::new(8, 2, 8, 2)
    $tabsViewport.Controls.Add($script:HostedSectionNavPanel)''',
    '''    $script:HostedSectionNavPanel.Dock = [Windows.Forms.DockStyle]::Fill
    $script:HostedSectionNavPanel.Margin = [Windows.Forms.Padding]::new(0)
    $script:HostedSectionNavPanel.Padding = [Windows.Forms.Padding]::new(8, 2, 8, 2)
    $script:HostedShell.Controls.Add($script:HostedSectionNavPanel, 0, 1)''',
    "navegacao no shell"
)
write(MAINT, maint)
print("Manutenção geral v0.14.5 aplicada com sucesso.")
