from pathlib import Path
p=Path('src/generated/Modulos/Controle-NF-Entrada/Controle NF Entrada.ps1')
s=p.read_text(encoding='utf-8-sig')
anchor='# HISTÓRICO — consulta auditável das alterações do módulo.\n'
if anchor not in s: raise SystemExit('Etapa 5: histórico não encontrado')
block='''# MOVIMENTAÇÕES
$movementLayout = New-Object Windows.Forms.TableLayoutPanel
$movementLayout.Dock = [Windows.Forms.DockStyle]::Fill
$movementLayout.Padding = [Windows.Forms.Padding]::new(10)
$movementLayout.RowCount = 3
[void]$movementLayout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 52)))
[void]$movementLayout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 100)))
[void]$movementLayout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 42)))
$movementTab.Controls.Add($movementLayout)
$movementFilters = New-Object Windows.Forms.TableLayoutPanel
$movementFilters.Dock = [Windows.Forms.DockStyle]::Fill
$movementFilters.ColumnCount = 4
[void]$movementFilters.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Absolute, 74)))
[void]$movementFilters.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 100)))
[void]$movementFilters.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Absolute, 62)))
[void]$movementFilters.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Absolute, 210)))
$movementLayout.Controls.Add($movementFilters,0,0)
$movementSearchLabel=New-Object Windows.Forms.Label
$movementSearchLabel.Text="Pesquisar"; $movementSearchLabel.Dock=[Windows.Forms.DockStyle]::Fill; $movementSearchLabel.TextAlign=[Drawing.ContentAlignment]::MiddleLeft; $movementSearchLabel.ForeColor=$script:CurrentPalette.Muted
$movementFilters.Controls.Add($movementSearchLabel,0,0)
$movementFilter=New-Object Windows.Forms.TextBox
$movementFilter.Dock=[Windows.Forms.DockStyle]::Fill; $movementFilter.Margin=[Windows.Forms.Padding]::new(0,9,12,9); $movementFilter.BackColor=$script:CurrentPalette.Input; $movementFilter.ForeColor=$script:CurrentPalette.Text
$movementFilters.Controls.Add($movementFilter,1,0)
$movementProductLabel=New-Object Windows.Forms.Label
$movementProductLabel.Text="Produto"; $movementProductLabel.Dock=[Windows.Forms.DockStyle]::Fill; $movementProductLabel.TextAlign=[Drawing.ContentAlignment]::MiddleLeft; $movementProductLabel.ForeColor=$script:CurrentPalette.Muted
$movementFilters.Controls.Add($movementProductLabel,2,0)
$movementProductFilter=New-Object Windows.Forms.ComboBox
$movementProductFilter.DropDownStyle=[Windows.Forms.ComboBoxStyle]::DropDownList
[void]$movementProductFilter.Items.AddRange(@("Todos","COMPUTADOR DE BORDO CB5","TECLADO V5"))
$movementProductFilter.SelectedIndex=0; $movementProductFilter.Dock=[Windows.Forms.DockStyle]::Fill; $movementProductFilter.Margin=[Windows.Forms.Padding]::new(0,8,8,8); $movementProductFilter.BackColor=$script:CurrentPalette.Input; $movementProductFilter.ForeColor=$script:CurrentPalette.Text
$movementFilters.Controls.Add($movementProductFilter,3,0)

# MOVEMENT_GRID_ANCHOR
'''
s=s.replace(anchor,block+anchor,1)
p.write_text(s,encoding='utf-8')
print('Etapa 5: filtros de movimentações aplicados')
