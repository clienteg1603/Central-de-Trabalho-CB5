from pathlib import Path

p=Path('src/generated/Modulos/Controle-NF-Entrada/NFEntrada.Core.ps1')
s=p.read_text(encoding='utf-8-sig')
anchor='function Get-NFEntradaDefaultDataDirectory {\n'
helper='''function Get-NFEntradaProductDisplayName {
    param([string]$Product)
    if ([string]::Equals($Product, "COMPUTADOR DE BORDO V5", [StringComparison]::OrdinalIgnoreCase)) { return "COMPUTADOR DE BORDO CB5" }
    return $Product
}

'''
if anchor not in s: raise SystemExit('Etapa 4: anchor core ausente')
s=s.replace(anchor,helper+anchor,1)
old='throw "A NF de Entrada $nf já está cadastrada em $Product."'
new='throw "A NF de Entrada $nf já está cadastrada em $(Get-NFEntradaProductDisplayName $Product)."'
if old not in s: raise SystemExit('Etapa 4: mensagem duplicada ausente')
s=s.replace(old,new,1)
p.write_text(s,encoding='utf-8')
print('Core etapa 4 aplicado')
