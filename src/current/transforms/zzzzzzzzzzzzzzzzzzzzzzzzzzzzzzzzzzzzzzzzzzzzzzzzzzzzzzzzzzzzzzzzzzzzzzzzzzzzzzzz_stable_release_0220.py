from pathlib import Path

p = Path('src/generated/Central de Trabalho.ps1')
s = p.read_text(encoding='utf-8-sig')
old = '$script:AppVersion = "0.21.69"'
new = '$script:AppVersion = "0.22.0"'
count = s.count(old)
if count != 1:
    raise SystemExit(f'RELEASE 0.22.0: esperado 1 AppVersion 0.21.69, encontrado {count}')
s = s.replace(old, new, 1)
marker = '# CENTRAL_STABLE_RELEASE_V0220'
if marker not in s:
    s += '\n' + marker + '\n'
for required in (
    '$script:AppVersion = "0.22.0"',
    '$script:GeneratorVersion = "3.7.21"',
    '$script:MaintenanceVersion = "0.6.18"',
    '$script:NFEntradaVersion = "2.6.25"',
    'CENTRAL_RESTORE_LIVE_HOST_REDRAW_STAGE3_V02169',
):
    if required not in s:
        raise SystemExit('RELEASE 0.22.0 marcador ausente: ' + required)
p.write_text(s, encoding='utf-8')
print('RELEASE 0.22.0: OK - mesma base validada da v0.21.69, somente promovida para a linha Estavel 0.22.0.')
