#!/usr/bin/env python3
from pathlib import Path

path = Path("src/generated/Central de Trabalho.ps1")
text = path.read_text(encoding="utf-8-sig")
old = '$script:AppVersion = "0.20.2"'
new = '$script:AppVersion = "0.20.3"'
if old not in text:
    raise SystemExit("Central: versão-base 0.20.2 não encontrada")
text = text.replace(old, new, 1)
path.write_text(text, encoding="utf-8-sig")
print("0.20.3: correção específica do ícone fixado na barra de tarefas.")
