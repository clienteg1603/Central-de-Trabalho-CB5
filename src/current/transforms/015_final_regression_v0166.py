from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CENTRAL = ROOT / "generated" / "Central de Trabalho.ps1"

text = CENTRAL.read_text(encoding="utf-8-sig")
old = '$script:AppVersion = "0.16.5"'
new = '$script:AppVersion = "0.16.6"'
count = text.count(old)
if count != 1:
    raise RuntimeError(f"versão da Central: esperado 1 trecho, encontrado {count}")
CENTRAL.write_text(text.replace(old, new, 1), encoding="utf-8-sig")
