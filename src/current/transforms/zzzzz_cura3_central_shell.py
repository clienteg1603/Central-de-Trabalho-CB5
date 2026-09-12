from pathlib import Path

path = Path('src/generated/Central de Trabalho.ps1')
text = path.read_text(encoding='utf-8-sig')


def one(old: str, new: str, label: str):
    global text
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'CURA 3 {label}: esperado 1 marcador, encontrado {count}')
    text = text.replace(old, new, 1)


# A cadeia anterior termina em 0.21.36. A CURA 3 altera somente a casca da Central.
one('$script:AppVersion = "0.21.36"', '$script:AppVersion = "0.21.37"', 'versão da Central')

# Aparência foi removida do produto: o ComboBox continua existindo internamente apenas
# para compatibilidade com os módulos/testes antigos, mas nunca volta a ocupar a UI.
old_hidden = '''if (-not $ThemeRuntimeSelfTest) {
    $sidebarThemeLabel.Visible = $false
    $themeCombo.Visible = $false
}'''
new_hidden = '''# CURA 3 — aparência fixa: nenhum controle de tema participa mais da interface.
# O objeto permanece somente como ponte interna de compatibilidade com código legado.
$sidebarThemeLabel.Visible = $false
$themeCombo.Visible = $false
$themeCombo.TabStop = $false'''
one(old_hidden, new_hidden, 'remoção definitiva do seletor visual')
one('$themeCombo.TabIndex = 4', '$themeCombo.TabIndex = 99\n$themeCombo.TabStop = $false', 'ordem de foco sem aparência')

# Cards no Técnico industrial já se distinguem por superfície + faixa lateral. A borda
# quadrada FixedSingle brigava com o recorte arredondado e criava caixa dentro de caixa.
one('$panel.BorderStyle = [Windows.Forms.BorderStyle]::FixedSingle', '$panel.BorderStyle = [Windows.Forms.BorderStyle]::None', 'moldura dos cards')

# Fluxo dos módulos: três colunas em telas realmente largas, duas no uso normal/125-150%
# e uma só quando a largura lógica exige. O cálculo usa DPI real para não confundir
# 150% com uma tela fisicamente enorme.
start = text.find('function Update-ResponsiveLayout {')
end = text.find('function Update-CentralChromeLayout {', start)
if start < 0 or end < 0 or end <= start:
    raise SystemExit('CURA 3: bloco Update-ResponsiveLayout não localizado')

new_responsive = r'''function Update-ResponsiveLayout {
    if ($null -eq $modulesFlow -or $modulesFlow.ClientSize.Width -le 0) { return }
    try {
        $dpi = 96
        try { if ($form.DeviceDpi -gt 0) { $dpi = [int]$form.DeviceDpi } } catch {}

        $availableWidth = [Math]::Max(320, $modulesFlow.ClientSize.Width - $modulesFlow.Padding.Horizontal - 8)
        $availableHeight = [Math]::Max(220, $modulesFlow.ClientSize.Height - $modulesFlow.Padding.Vertical - 8)
        $logicalWidth = [int][Math]::Round($availableWidth * 96.0 / $dpi)

        # 3 colunas só quando cada card continua confortável em largura lógica.
        $columns = if ($logicalWidth -ge 1400) { 3 } elseif ($logicalWidth -ge 760) { 2 } else { 1 }
        $cardMargins = 16 * $columns
        $moduleWidth = [Math]::Max(300, [int](($availableWidth - $cardMargins) / $columns))

        if ($columns -eq 3) {
            $moduleHeight = [Math]::Min(282, [Math]::Max(230, $availableHeight - 18))
        }
        elseif ($columns -eq 2) {
            $moduleHeight = [Math]::Min(238, [Math]::Max(208, [int](($availableHeight - 34) / 2)))
        }
        else {
            $moduleHeight = [Math]::Min(218, [Math]::Max(190, [int](($availableHeight - 46) / 3)))
        }

        foreach ($card in @($generatorCard, $maintenanceCard, $nfEntradaCard)) {
            if ($null -ne $card) {
                $card.Width = $moduleWidth
                $card.Height = $moduleHeight
            }
        }

        $compactCard = ($moduleWidth -lt 455)
        foreach ($titleLabel in @($generatorTitle, $maintenanceTitle, $nfEntradaTitle)) {
            if ($null -ne $titleLabel) {
                $titleLabel.Font = [Drawing.Font]::new('Segoe UI Semibold', $(if ($compactCard) { 11.8 } else { 13.8 }))
                $titleLabel.AutoEllipsis = $true
            }
        }
        foreach ($description in @($generatorDescription, $maintenanceDescription, $generatorDetail, $maintenanceDetail, $nfEntradaDescription, $nfEntradaDetail)) {
            if ($null -ne $description) { $description.AutoEllipsis = $true }
        }

        $openGeneratorButton.Text = if ($moduleWidth -lt 420) { 'ABRIR' } else { 'ABRIR GERENCIADOR' }
        $openMaintenanceButton.Text = if ($moduleWidth -lt 420) { 'ABRIR' } else { 'ABRIR MANUTENÇÃO' }
        $openNFEntradaButton.Text = if ($moduleWidth -lt 420) { 'ABRIR' } else { 'ABRIR CONTROLE' }

        foreach ($openButton in @($openGeneratorButton, $openMaintenanceButton, $openNFEntradaButton)) {
            try {
                $buttonHost = $openButton.Parent
                if ($buttonHost -is [Windows.Forms.TableLayoutPanel] -and $buttonHost.ColumnStyles.Count -ge 2) {
                    if ($moduleWidth -lt 420) {
                        $buttonHost.ColumnStyles[0].Width = 64
                        $buttonHost.ColumnStyles[1].Width = 36
                    }
                    else {
                        $buttonHost.ColumnStyles[0].Width = 74
                        $buttonHost.ColumnStyles[1].Width = 26
                    }
                }
            } catch {}
        }
    } catch {}
}

'''
text = text[:start] + new_responsive + text[end:]

# Densidade da casca por perfil. Além do menu lateral, cabeçalho, rodapé e área dos
# programas passam a acompanhar a largura/altura lógica. O painel inferior da sidebar
# perde o espaço morto que pertencia ao antigo seletor de aparência.
adaptive_marker = '''        # A altura visual da toolbar precisa ser a altura real da linha que a
        # hospeda; alterar somente Panel.Height não muda uma linha Absolute.'''
adaptive_block = r'''        # CURA 3 — densidade visual da própria Central.
        switch ($profile) {
            'Compact' {
                $sidebarBottom.Height = 92
                $mainLayout.RowStyles[0].Height = 76
                $mainLayout.RowStyles[2].Height = 38
                $modulesLayout.RowStyles[0].Height = 44
                $modulesHost.Padding = [Windows.Forms.Padding]::new(10, 0, 10, 2)
                $headerPanel.Padding = [Windows.Forms.Padding]::new(18, 8, 18, 5)
                $pageTitle.Location = [Drawing.Point]::new(18, 7)
                $pageTitle.Font = [Drawing.Font]::new('Segoe UI Semibold', 18)
                $pageSubtitle.Location = [Drawing.Point]::new(20, 40)
                $pageSubtitle.Font = [Drawing.Font]::new('Segoe UI', 8.8)
                $programsTitle.Location = [Drawing.Point]::new(6, 0)
                $programsTitle.Font = [Drawing.Font]::new('Segoe UI Semibold', 12.4)
                $programsSubtitle.Location = [Drawing.Point]::new(8, 23)
                $programsSubtitle.Font = [Drawing.Font]::new('Segoe UI', 8.0)
            }
            'Balanced' {
                $sidebarBottom.Height = 98
                $mainLayout.RowStyles[0].Height = 84
                $mainLayout.RowStyles[2].Height = 40
                $modulesLayout.RowStyles[0].Height = 48
                $modulesHost.Padding = [Windows.Forms.Padding]::new(14, 0, 14, 3)
                $headerPanel.Padding = [Windows.Forms.Padding]::new(22, 10, 22, 6)
                $pageTitle.Location = [Drawing.Point]::new(22, 9)
                $pageTitle.Font = [Drawing.Font]::new('Segoe UI Semibold', 19.5)
                $pageSubtitle.Location = [Drawing.Point]::new(24, 45)
                $pageSubtitle.Font = [Drawing.Font]::new('Segoe UI', 9.5)
                $programsTitle.Location = [Drawing.Point]::new(8, 0)
                $programsTitle.Font = [Drawing.Font]::new('Segoe UI Semibold', 13.2)
                $programsSubtitle.Location = [Drawing.Point]::new(10, 25)
                $programsSubtitle.Font = [Drawing.Font]::new('Segoe UI', 8.4)
            }
            default {
                $sidebarBottom.Height = 104
                $mainLayout.RowStyles[0].Height = 90
                $mainLayout.RowStyles[2].Height = 42
                $modulesLayout.RowStyles[0].Height = 50
                $modulesHost.Padding = [Windows.Forms.Padding]::new(18, 0, 18, 4)
                $headerPanel.Padding = [Windows.Forms.Padding]::new(26, 11, 24, 7)
                $pageTitle.Location = [Drawing.Point]::new(26, 10)
                $pageTitle.Font = [Drawing.Font]::new('Segoe UI Semibold', 20.5)
                $pageSubtitle.Location = [Drawing.Point]::new(28, 48)
                $pageSubtitle.Font = [Drawing.Font]::new('Segoe UI', 10)
                $programsTitle.Location = [Drawing.Point]::new(10, 0)
                $programsTitle.Font = [Drawing.Font]::new('Segoe UI Semibold', 13.8)
                $programsSubtitle.Location = [Drawing.Point]::new(12, 26)
                $programsSubtitle.Font = [Drawing.Font]::new('Segoe UI', 8.7)
            }
        }

'''
one(adaptive_marker, adaptive_block + adaptive_marker, 'densidade adaptativa da Central')

# O FlowLayout recebe um pouco mais de respiro vertical e menos margem lateral dupla.
one('$modulesFlow.Padding = [Windows.Forms.Padding]::new(8, 2, 8, 4)', '$modulesFlow.Padding = [Windows.Forms.Padding]::new(4, 5, 4, 8)', 'respiro da grade de módulos')

# Autoteste visual do dashboard em três tamanhos. Não depende de captura de tela para
# decidir sucesso: mede sobreposição, área válida e presença dos três cards.
helper_marker = 'function Invoke-CentralThemeRuntimeSelfTest {'
helper = r'''function Assert-CentralDashboardLayout {
    param([Drawing.Size]$TargetSize, [string]$Scenario)

    $form.Size = $TargetSize
    $form.PerformLayout()
    Update-CentralAdaptiveLayout
    Update-ResponsiveLayout
    [Windows.Forms.Application]::DoEvents()

    if ($sidebar.Width -le 0 -or $mainPanel.Width -le 0) { throw "${Scenario}: estrutura principal sem área útil." }
    if ($headerPanel.Height -lt 60 -or $modulesHost.Height -lt 180) { throw "${Scenario}: cabeçalho ou área de programas colapsou." }

    $cards = @($generatorCard, $maintenanceCard, $nfEntradaCard)
    foreach ($card in $cards) {
        if ($null -eq $card -or $card.Width -lt 280 -or $card.Height -lt 180) {
            throw "${Scenario}: card de módulo ficou abaixo do tamanho mínimo utilizável."
        }
    }
    for ($i = 0; $i -lt $cards.Count; $i++) {
        for ($j = $i + 1; $j -lt $cards.Count; $j++) {
            if ($cards[$i].Bounds.IntersectsWith($cards[$j].Bounds)) {
                throw "${Scenario}: cards de módulos se sobrepuseram."
            }
        }
    }
    if ($sidebarThemeLabel.Visible -or $themeCombo.Visible) {
        throw "${Scenario}: seletor de aparência voltou a ficar visível."
    }
    return [pscustomobject]@{
        Scenario = $Scenario
        Profile = $script:CentralAdaptiveProfile
        Width = $form.ClientSize.Width
        Height = $form.ClientSize.Height
        CardWidth = $generatorCard.Width
        CardHeight = $generatorCard.Height
    }
}

'''
if text.count(helper_marker) != 1:
    raise SystemExit(f'CURA 3 autoteste: esperado 1 marcador, encontrado {text.count(helper_marker)}')
text = text.replace(helper_marker, helper + helper_marker, 1)

# Exercita Compact/Balanced/Comfortable antes dos testes dos módulos e volta ao tamanho
# normal usado pelo diagnóstico integrado.
show_marker = '''    $form.Show()
    Wait-CentralThemeRuntimeUi 450

    try {'''
show_replacement = '''    $form.Show()
    Wait-CentralThemeRuntimeUi 450

    # CURA 3: valida a casca antes de abrir qualquer módulo.
    $layoutCases = @(
        (Assert-CentralDashboardLayout ([Drawing.Size]::new(980, 640)) 'Central/compact'),
        (Assert-CentralDashboardLayout ([Drawing.Size]::new(1260, 760)) 'Central/balanced'),
        (Assert-CentralDashboardLayout ([Drawing.Size]::new(1680, 940)) 'Central/comfortable')
    )
    $form.Size = [Drawing.Size]::new(1440, 900)
    Update-CentralAdaptiveLayout
    Update-ResponsiveLayout
    Wait-CentralThemeRuntimeUi 200
    $dashboardShot = Save-CentralThemeRuntimeScreenshot 'Central-dashboard-cura3'
    if (-not [string]::IsNullOrWhiteSpace($dashboardShot)) { $screenshots.Add($dashboardShot) }

    try {'''
one(show_marker, show_replacement, 'autoteste de tamanhos da Central')

# Valida invariantes do transform já no build Linux, antes do PowerShell/Windows.
required = [
    '$script:AppVersion = "0.21.37"',
    '$themeCombo.Visible = $false',
    '$themeCombo.TabStop = $false',
    '$columns = if ($logicalWidth -ge 1400) { 3 } elseif ($logicalWidth -ge 760) { 2 } else { 1 }',
    'function Assert-CentralDashboardLayout',
    '$panel.BorderStyle = [Windows.Forms.BorderStyle]::None',
]
for marker in required:
    if marker not in text:
        raise SystemExit('CURA 3 validação: marcador ausente: ' + marker)

path.write_text(text, encoding='utf-8')
print('CURA 3 CENTRAL: OK - shell polida, tema fixo limpo, grade 3/2/1 por DPI e autoteste de layout incluído.')
