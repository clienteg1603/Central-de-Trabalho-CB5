from pathlib import Path
p=Path('src/generated/Modulos/Gerador-de-Planilhas-CB5-TV5/Gerador Planilhas.ps1')
g=p.read_text(encoding='utf-8-sig')

def first(a,b,label):
    global g
    if a not in g: raise SystemExit('E2B2B ausente: '+label)
    g=g.replace(a,b,1)

def one(a,b,label):
    global g
    n=g.count(a)
    if n!=1: raise SystemExit(f'E2B2B {label}: {n}')
    g=g.replace(a,b,1)

first('$jw = [Math]::Max(520, [int]$tabCombine.ClientSize.Width)','$jw = [Math]::Max(360, [int]$tabCombine.ClientSize.Width)','jw1')
first('$jInnerW = [Math]::Max(460, $jw - 36)','$jInnerW = [Math]::Max(300, $jw - 24)','jin1')
one('$jw = [Math]::Max(520, [int]$tabCombine.ClientSize.Width)','$jw = [Math]::Max(360, [int]$tabCombine.ClientSize.Width)','jw2')
one('$jh = [Math]::Max(340, [int]$tabCombine.ClientSize.Height)','$jh = [Math]::Max(240, [int]$tabCombine.ClientSize.Height)','jh')
one('$jInnerW = [Math]::Max(460, $jw - 36)','$jInnerW = [Math]::Max(300, $jw - 24)','jin2')

g+='\n# GERAL2_ETAPA2_JUNTAR_V03715\n'
p.write_text(g,encoding='utf-8')
print('GERAL 2 ETAPA 2B2B: OK')
