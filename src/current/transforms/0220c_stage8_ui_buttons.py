from pathlib import Path
p=Path('src/generated/Modulos/Controle-NF-Entrada/Controle NF Entrada.ps1')
s=p.read_text(encoding='utf-8-sig')
old='''    $save = New-Object Windows.Forms.Button\n    $save.Text = "SALVAR"\n    $save.Width = 110\n    $save.Height = 34\n    $save.DialogResult = [Windows.Forms.DialogResult]::OK\n    Set-NFButtonStyle $save "Primary"\n    $buttons.Controls.Add($save)\n    $dialog.AcceptButton = $save\n    $dialog.CancelButton = $cancel\n'''
new='''    $save = New-Object Windows.Forms.Button\n    $save.Text = "SALVAR"\n    $save.Width = 110\n    $save.Height = 34\n    $save.DialogResult = [Windows.Forms.DialogResult]::OK\n    Set-NFButtonStyle $save "Primary"\n    $buttons.Controls.Add($save)\n\n    $saveAndNew = $null\n    if ($null -eq $Existing) {\n        $saveAndNew = New-Object Windows.Forms.Button\n        $saveAndNew.Text = "SALVAR E NOVA"\n        $saveAndNew.Width = 135\n        $saveAndNew.Height = 34\n        $saveAndNew.DialogResult = [Windows.Forms.DialogResult]::Retry\n        Set-NFButtonStyle $saveAndNew "Secondary"\n        $buttons.Controls.Add($saveAndNew)\n    }\n    $dialog.AcceptButton = $save\n    $dialog.CancelButton = $cancel\n'''
if s.count(old)!=1: raise SystemExit('stage8 save buttons')
s=s.replace(old,new,1)
p.write_text(s,encoding='utf-8')
