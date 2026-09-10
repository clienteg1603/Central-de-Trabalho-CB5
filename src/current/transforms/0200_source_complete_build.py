#!/usr/bin/env python3
from pathlib import Path

central_path = Path("src/generated/Central de Trabalho.ps1")
central = central_path.read_text(encoding="utf-8-sig")

old = '$script:AppVersion = "0.19.6"'
new = '$script:AppVersion = "0.20.0"'
if old not in central:
    raise SystemExit("Central: versão-base 0.19.6 não encontrada")
if central.count(old) != 1:
    raise SystemExit("Central: versão-base 0.19.6 apareceu quantidade inesperada de vezes")
central = central.replace(old, new, 1)

for marker in (
    '$script:GeneratorVersion = "3.7.3"',
    '$script:MaintenanceVersion = "0.6.1"',
    '$script:UpdaterVersion = "1.0.0"',
    'function Set-InternalRuntimeArtifactsHidden',
    'function Start-UpdaterModule',
):
    if marker not in central:
        raise SystemExit(f"Central: contrato esperado ausente após avanço para 0.20.0: {marker}")

central_path.write_text(central, encoding="utf-8-sig")
print("0.20.0: versão de consolidação do build 100% baseado no fonte runtime versionado.")
