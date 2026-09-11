from pathlib import Path
p=Path('src/generated/Modulos/Controle-NF-Entrada/Controle NF Entrada.ps1')
s=p.read_text(encoding='utf-8-sig')
def rep(a,b,label):
    global s
    if a not in s: raise SystemExit('ui2 ausente: '+label)
    s=s.replace(a,b,1)
old='''$editButton = New-Object Windows.Forms.Button
$editButton.Text = "EDITAR SELEÇÃO"; $editButton.Width = 125; $editButton.Height = 34; Set-NFButtonStyle $editButton "Secondary"
$deleteButton = New-Object Windows.Forms.Button
$deleteButton.Text = "EXCLUIR"; $deleteButton.Width = 95; $deleteButton.Height = 34; Set-NFButtonStyle $deleteButton "Danger"
$actionPanel.Controls.Add($newButton); $actionPanel.Controls.Add($editButton); $actionPanel.Controls.Add($deleteButton)
'''
new='''$editButton = New-Object Windows.Forms.Button
$editButton.Text = "EDITAR SELEÇÃO"; $editButton.Width = 125; $editButton.Height = 34; Set-NFButtonStyle $editButton "Secondary"
$outputButton = New-Object Windows.Forms.Button
$outputButton.Text = "REGISTRAR SAÍDA"; $outputButton.Width = 135; $outputButton.Height = 34; Set-NFButtonStyle $outputButton "Secondary"
$deleteButton = New-Object Windows.Forms.Button
$deleteButton.Text = "EXCLUIR"; $deleteButton.Width = 95; $deleteButton.Height = 34; Set-NFButtonStyle $deleteButton "Danger"
$actionPanel.Controls.Add($newButton); $actionPanel.Controls.Add($editButton); $actionPanel.Controls.Add($outputButton); $actionPanel.Controls.Add($deleteButton)
'''
rep(old,new,'botoes')
rep('''    $editButton.Enabled = $hasSelection
    $deleteButton.Enabled = $hasSelection
}
''','''    $editButton.Enabled = $hasSelection
    $deleteButton.Enabled = $hasSelection
    $canOutput = $false
    if ($hasSelection) {
        $id = Get-SelectedRecordId $grid
        $selected = Find-NFRecordById -Product $product -Id $id
        $canOutput = ($null -ne $selected -and [int]$selected.QuantidadeSaldo -gt 0)
    }
    $outputButton.Enabled = $canOutput
}
''','habilitacao')
rep('$editButton.Add_Click({ Edit-NFRecordFromUI })','$editButton.Add_Click({ Edit-NFRecordFromUI })\n$outputButton.Add_Click({ Register-NFOutputFromUI })','evento botao')
rep('$computerGrid.Add_CellDoubleClick({ if ($_.RowIndex -ge 0) { Edit-NFRecordFromUI } })','$computerGrid.Add_CellDoubleClick({ if ($_.RowIndex -ge 0) { Edit-NFRecordFromUI } })\n$computerGrid.Add_KeyDown({ if ($_.Control -and $_.KeyCode -eq [Windows.Forms.Keys]::N) { $_.SuppressKeyPress=$true; Add-NFRecordFromUI } elseif ($_.KeyCode -eq [Windows.Forms.Keys]::Enter) { $_.SuppressKeyPress=$true; Edit-NFRecordFromUI } elseif ($_.Control -and $_.KeyCode -eq [Windows.Forms.Keys]::F) { $_.SuppressKeyPress=$true; $computerFilter.Focus() } })','atalhos cb5')
rep('$keyboardGrid.Add_CellDoubleClick({ if ($_.RowIndex -ge 0) { Edit-NFRecordFromUI } })','$keyboardGrid.Add_CellDoubleClick({ if ($_.RowIndex -ge 0) { Edit-NFRecordFromUI } })\n$keyboardGrid.Add_KeyDown({ if ($_.Control -and $_.KeyCode -eq [Windows.Forms.Keys]::N) { $_.SuppressKeyPress=$true; Add-NFRecordFromUI } elseif ($_.KeyCode -eq [Windows.Forms.Keys]::Enter) { $_.SuppressKeyPress=$true; Edit-NFRecordFromUI } elseif ($_.Control -and $_.KeyCode -eq [Windows.Forms.Keys]::F) { $_.SuppressKeyPress=$true; $keyboardFilter.Focus() } })','atalhos teclado')
p.write_text(s,encoding='utf-8')
print('ui2 etapa 4 aplicado')
