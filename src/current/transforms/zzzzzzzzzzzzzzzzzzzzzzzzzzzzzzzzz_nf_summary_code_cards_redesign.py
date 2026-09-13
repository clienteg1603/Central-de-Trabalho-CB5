from pathlib import Path
import re

cp = Path('src/generated/Central de Trabalho.ps1')
np = Path('src/generated/Modulos/Controle-NF-Entrada/Controle NF Entrada.ps1')

c = cp.read_text(encoding='utf-8-sig')
n = np.read_text(encoding='utf-8-sig')


def one(text, old, new, label):
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'NF CODE CARDS {label}: esperado 1, encontrado {count}')
    return text.replace(old, new, 1)


# Versões — somente canal Teste.
c = one(c, '$script:AppVersion = "0.21.58"', '$script:AppVersion = "0.21.59"', 'versao Central')
c = one(c, '$script:NFEntradaVersion = "2.6.22"', '$script:NFEntradaVersion = "2.6.23"', 'versao NF Central')
n = one(n, '$script:ModuleVersion = "2.6.22"', '$script:ModuleVersion = "2.6.23"', 'versao NF modulo')

# O DataGridView continua existindo apenas como compatibilidade interna para os
# contratos antigos e para não reabrir caminhos já estabilizados do módulo.
# Visualmente, Saldo por código deixa de ser uma grade: passa a ser quatro cards
# fixos em 2x2. Assim 800, 100, 850 e Garantia estão sempre presentes e nenhum
# deles depende de altura de linha, scrollbar ou cálculo de DataGridView.
old_add = '$codeGroup.Controls.Add($codeSummaryGrid)'
new_add = r'''$codeSummaryGrid.Visible = $false
$script:NFCodeCardValues = @{}

function New-NFCodeSummaryCard {
    param([string]$Code)

    $panel = New-Object Windows.Forms.Panel
    $panel.Dock = [Windows.Forms.DockStyle]::Fill
    $panel.Margin = [Windows.Forms.Padding]::new(4)
    $panel.Padding = [Windows.Forms.Padding]::new(0)
    $panel.BackColor = $script:CurrentPalette.Card
    $panel.ForeColor = $script:CurrentPalette.Text
    $panel.Tag = "Theme.Card"
    $panel.BorderStyle = [Windows.Forms.BorderStyle]::FixedSingle

    $layout = New-Object Windows.Forms.TableLayoutPanel
    $layout.Dock = [Windows.Forms.DockStyle]::Fill
    $layout.Margin = [Windows.Forms.Padding]::new(0)
    $layout.Padding = [Windows.Forms.Padding]::new(10, 5, 10, 5)
    $layout.ColumnCount = 3
    $layout.RowCount = 2
    foreach ($pct in @(34, 33, 33)) {
        [void]$layout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, $pct)))
    }
    [void]$layout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 25)))
    [void]$layout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 100)))
    $panel.Controls.Add($layout)

    $codeLabel = New-Object Windows.Forms.Label
    $codeLabel.Text = $Code
    $codeLabel.Dock = [Windows.Forms.DockStyle]::Fill
    $codeLabel.Margin = [Windows.Forms.Padding]::new(0)
    $codeLabel.Font = [Drawing.Font]::new("Segoe UI Semibold", 11.5)
    $codeLabel.ForeColor = $script:CurrentPalette.Accent
    $codeLabel.Tag = "Theme.Accent"
    $codeLabel.TextAlign = [Drawing.ContentAlignment]::MiddleLeft
    $layout.Controls.Add($codeLabel, 0, 0)
    $layout.SetColumnSpan($codeLabel, 3)

    $cb = New-Object Windows.Forms.Label
    $cb.Text = "CB5`r`n0"
    $cb.Dock = [Windows.Forms.DockStyle]::Fill
    $cb.Margin = [Windows.Forms.Padding]::new(0)
    $cb.Font = [Drawing.Font]::new("Segoe UI Semibold", 8.5)
    $cb.ForeColor = $script:CurrentPalette.Text
    $cb.TextAlign = [Drawing.ContentAlignment]::MiddleLeft
    $layout.Controls.Add($cb, 0, 1)

    $tv = New-Object Windows.Forms.Label
    $tv.Text = "TV5`r`n0"
    $tv.Dock = [Windows.Forms.DockStyle]::Fill
    $tv.Margin = [Windows.Forms.Padding]::new(0)
    $tv.Font = [Drawing.Font]::new("Segoe UI Semibold", 8.5)
    $tv.ForeColor = $script:CurrentPalette.Text
    $tv.TextAlign = [Drawing.ContentAlignment]::MiddleLeft
    $layout.Controls.Add($tv, 1, 1)

    $total = New-Object Windows.Forms.Label
    $total.Text = "TOTAL`r`n0"
    $total.Dock = [Windows.Forms.DockStyle]::Fill
    $total.Margin = [Windows.Forms.Padding]::new(0)
    $total.Font = [Drawing.Font]::new("Segoe UI Semibold", 8.5)
    $total.ForeColor = $script:CurrentPalette.Text
    $total.TextAlign = [Drawing.ContentAlignment]::MiddleRight
    $layout.Controls.Add($total, 2, 1)

    $script:NFCodeCardValues[$Code] = [pscustomobject]@{
        Computador = $cb
        Teclado = $tv
        Total = $total
    }
    return $panel
}

$codeCardsLayout = New-Object Windows.Forms.TableLayoutPanel
$codeCardsLayout.Dock = [Windows.Forms.DockStyle]::Fill
$codeCardsLayout.Margin = [Windows.Forms.Padding]::new(0)
$codeCardsLayout.Padding = [Windows.Forms.Padding]::new(1)
$codeCardsLayout.ColumnCount = 2
$codeCardsLayout.RowCount = 2
[void]$codeCardsLayout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 50)))
[void]$codeCardsLayout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 50)))
[void]$codeCardsLayout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 50)))
[void]$codeCardsLayout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 50)))
$codeCardsLayout.Controls.Add((New-NFCodeSummaryCard "800"), 0, 0)
$codeCardsLayout.Controls.Add((New-NFCodeSummaryCard "100"), 1, 0)
$codeCardsLayout.Controls.Add((New-NFCodeSummaryCard "850"), 0, 1)
$codeCardsLayout.Controls.Add((New-NFCodeSummaryCard "Garantia"), 1, 1)
$codeGroup.Controls.Add($codeCardsLayout)'''
n = one(n, old_add, new_add, 'troca visual da grade por cards')

# Atualiza os quatro cards a partir da mesma fonte usada pela grade interna.
old_refresh = r'''    $codeSummaryGrid.Rows.Clear()
    foreach ($code in @("800", "100", "850", "Garantia")) {
        $item = $summary.Codigos[$code]
        [void]$codeSummaryGrid.Rows.Add($code, [int]$item.Computador, [int]$item.Teclado, [int]$item.Total)
    }
    [void]$codeSummaryGrid.Rows.Add("TOTAL", [int]$summary.Produtos[$script:ComputerProduct].Saldo, [int]$summary.Produtos[$script:KeyboardProduct].Saldo, [int]$summary.SaldoTotal)'''
new_refresh = r'''    $codeSummaryGrid.Rows.Clear()
    foreach ($code in @("800", "100", "850", "Garantia")) {
        $item = $summary.Codigos[$code]
        [void]$codeSummaryGrid.Rows.Add($code, [int]$item.Computador, [int]$item.Teclado, [int]$item.Total)
        $cardValues = $script:NFCodeCardValues[$code]
        if ($null -ne $cardValues) {
            $cardValues.Computador.Text = "CB5`r`n" + ([int]$item.Computador).ToString("N0")
            $cardValues.Teclado.Text = "TV5`r`n" + ([int]$item.Teclado).ToString("N0")
            $cardValues.Total.Text = "TOTAL`r`n" + ([int]$item.Total).ToString("N0")
        }
    }
    [void]$codeSummaryGrid.Rows.Add("TOTAL", [int]$summary.Produtos[$script:ComputerProduct].Saldo, [int]$summary.Produtos[$script:KeyboardProduct].Saldo, [int]$summary.SaldoTotal)'''
n = one(n, old_refresh, new_refresh, 'atualizacao dos cards')

# A faixa central agora contém dois andares de cards. Ela recebe uma altura
# conhecida e suficiente; o restante é distribuído entre a conferência e a
# atividade operacional. Isso elimina o ciclo de cortar uma linha e aumentar a
# grade novamente a cada resolução/DPI.
old_heights = r'''        $summaryLayout.RowStyles[0].SizeType = [Windows.Forms.SizeType]::Percent
        $summaryLayout.RowStyles[1].SizeType = [Windows.Forms.SizeType]::Absolute
        $summaryLayout.RowStyles[2].SizeType = [Windows.Forms.SizeType]::Percent
        if ($profile -eq "Tight") {
            $summaryLayout.RowStyles[0].Height = 52; $summaryLayout.RowStyles[1].Height = 122; $summaryLayout.RowStyles[2].Height = 48
        } elseif ($profile -eq "Compact") {
            $summaryLayout.RowStyles[0].Height = 54; $summaryLayout.RowStyles[1].Height = 130; $summaryLayout.RowStyles[2].Height = 46
        } else {
            $summaryLayout.RowStyles[0].Height = 55; $summaryLayout.RowStyles[1].Height = 136; $summaryLayout.RowStyles[2].Height = 45
        }'''
new_heights = r'''        $summaryLayout.RowStyles[0].SizeType = [Windows.Forms.SizeType]::Percent
        $summaryLayout.RowStyles[1].SizeType = [Windows.Forms.SizeType]::Absolute
        $summaryLayout.RowStyles[2].SizeType = [Windows.Forms.SizeType]::Percent
        if ($profile -eq "Tight") {
            $summaryLayout.RowStyles[0].Height = 52; $summaryLayout.RowStyles[1].Height = 176; $summaryLayout.RowStyles[2].Height = 48
        } elseif ($profile -eq "Compact") {
            $summaryLayout.RowStyles[0].Height = 53; $summaryLayout.RowStyles[1].Height = 184; $summaryLayout.RowStyles[2].Height = 47
        } else {
            $summaryLayout.RowStyles[0].Height = 54; $summaryLayout.RowStyles[1].Height = 190; $summaryLayout.RowStyles[2].Height = 46
        }
        $codeGroup.Padding = if ($profile -eq "Tight") {
            [Windows.Forms.Padding]::new(7, 17, 7, 5)
        } elseif ($profile -eq "Compact") {
            [Windows.Forms.Padding]::new(8, 18, 8, 6)
        } else {
            [Windows.Forms.Padding]::new(9, 19, 9, 7)
        }'''
n = one(n, old_heights, new_heights, 'altura fixa dos cards de codigo')

# Permite que o título de cada código preserve o ciano do tema caso a árvore seja
# reaplicada pelo host.
old_theme_label = r'''    elseif ($Control -is [Windows.Forms.Label]) {
        $Control.ForeColor = if ([string]$Control.Tag -eq "Theme.Muted") { $palette.Muted } else { $palette.Text }
    }'''
new_theme_label = r'''    elseif ($Control -is [Windows.Forms.Label]) {
        $labelRole = [string]$Control.Tag
        if ($labelRole -eq "Theme.Muted") { $Control.ForeColor = $palette.Muted }
        elseif ($labelRole -eq "Theme.Accent") { $Control.ForeColor = $palette.Accent }
        else { $Control.ForeColor = $palette.Text }
    }'''
n = one(n, old_theme_label, new_theme_label, 'papel Accent dos labels')

c += '\n# NF_RESUMO_CODE_CARDS_V02159\n'
n += '\n# NF_RESUMO_CODE_CARDS_V02623\n'

for marker in (
    '$script:AppVersion = "0.21.59"',
    '$script:NFEntradaVersion = "2.6.23"',
    'NF_RESUMO_CODE_CARDS_V02159',
):
    if marker not in c:
        raise SystemExit('NF CODE CARDS Central marcador ausente: ' + marker)

for marker in (
    '$script:ModuleVersion = "2.6.23"',
    'function New-NFCodeSummaryCard',
    '$codeCardsLayout.RowCount = 2',
    'New-NFCodeSummaryCard "Garantia"',
    '$cardValues.Total.Text = "TOTAL`r`n"',
    'NF_RESUMO_CODE_CARDS_V02623',
):
    if marker not in n:
        raise SystemExit('NF CODE CARDS marcador ausente: ' + marker)

for forbidden in (
    '$mainTabs.Add_SizeChanged',
    '$mainTabs.Add_HandleCreated',
    '$mainTabs.DrawMode = [Windows.Forms.TabDrawMode]::OwnerDrawFixed',
    '$mainTabs.ItemSize',
    'Update-NFMainTabStripLayout',
):
    if forbidden in n:
        raise SystemExit('NF CODE CARDS mecanismo proibido reapareceu: ' + forbidden)

cp.write_text(c, encoding='utf-8')
np.write_text(n, encoding='utf-8')
print('NF RESUMO: OK - Saldo por codigo repaginado em quatro cards fixos 2x2; Garantia sempre visivel.')
