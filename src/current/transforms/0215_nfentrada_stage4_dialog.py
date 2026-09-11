from pathlib import Path
p=Path('src/generated/Modulos/Controle-NF-Entrada/Controle NF Entrada.ps1')
s=p.read_text(encoding='utf-8-sig')
old='$dialog.Text = if ($null -eq $Existing) { "Novo registro — $Product" } else { "Editar registro — $Product" }'
new='$displayProduct = Get-NFEntradaProductDisplayName $Product\n    $dialog.Text = if ($null -eq $Existing) { "Novo registro — $displayProduct" } else { "Editar registro — $displayProduct" }'
if old not in s: raise SystemExit('Etapa 4: título do diálogo não encontrado')
s=s.replace(old,new,1)
p.write_text(s,encoding='utf-8')
print('Títulos de diálogo ajustados para CB5')
