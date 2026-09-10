#!/usr/bin/env python3
from pathlib import Path

path = Path('src/generated/Central de Trabalho.ps1')
text = path.read_text(encoding='utf-8-sig')
old = '$script:AppVersion = "0.19.1"'
new = '$script:AppVersion = "0.19.2"'
if old not in text:
    raise SystemExit('Versão-base 0.19.1 não encontrada na Central.')
text = text.replace(old, new, 1)
path.write_text(text, encoding='utf-8-sig')
print('0.19.2: versão da Central atualizada para aplicar o novo ícone CT simples.')
