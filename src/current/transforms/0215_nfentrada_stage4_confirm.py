from pathlib import Path
p=Path('src/generated/Modulos/Controle-NF-Entrada/Controle NF Entrada.ps1')
s=p.read_text(encoding='utf-8-sig')
old='de $product?`r`n`r`nEssa ação altera somente a base local'
new='de $(Get-NFEntradaProductDisplayName $product)?`r`n`r`nEssa ação altera somente a base local'
if old not in s: raise SystemExit('Etapa 4: confirmação não encontrada')
s=s.replace(old,new,1)
p.write_text(s,encoding='utf-8')
