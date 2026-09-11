from pathlib import Path
p=Path('src/ci/regression_contracts.py')
s=p.read_text(encoding='utf-8-sig')
needle='    # ATUALIZADOR — preserva núcleo, hash do pacote, arquivos ocultos e recuperação real.\n'
block='''    for fn in ("Get-NFEntradaMovements", "Add-NFEntradaMovement"):\n        require_function(errors, nf_core, fn, "NFEntrada.Core / movimentações estruturadas")\n    for marker in ("Movimentacoes", "MOVIMENTAÇÕES", "Refresh-NFMovements", "ABRIR NF", "MovementReference", "Open-NFFromMovement"):\n        if marker not in nf_core and marker not in nf:\n            errors.append("NF Entrada / etapa 5: marcador ausente: " + marker)\n\n'''
if needle not in s: raise SystemExit('ponto de regressao ausente')
s=s.replace(needle,block+needle,1)
p.write_text(s,encoding='utf-8')
