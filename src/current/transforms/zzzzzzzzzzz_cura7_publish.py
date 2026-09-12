from pathlib import Path

central_path = Path('src/generated/Central de Trabalho.ps1')
central = central_path.read_text(encoding='utf-8-sig')

old = '$script:AppVersion = "0.21.42"'
new = '$script:AppVersion = "0.21.43"'
count = central.count(old)
if count != 1:
    raise SystemExit(f'CURA 7: esperado 1 marcador de versão 0.21.42, encontrado {count}')
central = central.replace(old, new, 1)

# A CURA 7 é uma publicação de fechamento e validação do conjunto já aprovado.
# As versões dos três módulos permanecem inalteradas porque não houve mudança
# funcional neles durante a auditoria final.
for marker in (
    '$script:GeneratorVersion = "3.7.14"',
    '$script:MaintenanceVersion = "0.6.10"',
    '$script:NFEntradaVersion = "2.6.12"',
):
    if marker not in central:
        raise SystemExit('CURA 7: versão esperada de módulo ausente: ' + marker)

central += '\n# CURA7_FECHAMENTO_PUBLICADO_V02143\n'
central_path.write_text(central, encoding='utf-8')
print('CURA 7: fechamento preparado para publicação na Central v0.21.43.')
