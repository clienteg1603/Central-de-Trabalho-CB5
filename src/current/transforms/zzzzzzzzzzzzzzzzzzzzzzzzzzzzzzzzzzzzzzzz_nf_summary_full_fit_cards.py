from pathlib import Path

p = Path('src/generated/Modulos/Controle-NF-Entrada/Controle NF Entrada.ps1')
n = p.read_text(encoding='utf-8-sig')

def one(text, old, new, label):
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'NF FULL FIT CARDS {label}: esperado 1, encontrado {count}')
    return text.replace(old, new, 1)

# Os cards 2x2 precisam de alguns pixels a mais internamente para a linha de
# métricas no notebook. Como o Resumo agora possui AutoScroll de página, podemos
# reservar essa altura sem voltar a esconder informações das demais áreas.
n = one(n,
    '$l.Padding=[Windows.Forms.Padding]::new(10,5,10,5)',
    '$l.Padding=[Windows.Forms.Padding]::new(10,3,10,3)',
    'padding interno dos cards')
n = one(n,
    '[void]$l.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute,25)))',
    '[void]$l.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute,21)))',
    'linha do titulo dos cards')
n = one(n,
    '$summaryCodeMin = if ($profile -eq "Tight") { 158 } elseif ($profile -eq "Compact") { 168 } else { 178 }',
    '$summaryCodeMin = if ($profile -eq "Tight") { 188 } elseif ($profile -eq "Compact") { 198 } else { 206 }',
    'altura minima Saldo por codigo')

n += '\n# NF_FULL_FIT_CODE_CARD_HEIGHT_V02624\n'
p.write_text(n, encoding='utf-8')
print('NF FULL FIT CARDS: OK - linha de métricas recebe altura suficiente em notebook/DPI.')
