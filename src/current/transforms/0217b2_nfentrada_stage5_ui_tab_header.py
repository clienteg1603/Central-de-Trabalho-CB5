from pathlib import Path
p=Path('src/generated/Modulos/Controle-NF-Entrada/Controle NF Entrada.ps1')
s=p.read_text(encoding='utf-8-sig')
old='''$keyboardTab = New-Object Windows.Forms.TabPage
$keyboardTab.Text = "TECLADO V5"
$keyboardTab.BackColor = $script:CurrentPalette.Background
$mainTabs.TabPages.Add($keyboardTab)
$historyTab = New-Object Windows.Forms.TabPage
'''
new='''$keyboardTab = New-Object Windows.Forms.TabPage
$keyboardTab.Text = "TECLADO V5"
$keyboardTab.BackColor = $script:CurrentPalette.Background
$mainTabs.TabPages.Add($keyboardTab)
$movementTab = New-Object Windows.Forms.TabPage
$movementTab.Text = "MOVIMENTAÇÕES"
$movementTab.BackColor = $script:CurrentPalette.Background
$mainTabs.TabPages.Add($movementTab)
$historyTab = New-Object Windows.Forms.TabPage
'''
if old not in s: raise SystemExit('Etapa 5: abas não encontradas')
s=s.replace(old,new,1)
s=s.replace('Add-NFGridColumn $codeSummaryGrid "Computador" "COMPUTADOR V5" 150','Add-NFGridColumn $codeSummaryGrid "Computador" "COMPUTADOR CB5" 150',1)
p.write_text(s,encoding='utf-8')
print('Etapa 5: aba Movimentações declarada')
