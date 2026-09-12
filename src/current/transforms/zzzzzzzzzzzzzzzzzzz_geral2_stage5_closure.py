from pathlib import Path
import subprocess
import sys

central_path = Path('src/generated/Central de Trabalho.ps1')
central = central_path.read_text(encoding='utf-8-sig')

old = '$script:AppVersion = "0.21.52"'
new = '$script:AppVersion = "0.21.53"'
count = central.count(old)
if count != 1:
    raise SystemExit(f'GERAL2/E5 versao Central: esperado 1 marcador, encontrado {count}')
central = central.replace(old, new, 1)
central += '\n# GERAL2_ETAPA5_FECHAMENTO_V02153\n'

for marker in (
    '$script:AppVersion = "0.21.53"',
    'GERAL2_ETAPA1_CENTRAL_RESPONSIVA_V02149',
    'GERAL2_ETAPA2_GENERATOR_V02150',
    'GERAL2_ETAPA3_MANUTENCAO_V02151',
    'GERAL2_ETAPA4_NF_V02152',
    'GERAL2_ETAPA5_FECHAMENTO_V02153',
):
    if marker not in central:
        raise SystemExit('GERAL2/E5 marcador ausente na Central: ' + marker)

central_path.write_text(central, encoding='utf-8')

# A Etapa 5 é o fechamento cruzado da GERAL 2. Em vez de alterar novamente os
# módulos que acabaram de ser estabilizados, roda um contrato específico sobre
# o resultado final de todas as transformações.
subprocess.run(
    [sys.executable, 'src/ci/geral2_responsive_contracts.py', 'src/generated'],
    check=True,
)

print('GERAL 2 ETAPA 5: OK - fechamento cruzado responsivo concluido sem reabrir regras funcionais dos modulos.')
