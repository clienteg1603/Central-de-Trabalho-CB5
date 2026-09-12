from pathlib import Path

path = Path('src/generated/Central de Trabalho.ps1')
text = path.read_text(encoding='utf-8-sig')


def one(old: str, new: str, label: str) -> None:
    global text
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'GERAL 2 ETAPA 1 {label}: esperado 1 marcador, encontrado {count}')
    text = text.replace(old, new, 1)


# ---------------------------------------------------------------------------
# GERAL 2 / ETAPA 1 — casca responsiva da Central.
# Esta etapa mexe somente no host principal. Os três módulos serão tratados nas
# etapas seguintes para manter cada publicação pequena, testável e reversível.
# ---------------------------------------------------------------------------
one('$script:AppVersion = "0.21.48"', '$script:AppVersion = "0.21.49"', 'versao Central')

# O antigo SizeChanged atualizava apenas parte da casca. Ao arrastar a janela,
# maximizar/restaurar ou trocar DPI, dashboard e módulo hospedado podiam receber
# geometrias em momentos diferentes. A nova passagem é centralizada e debounced.
old_resize = '''$form.Add_Shown({ Update-CentralAdaptiveLayout; Update-ResponsiveLayout; Apply-CentralTheme; Update-CentralAvailabilityState })
$form.Add_SizeChanged({
    try { Update-CentralAdaptiveLayout } catch {}
})'''
new_resize = r'''$script:CentralResponsiveTimer = New-Object Windows.Forms.Timer
$script:CentralResponsiveTimer.Interval = 70
$script:CentralResponsiveTimer.Add_Tick({
    $script:CentralResponsiveTimer.Stop()
    try { Invoke-CentralResponsivePass } catch {}
})

function Invoke-CentralResponsivePass {
    if ($null -eq $form -or $form.IsDisposed) { return }
    try {
        Update-CentralAdaptiveLayout
        Update-CentralChromeLayout

        if ($script:ActiveNavName -eq "Home") {
            Update-ResponsiveLayout
        }
        else {
            # O módulo hospedado usa Dock=Fill, mas uma passagem explícita após a
            # mudança de viewport evita texto/campos presos ao tamanho anterior.
            try {
                if ($null -ne $embeddedContent) {
                    $embeddedContent.PerformLayout()
                    $embeddedContent.Invalidate($true)
                }
            } catch {}
            try {
                if ($null -ne $script:HostedForm -and -not $script:HostedForm.IsDisposed) {
                    $script:HostedForm.PerformLayout()
                    $script:HostedForm.Invalidate($true)
                }
            } catch {}
        }

        $state = if ($form.WindowState -eq [Windows.Forms.FormWindowState]::Maximized) { "Maximizada" } else { "Normal" }
        $script:CentralViewportMode = "{0}/{1}" -f $state, $script:CentralAdaptiveProfile
    }
    catch {}
}

function Schedule-CentralResponsivePass {
    try {
        if ($null -eq $script:CentralResponsiveTimer) { return }
        $script:CentralResponsiveTimer.Stop()
        $script:CentralResponsiveTimer.Start()
    } catch {}
}

$form.Add_Shown({ Invoke-CentralResponsivePass; Apply-CentralTheme; Update-CentralAvailabilityState })
$form.Add_SizeChanged({ Schedule-CentralResponsivePass })
try { $form.Add_ResizeEnd({ Invoke-CentralResponsivePass }) } catch {}
try { $form.Add_DpiChanged({ Schedule-CentralResponsivePass }) } catch {}'''
one(old_resize, new_resize, 'passagem responsiva unificada')

# Em largura compacta, libera um pouco mais de área útil para o conteúdo sem
# descaracterizar a navegação lateral. Balanced/Comfortable permanecem iguais.
one(
    '''            "Compact" {
                $rootLayout.ColumnStyles[0].Width = 174
                $sidebar.Padding = [Windows.Forms.Padding]::new(10, 12, 10, 10)''',
    '''            "Compact" {
                $rootLayout.ColumnStyles[0].Width = 158
                $sidebar.Padding = [Windows.Forms.Padding]::new(8, 10, 8, 9)''',
    'sidebar compacta'
)

# O autoteste já tinha três tamanhos. Acrescenta o limiar mínimo de uso para
# impedir regressão justamente quando a janela deixa de estar maximizada.
one(
    '''    $layoutCases = @(
        (Assert-CentralDashboardLayout ([Drawing.Size]::new(980, 640)) 'Central/compact'),''',
    '''    $layoutCases = @(
        (Assert-CentralDashboardLayout ([Drawing.Size]::new(900, 620)) 'Central/minimum'),
        (Assert-CentralDashboardLayout ([Drawing.Size]::new(980, 640)) 'Central/compact'),''',
    'autoteste em viewport minima'
)

# Fecha o timer junto com a Central para não deixar recurso WinForms pendente.
close_marker = '''$form.Add_FormClosed({
    try { Close-CentralSingleInstanceMutex } catch {}
})'''
if close_marker in text:
    one(
        close_marker,
        '''$form.Add_FormClosed({
    try {
        if ($null -ne $script:CentralResponsiveTimer) {
            $script:CentralResponsiveTimer.Stop()
            $script:CentralResponsiveTimer.Dispose()
            $script:CentralResponsiveTimer = $null
        }
    } catch {}
    try { Close-CentralSingleInstanceMutex } catch {}
})''',
        'limpeza do timer responsivo'
    )

text += '\n# GERAL2_ETAPA1_CENTRAL_RESPONSIVA_V02149\n'

for marker in (
    '$script:AppVersion = "0.21.49"',
    'function Invoke-CentralResponsivePass',
    'function Schedule-CentralResponsivePass',
    '$script:CentralViewportMode = "{0}/{1}" -f $state, $script:CentralAdaptiveProfile',
    '$rootLayout.ColumnStyles[0].Width = 158',
    "Central/minimum",
    'GERAL2_ETAPA1_CENTRAL_RESPONSIVA_V02149',
):
    if marker not in text:
        raise SystemExit('GERAL 2 ETAPA 1: marcador ausente: ' + marker)

path.write_text(text, encoding='utf-8')
print('GERAL 2 ETAPA 1: OK - resize/maximizar/restaurar/DPI passam por uma unica rotina responsiva e viewport compacta ganha mais area util.')
