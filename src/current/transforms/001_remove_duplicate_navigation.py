from pathlib import Path

path = Path('src/generated/Modulos/Central-de-Manutencao-CB5/Central Manutencao CB5.ps1')
text = path.read_text(encoding='utf-8-sig')

def replace_once(old, new, label):
    global text
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: esperado 1 ocorrência, encontrado {count}')
    text = text.replace(old, new, 1)

replace_once('$script:AppVersion = "0.5.1"', '$script:AppVersion = "0.5.2"', 'versao interna')

replace_once(
'''$dashboardRoot.RowCount = 4
$dashboardRoot.ColumnCount = 1
$dashboardIntroHeight = if ($script:IsInProcessHosted) { 56 } else { 68 }
$dashboardCardsHeight = if ($script:IsInProcessHosted) { 122 } else { 138 }
[void]$dashboardRoot.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, $dashboardIntroHeight)))
[void]$dashboardRoot.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, $dashboardCardsHeight)))
[void]$dashboardRoot.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 46)))
[void]$dashboardRoot.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 100)))''',
'''$dashboardRoot.RowCount = 3
$dashboardRoot.ColumnCount = 1
$dashboardIntroHeight = if ($script:IsInProcessHosted) { 56 } else { 68 }
$dashboardCardsHeight = if ($script:IsInProcessHosted) { 122 } else { 138 }
[void]$dashboardRoot.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, $dashboardIntroHeight)))
[void]$dashboardRoot.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, $dashboardCardsHeight)))
[void]$dashboardRoot.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 100)))''',
'dashboard 3 linhas'
)

quick = '''$dashboardQuickActions = New-Object Windows.Forms.TableLayoutPanel
$dashboardQuickActions.Dock = [Windows.Forms.DockStyle]::Fill
$dashboardQuickActions.ColumnCount = 3
$dashboardQuickActions.RowCount = 1
$dashboardQuickActions.Margin = [Windows.Forms.Padding]::new(4, 3, 4, 3)
for ($i = 0; $i -lt 3; $i++) { [void]$dashboardQuickActions.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 33.333))) }
$dashboardRoot.Controls.Add($dashboardQuickActions, 0, 2)

$dashboardHistoryButton = New-Object Windows.Forms.Button
$dashboardHistoryButton.Text = "HISTÓRICO"
$dashboardHistoryButton.Dock = [Windows.Forms.DockStyle]::Fill
$dashboardHistoryButton.Margin = [Windows.Forms.Padding]::new(0, 2, 4, 2)
$dashboardHistoryButton.Tag = "Primary"
$dashboardQuickActions.Controls.Add($dashboardHistoryButton, 0, 0)

$dashboardDiagnosisButton = New-Object Windows.Forms.Button
$dashboardDiagnosisButton.Text = "APOIO AO DIAGNÓSTICO"
$dashboardDiagnosisButton.Dock = [Windows.Forms.DockStyle]::Fill
$dashboardDiagnosisButton.Margin = [Windows.Forms.Padding]::new(4, 2, 4, 2)
$dashboardDiagnosisButton.Tag = "Secondary"
$dashboardQuickActions.Controls.Add($dashboardDiagnosisButton, 1, 0)

$dashboardSchematicsButton = New-Object Windows.Forms.Button
$dashboardSchematicsButton.Text = "ESQUEMÁTICOS"
$dashboardSchematicsButton.Dock = [Windows.Forms.DockStyle]::Fill
$dashboardSchematicsButton.Margin = [Windows.Forms.Padding]::new(4, 2, 0, 2)
$dashboardSchematicsButton.Tag = "Secondary"
$dashboardQuickActions.Controls.Add($dashboardSchematicsButton, 2, 0)

'''
replace_once(quick, '', 'atalhos duplicados')
replace_once('$dashboardRoot.Controls.Add($recentGroup, 0, 3)', '$dashboardRoot.Controls.Add($recentGroup, 0, 2)', 'atividade recente')
replace_once('        $dashboardRoot.RowStyles[2].Height = if ($profile -eq "Tight") { 38 } elseif ($profile -eq "Compact") { 42 } else { 46 }\n', '', 'altura atalhos')
replace_once('''$dashboardHistoryButton.Add_Click({ $mainTabs.SelectedTab = $historyTab })
$dashboardDiagnosisButton.Add_Click({ $mainTabs.SelectedTab = $diagnosisTab })
$dashboardSchematicsButton.Add_Click({ $mainTabs.SelectedTab = $schematicsTab })
''', '', 'eventos atalhos')
replace_once('# VISUAL_BLOCK_2_V0111', '# UI_DEDUP_V0112', 'marcador')

path.write_text(text, encoding='utf-8', newline='')
print('Navegação duplicada removida da Central de Manutenção CB5.')
