from pathlib import Path
p=Path('src/generated/Modulos/Gerador-de-Planilhas-CB5-TV5/Gerador Planilhas.ps1')
s=p.read_text(encoding='utf-8-sig')
a='$actionW = if ($cw -lt 620) { 76 } elseif ($cw -lt 850) { 92 } else { 118 }'
b='$actionW = if ($cw -lt 850) { 92 } else { 118 }'
if s.count(a)!=1:
    raise SystemExit(f'PRE COMPONENT RECOVERY LAYOUT: esperado 1, encontrado {s.count(a)}')
s=s.replace(a,b,1)
p.write_text(s,encoding='utf-8')
print('PRE COMPONENT RECOVERY LAYOUT: OK - bloco preparado para terceira ação responsiva.')
