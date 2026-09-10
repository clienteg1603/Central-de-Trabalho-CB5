#!/usr/bin/env python3
from pathlib import Path

central_path = Path("src/generated/Central de Trabalho.ps1")
central = central_path.read_text(encoding="utf-8-sig")

if '$script:AppVersion = "0.20.0"' not in central:
    raise SystemExit("Central: versão-base 0.20.0 não encontrada")

central = central.replace('$script:AppVersion = "0.20.0"', '$script:AppVersion = "0.20.1"', 1)
central_path.write_text(central, encoding="utf-8-sig")

print("0.20.1: acabamento da identidade Windows dos executáveis, sem mudança funcional.")
