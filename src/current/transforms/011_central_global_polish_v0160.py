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
central = replace_once(central, '$script:AppVersion = "0.15.2"', '$script:AppVersion = "0.16.0"', 'versao Central')

start = central.find('function Update-ResponsiveLayout {\n')
end_marker = '\n\n$script:CentralAdaptiveBusy = $false\n'
end = central.find(end_marker, start)
if start < 0 or end < 0:
    raise RuntimeError('bloco Update-ResponsiveLayout nao localizado')

new_helpers = r'''function Update-ResponsiveLayout {
    if ($null -eq $modulesFlow -or $modulesFlow.ClientSize.Width -le 0) { return }
    try {
        $availableWidth = [Math]::Max(360, $modulesFlow.ClientSize.Width - $modulesFlow.Padding.Horizontal - 34)
        $availableHeight = [Math]::Max(220, $modulesFlow.ClientSize.Height - $modulesFlow.Padding.Vertical - 12)
        $twoColumns = ($availableWidth -ge 860)

        if ($twoColumns) {
            $moduleWidth = [int](($availableWidth - 22) / 2)
            $moduleHeight = [Math]::Min(252, [Math]::Max(220, $availableHeight - 10))
        }
        else {
            $moduleWidth = $availableWidth
            $moduleHeight = [Math]::Min(238, [Math]::Max(205, [int](($availableHeight - 26) / 2)))
        }

        foreach ($card in @($generatorCard, $maintenanceCard)) {
            if ($null -ne $card) {
                $card.Width = $moduleWidth
                $card.Height = $moduleHeight
            }
        }

        $compactCard = ($moduleWidth -lt 560)
        foreach ($titleLabel in @($generatorTitle, $maintenanceTitle)) {
            if ($null -ne $titleLabel) {
                $titleLabel.Font = [Drawing.Font]::new("Segoe UI Semibold", $(if ($compactCard) { 12.5 } else { 14.5 }))
                $titleLabel.AutoEllipsis = $true
            }
        }
        foreach ($description in @($generatorDescription, $maintenanceDescription, $generatorDetail, $maintenanceDetail)) {
            if ($null -ne $description) { $description.AutoEllipsis = $true }
        }

        $openGeneratorButton.Text = if ($moduleWidth -lt 470) { "ABRIR" } else { "ABRIR GERENCIADOR" }
        $openMaintenanceButton.Text = if ($moduleWidth -lt 470) { "ABRIR" } else { "ABRIR MANUTENÇÃO" }

        foreach ($openButton in @($openGeneratorButton, $openMaintenanceButton)) {
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

function Update-CentralChromeLayout {
    try {
        # Cabeçalho principal: título, subtítulo e data nunca disputam o mesmo espaço.
        if ($null -ne $headerPanel -and $headerPanel.ClientSize.Width -gt 0) {
            $hw = [int]$headerPanel.ClientSize.Width
            $right = 26
            $todayLabel.Visible = ($hw -ge 620)
            if ($todayLabel.Visible) {
                $todayLabel.Left = [Math]::Max(330, $hw - $todayLabel.Width - $right)
                $textRight = $todayLabel.Left - 22
            }
            else {
                $textRight = $hw - $right
            }
            $pageTitle.Width = [Math]::Max(210, $textRight - $pageTitle.Left)
            $pageTitle.AutoEllipsis = $true
            $pageSubtitle.Width = [Math]::Max(210, $textRight - $pageSubtitle.Left)
            $pageSubtitle.AutoEllipsis = $true
        }

        # Cabeçalho dos programas acompanha a largura real do painel.
        if ($null -ne $programsHeader -and $programsHeader.ClientSize.Width -gt 0) {
            $programsTitle.Width = [Math]::Max(180, $programsHeader.ClientSize.Width - 20)
            $programsTitle.AutoEllipsis = $true
            $programsSubtitle.Width = [Math]::Max(180, $programsHeader.ClientSize.Width - 24)
            $programsSubtitle.AutoEllipsis = $true
        }

        # Barra lateral: controles usam a largura interna real, não tamanhos históricos fixos.
        if ($null -ne $navPanel -and $navPanel.ClientSize.Width -gt 0) {
            $navWidth = [Math]::Max(118, $navPanel.ClientSize.Width - $navPanel.Padding.Horizontal - 2)
            foreach ($b in @($navHome,$navUpdates,$navFolder,$navAbout)) {
                if ($null -ne $b) { $b.Width = $navWidth }
            }
        }
        if ($null -ne $sidebarBottom -and $sidebarBottom.ClientSize.Width -gt 0) {
            $bottomWidth = [Math]::Max(118, $sidebarBottom.ClientSize.Width - 8)
            foreach ($c in @($sidebarThemeLabel,$themeCombo,$sidebarStatus,$sidebarVersion)) {
                if ($null -ne $c) { $c.Width = $bottomWidth }
            }
            if ($null -ne $sidebarStatusSub) { $sidebarStatusSub.Width = [Math]::Max(100, $sidebarBottom.ClientSize.Width - 24) }
        }

        # Toolbar de um módulo integrado: pasta fica presa à direita e textos usam só o espaço restante.
        if ($null -ne $embeddedToolbar -and $embeddedToolbar.ClientSize.Width -gt 0) {
            $tw = [int]$embeddedToolbar.ClientSize.Width
            $embeddedFolderButton.Left = [Math]::Max(260, $tw - $embeddedFolderButton.Width - 12)
            $textWidth = [Math]::Max(120, $embeddedFolderButton.Left - $embeddedTitle.Left - 12)
            $embeddedTitle.Width = $textWidth
            $embeddedTitle.AutoEllipsis = $true
            $embeddedSubtitle.Width = [Math]::Max(120, $embeddedFolderButton.Left - $embeddedSubtitle.Left - 12)
            $embeddedSubtitle.AutoEllipsis = $true
        }

        Update-ResponsiveLayout
    } catch {}
}
'''

central = central[:start] + new_helpers + central[end:]

central = replace_once(
    central,
    '''        try { $embeddedFolderButton.Left = [Math]::Max(380, $embeddedToolbar.ClientSize.Width - $embeddedFolderButton.Width - 12) } catch {}
        Update-ResponsiveLayout''',
    '''        try { $embeddedFolderButton.Left = [Math]::Max(260, $embeddedToolbar.ClientSize.Width - $embeddedFolderButton.Width - 12) } catch {}
        Update-CentralChromeLayout''',
    'chamada do polimento global'
)

# Mantém o layout recalculado também quando as áreas que mudam de tamanho são redimensionadas.
insert_marker = '$modulesFlow.Add_SizeChanged({ Update-ResponsiveLayout })\n'
if insert_marker in central:
    central = central.replace(insert_marker, '$modulesFlow.Add_SizeChanged({ Update-CentralChromeLayout })\n', 1)
else:
    # Algumas bases chamam Update-ResponsiveLayout apenas pelo resize da janela; nesse caso não falha o build.
    pass

write(CENTRAL, central)
