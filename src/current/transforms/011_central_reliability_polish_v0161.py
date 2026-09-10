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
central = replace_once(central, '$script:AppVersion = "0.16.0"', '$script:AppVersion = "0.16.1"', 'versao Central')
central = replace_once(central, '$script:EmbeddedClosing = $false', '$script:EmbeddedClosing = $false\n$script:ModuleLoading = $false', 'estado de carregamento')

# Remove duas funções antigas que sobreviveram ao redesenho. A segunda Apply-AppTheme,
# mais abaixo, é a implementação atual; Update-CardLayout foi substituída por Update-ResponsiveLayout.
first_theme = central.find('function Apply-AppTheme {\n')
second_theme = central.find('function Apply-AppTheme {\n', first_theme + 1)
integration_marker = central.find('# Integração real dos módulos', first_theme)
if first_theme < 0 or second_theme < 0 or integration_marker < 0 or not (first_theme < integration_marker < second_theme):
    raise RuntimeError('bloco legado inicial da Central nao localizado com seguranca')
central = central[:first_theme] + central[integration_marker:]

# Estado de disponibilidade real dos três componentes principais.
last_theme = central.rfind('function Apply-AppTheme {\n')
if last_theme < 0:
    raise RuntimeError('Apply-AppTheme atual nao localizado')
availability = r'''function Update-CentralAvailabilityState {
    try {
        $generatorAvailable = [IO.File]::Exists($script:GeneratorScript)
        $maintenanceAvailable = [IO.File]::Exists($script:MaintenanceScript)
        $updaterAvailable = [IO.File]::Exists($script:UpdaterScript)

        if ($null -ne $openGeneratorButton) { $openGeneratorButton.Enabled = ($generatorAvailable -and -not $script:ModuleLoading) }
        if ($null -ne $openMaintenanceButton) { $openMaintenanceButton.Enabled = ($maintenanceAvailable -and -not $script:ModuleLoading) }
        if ($null -ne $openGeneratorFolderButton) { $openGeneratorFolderButton.Enabled = [IO.Directory]::Exists($script:GeneratorDirectory) }
        if ($null -ne $openMaintenanceFolderButton) { $openMaintenanceFolderButton.Enabled = [IO.Directory]::Exists($script:MaintenanceDirectory) }
        if ($null -ne $navUpdates) { $navUpdates.Enabled = $updaterAvailable }

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
    } catch {}
}

'''
central = central[:last_theme] + availability + central[last_theme:]

# O tema sempre termina sincronizando a disponibilidade, para que botão e selo nunca
# contradigam o estado real dos arquivos instalados.
needle = '''    try {
        foreach ($rounded in @($generatorCard,$maintenanceCard,$brandMark,$generatorIcon,$maintenanceIcon,$openGeneratorButton,$openMaintenanceButton,$openGeneratorFolderButton,$openMaintenanceFolderButton)) {'''
replacement = '''    try { Update-CentralAvailabilityState } catch {}
    try {
        foreach ($rounded in @($generatorCard,$maintenanceCard,$brandMark,$generatorIcon,$maintenanceIcon,$openGeneratorButton,$openMaintenanceButton,$openGeneratorFolderButton,$openMaintenanceFolderButton)) {'''
central = replace_once(central, needle, replacement, 'sincronizacao de disponibilidade no tema')

# Bloqueia reentrada durante o carregamento do módulo e restaura os botões no final.
start_try = '''    try {
        Close-EmbeddedModule
        $mainLayout.Visible = $false'''
start_try_new = '''    if ($script:ModuleLoading) { return }
    $script:ModuleLoading = $true
    try { Update-CentralAvailabilityState } catch {}

    try {
        Close-EmbeddedModule
        $mainLayout.Visible = $false'''
central = replace_once(central, start_try, start_try_new, 'inicio protegido do modulo')

catch_tail = '''        [Windows.Forms.MessageBox]::Show(
            "Não foi possível integrar $moduleName à Central.`r`n`r`n$($_.Exception.Message)",
            "Central de Trabalho",
            [Windows.Forms.MessageBoxButtons]::OK,
            [Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
    }
}

function Start-GeneratorModule'''
catch_tail_new = '''        [Windows.Forms.MessageBox]::Show(
            "Não foi possível integrar $moduleName à Central.`r`n`r`n$($_.Exception.Message)",
            "Central de Trabalho",
            [Windows.Forms.MessageBoxButtons]::OK,
            [Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
    }
    finally {
        $script:ModuleLoading = $false
        try { Update-CentralAvailabilityState } catch {}
    }
}

function Start-GeneratorModule'''
central = replace_once(central, catch_tail, catch_tail_new, 'finalizacao protegida do modulo')

# Melhor foco ao voltar para a tela inicial.
central = replace_once(
    central,
    '''    Set-ActiveNavigation "Home"
    Set-StatusMessage "Visão geral da Central de Trabalho." "Normal"
}''',
    '''    Set-ActiveNavigation "Home"
    Set-StatusMessage "Visão geral da Central de Trabalho." "Normal"
    try { if ($null -ne $openGeneratorButton -and $openGeneratorButton.Enabled) { $openGeneratorButton.Select() } } catch {}
}''',
    'foco ao voltar para inicio'
)

# Teclado e ordem de navegação passam a ser previsíveis sem mudar nenhuma função.
central = replace_once(central, '$form.SizeGripStyle = [Windows.Forms.SizeGripStyle]::Show', '$form.SizeGripStyle = [Windows.Forms.SizeGripStyle]::Show\n$form.KeyPreview = $true', 'KeyPreview')

events_marker = '# Eventos\n'
if central.count(events_marker) != 1:
    raise RuntimeError('marcador de eventos nao localizado')
keyboard = r'''# Ordem de foco: navegação da Central, aparência e ações principais.
$navHome.TabIndex = 0
$navUpdates.TabIndex = 1
$navFolder.TabIndex = 2
$navAbout.TabIndex = 3
$themeCombo.TabIndex = 4
$openGeneratorButton.TabIndex = 10
$openGeneratorFolderButton.TabIndex = 11
$openMaintenanceButton.TabIndex = 12
$openMaintenanceFolderButton.TabIndex = 13
$embeddedBackButton.TabIndex = 0
$embeddedFolderButton.TabIndex = 1

'''
central = central.replace(events_marker, keyboard + events_marker, 1)

# Alt+Esquerda volta ao painel quando um módulo estiver aberto; não interfere com Esc
# usado por campos, grades ou janelas internas dos módulos.
closing_marker = '$form.Add_FormClosing({ Close-EmbeddedModule; Save-AppSettings })\n'
if central.count(closing_marker) != 1:
    raise RuntimeError('evento FormClosing nao localizado')
key_event = r'''$form.Add_KeyDown({
    param($sender, $eventArgs)
    try {
        if ($eventArgs.Alt -and $eventArgs.KeyCode -eq [Windows.Forms.Keys]::Left -and $embeddedHost.Visible) {
            Show-Dashboard
            $eventArgs.Handled = $true
            $eventArgs.SuppressKeyPress = $true
        }
    } catch {}
})
'''
central = central.replace(closing_marker, key_event + closing_marker, 1)

# Tooltip documenta o atalho no botão de retorno.
central = replace_once(
    central,
    '$toolTip.SetToolTip($embeddedBackButton, "Voltar para a tela inicial da Central de Trabalho")',
    '$toolTip.SetToolTip($embeddedBackButton, "Voltar para a tela inicial da Central de Trabalho (Alt+←)")',
    'tooltip do retorno'
)

write(CENTRAL, central)
