from pathlib import Path
p=Path('src/generated/Modulos/Controle-NF-Entrada/Controle NF Entrada.ps1')
s=p.read_text(encoding='utf-8-sig')
old='$mainTabs.Add_SelectedIndexChanged({ Update-NFActions; if ($mainTabs.SelectedTab -eq $historyTab) { Refresh-NFHistory }; if ($mainTabs.SelectedTab -eq $securityTab) { Refresh-NFBackups } })'
new='$mainTabs.Add_SelectedIndexChanged({ Update-NFActions; if ($mainTabs.SelectedTab -eq $movementTab) { Refresh-NFMovements }; if ($mainTabs.SelectedTab -eq $historyTab) { Refresh-NFHistory }; if ($mainTabs.SelectedTab -eq $securityTab) { Refresh-NFBackups } })'
if old not in s: raise SystemExit('Etapa 5: evento das abas não encontrado')
s=s.replace(old,new,1)
anchor='$historyFilter.Add_TextChanged({ Refresh-NFHistory })\n'
block='''$movementFilter.Add_TextChanged({ Refresh-NFMovements })
$movementProductFilter.Add_SelectedIndexChanged({ Refresh-NFMovements })
$movementGrid.Add_SelectionChanged({ $movementOpenButton.Enabled = ($movementGrid.SelectedRows.Count -gt 0) })
$movementGrid.Add_CellDoubleClick({ if ($_.RowIndex -ge 0) { Open-NFFromMovement } })
$movementOpenButton.Add_Click({ Open-NFFromMovement })
'''
if anchor not in s: raise SystemExit('Etapa 5: evento do histórico não encontrado')
s=s.replace(anchor,block+anchor,1)
p.write_text(s,encoding='utf-8')
print('Etapa 5: eventos de movimentações conectados')
