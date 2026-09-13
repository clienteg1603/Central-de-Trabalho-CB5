from pathlib import Path

cp = Path('src/generated/Central de Trabalho.ps1')
mp = Path('src/generated/Modulos/Central-de-Manutencao-CB5/Central Manutencao CB5.ps1')

c = cp.read_text(encoding='utf-8-sig')
m = mp.read_text(encoding='utf-8-sig')


def one(text, old, new, label):
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'UI FIT MAINT UPDATE {label}: esperado 1, encontrado {count}')
    return text.replace(old, new, 1)

# O módulo muda porque a correção é de geometria real da tela Nova Passagem.
c = one(c, '$script:MaintenanceVersion = "0.6.15"', '$script:MaintenanceVersion = "0.6.16"', 'versao Central')
m = one(m, '$script:AppVersion = "0.6.15"', '$script:AppVersion = "0.6.16"', 'versao modulo')

# A matriz visual encontrou no notebook 1366x768 o texto de "Atualização / próxima etapa"
# precisando de ~60 px, mas recebendo só 47 px. A linha lateral passa a reservar altura
# suficiente em todos os perfis, retirando o espaço apenas da área elástica do histórico.
m = one(
    m,
    '$side = @(48, 94, 30, 30, 84)',
    '$side = @(48, 110, 30, 30, 84)',
    'altura atualização Tight'
)
m = one(
    m,
    '$side = @(52, 102, 34, 34, 94)',
    '$side = @(52, 120, 34, 34, 94)',
    'altura atualização Compact'
)
m = one(
    m,
    '$side = @(58, 112, 38, 38, 104)',
    '$side = @(58, 130, 38, 38, 104)',
    'altura atualização Comfortable'
)

# Reduz somente o padding vertical do aviso; o texto continua completo, sem elipse.
m = one(
    m,
    '$updateInfo.Padding = [Windows.Forms.Padding]::new(9, 6, 9, 6)',
    '$updateInfo.Padding = [Windows.Forms.Padding]::new(9, 4, 9, 4)',
    'padding updateInfo'
)

# Mantém explicitamente a exibição integral do aviso, que pode ocupar múltiplas linhas.
if '$updateInfo.AutoEllipsis = $false' not in m:
    raise SystemExit('UI FIT MAINT UPDATE: contrato AutoEllipsis ausente')

c += '\n# POS_GERAL2_MAINTENANCE_UPDATEINFO_FIT_V02157\n'
m += '\n# POS_GERAL2_MAINTENANCE_UPDATEINFO_FIT_V00616\n'

for marker in ('$script:MaintenanceVersion = "0.6.16"', 'POS_GERAL2_MAINTENANCE_UPDATEINFO_FIT_V02157'):
    if marker not in c:
        raise SystemExit('UI FIT MAINT UPDATE Central marcador ausente: ' + marker)
for marker in ('$script:AppVersion = "0.6.16"', '$side = @(52, 120, 34, 34, 94)', '$updateInfo.Padding = [Windows.Forms.Padding]::new(9, 4, 9, 4)', 'POS_GERAL2_MAINTENANCE_UPDATEINFO_FIT_V00616'):
    if marker not in m:
        raise SystemExit('UI FIT MAINT UPDATE marcador ausente: ' + marker)

cp.write_text(c, encoding='utf-8')
mp.write_text(m, encoding='utf-8')
print('POS-GERAL 2 MAINT UPDATE FIT: OK - aviso de próxima etapa recebe altura real suficiente em notebook, janela maximizada e DPI alto.')
