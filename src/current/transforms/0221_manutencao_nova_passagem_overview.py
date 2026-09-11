from pathlib import Path

ROOT = Path('.')
MAINT = ROOT / 'src/generated/Modulos/Central-de-Manutencao-CB5/Central Manutencao CB5.ps1'
CENTRAL = ROOT / 'src/generated/Central de Trabalho.ps1'


def read(path):
    return path.read_text(encoding='utf-8-sig')


def write(path, text):
    path.write_text(text, encoding='utf-8')


def rep(text, old, new, label):
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'Ajuste Nova Passagem: marcador inesperado em {label}: {count}')
    return text.replace(old, new, 1)


maint = read(MAINT)
central = read(CENTRAL)

maint = rep(
    maint,
    '            if (-not $isPassage -and $shellH -ge 650) {',
    '            if ($shellH -ge 650) {',
    'visibilidade do resumo na Nova Passagem'
)
maint = rep(maint, '$script:AppVersion = "0.6.1"', '$script:AppVersion = "0.6.2"', 'versão da manutenção')
central = rep(central, '$script:AppVersion = "0.21.11"', '$script:AppVersion = "0.21.12"', 'versão da Central')
central = rep(central, '$script:MaintenanceVersion = "0.6.1"', '$script:MaintenanceVersion = "0.6.2"', 'versão da manutenção na Central')

write(MAINT, maint)
write(CENTRAL, central)

check = read(MAINT)
if 'if (-not $isPassage -and $shellH -ge 650)' in check:
    raise SystemExit('Ajuste Nova Passagem não foi aplicado.')
if 'if ($shellH -ge 650) {' not in check:
    raise SystemExit('Condição responsiva esperada não encontrada após o ajuste.')
print('MANUTENÇÃO CB5: OK — Nova Passagem mantém o resumo visível, igual às demais seções.')
