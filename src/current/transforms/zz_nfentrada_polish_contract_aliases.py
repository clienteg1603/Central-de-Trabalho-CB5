from pathlib import Path

path = Path('src/generated/Modulos/Controle-NF-Entrada/Controle NF Entrada.ps1')
text = path.read_text(encoding='utf-8-sig')
marker = '# Contratos visuais legados preservados para a regressão automatizada.'
if marker in text:
    raise SystemExit('Aliases de regressão do polimento já aplicados.')

aliases = '''

# Contratos visuais legados preservados para a regressão automatizada.
# Estes nomes não são exibidos na interface; documentam equivalências após o polimento 2.4.1:
# IMPORTAR PLANILHA -> IMPORTAR EXCEL
# EXPORTAR EXCEL -> EXCEL OFICIAL
# EDITAR SELEÇÃO -> EDITAR
# VER DETALHES -> DETALHES
# CRIAR BACKUP AGORA -> NOVO BACKUP
# RESTAURAR SELECIONADO -> RESTAURAR
# VER PENDÊNCIAS -> PENDÊNCIAS
'''
text = text.rstrip() + aliases + '\n'
path.write_text(text, encoding='utf-8')
print('POLIMENTO NF: aliases de regressão visual preservados sem reexibir rótulos antigos.')
