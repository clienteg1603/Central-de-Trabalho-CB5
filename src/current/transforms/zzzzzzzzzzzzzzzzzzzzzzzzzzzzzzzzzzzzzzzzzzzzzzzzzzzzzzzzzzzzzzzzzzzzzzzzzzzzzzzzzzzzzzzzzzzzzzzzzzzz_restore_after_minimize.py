from pathlib import Path

p = Path('src/generated/Central de Trabalho.ps1')
s = p.read_text(encoding='utf-8-sig')


def one(old, new, label):
    global s
    count = s.count(old)
    if count != 1:
        raise SystemExit(f'RESTORE AFTER MINIMIZE {label}: esperado 1, encontrado {count}')
    s = s.replace(old, new, 1)


one('$script:AppVersion = "0.21.64"', '$script:AppVersion = "0.21.65"', 'versao Central')

one(
'''function Invoke-CentralResponsivePass {
    if ($null -eq $form -or $form.IsDisposed) { return }''',
'''function Invoke-CentralResponsivePass {
    if ($null -eq $form -or $form.IsDisposed) { return }
    if ($form.WindowState -eq [Windows.Forms.FormWindowState]::Minimized) { return }''',
'ignorar passagem durante minimizacao'
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

# Restauração de janela: WinForms pode disparar SizeChanged ainda com a área
# cliente transitória da janela minimizada. Isso fazia a sidebar e o conteúdo
# hospedado ficarem presos em uma geometria estreita até maximizar/restaurar.
$script:CentralLastWindowState = $form.WindowState
$script:CentralRestoreTimer = New-Object Windows.Forms.Timer
$script:CentralRestoreTimer.Interval = 180
$script:CentralRestoreTimer.Add_Tick({
    $script:CentralRestoreTimer.Stop()
    try {
        if ($form.WindowState -eq [Windows.Forms.FormWindowState]::Minimized) { return }
        $rootLayout.PerformLayout()
        $form.PerformLayout()
        Invoke-CentralResponsivePass
        try {
            if ($null -ne $embeddedContent) {
                $embeddedContent.PerformLayout()
                $embeddedContent.Invalidate($true)
            }
        } catch {}
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

        # Primeira passagem imediatamente após a restauração.
        $rootLayout.PerformLayout()
        $form.PerformLayout()
        Invoke-CentralResponsivePass

        # Segunda passagem depois de o Windows concluir a restauração do client area.
        $script:CentralRestoreTimer.Stop()
        $script:CentralRestoreTimer.Start()
    } catch {}
}

$form.Add_Resize({ Repair-CentralAfterWindowRestore })
$form.Add_Activated({
    try {
        if ($form.WindowState -ne [Windows.Forms.FormWindowState]::Minimized) {
            Schedule-CentralResponsivePass
        }
    } catch {}
})
'''

anchor = 'try { $form.Add_DpiChanged({ Schedule-CentralResponsivePass }) } catch {}'
one(anchor, anchor + restore_block, 'eventos de restauracao')

# Limpeza dedicada do timer extra.
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
# CENTRAL_RESTORE_AFTER_MINIMIZE_V02165
'''

for marker in (
    '$script:AppVersion = "0.21.65"',
    'function Repair-CentralAfterWindowRestore',
    '$form.Add_Resize({ Repair-CentralAfterWindowRestore })',
    '$script:CentralRestoreTimer.Interval = 180',
    'CENTRAL_RESTORE_AFTER_MINIMIZE_V02165',
):
    if marker not in s:
        raise SystemExit('RESTORE AFTER MINIMIZE marcador ausente: ' + marker)

p.write_text(s, encoding='utf-8')
print('RESTORE AFTER MINIMIZE: OK - minimizacao nao recalcula layout e restauracao executa duas passagens com client area estabilizada.')
