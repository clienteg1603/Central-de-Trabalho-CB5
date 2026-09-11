from pathlib import Path
p=Path('src/generated/Modulos/Controle-NF-Entrada/Controle NF Entrada.ps1')
s=p.read_text(encoding='utf-8-sig')
anchor='# MOVEMENT_GRID_ANCHOR\n'
if anchor not in s: raise SystemExit('Etapa 5: âncora da grade não encontrada')
block='''$movementGrid=New-NFGrid
$movementIdCol=New-Object Windows.Forms.DataGridViewTextBoxColumn
$movementIdCol.Name="MovementId"; $movementIdCol.Visible=$false; [void]$movementGrid.Columns.Add($movementIdCol)
$movementProductKeyCol=New-Object Windows.Forms.DataGridViewTextBoxColumn
$movementProductKeyCol.Name="MovementProductKey"; $movementProductKeyCol.Visible=$false; [void]$movementGrid.Columns.Add($movementProductKeyCol)
Add-NFGridColumn $movementGrid "MovementDate" "DATA / HORA" 145
Add-NFGridColumn $movementGrid "MovementProduct" "PRODUTO" 190
Add-NFGridColumn $movementGrid "MovementNF" "NF DE ENTRADA" 110
Add-NFGridColumn $movementGrid "MovementQty" "SAÍDA" 75
Add-NFGridColumn $movementGrid "MovementBefore" "SALDO ANTES" 95
Add-NFGridColumn $movementGrid "MovementAfter" "SALDO DEPOIS" 100
Add-NFGridColumn $movementGrid "MovementReference" "NF DE SAÍDA / REFERÊNCIA" 240 $true
$movementLayout.Controls.Add($movementGrid,0,1)
$movementFooter=New-Object Windows.Forms.TableLayoutPanel
$movementFooter.Dock=[Windows.Forms.DockStyle]::Fill; $movementFooter.ColumnCount=2
[void]$movementFooter.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent,100)))
[void]$movementFooter.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::AutoSize)))
$movementCountLabel=New-Object Windows.Forms.Label
$movementCountLabel.Text="0 movimentação(ões)"; $movementCountLabel.Dock=[Windows.Forms.DockStyle]::Fill; $movementCountLabel.TextAlign=[Drawing.ContentAlignment]::MiddleLeft; $movementCountLabel.ForeColor=$script:CurrentPalette.Muted
$movementFooter.Controls.Add($movementCountLabel,0,0)
$movementOpenButton=New-Object Windows.Forms.Button
$movementOpenButton.Text="ABRIR NF"; $movementOpenButton.Width=110; $movementOpenButton.Height=32; $movementOpenButton.Enabled=$false; Set-NFButtonStyle $movementOpenButton "Secondary"
$movementFooter.Controls.Add($movementOpenButton,1,0)
$movementLayout.Controls.Add($movementFooter,0,2)
'''
s=s.replace(anchor,block,1)
p.write_text(s,encoding='utf-8')
print('Etapa 5: grade de movimentações aplicada')
