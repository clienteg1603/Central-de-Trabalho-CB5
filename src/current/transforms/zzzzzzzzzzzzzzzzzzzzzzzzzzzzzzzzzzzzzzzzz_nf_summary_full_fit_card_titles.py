from pathlib import Path

p = Path('src/generated/Modulos/Controle-NF-Entrada/Controle NF Entrada.ps1')
n = p.read_text(encoding='utf-8-sig')

old = '[void]$l.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute,21)))'
new = '[void]$l.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute,28)))'
count = n.count(old)
if count != 1:
    raise SystemExit(f'NF FULL FIT CARD TITLES: esperado 1, encontrado {count}')
n = n.replace(old, new, 1)

n += '\n# NF_FULL_FIT_CODE_CARD_TITLES_V02624\n'
p.write_text(n, encoding='utf-8')
print('NF FULL FIT CARD TITLES: OK - 800, 100, 850 e Garantia recebem altura suficiente.')
