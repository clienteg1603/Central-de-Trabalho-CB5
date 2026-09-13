from pathlib import Path

cp = Path('src/generated/Central de Trabalho.ps1')
np = Path('src/generated/Modulos/Controle-NF-Entrada/Controle NF Entrada.ps1')

c = cp.read_text(encoding='utf-8-sig')
n = np.read_text(encoding='utf-8-sig')


def one(text, old, new, label):
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'UI FIT {label}: esperado 1, encontrado {count}')
    return text.replace(old, new, 1)


# Publicação seguinte à GERAL 2. O problema apareceu em uso real com a janela
# maximizada: a Conferência automática possuía seis linhas, mas não possuía seis
# RowStyles explícitos. Em alguns DPI/alturas o TableLayout calculava linhas mais
# altas que o GroupBox e as últimas informações eram recortadas.
c = one(c, '$script:AppVersion = "0.21.56"', '$script:AppVersion = "0.21.57"', 'versao Central')
c = one(c, '$script:NFEntradaVersion = "2.6.19"', '$script:NFEntradaVersion = "2.6.20"', 'versao NF Central')
n = one(n, '$script:ModuleVersion = "2.6.19"', '$script:ModuleVersion = "2.6.20"', 'versao NF modulo')

n = one(
    n,
    '''$conference.RowCount = 6
[void]$conference.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 70)))
[void]$conference.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 30)))
$conferenceGroup.Controls.Add($conference)''',
    '''$conference.RowCount = 6
[void]$conference.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 70)))
[void]$conference.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 30)))
for ($conferenceRow = 0; $conferenceRow -lt 6; $conferenceRow++) {
    [void]$conference.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 16.6667)))
}
$conference.GrowStyle = [Windows.Forms.TableLayoutPanelGrowStyle]::FixedSize
$conferenceGroup.Controls.Add($conference)''',
    'seis linhas explicitas da conferencia'
)

# O Resumo tinha três faixas percentuais, mas o primeiro bloco continha seis
# indicadores e recebia apenas 30-34% da altura. Redistribuímos a área: as duas
# grades têm poucas linhas e cedem espaço para Conferência/Atividade sem criar
# rolagem desnecessária.
n = one(
    n,
    '''        if ($profile -eq "Tight") {
            $summaryLayout.RowStyles[0].Height = 30; $summaryLayout.RowStyles[1].Height = 32; $summaryLayout.RowStyles[2].Height = 38
        } elseif ($profile -eq "Compact") {
            $summaryLayout.RowStyles[0].Height = 32; $summaryLayout.RowStyles[1].Height = 35; $summaryLayout.RowStyles[2].Height = 33
        } else {
            $summaryLayout.RowStyles[0].Height = 34; $summaryLayout.RowStyles[1].Height = 38; $summaryLayout.RowStyles[2].Height = 28
        }
        Set-NFActivityResponsive -TwoRows:($profile -eq "Tight")''',
    '''        if ($profile -eq "Tight") {
            $summaryLayout.RowStyles[0].Height = 38; $summaryLayout.RowStyles[1].Height = 25; $summaryLayout.RowStyles[2].Height = 37
        } elseif ($profile -eq "Compact") {
            $summaryLayout.RowStyles[0].Height = 38; $summaryLayout.RowStyles[1].Height = 28; $summaryLayout.RowStyles[2].Height = 34
        } else {
            $summaryLayout.RowStyles[0].Height = 38; $summaryLayout.RowStyles[1].Height = 30; $summaryLayout.RowStyles[2].Height = 32
        }

        # Conferência automática: padding e tipografia acompanham a densidade.
        # Isso evita que DPI alto transforme as seis linhas em uma área maior que
        # o GroupBox mesmo quando a janela está maximizada.
        $conferenceGroup.Padding = if ($profile -eq "Tight") {
            [Windows.Forms.Padding]::new(8, 17, 8, 5)
        } elseif ($profile -eq "Compact") {
            [Windows.Forms.Padding]::new(10, 19, 10, 6)
        } else {
            [Windows.Forms.Padding]::new(12, 21, 12, 8)
        }
        $conferenceLabelFont = if ($profile -eq "Tight") { 7.7 } elseif ($profile -eq "Compact") { 8.3 } else { 9.0 }
        $conferenceValueFont = if ($profile -eq "Tight") { 8.4 } elseif ($profile -eq "Compact") { 9.1 } else { 10.0 }
        for ($conferenceRow = 0; $conferenceRow -lt 6; $conferenceRow++) {
            $conferenceLabel = $conference.GetControlFromPosition(0, $conferenceRow)
            $conferenceValue = $conference.GetControlFromPosition(1, $conferenceRow)
            if ($null -ne $conferenceLabel) {
                $conferenceLabel.Margin = [Windows.Forms.Padding]::new(0)
                $conferenceLabel.AutoEllipsis = $true
                $conferenceLabel.Font = [Drawing.Font]::new("Segoe UI", $conferenceLabelFont)
            }
            if ($null -ne $conferenceValue) {
                $conferenceValue.Margin = [Windows.Forms.Padding]::new(0)
                $conferenceValue.AutoEllipsis = $true
                $conferenceValue.Font = [Drawing.Font]::new("Segoe UI Semibold", $conferenceValueFont)
            }
        }

        Set-NFActivityResponsive -TwoRows:($profile -eq "Tight")''',
    'redistribuicao e densidade do Resumo'
)

# Mantém as duas grades-resumo fechadas sem scrollbar, mas garante que o espaço
# reduzido ainda acomode cabeçalho + linhas reais.
n = one(
    n,
    '''                $grid.ColumnHeadersHeight = if ($profile -eq "Tight") { 22 } elseif ($profile -eq "Compact") { 24 } else { 26 }
                $grid.RowTemplate.Height = if ($profile -eq "Tight") { 19 } elseif ($profile -eq "Compact") { 20 } else { 21 }''',
    '''                $grid.ColumnHeadersHeight = if ($profile -eq "Tight") { 21 } elseif ($profile -eq "Compact") { 23 } else { 25 }
                $grid.RowTemplate.Height = if ($profile -eq "Tight") { 18 } elseif ($profile -eq "Compact") { 19 } else { 20 }''',
    'densidade das grades do Resumo'
)

c += '\n# POS_GERAL2_UI_FIT_V02157\n'
n += '\n# POS_GERAL2_NF_CONFERENCIA_FIT_V02620\n'

for marker in (
    '$script:AppVersion = "0.21.57"',
    '$script:NFEntradaVersion = "2.6.20"',
    'POS_GERAL2_UI_FIT_V02157',
):
    if marker not in c:
        raise SystemExit('UI FIT Central marcador ausente: ' + marker)

for marker in (
    '$script:ModuleVersion = "2.6.20"',
    '$conference.GrowStyle = [Windows.Forms.TableLayoutPanelGrowStyle]::FixedSize',
    '$summaryLayout.RowStyles[0].Height = 38',
    '$conferenceLabel.AutoEllipsis = $true',
    'POS_GERAL2_NF_CONFERENCIA_FIT_V02620',
):
    if marker not in n:
        raise SystemExit('UI FIT NF marcador ausente: ' + marker)

for forbidden in (
    '$mainTabs.Add_SizeChanged',
    '$mainTabs.Add_HandleCreated',
    '$mainTabs.DrawMode = [Windows.Forms.TabDrawMode]::OwnerDrawFixed',
    '$mainTabs.ItemSize',
    'Update-NFMainTabStripLayout',
):
    if forbidden in n:
        raise SystemExit('UI FIT NF mecanismo proibido reapareceu: ' + forbidden)

cp.write_text(c, encoding='utf-8')
np.write_text(n, encoding='utf-8')
print('POS-GERAL 2 UI FIT: OK - Conferencia automatica com seis linhas fixas, Resumo redistribuido e densidade protegida em DPI/resize.')
