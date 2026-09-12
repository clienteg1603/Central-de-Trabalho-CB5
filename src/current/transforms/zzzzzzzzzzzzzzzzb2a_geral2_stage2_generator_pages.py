from pathlib import Path
p=Path('src/generated/Modulos/Gerador-de-Planilhas-CB5-TV5/Gerador Planilhas.ps1')
g=p.read_text(encoding='utf-8-sig')

def first(a,b,label):
    global g
    if a not in g: raise SystemExit('E2B2A ausente: '+label)
    g=g.replace(a,b,1)

def one(a,b,label):
    global g
    n=g.count(a)
    if n!=1: raise SystemExit(f'E2B2A {label}: {n}')
    g=g.replace(a,b,1)

first('$gw = [Math]::Max(520, [int]$tabGenerate.ClientSize.Width)','$gw = [Math]::Max(360, [int]$tabGenerate.ClientSize.Width)','gw1')
one('$gw = [Math]::Max(520, [int]$tabGenerate.ClientSize.Width)','$gw = [Math]::Max(360, [int]$tabGenerate.ClientSize.Width)','gw2')
for a,b,label in (
('$gh = [Math]::Max(330, [int]$tabGenerate.ClientSize.Height)','$gh = [Math]::Max(235, [int]$tabGenerate.ClientSize.Height)','gh'),
('$gInnerW = [Math]::Max(460, $gw - 36)','$gInnerW = [Math]::Max(300, $gw - 24)','gin'),
('$summaryLayout.Width = [Math]::Max(420, $summaryCard.ClientSize.Width - 20)','$summaryLayout.Width = [Math]::Max(260, $summaryCard.ClientSize.Width - 20)','resumo'),
('$statusText.Height = [Math]::Max(82, $gh - $statusText.Top - 14)','$statusText.Height = [Math]::Max(58, $gh - $statusText.Top - 12)','resultado'),
('$ew = [Math]::Max(520, [int]$tabExtra.ClientSize.Width)','$ew = [Math]::Max(360, [int]$tabExtra.ClientSize.Width)','ew'),
('$eh = [Math]::Max(300, [int]$tabExtra.ClientSize.Height)','$eh = [Math]::Max(220, [int]$tabExtra.ClientSize.Height)','eh'),
('$eInnerW = [Math]::Max(460, $ew - 36)','$eInnerW = [Math]::Max(300, $ew - 24)','ein'),
('$extraGrid.Height = [Math]::Max(150, $eh - $extraGrid.Top - 14)','$extraGrid.Height = [Math]::Max(108, $eh - $extraGrid.Top - 12)','extra'),
('$dw = [Math]::Max(520, [int]$tabDescriptions.ClientSize.Width)','$dw = [Math]::Max(360, [int]$tabDescriptions.ClientSize.Width)','dw'),
('$dh = [Math]::Max(300, [int]$tabDescriptions.ClientSize.Height)','$dh = [Math]::Max(220, [int]$tabDescriptions.ClientSize.Height)','dh'),
('$dInnerW = [Math]::Max(460, $dw - 36)','$dInnerW = [Math]::Max(300, $dw - 24)','din'),
('$descriptionsGrid.Height = [Math]::Max(170, $dh - $descriptionsGrid.Top - 14)','$descriptionsGrid.Height = [Math]::Max(118, $dh - $descriptionsGrid.Top - 12)','codigos')):
    one(a,b,label)

g+='\n# GERAL2_ETAPA2_GERAR_MANUT_CODIGOS_V03715\n'
p.write_text(g,encoding='utf-8')
print('GERAL 2 ETAPA 2B2A: OK')
