#!/usr/bin/env python3
from pathlib import Path

central_path = Path("src/generated/Central de Trabalho.ps1")
central = central_path.read_text(encoding="utf-8-sig")

if '$script:AppVersion = "0.20.1"' not in central:
    raise SystemExit("Central: versão-base 0.20.1 não encontrada")
central = central.replace('$script:AppVersion = "0.20.1"', '$script:AppVersion = "0.20.2"', 1)

for marker in (
    '$script:GeneratorVersion = "3.7.3"',
    '$script:MaintenanceVersion = "0.6.1"',
    '$script:UpdaterVersion = "1.0.0"',
):
    if marker not in central:
        raise SystemExit(f"Central: contrato de versão ausente: {marker}")

central_path.write_text(central, encoding="utf-8-sig")
print("0.20.2: candidata final com smoke test nativo obrigatório antes da publicação.")
