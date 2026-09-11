from pathlib import Path
p=Path('src/generated/Modulos/Controle-NF-Entrada/Controle NF Entrada.ps1')
s=p.read_text(encoding='utf-8-sig')
old='[string]$event.Produto'
new='(Get-NFEntradaProductDisplayName ([string]$event.Produto))'
if s.count(old) < 2: raise SystemExit('Etapa 4: referências de produto no histórico não encontradas')
s=s.replace(old,new)
p.write_text(s,encoding='utf-8')
print('Rótulos de histórico ajustados para CB5')
