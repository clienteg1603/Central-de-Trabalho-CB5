from pathlib import Path

cp = Path('src/generated/Central de Trabalho.ps1')
gp = Path('src/generated/Modulos/Gerador-de-Planilhas-CB5-TV5/Gerador Planilhas.ps1')
mp = Path('src/generated/Modulos/Central-de-Manutencao-CB5/Central Manutencao CB5.ps1')
np = Path('src/generated/Modulos/Controle-NF-Entrada/Controle NF Entrada.ps1')

c = cp.read_text(encoding='utf-8-sig')
g = gp.read_text(encoding='utf-8-sig')
m = mp.read_text(encoding='utf-8-sig')
n = np.read_text(encoding='utf-8-sig')


def one(text, old, new, label):
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'GERAL2/E8 {label}: esperado 1, encontrado {count}')
    return text.replace(old, new, 1)


# Etapa 8 fecha a revisão geral. Os módulos já foram alterados nas etapas 2, 3, 4 e 7;
# aqui não há novo bump de módulo porque a mudança funcional é a auditoria final.
c = one(c, '$script:AppVersion = "0.21.55"', '$script:AppVersion = "0.21.56"', 'versao Central')

# A Etapa 1 já havia acrescentado 900x620 à matriz antiga da CURA 3. A Etapa 8
# substitui o bloco inteiro pela matriz final, incluindo o alvo literal 1366x768.
old_cases = '''    $layoutCases = @(
        (Assert-CentralDashboardLayout ([Drawing.Size]::new(900, 620)) 'Central/minimum'),
        (Assert-CentralDashboardLayout ([Drawing.Size]::new(980, 640)) 'Central/compact'),
        (Assert-CentralDashboardLayout ([Drawing.Size]::new(1260, 760)) 'Central/balanced'),
        (Assert-CentralDashboardLayout ([Drawing.Size]::new(1680, 940)) 'Central/comfortable')
    )'''
new_cases = '''    $layoutCases = @(
        (Assert-CentralDashboardLayout ([Drawing.Size]::new(900, 600)) 'Central/compacta-900x600'),
        (Assert-CentralDashboardLayout ([Drawing.Size]::new(1180, 700)) 'Central/intermediaria-1180x700'),
        (Assert-CentralDashboardLayout ([Drawing.Size]::new(1366, 768)) 'Central/notebook-1366x768'),
        (Assert-CentralDashboardLayout ([Drawing.Size]::new(1600, 900)) 'Central/ampla-1600x900'),
        (Assert-CentralDashboardLayout ([Drawing.Size]::new(1920, 1080)) 'Central/fullhd-1920x1080')
    )'''
c = one(c, old_cases, new_cases, 'matriz de tamanhos da Central')

c += '\n# GERAL2_ETAPA8_MATRIZ_FINAL_V02156\n'

required_central = (
    '$script:AppVersion = "0.21.56"',
    '$script:GeneratorVersion = "3.7.16"',
    '$script:MaintenanceVersion = "0.6.13"',
    '$script:NFEntradaVersion = "2.6.19"',
    'Central/compacta-900x600',
    'Central/notebook-1366x768',
    'Central/fullhd-1920x1080',
    'GERAL2_ETAPA7_FLUIDEZ_V02155',
    'GERAL2_ETAPA8_MATRIZ_FINAL_V02156',
)
for marker in required_central:
    if marker not in c:
        raise SystemExit('GERAL2/E8 Central marcador ausente: ' + marker)

for text, label, markers in (
    (g, 'Gerenciador', ('$script:AppVersion = "3.7.16"', 'function Schedule-GeneratorLayoutPass', 'GERAL2_ETAPA7_GENERATOR_PERF_V03716')),
    (m, 'Manutencao', ('$script:AppVersion = "0.6.13"', 'function Schedule-MaintenanceLayoutPass', 'GERAL2_ETAPA7_MANUTENCAO_PERF_V00613')),
    (n, 'NF', ('$script:ModuleVersion = "2.6.19"', 'function Schedule-NFResponsiveLayout', 'GERAL2_ETAPA7_NF_PERF_V02619')),
):
    for marker in markers:
        if marker not in text:
            raise SystemExit(f'GERAL2/E8 {label} marcador ausente: {marker}')

for forbidden in (
    '$mainTabs.Add_SizeChanged',
    '$mainTabs.Add_HandleCreated',
    '$mainTabs.DrawMode = [Windows.Forms.TabDrawMode]::OwnerDrawFixed',
    '$mainTabs.ItemSize',
    'Update-NFMainTabStripLayout',
):
    if forbidden in n:
        raise SystemExit('GERAL2/E8 NF mecanismo proibido reapareceu: ' + forbidden)

cp.write_text(c, encoding='utf-8')
print('GERAL 2 ETAPA 8: OK - Central ampliada para matriz 900x600, 1180x700, 1366x768, 1600x900 e 1920x1080; versões e proteções finais preservadas.')
