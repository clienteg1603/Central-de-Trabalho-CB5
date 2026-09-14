from pathlib import Path

p = Path('src/generated/Central de Trabalho.ps1')
s = p.read_text(encoding='utf-8-sig')


def one(old, new, label):
    global s
    count = s.count(old)
    if count != 1:
        raise SystemExit(f'RESTORE AFTER MINIMIZE FINAL {label}: esperado 1, encontrado {count}')
    s = s.replace(old, new, 1)


one('$script:AppVersion = "0.21.64"', '$script:AppVersion = "0.21.65"', 'versao Central')

# Não permitir que a passagem responsiva meça a janela enquanto o Windows a
# mantém minimizada. O ClientSize transitório nesse estado era salvo na árvore
# visual e deixava sidebar/conteúdo estreitos ao restaurar pela barra de tarefas.
one(
'''function Invoke-CentralResponsivePass {
    if ($null -eq $form -or $form.IsDisposed) { return }''',
'''function Invoke-CentralResponsivePass {
    if ($null -eq $form -or $form.IsDisposed) { return }
    if ($form.WindowState -eq [Windows.Forms.FormWindowState]::Minimized) { return }''',
'guard da passagem responsiva'
)

one(
'''function Schedule-CentralResponsivePass {
    try {
        if ($null -eq $script:CentralResponsiveTimer) { return }
        $script:CentralResponsiveTimer.Stop()
        $script:CentralResponsiveTimer.Start()
    } catch {}
}''',
'''function Schedule-CentralResponsivePass {
    try {
        if ($null -eq $script:CentralResponsiveTimer) { return }
        $script:CentralResponsiveTimer.Stop()
        if ($form.WindowState -eq [Windows.Forms.FormWindowState]::Minimized) { return }
        $script:CentralResponsiveTimer.Start()
    } catch {}
}''',
'nao agendar enquanto minimizada'
)

restore_block = r'''

# RESTORE AFTER MINIMIZE — acompanha explicitamente a transição do estado da
# janela. Uma passagem ocorre imediatamente e outra após 180 ms, quando o
# client-area já voltou ao tamanho definitivo informado pelo Windows.
$script:CentralLastWindowState = $form.WindowState
$script:CentralRestoreTimer = New-Object Windows.Forms.Timer
$script:CentralRestoreTimer.Interval = 180
$script:CentralRestoreTimer.Add_Tick({
    $script:CentralRestoreTimer.Stop()
    try {
        if ($form.WindowState -eq [Windows.Forms.FormWindowState]::Minimized) { return }
        $form.PerformLayout()
        $rootLayout.PerformLayout()
        $sidebar.PerformLayout()
        $mainPanel.PerformLayout()
        if ($embeddedHost.Visible) { $embeddedHost.PerformLayout() }
        Invoke-CentralResponsivePass
        $form.Invalidate($true)
    } catch {}
})

function Repair-CentralAfterWindowRestore {
    try {
        if ($null -eq $form -or $form.IsDisposed) { return }
        $currentState = $form.WindowState
        if ($currentState -eq [Windows.Forms.FormWindowState]::Minimized) {
            $script:CentralLastWindowState = $currentState
            try { $script:CentralResponsiveTimer.Stop() } catch {}
            try { $script:CentralRestoreTimer.Stop() } catch {}
            return
        }

        $wasMinimized = ($script:CentralLastWindowState -eq [Windows.Forms.FormWindowState]::Minimized)
        $script:CentralLastWindowState = $currentState
        if (-not $wasMinimized) { return }

        $form.PerformLayout()
        $rootLayout.PerformLayout()
        $sidebar.PerformLayout()
        $mainPanel.PerformLayout()
        if ($embeddedHost.Visible) { $embeddedHost.PerformLayout() }
        Invoke-CentralResponsivePass

        $script:CentralRestoreTimer.Stop()
        $script:CentralRestoreTimer.Start()
    } catch {}
}

$form.Add_Resize({ Repair-CentralAfterWindowRestore })
$form.Add_Activated({
    try {
        if ($form.WindowState -ne [Windows.Forms.FormWindowState]::Minimized) {
            Repair-CentralAfterWindowRestore
            Schedule-CentralResponsivePass
        }
    } catch {}
})
'''

anchor = 'try { $form.Add_DpiChanged({ Schedule-CentralResponsivePass }) } catch {}'
one(anchor, anchor + restore_block, 'eventos de restauracao')

s += r'''
$form.Add_FormClosed({
    try {
        if ($null -ne $script:CentralRestoreTimer) {
            $script:CentralRestoreTimer.Stop()
            $script:CentralRestoreTimer.Dispose()
            $script:CentralRestoreTimer = $null
        }
    } catch {}
})
# CENTRAL_RESTORE_AFTER_MINIMIZE_FINAL_V02165
'''

for marker in (
    '$script:AppVersion = "0.21.65"',
    'if ($form.WindowState -eq [Windows.Forms.FormWindowState]::Minimized) { return }',
    'function Repair-CentralAfterWindowRestore',
    '$form.Add_Resize({ Repair-CentralAfterWindowRestore })',
    '$script:CentralRestoreTimer.Interval = 180',
    'CENTRAL_RESTORE_AFTER_MINIMIZE_FINAL_V02165',
):
    if marker not in s:
        raise SystemExit('RESTORE AFTER MINIMIZE FINAL marcador ausente: ' + marker)

p.write_text(s, encoding='utf-8')
print('RESTORE AFTER MINIMIZE FINAL: OK - minimizar não mede viewport transitória; restaurar refaz sidebar, conteúdo e módulo hospedado em duas passagens.')
