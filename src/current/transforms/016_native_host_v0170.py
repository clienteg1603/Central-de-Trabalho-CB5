from pathlib import Path

root = Path(__file__).resolve().parents[2]
central = root / "generated" / "Central de Trabalho.ps1"
text = central.read_text(encoding="utf-8-sig")
old = '$script:AppVersion = "0.16.6"'
new = '$script:AppVersion = "0.17.0"'
if text.count(old) != 1:
    raise RuntimeError(f"versão anterior da Central não encontrada de forma única: {text.count(old)}")
central.write_text(text.replace(old, new, 1), encoding="utf-8-sig")
