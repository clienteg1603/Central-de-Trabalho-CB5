from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CENTRAL = ROOT / "generated" / "Central de Trabalho.ps1"

text = CENTRAL.read_text(encoding="utf-8-sig")

old_version = '$script:AppVersion = "0.14.0"'
new_version = '$script:AppVersion = "0.14.1"'
if text.count(old_version) != 1:
    raise RuntimeError(f"versao Central: esperado 1 trecho, encontrado {text.count(old_version)}")
text = text.replace(old_version, new_version, 1)

old_loop = 'foreach ($b in @($navHome,$navPrograms,$navUpdates,$navBackup,$navFolder,$navAbout))'
new_loop = 'foreach ($b in @($navHome,$navUpdates,$navFolder,$navAbout))'
count = text.count(old_loop)
if count != 3:
    raise RuntimeError(f"loops responsivos da navegacao: esperado 3 trechos, encontrado {count}")
text = text.replace(old_loop, new_loop)

CENTRAL.write_text(text, encoding="utf-8-sig")
print("Hotfix v0.14.1 aplicado: controles removidos nao participam mais do layout responsivo.")
