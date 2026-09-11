from pathlib import Path
p=Path('src/generated/Modulos/Controle-NF-Entrada/Controle NF Entrada.ps1')
s=p.read_text(encoding='utf-8-sig')
def rep(a,b,label):
    global s
    if a not in s: raise SystemExit('ui1 ausente: '+label)
    s=s.replace(a,b,1)
rep('$script:ModuleVersion = "1.4.0"','$script:ModuleVersion = "1.5.0"','versao')
rep('"RestauracaoBackup" { "Restauração" }','"RestauracaoBackup" { "Restauração" }\n            "Saida" { "Saída" }','historico saida')
rep('[void]$historyTypeFilter.Items.AddRange(@("Todos", "Adição", "Edição", "Exclusão", "Importação", "Restauração"))','[void]$historyTypeFilter.Items.AddRange(@("Todos", "Adição", "Edição", "Saída", "Exclusão", "Importação", "Restauração"))','filtro saida')
anchor='function Remove-NFRecordFromUI {\n'
if anchor not in s: raise SystemExit('ui1 anchor saida ausente')
fn=r'''function Register-NFOutputFromUI {
    $product = Get-SelectedProduct
    if ([string]::IsNullOrWhiteSpace($product)) { return }
    $grid = if ($product -eq $script:ComputerProduct) { $computerGrid } else { $keyboardGrid }
    $id = Get-SelectedRecordId $grid
    if ($id -le 0) { [Windows.Forms.MessageBox]::Show("Selecione uma NF em estoque para registrar a saída.", "Controle de NF de Entrada", 0, 64) | Out-Null; return }
    $record = Find-NFRecordById -Product $product -Id $id
    if ($null -eq $record) { return }
    $saldoAtual = [int]$record.QuantidadeSaldo
    if ($saldoAtual -le 0) { [Windows.Forms.MessageBox]::Show("A NF selecionada já está encerrada.", "Controle de NF de Entrada", 0, 64) | Out-Null; return }

    $dialog = New-Object Windows.Forms.Form
    $dialog.Text = "Registrar saída — NF $($record.NFEntrada)"
    $dialog.StartPosition = [Windows.Forms.FormStartPosition]::CenterParent
    $dialog.FormBorderStyle = [Windows.Forms.FormBorderStyle]::FixedDialog
    $dialog.MaximizeBox = $false; $dialog.MinimizeBox = $false; $dialog.ShowInTaskbar = $false
    $dialog.ClientSize = [Drawing.Size]::new(570, 300)
    $dialog.BackColor = $script:CurrentPalette.Background; $dialog.ForeColor = $script:CurrentPalette.Text
    $layout = New-Object Windows.Forms.TableLayoutPanel
    $layout.Dock = [Windows.Forms.DockStyle]::Fill; $layout.Padding = [Windows.Forms.Padding]::new(18); $layout.ColumnCount = 2; $layout.RowCount = 5
    [void]$layout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Absolute, 190)))
    [void]$layout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 100)))
    foreach($h in @(46,46,46,62,50)){ [void]$layout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute,$h))) }
    $dialog.Controls.Add($layout)
    function Add-OutputLabel([string]$text,[int]$row){ $l=New-Object Windows.Forms.Label; $l.Text=$text; $l.Dock=[Windows.Forms.DockStyle]::Fill; $l.TextAlign=[Drawing.ContentAlignment]::MiddleLeft; $l.ForeColor=$script:CurrentPalette.Text; $layout.Controls.Add($l,0,$row) }
    Add-OutputLabel "Saldo atual" 0
    $current=New-Object Windows.Forms.Label; $current.Text=[string]$saldoAtual; $current.Dock=[Windows.Forms.DockStyle]::Fill; $current.TextAlign=[Drawing.ContentAlignment]::MiddleLeft; $layout.Controls.Add($current,1,0)
    Add-OutputLabel "Quantidade da saída" 1
    $qty=New-Object Windows.Forms.NumericUpDown; $qty.Minimum=1; $qty.Maximum=$saldoAtual; $qty.Value=1; $qty.Dock=[Windows.Forms.DockStyle]::Fill; $layout.Controls.Add($qty,1,1)
    Add-OutputLabel "Saldo após saída" 2
    $after=New-Object Windows.Forms.Label; $after.Text=[string]($saldoAtual-1); $after.Dock=[Windows.Forms.DockStyle]::Fill; $after.TextAlign=[Drawing.ContentAlignment]::MiddleLeft; $layout.Controls.Add($after,1,2)
    Add-OutputLabel "NF de Saída / referência" 3
    $refBox=New-Object Windows.Forms.TextBox; $refBox.Dock=[Windows.Forms.DockStyle]::Fill; $refBox.MaxLength=120; $layout.Controls.Add($refBox,1,3)
    $qty.Add_ValueChanged({ $after.Text=[string]($saldoAtual-[int]$qty.Value) })
    $buttons=New-Object Windows.Forms.FlowLayoutPanel; $buttons.Dock=[Windows.Forms.DockStyle]::Fill; $buttons.FlowDirection=[Windows.Forms.FlowDirection]::RightToLeft; $layout.SetColumnSpan($buttons,2); $layout.Controls.Add($buttons,0,4)
    $cancel=New-Object Windows.Forms.Button; $cancel.Text="CANCELAR"; $cancel.Width=110; $cancel.Height=34; $cancel.DialogResult=[Windows.Forms.DialogResult]::Cancel; Set-NFButtonStyle $cancel "Secondary"; $buttons.Controls.Add($cancel)
    $save=New-Object Windows.Forms.Button; $save.Text="REGISTRAR SAÍDA"; $save.Width=140; $save.Height=34; $save.DialogResult=[Windows.Forms.DialogResult]::OK; Set-NFButtonStyle $save "Primary"; $buttons.Controls.Add($save)
    $dialog.AcceptButton=$save; $dialog.CancelButton=$cancel
    if ($dialog.ShowDialog() -ne [Windows.Forms.DialogResult]::OK) { $dialog.Dispose(); return }
    $quantity=[int]$qty.Value; $reference=([string]$refBox.Text).Trim(); $dialog.Dispose()
    try {
        [void](Register-NFEntradaOutput -Store $script:Store -Product $product -Id $id -Quantidade $quantity -NFSaida $reference)
        Save-NFStore
        Refresh-NFAll
        Set-NFStatus ("Saída registrada na NF " + $record.NFEntrada + ". Saldo atual: " + ($saldoAtual-$quantity)) "Success"
    }
    catch { Set-NFStatus $_.Exception.Message "Error"; [Windows.Forms.MessageBox]::Show($_.Exception.Message, "Falha ao registrar saída", 0, 16) | Out-Null }
}

'''
s=s.replace(anchor,fn+anchor,1)
p.write_text(s,encoding='utf-8')
print('ui1 etapa 4 aplicado')
