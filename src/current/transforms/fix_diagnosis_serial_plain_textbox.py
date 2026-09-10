from pathlib import Path

root = Path('src/generated')
maintenance = root / 'Modulos' / 'Central-de-Manutencao-CB5' / 'Central Manutencao CB5.ps1'
central = root / 'Central de Trabalho.ps1'

m = maintenance.read_text(encoding='utf-8-sig')
old = '''$diagnosisSerialBox = New-Object Windows.Forms.MaskedTextBox
$diagnosisSerialBox.Mask = "00000000"
$diagnosisSerialBox.TextMaskFormat = [Windows.Forms.MaskFormat]::ExcludePromptAndLiterals
$diagnosisSerialBox.Dock = [Windows.Forms.DockStyle]::Fill
$diagnosisInputLayout.Controls.Add($diagnosisSerialBox, 0, 1)'''
new = '''$diagnosisSerialBox = New-Object Windows.Forms.TextBox
$diagnosisSerialBox.MaxLength = 8
$diagnosisSerialBox.WordWrap = $false
$diagnosisSerialBox.Dock = [Windows.Forms.DockStyle]::Fill
$diagnosisSerialBox.Add_KeyPress({
    if (-not [char]::IsControl($_.KeyChar) -and -not [char]::IsDigit($_.KeyChar)) {
        $_.Handled = $true
    }
})
$diagnosisInputLayout.Controls.Add($diagnosisSerialBox, 0, 1)'''
if old not in m:
    raise SystemExit('Bloco antigo de Série opcional não encontrado; transformação abortada.')
m = m.replace(old, new, 1)
m = m.replace('$script:AppVersion = "0.5.7"', '$script:AppVersion = "0.5.8"', 1)
maintenance.write_text(m, encoding='utf-8-sig')

c = central.read_text(encoding='utf-8-sig')
if '$script:AppVersion = "0.12.3"' not in c:
    raise SystemExit('Versão 0.12.3 da Central não encontrada.')
if '$script:MaintenanceVersion = "0.5.7"' not in c:
    raise SystemExit('Versão 0.5.7 da Manutenção não encontrada na Central.')
c = c.replace('$script:AppVersion = "0.12.3"', '$script:AppVersion = "0.12.4"', 1)
c = c.replace('$script:MaintenanceVersion = "0.5.7"', '$script:MaintenanceVersion = "0.5.8"', 1)
central.write_text(c, encoding='utf-8-sig')
