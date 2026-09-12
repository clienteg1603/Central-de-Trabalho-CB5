from pathlib import Path

cp=Path('src/generated/Central de Trabalho.ps1')
gp=Path('src/generated/Modulos/Gerador-de-Planilhas-CB5-TV5/Gerador Planilhas.ps1')
c=cp.read_text(encoding='utf-8-sig'); g=gp.read_text(encoding='utf-8-sig')

def one(t,a,b,label):
    n=t.count(a)
    if n!=1: raise SystemExit(f'GERAL2/E2A {label}: esperado 1, encontrado {n}')
    return t.replace(a,b,1)

c=one(c,'$script:AppVersion = "0.21.49"','$script:AppVersion = "0.21.50"','Central')
c=one(c,'$script:GeneratorVersion = "3.7.14"','$script:GeneratorVersion = "3.7.15"','Gerenciador Central')
g=one(g,'$script:AppVersion = "3.7.14"','$script:AppVersion = "3.7.15"','Gerenciador')

g=one(g,'$tabs.ItemSize = [Drawing.Size]::new($tabWidth, 52)','$tabs.ItemSize = [Drawing.Size]::new($tabWidth, $(if ($profile -eq "Tight") { 44 } elseif ($profile -eq "Compact") { 48 } else { 52 }))','altura das abas')
g=one(g,'foreach ($page in @($tabGenerate,$tabExtra,$tabComponents,$tabCombine,$tabDescriptions)) { $page.AutoScroll = $true; $page.AutoScrollMinSize = [Drawing.Size]::new(0,0) }','''foreach ($page in @($tabGenerate,$tabExtra,$tabComponents,$tabCombine,$tabDescriptions)) {
            $page.AutoScrollMinSize = [Drawing.Size]::new(0,0)
            $page.AutoScroll = ($page.ClientSize.Width -lt 620 -or $page.ClientSize.Height -lt 360)
        }''','rolagem por necessidade')

c+='\n# GERAL2_ETAPA2_GENERATOR_V02150\n'
g+='\n# GERAL2_ETAPA2_GENERATOR_NAV_V03715\n'
for m in ('$script:AppVersion = "0.21.50"','$script:GeneratorVersion = "3.7.15"','GERAL2_ETAPA2_GENERATOR_V02150'):
    if m not in c: raise SystemExit('GERAL2/E2A Central marcador ausente: '+m)
for m in ('$script:AppVersion = "3.7.15"','GERAL2_ETAPA2_GENERATOR_NAV_V03715'):
    if m not in g: raise SystemExit('GERAL2/E2A Gerenciador marcador ausente: '+m)
cp.write_text(c,encoding='utf-8'); gp.write_text(g,encoding='utf-8')
print('GERAL 2 ETAPA 2A: OK - versoes, navegacao e rolagem adaptativas.')
