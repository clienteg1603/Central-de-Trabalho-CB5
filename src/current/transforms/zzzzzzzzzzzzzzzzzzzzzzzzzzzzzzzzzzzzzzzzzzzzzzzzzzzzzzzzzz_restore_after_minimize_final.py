from pathlib import Path

p = Path('src/generated/Central de Trabalho.ps1')
s = p.read_text(encoding='utf-8-sig')


def one(old, new, label):
    global s
    count = s.count(old)
    if count != 1:
        raise SystemExit(f'RESTORE AFTER MINIMIZE FINAL {label}: esperado 1, encontrado {count}')
    s = s.replace(old, new, 1)


one('$script:AppVersion = "0.21.64"', '$script:AppVersion = "0.21.66"', 'versao Central')

# Não permitir que a passagem responsiva meça a janela enquanto o Windows a
# mantém minimizada ou durante a estabilização da restauração.
one(
'''function Invoke-CentralResponsivePass {
    if ($null -eq $form -or $form.IsDisposed) { return }''',
'''function Invoke-CentralResponsivePass {
    if ($null -eq $form -or $form.IsDisposed) { return }
    if ($form.WindowState -eq [Windows.Forms.FormWindowState]::Minimized) { return }
    if ($script:CentralRestoreInProgress) { return }''',
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
        if ($script:CentralRestoreInProgress) { return }
        $script:CentralResponsiveTimer.Start()
    } catch {}
}''',
'nao agendar enquanto minimizada/restaurando'
)

restore_block = r'''

# RESTORE AFTER MINIMIZE — a árvore de layout é suspensa enquanto a janela está
# minimizada. Ao restaurar, nenhuma passagem responsiva é executada com o
# ClientSize transitório do Windows: esperamos a área cliente estabilizar e só
# então retomamos o layout e calculamos a interface uma única vez.
$script:CentralLastWindowState = $form.WindowState
$script:CentralRestoreInProgress = $false
$script:CentralRestoreLayoutSuspended = $false
$script:CentralRestoreStableTicks = 0
$script:CentralRestoreElapsedTicks = 0
$script:CentralRestoreLastClientSize = [Drawing.Size]::Empty

function Suspend-CentralRestoreLayout {
    try {
        if ($script:CentralRestoreLayoutSuspended) { return }
        $form.SuspendLayout()
        $rootLayout.SuspendLayout()
        $sidebar.SuspendLayout()
        $mainPanel.SuspendLayout()
        if ($embeddedHost.Visible) { $embeddedHost.SuspendLayout() }
        $script:CentralRestoreLayoutSuspended = $true
    } catch {}
}

function Resume-CentralRestoreLayout {
    try {
        if (-not $script:CentralRestoreLayoutSuspended) { return }
        if ($embeddedHost.Visible) { $embeddedHost.ResumeLayout($false) }
        $mainPanel.ResumeLayout($false)
        $sidebar.ResumeLayout($false)
        $rootLayout.ResumeLayout($false)
        $form.ResumeLayout($false)
    } catch {}
    finally {
        $script:CentralRestoreLayoutSuspended = $false
    }
}

function Complete-CentralRestoreAfterMinimize {
    try {
        if ($null -eq $form -or $form.IsDisposed) { return }
        if ($form.WindowState -eq [Windows.Forms.FormWindowState]::Minimized) { return }

        Resume-CentralRestoreLayout
        $script:CentralRestoreInProgress = $false

        Invoke-CentralResponsivePass
        try { $form.PerformLayout() } catch {}
        try { $rootLayout.PerformLayout() } catch {}
        try { $sidebar.PerformLayout() } catch {}
        try { $mainPanel.PerformLayout() } catch {}
        try {
            if ($embeddedHost.Visible) { $embeddedHost.PerformLayout() }
        } catch {}
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
        try { $form.Invalidate($true) } catch {}
    }
    catch {
        Resume-CentralRestoreLayout
        $script:CentralRestoreInProgress = $false
        try { Invoke-CentralResponsivePass } catch {}
    }
}

$script:CentralRestoreTimer = New-Object Windows.Forms.Timer
$script:CentralRestoreTimer.Interval = 35
$script:CentralRestoreTimer.Add_Tick({
    try {
        if ($null -eq $form -or $form.IsDisposed) {
            $script:CentralRestoreTimer.Stop()
            return
        }

        if ($form.WindowState -eq [Windows.Forms.FormWindowState]::Minimized) {
            $script:CentralRestoreTimer.Stop()
            return
        }

        $script:CentralRestoreElapsedTicks++
        $currentSize = $form.ClientSize

        if ($currentSize.Width -le 0 -or $currentSize.Height -le 0) {
            $script:CentralRestoreStableTicks = 0
            $script:CentralRestoreLastClientSize = $currentSize
            return
        }

        if (
            $currentSize.Width -eq $script:CentralRestoreLastClientSize.Width -and
            $currentSize.Height -eq $script:CentralRestoreLastClientSize.Height
        ) {
            $script:CentralRestoreStableTicks++
        }
        else {
            $script:CentralRestoreStableTicks = 0
            $script:CentralRestoreLastClientSize = $currentSize
        }

        # Dois ciclos iguais (~70 ms) substituem o atraso fixo de 180 ms.
        # O limite de oito ciclos (~280 ms) funciona apenas como saída segura
        # caso um driver continue notificando pequenas mudanças de viewport.
        if ($script:CentralRestoreStableTicks -ge 2 -or $script:CentralRestoreElapsedTicks -ge 8) {
            $script:CentralRestoreTimer.Stop()
            Complete-CentralRestoreAfterMinimize
        }
    }
    catch {
        $script:CentralRestoreTimer.Stop()
        Resume-CentralRestoreLayout
        $script:CentralRestoreInProgress = $false
        try { Invoke-CentralResponsivePass } catch {}
        try { $form.Invalidate($true) } catch {}
    }
})

function Repair-CentralAfterWindowRestore {
    try {
        if ($null -eq $form -or $form.IsDisposed) { return }
        $currentState = $form.WindowState

        if ($currentState -eq [Windows.Forms.FormWindowState]::Minimized) {
            $script:CentralLastWindowState = $currentState
            $script:CentralRestoreInProgress = $true
            try { $script:CentralResponsiveTimer.Stop() } catch {}
            try { $script:CentralRestoreTimer.Stop() } catch {}
            Suspend-CentralRestoreLayout
            return
        }

        $wasMinimized = ($script:CentralLastWindowState -eq [Windows.Forms.FormWindowState]::Minimized)
        $script:CentralLastWindowState = $currentState
        if (-not $wasMinimized) { return }

        try { $script:CentralResponsiveTimer.Stop() } catch {}
        try { $script:CentralRestoreTimer.Stop() } catch {}

        $script:CentralRestoreInProgress = $true
        $script:CentralRestoreStableTicks = 0
        $script:CentralRestoreElapsedTicks = 0
        $script:CentralRestoreLastClientSize = $form.ClientSize
        $script:CentralRestoreTimer.Start()
    } catch {
        Resume-CentralRestoreLayout
        $script:CentralRestoreInProgress = $false
    }
}

$form.Add_Resize({ Repair-CentralAfterWindowRestore })
$form.Add_Activated({
    try {
        if ($form.WindowState -ne [Windows.Forms.FormWindowState]::Minimized) {
            Repair-CentralAfterWindowRestore
            if (-not $script:CentralRestoreInProgress) {
                Schedule-CentralResponsivePass
            }
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
    try { Resume-CentralRestoreLayout } catch {}
    $script:CentralRestoreInProgress = $false
})
# CENTRAL_RESTORE_STABLE_VIEWPORT_V02166
'''

for marker in (
    '$script:AppVersion = "0.21.66"',
    'if ($script:CentralRestoreInProgress) { return }',
    'function Suspend-CentralRestoreLayout',
    'function Complete-CentralRestoreAfterMinimize',
    '$script:CentralRestoreTimer.Interval = 35',
    '$script:CentralRestoreStableTicks -ge 2',
    'Suspend-CentralRestoreLayout',
    'CENTRAL_RESTORE_STABLE_VIEWPORT_V02166',
):
    if marker not in s:
        raise SystemExit('RESTORE AFTER MINIMIZE FINAL marcador ausente: ' + marker)

p.write_text(s, encoding='utf-8')
print('RESTORE AFTER MINIMIZE FINAL: OK - layout fica suspenso ao minimizar e só é retomado após o viewport restaurado estabilizar.')
