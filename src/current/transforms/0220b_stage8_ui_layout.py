from pathlib import Path
p=Path('src/generated/Modulos/Controle-NF-Entrada/Controle NF Entrada.ps1')
s=p.read_text(encoding='utf-8-sig')
def one(a,b,label):
    global s
    if s.count(a)!=1: raise SystemExit(label)
    s=s.replace(a,b,1)
one('$script:ModuleVersion = "1.8.0"','$script:ModuleVersion = "1.9.0"','version')
one('function Show-NFRecordDialog {\n    param([string]$Product, $Existing = $null)','function Show-NFRecordDialog {\n    param([string]$Product, $Existing = $null, [string]$DefaultDate = "", [string]$DefaultCode = "800")','params')
one('$dialog.ClientSize = [Drawing.Size]::new(620, 430)','$dialog.ClientSize = [Drawing.Size]::new(620, 480)','size')
one('$layout.RowCount = 7','$layout.RowCount = 8','rows')
one('''    foreach ($i in 0..5) { [void]$layout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, $(if ($i -eq 5) { 112 } else { 44 })))) }\n    [void]$layout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 100)))''','''    foreach ($i in 0..5) { [void]$layout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, $(if ($i -eq 5) { 112 } else { 44 })))) }\n    [void]$layout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 44)))\n    [void]$layout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 100)))''','rowstyles')
one('''    $outBox.Dock = [Windows.Forms.DockStyle]::Fill\n    $layout.Controls.Add($outBox, 1, 5)\n\n    $buttons = New-Object Windows.Forms.FlowLayoutPanel''','''    $outBox.Dock = [Windows.Forms.DockStyle]::Fill\n    $layout.Controls.Add($outBox, 1, 5)\n\n    $validationLabel = New-Object Windows.Forms.Label\n    $validationLabel.Text = "Preencha os dados para validar o registro."\n    $validationLabel.Dock = [Windows.Forms.DockStyle]::Fill\n    $validationLabel.TextAlign = [Drawing.ContentAlignment]::MiddleLeft\n    $validationLabel.ForeColor = $script:CurrentPalette.Muted\n    $layout.SetColumnSpan($validationLabel, 2)\n    $layout.Controls.Add($validationLabel, 0, 6)\n\n    $buttons = New-Object Windows.Forms.FlowLayoutPanel''','validation label')
one('$layout.Controls.Add($buttons, 0, 6)','$layout.Controls.Add($buttons, 0, 7)','buttons row')
p.write_text(s,encoding='utf-8')
