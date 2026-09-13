from pathlib import Path

cp = Path('src/generated/Central de Trabalho.ps1')
gp = Path('src/generated/Modulos/Gerador-de-Planilhas-CB5-TV5/Gerador Planilhas.ps1')

c = cp.read_text(encoding='utf-8-sig')
g = gp.read_text(encoding='utf-8-sig')


def one(text, old, new, label):
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'UI FIT GENERATOR {label}: esperado 1, encontrado {count}')
    return text.replace(old, new, 1)

# A auditoria profunda pós-GERAL 2 revelou dois pontos reais na área Componentes:
# a linha dos três cartões não tinha RowStyle explícito e grids internos podiam
# conservar geometria de uma largura anterior após trocar/redimensionar abas.
c = one(c, '$script:GeneratorVersion = "3.7.16"', '$script:GeneratorVersion = "3.7.17"', 'versao Central')
g = one(g, '$script:AppVersion = "3.7.16"', '$script:AppVersion = "3.7.17"', 'versao modulo')

g = one(
    g,
    '''$componentMetricsLayout.RowCount = 1
$componentMetricsLayout.Padding = New-Object Windows.Forms.Padding(0)
[void]$componentMetricsLayout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 33.33)))''',
    '''$componentMetricsLayout.RowCount = 1
$componentMetricsLayout.Padding = New-Object Windows.Forms.Padding(0)
[void]$componentMetricsLayout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 100)))
$componentMetricsLayout.GrowStyle = [Windows.Forms.TableLayoutPanelGrowStyle]::FixedSize
[void]$componentMetricsLayout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 33.33)))''',
    'RowStyle dos cartões de Componentes'
)

old_width_block = '''        foreach ($control in @($componentsIntro, $componentMetricsLayout, $componentTabs)) {
            if ($null -ne $control) { $control.Width = $innerW }
        }

        $actionW ='''
new_width_block = '''        foreach ($control in @($componentsIntro, $componentMetricsLayout, $componentTabs)) {
            if ($null -ne $control) { $control.Width = $innerW }
        }

        # Pós-GERAL 2: não depender apenas de Anchor para as abas internas de
        # Componentes. A geometria é recalculada a partir da viewport atual.
        $componentMetricsLayout.Height = if ($profile -eq "Tight") { 52 } else { 58 }
        $componentTabs.Location = [Drawing.Point]::new(12, $(if ($profile -eq "Tight") { 148 } else { 156 }))
        $componentTabs.Size = [Drawing.Size]::new(
            $innerW,
            [Math]::Max(160, $ch - $(if ($profile -eq "Tight") { 158 } else { 166 }))
        )

        $componentPageW = [Math]::Max(300, [int]$componentBalancesPage.ClientSize.Width)
        $componentPageH = [Math]::Max(150, [int]$componentBalancesPage.ClientSize.Height)
        $componentGrid.Location = [Drawing.Point]::new(8, 48)
        $componentGrid.Size = [Drawing.Size]::new([Math]::Max(280, $componentPageW - 16), [Math]::Max(84, $componentPageH - 56))

        # Quatro ações da página Saldos dividem a largura disponível e não
        # continuam usando a geometria fixa criada para 982 px.
        $componentActionW = [Math]::Max(72, [int](($componentPageW - 28) / 4))
        $componentActionButtons = @($componentLaunchButton,$componentAdjustButton,$componentNewButton,$componentEditButton)
        for ($componentActionIndex = 0; $componentActionIndex -lt $componentActionButtons.Count; $componentActionIndex++) {
            $componentActionButton = $componentActionButtons[$componentActionIndex]
            if ($null -eq $componentActionButton) { continue }
            $componentActionButton.Location = [Drawing.Point]::new(8 + ($componentActionIndex * ($componentActionW + 4)), 7)
            $componentActionButton.Size = [Drawing.Size]::new($componentActionW, 34)
        }

        foreach ($componentGridSpec in @(
            @($componentMovementsPage, $componentHistoryGrid),
            @($componentOperationsPage, $componentOperationsGrid)
        )) {
            $componentPage = $componentGridSpec[0]
            $componentInnerGrid = $componentGridSpec[1]
            if ($null -eq $componentPage -or $null -eq $componentInnerGrid) { continue }
            $nestedW = [Math]::Max(300, [int]$componentPage.ClientSize.Width)
            $nestedH = [Math]::Max(120, [int]$componentPage.ClientSize.Height)
            $componentInnerGrid.Location = [Drawing.Point]::new(8, 8)
            $componentInnerGrid.Size = [Drawing.Size]::new([Math]::Max(280, $nestedW - 16), [Math]::Max(84, $nestedH - 16))
        }

        $actionW ='''
g = one(g, old_width_block, new_width_block, 'geometria interna de Componentes')

g += '\n# POS_GERAL2_GENERATOR_COMPONENTES_FIT_V03717\n'
c += '\n# POS_GERAL2_GENERATOR_FIT_V02157\n'

for marker in (
    '$script:GeneratorVersion = "3.7.17"',
    'POS_GERAL2_GENERATOR_FIT_V02157',
):
    if marker not in c:
        raise SystemExit('UI FIT GENERATOR Central marcador ausente: ' + marker)

for marker in (
    '$script:AppVersion = "3.7.17"',
    '$componentMetricsLayout.GrowStyle = [Windows.Forms.TableLayoutPanelGrowStyle]::FixedSize',
    '$componentActionW = [Math]::Max(72',
    'POS_GERAL2_GENERATOR_COMPONENTES_FIT_V03717',
):
    if marker not in g:
        raise SystemExit('UI FIT GENERATOR marcador ausente: ' + marker)

cp.write_text(c, encoding='utf-8')
gp.write_text(g, encoding='utf-8')
print('POS-GERAL 2 GENERATOR FIT: OK - cartões e grids de Componentes acompanham a viewport atual sem conservar geometria antiga.')
