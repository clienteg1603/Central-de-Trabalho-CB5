from pathlib import Path

cp = Path('src/generated/Central de Trabalho.ps1')
up = Path('src/generated/Atualizador/Central de Trabalho Updater.ps1')
ucp = Path('src/generated/Atualizador/Update.Core.ps1')

c = cp.read_text(encoding='utf-8-sig')
u = up.read_text(encoding='utf-8-sig')
uc = ucp.read_text(encoding='utf-8-sig')


def one(text, old, new, label):
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'GERAL2/E6 {label}: esperado 1, encontrado {count}')
    return text.replace(old, new, 1)


c = one(c, '$script:AppVersion = "0.21.53"', '$script:AppVersion = "0.21.54"', 'versao Central')
c = one(c, '$script:UpdaterVersion = "1.0.0"', '$script:UpdaterVersion = "1.0.1"', 'versao Atualizador na Central')
uc = one(uc, '$script:CentralUpdaterVersion = "1.0.0"', '$script:CentralUpdaterVersion = "1.0.1"', 'versao nucleo Atualizador')

# Atualizador deixa de ser a ultima janela clara do conjunto e passa a seguir
# a mesma linguagem Tecnico industrial usada pela Central e pelos modulos.
u = one(u, '$form.BackColor = [Drawing.Color]::FromArgb(241, 245, 249)', '$form.BackColor = [Drawing.Color]::FromArgb(18, 23, 25)\n$form.ForeColor = [Drawing.Color]::FromArgb(242, 246, 245)', 'fundo Atualizador')
u = one(u, '$versionPanel.BackColor = [Drawing.Color]::White', '$versionPanel.BackColor = [Drawing.Color]::FromArgb(34, 43, 46)\n$versionPanel.ForeColor = [Drawing.Color]::FromArgb(242, 246, 245)', 'card versoes')
u = one(u, '$endpointLabel.BackColor = [Drawing.Color]::White', '$endpointLabel.BackColor = [Drawing.Color]::FromArgb(34, 43, 46)\n$endpointLabel.ForeColor = [Drawing.Color]::FromArgb(174, 188, 186)', 'card endpoint')
u = one(u, '$releaseNotesBox.BackColor = [Drawing.Color]::White', '$releaseNotesBox.BackColor = [Drawing.Color]::FromArgb(18, 23, 25)\n$releaseNotesBox.ForeColor = [Drawing.Color]::FromArgb(242, 246, 245)', 'notas versao')
u = one(u, '$notesGroup.Padding = [Windows.Forms.Padding]::new(12, 22, 12, 12)', '$notesGroup.Padding = [Windows.Forms.Padding]::new(12, 22, 12, 12)\n$notesGroup.ForeColor = [Drawing.Color]::FromArgb(242, 246, 245)', 'grupo notas')
u = one(u, '$restoreDataCheck.Checked = $false', '$restoreDataCheck.Checked = $false\n$restoreDataCheck.ForeColor = [Drawing.Color]::FromArgb(242, 246, 245)', 'checkbox restauracao')
u = one(u, '$channelCombo.SelectedIndex = if ($script:UserSettings.Channel -eq "test") { 1 } else { 0 }', '$channelCombo.SelectedIndex = if ($script:UserSettings.Channel -eq "test") { 1 } else { 0 }\n$channelCombo.BackColor = [Drawing.Color]::FromArgb(18, 23, 25)\n$channelCombo.ForeColor = [Drawing.Color]::FromArgb(242, 246, 245)', 'combo canal')

# Status escuros e legiveis, sem os blocos claros que destoavam do restante.
for old, new, label in (
    ('[Drawing.Color]::FromArgb(220, 252, 231)', '[Drawing.Color]::FromArgb(22, 72, 57)', 'status success bg'),
    ('[Drawing.Color]::FromArgb(21, 128, 61)', '[Drawing.Color]::FromArgb(72, 202, 143)', 'status success fg'),
    ('[Drawing.Color]::FromArgb(255, 247, 237)', '[Drawing.Color]::FromArgb(86, 59, 13)', 'status warning bg'),
    ('[Drawing.Color]::FromArgb(194, 65, 12)', '[Drawing.Color]::FromArgb(246, 186, 68)', 'status warning fg'),
    ('[Drawing.Color]::FromArgb(254, 226, 226)', '[Drawing.Color]::FromArgb(78, 28, 26)', 'status error bg'),
    ('[Drawing.Color]::FromArgb(185, 28, 28)', '[Drawing.Color]::FromArgb(239, 108, 102)', 'status error fg'),
    ('[Drawing.Color]::FromArgb(239, 246, 255)', '[Drawing.Color]::FromArgb(27, 35, 38)', 'status normal bg'),
    ('[Drawing.Color]::FromArgb(29, 78, 216)', '[Drawing.Color]::FromArgb(44, 189, 197)', 'status normal fg'),
    ('[Drawing.Color]::FromArgb(71, 85, 105)', '[Drawing.Color]::FromArgb(174, 188, 186)', 'texto muted'),
    ('[Drawing.Color]::FromArgb(180, 83, 9)', '[Drawing.Color]::FromArgb(246, 186, 68)', 'endpoint warning'),
):
    if old in u:
        u = u.replace(old, new)

helper = r'''
function Set-UpdaterRoundedRegion {
    param([Windows.Forms.Control]$Control, [int]$Radius = 7)
    if ($null -eq $Control -or $Control.Width -le 2 -or $Control.Height -le 2) { return }
    try {
        $d = [Math]::Max(2, $Radius * 2)
        $r = [Drawing.Rectangle]::new(0, 0, $Control.Width - 1, $Control.Height - 1)
        $p = New-Object Drawing.Drawing2D.GraphicsPath
        $p.AddArc($r.Left,$r.Top,$d,$d,180,90); $p.AddArc($r.Right-$d,$r.Top,$d,$d,270,90)
        $p.AddArc($r.Right-$d,$r.Bottom-$d,$d,$d,0,90); $p.AddArc($r.Left,$r.Bottom-$d,$d,$d,90,90)
        $p.CloseFigure(); $old = $Control.Region; $Control.Region = New-Object Drawing.Region($p); $p.Dispose()
        if ($null -ne $old) { $old.Dispose() }
    } catch {}
}

function Set-UpdaterButtonStyle {
    param([Windows.Forms.Button]$Button, [ValidateSet("Primary","Action","Secondary")][string]$Kind="Secondary")
    $Button.FlatStyle = [Windows.Forms.FlatStyle]::Flat
    $Button.Cursor = [Windows.Forms.Cursors]::Hand
    $Button.Font = [Drawing.Font]::new("Segoe UI Semibold", 9)
    if ($Kind -eq "Action") {
        $Button.BackColor = [Drawing.Color]::FromArgb(244,142,40); $Button.ForeColor = [Drawing.Color]::FromArgb(27,24,17); $Button.FlatAppearance.BorderSize = 0
    }
    elseif ($Kind -eq "Primary") {
        $Button.BackColor = [Drawing.Color]::FromArgb(44,189,197); $Button.ForeColor = [Drawing.Color]::FromArgb(9,24,28); $Button.FlatAppearance.BorderSize = 0
    }
    else {
        $Button.BackColor = [Drawing.Color]::FromArgb(27,35,38); $Button.ForeColor = [Drawing.Color]::White; $Button.FlatAppearance.BorderColor = [Drawing.Color]::FromArgb(62,77,80); $Button.FlatAppearance.BorderSize = 1
    }
    Set-UpdaterRoundedRegion $Button 7
}

function Apply-UpdaterIndustrialPolish {
    foreach ($panel in @($root,$header,$bodyHost,$body,$channelPanel,$restorePanel,$footer,$buttonBar)) {
        if ($null -ne $panel) { $panel.BackColor = [Drawing.Color]::FromArgb(18,23,25); $panel.ForeColor = [Drawing.Color]::FromArgb(242,246,245) }
    }
    Set-UpdaterButtonStyle $configureButton "Secondary"
    Set-UpdaterButtonStyle $openBackupsButton "Secondary"
    Set-UpdaterButtonStyle $restoreButton "Secondary"
    Set-UpdaterButtonStyle $checkButton "Primary"
    Set-UpdaterButtonStyle $installButton "Action"
}
'''
u = one(u, '$form = New-Object Windows.Forms.Form', helper + '\n$form = New-Object Windows.Forms.Form', 'helpers visuais Atualizador')

# Remove o azul isolado do botao de instalacao e usa o papel laranja de acao.
u = one(u, '$installButton.BackColor = [Drawing.Color]::FromArgb(37, 99, 235)\n$installButton.ForeColor = [Drawing.Color]::White\n$installButton.FlatStyle = [Windows.Forms.FlatStyle]::Flat\n$installButton.FlatAppearance.BorderSize = 0', 'Set-UpdaterButtonStyle $installButton "Action"', 'botao instalar')

# Dialogo de configuracao acompanha o mesmo tema.
u = one(u, '$dialog.Font = [Drawing.Font]::new("Segoe UI", 9.5)', '$dialog.Font = [Drawing.Font]::new("Segoe UI", 9.5)\n    $dialog.BackColor = [Drawing.Color]::FromArgb(18,23,25)\n    $dialog.ForeColor = [Drawing.Color]::FromArgb(242,246,245)', 'dialog tema')
u = one(u, '$textBox.Text = $CurrentUrl', '$textBox.Text = $CurrentUrl\n    $textBox.BackColor = [Drawing.Color]::FromArgb(18,23,25)\n    $textBox.ForeColor = [Drawing.Color]::FromArgb(242,246,245)', 'dialog textbox')
u = one(u, '$cancel.DialogResult = [Windows.Forms.DialogResult]::Cancel', '$cancel.DialogResult = [Windows.Forms.DialogResult]::Cancel\n    Set-UpdaterButtonStyle $cancel "Secondary"', 'dialog cancelar')
u = one(u, '$save.BackColor = [Drawing.Color]::FromArgb(37, 99, 235)\n    $save.ForeColor = [Drawing.Color]::White\n    $save.FlatStyle = [Windows.Forms.FlatStyle]::Flat\n    $save.FlatAppearance.BorderSize = 0', 'Set-UpdaterButtonStyle $save "Action"', 'dialog salvar')

u = one(u, '$form.Add_Shown({\n    $restoreButton.Enabled = @(Get-CentralUpdateBackups).Count -gt 0', '$form.Add_Shown({\n    Apply-UpdaterIndustrialPolish\n    $restoreButton.Enabled = @(Get-CentralUpdateBackups).Count -gt 0', 'aplica polimento')

c += '\n# GERAL2_ETAPA6_VISUAL_V02154\n'
u += '\n# GERAL2_ETAPA6_UPDATER_INDUSTRIAL_V101\n'
uc += '\n# GERAL2_ETAPA6_UPDATER_CORE_V101\n'

for marker in ('$script:AppVersion = "0.21.54"','$script:UpdaterVersion = "1.0.1"','GERAL2_ETAPA6_VISUAL_V02154'):
    if marker not in c: raise SystemExit('GERAL2/E6 Central marcador ausente: '+marker)
for marker in ('function Apply-UpdaterIndustrialPolish','Set-UpdaterButtonStyle $installButton "Action"','GERAL2_ETAPA6_UPDATER_INDUSTRIAL_V101'):
    if marker not in u: raise SystemExit('GERAL2/E6 Atualizador marcador ausente: '+marker)
for marker in ('$script:CentralUpdaterVersion = "1.0.1"','GERAL2_ETAPA6_UPDATER_CORE_V101'):
    if marker not in uc: raise SystemExit('GERAL2/E6 Core marcador ausente: '+marker)

cp.write_text(c, encoding='utf-8')
up.write_text(u, encoding='utf-8')
ucp.write_text(uc, encoding='utf-8')
print('GERAL 2 ETAPA 6: OK - Atualizador unificado ao tema Tecnico industrial e hierarquia de acoes da Central.')
