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
        raise SystemExit(f'GERAL2/E7 {label}: esperado 1, encontrado {count}')
    return text.replace(old, new, 1)


def at_least(text, old, new, minimum, label):
    count = text.count(old)
    if count < minimum:
        raise SystemExit(f'GERAL2/E7 {label}: esperado >= {minimum}, encontrado {count}')
    return text.replace(old, new)


# ---------------------------------------------------------------------------
# Versões — somente canal Teste.
# ---------------------------------------------------------------------------
c = one(c, '$script:AppVersion = "0.21.54"', '$script:AppVersion = "0.21.55"', 'versao Central')
c = one(c, '$script:GeneratorVersion = "3.7.15"', '$script:GeneratorVersion = "3.7.16"', 'versao Gerenciador Central')
c = one(c, '$script:MaintenanceVersion = "0.6.12"', '$script:MaintenanceVersion = "0.6.13"', 'versao Manutencao Central')
c = one(c, '$script:NFEntradaVersion = "2.6.18"', '$script:NFEntradaVersion = "2.6.19"', 'versao NF Central')
g = one(g, '$script:AppVersion = "3.7.15"', '$script:AppVersion = "3.7.16"', 'versao Gerenciador')
m = one(m, '$script:AppVersion = "0.6.12"', '$script:AppVersion = "0.6.13"', 'versao Manutencao')
n = one(n, '$script:ModuleVersion = "2.6.18"', '$script:ModuleVersion = "2.6.19"', 'versao NF')


# ---------------------------------------------------------------------------
# CENTRAL — a faixa de módulos também passa pelo debounce já criado na Etapa 1.
# Antes ela ainda recalculava o chrome a cada pixel durante o arraste da janela.
# ---------------------------------------------------------------------------
c = one(
    c,
    '$modulesFlow.Add_SizeChanged({ Update-CentralChromeLayout })',
    '$modulesFlow.Add_SizeChanged({ Schedule-CentralResponsivePass })',
    'debounce faixa de modulos Central'
)


# ---------------------------------------------------------------------------
# GERENCIADOR — reduz tempestade de layout quando o host muda de tamanho.
# ---------------------------------------------------------------------------
generator_helper = r'''
$script:GeneratorLayoutTimer = New-Object Windows.Forms.Timer
$script:GeneratorLayoutTimer.Interval = 70
$script:GeneratorLayoutTimer.Add_Tick({
    $script:GeneratorLayoutTimer.Stop()
    try { Invoke-GeneratorLayoutPass } catch {}
})

function Invoke-GeneratorLayoutPass {
    try {
        Update-GeneratorResponsiveLayout
        Update-RootLayout
    } catch {}
}

function Schedule-GeneratorLayoutPass {
    try {
        if ($null -eq $script:GeneratorLayoutTimer) { return }
        $script:GeneratorLayoutTimer.Stop()
        $script:GeneratorLayoutTimer.Start()
    } catch {}
}
'''

g = one(
    g,
    '''if ($script:IsInProcessHosted) {
    $form.MinimumSize = [Drawing.Size]::new(1, 1)''',
    generator_helper + '''
if ($script:IsInProcessHosted) {
    $form.MinimumSize = [Drawing.Size]::new(1, 1)''',
    'motor debounce Gerenciador'
)
g = one(
    g,
    '$form.Add_HandleCreated({ try { Update-GeneratorResponsiveLayout; Update-RootLayout } catch {} })',
    '$form.Add_HandleCreated({ try { Invoke-GeneratorLayoutPass } catch {} })',
    'HandleCreated Gerenciador'
)
g = one(
    g,
    '$script:GeneratorHostedShell.Add_SizeChanged({ try { Update-GeneratorResponsiveLayout; Update-RootLayout } catch {} })',
    '$script:GeneratorHostedShell.Add_SizeChanged({ Schedule-GeneratorLayoutPass })',
    'resize host Gerenciador'
)
g = one(
    g,
    '''    $form.Add_Disposed({
        try { Save-AppSettings } catch {}''',
    '''    try { $form.Add_ResizeEnd({ Invoke-GeneratorLayoutPass }) } catch {}
    $form.Add_Disposed({
        try {
            if ($null -ne $script:GeneratorLayoutTimer) {
                $script:GeneratorLayoutTimer.Stop()
                $script:GeneratorLayoutTimer.Dispose()
                $script:GeneratorLayoutTimer = $null
            }
        } catch {}
        try { Save-AppSettings } catch {}''',
    'limpeza timer Gerenciador'
)


# ---------------------------------------------------------------------------
# MANUTENÇÃO — unifica quatro fontes de resize em uma única passagem atrasada.
# A passagem imediata continua existindo no Shown/HandleCreated e no ResizeEnd.
# ---------------------------------------------------------------------------
maintenance_helper = r'''
$script:MaintenanceLayoutTimer = New-Object Windows.Forms.Timer
$script:MaintenanceLayoutTimer.Interval = 70
$script:MaintenanceLayoutTimer.Add_Tick({
    $script:MaintenanceLayoutTimer.Stop()
    try { Invoke-MaintenanceLayoutPass } catch {}
})

function Invoke-MaintenanceLayoutPass {
    try { Update-MaintenanceResponsiveLayout } catch {}
    if ($script:IsInProcessHosted) {
        try { Update-MaintenanceHostedViewport } catch {}
    }
}

function Schedule-MaintenanceLayoutPass {
    try {
        if ($null -eq $script:MaintenanceLayoutTimer) { return }
        $script:MaintenanceLayoutTimer.Stop()
        $script:MaintenanceLayoutTimer.Start()
    } catch {}
}

try { $form.Add_ResizeEnd({ Invoke-MaintenanceLayoutPass }) } catch {}
$form.Add_Disposed({
    try {
        if ($null -ne $script:MaintenanceLayoutTimer) {
            $script:MaintenanceLayoutTimer.Stop()
            $script:MaintenanceLayoutTimer.Dispose()
            $script:MaintenanceLayoutTimer = $null
        }
    } catch {}
})
'''

m = one(m, '# TECH_PAGES_V0114', maintenance_helper + '\n# TECH_PAGES_V0114', 'motor debounce Manutencao')
m = at_least(
    m,
    '$form.Add_SizeChanged({ Update-MaintenanceResponsiveLayout })',
    '$form.Add_SizeChanged({ Schedule-MaintenanceLayoutPass })',
    2,
    'resize form Manutencao'
)
m = at_least(
    m,
    'try { $form.Add_DpiChanged({ Update-MaintenanceResponsiveLayout }) } catch {}',
    'try { $form.Add_DpiChanged({ Schedule-MaintenanceLayoutPass }) } catch {}',
    1,
    'DPI Manutencao'
)
m = one(
    m,
    '$tabsViewport.Add_SizeChanged({ Update-MaintenanceHostedViewport })',
    '$tabsViewport.Add_SizeChanged({ Schedule-MaintenanceLayoutPass })',
    'viewport Manutencao'
)
m = one(
    m,
    '$script:HostedShell.Add_SizeChanged({ Update-MaintenanceHostedViewport })',
    '$script:HostedShell.Add_SizeChanged({ Schedule-MaintenanceLayoutPass })',
    'shell Manutencao'
)


# ---------------------------------------------------------------------------
# CONTROLE DE NF — o motor responsivo passa a ser debounced no Form, sem tocar
# no TabControl nativo protegido. Isso reduz redraw e cálculo repetido ao arrastar.
# ---------------------------------------------------------------------------
nf_events_old = '''$form.Add_SizeChanged({ Update-NFResponsiveLayout })
try { $form.Add_DpiChanged({ Update-NFResponsiveLayout }) } catch {}
Update-NFResponsiveLayout'''
nf_events_new = r'''$script:NFLayoutTimer = New-Object Windows.Forms.Timer
$script:NFLayoutTimer.Interval = 70
$script:NFLayoutTimer.Add_Tick({
    $script:NFLayoutTimer.Stop()
    try { Update-NFResponsiveLayout } catch {}
})

function Schedule-NFResponsiveLayout {
    try {
        if ($null -eq $script:NFLayoutTimer) { return }
        $script:NFLayoutTimer.Stop()
        $script:NFLayoutTimer.Start()
    } catch {}
}

$form.Add_SizeChanged({ Schedule-NFResponsiveLayout })
try { $form.Add_DpiChanged({ Schedule-NFResponsiveLayout }) } catch {}
try { $form.Add_ResizeEnd({ Update-NFResponsiveLayout }) } catch {}
$form.Add_Disposed({
    try {
        if ($null -ne $script:NFLayoutTimer) {
            $script:NFLayoutTimer.Stop()
            $script:NFLayoutTimer.Dispose()
            $script:NFLayoutTimer = $null
        }
    } catch {}
})
Update-NFResponsiveLayout'''
n = one(n, nf_events_old, nf_events_new, 'debounce NF')


# Marcadores e proteções.
c += '\n# GERAL2_ETAPA7_FLUIDEZ_V02155\n'
g += '\n# GERAL2_ETAPA7_GENERATOR_PERF_V03716\n'
m += '\n# GERAL2_ETAPA7_MANUTENCAO_PERF_V00613\n'
n += '\n# GERAL2_ETAPA7_NF_PERF_V02619\n'

for marker in (
    '$script:AppVersion = "0.21.55"',
    '$script:GeneratorVersion = "3.7.16"',
    '$script:MaintenanceVersion = "0.6.13"',
    '$script:NFEntradaVersion = "2.6.19"',
    '$modulesFlow.Add_SizeChanged({ Schedule-CentralResponsivePass })',
    'GERAL2_ETAPA7_FLUIDEZ_V02155',
):
    if marker not in c:
        raise SystemExit('GERAL2/E7 Central marcador ausente: ' + marker)

for marker in ('function Schedule-GeneratorLayoutPass', '$script:GeneratorHostedShell.Add_SizeChanged({ Schedule-GeneratorLayoutPass })', 'GERAL2_ETAPA7_GENERATOR_PERF_V03716'):
    if marker not in g:
        raise SystemExit('GERAL2/E7 Gerenciador marcador ausente: ' + marker)
for marker in ('function Schedule-MaintenanceLayoutPass', '$tabsViewport.Add_SizeChanged({ Schedule-MaintenanceLayoutPass })', 'GERAL2_ETAPA7_MANUTENCAO_PERF_V00613'):
    if marker not in m:
        raise SystemExit('GERAL2/E7 Manutencao marcador ausente: ' + marker)
for marker in ('function Schedule-NFResponsiveLayout', '$form.Add_SizeChanged({ Schedule-NFResponsiveLayout })', 'GERAL2_ETAPA7_NF_PERF_V02619'):
    if marker not in n:
        raise SystemExit('GERAL2/E7 NF marcador ausente: ' + marker)

for forbidden in (
    '$mainTabs.Add_SizeChanged',
    '$mainTabs.Add_HandleCreated',
    '$mainTabs.DrawMode = [Windows.Forms.TabDrawMode]::OwnerDrawFixed',
    '$mainTabs.ItemSize',
    'Update-NFMainTabStripLayout',
):
    if forbidden in n:
        raise SystemExit('GERAL2/E7 NF mecanismo proibido reapareceu: ' + forbidden)

cp.write_text(c, encoding='utf-8')
gp.write_text(g, encoding='utf-8')
mp.write_text(m, encoding='utf-8')
np.write_text(n, encoding='utf-8')
print('GERAL 2 ETAPA 7: OK - resize coalescido em Central, Gerenciador, Manutencao e NF; menos recalculo e redraw por pixel.')
