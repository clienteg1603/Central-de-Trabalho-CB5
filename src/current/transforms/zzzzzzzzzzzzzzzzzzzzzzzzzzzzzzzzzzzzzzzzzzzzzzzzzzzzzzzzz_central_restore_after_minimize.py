from pathlib import Path

p = Path('src/generated/Central de Trabalho.ps1')
s = p.read_text(encoding='utf-8-sig')

def one(a,b,n):
    global s
    c=s.count(a)
    if c!=1: raise SystemExit(f'CENTRAL RESTORE {n}: esperado 1, encontrado {c}')
    s=s.replace(a,b,1)

one('$script:AppVersion = "0.21.64"','$script:AppVersion = "0.21.65"','versao')
one('$script:CentralResponsiveTimer = New-Object Windows.Forms.Timer','$script:CentralWasMinimized = $false\n$script:CentralRestorePending = $false\n$script:CentralResponsiveTimer = New-Object Windows.Forms.Timer','estado')
one('''function Invoke-CentralResponsivePass {
    if ($null -eq $form -or $form.IsDisposed) { return }
    try {''','''function Invoke-CentralResponsivePass {
    if ($null -eq $form -or $form.IsDisposed) { return }
    if ($form.WindowState -eq [Windows.Forms.FormWindowState]::Minimized) {
        $script:CentralWasMinimized = $true
        $script:CentralRestorePending = $true
        return
    }
    try {''','guard')
one('''function Schedule-CentralResponsivePass {
    try {
        if ($null -eq $script:CentralResponsiveTimer) { return }
        $script:CentralResponsiveTimer.Stop()
        $script:CentralResponsiveTimer.Start()
    } catch {}
}''','''function Schedule-CentralResponsivePass {
    try {
        if ($null -eq $script:CentralResponsiveTimer) { return }
        $script:CentralResponsiveTimer.Stop()
        if ($null -eq $form -or $form.IsDisposed) { return }
        if ($form.WindowState -eq [Windows.Forms.FormWindowState]::Minimized) {
            $script:CentralWasMinimized = $true
            $script:CentralRestorePending = $true
            return
        }
        $script:CentralResponsiveTimer.Start()
    } catch {}
}

function Invoke-CentralRestorePass {
    if ($null -eq $form -or $form.IsDisposed) { return }
    if ($form.WindowState -eq [Windows.Forms.FormWindowState]::Minimized) { return }
    $script:CentralWasMinimized = $false
    $script:CentralRestorePending = $false
    try {
        $form.PerformLayout()
        $rootLayout.PerformLayout()
        $sidebar.PerformLayout()
        $mainPanel.PerformLayout()
        if ($embeddedHost.Visible) { $embeddedHost.PerformLayout() }
        Invoke-CentralResponsivePass
        $form.Invalidate($true)
    } catch {}
}

function Schedule-CentralRestorePass {
    if ($null -eq $form -or $form.IsDisposed) { return }
    if ($form.WindowState -eq [Windows.Forms.FormWindowState]::Minimized) { return }
    $script:CentralRestorePending = $true
    try {
        $a=[Action]{ try { Invoke-CentralRestorePass; Schedule-CentralResponsivePass } catch {} }
        [void]$form.BeginInvoke($a)
    } catch { Invoke-CentralRestorePass; Schedule-CentralResponsivePass }
}''','scheduler')
one('''$form.Add_SizeChanged({ Schedule-CentralResponsivePass })
try { $form.Add_ResizeEnd({ Invoke-CentralResponsivePass }) } catch {}''','''$form.Add_SizeChanged({ Schedule-CentralResponsivePass })
$form.Add_Resize({
    try {
        if ($form.WindowState -eq [Windows.Forms.FormWindowState]::Minimized) {
            if ($null -ne $script:CentralResponsiveTimer) { $script:CentralResponsiveTimer.Stop() }
            $script:CentralWasMinimized = $true
            $script:CentralRestorePending = $true
        } elseif ($script:CentralWasMinimized -or $script:CentralRestorePending) {
            Schedule-CentralRestorePass
        }
    } catch {}
})
$form.Add_Activated({
    try {
        if ($form.WindowState -ne [Windows.Forms.FormWindowState]::Minimized -and ($script:CentralWasMinimized -or $script:CentralRestorePending)) { Schedule-CentralRestorePass }
    } catch {}
})
try { $form.Add_ResizeEnd({ Invoke-CentralResponsivePass }) } catch {}''','events')
s+='\n# CENTRAL_RESTORE_AFTER_MINIMIZE_V02165\n'
for m in ('$script:AppVersion = "0.21.65"','function Invoke-CentralRestorePass','$form.Add_Activated({','CENTRAL_RESTORE_AFTER_MINIMIZE_V02165'):
    if m not in s: raise SystemExit('CENTRAL RESTORE marcador ausente: '+m)
p.write_text(s,encoding='utf-8')
print('CENTRAL RESTORE: OK - restauracao apos minimizar recalcula a geometria real da janela.')
