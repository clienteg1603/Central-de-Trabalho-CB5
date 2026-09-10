#!/usr/bin/env python3
from pathlib import Path

central_path = Path("src/generated/Central de Trabalho.ps1")
central = central_path.read_text(encoding="utf-8-sig")

old = '$script:AppVersion = "0.19.5"'
new = '$script:AppVersion = "0.19.6"'
if old not in central:
    raise SystemExit("Central: versão-base 0.19.5 não encontrada")
central = central.replace(old, new, 1)

# Esta versão é propositalmente funcionalmente neutra: serve para validar em uso real
# o ciclo completo do Atualizador já corrigido na 0.19.5.
if '$script:UpdaterExecutable' not in central:
    raise SystemExit("Central: executável nativo do Atualizador não está configurado")
if 'powershell.exe' in central.lower() or 'pwsh.exe' in central.lower():
    raise SystemExit("Central: referência inesperada a lançador PowerShell externo")

central_path.write_text(central, encoding="utf-8-sig")
print("0.19.6: versão neutra para validação real do ciclo nativo 0.19.5 -> 0.19.6.")
