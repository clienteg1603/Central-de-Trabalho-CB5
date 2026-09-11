#!/usr/bin/env python3
from pathlib import Path
import re

path = Path('src/generated/Central de Trabalho.ps1')
text = path.read_text(encoding='utf-8-sig')


def replace_once(old, new, label):
    global text
    if old not in text:
        raise SystemExit(f'Central 0.21.0: trecho ausente: {label}')
    text = text.replace(old, new, 1)


def replace_regex(pattern, replacement, label):
    global text
    text2, count = re.subn(pattern, replacement, text, count=1, flags=re.S)
    if count != 1:
        raise SystemExit(f'Central 0.21.0: padrão ausente ou ambíguo: {label} ({count})')
    text = text2

replace_once('$script:AppVersion = "0.20.3"', '$script:AppVersion = "0.21.0"', 'versão base 0.20.3')
replace_once(
'''$script:MaintenanceCore = [IO.Path]::Combine($script:MaintenanceDirectory, "Manutencao.Core.ps1")
$script:UpdaterDirectory = [IO.Path]::Combine($script:RootPath, "Atualizador")''',
'''$script:MaintenanceCore = [IO.Path]::Combine($script:MaintenanceDirectory, "Manutencao.Core.ps1")
$script:NFEntradaVersion = "1.0.0"
$script:NFEntradaDirectory = [IO.Path]::Combine(
    $script:RootPath,
    "Modulos",
    "Controle-NF-Entrada"
)
$script:NFEntradaScript = [IO.Path]::Combine($script:NFEntradaDirectory, "Controle NF Entrada.ps1")
$script:NFEntradaCore = [IO.Path]::Combine($script:NFEntradaDirectory, "NFEntrada.Core.ps1")
$script:UpdaterDirectory = [IO.Path]::Combine($script:RootPath, "Atualizador")''',
'caminhos NF Entrada')

replace_regex(
r'function Get-CentralHealthSnapshot \{.*?\n\}\n\nfunction Format-MissingCentralFiles',
'''function Get-CentralHealthSnapshot {
    $generatorRequired = @($script:GeneratorScript, $script:GeneratorCore)
    $maintenanceRequired = @($script:MaintenanceScript, $script:MaintenanceCore)
    $nfEntradaRequired = @($script:NFEntradaScript, $script:NFEntradaCore)
    $updaterRequired = @($script:UpdaterExecutable, $script:UpdaterScript, $script:UpdaterCore, $script:UpdaterChannels)

    $generatorMissing = @($generatorRequired | Where-Object { -not [IO.File]::Exists($_) })
    $maintenanceMissing = @($maintenanceRequired | Where-Object { -not [IO.File]::Exists($_) })
    $nfEntradaMissing = @($nfEntradaRequired | Where-Object { -not [IO.File]::Exists($_) })
    $updaterMissing = @($updaterRequired | Where-Object { -not [IO.File]::Exists($_) })

    [pscustomobject]@{
        GeneratorAvailable = ($generatorMissing.Count -eq 0)
        MaintenanceAvailable = ($maintenanceMissing.Count -eq 0)
        NFEntradaAvailable = ($nfEntradaMissing.Count -eq 0)
        UpdaterAvailable = ($updaterMissing.Count -eq 0)
        GeneratorMissing = $generatorMissing
        MaintenanceMissing = $maintenanceMissing
        NFEntradaMissing = $nfEntradaMissing
        UpdaterMissing = $updaterMissing
    }
}

function Format-MissingCentralFiles''',
'saúde da Central')

replace_regex(
r'function Start-EmbeddedModule \{\n\s*param\(\[ValidateSet\("Generator", "Maintenance"\)\]\[string\]\$Module\).*?\n\s*if \(-not \$moduleAvailable\) \{',
'''function Start-EmbeddedModule {
    param([ValidateSet("Generator", "Maintenance", "NFEntrada")][string]$Module)

    switch ($Module) {
        "Generator" {
            $moduleScript = $script:GeneratorScript
            $moduleName = "Gerenciador de Planilhas"
            $moduleVersion = $script:GeneratorVersion
        }
        "Maintenance" {
            $moduleScript = $script:MaintenanceScript
            $moduleName = "Central de Manutenção CB5"
            $moduleVersion = $script:MaintenanceVersion
        }
        default {
            $moduleScript = $script:NFEntradaScript
            $moduleName = "Controle de NF de Entrada"
            $moduleVersion = $script:NFEntradaVersion
        }
    }

    $health = Get-CentralHealthSnapshot
    switch ($Module) {
        "Generator" { $moduleAvailable = $health.GeneratorAvailable; $moduleMissing = @($health.GeneratorMissing) }
        "Maintenance" { $moduleAvailable = $health.MaintenanceAvailable; $moduleMissing = @($health.MaintenanceMissing) }
        default { $moduleAvailable = $health.NFEntradaAvailable; $moduleMissing = @($health.NFEntradaMissing) }
    }
    if (-not $moduleAvailable) {''',
'integração Start-EmbeddedModule')

replace_once(
'''$embeddedAccentLine.BackColor = if ($Module -eq "Generator") { Get-ModuleAccent "Generator" } else { Get-ModuleAccent "Maintenance" }''',
'''$embeddedAccentLine.BackColor = if ($Module -eq "Generator") { Get-ModuleAccent "Generator" } elseif ($Module -eq "Maintenance") { Get-ModuleAccent "Maintenance" } else { Get-ModuleAccent "NFEntrada" }''',
'acento do módulo integrado')

replace_once(
'''function Start-MaintenanceModule {
    Start-EmbeddedModule "Maintenance"
}

function Start-UpdaterModule''',
'''function Start-MaintenanceModule {
    Start-EmbeddedModule "Maintenance"
}

function Start-NFEntradaModule {
    Start-EmbeddedModule "NFEntrada"
}

function Start-UpdaterModule''',
'wrapper NF Entrada')

replace_regex(
r'function Get-ModuleAccent \{.*?\n\}\n\n\nfunction Get-CardHoverColor',
'''function Get-ModuleAccent {
    param([ValidateSet("Generator", "Maintenance", "NFEntrada")][string]$Module)
    $theme = [string]$themeCombo.SelectedItem
    if ($Module -eq "Generator") {
        if ($theme -eq "Claro corporativo") { return [Drawing.Color]::FromArgb(13, 142, 158) }
        if ($theme -eq "Técnico industrial") { return [Drawing.Color]::FromArgb(44, 189, 197) }
        if ($theme -eq "Alto contraste") { return [Drawing.Color]::Cyan }
        return [Drawing.Color]::FromArgb(33, 156, 211)
    }
    if ($Module -eq "NFEntrada") {
        if ($theme -eq "Claro corporativo") { return [Drawing.Color]::FromArgb(117, 90, 200) }
        if ($theme -eq "Técnico industrial") { return [Drawing.Color]::FromArgb(155, 120, 255) }
        if ($theme -eq "Alto contraste") { return [Drawing.Color]::Fuchsia }
        return [Drawing.Color]::FromArgb(139, 92, 246)
    }
    if ($theme -eq "Claro corporativo") { return [Drawing.Color]::FromArgb(220, 111, 24) }
    if ($theme -eq "Técnico industrial") { return [Drawing.Color]::FromArgb(244, 142, 40) }
    if ($theme -eq "Alto contraste") { return [Drawing.Color]::Orange }
    return [Drawing.Color]::FromArgb(222, 132, 28)
}


function Get-CardHoverColor''',
'acento visual NF Entrada')

replace_regex(
r'function Update-CentralAvailabilityState \{.*?\n\}\n\nfunction Apply-AppTheme',
'''function Update-CentralAvailabilityState {
    try {
        $health = Get-CentralHealthSnapshot
        $generatorAvailable = [bool]$health.GeneratorAvailable
        $maintenanceAvailable = [bool]$health.MaintenanceAvailable
        $nfEntradaAvailable = [bool]$health.NFEntradaAvailable
        $updaterAvailable = [bool]$health.UpdaterAvailable
        $generatorFolderAvailable = [IO.Directory]::Exists($script:GeneratorDirectory)
        $maintenanceFolderAvailable = [IO.Directory]::Exists($script:MaintenanceDirectory)
        $nfEntradaFolderAvailable = [IO.Directory]::Exists($script:NFEntradaDirectory)
        $moduleCount = ([int]$generatorAvailable + [int]$maintenanceAvailable + [int]$nfEntradaAvailable)

        if ($null -ne $script:UpdaterProcess) {
            try {
                if ($script:UpdaterProcess.HasExited) {
                    try { $script:UpdaterProcess.Dispose() } catch {}
                    $script:UpdaterProcess = $null
                }
            } catch { $script:UpdaterProcess = $null }
        }

        foreach ($pair in @(
            @($openGeneratorButton, $generatorAvailable),
            @($openMaintenanceButton, $maintenanceAvailable),
            @($openNFEntradaButton, $nfEntradaAvailable),
            @($openGeneratorFolderButton, $generatorFolderAvailable),
            @($openMaintenanceFolderButton, $maintenanceFolderAvailable),
            @($openNFEntradaFolderButton, $nfEntradaFolderAvailable)
        )) {
            $button = $pair[0]
            if ($null -ne $button) {
                $button.Enabled = ([bool]$pair[1] -and -not $script:ModuleLoading)
                $button.Cursor = if ($button.Enabled) { [Windows.Forms.Cursors]::Hand } else { [Windows.Forms.Cursors]::Default }
            }
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

        foreach ($entry in @(
            @($generatorStatus, $generatorAvailable, $generatorFolderAvailable),
            @($maintenanceStatus, $maintenanceAvailable, $maintenanceFolderAvailable),
            @($nfEntradaStatus, $nfEntradaAvailable, $nfEntradaFolderAvailable)
        )) {
            $status = $entry[0]
            if ($null -ne $status) {
                $available = [bool]$entry[1]
                $folderAvailable = [bool]$entry[2]
                $status.Text = if ($available) { "  DISPONÍVEL  " } elseif ($folderAvailable) { "  INCOMPLETO  " } else { "  INDISPONÍVEL  " }
                $status.BackColor = if ($available) { $script:CurrentPalette.SuccessBack } else { $script:CurrentPalette.PlannedBack }
                $status.ForeColor = if ($available) { $script:CurrentPalette.Success } else { $script:CurrentPalette.Planned }
            }
        }

        if ($null -ne $sidebarStatus -and $null -ne $sidebarStatusSub) {
            if ($generatorAvailable -and $maintenanceAvailable -and $nfEntradaAvailable -and $updaterAvailable) {
                $sidebarStatus.Text = "●  Sistema pronto"
                $sidebarStatusSub.Text = "3 módulos disponíveis"
                $sidebarStatus.ForeColor = $script:CurrentPalette.Success
            }
            else {
                $sidebarStatus.Text = "●  Atenção"
                if ($moduleCount -lt 3) {
                    $sidebarStatusSub.Text = "$moduleCount de 3 módulos disponíveis"
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

        $signature = "$generatorAvailable|$maintenanceAvailable|$nfEntradaAvailable|$updaterAvailable|$generatorFolderAvailable|$maintenanceFolderAvailable|$nfEntradaFolderAvailable|$(@($health.GeneratorMissing).Count)|$(@($health.MaintenanceMissing).Count)|$(@($health.NFEntradaMissing).Count)|$(@($health.UpdaterMissing).Count)|$($script:ModuleLoading)"
        if ($script:LastAvailabilitySignature -ne $signature) {
            $script:LastAvailabilitySignature = $signature
            try { $form.Invalidate($false) } catch {}
        }
    } catch {}
}

function Apply-AppTheme''',
'disponibilidade dos três módulos')

replace_once(
'''    $generatorAccent = Get-ModuleAccent "Generator"
    $maintenanceAccent = Get-ModuleAccent "Maintenance"''',
'''    $generatorAccent = Get-ModuleAccent "Generator"
    $maintenanceAccent = Get-ModuleAccent "Maintenance"
    $nfEntradaAccent = Get-ModuleAccent "NFEntrada"''',
'acento NF no tema')
replace_once(
'''foreach ($label in @($pageTitle, $programsTitle, $generatorTitle, $maintenanceTitle, $todayLabel, $embeddedTitle))''',
'''foreach ($label in @($pageTitle, $programsTitle, $generatorTitle, $maintenanceTitle, $nfEntradaTitle, $todayLabel, $embeddedTitle))''',
'rótulos principais NF')
replace_once(
'''foreach ($label in @($pageSubtitle, $programsSubtitle, $generatorDescription, $generatorDetail, $maintenanceDescription, $maintenanceDetail, $embeddedSubtitle, $embeddedLoading))''',
'''foreach ($label in @($pageSubtitle, $programsSubtitle, $generatorDescription, $generatorDetail, $maintenanceDescription, $maintenanceDetail, $nfEntradaDescription, $nfEntradaDetail, $embeddedSubtitle, $embeddedLoading))''',
'rótulos secundários NF')
replace_once('''foreach ($panel in @($generatorCard, $maintenanceCard))''', '''foreach ($panel in @($generatorCard, $maintenanceCard, $nfEntradaCard))''', 'painéis NF')
replace_once('''foreach ($layout in @($generatorLayout, $maintenanceLayout))''', '''foreach ($layout in @($generatorLayout, $maintenanceLayout, $nfEntradaLayout))''', 'layouts NF')
replace_once(
'''        $maintenanceAccentBar.BackColor = $maintenanceAccent
        $maintenanceIcon.BackColor = $maintenanceAccent
        $maintenanceIcon.ForeColor = [Drawing.Color]::White
        $generatorStatus.BackColor = $script:CurrentPalette.SuccessBack''',
'''        $maintenanceAccentBar.BackColor = $maintenanceAccent
        $maintenanceIcon.BackColor = $maintenanceAccent
        $maintenanceIcon.ForeColor = [Drawing.Color]::White
        $nfEntradaAccentBar.BackColor = $nfEntradaAccent
        $nfEntradaIcon.BackColor = $nfEntradaAccent
        $nfEntradaIcon.ForeColor = [Drawing.Color]::White
        $generatorStatus.BackColor = $script:CurrentPalette.SuccessBack''',
'cores NF')
replace_once(
'''        $maintenanceStatus.BackColor = $script:CurrentPalette.SuccessBack
        $maintenanceStatus.ForeColor = $script:CurrentPalette.Success''',
'''        $maintenanceStatus.BackColor = $script:CurrentPalette.SuccessBack
        $maintenanceStatus.ForeColor = $script:CurrentPalette.Success
        $nfEntradaStatus.BackColor = $script:CurrentPalette.SuccessBack
        $nfEntradaStatus.ForeColor = $script:CurrentPalette.Success''',
'status NF')
replace_once(
'''        Set-PrimaryButtonStyle $openMaintenanceButton
        $openMaintenanceButton.BackColor = $maintenanceAccent
        $openMaintenanceButton.ForeColor = [Drawing.Color]::White
        Set-SecondaryButtonStyle $openGeneratorFolderButton
        Set-SecondaryButtonStyle $openMaintenanceFolderButton''',
'''        Set-PrimaryButtonStyle $openMaintenanceButton
        $openMaintenanceButton.BackColor = $maintenanceAccent
        $openMaintenanceButton.ForeColor = [Drawing.Color]::White
        Set-PrimaryButtonStyle $openNFEntradaButton
        $openNFEntradaButton.BackColor = $nfEntradaAccent
        $openNFEntradaButton.ForeColor = [Drawing.Color]::White
        Set-SecondaryButtonStyle $openGeneratorFolderButton
        Set-SecondaryButtonStyle $openMaintenanceFolderButton
        Set-SecondaryButtonStyle $openNFEntradaFolderButton''',
'botões NF')
replace_once(
'''$embeddedAccentLine.BackColor = if ($script:EmbeddedModule -eq "Generator") { $generatorAccent } elseif ($script:EmbeddedModule -eq "Maintenance") { $maintenanceAccent } else { $script:CurrentPalette.Accent }''',
'''$embeddedAccentLine.BackColor = if ($script:EmbeddedModule -eq "Generator") { $generatorAccent } elseif ($script:EmbeddedModule -eq "Maintenance") { $maintenanceAccent } elseif ($script:EmbeddedModule -eq "NFEntrada") { $nfEntradaAccent } else { $script:CurrentPalette.Accent }''',
'acento toolbar NF')
replace_once(
'''foreach ($rounded in @($generatorCard,$maintenanceCard,$brandMark,$generatorIcon,$maintenanceIcon,$openGeneratorButton,$openMaintenanceButton,$openGeneratorFolderButton,$openMaintenanceFolderButton))''',
'''foreach ($rounded in @($generatorCard,$maintenanceCard,$nfEntradaCard,$brandMark,$generatorIcon,$maintenanceIcon,$nfEntradaIcon,$openGeneratorButton,$openMaintenanceButton,$openNFEntradaButton,$openGeneratorFolderButton,$openMaintenanceFolderButton,$openNFEntradaFolderButton))''',
'arredondamento NF')

replace_regex(
r'function Update-ResponsiveLayout \{.*?\n\}\n\nfunction Update-CentralChromeLayout',
'''function Update-ResponsiveLayout {
    if ($null -eq $modulesFlow -or $modulesFlow.ClientSize.Width -le 0) { return }
    try {
        $availableWidth = [Math]::Max(360, $modulesFlow.ClientSize.Width - $modulesFlow.Padding.Horizontal - 34)
        $availableHeight = [Math]::Max(220, $modulesFlow.ClientSize.Height - $modulesFlow.Padding.Vertical - 12)
        $twoColumns = ($availableWidth -ge 860)

        if ($twoColumns) {
            $moduleWidth = [int](($availableWidth - 22) / 2)
            $moduleHeight = [Math]::Min(230, [Math]::Max(205, [int](($availableHeight - 22) / 2)))
        }
        else {
            $moduleWidth = $availableWidth
            $moduleHeight = [Math]::Min(215, [Math]::Max(195, [int](($availableHeight - 40) / 3)))
        }

        foreach ($card in @($generatorCard, $maintenanceCard, $nfEntradaCard)) {
            if ($null -ne $card) {
                $card.Width = $moduleWidth
                $card.Height = $moduleHeight
            }
        }

        $compactCard = ($moduleWidth -lt 560)
        foreach ($titleLabel in @($generatorTitle, $maintenanceTitle, $nfEntradaTitle)) {
            if ($null -ne $titleLabel) {
                $titleLabel.Font = [Drawing.Font]::new("Segoe UI Semibold", $(if ($compactCard) { 12.5 } else { 14.5 }))
                $titleLabel.AutoEllipsis = $true
            }
        }
        foreach ($description in @($generatorDescription, $maintenanceDescription, $generatorDetail, $maintenanceDetail, $nfEntradaDescription, $nfEntradaDetail)) {
            if ($null -ne $description) { $description.AutoEllipsis = $true }
        }

        $openGeneratorButton.Text = if ($moduleWidth -lt 470) { "ABRIR" } else { "ABRIR GERENCIADOR" }
        $openMaintenanceButton.Text = if ($moduleWidth -lt 470) { "ABRIR" } else { "ABRIR MANUTENÇÃO" }
        $openNFEntradaButton.Text = if ($moduleWidth -lt 470) { "ABRIR" } else { "ABRIR CONTROLE" }

        foreach ($openButton in @($openGeneratorButton, $openMaintenanceButton, $openNFEntradaButton)) {
            try {
                $buttonHost = $openButton.Parent
                if ($buttonHost -is [Windows.Forms.TableLayoutPanel] -and $buttonHost.ColumnStyles.Count -ge 2) {
                    if ($moduleWidth -lt 470) {
                        $buttonHost.ColumnStyles[0].Width = 66
                        $buttonHost.ColumnStyles[1].Width = 34
                    }
                    else {
                        $buttonHost.ColumnStyles[0].Width = 72
                        $buttonHost.ColumnStyles[1].Width = 28
                    }
                }
            } catch {}
        }
    } catch {}
}

function Update-CentralChromeLayout''',
'layout responsivo com terceiro card')

replace_once('$sidebarStatusSub.Text = "2 módulos disponíveis"', '$sidebarStatusSub.Text = "3 módulos disponíveis"', 'texto inicial sidebar')

replace_once(
'''$m = New-ModuleCard "CB5" "Central de Manutenção CB5" "Cadastro de peças por código, histórico automático por série, correção auditada, relatórios e apoio ao diagnóstico." "Versão integrada: $($script:MaintenanceVersion)   •   Histórico local por série" "ABRIR MANUTENÇÃO"
$maintenanceCard=$m[0]; $maintenanceOuter=$m[1]; $maintenanceLayout=$m[2]; $maintenanceAccentBar=$m[3]; $maintenanceIcon=$m[4]; $maintenanceStatus=$m[5]; $maintenanceTitle=$m[6]; $maintenanceDescription=$m[7]; $maintenanceDetail=$m[8]; $openMaintenanceButton=$m[9]; $openMaintenanceFolderButton=$m[10]
$modulesFlow.Controls.Add($generatorCard)
$modulesFlow.Controls.Add($maintenanceCard)''',
'''$m = New-ModuleCard "CB5" "Central de Manutenção CB5" "Cadastro de peças por código, histórico automático por série, correção auditada, relatórios e apoio ao diagnóstico." "Versão integrada: $($script:MaintenanceVersion)   •   Histórico local por série" "ABRIR MANUTENÇÃO"
$maintenanceCard=$m[0]; $maintenanceOuter=$m[1]; $maintenanceLayout=$m[2]; $maintenanceAccentBar=$m[3]; $maintenanceIcon=$m[4]; $maintenanceStatus=$m[5]; $maintenanceTitle=$m[6]; $maintenanceDescription=$m[7]; $maintenanceDetail=$m[8]; $openMaintenanceButton=$m[9]; $openMaintenanceFolderButton=$m[10]
$n = New-ModuleCard "NF" "Controle de NF de Entrada" "Controla entradas, saldos e movimentações de Computador de Bordo V5 e Teclado V5 e exporta no modelo original." "Versão integrada: $($script:NFEntradaVersion)   •   Modelo original .xlsx" "ABRIR CONTROLE"
$nfEntradaCard=$n[0]; $nfEntradaOuter=$n[1]; $nfEntradaLayout=$n[2]; $nfEntradaAccentBar=$n[3]; $nfEntradaIcon=$n[4]; $nfEntradaStatus=$n[5]; $nfEntradaTitle=$n[6]; $nfEntradaDescription=$n[7]; $nfEntradaDetail=$n[8]; $openNFEntradaButton=$n[9]; $openNFEntradaFolderButton=$n[10]
$modulesFlow.Controls.Add($generatorCard)
$modulesFlow.Controls.Add($maintenanceCard)
$modulesFlow.Controls.Add($nfEntradaCard)''',
'card Controle NF Entrada')

replace_once(
'''$toolTip.SetToolTip($openMaintenanceFolderButton, "Abrir a pasta da Manutenção CB5")
$toolTip.SetToolTip($embeddedBackButton''',
'''$toolTip.SetToolTip($openMaintenanceFolderButton, "Abrir a pasta da Manutenção CB5")
$toolTip.SetToolTip($openNFEntradaButton, "Abrir o Controle de NF de Entrada dentro da Central")
$toolTip.SetToolTip($openNFEntradaFolderButton, "Abrir a pasta do Controle de NF de Entrada")
$toolTip.SetToolTip($embeddedBackButton''',
'tooltips NF')
replace_once('''foreach ($roundedPanel in @($generatorCard,$maintenanceCard))''', '''foreach ($roundedPanel in @($generatorCard,$maintenanceCard,$nfEntradaCard))''', 'cards arredondados NF')
replace_once(
'''foreach ($roundedSmall in @($brandMark,$generatorIcon,$maintenanceIcon,$openGeneratorButton,$openMaintenanceButton,$openGeneratorFolderButton,$openMaintenanceFolderButton))''',
'''foreach ($roundedSmall in @($brandMark,$generatorIcon,$maintenanceIcon,$nfEntradaIcon,$openGeneratorButton,$openMaintenanceButton,$openNFEntradaButton,$openGeneratorFolderButton,$openMaintenanceFolderButton,$openNFEntradaFolderButton))''',
'controles arredondados NF')
replace_once(
'''$openMaintenanceButton.TabIndex = 12
$openMaintenanceFolderButton.TabIndex = 13
$embeddedBackButton.TabIndex = 0''',
'''$openMaintenanceButton.TabIndex = 12
$openMaintenanceFolderButton.TabIndex = 13
$openNFEntradaButton.TabIndex = 14
$openNFEntradaFolderButton.TabIndex = 15
$embeddedBackButton.TabIndex = 0''',
f'ordem de foco NF')
replace_once(
'''$openMaintenanceButton.Add_Click({ Start-MaintenanceModule })
$openGeneratorFolderButton.Add_Click''',
'''$openMaintenanceButton.Add_Click({ Start-MaintenanceModule })
$openNFEntradaButton.Add_Click({ Start-NFEntradaModule })
$openGeneratorFolderButton.Add_Click''',
'evento abrir NF')
replace_once(
'''$openMaintenanceFolderButton.Add_Click({ Open-ModuleFolder $script:MaintenanceDirectory "Central de Manutenção CB5" })
$navUpdates.Add_Click''',
'''$openMaintenanceFolderButton.Add_Click({ Open-ModuleFolder $script:MaintenanceDirectory "Central de Manutenção CB5" })
$openNFEntradaFolderButton.Add_Click({ Open-ModuleFolder $script:NFEntradaDirectory "Controle de NF de Entrada" })
$navUpdates.Add_Click''',
'evento pasta NF')
replace_once(
'''Integra o Gerenciador de Planilhas, a Central de Manutenção CB5 e o sistema de atualização.''',
'''Integra o Gerenciador de Planilhas, a Central de Manutenção CB5, o Controle de NF de Entrada e o sistema de atualização.''',
'sobre NF')
replace_once(
'''    if ($script:EmbeddedModule -eq "Generator") { Open-ModuleFolder $script:GeneratorDirectory "Gerenciador de Planilhas" }
    elseif ($script:EmbeddedModule -eq "Maintenance") { Open-ModuleFolder $script:MaintenanceDirectory "Central de Manutenção CB5" }
})''',
'''    if ($script:EmbeddedModule -eq "Generator") { Open-ModuleFolder $script:GeneratorDirectory "Gerenciador de Planilhas" }
    elseif ($script:EmbeddedModule -eq "Maintenance") { Open-ModuleFolder $script:MaintenanceDirectory "Central de Manutenção CB5" }
    elseif ($script:EmbeddedModule -eq "NFEntrada") { Open-ModuleFolder $script:NFEntradaDirectory "Controle de NF de Entrada" }
})''',
'pasta do módulo NF')

# Garante que contratos essenciais foram realmente inseridos antes de publicar.
required = [
    '$script:AppVersion = "0.21.0"',
    '$script:NFEntradaVersion = "1.0.0"',
    'Start-EmbeddedModule "NFEntrada"',
    'New-ModuleCard "NF" "Controle de NF de Entrada"',
    '3 módulos disponíveis',
    'Get-ModuleAccent "NFEntrada"',
    '$openNFEntradaButton.Add_Click({ Start-NFEntradaModule })',
]
for marker in required:
    if marker not in text:
        raise SystemExit(f'Central 0.21.0: marcador final ausente: {marker}')

path.write_text(text, encoding='utf-8-sig')
print('0.21.0: integra Controle de NF de Entrada como terceiro módulo da Central.')
