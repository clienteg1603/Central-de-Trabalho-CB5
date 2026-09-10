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


def remove_between(text, start, end, label):
    a = text.find(start)
    b = text.find(end, a + len(start)) if a >= 0 else -1
    if a < 0 or b < 0 or b <= a:
        raise RuntimeError(f"{label}: marcadores nao localizados com seguranca")
    return text[:a] + text[b:]


central = read(CENTRAL)
central = replace_once(central, '$script:AppVersion = "0.16.1"', '$script:AppVersion = "0.16.2"', 'versao Central')

# Remove estados nulos que já não têm qualquer consumidor: Programas e Backup deixaram
# de ser rotas há várias versões e o mapa de navegação atual não os referencia mais.
central = replace_once(
    central,
    '''$navHome = New-SidebarButton "⌂   Início"
# Programas e Backup deixaram de ser botões próprios: eram rotas duplicadas.
# Mantemos as variáveis nulas para compatibilidade com o estado interno de navegação.
$navPrograms = $null
$navUpdates = New-SidebarButton "↻   Atualizações"
$navBackup = $null
$navFolder = New-SidebarButton "▣   Pasta da Central"
$navAbout = New-SidebarButton "ⓘ   Sobre"''',
    '''$navHome = New-SidebarButton "⌂   Início"
$navUpdates = New-SidebarButton "↻   Atualizações"
$navFolder = New-SidebarButton "▣   Pasta da Central"
$navAbout = New-SidebarButton "ⓘ   Sobre"''',
    'rotas nulas antigas'
)

# A tela inicial tinha duas linhas de altura zero e controles completos escondidos nelas.
# Consolida o layout no que realmente existe hoje: cabeçalho, módulos e rodapé.
central = replace_once(
    central,
    '''$mainLayout.ColumnCount = 1
$mainLayout.RowCount = 5
[void]$mainLayout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 92)))
[void]$mainLayout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 0)))
[void]$mainLayout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 100)))
[void]$mainLayout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 0)))
[void]$mainLayout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 44)))''',
    '''$mainLayout.ColumnCount = 1
$mainLayout.RowCount = 3
[void]$mainLayout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 92)))
[void]$mainLayout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 100)))
[void]$mainLayout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 44)))''',
    'linhas reais do painel inicial'
)

# O selo do cabeçalho estava permanentemente invisível desde a deduplicação de status.
central = remove_between(central, '$headerStatusPill = New-Object Windows.Forms.Label\n', '$headerAccent = New-Object Windows.Forms.Panel\n', 'selo oculto do cabecalho')

# Remove os cartões de resumo completos que ocupavam uma linha de 0 px e nunca apareciam.
central = remove_between(central, '$summaryHost = New-Object Windows.Forms.Panel\n', '$modulesHost = New-Object Windows.Forms.Panel\n', 'resumo oculto')
central = replace_once(central, '$mainLayout.Controls.Add($modulesHost, 0, 2)', '$mainLayout.Controls.Add($modulesHost, 0, 1)', 'linha dos modulos')

# Remove a antiga área de Ações rápidas, também permanentemente escondida. As mesmas
# funções continuam acessíveis pela navegação lateral, que é hoje a rota oficial.
central = remove_between(central, '$quickHost = New-Object Windows.Forms.Panel\n', '$footerPanel = New-Object Windows.Forms.Panel\n', 'acoes rapidas ocultas')
central = replace_once(central, '$mainLayout.Controls.Add($footerPanel, 0, 4)', '$mainLayout.Controls.Add($footerPanel, 0, 2)', 'linha do rodape')

# Limpa referências dos controles que deixaram de existir.
for old in [
    '        $headerStatusPill.BackColor = $script:CurrentPalette.SuccessBack\n',
    '        $headerStatusPill.ForeColor = $script:CurrentPalette.Success\n',
    '$toolTip.SetToolTip($quickUpdatesButton, "Abrir atualização, backup e restauração")\n',
    '$quickUpdatesButton.Add_Click({ Start-UpdaterModule })\n',
    '$quickFolderButton.Add_Click({ Open-RootFolder })\n',
]:
    if old not in central:
        raise RuntimeError(f'referencia antiga nao localizada: {old[:50]}')
    central = central.replace(old, '', 1)

central = replace_once(
    central,
    'foreach ($roundedPanel in @($summaryCard1,$summaryCard2,$summaryCard3,$generatorCard,$maintenanceCard,$updatesQuickCard,$folderQuickCard)) {',
    'foreach ($roundedPanel in @($generatorCard,$maintenanceCard)) {',
    'paineis arredondados atuais'
)
central = replace_once(
    central,
    'foreach ($roundedSmall in @($brandMark,$generatorIcon,$maintenanceIcon,$headerStatusPill,$openGeneratorButton,$openMaintenanceButton,$openGeneratorFolderButton,$openMaintenanceFolderButton,$quickUpdatesButton,$quickFolderButton)) {',
    'foreach ($roundedSmall in @($brandMark,$generatorIcon,$maintenanceIcon,$openGeneratorButton,$openMaintenanceButton,$openGeneratorFolderButton,$openMaintenanceFolderButton)) {',
    'controles arredondados atuais'
)

# A atualização de disponibilidade também representa o estado de carregamento. Durante
# DoEvents, todos os comandos que poderiam iniciar outra ação ficam temporariamente inativos.
old_avail = '''        if ($null -ne $openGeneratorButton) { $openGeneratorButton.Enabled = ($generatorAvailable -and -not $script:ModuleLoading) }
        if ($null -ne $openMaintenanceButton) { $openMaintenanceButton.Enabled = ($maintenanceAvailable -and -not $script:ModuleLoading) }
        if ($null -ne $openGeneratorFolderButton) { $openGeneratorFolderButton.Enabled = [IO.Directory]::Exists($script:GeneratorDirectory) }
        if ($null -ne $openMaintenanceFolderButton) { $openMaintenanceFolderButton.Enabled = [IO.Directory]::Exists($script:MaintenanceDirectory) }
        if ($null -ne $navUpdates) { $navUpdates.Enabled = $updaterAvailable }'''
new_avail = '''        $busy = [bool]$script:ModuleLoading
        if ($null -ne $openGeneratorButton) { $openGeneratorButton.Enabled = ($generatorAvailable -and -not $busy) }
        if ($null -ne $openMaintenanceButton) { $openMaintenanceButton.Enabled = ($maintenanceAvailable -and -not $busy) }
        if ($null -ne $openGeneratorFolderButton) { $openGeneratorFolderButton.Enabled = ([IO.Directory]::Exists($script:GeneratorDirectory) -and -not $busy) }
        if ($null -ne $openMaintenanceFolderButton) { $openMaintenanceFolderButton.Enabled = ([IO.Directory]::Exists($script:MaintenanceDirectory) -and -not $busy) }
        if ($null -ne $navHome) { $navHome.Enabled = -not $busy }
        if ($null -ne $navUpdates) { $navUpdates.Enabled = ($updaterAvailable -and -not $busy) }
        if ($null -ne $navFolder) { $navFolder.Enabled = -not $busy }
        if ($null -ne $navAbout) { $navAbout.Enabled = -not $busy }
        if ($null -ne $themeCombo) { $themeCombo.Enabled = -not $busy }
        if ($null -ne $embeddedBackButton) { $embeddedBackButton.Enabled = -not $busy }
        if ($null -ne $embeddedFolderButton) {
            $moduleFolderAvailable = if ($script:EmbeddedModule -eq "Generator") { [IO.Directory]::Exists($script:GeneratorDirectory) } elseif ($script:EmbeddedModule -eq "Maintenance") { [IO.Directory]::Exists($script:MaintenanceDirectory) } else { $false }
            $embeddedFolderButton.Enabled = ($moduleFolderAvailable -and -not $busy)
        }'''
central = replace_once(central, old_avail, new_avail, 'estado ocupado da Central')

# Variável local que não era usada pela integração.
central = replace_once(
    central,
    '    $moduleDirectory = if ($Module -eq "Generator") { $script:GeneratorDirectory } else { $script:MaintenanceDirectory }\n',
    '',
    'variavel local sem uso'
)

# Corrige o feedback de carregamento: Controls.Clear removia o próprio label antes que ele
# pudesse ser pintado. Reanexa o label, mostra espera visível e só então inicia o módulo.
old_loading = '''        $mainLayout.Visible = $false
        $embeddedHost.Visible = $true
        $embeddedHost.BringToFront()
        $embeddedTitle.Text = $moduleName
        $embeddedSubtitle.Text = "Módulo v$moduleVersion integrado à Central de Trabalho"
        $embeddedLoading.Text = "Carregando $moduleName..."
        $embeddedLoading.Visible = $true
        $embeddedContent.BackColor = $script:CurrentPalette.Background
        $embeddedContent.Controls.Clear()'''
new_loading = '''        $mainLayout.Visible = $false
        $embeddedHost.Visible = $true
        $embeddedHost.BringToFront()
        Set-ActiveNavigation ""
        $embeddedTitle.Text = $moduleName
        $embeddedSubtitle.Text = "Módulo v$moduleVersion integrado à Central de Trabalho"
        $embeddedContent.BackColor = $script:CurrentPalette.Background
        $embeddedContent.Controls.Clear()
        $embeddedLoading.Text = "Carregando $moduleName...`r`nAguarde um instante."
        $embeddedContent.Controls.Add($embeddedLoading)
        $embeddedLoading.Visible = $true
        $embeddedLoading.BringToFront()
        $form.UseWaitCursor = $true
        $embeddedContent.Cursor = [Windows.Forms.Cursors]::WaitCursor
        Set-StatusMessage "Carregando $moduleName..." "Normal"
        [Windows.Forms.Application]::DoEvents()'''
central = replace_once(central, old_loading, new_loading, 'feedback real de carregamento')

# Ao finalizar, o cursor e os comandos sempre voltam ao estado normal, inclusive em erro.
old_finally = '''    finally {
        $script:ModuleLoading = $false
        try { Update-CentralAvailabilityState } catch {}
    }
}

function Start-GeneratorModule'''
new_finally = '''    finally {
        $script:ModuleLoading = $false
        try { $form.UseWaitCursor = $false } catch {}
        try { $embeddedContent.Cursor = [Windows.Forms.Cursors]::Default } catch {}
        try { Update-CentralAvailabilityState } catch {}
    }
}

function Start-GeneratorModule'''
central = replace_once(central, old_finally, new_finally, 'restauracao apos carregamento')

# Se um módulo integrado se descartar por conta própria, libere também o módulo PowerShell
# correspondente em vez de deixar um escopo órfão na memória.
old_watch = '''            if ($script:HostedForm.IsDisposed) {
                Show-Dashboard -SkipClose
                $script:HostedForm = $null
                $script:EmbeddedModule = ""
                Set-StatusMessage "O módulo integrado foi fechado." "Normal"
            }'''
new_watch = '''            if ($script:HostedForm.IsDisposed) {
                Close-EmbeddedModule -Force
                Show-Dashboard -SkipClose
                Set-StatusMessage "O módulo integrado foi fechado." "Normal"
            }'''
central = replace_once(central, old_watch, new_watch, 'limpeza de modulo descartado')

# Atualizações, Pasta e Sobre são ações, não páginas internas. Mantém Início como seleção
# coerente após executá-las; ao entrar num módulo nenhuma rota lateral fica falsamente ativa.
central = replace_once(
    central,
    '$navUpdates.Add_Click({ Set-ActiveNavigation "Updates"; Start-UpdaterModule })',
    '$navUpdates.Add_Click({ Start-UpdaterModule; Set-ActiveNavigation "Home" })',
    'acao Atualizacoes'
)
central = replace_once(
    central,
    '$navFolder.Add_Click({ Set-ActiveNavigation "Folder"; Open-RootFolder })',
    '$navFolder.Add_Click({ Open-RootFolder; Set-ActiveNavigation "Home" })',
    'acao Pasta'
)
central = replace_once(
    central,
    '''    ) | Out-Null
})
$modulesFlow.Add_SizeChanged''',
    '''    ) | Out-Null
    Set-ActiveNavigation "Home"
})
$modulesFlow.Add_SizeChanged''',
    'retorno visual do Sobre'
)

# O redimensionamento já é resolvido pelo layout adaptativo; remove posições manuais de
# controles antigos para ter apenas uma fonte de verdade.
old_resize = '''$form.Add_SizeChanged({
    try {
        Update-CentralAdaptiveLayout
        $todayLabel.Left = [Math]::Max(360, $headerPanel.ClientSize.Width - 285)
        $headerStatusPill.Left = [Math]::Max(470, $headerPanel.ClientSize.Width - 155)
    } catch {}
})'''
new_resize = '''$form.Add_SizeChanged({
    try { Update-CentralAdaptiveLayout } catch {}
})'''
central = replace_once(central, old_resize, new_resize, 'evento de redimensionamento')

write(CENTRAL, central)
