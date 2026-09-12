from pathlib import Path
p=Path('src/generated/Modulos/Gerador-de-Planilhas-CB5-TV5/Gerador Planilhas.ps1')
g=p.read_text(encoding='utf-8-sig')

def one(a,b,label):
    global g
    n=g.count(a)
    if n!=1: raise SystemExit(f'E2B1 {label}: {n}')
    g=g.replace(a,b,1)

for a,b,label in (
('$cw = [Math]::Max(520, [int]$tabComponents.ClientSize.Width)','$cw = [Math]::Max(360, [int]$tabComponents.ClientSize.Width)','cw'),
('$ch = [Math]::Max(320, [int]$tabComponents.ClientSize.Height)','$ch = [Math]::Max(230, [int]$tabComponents.ClientSize.Height)','ch'),
('$innerW = [Math]::Max(460, $cw - 36)','$innerW = [Math]::Max(300, $cw - 24)','inner'),
('$actionW = if ($cw -lt 850) { 92 } else { 118 }','$actionW = if ($cw -lt 620) { 76 } elseif ($cw -lt 850) { 92 } else { 118 }','acoes'),
('$componentSearchText.Width = if ($cw -lt 760) { 170 } elseif ($cw -lt 980) { 220 } else { 260 }','$componentSearchText.Width = if ($cw -lt 620) { 128 } elseif ($cw -lt 760) { 170 } elseif ($cw -lt 980) { 220 } else { 260 }','pesquisa'),
('$componentSearchClearButton.Width = if ($cw -lt 760) { 64 } else { 76 }','$componentSearchClearButton.Width = if ($cw -lt 620) { 56 } elseif ($cw -lt 760) { 64 } else { 76 }','limpar')):
    one(a,b,label)

g+='\n# GERAL2_ETAPA2_COMPONENTES_V03715\n'
p.write_text(g,encoding='utf-8')
print('GERAL 2 ETAPA 2B1: OK')
