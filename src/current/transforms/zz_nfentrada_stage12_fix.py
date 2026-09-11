from pathlib import Path

path = Path('src/generated/Modulos/Controle-NF-Entrada/Controle NF Entrada.ps1')
text = path.read_text(encoding='utf-8-sig')
old = 'Set-NFStatus ("Falha ao exportar $Title: " + $_.Exception.Message) "Error"'
new = 'Set-NFStatus ("Falha ao exportar ${Title}: " + $_.Exception.Message) "Error"'
count = text.count(old)
if count != 1:
    raise SystemExit(f'Etapa 12 fix: marcador inesperado: {count}')
text = text.replace(old, new, 1)
path.write_text(text, encoding='utf-8')
print('ETAPA 12 FIX: OK - interpolação com dois-pontos corrigida para PowerShell.')
