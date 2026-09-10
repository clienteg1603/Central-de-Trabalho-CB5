from pathlib import Path

CENTRAL = Path('src/generated/Central de Trabalho.ps1')
MAINT = Path('src/generated/Modulos/Central-de-Manutencao-CB5/Central Manutencao CB5.ps1')


def replace_once(text, old, new, label):
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: esperado 1 ocorrência, encontrado {count}')
    return text.replace(old, new, 1)


def replace_count(text, old, new, expected, label):
    count = text.count(old)
    if count != expected:
        raise SystemExit(f'{label}: esperado {expected} ocorrência(s), encontrado {count}')
    return text.replace(old, new)


# -----------------------------------------------------------------------------
# CENTRAL DE TRABALHO — uma rota visível para cada função
# -----------------------------------------------------------------------------
central = CENTRAL.read_text(encoding='utf-8-sig')
central = replace_once(central, '$script:AppVersion = "0.11.0"', '$script:AppVersion = "0.11.3"', 'versão da Central')
central = replace_once(central, '$script:MaintenanceVersion = "0.5.0"', '$script:MaintenanceVersion = "0.5.3"', 'versão exibida da Manutenção')

# A área central passa a dedicar o espaço aos programas. Resumo e Ações rápidas
# continuam construídos internamente nesta revisão por segurança, porém ficam
# invisíveis e com linhas de altura zero. Isso evita tocar em regras/eventos já
# estabilizados e elimina a repetição visual.
central = replace_once(
    central,
    '[void]$mainLayout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 98)))',
    '[void]$mainLayout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 0)))',
    'linha de resumo da Central'
)
central = replace_once(
    central,
    '[void]$mainLayout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 132)))',
    '[void]$mainLayout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 0)))',
    'linha de ações rápidas da Central'
)
central = replace_once(
    central,
    '$summaryHost.Padding = [Windows.Forms.Padding]::new(18, 2, 18, 6)\n$mainLayout.Controls.Add($summaryHost, 0, 1)',
    '$summaryHost.Padding = [Windows.Forms.Padding]::new(18, 2, 18, 6)\n$summaryHost.Visible = $false\n$mainLayout.Controls.Add($summaryHost, 0, 1)',
    'oculta resumo repetido'
)
central = replace_once(
    central,
    '$quickHost.Padding = [Windows.Forms.Padding]::new(18, 0, 18, 4)\n$mainLayout.Controls.Add($quickHost, 0, 3)',
    '$quickHost.Padding = [Windows.Forms.Padding]::new(18, 0, 18, 4)\n$quickHost.Visible = $false\n$mainLayout.Controls.Add($quickHost, 0, 3)',
    'oculta ações rápidas repetidas'
)

# Navegação lateral: Início + Atualizações/backup + Pasta da Central + Sobre.
central = replace_once(
    central,
    '$navPrograms = New-SidebarButton "▦   Programas"',
    '$navPrograms = New-SidebarButton "▦   Programas"\n$navPrograms.Visible = $false',
    'oculta Programas duplicado'
)
central = replace_once(
    central,
    '$navUpdates = New-SidebarButton "↻   Atualizações"',
    '$navUpdates = New-SidebarButton "↻   Atualizações / backup"',
    'une Atualizações e backup'
)
central = replace_once(
    central,
    '$navBackup = New-SidebarButton "⟲   Backup / restauração"',
    '$navBackup = New-SidebarButton "⟲   Backup / restauração"\n$navBackup.Visible = $false',
    'oculta Backup duplicado'
)
central = replace_once(
    central,
    '$navFolder = New-SidebarButton "▣   Abrir pasta"',
    '$navFolder = New-SidebarButton "▣   Pasta da Central"',
    'nome claro para pasta raiz'
)
central = replace_once(
    central,
    '$embeddedFolderButton.Text = "ABRIR PASTA"',
    '$embeddedFolderButton.Text = "PASTA DO MÓDULO"',
    'distingue pasta do módulo'
)

# Com quatro itens visíveis, a navegação não precisa reservar o espaço de seis.
central = replace_once(central, '$navPanel.Height = 256', '$navPanel.Height = 180', 'nav compacta')
central = replace_once(central, '$navPanel.Height = 278', '$navPanel.Height = 195', 'nav balanceada')
central = replace_count(central, '$navPanel.Height = 300', '$navPanel.Height = 210', 2, 'nav confortável/inicial')

# Status e versão já aparecem na lateral; não repetir no cabeçalho/rodapé.
central = replace_once(
    central,
    '$headerPanel.Controls.Add($headerStatusPill)',
    '$headerPanel.Controls.Add($headerStatusPill)\n$headerStatusPill.Visible = $false',
    'status duplicado do cabeçalho'
)
central = replace_once(
    central,
    '$footerLayout.Controls.Add($footerVersion, 1, 0)',
    '$footerLayout.Controls.Add($footerVersion, 1, 0)\n$footerVersion.Visible = $false',
    'versão duplicada do rodapé'
)
central += '\n# UI_DEDUP_CENTRAL_V0113\n'
CENTRAL.write_text(central, encoding='utf-8', newline='')


# -----------------------------------------------------------------------------
# CENTRAL DE MANUTENÇÃO — botões centrais como navegação principal
# -----------------------------------------------------------------------------
maint = MAINT.read_text(encoding='utf-8-sig')
maint = replace_once(maint, '$script:AppVersion = "0.5.2"', '$script:AppVersion = "0.5.3"', 'versão interna da Manutenção')

# Em modo hospedado, esconder fisicamente a faixa de abas. O TabControl continua
# sendo o mecanismo interno de páginas, mas seus cabeçalhos ficam fora da área
# visível. Isso preserva todo o código funcional e deixa a navegação para os
# botões da Visão geral.
maint = replace_once(
    maint,
    '$rootLayout.Controls.Add($mainTabs, 0, 1)',
    '''if ($script:IsInProcessHosted) {
    $tabsViewport = New-Object Windows.Forms.Panel
    $tabsViewport.Dock = [Windows.Forms.DockStyle]::Fill
    $tabsViewport.Margin = [Windows.Forms.Padding]::new(0)
    $tabsViewport.Padding = [Windows.Forms.Padding]::new(0)
    $tabsViewport.AutoScroll = $false
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
}
else {
    $rootLayout.Controls.Add($mainTabs, 0, 1)
}''',
    'hospedagem sem cabeçalhos de abas'
)

# Visão geral com uma faixa única de navegação central.
maint = replace_once(
    maint,
    '''$dashboardRoot.RowCount = 3
$dashboardRoot.ColumnCount = 1
$dashboardIntroHeight = if ($script:IsInProcessHosted) { 56 } else { 68 }
$dashboardCardsHeight = if ($script:IsInProcessHosted) { 122 } else { 138 }
[void]$dashboardRoot.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, $dashboardIntroHeight)))
[void]$dashboardRoot.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, $dashboardCardsHeight)))
[void]$dashboardRoot.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 100)))''',
    '''$dashboardRoot.RowCount = 4
$dashboardRoot.ColumnCount = 1
$dashboardIntroHeight = if ($script:IsInProcessHosted) { 56 } else { 68 }
$dashboardCardsHeight = if ($script:IsInProcessHosted) { 122 } else { 138 }
[void]$dashboardRoot.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, $dashboardIntroHeight)))
[void]$dashboardRoot.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, $dashboardCardsHeight)))
[void]$dashboardRoot.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 46)))
[void]$dashboardRoot.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 100)))''',
    'dashboard com navegação central'
)

nav_block = '''$dashboardNavigation = New-Object Windows.Forms.TableLayoutPanel
$dashboardNavigation.Dock = [Windows.Forms.DockStyle]::Fill
$dashboardNavigation.ColumnCount = 5
$dashboardNavigation.RowCount = 1
$dashboardNavigation.Margin = [Windows.Forms.Padding]::new(4, 3, 4, 3)
for ($i = 0; $i -lt 5; $i++) { [void]$dashboardNavigation.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 20))) }
$dashboardRoot.Controls.Add($dashboardNavigation, 0, 2)

function New-DashboardNavButton([string]$Text) {
    $button = New-Object Windows.Forms.Button
    $button.Text = $Text
    $button.Dock = [Windows.Forms.DockStyle]::Fill
    $button.Margin = [Windows.Forms.Padding]::new(3, 2, 3, 2)
    $button.Font = [Drawing.Font]::new("Segoe UI Semibold", 8.0)
    $button.Tag = "Secondary"
    return $button
}

$dashboardHistoryButton = New-DashboardNavButton "HISTÓRICO"
$dashboardStatsButton = New-DashboardNavButton "ESTATÍSTICAS"
$dashboardDiagnosisButton = New-DashboardNavButton "DIAGNÓSTICO"
$dashboardSchematicsButton = New-DashboardNavButton "ESQUEMÁTICOS"
$dashboardRulesButton = New-DashboardNavButton "REGRAS / DADOS"
$dashboardNavigation.Controls.Add($dashboardHistoryButton, 0, 0)
$dashboardNavigation.Controls.Add($dashboardStatsButton, 1, 0)
$dashboardNavigation.Controls.Add($dashboardDiagnosisButton, 2, 0)
$dashboardNavigation.Controls.Add($dashboardSchematicsButton, 3, 0)
$dashboardNavigation.Controls.Add($dashboardRulesButton, 4, 0)

'''
maint = replace_once(
    maint,
    '$recentGroup = New-Object Windows.Forms.GroupBox',
    nav_block + '$recentGroup = New-Object Windows.Forms.GroupBox',
    'botões centrais da Manutenção'
)
maint = replace_once(
    maint,
    '$dashboardRoot.Controls.Add($recentGroup, 0, 2)',
    '$dashboardRoot.Controls.Add($recentGroup, 0, 3)',
    'atividade recente abaixo da navegação'
)

# Ajuste da altura da nova faixa conforme o perfil responsivo.
maint = replace_once(
    maint,
    '''        $dashboardRoot.RowStyles[0].Height = $dashIntro
        $dashboardRoot.RowStyles[1].Height = $dashboardCardsH
        $dashboardRoot.AutoScroll = ($summaryColumns -eq 1)''',
    '''        $dashboardRoot.RowStyles[0].Height = $dashIntro
        $dashboardRoot.RowStyles[1].Height = $dashboardCardsH
        $dashboardRoot.RowStyles[2].Height = if ($profile -eq "Tight") { 38 } elseif ($profile -eq "Compact") { 42 } else { 46 }
        $dashboardRoot.AutoScroll = ($summaryColumns -eq 1)''',
    'altura responsiva da navegação central'
)

# Rodapé: em páginas internas aparece somente um retorno contextual à Visão geral.
maint = replace_once(
    maint,
    '''$footerLayout.ColumnCount = 2
[void]$footerLayout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 100)))
[void]$footerLayout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::AutoSize)))''',
    '''$footerLayout.ColumnCount = 3
[void]$footerLayout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 100)))
[void]$footerLayout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Absolute, 132)))
[void]$footerLayout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::AutoSize)))''',
    'rodapé com retorno à visão geral'
)
maint = replace_once(
    maint,
    '''$footerLayout.Controls.Add($statusLabel, 0, 0)
$footerVersion = New-Object Windows.Forms.Label''',
    '''$footerLayout.Controls.Add($statusLabel, 0, 0)
$footerHomeButton = New-Object Windows.Forms.Button
$footerHomeButton.Text = "← VISÃO GERAL"
$footerHomeButton.Dock = [Windows.Forms.DockStyle]::Fill
$footerHomeButton.Margin = [Windows.Forms.Padding]::new(4, 0, 4, 0)
$footerHomeButton.Font = [Drawing.Font]::new("Segoe UI Semibold", 8.0)
$footerHomeButton.Tag = "Secondary"
$footerHomeButton.Visible = $false
$footerLayout.Controls.Add($footerHomeButton, 1, 0)
$footerVersion = New-Object Windows.Forms.Label''',
    'botão contextual do rodapé'
)
maint = replace_once(
    maint,
    '$footerLayout.Controls.Add($footerVersion, 1, 0)',
    '$footerLayout.Controls.Add($footerVersion, 2, 0)',
    'posição da versão no rodapé'
)

# Histórico já filtra automaticamente por TextChanged/SelectedIndexChanged.
maint = replace_once(
    maint,
    '$historyFilterLayout.Controls.Add($historyFilterButton, 4, 0)',
    '''$historyFilterLayout.Controls.Add($historyFilterButton, 4, 0)
$historyFilterButton.Visible = $false
$historyFilterLayout.ColumnStyles[4].Width = 0
$historyFilterLayout.ColumnStyles[5].Width = 20''',
    'remove botão FILTRAR redundante'
)
maint = replace_once(maint, '$historyClearButton.Text = "LIMPAR"', '$historyClearButton.Text = "LIMPAR FILTROS"', 'clareza do limpar filtros')

# Esquemáticos também atualiza automaticamente ao digitar/mudar versão.
maint = replace_once(
    maint,
    '$schemaSearchLayout.Controls.Add($schemaSearchButton, 2, 0)',
    '''$schemaSearchLayout.Controls.Add($schemaSearchButton, 2, 0)
$schemaSearchButton.Visible = $false
$schemaSearchLayout.ColumnStyles[2].Width = 0''',
    'remove botão BUSCAR redundante'
)

# Eventos dos botões centrais e retorno contextual.
maint = replace_once(
    maint,
    '$dashboardNewButton.Add_Click({ Reset-PassageForm; $mainTabs.SelectedTab = $passageTab })',
    '''$dashboardNewButton.Add_Click({ Reset-PassageForm; $mainTabs.SelectedTab = $passageTab })
$dashboardHistoryButton.Add_Click({ $mainTabs.SelectedTab = $historyTab })
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
})''',
    'eventos da navegação central'
)

maint += '\n# UI_DEDUP_MAINTENANCE_V0113\n'
MAINT.write_text(maint, encoding='utf-8', newline='')

print('v0.11.3: duplicações visuais removidas e navegação da Manutenção centralizada.')
