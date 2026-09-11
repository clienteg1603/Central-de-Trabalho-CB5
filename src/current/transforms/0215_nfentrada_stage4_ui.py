from pathlib import Path

p=Path('src/generated/Modulos/Controle-NF-Entrada/Controle NF Entrada.ps1')
s=p.read_text(encoding='utf-8-sig')

def r(old,new,label):
    global s
    if old not in s: raise SystemExit('Etapa 4: trecho ausente: '+label)
    s=s.replace(old,new,1)

r('$script:ModuleVersion = "1.3.0"','$script:ModuleVersion = "1.4.0"','versao')
r('$computerTab.Text = "COMPUTADOR DE BORDO V5 ($([int]$summary.Produtos[$script:ComputerProduct].Registros))"','$computerTab.Text = "COMPUTADOR DE BORDO CB5 ($([int]$summary.Produtos[$script:ComputerProduct].Registros))"','aba dinamica')
r('[void]$productSummaryGrid.Rows.Add("Computador de bordo V5", [int]$summary.Produtos[$script:ComputerProduct].NFsAbertas, [int]$summary.Produtos[$script:ComputerProduct].Saldo)','[void]$productSummaryGrid.Rows.Add("Computador de bordo CB5", [int]$summary.Produtos[$script:ComputerProduct].NFsAbertas, [int]$summary.Produtos[$script:ComputerProduct].Saldo)','resumo')
r('$cards.Controls.Add((New-NFSummaryCard "COMPUTADOR DE BORDO V5" "saldo atual" ([ref]$computerBalanceValue)), 1, 0)','$cards.Controls.Add((New-NFSummaryCard "COMPUTADOR DE BORDO CB5" "saldo atual" ([ref]$computerBalanceValue)), 1, 0)','card')
r('$statusFilter.SelectedIndex = 0','$statusFilter.SelectedIndex = 1','status padrao')
old='''$summaryTab = New-Object Windows.Forms.TabPage
$summaryTab.Text = "RESUMO"
$summaryTab.BackColor = $script:CurrentPalette.Background
$mainTabs.TabPages.Add($summaryTab)
$computerTab = New-Object Windows.Forms.TabPage
$computerTab.Text = "COMPUTADOR DE BORDO V5"
$computerTab.BackColor = $script:CurrentPalette.Background
$mainTabs.TabPages.Add($computerTab)
$keyboardTab = New-Object Windows.Forms.TabPage
$keyboardTab.Text = "TECLADO V5"
$keyboardTab.BackColor = $script:CurrentPalette.Background
$mainTabs.TabPages.Add($keyboardTab)
$historyTab = New-Object Windows.Forms.TabPage
$historyTab.Text = "HISTÓRICO"
$historyTab.BackColor = $script:CurrentPalette.Background
$mainTabs.TabPages.Add($historyTab)
$securityTab = New-Object Windows.Forms.TabPage
$securityTab.Text = "SEGURANÇA"
$securityTab.BackColor = $script:CurrentPalette.Background
$mainTabs.TabPages.Add($securityTab)
'''
new='''$computerTab = New-Object Windows.Forms.TabPage
$computerTab.Text = "COMPUTADOR DE BORDO CB5"
$computerTab.BackColor = $script:CurrentPalette.Background
$mainTabs.TabPages.Add($computerTab)
$keyboardTab = New-Object Windows.Forms.TabPage
$keyboardTab.Text = "TECLADO V5"
$keyboardTab.BackColor = $script:CurrentPalette.Background
$mainTabs.TabPages.Add($keyboardTab)
$historyTab = New-Object Windows.Forms.TabPage
$historyTab.Text = "HISTÓRICO"
$historyTab.BackColor = $script:CurrentPalette.Background
$mainTabs.TabPages.Add($historyTab)
$securityTab = New-Object Windows.Forms.TabPage
$securityTab.Text = "SEGURANÇA"
$securityTab.BackColor = $script:CurrentPalette.Background
$mainTabs.TabPages.Add($securityTab)
$summaryTab = New-Object Windows.Forms.TabPage
$summaryTab.Text = "RESUMO"
$summaryTab.BackColor = $script:CurrentPalette.Background
$mainTabs.TabPages.Add($summaryTab)
$mainTabs.SelectedTab = $computerTab
'''
r(old,new,'ordem abas')
r('Set-NFStatus ("Pronto • " + $totalRecords + " registro(s) • base local protegida") "Normal"','Set-NFStatus ("Pronto • " + $totalRecords + " registro(s) • abas operacionais iniciam em Em estoque") "Normal"','rodape')
p.write_text(s,encoding='utf-8')
print('UI etapa 4 aplicada')
