from pathlib import Path
import re

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


def regex_once(text, pattern, replacement, label):
    out, count = re.subn(pattern, replacement, text, count=1, flags=re.S)
    if count != 1:
        raise RuntimeError(f"{label}: esperado 1 trecho, encontrado {count}")
    return out


central = read(CENTRAL)
central = replace_once(central, '$script:AppVersion = "0.14.2"', '$script:AppVersion = "0.14.3"', "versao Central")
central = replace_once(central, '$script:MaintenanceVersion = "0.5.8"', '$script:MaintenanceVersion = "0.5.9"', "versao Manutencao na Central")
write(CENTRAL, central)

maint = read(MAINT)
maint = replace_once(maint, '$script:AppVersion = "0.5.8"', '$script:AppVersion = "0.5.9"', "versao Manutencao")

old_globals = '''$script:InternalNavPanel = $null
$script:InternalBackButton = $null
$script:InternalSectionLabel = $null'''
new_globals = '''$script:InternalNavPanel = $null
$script:InternalBackButton = $null
$script:InternalSectionLabel = $null
$script:HostedOverviewPanel = $null
$script:HostedOverviewLayout = $null
$script:HostedSectionNavPanel = $null'''
maint = replace_once(maint, old_globals, new_globals, "estado da navegacao persistente")

# O antigo painel de voltar interno deixa de participar do layout. A faixa de
# seções e o resumo passam a viver fora do TabControl e permanecem visíveis.
new_viewport = r'''function Update-MaintenanceHostedViewport {
        if (-not $script:IsInProcessHosted) { return }
        try {
            $hiddenTabStrip = 31
            $overviewHeight = 0
            $sectionNavHeight = 0
            $isPassage = $false

            $passageVar = Get-Variable -Name passageTab -ErrorAction SilentlyContinue
            if ($null -ne $passageVar -and $null -ne $passageVar.Value -and $mainTabs.SelectedTab -eq $passageVar.Value) {
                $isPassage = $true
            }

            if ($null -ne $script:HostedOverviewPanel) {
                if ($isPassage) {
                    $script:HostedOverviewPanel.Visible = $false
                }
                else {
                    $introHeight = 56
                    $cardsHeight = 122
                    try { $introHeight = [Math]::Max(42, [int]$dashboardRoot.RowStyles[0].Height) } catch {}
                    try { $cardsHeight = [Math]::Max(96, [int]$dashboardRoot.RowStyles[1].Height) } catch {}
                    $overviewHeight = $introHeight + $cardsHeight + 16
                    $script:HostedOverviewPanel.Visible = $true
                    $script:HostedOverviewPanel.Location = [Drawing.Point]::new(0, 0)
                    $script:HostedOverviewPanel.Size = [Drawing.Size]::new([Math]::Max(1, $tabsViewport.ClientSize.Width), $overviewHeight)
                    if ($null -ne $script:HostedOverviewLayout) {
                        $script:HostedOverviewLayout.RowStyles[0].Height = $introHeight
                        $script:HostedOverviewLayout.RowStyles[1].Height = $cardsHeight
                    }
                }
            }

            if ($null -ne $script:HostedSectionNavPanel) {
                $sectionNavHeight = 46
                $script:HostedSectionNavPanel.Visible = $true
                $script:HostedSectionNavPanel.Location = [Drawing.Point]::new(0, $overviewHeight)
                $script:HostedSectionNavPanel.Size = [Drawing.Size]::new([Math]::Max(1, $tabsViewport.ClientSize.Width), $sectionNavHeight)
                $script:HostedSectionNavPanel.BringToFront()
            }

            if ($null -ne $script:InternalNavPanel) { $script:InternalNavPanel.Visible = $false }

            $contentTop = $overviewHeight + $sectionNavHeight
            $mainTabs.Location = [Drawing.Point]::new(0, $contentTop - $hiddenTabStrip)
            $mainTabs.Size = [Drawing.Size]::new(
                [Math]::Max(1, $tabsViewport.ClientSize.Width),
                [Math]::Max(1, $tabsViewport.ClientSize.Height - $contentTop + $hiddenTabStrip)
            )
        } catch {}
    }
'''
maint = regex_once(
    maint,
    r'function Update-MaintenanceHostedViewport \{.*?\n    \}\n\n    \$tabsViewport\.Add_SizeChanged',
    new_viewport + '\n    $tabsViewport.Add_SizeChanged',
    "viewport hospedado persistente"
)

# Depois que os cinco botões existem, tiramos resumo/cartões/navegação da
# página Visão geral e os colocamos como cabeçalho persistente do módulo.
anchor = '''$dashboardNavigation.Controls.Add($dashboardHistoryButton, 0, 0)
$dashboardNavigation.Controls.Add($dashboardStatsButton, 1, 0)
$dashboardNavigation.Controls.Add($dashboardDiagnosisButton, 2, 0)
$dashboardNavigation.Controls.Add($dashboardSchematicsButton, 3, 0)
$dashboardNavigation.Controls.Add($dashboardRulesButton, 4, 0)
'''
insert = anchor + r'''
if ($script:IsInProcessHosted) {
    # Cabeçalho persistente: visão geral + cartões.
    $script:HostedOverviewPanel = New-Object Windows.Forms.Panel
    $script:HostedOverviewPanel.Margin = [Windows.Forms.Padding]::new(0)
    $script:HostedOverviewPanel.Padding = [Windows.Forms.Padding]::new(8, 6, 8, 4)
    $tabsViewport.Controls.Add($script:HostedOverviewPanel)

    $script:HostedOverviewLayout = New-Object Windows.Forms.TableLayoutPanel
    $script:HostedOverviewLayout.Dock = [Windows.Forms.DockStyle]::Fill
    $script:HostedOverviewLayout.Margin = [Windows.Forms.Padding]::new(0)
    $script:HostedOverviewLayout.Padding = [Windows.Forms.Padding]::new(4, 0, 4, 0)
    $script:HostedOverviewLayout.ColumnCount = 1
    $script:HostedOverviewLayout.RowCount = 2
    [void]$script:HostedOverviewLayout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 100)))
    [void]$script:HostedOverviewLayout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, $dashboardIntroHeight)))
    [void]$script:HostedOverviewLayout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, $dashboardCardsHeight)))
    $script:HostedOverviewPanel.Controls.Add($script:HostedOverviewLayout)

    try { $dashboardRoot.Controls.Remove($dashboardIntro) } catch {}
    try { $dashboardRoot.Controls.Remove($cardsLayout) } catch {}
    $dashboardIntro.Dock = [Windows.Forms.DockStyle]::Fill
    $dashboardIntro.Margin = [Windows.Forms.Padding]::new(0)
    $cardsLayout.Dock = [Windows.Forms.DockStyle]::Fill
    $cardsLayout.Margin = [Windows.Forms.Padding]::new(0)
    $script:HostedOverviewLayout.Controls.Add($dashboardIntro, 0, 0)
    $script:HostedOverviewLayout.Controls.Add($cardsLayout, 0, 1)

    # Os cinco botões viram a navegação fixa da Manutenção.
    $script:HostedSectionNavPanel = New-Object Windows.Forms.Panel
    $script:HostedSectionNavPanel.Margin = [Windows.Forms.Padding]::new(0)
    $script:HostedSectionNavPanel.Padding = [Windows.Forms.Padding]::new(8, 2, 8, 2)
    $tabsViewport.Controls.Add($script:HostedSectionNavPanel)
    try { $dashboardRoot.Controls.Remove($dashboardNavigation) } catch {}
    $dashboardNavigation.Dock = [Windows.Forms.DockStyle]::Fill
    $dashboardNavigation.Margin = [Windows.Forms.Padding]::new(0)
    $script:HostedSectionNavPanel.Controls.Add($dashboardNavigation)

    if ($null -ne $script:InternalNavPanel) { $script:InternalNavPanel.Visible = $false }
    $script:HostedOverviewPanel.BringToFront()
    $script:HostedSectionNavPanel.BringToFront()
}

function Update-MaintenanceSectionNavigation {
    if (-not $script:IsInProcessHosted) { return }
    try {
        $pairs = @(
            @($dashboardHistoryButton, $historyTab),
            @($dashboardStatsButton, $statisticsTab),
            @($dashboardDiagnosisButton, $diagnosisTab),
            @($dashboardSchematicsButton, $schematicsTab),
            @($dashboardRulesButton, $rulesTab)
        )
        foreach ($pair in $pairs) {
            $button = $pair[0]
            $page = $pair[1]
            $button.Tag = if ($mainTabs.SelectedTab -eq $page) { "Primary" } else { "Secondary" }
            Set-MaintenanceButtonStyle $button
        }
        Update-MaintenanceHostedViewport
    } catch {}
}
'''
maint = replace_once(maint, anchor, insert, "cabecalho e botoes persistentes")

# O botão Painel da manutenção deixa de ser necessário no modo integrado.
new_internal_nav = r'''function Update-MaintenanceInternalNavigation {
    if (-not $script:IsInProcessHosted) { return }
    try {
        $footerHomeButton.Visible = $false
        if ($null -ne $script:InternalNavPanel) { $script:InternalNavPanel.Visible = $false }
        Update-MaintenanceSectionNavigation
    } catch {}
}
'''
maint = regex_once(
    maint,
    r'function Update-MaintenanceInternalNavigation \{.*?\n\}\n\n\$mainTabs\.Add_SelectedIndexChanged',
    new_internal_nav + '\n$mainTabs.Add_SelectedIndexChanged',
    "remove painel voltar interno"
)

maint = replace_once(
    maint,
    '$mainTabs.Add_SelectedIndexChanged({ Update-MaintenanceInternalNavigation })',
    '$mainTabs.Add_SelectedIndexChanged({ Update-MaintenanceInternalNavigation; Update-MaintenanceSectionNavigation })',
    "atualiza navegacao fixa ao trocar secao"
)

# Os painéis persistentes também acompanham a paleta ativa.
old_theme = '''    if ($script:IsInProcessHosted -and $null -ne $script:InternalNavPanel) {
        $script:InternalNavPanel.BackColor = $script:CurrentPalette.Surface
        if ($null -ne $script:InternalBackButton) { Set-MaintenanceButtonStyle $script:InternalBackButton }
        if ($null -ne $script:InternalSectionLabel) { $script:InternalSectionLabel.ForeColor = $script:CurrentPalette.Muted }
    }'''
new_theme = old_theme + r'''
    if ($script:IsInProcessHosted) {
        if ($null -ne $script:HostedOverviewPanel) { $script:HostedOverviewPanel.BackColor = $script:CurrentPalette.Background }
        if ($null -ne $script:HostedOverviewLayout) { $script:HostedOverviewLayout.BackColor = $script:CurrentPalette.Background }
        if ($null -ne $script:HostedSectionNavPanel) { $script:HostedSectionNavPanel.BackColor = $script:CurrentPalette.Background }
        try { Update-MaintenanceSectionNavigation } catch {}
    }'''
maint = replace_once(maint, old_theme, new_theme, "tema dos paineis persistentes")

# Ao abrir integrada, Histórico é a seção padrão real; assim seus botões de
# visualizar/editar/retorno/exportar já aparecem abaixo da navegação fixa.
old_start = '''    Apply-MaintenanceTheme
    Reset-PassageForm
    Refresh-AllViews
    Update-MaintenanceResponsiveLayout'''
new_start = '''    Apply-MaintenanceTheme
    Reset-PassageForm
    Refresh-AllViews
    $mainTabs.SelectedTab = $historyTab
    Update-MaintenanceResponsiveLayout
    Update-MaintenanceSectionNavigation'''
maint = replace_once(maint, old_start, new_start, "historico como secao padrao integrada")

write(MAINT, maint)
print("Transformação v0.14.3 aplicada com sucesso.")
