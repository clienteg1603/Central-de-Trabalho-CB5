from pathlib import Path

cp = Path('src/generated/Central de Trabalho.ps1')
np = Path('src/generated/Modulos/Controle-NF-Entrada/Controle NF Entrada.ps1')
c = cp.read_text(encoding='utf-8-sig')
n = np.read_text(encoding='utf-8-sig')

def one(text, old, new, label):
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: esperado 1, encontrado {count}')
    return text.replace(old, new, 1)

c = one(c, '$script:AppVersion = "0.21.57"', '$script:AppVersion = "0.21.58"', 'versao Central')
c = one(c, '$script:NFEntradaVersion = "2.6.21"', '$script:NFEntradaVersion = "2.6.22"', 'versao NF Central')
n = one(n, '$script:ModuleVersion = "2.6.21"', '$script:ModuleVersion = "2.6.22"', 'versao NF')

n = one(n,
'''        if ($profile -eq "Tight") {
            $summaryLayout.RowStyles[0].Height = 38; $summaryLayout.RowStyles[1].Height = 25; $summaryLayout.RowStyles[2].Height = 37
        } elseif ($profile -eq "Compact") {
            $summaryLayout.RowStyles[0].Height = 38; $summaryLayout.RowStyles[1].Height = 28; $summaryLayout.RowStyles[2].Height = 34
        } else {
            $summaryLayout.RowStyles[0].Height = 38; $summaryLayout.RowStyles[1].Height = 30; $summaryLayout.RowStyles[2].Height = 32
        }''',
'''        $summaryLayout.RowStyles[0].SizeType = [Windows.Forms.SizeType]::Percent
        $summaryLayout.RowStyles[1].SizeType = [Windows.Forms.SizeType]::Absolute
        $summaryLayout.RowStyles[2].SizeType = [Windows.Forms.SizeType]::Percent
        if ($profile -eq "Tight") {
            $summaryLayout.RowStyles[0].Height = 52; $summaryLayout.RowStyles[1].Height = 122; $summaryLayout.RowStyles[2].Height = 48
        } elseif ($profile -eq "Compact") {
            $summaryLayout.RowStyles[0].Height = 54; $summaryLayout.RowStyles[1].Height = 130; $summaryLayout.RowStyles[2].Height = 46
        } else {
            $summaryLayout.RowStyles[0].Height = 55; $summaryLayout.RowStyles[1].Height = 136; $summaryLayout.RowStyles[2].Height = 45
        }''', 'altura Saldo por codigo')

n = one(n,
'''Add-NFGridColumn $codeSummaryGrid "Codigo" "CÓDIGO" 110
Add-NFGridColumn $codeSummaryGrid "Computador" "COMPUTADOR CB5" 150
Add-NFGridColumn $codeSummaryGrid "Teclado" "TECLADO V5" 150
Add-NFGridColumn $codeSummaryGrid "Total" "TOTAL" 130 $true''',
'''Add-NFGridColumn $codeSummaryGrid "Codigo" "CÓDIGO" 110
Add-NFGridColumn $codeSummaryGrid "Computador" "COMPUTADOR CB5" 150
Add-NFGridColumn $codeSummaryGrid "Teclado" "TECLADO V5" 150
Add-NFGridColumn $codeSummaryGrid "Total" "TOTAL" 130
foreach ($columnName in @("Codigo","Computador","Teclado","Total")) { $codeSummaryGrid.Columns[$columnName].AutoSizeMode = [Windows.Forms.DataGridViewAutoSizeColumnMode]::Fill }
$codeSummaryGrid.Columns["Codigo"].FillWeight = 15
$codeSummaryGrid.Columns["Computador"].FillWeight = 35
$codeSummaryGrid.Columns["Teclado"].FillWeight = 30
$codeSummaryGrid.Columns["Total"].FillWeight = 20''', 'colunas Saldo por codigo')

c += '\n# NF_CODE_SUMMARY_FIX_V02158\n'
n += '\n# NF_CODE_SUMMARY_FIX_V02622\n'
cp.write_text(c, encoding='utf-8')
np.write_text(n, encoding='utf-8')
print('NF Saldo por codigo: OK')
