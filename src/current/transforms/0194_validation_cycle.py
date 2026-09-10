#!/usr/bin/env python3
from pathlib import Path

path = Path('src/generated/Central de Trabalho.ps1')
text = path.read_text(encoding='utf-8-sig')

old = '$script:AppVersion = "0.19.3"'
new = '$script:AppVersion = "0.19.4"'
if old not in text:
    raise SystemExit('Versão-base 0.19.3 não encontrada no script da Central.')
text = text.replace(old, new, 1)

# Esta versão é propositalmente um ciclo de validação operacional.
# Não altera regras do Gerenciador, Manutenção, Atualizador ou persistência.
path.write_text(text, encoding='utf-8-sig')
print('0.19.4: ciclo de validação preparado sem alterações funcionais.')
