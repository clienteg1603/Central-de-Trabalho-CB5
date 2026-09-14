from pathlib import Path

p = Path('src/generated/Central de Trabalho.ps1')
s = p.read_text(encoding='utf-8-sig')


def one(old, new, label):
    global s
    count = s.count(old)
    if count != 1:
        raise SystemExit(f'RESTORE STAGE3 {label}: esperado 1, encontrado {count}')
    s = s.replace(old, new, 1)


# Somente a Central muda nesta etapa. Os módulos permanecem exatamente nas
# versões validadas da Etapa 2.
one('$script:AppVersion = "0.21.68"', '$script:AppVersion = "0.21.69"', 'versao Central')

# A Visão geral já está estável e o NF também. O problema restante ocorre nos
# dois módulos mais pesados, que precisam continuar recebendo Dock/ClientSize
# reais durante a restauração sem desenhar os quadros intermediários.
one(
'''        [DllImport("dwmapi.dll")]
        public static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int value, int size);''',
'''        [DllImport("dwmapi.dll")]
        public static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int value, int size);
        [DllImport("user32.dll", SetLastError=true)]
        public static extern IntPtr SendMessage(IntPtr hWnd, int msg, IntPtr wParam, IntPtr lParam);''',
'nativo WM_SETREDRAW'
)

one(
'''$script:CentralRestoreLastClientSize = [Drawing.Size]::Empty
$script:CentralRestoreEmbeddedContentWasVisible = $false''',
'''$script:CentralRestoreLastClientSize = [Drawing.Size]::Empty
$script:CentralRestoreEmbeddedContentWasVisible = $false
$script:CentralRestoreHostedRedrawSuppressed = $false''',
'estado de redraw hospedado'
)

helper = r'''function Test-CentralRestoreUsesRedrawFreeze {
    return ($script:EmbeddedModule -eq "Generator" -or $script:EmbeddedModule -eq "Maintenance")
}

function Set-CentralHostedRedraw {
    param([bool]$Enabled)
    try {
        if ($null -eq $script:HostedForm -or $script:HostedForm.IsDisposed -or -not $script:HostedForm.IsHandleCreated) { return }
        $wParam = if ($Enabled) { [IntPtr]1 } else { [IntPtr]0 }
        [void][CentralWindowStyle.Native]::SendMessage($script:HostedForm.Handle, 0x000B, $wParam, [IntPtr]::Zero)
        if ($Enabled) {
            $script:HostedForm.Invalidate($true)
            $script:HostedForm.Update()
        }
    } catch {}
}

'''
one('function Complete-CentralRestoreAfterMinimize {', helper + 'function Complete-CentralRestoreAfterMinimize {', 'helpers de redraw')

old_complete = r'''function Complete-CentralRestoreAfterMinimize {
    try {
        if ($null -eq $form -or $form.IsDisposed) { return }
        if ($form.WindowState -eq [Windows.Forms.FormWindowState]::Minimized) { return }

        # Libera primeiro o guard e somente depois executa as duas passagens
        # finais. Assim nenhum cálculo usa a geometria intermediária da animação.
        $script:CentralRestoreInProgress = $false

        Invoke-CentralResponsivePass
        try { $script:HostedThemeContext.LayoutRestoreActive = $false } catch {}
        Invoke-CentralHostedLayoutPass
        try { $script:HostedThemeContext.LayoutRestoreActive = $true } catch {}

        if ($script:CentralRestoreEmbeddedContentWasVisible) {
            try {
                $embeddedContent.Visible = $true
                $embeddedContent.PerformLayout()
                if ($null -ne $script:HostedForm -and -not $script:HostedForm.IsDisposed) { $script:HostedForm.PerformLayout() }
            } catch {}
        }
        $script:CentralRestoreEmbeddedContentWasVisible = $false
        try { $script:HostedThemeContext.LayoutRestoreActive = $false } catch {}
        try {
            if ($null -ne $script:HostedForm -and -not $script:HostedForm.IsDisposed) { $script:HostedForm.Invalidate($true) }
            $form.Invalidate($true)
        } catch {}
    }
    catch {
        $script:CentralRestoreInProgress = $false
        try { $embeddedContent.Visible = $true } catch {}
        try { $script:HostedThemeContext.LayoutRestoreActive = $false } catch {}
        try { Invoke-CentralResponsivePass } catch {}
        try { Invoke-CentralHostedLayoutPass } catch {}
    }
}'''

new_complete = r'''function Complete-CentralRestoreAfterMinimize {
    try {
        if ($null -eq $form -or $form.IsDisposed) { return }
        if ($form.WindowState -eq [Windows.Forms.FormWindowState]::Minimized) { return }

        $script:CentralRestoreInProgress = $false
        Invoke-CentralResponsivePass

        if ($script:CentralRestoreHostedRedrawSuppressed) {
            # Gerenciador e Manutenção continuam logicamente visíveis. Dessa
            # forma Dock/ClientSize acompanham a janela restaurada mesmo com a
            # pintura bloqueada. A passagem interna roda somente no tamanho final.
            try { $script:HostedThemeContext.LayoutRestoreActive = $false } catch {}
            try { $embeddedContent.PerformLayout() } catch {}
            try {
                if ($null -ne $script:HostedForm -and -not $script:HostedForm.IsDisposed) {
                    $script:HostedForm.PerformLayout()
                }
            } catch {}

            Invoke-CentralHostedLayoutPass

            try {
                if ($null -ne $script:HostedForm -and -not $script:HostedForm.IsDisposed) {
                    $script:HostedForm.PerformLayout()
                }
            } catch {}

            $script:CentralRestoreEmbeddedContentWasVisible = $false
            Set-CentralHostedRedraw $true
            $script:CentralRestoreHostedRedrawSuppressed = $false
            try {
                $embeddedContent.Invalidate($true)
                $form.Invalidate($true)
            } catch {}
            return
        }

        # O Controle de NF já ficou estável na Etapa 2. Preservamos exatamente
        # o caminho que funcionou para ele, sem reabrir essa parte.
        try { $script:HostedThemeContext.LayoutRestoreActive = $false } catch {}
        Invoke-CentralHostedLayoutPass
        try { $script:HostedThemeContext.LayoutRestoreActive = $true } catch {}

        if ($script:CentralRestoreEmbeddedContentWasVisible) {
            try {
                $embeddedContent.Visible = $true
                $embeddedContent.PerformLayout()
                if ($null -ne $script:HostedForm -and -not $script:HostedForm.IsDisposed) { $script:HostedForm.PerformLayout() }
            } catch {}
        }
        $script:CentralRestoreEmbeddedContentWasVisible = $false
        try { $script:HostedThemeContext.LayoutRestoreActive = $false } catch {}
        try {
            if ($null -ne $script:HostedForm -and -not $script:HostedForm.IsDisposed) { $script:HostedForm.Invalidate($true) }
            $form.Invalidate($true)
        } catch {}
    }
    catch {
        $script:CentralRestoreInProgress = $false
        try { $embeddedContent.Visible = $true } catch {}
        try { $script:HostedThemeContext.LayoutRestoreActive = $false } catch {}
        if ($script:CentralRestoreHostedRedrawSuppressed) {
            try { Set-CentralHostedRedraw $true } catch {}
            $script:CentralRestoreHostedRedrawSuppressed = $false
        }
        try { Invoke-CentralResponsivePass } catch {}
        try { Invoke-CentralHostedLayoutPass } catch {}
    }
}'''
one(old_complete, new_complete, 'ordem final da restauracao')

old_minimize = r'''            $script:CentralRestoreEmbeddedContentWasVisible = $false
            try {
                if ($embeddedHost.Visible -and $embeddedContent.Visible) {
                    $script:CentralRestoreEmbeddedContentWasVisible = $true
                    $embeddedContent.Visible = $false
                }
            } catch {}
            return'''

new_minimize = r'''            $script:CentralRestoreEmbeddedContentWasVisible = $false
            try {
                if ($embeddedHost.Visible -and $embeddedContent.Visible) {
                    $script:CentralRestoreEmbeddedContentWasVisible = $true
                    if (Test-CentralRestoreUsesRedrawFreeze) {
                        # Não escondemos Gerenciador/Manutenção: ocultar fazia o
                        # WinForms conservar geometria antiga até Visible=true.
                        # Bloqueamos apenas a pintura enquanto Dock continua vivo.
                        Set-CentralHostedRedraw $false
                        $script:CentralRestoreHostedRedrawSuppressed = $true
                    }
                    else {
                        $embeddedContent.Visible = $false
                    }
                }
            } catch {}
            return'''
one(old_minimize, new_minimize, 'minimizar sem esconder modulos pesados')

one(
'''    } catch {
        $script:CentralRestoreInProgress = $false
        try { $embeddedContent.Visible = $true } catch {}
        try { $script:HostedThemeContext.LayoutRestoreActive = $false } catch {}
    }
}''',
'''    } catch {
        $script:CentralRestoreInProgress = $false
        try { $embeddedContent.Visible = $true } catch {}
        try { $script:HostedThemeContext.LayoutRestoreActive = $false } catch {}
        if ($script:CentralRestoreHostedRedrawSuppressed) {
            try { Set-CentralHostedRedraw $true } catch {}
            $script:CentralRestoreHostedRedrawSuppressed = $false
        }
    }
}''',
'fallback da deteccao de restore'
)

s += r'''
$form.Add_FormClosed({
    if ($script:CentralRestoreHostedRedrawSuppressed) {
        try { Set-CentralHostedRedraw $true } catch {}
        $script:CentralRestoreHostedRedrawSuppressed = $false
    }
})
# CENTRAL_RESTORE_LIVE_HOST_REDRAW_STAGE3_V02169
'''

for marker in (
    '$script:AppVersion = "0.21.69"',
    'public static extern IntPtr SendMessage',
    'function Test-CentralRestoreUsesRedrawFreeze',
    'function Set-CentralHostedRedraw',
    '$script:CentralRestoreHostedRedrawSuppressed = $true',
    'CENTRAL_RESTORE_LIVE_HOST_REDRAW_STAGE3_V02169',
):
    if marker not in s:
        raise SystemExit('RESTORE STAGE3 marcador ausente: ' + marker)

# O caminho do NF deve continuar existindo e a Etapa 3 não altera as versões
# dos módulos, apenas a política de pintura do host central.
for marker in (
    '$script:GeneratorVersion = "3.7.21"',
    '$script:MaintenanceVersion = "0.6.18"',
    '$script:NFEntradaVersion = "2.6.25"',
    '$embeddedContent.Visible = $false',
):
    if marker not in s:
        raise SystemExit('RESTORE STAGE3 preservacao ausente: ' + marker)

p.write_text(s, encoding='utf-8')
print('RESTORE STAGE3: OK - Gerenciador e Manutencao mantem geometria viva com pintura bloqueada; NF preserva o caminho estavel da Etapa 2.')
