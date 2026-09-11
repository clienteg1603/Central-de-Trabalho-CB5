from pathlib import Path

root = Path('.')
ui = root / 'src/generated/Modulos/Controle-NF-Entrada/Controle NF Entrada.ps1'
text = ui.read_text(encoding='utf-8-sig')
text = text.replace('$script:ModuleVersion = "1.9.0"', '$script:ModuleVersion = "2.0.0"', 1)
ui.write_text(text, encoding='utf-8')
print('stage9 transform prepared')
