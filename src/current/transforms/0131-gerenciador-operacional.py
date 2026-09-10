from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
GEN = ROOT / "generated" / "Modulos" / "Gerador-de-Planilhas-CB5-TV5" / "Gerador Planilhas.ps1"
CENTRAL = ROOT / "generated" / "Central de Trabalho.ps1"


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"[{label}] esperado 1 ocorrência, encontrado {count}")
    return text.replace(old, new, 1)


g = GEN.read_text(encoding="utf-8-sig")
c = CENTRAL.read_text(encoding="utf-8-sig")

# Versões.
g = replace_once(g, '$script:AppVersion = "3.6.0"', '$script:AppVersion = "3.6.1"', "versão gerenciador")
c = replace_once(c, '$script:AppVersion = "0.13.0"', '$script:AppVersion = "0.13.1"', "versão central")
c = replace_once(c, '$script:GeneratorVersion = "3.6.0"', '$script:GeneratorVersion = "3.6.1"', "versão módulo na central")

# -----------------------------------------------------------------------------
# MANUTENÇÕES: separa orientação, resumo e grade em três faixas legíveis.
# -----------------------------------------------------------------------------
g = replace_once(g,
'''$extraIntro.Location = New-Object Drawing.Point(18, 16)
$extraIntro.Size = New-Object Drawing.Size(982, 36)''',
'''$extraIntro.Location = New-Object Drawing.Point(18, 12)
$extraIntro.Size = New-Object Drawing.Size(982, 38)''',
"posição orientação manutenções")

g = replace_once(g,
'''$extraSelectionLabel.Location = New-Object Drawing.Point(18, 53)
$extraSelectionLabel.Size = New-Object Drawing.Size(982, 23)''',
'''$extraSelectionLabel.Location = New-Object Drawing.Point(18, 56)
$extraSelectionLabel.Size = New-Object Drawing.Size(982, 34)''',
"posição resumo manutenções")

g = replace_once(g,
'''$extraGrid.Location = New-Object Drawing.Point(18, 80)
$extraGrid.Size = New-Object Drawing.Size(982, 407)''',
'''$extraGrid.Location = New-Object Drawing.Point(18, 98)
$extraGrid.Size = New-Object Drawing.Size(982, 389)''',
"posição grade manutenções")

marker = '''$tabExtra.Controls.Add($extraSelectionLabel)

$extraGrid = New-Object Windows.Forms.DataGridView'''
insert = '''$tabExtra.Controls.Add($extraSelectionLabel)
$extraIntro.Font = New-Object Drawing.Font("Segoe UI Semibold", 9.2)
$extraIntro.Padding = New-Object Windows.Forms.Padding(12, 7, 12, 6)
$extraIntro.BorderStyle = [Windows.Forms.BorderStyle]::None
$extraSelectionLabel.Padding = New-Object Windows.Forms.Padding(12, 7, 12, 6)
$extraSelectionLabel.BorderStyle = [Windows.Forms.BorderStyle]::None
$extraIntro.Add_SizeChanged({ Set-GeneratorRoundedRegion $this 9 })
$extraSelectionLabel.Add_SizeChanged({ Set-GeneratorRoundedRegion $this 9 })
Set-GeneratorRoundedRegion $extraIntro 9
Set-GeneratorRoundedRegion $extraSelectionLabel 9

$extraGrid = New-Object Windows.Forms.DataGridView'''
g = replace_once(g, marker, insert, "estilo manutenções")

# -----------------------------------------------------------------------------
# COMPONENTES: transforma a explicação em uma faixa de contexto e compacta
# ações operacionais sem retirar nenhuma função.
# -----------------------------------------------------------------------------
g = replace_once(g,
'''$componentsIntro.Location = New-Object Drawing.Point(18, 12)
$componentsIntro.Size = New-Object Drawing.Size(982, 26)''',
'''$componentsIntro.Location = New-Object Drawing.Point(18, 10)
$componentsIntro.Size = New-Object Drawing.Size(982, 38)''',
"contexto componentes")

# Desloca o bloco abaixo apenas 10 px para dar respiro à faixa de contexto.
for old, new, label in [
    ('Drawing.Point(18, 42)\n$componentMetricsLayout.Size = New-Object Drawing.Size(982, 56)', 'Drawing.Point(18, 56)\n$componentMetricsLayout.Size = New-Object Drawing.Size(982, 58)', 'métricas componentes'),
    ('Drawing.Point(18, 111)', 'Drawing.Point(18, 125)', 'rótulo pesquisa componentes'),
    ('Drawing.Point(88, 106)', 'Drawing.Point(88, 120)', 'campo pesquisa componentes'),
    ('Drawing.Point(321, 104)', 'Drawing.Point(321, 118)', 'limpar pesquisa componentes'),
    ('Drawing.Point(409, 111)', 'Drawing.Point(409, 125)', 'resumo componentes'),
    ('Drawing.Point(690, 104)', 'Drawing.Point(690, 118)', 'backup componentes'),
    ('Drawing.Point(842, 104)', 'Drawing.Point(842, 118)', 'restaurar componentes'),
    ('Drawing.Point(18, 146)\n$componentTabs.Size = New-Object Drawing.Size(982, 341)', 'Drawing.Point(18, 160)\n$componentTabs.Size = New-Object Drawing.Size(982, 327)', 'abas componentes'),
]:
    g = replace_once(g, old, new, label)

marker = '''$tabComponents.Controls.Add($componentsIntro)

$componentMetricsLayout = New-Object Windows.Forms.TableLayoutPanel'''
insert = '''$tabComponents.Controls.Add($componentsIntro)
$componentsIntro.Font = New-Object Drawing.Font("Segoe UI Semibold", 9.1)
$componentsIntro.Padding = New-Object Windows.Forms.Padding(12, 7, 12, 6)
$componentsIntro.BorderStyle = [Windows.Forms.BorderStyle]::None
$componentsIntro.Add_SizeChanged({ Set-GeneratorRoundedRegion $this 9 })
Set-GeneratorRoundedRegion $componentsIntro 9

$componentMetricsLayout = New-Object Windows.Forms.TableLayoutPanel'''
g = replace_once(g, marker, insert, "estilo contexto componentes")

# Textos mais curtos e operacionais no cadastro de saldos.
g = g.replace('$componentLaunchButton.Text = "+  Lançar quantidade"', '$componentLaunchButton.Text = "+  Lançar uso"')
g = g.replace('$componentNewButton.Text = "+  Novo componente"', '$componentNewButton.Text = "+  Novo"')
g = g.replace('$componentEditButton.Text = "Editar componente"', '$componentEditButton.Text = "Editar"')
g = g.replace('$componentBackupButton.Text = "Exportar backup"', '$componentBackupButton.Text = "Backup"')
g = g.replace('$componentRestoreButton.Text = "Restaurar backup"', '$componentRestoreButton.Text = "Restaurar"')

# -----------------------------------------------------------------------------
# JUNTAR LOTES: destaca o estado de consumo de saldo e reduz poluição da barra.
# -----------------------------------------------------------------------------
g = replace_once(g, '$combineCopyQuantitiesButton.Text = "Copiar quantidades"', '$combineCopyQuantitiesButton.Text = "Copiar linha"', "copiar linha")
g = replace_once(g, '$combinePasteQuantitiesButton.Text = "Colar quantidades"', '$combinePasteQuantitiesButton.Text = "Colar linha"', "colar linha")

old_checkbox = '''$combineConsumeBalanceCheck = New-Object Windows.Forms.CheckBox
$combineConsumeBalanceCheck.Text = "Consumir saldo de componentes a faturar"
$combineConsumeBalanceCheck.Checked = $true
$combineConsumeBalanceCheck.Location = New-Object Drawing.Point(18, 120)
$combineConsumeBalanceCheck.Size = New-Object Drawing.Size(420, 24)
$combineConsumeBalanceCheck.Font = New-Object Drawing.Font("Segoe UI Semibold", 9.5)
$combineConsumeBalanceCheck.Anchor = "Top,Left"
$tabCombine.Controls.Add($combineConsumeBalanceCheck)
$toolTip.SetToolTip($combineConsumeBalanceCheck, "Marcado: valida os reparos, consulta e baixa o saldo após a união. Desmarcado: não consulta o saldo e permite textos de REPARO não cadastrados, preservando-os na planilha unida.")'''
new_checkbox = '''$combineBalanceCard = New-Object Windows.Forms.Panel
$combineBalanceCard.Location = New-Object Drawing.Point(18, 118)
$combineBalanceCard.Size = New-Object Drawing.Size(982, 40)
$combineBalanceCard.Anchor = "Top,Left,Right"
$combineBalanceCard.BorderStyle = [Windows.Forms.BorderStyle]::None
$tabCombine.Controls.Add($combineBalanceCard)

$combineConsumeBalanceCheck = New-Object Windows.Forms.CheckBox
$combineConsumeBalanceCheck.Text = "Consumir saldo ao concluir a união"
$combineConsumeBalanceCheck.Checked = $true
$combineConsumeBalanceCheck.Location = New-Object Drawing.Point(12, 8)
$combineConsumeBalanceCheck.Size = New-Object Drawing.Size(420, 24)
$combineConsumeBalanceCheck.Font = New-Object Drawing.Font("Segoe UI Semibold", 9.5)
$combineConsumeBalanceCheck.Anchor = "Top,Left"
$combineBalanceCard.Controls.Add($combineConsumeBalanceCheck)
$toolTip.SetToolTip($combineConsumeBalanceCheck, "Marcado: valida os reparos, consulta e baixa o saldo após a união. Desmarcado: não consulta o saldo e permite textos de REPARO não cadastrados, preservando-os na planilha unida.")

$combineBalanceStatus = New-Object Windows.Forms.Label
$combineBalanceStatus.Text = "SALDO: SERÁ CONSUMIDO"
$combineBalanceStatus.Font = New-Object Drawing.Font("Segoe UI Semibold", 9.2)
$combineBalanceStatus.Location = New-Object Drawing.Point(650, 8)
$combineBalanceStatus.Size = New-Object Drawing.Size(316, 24)
$combineBalanceStatus.Anchor = "Top,Right"
$combineBalanceStatus.TextAlign = [Drawing.ContentAlignment]::MiddleRight
$combineBalanceCard.Controls.Add($combineBalanceStatus)
$combineBalanceCard.Add_SizeChanged({ Set-GeneratorRoundedRegion $this 9 })
Set-GeneratorRoundedRegion $combineBalanceCard 9'''
g = replace_once(g, old_checkbox, new_checkbox, "cartão consumo saldo")

g = replace_once(g,
'''$combineGrid.Location = New-Object Drawing.Point(18, 149)
$combineGrid.Size = New-Object Drawing.Size(982, 210)''',
'''$combineGrid.Location = New-Object Drawing.Point(18, 166)
$combineGrid.Size = New-Object Drawing.Size(982, 193)''',
"grade juntar lotes")

# Atualiza texto e sinal visual sempre que a opção de saldo mudar.
old_summary = '''    $balanceText = if ($combineConsumeBalanceCheck.Checked) { "consumir saldo" } else { "não consumir saldo" }
    $combineSelectionLabel.Text = "$($combineGrid.Rows.Count) lote(s) selecionado(s)  •  $withMaintenance mestre(s) serão atualizadas  •  $balanceText$invalidText"
    if ($null -ne $script:CurrentPalette) {
        $combineSelectionLabel.ForeColor = if ($invalidFields -gt 0) { $script:CurrentPalette.Error } else { $script:CurrentPalette.Text }
        Update-CombineGridHighlights
    }'''
new_summary = '''    $balanceText = if ($combineConsumeBalanceCheck.Checked) { "consumir saldo" } else { "não consumir saldo" }
    $combineSelectionLabel.Text = "$($combineGrid.Rows.Count) lote(s) selecionado(s)  •  $withMaintenance mestre(s) serão atualizadas  •  $balanceText$invalidText"
    $combineBalanceStatus.Text = if ($combineConsumeBalanceCheck.Checked) { "SALDO: SERÁ CONSUMIDO" } else { "SALDO: NÃO SERÁ CONSUMIDO" }
    if ($null -ne $script:CurrentPalette) {
        $combineSelectionLabel.ForeColor = if ($invalidFields -gt 0) { $script:CurrentPalette.Error } else { $script:CurrentPalette.Text }
        $combineBalanceStatus.ForeColor = if ($combineConsumeBalanceCheck.Checked) { $script:CurrentPalette.Warning } else { $script:CurrentPalette.Success }
        $combineBalanceCard.BackColor = $script:CurrentPalette.Surface
        Update-CombineGridHighlights
    }'''
g = replace_once(g, old_summary, new_summary, "resumo saldo juntar lotes")

# Tema dos novos blocos.
g = replace_once(g,
'''    foreach ($panel in @($masterCard, $summaryCard, $destinationCard, $componentActiveCard, $componentPendingCard, $componentOperationsCard)) {''',
'''    foreach ($panel in @($masterCard, $summaryCard, $destinationCard, $componentActiveCard, $componentPendingCard, $componentOperationsCard, $combineBalanceCard)) {''',
"painéis no tema")

g = replace_once(g,
'''    $infoBox.BackColor = $palette.Info
    $infoBox.ForeColor = $palette.Text''',
'''    $infoBox.BackColor = $palette.Info
    $infoBox.ForeColor = $palette.Text
    $extraIntro.BackColor = $palette.Info
    $extraIntro.ForeColor = $palette.Text
    $extraSelectionLabel.BackColor = $palette.Surface
    $extraSelectionLabel.ForeColor = $palette.Text
    $componentsIntro.BackColor = $palette.Info
    $componentsIntro.ForeColor = $palette.Text
    $combineBalanceCard.BackColor = $palette.Surface''',
"cores blocos operacionais")

g = replace_once(g,
'''foreach ($roundedPanel in @($masterCard, $destinationCard, $summaryCard, $componentActiveCard, $componentPendingCard, $componentOperationsCard)) {''',
'''foreach ($roundedPanel in @($masterCard, $destinationCard, $summaryCard, $componentActiveCard, $componentPendingCard, $componentOperationsCard, $combineBalanceCard)) {''',
"arredondamento cartão saldo")

# Tooltips mais claros para ações compactadas.
marker = '''$componentBalancesPage.Controls.Add($componentLaunchButton)'''
g = replace_once(g, marker, marker + '\n$toolTip.SetToolTip($componentLaunchButton, "Acrescenta ao saldo a faturar a quantidade usada do componente selecionado.")', "tooltip lançar uso")
marker = '''$componentBalancesPage.Controls.Add($componentAdjustButton)'''
g = replace_once(g, marker, marker + '\n$toolTip.SetToolTip($componentAdjustButton, "Define manualmente o saldo exato do componente selecionado.")', "tooltip ajustar saldo")

# Grava preservando BOM para Windows PowerShell.
GEN.write_text(g, encoding="utf-8-sig")
CENTRAL.write_text(c, encoding="utf-8-sig")
print("v0.13.1 / Gerenciador 3.6.1 aplicado")
