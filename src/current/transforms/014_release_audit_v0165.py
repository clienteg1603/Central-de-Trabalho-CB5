from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CENTRAL = ROOT / "generated" / "Central de Trabalho.ps1"

text = CENTRAL.read_text(encoding="utf-8-sig")
old = '$script:AppVersion = "0.16.4"'
new = '$script:AppVersion = "0.16.5"'
if text.count(old) != 1:
    raise RuntimeError(f"versão Central: esperado 1 trecho, encontrado {text.count(old)}")
CENTRAL.write_text(text.replace(old, new, 1), encoding="utf-8-sig")
