from pathlib import Path
p=Path('src/generated/Modulos/Gerador-de-Planilhas-CB5-TV5/Gerador Planilhas.ps1')
g=p.read_text(encoding='utf-8-sig')

def one(a,b,label):
    global g
    n=g.count(a)
    if n!=1: raise SystemExit(f'GERAL2/E2B {label}: esperado 1, encontrado {n}')
    g=g.replace(a,b,1)

# Componentes.
for a,b,label in (
('$cw = [Math]::Max(520, [int]$tabComponents.ClientSize.Width)','$cw = [Math]::Max(360, [int]$tabComponents.ClientSize.Width)','cw'),
('$ch = [Math]::Max(320, [int]$tabComponents.ClientSize.Height)','$ch = [Math]::Max(230, [int]$tabComponents.ClientSize.Height)','ch'),
('$innerW = [Math]::Max(460, $cw - 36)','$innerW = [Math]::Max(300, $cw - 24)','inner'),
('$actionW = if ($cw -lt 850) { 92 } else { 118 }','$actionW = if ($cw -lt 620) { 76 } elseif ($cw -lt 850) { 92 } else { 118 }','acoes'),
('$componentSearchText.Width = if ($cw -lt 760) { 170 } elseif ($cw -lt 980) { 220 } else { 260 }','$componentSearchText.Width = if ($cw -lt 620) { 128 } elseif ($cw -lt 760) { 170 } elseif ($cw -lt 980) { 220 } else { 260 }','pesquisa'),
('$componentSearchClearButton.Width = if ($cw -lt 760) { 64 } else { 76 }','$componentSearchClearButton.Width = if ($cw -lt 620) { 56 } elseif ($cw -lt 760) { 64 } else { 76 }','limpar')):
    one(a,b,label)

# Gerar e Juntar dentro da primeira rotina.
one('$gw = [Math]::Max(520, [int]$tabGenerate.ClientSize.Width)','$gw = [Math]::Max(360, [int]$tabGenerate.ClientSize.Width)','gw1')
one('$jw = [Math]::Max(520, [int]$tabCombine.ClientSize.Width)','$jw = [Math]::Max(360, [int]$tabCombine.ClientSize.Width)','jw1')

# Segunda rotina: todas as cinco areas passam a respeitar a area real.
for a,b,label in (
('$gw = [Math]::Max(520, [int]$tabGenerate.ClientSize.Width)','$gw = [Math]::Max(360, [int]$tabGenerate.ClientSize.Width)','gw2'),
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
('$descriptionsGrid.Height = [Math]::Max(170, $dh - $descriptionsGrid.Top - 14)','$descriptionsGrid.Height = [Math]::Max(118, $dh - $descriptionsGrid.Top - 12)','codigos'),
('$jw = [Math]::Max(520, [int]$tabCombine.ClientSize.Width)','$jw = [Math]::Max(360, [int]$tabCombine.ClientSize.Width)','jw2'),
('$jh = [Math]::Max(340, [int]$tabCombine.ClientSize.Height)','$jh = [Math]::Max(240, [int]$tabCombine.ClientSize.Height)','jh'),
('$jInnerW = [Math]::Max(460, $jw - 36)','$jInnerW = [Math]::Max(300, $jw - 24)','jin')):
    one(a,b,label)

g+='\n# GERAL2_ETAPA2_GENERATOR_FIT_V03715\n'
if '$script:AppVersion = "3.7.15"' not in g or 'GERAL2_ETAPA2_GENERATOR_FIT_V03715' not in g:
    raise SystemExit('GERAL2/E2B marcadores finais ausentes')
p.write_text(g,encoding='utf-8')
print('GERAL 2 ETAPA 2B: OK - cinco areas respeitam largura e altura reais.')
