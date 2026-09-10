from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CENTRAL = ROOT / "generated" / "Central de Trabalho.ps1"


def read(path):
    return path.read_text(encoding="utf-8-sig")


def write(path, text):
    path.write_text(text, encoding="utf-8-sig")


def replace_once(text, old, new, label):
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: esperado 1 trecho, encontrado {count}")
    return text.replace(old, new, 1)


central = read(CENTRAL)
central = replace_once(central, '$script:AppVersion = "0.16.2"', '$script:AppVersion = "0.16.3"', 'versao Central')
state_marker = '$script:ModuleLoading = $false'
if state_marker not in central:
    raise RuntimeError('estado global da Central nao localizado')
central = central.replace(
    state_marker,
    '$script:ModuleLoading = $false\n$script:UpdaterProcess = $null\n$script:LastAvailabilitySignature = ""',
    1
)

old_availability_start = central.find('function Update-CentralAvailabilityState {\n')
old_availability_end = central.find('\nfunction Apply-AppTheme {', old_availability_start)
if old_availability_start < 0 or old_availability_end < 0:
    raise RuntimeError('Update-CentralAvailabilityState nao localizado')

new_availability = r'''function Update-CentralAvailabilityState {
    try {
        $generatorAvailable = [IO.File]::Exists($script:GeneratorScript)
        $maintenanceAvailable = [IO.File]::Exists($script:MaintenanceScript)
        $updaterAvailable = [IO.File]::Exists($script:UpdaterScript)
        $generatorFolderAvailable = [IO.Directory]::Exists($script:GeneratorDirectory)
        $maintenanceFolderAvailable = [IO.Directory]::Exists($script:MaintenanceDirectory)
        $moduleCount = ([int]$generatorAvailable + [int]$maintenanceAvailable)

        if ($null -ne $script:UpdaterProcess) {
            try {
                if ($script:UpdaterProcess.HasExited) {
                    try { $script:UpdaterProcess.Dispose() } catch {}
                    $script:UpdaterProcess = $null
                }
            } catch { $script:UpdaterProcess = $null }
        }

        if ($null -ne $openGeneratorButton) {
            $openGeneratorButton.Enabled = ($generatorAvailable -and -not $script:ModuleLoading)
            $openGeneratorButton.Cursor = if ($openGeneratorButton.Enabled) { [Windows.Forms.Cursors]::Hand } else { [Windows.Forms.Cursors]::Default }
        }
        if ($null -ne $openMaintenanceButton) {
            $openMaintenanceButton.Enabled = ($maintenanceAvailable -and -not $script:ModuleLoading)
            $openMaintenanceButton.Cursor = if ($openMaintenanceButton.Enabled) { [Windows.Forms.Cursors]::Hand } else { [Windows.Forms.Cursors]::Default }
        }
        if ($null -ne $openGeneratorFolderButton) {
            $openGeneratorFolderButton.Enabled = ($generatorFolderAvailable -and -not $script:ModuleLoading)
            $openGeneratorFolderButton.Cursor = if ($openGeneratorFolderButton.Enabled) { [Windows.Forms.Cursors]::Hand } else { [Windows.Forms.Cursors]::Default }
        }
        if ($null -ne $openMaintenanceFolderButton) {
            $openMaintenanceFolderButton.Enabled = ($maintenanceFolderAvailable -and -not $script:ModuleLoading)
            $openMaintenanceFolderButton.Cursor = if ($openMaintenanceFolderButton.Enabled) { [Windows.Forms.Cursors]::Hand } else { [Windows.Forms.Cursors]::Default }
        }
        if ($null -ne $navUpdates) {
            $navUpdates.Enabled = ($updaterAvailable -and -not $script:ModuleLoading)
            $navUpdates.Cursor = if ($navUpdates.Enabled) { [Windows.Forms.Cursors]::Hand } else { [Windows.Forms.Cursors]::Default }
        }
        foreach ($navAction in @($navHome,$navFolder,$navAbout)) {
            if ($null -ne $navAction) {
                $navAction.Enabled = (-not $script:ModuleLoading)
                $navAction.Cursor = if ($navAction.Enabled) { [Windows.Forms.Cursors]::Hand } else { [Windows.Forms.Cursors]::Default }
            }
        }
        if ($null -ne $themeCombo) { $themeCombo.Enabled = (-not $script:ModuleLoading) }

        if ($null -ne $generatorStatus) {
            $generatorStatus.Text = if ($generatorAvailable) { "  DISPONÍVEL  " } else { "  INDISPONÍVEL  " }
            $generatorStatus.BackColor = if ($generatorAvailable) { $script:CurrentPalette.SuccessBack } else { $script:CurrentPalette.PlannedBack }
            $generatorStatus.ForeColor = if ($generatorAvailable) { $script:CurrentPalette.Success } else { $script:CurrentPalette.Planned }
        }
        if ($null -ne $maintenanceStatus) {
            $maintenanceStatus.Text = if ($maintenanceAvailable) { "  DISPONÍVEL  " } else { "  INDISPONÍVEL  " }
            $maintenanceStatus.BackColor = if ($maintenanceAvailable) { $script:CurrentPalette.SuccessBack } else { $script:CurrentPalette.PlannedBack }
            $maintenanceStatus.ForeColor = if ($maintenanceAvailable) { $script:CurrentPalette.Success } else { $script:CurrentPalette.Planned }
        }

        if ($null -ne $sidebarStatus -and $null -ne $sidebarStatusSub) {
            if ($generatorAvailable -and $maintenanceAvailable -and $updaterAvailable) {
                $sidebarStatus.Text = "●  Sistema pronto"
                $sidebarStatusSub.Text = "2 módulos disponíveis"
                $sidebarStatus.ForeColor = $script:CurrentPalette.Success
            }
            else {
                $sidebarStatus.Text = "●  Atenção"
                if ($moduleCount -lt 2) {
                    $sidebarStatusSub.Text = "$moduleCount de 2 módulos disponíveis"
                }
                elseif (-not $updaterAvailable) {
                    $sidebarStatusSub.Text = "Atualizador não localizado"
                }
                else {
                    $sidebarStatusSub.Text = "Verifique a instalação"
                }
                $sidebarStatus.ForeColor = $script:CurrentPalette.Planned
            }
        }
        if ($null -ne $sidebarVersion) { $sidebarVersion.Text = "Central v$($script:AppVersion)" }
        if ($null -ne $todayLabel) { $todayLabel.Text = (Get-Date).ToString("dd/MM/yyyy") }

        $signature = "$generatorAvailable|$maintenanceAvailable|$updaterAvailable|$generatorFolderAvailable|$maintenanceFolderAvailable|$($script:ModuleLoading)"
        if ($script:LastAvailabilitySignature -ne $signature) {
            $script:LastAvailabilitySignature = $signature
            try { $form.Invalidate($false) } catch {}
        }
    } catch {}
}
'''
central = central[:old_availability_start] + new_availability + central[old_availability_end:]

old_status_block = r'''    try {
        if ([IO.File]::Exists($script:GeneratorScript) -and [IO.File]::Exists($script:MaintenanceScript) -and [IO.File]::Exists($script:UpdaterScript)) {
            $sidebarStatus.Text = "●  Sistema pronto"
            $sidebarStatusSub.Text = "2 módulos disponíveis"
        }
        elseif (-not [IO.File]::Exists($script:UpdaterScript)) {
            Set-StatusMessage "O Atualizador da Central de Trabalho não foi encontrado." "Error"
            $sidebarStatus.Text = "●  Atenção"
            $sidebarStatusSub.Text = "Atualizador não localizado"
        }
        elseif (-not [IO.File]::Exists($script:MaintenanceScript)) {
            Set-StatusMessage "O módulo Central de Manutenção CB5 não foi encontrado." "Error"
            $sidebarStatus.Text = "●  Atenção"
            $sidebarStatusSub.Text = "Manutenção não localizada"
        }
        else {
            Set-StatusMessage "O módulo Gerenciador de Planilhas não foi encontrado." "Error"
            $sidebarStatus.Text = "●  Atenção"
            $sidebarStatusSub.Text = "Gerenciador não localizado"
        }
    } catch {}
    try { Update-CentralAvailabilityState } catch {}'''
central = replace_once(central, old_status_block, '    try { Update-CentralAvailabilityState } catch {}', 'estado duplicado no tema')

updater_guard = r'''function Start-UpdaterModule {
    if (-not [IO.File]::Exists($script:UpdaterScript)) {'''
updater_guard_new = r'''function Start-UpdaterModule {
    if ($null -ne $script:UpdaterProcess) {
        try {
            if (-not $script:UpdaterProcess.HasExited) {
                Set-StatusMessage "A tela de atualizações já está aberta." "Normal"
                return
            }
        } catch {}
        try { $script:UpdaterProcess.Dispose() } catch {}
        $script:UpdaterProcess = $null
    }

    if (-not [IO.File]::Exists($script:UpdaterScript)) {'''
central = replace_once(central, updater_guard, updater_guard_new, 'proteção do Atualizador')
central = replace_once(
    central,
    '[void][Diagnostics.Process]::Start($startInfo)\n        Set-StatusMessage "Tela de atualizações aberta em uma nova janela." "Success"',
    '$script:UpdaterProcess = [Diagnostics.Process]::Start($startInfo)\n        Set-StatusMessage "Tela de atualizações aberta em uma nova janela." "Success"',
    'captura do processo do Atualizador'
)

watch_marker = '$embeddedWatchTimer.Start()\n'
if central.count(watch_marker) != 1:
    raise RuntimeError('timer de modulo nao localizado')
health_timer = r'''
$centralHealthTimer = New-Object Windows.Forms.Timer
$centralHealthTimer.Interval = 3000
$centralHealthTimer.Add_Tick({
    try { Update-CentralAvailabilityState } catch {}
})
$centralHealthTimer.Start()
'''
central = central.replace(watch_marker, watch_marker + health_timer, 1)

central = replace_once(
    central,
    '$form.Add_Shown({ Update-CentralAdaptiveLayout; Update-ResponsiveLayout; Apply-AppTheme })',
    '$form.Add_Shown({ Update-CentralAdaptiveLayout; Update-ResponsiveLayout; Apply-AppTheme; Update-CentralAvailabilityState })',
    'sincronizacao no Shown'
)

central = replace_once(
    central,
    'try { if ($null -ne $embeddedWatchTimer) { $embeddedWatchTimer.Stop(); $embeddedWatchTimer.Dispose() } } catch {}',
    'try { if ($null -ne $embeddedWatchTimer) { $embeddedWatchTimer.Stop(); $embeddedWatchTimer.Dispose() } } catch {}\n    try { if ($null -ne $centralHealthTimer) { $centralHealthTimer.Stop(); $centralHealthTimer.Dispose() } } catch {}\n    try { if ($null -ne $script:UpdaterProcess -and $script:UpdaterProcess.HasExited) { $script:UpdaterProcess.Dispose() } } catch {}',
    'limpeza de timers'
)

write(CENTRAL, central)
