from pathlib import Path

cp = Path('src/generated/Central de Trabalho.ps1')
mp = Path('src/generated/Modulos/Central-de-Manutencao-CB5/Central Manutencao CB5.ps1')

c = cp.read_text(encoding='utf-8-sig')
m = mp.read_text(encoding='utf-8-sig')


def one(text, old, new, label):
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'UI FIT MAINT {label}: esperado 1, encontrado {count}')
    return text.replace(old, new, 1)

# A varredura visual encontrou um padrão equivalente ao da Conferência do NF:
# cada SummaryCard possuía um TableLayout de uma linha sem RowStyle explícito.
# Em 1366x768 isso podia deixar os filhos com 100 px dentro de uma célula menor.
c = one(c, '$script:MaintenanceVersion = "0.6.13"', '$script:MaintenanceVersion = "0.6.14"', 'versao Central')
m = one(m, '$script:AppVersion = "0.6.13"', '$script:AppVersion = "0.6.14"', 'versao modulo')

m = one(
    m,
    '''    $frame.ColumnCount = 2
    $frame.RowCount = 1
    [void]$frame.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Absolute, 5)))''',
    '''    $frame.ColumnCount = 2
    $frame.RowCount = 1
    [void]$frame.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 100)))
    $frame.GrowStyle = [Windows.Forms.TableLayoutPanelGrowStyle]::FixedSize
    [void]$frame.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Absolute, 5)))''',
    'RowStyle dos SummaryCards'
)

# Quando os cards ficam no resumo persistente da Central, a altura disponível é
# intencionalmente compacta. Quatro colunas funcionam melhor já a partir de 760 px:
# evita transformar ~90 px de altura em duas linhas de ~40 px cada.
m = one(
    m,
    '$summaryColumns = if ($m.LogicalWidth -lt 720) { 1 } elseif ($m.LogicalWidth -lt 1380) { 2 } else { 4 }',
    '$summaryColumns = if ($m.LogicalWidth -lt 560) { 1 } elseif ($m.LogicalWidth -lt 760) { 2 } else { 4 }',
    'limiares dos cards de resumo'
)

# Densidade dos cartões hospedados: com uma única linha há espaço suficiente para
# valor + legenda, sem cortar texto em notebook nem desperdiçar altura em Full HD.
old_responsive_anchor = '''        Set-DashboardSummaryLayout -Columns $summaryColumns
        $summaryRows = [int][Math]::Ceiling(4.0 / $summaryColumns)'''
new_responsive_anchor = '''        Set-DashboardSummaryLayout -Columns $summaryColumns
        if ($script:IsInProcessHosted -and $summaryColumns -eq 4) {
            foreach ($decoration in @($script:SummaryCardDecorations)) {
                if ($null -eq $decoration) { continue }
                try {
                    $decoration.Value.Font = [Drawing.Font]::new("Segoe UI Semibold", $(if ($profile -eq "Tight") { 16.5 } elseif ($profile -eq "Compact") { 18.0 } else { 20.0 }))
                    $decoration.Label.Font = [Drawing.Font]::new("Segoe UI Semibold", $(if ($profile -eq "Tight") { 7.5 } elseif ($profile -eq "Compact") { 8.0 } else { 8.6 }))
                    $decoration.Label.AutoEllipsis = $true
                    $contentTable = $decoration.Value.Parent
                    if ($null -ne $contentTable -and $contentTable -is [Windows.Forms.TableLayoutPanel]) {
                        $contentTable.Padding = if ($profile -eq "Tight") { [Windows.Forms.Padding]::new(9,5,7,4) } elseif ($profile -eq "Compact") { [Windows.Forms.Padding]::new(10,6,8,5) } else { [Windows.Forms.Padding]::new(12,7,9,6) }
                    }
                } catch {}
            }
        }
        $summaryRows = [int][Math]::Ceiling(4.0 / $summaryColumns)'''
m = one(m, old_responsive_anchor, new_responsive_anchor, 'densidade dos SummaryCards')

c += '\n# POS_GERAL2_MAINTENANCE_FIT_V02157\n'
m += '\n# POS_GERAL2_MAINTENANCE_SUMMARY_FIT_V00614\n'

for marker in ('$script:MaintenanceVersion = "0.6.14"', 'POS_GERAL2_MAINTENANCE_FIT_V02157'):
    if marker not in c:
        raise SystemExit('UI FIT MAINT Central marcador ausente: ' + marker)
for marker in ('$script:AppVersion = "0.6.14"', '$frame.GrowStyle = [Windows.Forms.TableLayoutPanelGrowStyle]::FixedSize', '$m.LogicalWidth -lt 760', 'POS_GERAL2_MAINTENANCE_SUMMARY_FIT_V00614'):
    if marker not in m:
        raise SystemExit('UI FIT MAINT marcador ausente: ' + marker)

cp.write_text(c, encoding='utf-8')
mp.write_text(m, encoding='utf-8')
print('POS-GERAL 2 MAINT FIT: OK - SummaryCards têm linha explícita e permanecem em uma linha nos viewports usuais da Central.')
