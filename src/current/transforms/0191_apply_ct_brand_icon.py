#!/usr/bin/env python3
from pathlib import Path

path = Path('src/generated/Central de Trabalho.ps1')
text = path.read_text(encoding='utf-8-sig')

old_version = '$script:AppVersion = "0.19.0"'
new_version = '$script:AppVersion = "0.19.1"'
if old_version not in text:
    raise SystemExit('Central: versão-base 0.19.0 não encontrada.')
text = text.replace(old_version, new_version, 1)

marker = '''    $form = New-Object Windows.Forms.Form
$form.Text = "Central de Trabalho"'''
replacement = '''    $form = New-Object Windows.Forms.Form

# A janela usa a mesma identidade visual gravada no Central de Trabalho.exe.
# Assim, Explorador, barra de tarefas, Alt+Tab e a própria janela mostram o ícone CT.
try {
    $executablePath = [Windows.Forms.Application]::ExecutablePath
    if ([IO.File]::Exists($executablePath)) {
        $applicationIcon = [Drawing.Icon]::ExtractAssociatedIcon($executablePath)
        if ($null -ne $applicationIcon) { $form.Icon = $applicationIcon }
    }
}
catch {
    # A identidade visual não pode impedir a abertura da Central.
}

$form.Text = "Central de Trabalho"'''
if marker not in text:
    raise SystemExit('Central: ponto de criação da janela principal não encontrado.')
text = text.replace(marker, replacement, 1)

for required in (
    '[Windows.Forms.Application]::ExecutablePath',
    '[Drawing.Icon]::ExtractAssociatedIcon($executablePath)',
    '$form.Icon = $applicationIcon',
):
    if required not in text:
        raise SystemExit(f'Central: integração visual ausente: {required}')

path.write_text(text, encoding='utf-8-sig')
print('0.19.1: identidade visual CT vinculada ao EXE e à janela principal.')
