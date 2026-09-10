from pathlib import Path

ROOT = Path('src/generated')
central_path = ROOT / 'Central de Trabalho.ps1'
maint_path = ROOT / 'Modulos/Central-de-Manutencao-CB5/Central Manutencao CB5.ps1'
central = central_path.read_text(encoding='utf-8-sig')
maint = maint_path.read_text(encoding='utf-8-sig')


def rep(text, old, new, label, count=1):
    n = text.count(old)
    if n != count:
        raise RuntimeError(f'{label}: esperado {count} trecho(s), encontrado {n}')
    return text.replace(old, new, count)

# ---------------------------------------------------------------------------
# Central de Trabalho — pequenos cortes visíveis na captura do usuário.
# ---------------------------------------------------------------------------
central = rep(central, '$script:AppVersion = "0.12.0"', '$script:AppVersion = "0.12.1"', 'versão da Central')
central = rep(central, '$script:MaintenanceVersion = "0.5.5"', '$script:MaintenanceVersion = "0.5.6"', 'versão da Manutenção na Central')
central = rep(central, '$navUpdates = New-SidebarButton "↻   Atualizações / backup"', '$navUpdates = New-SidebarButton "↻   Atualizações"', 'texto de Atualizações')
central = rep(central, '$brandSub.Text = "Organização • Controle • Trabalho"', '$brandSub.Text = "Organização • Controle"', 'subtítulo da marca')
central = central.replace('Todos os módulos disponíveis', '2 módulos disponíveis')
central = rep(central, '$sidebarVersion.Location = [Drawing.Point]::new(4, 128)', '$sidebarVersion.Location = [Drawing.Point]::new(4, 123)', 'posição da versão lateral')

# O botão da pasta do módulo estava sendo truncado em todos os perfis.
central = rep(central, '$embeddedFolderButton.Size = [Drawing.Size]::new(110, 32)', '$embeddedFolderButton.Size = [Drawing.Size]::new(150, 32)', 'botão pasta inicial')
central = rep(central, '$embeddedFolderButton.Size = [Drawing.Size]::new(102, 30)', '$embeddedFolderButton.Size = [Drawing.Size]::new(132, 30)', 'botão pasta compacto')
central = rep(central, '$embeddedFolderButton.Size = [Drawing.Size]::new(106,31)', '$embeddedFolderButton.Size = [Drawing.Size]::new(140,31)', 'botão pasta balanced')
central = rep(central, '$embeddedFolderButton.Size = [Drawing.Size]::new(110,32)', '$embeddedFolderButton.Size = [Drawing.Size]::new(150,32)', 'botão pasta confortável')

# ---------------------------------------------------------------------------
# Central de Manutenção — dashboard, textos e voltar interno.
# ---------------------------------------------------------------------------
maint = rep(maint, '$script:AppVersion = "0.5.5"', '$script:AppVersion = "0.5.6"', 'versão da Manutenção')

# Variáveis sempre definidas para o StrictMode, inclusive no modo independente.
maint = rep(
    maint,
    '$script:IsLoadingForm = $false\n$script:CorrectionMode = $false\n',
    '$script:IsLoadingForm = $false\n$script:CorrectionMode = $false\n$script:InternalNavPanel = $null\n$script:InternalBackButton = $null\n$script:InternalSectionLabel = $null\n',
    'estado da navegação interna'
)

# A área superior das abas já era escondida. Aproveitamos esse espaço para uma
# barra interna real, exibida somente nas subpáginas da Manutenção.
old_viewport = '''    $tabsViewport.AutoScroll = $false
    $rootLayout.Controls.Add($tabsViewport, 0, 1)

    $mainTabs.Dock = [Windows.Forms.DockStyle]::None
    $mainTabs.Anchor = [Windows.Forms.AnchorStyles]::Top -bor [Windows.Forms.AnchorStyles]::Bottom -bor [Windows.Forms.AnchorStyles]::Left -bor [Windows.Forms.AnchorStyles]::Right
    $tabsViewport.Controls.Add($mainTabs)
    $tabsViewport.Add_SizeChanged({
        try {
            $hiddenTabStrip = 31
            $mainTabs.Location = [Drawing.Point]::new(0, -$hiddenTabStrip)
            $mainTabs.Size = [Drawing.Size]::new([Math]::Max(1, $tabsViewport.ClientSize.Width), [Math]::Max(1, $tabsViewport.ClientSize.Height + $hiddenTabStrip))
        } catch {}
    })
    try {
        $hiddenTabStrip = 31
        $mainTabs.Location = [Drawing.Point]::new(0, -$hiddenTabStrip)
        $mainTabs.Size = [Drawing.Size]::new([Math]::Max(1, $tabsViewport.ClientSize.Width), [Math]::Max(1, $tabsViewport.ClientSize.Height + $hiddenTabStrip))
    } catch {}
'''
new_viewport = '''    $tabsViewport.AutoScroll = $false
    $rootLayout.Controls.Add($tabsViewport, 0, 1)

    $script:InternalNavPanel = New-Object Windows.Forms.Panel
    $script:InternalNavPanel.Dock = [Windows.Forms.DockStyle]::Top
    $script:InternalNavPanel.Height = 38
    $script:InternalNavPanel.Padding = [Windows.Forms.Padding]::new(8, 4, 8, 4)
    $script:InternalNavPanel.Visible = $false
    $tabsViewport.Controls.Add($script:InternalNavPanel)

    $script:InternalBackButton = New-Object Windows.Forms.Button
    $script:InternalBackButton.Text = "←  PAINEL DA MANUTENÇÃO"
    $script:InternalBackButton.Dock = [Windows.Forms.DockStyle]::Left
    $script:InternalBackButton.Width = 205
    $script:InternalBackButton.Margin = [Windows.Forms.Padding]::new(0)
    $script:InternalBackButton.Font = [Drawing.Font]::new("Segoe UI Semibold", 8.6)
    $script:InternalBackButton.Tag = "Secondary"
    $script:InternalNavPanel.Controls.Add($script:InternalBackButton)

    $script:InternalSectionLabel = New-Object Windows.Forms.Label
    $script:InternalSectionLabel.Text = ""
    $script:InternalSectionLabel.Dock = [Windows.Forms.DockStyle]::Fill
    $script:InternalSectionLabel.Padding = [Windows.Forms.Padding]::new(12, 0, 0, 0)
    $script:InternalSectionLabel.TextAlign = [Drawing.ContentAlignment]::MiddleLeft
    $script:InternalSectionLabel.Font = [Drawing.Font]::new("Segoe UI Semibold", 9.2)
    $script:InternalNavPanel.Controls.Add($script:InternalSectionLabel)

    $mainTabs.Dock = [Windows.Forms.DockStyle]::None
    $mainTabs.Anchor = [Windows.Forms.AnchorStyles]::Top -bor [Windows.Forms.AnchorStyles]::Bottom -bor [Windows.Forms.AnchorStyles]::Left -bor [Windows.Forms.AnchorStyles]::Right
    $tabsViewport.Controls.Add($mainTabs)

    function Update-MaintenanceHostedViewport {
        if (-not $script:IsInProcessHosted) { return }
        try {
            $hiddenTabStrip = 31
            $navHeight = if ($null -ne $script:InternalNavPanel -and $script:InternalNavPanel.Visible) { 38 } else { 0 }
            $mainTabs.Location = [Drawing.Point]::new(0, $navHeight - $hiddenTabStrip)
            $mainTabs.Size = [Drawing.Size]::new(
                [Math]::Max(1, $tabsViewport.ClientSize.Width),
                [Math]::Max(1, $tabsViewport.ClientSize.Height - $navHeight + $hiddenTabStrip)
            )
            if ($null -ne $script:InternalNavPanel) {
                $script:InternalNavPanel.Width = [Math]::Max(1, $tabsViewport.ClientSize.Width)
                $script:InternalNavPanel.BringToFront()
            }
        } catch {}
    }

    $tabsViewport.Add_SizeChanged({ Update-MaintenanceHostedViewport })
    Update-MaintenanceHostedViewport
'''
maint = rep(maint, old_viewport, new_viewport, 'viewport hospedado')

# Cartões: guardamos também o rótulo para aplicar contraste explicitamente.
maint = rep(
    maint,
    '$script:SummaryCardDecorations += [pscustomobject]@{ Card = $card; Bar = $accentBar; Value = $value; Kind = $Kind }',
    '$script:SummaryCardDecorations += [pscustomobject]@{ Card = $card; Bar = $accentBar; Value = $value; Label = $label; Kind = $Kind }',
    'metadados dos cartões'
)

# Reforça legibilidade do dashboard. Na captura, título, subtítulo, nomes dos
# cartões e texto do botão estavam visualmente desaparecendo.
maint = rep(
    maint,
    '        $d.Bar.BackColor = $color\n        $d.Value.ForeColor = $color\n    }\n    if ($null -ne $dashboardSubtitle) { $dashboardSubtitle.ForeColor = $script:CurrentPalette.Muted }',
    '        $d.Bar.BackColor = $color\n        $d.Value.ForeColor = $color\n        if ($null -ne $d.Label) {\n            $d.Label.ForeColor = $script:CurrentPalette.Muted\n            $d.Label.BackColor = $script:CurrentPalette.Card\n        }\n    }\n    if ($null -ne $dashboardTitle) {\n        $dashboardTitle.ForeColor = $script:CurrentPalette.Text\n        $dashboardTitle.BackColor = $script:CurrentPalette.Background\n    }\n    if ($null -ne $dashboardSubtitle) {\n        $dashboardSubtitle.ForeColor = $script:CurrentPalette.Muted\n        $dashboardSubtitle.BackColor = $script:CurrentPalette.Background\n    }\n    if ($null -ne $dashboardNewButton) {\n        $dashboardNewButton.Text = "+  NOVA PASSAGEM"\n        $dashboardNewButton.BackColor = $script:CurrentPalette.Action\n        $dashboardNewButton.ForeColor = $script:CurrentPalette.ActionText\n        $dashboardNewButton.FlatAppearance.BorderSize = 0\n        $dashboardNewButton.UseVisualStyleBackColor = $false\n    }\n    if ($script:IsInProcessHosted -and $null -ne $script:InternalNavPanel) {\n        $script:InternalNavPanel.BackColor = $script:CurrentPalette.Surface\n        if ($null -ne $script:InternalBackButton) { Set-MaintenanceButtonStyle $script:InternalBackButton }\n        if ($null -ne $script:InternalSectionLabel) { $script:InternalSectionLabel.ForeColor = $script:CurrentPalette.Muted }\n    }\n    if ($null -ne $dashboardSubtitle) { $dashboardSubtitle.ForeColor = $script:CurrentPalette.Muted }',
    'contraste do dashboard'
)

# Tipografia explícita nos elementos que sumiram visualmente.
maint = rep(
    maint,
    '$dashboardNewButton.Tag = "Action"\n$dashboardIntro.Controls.Add($dashboardNewButton, 1, 0)',
    '$dashboardNewButton.Tag = "Action"\n$dashboardNewButton.Font = [Drawing.Font]::new("Segoe UI Semibold", 9.0)\n$dashboardNewButton.TextAlign = [Drawing.ContentAlignment]::MiddleCenter\n$dashboardNewButton.UseVisualStyleBackColor = $false\n$dashboardIntro.Controls.Add($dashboardNewButton, 1, 0)',
    'botão nova passagem'
)
maint = rep(
    maint,
    '$label.AutoEllipsis = $true\n    $content.Controls.Add($label, 0, 1)',
    '$label.AutoEllipsis = $true\n    $label.Font = [Drawing.Font]::new("Segoe UI Semibold", $(if ($script:IsInProcessHosted) { 8.6 } else { 9.0 }))\n    $content.Controls.Add($label, 0, 1)',
    'rótulo dos cartões'
)

# O antigo voltar do rodapé deixa de ser a navegação principal. A nova barra
# aparece logo acima da subpágina, sem sair da Central de Manutenção.
maint = rep(
    maint,
    '[void]$footerLayout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Absolute, 132)))',
    '[void]$footerLayout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Absolute, 0)))',
    'coluna do voltar antigo'
)
maint = rep(
    maint,
    '$footerHomeButton.Text = "← VISÃO GERAL"',
    '$footerHomeButton.Text = "← PAINEL DA MANUTENÇÃO"',
    'texto do voltar antigo'
)

old_events = '''$dashboardHistoryButton.Add_Click({ $mainTabs.SelectedTab = $historyTab })
$dashboardStatsButton.Add_Click({ $mainTabs.SelectedTab = $statisticsTab })
$dashboardDiagnosisButton.Add_Click({ $mainTabs.SelectedTab = $diagnosisTab })
$dashboardSchematicsButton.Add_Click({ $mainTabs.SelectedTab = $schematicsTab })
$dashboardRulesButton.Add_Click({ $mainTabs.SelectedTab = $rulesTab })
$footerHomeButton.Add_Click({ $mainTabs.SelectedTab = $dashboardTab })
$mainTabs.Add_SelectedIndexChanged({
    try {
        if ($script:IsInProcessHosted) {
            $footerHomeButton.Visible = ($mainTabs.SelectedTab -ne $dashboardTab)
        }
    } catch {}
})
'''
new_events = '''$dashboardHistoryButton.Add_Click({ $mainTabs.SelectedTab = $historyTab })
$dashboardStatsButton.Add_Click({ $mainTabs.SelectedTab = $statisticsTab })
$dashboardDiagnosisButton.Add_Click({ $mainTabs.SelectedTab = $diagnosisTab })
$dashboardSchematicsButton.Add_Click({ $mainTabs.SelectedTab = $schematicsTab })
$dashboardRulesButton.Add_Click({ $mainTabs.SelectedTab = $rulesTab })
$footerHomeButton.Add_Click({ $mainTabs.SelectedTab = $dashboardTab })
if ($script:IsInProcessHosted -and $null -ne $script:InternalBackButton) {
    $script:InternalBackButton.Add_Click({ $mainTabs.SelectedTab = $dashboardTab })
}

function Update-MaintenanceInternalNavigation {
    if (-not $script:IsInProcessHosted) { return }
    try {
        $showInternalBack = ($mainTabs.SelectedTab -ne $dashboardTab)
        $footerHomeButton.Visible = $false
        if ($null -ne $script:InternalNavPanel) {
            $script:InternalNavPanel.Visible = $showInternalBack
            if ($showInternalBack -and $null -ne $script:InternalSectionLabel) {
                $section = [string]$mainTabs.SelectedTab.Text
                if ($section -eq "Passagem") { $section = "Passagem / manutenção" }
                $script:InternalSectionLabel.Text = $section
            }
        }
        Update-MaintenanceHostedViewport
    } catch {}
}

$mainTabs.Add_SelectedIndexChanged({ Update-MaintenanceInternalNavigation })
'''
maint = rep(maint, old_events, new_events, 'eventos da navegação interna')

# Garante estado correto logo na primeira abertura.
maint = rep(
    maint,
    '$themeCombo.Add_SelectedIndexChanged({ Apply-MaintenanceTheme; Update-MaintenanceResponsiveLayout; Save-MaintenanceSettings })',
    '$themeCombo.Add_SelectedIndexChanged({ Apply-MaintenanceTheme; Update-MaintenanceResponsiveLayout; Update-MaintenanceInternalNavigation; Save-MaintenanceSettings })',
    'evento do tema'
)

checks = [
    ('$script:AppVersion = "0.12.1"' in central, 'Central não ficou em 0.12.1'),
    ('$script:MaintenanceVersion = "0.5.6"' in central, 'Central não referencia Manutenção 0.5.6'),
    ('↻   Atualizações / backup' not in central, 'texto lateral ainda pode cortar'),
    ('Organização • Controle • Trabalho' not in central, 'subtítulo lateral ainda pode cortar'),
    ('PASTA DO MÓDULO' in central, 'botão pasta do módulo ausente'),
    ('$script:AppVersion = "0.5.6"' in maint, 'Manutenção não ficou em 0.5.6'),
    ('PAINEL DA MANUTENÇÃO' in maint, 'voltar interno ausente'),
    ('Update-MaintenanceHostedViewport' in maint, 'layout da barra interna ausente'),
    ('Update-MaintenanceInternalNavigation' in maint, 'estado da navegação interna ausente'),
    ('Label = $label' in maint, 'rótulos dos cartões não entram no tema'),
    ('$dashboardNewButton.UseVisualStyleBackColor = $false' in maint, 'botão Nova passagem sem renderização explícita'),
]
for ok, msg in checks:
    if not ok:
        raise RuntimeError(msg)

for name, content in [('Central', central), ('Manutenção', maint)]:
    if content.count('{') != content.count('}'):
        raise RuntimeError(f'{name}: chaves desbalanceadas')
    if content.count('(') != content.count(')'):
        raise RuntimeError(f'{name}: parênteses desbalanceados')

central_path.write_text(central, encoding='utf-8', newline='')
maint_path.write_text(maint, encoding='utf-8', newline='')
print('v0.12.1: dashboard e navegação interna da Manutenção corrigidos.')
