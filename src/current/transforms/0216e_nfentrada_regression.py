from pathlib import Path
p=Path('src/ci/regression_contracts.py')
s=p.read_text(encoding='utf-8-sig')
needle='    # ATUALIZADOR — preserva núcleo, hash do pacote, arquivos ocultos e recuperação real.\n'
block='''    require_function(errors, nf_core, "Register-NFEntradaOutput", "NFEntrada.Core / saída assistida")\n    for marker in ('REGISTRAR SAÍDA', 'Register-NFOutputFromUI', '"Saida" { "Saída" }', '[Windows.Forms.Keys]::N', '[Windows.Forms.Keys]::Enter'):\n        require(errors, nf, marker, "NF Entrada / etapa 4 operacional")\n    require(errors, nf_core, '-Tipo "Saida"', "NFEntrada.Core / histórico da saída")\n\n'''
if needle not in s: raise SystemExit('ponto de regressao ausente')
s=s.replace(needle,block+needle,1)
p.write_text(s,encoding='utf-8')
print('regressao etapa 4 aplicada')
