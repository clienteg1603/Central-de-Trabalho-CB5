from pathlib import Path
import json

central=Path('src/generated/Central de Trabalho.ps1')
s=central.read_text(encoding='utf-8-sig')
for old,new in [('$script:AppVersion = "0.21.4"','$script:AppVersion = "0.21.5"'),('$script:NFEntradaVersion = "1.3.0"','$script:NFEntradaVersion = "1.4.0"')]:
    if old not in s: raise SystemExit('Etapa 4: versão não encontrada: '+old)
    s=s.replace(old,new,1)
central.write_text(s,encoding='utf-8')

reg=Path('src/ci/regression_contracts.py')
r=reg.read_text(encoding='utf-8-sig')
needle='''    # ATUALIZADOR — preserva núcleo, hash do pacote, arquivos ocultos e recuperação real.\n'''
block='''    for marker in ('COMPUTADOR DE BORDO CB5', '$statusFilter.SelectedIndex = 1', '$mainTabs.SelectedTab = $computerTab'):\n        require(errors, nf, marker, "NF Entrada / fluxo diário etapa 4")\n    require(errors, nf_core, 'function Get-NFEntradaProductDisplayName', "NFEntrada.Core / nome visível CB5")\n    require_regex(errors, nf, r'\\$mainTabs\\.TabPages\\.Add\\(\\$computerTab\\).{0,900}\\$mainTabs\\.TabPages\\.Add\\(\\$keyboardTab\\).{0,900}\\$mainTabs\\.TabPages\\.Add\\(\\$historyTab\\).{0,900}\\$mainTabs\\.TabPages\\.Add\\(\\$securityTab\\).{0,900}\\$mainTabs\\.TabPages\\.Add\\(\\$summaryTab\\)', "NF Entrada / resumo por último")\n\n'''
if needle not in r: raise SystemExit('Etapa 4: ponto de regressão não encontrado')
r=r.replace(needle,block+needle,1)
reg.write_text(r,encoding='utf-8')

meta={'version':'0.21.5','buildRevision':1,'releaseNotes':[
'Etapa 4 do Controle de NF de Entrada: prioriza o fluxo diário de inclusão e edição.',
'A ordem das abas passa a ser Computador de Bordo CB5, Teclado V5, Histórico, Segurança e Resumo; Resumo fica por último.',
'O nome visível é corrigido para Computador de Bordo CB5, mantendo a chave interna antiga somente para compatibilidade com a base e o modelo Excel existentes.',
'Ao abrir o módulo, Computador de Bordo CB5 fica selecionado diretamente.',
'Computador de Bordo CB5 e Teclado V5 iniciam com o filtro Status em Em estoque; os demais estados continuam disponíveis no filtro.',
'Histórico, backups, restauração protegida, importação e exportação fiel à planilha original permanecem preservados.',
'Controle de NF de Entrada passa para v1.4.0; Gerenciador de Planilhas permanece v3.7.3 e Central de Manutenção permanece v0.6.1.',
'A versão Estável permanece v0.20.2; a v0.21.5 é publicada somente no canal Teste.'
]}
Path('src/current/version.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('Metadados etapa 4 aplicados')
