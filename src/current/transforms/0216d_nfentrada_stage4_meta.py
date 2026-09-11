from pathlib import Path
import json

central=Path('src/generated/Central de Trabalho.ps1')
s=central.read_text(encoding='utf-8-sig')
for a,b in [('$script:AppVersion = "0.21.5"','$script:AppVersion = "0.21.6"'),('$script:NFEntradaVersion = "1.4.0"','$script:NFEntradaVersion = "1.5.0"')]:
    if a not in s: raise SystemExit('versao ausente: '+a)
    s=s.replace(a,b,1)
central.write_text(s,encoding='utf-8')

reg=Path('src/ci/regression_contracts.py')
r=reg.read_text(encoding='utf-8-sig')
needle='    # ATUALIZADOR — preserva núcleo, hash do pacote, arquivos ocultos e recuperação real.\n'
block='''    require_function(errors, nf_core, "Register-NFEntradaOutput", "NFEntrada.Core / saída assistida")\n    for marker in ('REGISTRAR SAÍDA', 'Register-NFOutputFromUI', 'Saída de ', '"Saida" { "Saída" }', '[Windows.Forms.Keys]::N', '[Windows.Forms.Keys]::Enter'):\n        require(errors, nf, marker, "NF Entrada / etapa 4 operacional")\n\n'''
if needle not in r: raise SystemExit('ponto regressao ausente')
r=r.replace(needle,block+needle,1)
reg.write_text(r,encoding='utf-8')

meta={'version':'0.21.6','buildRevision':1,'releaseNotes':[
'Conclusão da Etapa 4 do Controle de NF de Entrada: fluxo operacional diário para incluir, editar e registrar saídas com menos digitação manual.',
'As alterações pedidas na v0.21.5 permanecem: Computador de Bordo CB5 abre primeiro, CB5 e Teclado V5 iniciam em Em estoque e Resumo continua por último.',
'Nova ação REGISTRAR SAÍDA permite escolher uma NF em estoque, informar a quantidade retirada e a NF de saída/referência; o saldo é reduzido automaticamente sem alterar a quantidade original da entrada.',
'A saída é bloqueada quando a quantidade é inválida, maior que o saldo ou quando a NF já está encerrada.',
'Cada saída recebe evento próprio no Histórico com estado anterior, estado posterior, quantidade e referência informada.',
'Atalhos nas grades: Ctrl+N abre novo registro, Enter edita a seleção e Ctrl+F leva o foco para a pesquisa.',
'As regras de importação, exportação fiel ao XLSX, histórico, backups e restauração protegida continuam preservadas.',
'Controle de NF de Entrada passa para v1.5.0; Gerenciador de Planilhas permanece v3.7.3 e Central de Manutenção permanece v0.6.1.',
'A versão Estável permanece v0.20.2; a v0.21.6 é publicada somente no canal Teste.'
]}
Path('src/current/version.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('meta etapa 4 aplicado')
