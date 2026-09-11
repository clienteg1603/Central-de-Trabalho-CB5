from pathlib import Path
central=Path('src/generated/Central de Trabalho.ps1')
s=central.read_text(encoding='utf-8-sig')
for a,b in [('$script:AppVersion = "0.21.9"','$script:AppVersion = "0.21.10"'),('$script:NFEntradaVersion = "1.8.0"','$script:NFEntradaVersion = "1.9.0"')]:
    if s.count(a)!=1: raise SystemExit(a)
    s=s.replace(a,b,1)
central.write_text(s,encoding='utf-8')
reg=Path('src/ci/regression_contracts.py')
r=reg.read_text(encoding='utf-8-sig')
anchor='    # ATUALIZADOR — preserva núcleo, hash do pacote, arquivos ocultos e recuperação real.\n'
block='''    require_function(errors, nf_core, "Get-NFEntradaDuplicateRecord", "NFEntrada.Core / etapa 8")\n    for marker in ('$saveAndNew', 'ContinuarCadastro', '$validateDialog', '$balanceBox.Value = $qtyBox.Value', '-DefaultDate $defaultDate', '$qtyBox.Focus()'):\n        require(errors, nf, marker, "NF Entrada / etapa 8 cadastro rapido")\n\n'''
if r.count(anchor)!=1: raise SystemExit('regression anchor')
r=r.replace(anchor,block+anchor,1)
reg.write_text(r,encoding='utf-8')
