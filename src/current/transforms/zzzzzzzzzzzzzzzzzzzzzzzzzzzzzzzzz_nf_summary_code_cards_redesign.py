from pathlib import Path

cp=Path('src/generated/Central de Trabalho.ps1')
np=Path('src/generated/Modulos/Controle-NF-Entrada/Controle NF Entrada.ps1')
c=cp.read_text(encoding='utf-8-sig')
n=np.read_text(encoding='utf-8-sig')

def one(t,a,b,label):
    k=t.count(a)
    if k!=1: raise SystemExit(f'NF CARDS {label}: esperado 1, encontrado {k}')
    return t.replace(a,b,1)

c=one(c,'$script:AppVersion = "0.21.58"','$script:AppVersion = "0.21.59"','versao Central')
c=one(c,'$script:NFEntradaVersion = "2.6.22"','$script:NFEntradaVersion = "2.6.23"','versao NF Central')
n=one(n,'$script:ModuleVersion = "2.6.22"','$script:ModuleVersion = "2.6.23"','versao NF')

cards=r'''$codeSummaryGrid.Visible = $false
$script:NFCodeCardValues = @{}
function New-NFCodeSummaryCard {
    param([string]$Code)
    $p=New-Object Windows.Forms.Panel
    $p.Dock=[Windows.Forms.DockStyle]::Fill
    $p.Margin=[Windows.Forms.Padding]::new(4)
    $p.BackColor=$script:CurrentPalette.Card
    $p.ForeColor=$script:CurrentPalette.Text
    $p.Tag="Theme.Card"
    $p.BorderStyle=[Windows.Forms.BorderStyle]::FixedSingle
    $l=New-Object Windows.Forms.TableLayoutPanel
    $l.Dock=[Windows.Forms.DockStyle]::Fill
    $l.Margin=[Windows.Forms.Padding]::new(0)
    $l.Padding=[Windows.Forms.Padding]::new(10,5,10,5)
    $l.ColumnCount=3; $l.RowCount=2
    foreach($pct in @(34,33,33)){[void]$l.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent,$pct)))}
    [void]$l.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute,25)))
    [void]$l.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent,100)))
    $p.Controls.Add($l)
    $h=New-Object Windows.Forms.Label
    $h.Text=$Code; $h.Dock=[Windows.Forms.DockStyle]::Fill; $h.Margin=[Windows.Forms.Padding]::new(0)
    $h.Font=[Drawing.Font]::new("Segoe UI Semibold",11.5); $h.ForeColor=$script:CurrentPalette.Text
    $h.TextAlign=[Drawing.ContentAlignment]::MiddleLeft
    $l.Controls.Add($h,0,0); $l.SetColumnSpan($h,3)
    $cb=New-Object Windows.Forms.Label
    $cb.Text="CB5`r`n0"; $cb.Dock=[Windows.Forms.DockStyle]::Fill; $cb.Margin=[Windows.Forms.Padding]::new(0)
    $cb.Font=[Drawing.Font]::new("Segoe UI Semibold",8.5); $cb.ForeColor=$script:CurrentPalette.Text; $cb.TextAlign=[Drawing.ContentAlignment]::MiddleLeft
    $l.Controls.Add($cb,0,1)
    $tv=New-Object Windows.Forms.Label
    $tv.Text="TV5`r`n0"; $tv.Dock=[Windows.Forms.DockStyle]::Fill; $tv.Margin=[Windows.Forms.Padding]::new(0)
    $tv.Font=[Drawing.Font]::new("Segoe UI Semibold",8.5); $tv.ForeColor=$script:CurrentPalette.Text; $tv.TextAlign=[Drawing.ContentAlignment]::MiddleLeft
    $l.Controls.Add($tv,1,1)
    $tt=New-Object Windows.Forms.Label
    $tt.Text="TOTAL`r`n0"; $tt.Dock=[Windows.Forms.DockStyle]::Fill; $tt.Margin=[Windows.Forms.Padding]::new(0)
    $tt.Font=[Drawing.Font]::new("Segoe UI Semibold",8.5); $tt.ForeColor=$script:CurrentPalette.Text; $tt.TextAlign=[Drawing.ContentAlignment]::MiddleRight
    $l.Controls.Add($tt,2,1)
    $script:NFCodeCardValues[$Code]=[pscustomobject]@{Computador=$cb;Teclado=$tv;Total=$tt}
    return $p
}
$codeCardsLayout=New-Object Windows.Forms.TableLayoutPanel
$codeCardsLayout.Dock=[Windows.Forms.DockStyle]::Fill
$codeCardsLayout.Margin=[Windows.Forms.Padding]::new(0)
$codeCardsLayout.Padding=[Windows.Forms.Padding]::new(1)
$codeCardsLayout.ColumnCount=2; $codeCardsLayout.RowCount=2
[void]$codeCardsLayout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent,50)))
[void]$codeCardsLayout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent,50)))
[void]$codeCardsLayout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent,50)))
[void]$codeCardsLayout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent,50)))
$codeCardsLayout.Controls.Add((New-NFCodeSummaryCard "800"),0,0)
$codeCardsLayout.Controls.Add((New-NFCodeSummaryCard "100"),1,0)
$codeCardsLayout.Controls.Add((New-NFCodeSummaryCard "850"),0,1)
$codeCardsLayout.Controls.Add((New-NFCodeSummaryCard "Garantia"),1,1)
$codeGroup.Controls.Add($codeCardsLayout)'''
n=one(n,'$codeGroup.Controls.Add($codeSummaryGrid)',cards,'cards 2x2')

old=r'''    $codeSummaryGrid.Rows.Clear()
    foreach ($code in @("800", "100", "850", "Garantia")) {
        $item = $summary.Codigos[$code]
        [void]$codeSummaryGrid.Rows.Add($code, [int]$item.Computador, [int]$item.Teclado, [int]$item.Total)
    }
    [void]$codeSummaryGrid.Rows.Add("TOTAL", [int]$summary.Produtos[$script:ComputerProduct].Saldo, [int]$summary.Produtos[$script:KeyboardProduct].Saldo, [int]$summary.SaldoTotal)'''
new=r'''    $codeSummaryGrid.Rows.Clear()
    foreach ($code in @("800", "100", "850", "Garantia")) {
        $item = $summary.Codigos[$code]
        [void]$codeSummaryGrid.Rows.Add($code, [int]$item.Computador, [int]$item.Teclado, [int]$item.Total)
        $cv=$script:NFCodeCardValues[$code]
        if($null -ne $cv){
            $cv.Computador.Text="CB5`r`n"+([int]$item.Computador).ToString("N0")
            $cv.Teclado.Text="TV5`r`n"+([int]$item.Teclado).ToString("N0")
            $cv.Total.Text="TOTAL`r`n"+([int]$item.Total).ToString("N0")
        }
    }
    [void]$codeSummaryGrid.Rows.Add("TOTAL", [int]$summary.Produtos[$script:ComputerProduct].Saldo, [int]$summary.Produtos[$script:KeyboardProduct].Saldo, [int]$summary.SaldoTotal)'''
n=one(n,old,new,'refresh cards')

oldh=r'''        $summaryLayout.RowStyles[0].SizeType = [Windows.Forms.SizeType]::Percent
        $summaryLayout.RowStyles[1].SizeType = [Windows.Forms.SizeType]::Absolute
        $summaryLayout.RowStyles[2].SizeType = [Windows.Forms.SizeType]::Percent
        if ($profile -eq "Tight") {
            $summaryLayout.RowStyles[0].Height = 52; $summaryLayout.RowStyles[1].Height = 122; $summaryLayout.RowStyles[2].Height = 48
        } elseif ($profile -eq "Compact") {
            $summaryLayout.RowStyles[0].Height = 54; $summaryLayout.RowStyles[1].Height = 130; $summaryLayout.RowStyles[2].Height = 46
        } else {
            $summaryLayout.RowStyles[0].Height = 55; $summaryLayout.RowStyles[1].Height = 136; $summaryLayout.RowStyles[2].Height = 45
        }'''
newh=r'''        $summaryLayout.RowStyles[0].SizeType = [Windows.Forms.SizeType]::Percent
        $summaryLayout.RowStyles[1].SizeType = [Windows.Forms.SizeType]::Absolute
        $summaryLayout.RowStyles[2].SizeType = [Windows.Forms.SizeType]::Percent
        if ($profile -eq "Tight") {
            $summaryLayout.RowStyles[0].Height = 52; $summaryLayout.RowStyles[1].Height = 176; $summaryLayout.RowStyles[2].Height = 48
        } elseif ($profile -eq "Compact") {
            $summaryLayout.RowStyles[0].Height = 53; $summaryLayout.RowStyles[1].Height = 184; $summaryLayout.RowStyles[2].Height = 47
        } else {
            $summaryLayout.RowStyles[0].Height = 54; $summaryLayout.RowStyles[1].Height = 190; $summaryLayout.RowStyles[2].Height = 46
        }
        $codeGroup.Padding=if($profile -eq "Tight"){[Windows.Forms.Padding]::new(7,17,7,5)}elseif($profile -eq "Compact"){[Windows.Forms.Padding]::new(8,18,8,6)}else{[Windows.Forms.Padding]::new(9,19,9,7)}'''
n=one(n,oldh,newh,'altura cards')

c+='\n# NF_RESUMO_CODE_CARDS_V02159\n'
n+='\n# NF_RESUMO_CODE_CARDS_V02623\n'
for m in ('$script:AppVersion = "0.21.59"','$script:NFEntradaVersion = "2.6.23"','NF_RESUMO_CODE_CARDS_V02159'):
    if m not in c: raise SystemExit('Central marcador ausente: '+m)
for m in ('$script:ModuleVersion = "2.6.23"','function New-NFCodeSummaryCard','$codeCardsLayout.RowCount=2','New-NFCodeSummaryCard "Garantia"','NF_RESUMO_CODE_CARDS_V02623'):
    if m not in n: raise SystemExit('NF marcador ausente: '+m)
for bad in ('$mainTabs.Add_SizeChanged','$mainTabs.Add_HandleCreated','$mainTabs.DrawMode = [Windows.Forms.TabDrawMode]::OwnerDrawFixed','$mainTabs.ItemSize','Update-NFMainTabStripLayout'):
    if bad in n: raise SystemExit('mecanismo proibido: '+bad)
cp.write_text(c,encoding='utf-8')
np.write_text(n,encoding='utf-8')
print('NF RESUMO: OK - cards 800, 100, 850 e Garantia sempre visiveis.')
