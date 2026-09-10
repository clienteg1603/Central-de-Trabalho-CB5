#!/usr/bin/env python3
from pathlib import Path

path = Path('src/generated/Central de Trabalho.ps1')
text = path.read_text(encoding='utf-8-sig')
old = '$script:AppVersion = "0.18.0"'
new = '$script:AppVersion = "0.18.1"'
if old not in text:
    raise SystemExit('Versão-base 0.18.0 não encontrada no script da Central.')
text = text.replace(old, new, 1)
path.write_text(text, encoding='utf-8-sig')
print('0.18.1: versão de validação do ciclo completo pelo Atualizador nativo preparada.')
