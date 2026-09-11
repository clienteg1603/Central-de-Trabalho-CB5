from pathlib import Path
p=Path('src/generated/Modulos/Controle-NF-Entrada/Controle NF Entrada.ps1')
s=p.read_text(encoding='utf-8-sig')
if '$script:ModuleVersion = "1.5.0"' not in s: raise SystemExit('Etapa 5 UI: versão não encontrada')
s=s.replace('$script:ModuleVersion = "1.5.0"','$script:ModuleVersion = "1.6.0"',1)
anchor='''function Format-NFHistoryDate {
    param([string]$Text)
    $date = [DateTime]::MinValue
    if ([DateTime]::TryParse($Text, [ref]$date)) { return $date.ToString("dd/MM/yyyy HH:mm:ss") }
    return $Text
}
'''
extra='''
function Refresh-NFMovements {
    if ($null -eq $movementGrid) { return }
    $filter = if ($null -ne $movementFilter) { ([string]$movementFilter.Text).Trim().ToLowerInvariant() } else { "" }
    $productFilter = if ($null -ne $movementProductFilter -and $movementProductFilter.SelectedIndex -gt 0) { [string]$movementProductFilter.SelectedItem } else { "Todos" }
    $items = @(Get-NFEntradaMovements -Store $script:Store)
    $movementGrid.Rows.Clear()
    $shown = 0
    $qtyShown = 0
    foreach ($item in $items) {
        $displayProduct = Get-NFEntradaProductDisplayName ([string]$item.Produto)
        if ($productFilter -ne "Todos" -and $displayProduct -ne $productFilter) { continue }
        $search = (($displayProduct + " " + [string]$item.NFEntrada + " " + [string]$item.Referencia)).ToLowerInvariant()
        if (-not [string]::IsNullOrWhiteSpace($filter) -and -not $search.Contains($filter)) { continue }
        [void]$movementGrid.Rows.Add(
            [string]$item.Id,
            [string]$item.Produto,
            (Format-NFHistoryDate ([string]$item.DataHora)),
            $displayProduct,
            [string]$item.NFEntrada,
            [int]$item.Quantidade,
            [int]$item.SaldoAntes,
            [int]$item.SaldoDepois,
            [string]$item.Referencia
        )
        $shown++
        $qtyShown += [int]$item.Quantidade
    }
    $movementCountLabel.Text = "$shown de $($items.Count) movimentação(ões) • $qtyShown peça(s) na seleção"
    $movementGrid.ClearSelection()
    $movementOpenButton.Enabled = $false
}

function Open-NFFromMovement {
    if ($movementGrid.SelectedRows.Count -eq 0) { return }
    $row = $movementGrid.SelectedRows[0]
    $product = [string]$row.Cells["MovementProductKey"].Value
    $nf = [string]$row.Cells["MovementNF"].Value
    if ($product -eq $script:ComputerProduct) {
        $computerStatusFilter.SelectedIndex = 0
        $computerFilter.Text = $nf
        $mainTabs.SelectedTab = $computerTab
        $computerFilter.Focus()
    }
    elseif ($product -eq $script:KeyboardProduct) {
        $keyboardStatusFilter.SelectedIndex = 0
        $keyboardFilter.Text = $nf
        $mainTabs.SelectedTab = $keyboardTab
        $keyboardFilter.Focus()
    }
}
'''
if anchor not in s: raise SystemExit('Etapa 5 UI: âncora de data não encontrada')
s=s.replace(anchor,anchor+extra,1)
old='''    if ($mainTabs.SelectedTab -eq $historyTab) { Refresh-NFHistory }
    if ($mainTabs.SelectedTab -eq $securityTab) { Refresh-NFBackups }
'''
new='''    if ($mainTabs.SelectedTab -eq $movementTab) { Refresh-NFMovements }
    if ($mainTabs.SelectedTab -eq $historyTab) { Refresh-NFHistory }
    if ($mainTabs.SelectedTab -eq $securityTab) { Refresh-NFBackups }
'''
if old not in s: raise SystemExit('Etapa 5 UI: refresh não encontrado')
s=s.replace(old,new,1)
p.write_text(s,encoding='utf-8')
print('Etapa 5 UI: funções de movimentações aplicadas')
