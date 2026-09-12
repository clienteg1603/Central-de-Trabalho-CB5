from pathlib import Path

R = Path('src/generated')

def load(p): return p.read_text(encoding='utf-8-sig')
def save(p,s): p.write_text(s, encoding='utf-8')
def one(s, old, new, label):
    n=s.count(old)
    if n!=1: raise SystemExit(f'CURA2 versões {label}: esperado 1, encontrado {n}')
    return s.replace(old,new,1)

p=R/'Central de Trabalho.ps1'
s=load(p)
s=one(s,'$script:AppVersion = "0.21.31"','$script:AppVersion = "0.21.32"','Central')
s=one(s,'$script:GeneratorVersion = "3.7.8"','$script:GeneratorVersion = "3.7.9"','Gerenciador na Central')
s=one(s,'$script:MaintenanceVersion = "0.6.6"','$script:MaintenanceVersion = "0.6.7"','Manutenção na Central')
s=one(s,'$script:NFEntradaVersion = "2.6.7"','$script:NFEntradaVersion = "2.6.8"','NF na Central')
save(p,s)

p=R/'Modulos/Gerador-de-Planilhas-CB5-TV5/Gerador Planilhas.ps1'
s=load(p)
s=one(s,'$script:AppVersion = "3.7.8"','$script:AppVersion = "3.7.9"','Gerenciador')
save(p,s)

p=R/'Modulos/Central-de-Manutencao-CB5/Central Manutencao CB5.ps1'
s=load(p)
s=one(s,'$script:AppVersion = "0.6.6"','$script:AppVersion = "0.6.7"','Manutenção')
save(p,s)

p=R/'Modulos/Controle-NF-Entrada/Controle NF Entrada.ps1'
s=load(p)
s=one(s,'$script:ModuleVersion = "2.6.7"','$script:ModuleVersion = "2.6.8"','NF Entrada')
save(p,s)

print('CURA 2 versões v0.21.32 — OK')
