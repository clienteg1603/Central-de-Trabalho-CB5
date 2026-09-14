from pathlib import Path

p = Path('src/generated/Central de Trabalho.ps1')
s = p.read_text(encoding='utf-8-sig')


def one(old, new, label):
    global s
    count = s.count(old)
    if count != 1:
        raise SystemExit(f'RESTORE AFTER MINIMIZE FINAL {label}: esperado 1, encontrado {count}')
    s = s.replace(old, new, 1)


one('$script:AppVersion = "0.21.64"', '$script:AppVersion = "0.21.67"', 'versao Central')

# Estado de restauração existe antes de qualquer chamada da camada adaptativa.
one(
    '$script:CentralAdaptiveBusy = $false\n$script:CentralAdaptiveProfile = ""',
    '$script:CentralRestoreInProgress = $false\n$script:CentralAdaptiveBusy = $false\n$script:CentralAdaptiveProfile = ""',
    'estado de restauracao antes do adaptativo'
)

# Nenhuma passagem manual pode medir a área cliente enquanto o Windows ainda
# está minimizado ou enquanto a restauração está aguardando estabilização.
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

one(
'''function Update-CentralAdaptiveLayout {
    if ($script:CentralAdaptiveBusy -or $null -eq $form -or $null -eq $rootLayout) { return }''',
'''function Update-CentralAdaptiveLayout {
    if ($script:CentralAdaptiveBusy -or $null -eq $form -or $null -eq $rootLayout) { return }
    if ($form.WindowState -eq [Windows.Forms.FormWindowState]::Minimized) { return }
    if ($script:CentralRestoreInProgress) { return }''',
'guard adaptativo central'
)

# Estes dois callbacks antigos eram o ponto que escapava do debounce central:
# mesmo com a Central protegida, um módulo aberto forçava layout imediatamente
# em cada SizeChanged transitório da restauração. Dock=Fill já cuida dos Bounds.
one(
'''$embeddedHost.Add_SizeChanged({
    try { $embeddedFolderButton.Left = [Math]::Max(380, $embeddedToolbar.ClientSize.Width - $embeddedFolderButton.Width - 12); Update-CentralAdaptiveLayout } catch {}
})''',
'''$embeddedHost.Add_SizeChanged({
    try {
        if ($form.WindowState -eq [Windows.Forms.FormWindowState]::Minimized) { return }
        if ($script:CentralRestoreInProgress) { return }
        $embeddedFolderButton.Left = [Math]::Max(260, $embeddedToolbar.ClientSize.Width - $embeddedFolderButton.Width - 12)
        Schedule-CentralResponsivePass
    } catch {}
})''',
'embedded host sem recalculo imediato'
)

one(
'''$embeddedContent.Add_SizeChanged({
    try {
        if ($null -ne $script:HostedForm -and -not $script:HostedForm.IsDisposed) {
            $script:HostedForm.Bounds = $embeddedContent.ClientRectangle
            $script:HostedForm.PerformLayout()
            if ($null -ne $script:HostedModule) {
                & $script:HostedModule {
                    if (Get-Command Update-MaintenanceResponsiveLayout -ErrorAction SilentlyContinue) {
                        Update-MaintenanceResponsiveLayout
                    }
                    elseif (Get-Command Update-GeneratorResponsiveLayout -ErrorAction SilentlyContinue) {
                        Update-GeneratorResponsiveLayout
                        if (Get-Command Update-RootLayout -ErrorAction SilentlyContinue) { Update-RootLayout }
                    }
                }
            }
        }
    } catch {}
})''',
'''$embeddedContent.Add_SizeChanged({
    try {
        if ($form.WindowState -eq [Windows.Forms.FormWindowState]::Minimized) { return }
        if ($script:CentralRestoreInProgress) { return }
        Schedule-CentralHostedLayoutPass
    } catch {}
})''',
'embedded content sem bounds/layout imediato'
)

restore_block = r'''

# RESTORE AFTER MINIMIZE / ETAPA 1
#
# A correção anterior suspendeu a árvore inteira da Central. Isso evitava alguns
# cálculos, mas passou a expor um quadro antigo também na Visão geral. Agora a
# casca continua livre para o WinForms fazer Dock/Anchor normalmente; bloqueamos
# somente os recálculos MANUAIS enquanto o Windows estabiliza o ClientSize.
$script:CentralLastWindowState = $form.WindowState
$script:CentralRestoreStableTicks = 0
$script:CentralRestoreElapsedTicks = 0
$script:CentralRestoreLastClientSize = [Drawing.Size]::Empty
$script:CentralRestoreEmbeddedContentWasVisible = $false

$script:CentralHostedLayoutTimer = New-Object Windows.Forms.Timer
$script:CentralHostedLayoutTimer.Interval = 90
$script:CentralHostedLayoutTimer.Add_Tick({
    $script:CentralHostedLayoutTimer.Stop()
    try { Invoke-CentralHostedLayoutPass } catch {}
})

function Invoke-CentralHostedLayoutPass {
    try {
        if ($null -eq $form -or $form.IsDisposed) { return }
        if ($form.WindowState -eq [Windows.Forms.FormWindowState]::Minimized) { return }
        if ($script:CentralRestoreInProgress) { return }
        if ($null -eq $embeddedHost -or -not $embeddedHost.Visible) { return }
        if ($null -eq $script:HostedForm -or $script:HostedForm.IsDisposed) { return }

        # O controle hospedado já está em Dock=Fill. Não reescrevemos Bounds aqui.
        # Paramos qualquer debounce pendente do módulo e fazemos uma única
        # passagem final sobre o tamanho já estabilizado.
        if ($null -ne $script:HostedModule) {
            & $script:HostedModule {
                try {
                    if ($null -ne $script:GeneratorLayoutTimer) { $script:GeneratorLayoutTimer.Stop() }
                } catch {}
                try {
                    if ($null -ne $script:MaintenanceLayoutTimer) { $script:MaintenanceLayoutTimer.Stop() }
                } catch {}
                try {
                    if ($null -ne $script:NFLayoutTimer) { $script:NFLayoutTimer.Stop() }
                } catch {}

                if (Get-Command Invoke-MaintenanceLayoutPass -ErrorAction SilentlyContinue) {
                    Invoke-MaintenanceLayoutPass
                }
                elseif (Get-Command Invoke-GeneratorLayoutPass -ErrorAction SilentlyContinue) {
                    Invoke-GeneratorLayoutPass
                }
                elseif (Get-Command Update-NFResponsiveLayout -ErrorAction SilentlyContinue) {
                    Update-NFResponsiveLayout
                }
                elseif (Get-Command Update-MaintenanceResponsiveLayout -ErrorAction SilentlyContinue) {
                    Update-MaintenanceResponsiveLayout
                }
                elseif (Get-Command Update-GeneratorResponsiveLayout -ErrorAction SilentlyContinue) {
                    Update-GeneratorResponsiveLayout
                    if (Get-Command Update-RootLayout -ErrorAction SilentlyContinue) { Update-RootLayout }
                }
            }
        }

        $script:HostedForm.PerformLayout()
        $script:HostedForm.Invalidate($true)
    } catch {}
}

function Schedule-CentralHostedLayoutPass {
    try {
        if ($null -eq $script:CentralHostedLayoutTimer) { return }
        $script:CentralHostedLayoutTimer.Stop()
        if ($form.WindowState -eq [Windows.Forms.FormWindowState]::Minimized) { return }
        if ($script:CentralRestoreInProgress) { return }
        if ($null -eq $embeddedHost -or -not $embeddedHost.Visible) { return }
        $script:CentralHostedLayoutTimer.Start()
    } catch {}
}

function Complete-CentralRestoreAfterMinimize {
    try {
        if ($null -eq $form -or $form.IsDisposed) { return }
        if ($form.WindowState -eq [Windows.Forms.FormWindowState]::Minimized) { return }

        # Libera primeiro o guard e somente depois executa as duas passagens
        # finais. Assim nenhum cálculo usa a geometria intermediária da animação.
        $script:CentralRestoreInProgress = $false

        if ($script:CentralRestoreEmbeddedContentWasVisible) {
            try { $embeddedContent.Visible = $true } catch {}
        }
        $script:CentralRestoreEmbeddedContentWasVisible = $false

        Invoke-CentralResponsivePass
        Invoke-CentralHostedLayoutPass
        try { $form.Invalidate($true) } catch {}
    }
    catch {
        $script:CentralRestoreInProgress = $false
        try { $embeddedContent.Visible = $true } catch {}
        try { Invoke-CentralResponsivePass } catch {}
        try { Invoke-CentralHostedLayoutPass } catch {}
    }
}

$script:CentralRestoreTimer = New-Object Windows.Forms.Timer
$script:CentralRestoreTimer.Interval = 40
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

        # Duas amostras repetidas bastam na maioria dos PCs. O limite existe
        # apenas para nunca deixar o estado de restauração preso por um driver.
        if ($script:CentralRestoreStableTicks -ge 2 -or $script:CentralRestoreElapsedTicks -ge 8) {
            $script:CentralRestoreTimer.Stop()
            Complete-CentralRestoreAfterMinimize
        }
    }
    catch {
        $script:CentralRestoreTimer.Stop()
        Complete-CentralRestoreAfterMinimize
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
            try { $script:CentralHostedLayoutTimer.Stop() } catch {}
            try { $script:CentralRestoreTimer.Stop() } catch {}

            # Somente a área do programa integrado é ocultada enquanto a janela
            # não está visível. A Visão geral nunca é suspensa nem escondida.
            $script:CentralRestoreEmbeddedContentWasVisible = $false
            try {
                if ($embeddedHost.Visible -and $embeddedContent.Visible) {
                    $script:CentralRestoreEmbeddedContentWasVisible = $true
                    $embeddedContent.Visible = $false
                }
            } catch {}
            return
        }

        $wasMinimized = ($script:CentralLastWindowState -eq [Windows.Forms.FormWindowState]::Minimized)
        $script:CentralLastWindowState = $currentState
        if (-not $wasMinimized) { return }

        try { $script:CentralResponsiveTimer.Stop() } catch {}
        try { $script:CentralHostedLayoutTimer.Stop() } catch {}
        try { $script:CentralRestoreTimer.Stop() } catch {}

        $script:CentralRestoreInProgress = $true
        $script:CentralRestoreStableTicks = 0
        $script:CentralRestoreElapsedTicks = 0
        $script:CentralRestoreLastClientSize = $form.ClientSize
        $script:CentralRestoreTimer.Start()
    } catch {
        $script:CentralRestoreInProgress = $false
        try { $embeddedContent.Visible = $true } catch {}
    }
}

$form.Add_Resize({ Repair-CentralAfterWindowRestore })
$form.Add_Activated({
    try {
        if ($form.WindowState -ne [Windows.Forms.FormWindowState]::Minimized) {
            Repair-CentralAfterWindowRestore
            if (-not $script:CentralRestoreInProgress) {
                Schedule-CentralResponsivePass
                Schedule-CentralHostedLayoutPass
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
    try {
        if ($null -ne $script:CentralHostedLayoutTimer) {
            $script:CentralHostedLayoutTimer.Stop()
            $script:CentralHostedLayoutTimer.Dispose()
            $script:CentralHostedLayoutTimer = $null
        }
    } catch {}
    $script:CentralRestoreInProgress = $false
})
# CENTRAL_RESTORE_TARGETED_STAGE1_V02167
'''

# Contratos locais desta correção: a regressão da v0.21.66 não pode voltar e os
# dois callbacks de módulo não podem mais forçar Bounds/adaptativo imediatamente.
for marker in (
    '$script:AppVersion = "0.21.67"',
    'function Invoke-CentralHostedLayoutPass',
    'function Schedule-CentralHostedLayoutPass',
    '$script:CentralHostedLayoutTimer.Interval = 90',
    '$script:CentralRestoreTimer.Interval = 40',
    '$script:CentralRestoreStableTicks -ge 2',
    '$script:CentralRestoreEmbeddedContentWasVisible',
    'CENTRAL_RESTORE_TARGETED_STAGE1_V02167',
):
    if marker not in s:
        raise SystemExit('RESTORE AFTER MINIMIZE FINAL marcador ausente: ' + marker)

for forbidden in (
    'function Suspend-CentralRestoreLayout',
    'function Resume-CentralRestoreLayout',
    '$script:HostedForm.Bounds = $embeddedContent.ClientRectangle\n            $script:HostedForm.PerformLayout()',
    '$embeddedFolderButton.Left = [Math]::Max(380, $embeddedToolbar.ClientSize.Width - $embeddedFolderButton.Width - 12); Update-CentralAdaptiveLayout',
):
    if forbidden in s:
        raise SystemExit('RESTORE AFTER MINIMIZE FINAL regressao ainda presente: ' + forbidden)

p.write_text(s, encoding='utf-8')
print('RESTORE AFTER MINIMIZE FINAL: OK - etapa 1 remove suspensão global, elimina callbacks imediatos do módulo e finaliza o layout somente após o viewport estabilizar.')
