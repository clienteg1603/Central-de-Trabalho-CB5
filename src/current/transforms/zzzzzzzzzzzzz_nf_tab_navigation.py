from pathlib import Path

cp = Path('src/generated/Central de Trabalho.ps1')
np = Path('src/generated/Modulos/Controle-NF-Entrada/Controle NF Entrada.ps1')
c = cp.read_text(encoding='utf-8-sig')
n = np.read_text(encoding='utf-8-sig')

def r(t, a, b, label):
    if t.count(a) != 1:
        raise SystemExit(f'{label}: marcador inesperado ({t.count(a)})')
    return t.replace(a, b, 1)

c = r(c, '$script:AppVersion = "0.21.44"', '$script:AppVersion = "0.21.45"', 'Central')
c = r(c, '$script:NFEntradaVersion = "2.6.13"', '$script:NFEntradaVersion = "2.6.14"', 'NF Central')
n = r(n, '$script:ModuleVersion = "2.6.13"', '$script:ModuleVersion = "2.6.14"', 'NF modulo')

n = r(n,
'''$script:CurrentPalette = $null
$script:ComputerProduct = "COMPUTADOR DE BORDO V5"''',
'''$script:CurrentPalette = $null
$script:NFComputerNavButton = $null
$script:NFKeyboardNavButton = $null
$script:NFMovementNavButton = $null
$script:NFHistoryNavButton = $null
$script:NFSecurityNavButton = $null
$script:NFSummaryNavButton = $null
$script:ComputerProduct = "COMPUTADOR DE BORDO V5"''',
'variaveis navegacao NF')

n = r(n,
'''$mainTabs = New-Object Windows.Forms.TabControl
$mainTabs.Dock = [Windows.Forms.DockStyle]::Fill
$mainTabs.Margin = if ($script:IsInProcessHosted) { [Windows.Forms.Padding]::new(0, 4, 0, 4) } else { [Windows.Forms.Padding]::new(3) }
$mainTabs.Font = [Drawing.Font]::new("Segoe UI Semibold", $(if ($script:IsInProcessHosted) { 8.6 } else { 9 }))
$root.Controls.Add($mainTabs, 0, 2)''',
'''$nfTabsShell = New-Object Windows.Forms.TableLayoutPanel
$nfTabsShell.Dock = [Windows.Forms.DockStyle]::Fill
$nfTabsShell.Margin = [Windows.Forms.Padding]::new(0, 4, 0, 4)
$nfTabsShell.Padding = [Windows.Forms.Padding]::new(0)
$nfTabsShell.RowCount = 2
$nfTabsShell.ColumnCount = 1
[void]$nfTabsShell.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, $(if ($script:IsInProcessHosted) { 43 } else { 46 }))))
[void]$nfTabsShell.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 100)))
$root.Controls.Add($nfTabsShell, 0, 2)

$nfSectionNav = New-Object Windows.Forms.TableLayoutPanel
$nfSectionNav.Dock = [Windows.Forms.DockStyle]::Fill
$nfSectionNav.Margin = [Windows.Forms.Padding]::new(0)
$nfSectionNav.Padding = [Windows.Forms.Padding]::new(5, 2, 5, 2)
$nfSectionNav.ColumnCount = 6
$nfSectionNav.RowCount = 1
for ($i = 0; $i -lt 6; $i++) { [void]$nfSectionNav.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 16.6667))) }
$nfTabsShell.Controls.Add($nfSectionNav, 0, 0)

function New-NFSectionNavButton([string]$Text) {
    $button = New-Object Windows.Forms.Button
    $button.Text = $Text
    $button.Dock = [Windows.Forms.DockStyle]::Fill
    $button.Margin = [Windows.Forms.Padding]::new(3, 2, 3, 2)
    $button.Padding = [Windows.Forms.Padding]::new(4, 0, 4, 0)
    $button.Font = [Drawing.Font]::new("Segoe UI Semibold", $(if ($script:IsInProcessHosted) { 8.0 } else { 8.4 }))
    $button.TextAlign = [Drawing.ContentAlignment]::MiddleCenter
    $button.AutoEllipsis = $true
    Set-NFButtonStyle $button "Secondary"
    return $button
}

$script:NFComputerNavButton = New-NFSectionNavButton "COMPUTADOR DE BORDO CB5 (0)"
$script:NFKeyboardNavButton = New-NFSectionNavButton "TECLADO V5 (0)"
$script:NFMovementNavButton = New-NFSectionNavButton "MOVIMENTAÇÕES"
$script:NFHistoryNavButton = New-NFSectionNavButton "HISTÓRICO"
$script:NFSecurityNavButton = New-NFSectionNavButton "SEGURANÇA"
$script:NFSummaryNavButton = New-NFSectionNavButton "RESUMO"
$nfSectionNav.Controls.Add($script:NFComputerNavButton, 0, 0)
$nfSectionNav.Controls.Add($script:NFKeyboardNavButton, 1, 0)
$nfSectionNav.Controls.Add($script:NFMovementNavButton, 2, 0)
$nfSectionNav.Controls.Add($script:NFHistoryNavButton, 3, 0)
$nfSectionNav.Controls.Add($script:NFSecurityNavButton, 4, 0)
$nfSectionNav.Controls.Add($script:NFSummaryNavButton, 5, 0)

$nfTabsViewport = New-Object Windows.Forms.Panel
$nfTabsViewport.Dock = [Windows.Forms.DockStyle]::Fill
$nfTabsViewport.Margin = [Windows.Forms.Padding]::new(0)
$nfTabsViewport.Padding = [Windows.Forms.Padding]::new(0)
$nfTabsViewport.BackColor = $script:CurrentPalette.Background
$nfTabsShell.Controls.Add($nfTabsViewport, 0, 1)

$mainTabs = New-Object Windows.Forms.TabControl
$mainTabs.Dock = [Windows.Forms.DockStyle]::None
$mainTabs.Margin = [Windows.Forms.Padding]::new(0)
$mainTabs.Font = [Drawing.Font]::new("Segoe UI Semibold", $(if ($script:IsInProcessHosted) { 8.6 } else { 9 }))
$nfTabsViewport.Controls.Add($mainTabs)

function Sync-NFTabViewport {
    if ($null -eq $nfTabsViewport -or $null -eq $mainTabs) { return }
    try {
        $clip = 27
        try {
            $displayY = [int]$mainTabs.DisplayRectangle.Y
            if ($displayY -gt 18 -and $displayY -lt 48) { $clip = $displayY }
        } catch {}
        $w = [Math]::Max(1, $nfTabsViewport.ClientSize.Width)
        $h = [Math]::Max(1, $nfTabsViewport.ClientSize.Height)
        $mainTabs.SetBounds(0, -$clip, $w, $h + $clip)
    } catch {}
}
$nfTabsViewport.Add_Resize({ Sync-NFTabViewport })''',
'navegacao visual NF')

n = r(n,
'''$mainTabs.SelectedTab = $computerTab''',
'''$mainTabs.SelectedTab = $computerTab

function Update-NFSectionNavigation {
    $items = @(
        @($script:NFComputerNavButton, $computerTab),
        @($script:NFKeyboardNavButton, $keyboardTab),
        @($script:NFMovementNavButton, $movementTab),
        @($script:NFHistoryNavButton, $historyTab),
        @($script:NFSecurityNavButton, $securityTab),
        @($script:NFSummaryNavButton, $summaryTab)
    )
    foreach ($item in $items) {
        $button = $item[0]
        $page = $item[1]
        if ($null -eq $button -or $null -eq $page) { continue }
        $kind = if ($mainTabs.SelectedTab -eq $page) { "Primary" } else { "Secondary" }
        Set-NFButtonStyle $button $kind
    }
}

$script:NFComputerNavButton.Add_Click({ $mainTabs.SelectedTab = $computerTab })
$script:NFKeyboardNavButton.Add_Click({ $mainTabs.SelectedTab = $keyboardTab })
$script:NFMovementNavButton.Add_Click({ $mainTabs.SelectedTab = $movementTab })
$script:NFHistoryNavButton.Add_Click({ $mainTabs.SelectedTab = $historyTab })
$script:NFSecurityNavButton.Add_Click({ $mainTabs.SelectedTab = $securityTab })
$script:NFSummaryNavButton.Add_Click({ $mainTabs.SelectedTab = $summaryTab })
Update-NFSectionNavigation
Sync-NFTabViewport''',
'eventos navegacao NF')

n = r(n,
'''    $computerTab.Text = "COMPUTADOR DE BORDO CB5 ($([int]$summary.Produtos[$script:ComputerProduct].Registros))"
    $keyboardTab.Text = "TECLADO V5 ($([int]$summary.Produtos[$script:KeyboardProduct].Registros))"''',
'''    $computerTab.Text = "COMPUTADOR DE BORDO CB5 ($([int]$summary.Produtos[$script:ComputerProduct].Registros))"
    $keyboardTab.Text = "TECLADO V5 ($([int]$summary.Produtos[$script:KeyboardProduct].Registros))"
    if ($null -ne $script:NFComputerNavButton) { $script:NFComputerNavButton.Text = $computerTab.Text }
    if ($null -ne $script:NFKeyboardNavButton) { $script:NFKeyboardNavButton.Text = $keyboardTab.Text }''',
'contadores navegacao NF')

n = r(n,
'''$mainTabs.Add_SelectedIndexChanged({ Update-NFActions; if ($mainTabs.SelectedTab -eq $movementTab) { Refresh-NFMovements }; if ($mainTabs.SelectedTab -eq $historyTab) { Refresh-NFHistory }; if ($mainTabs.SelectedTab -eq $securityTab) { Refresh-NFBackups } })''',
'''$mainTabs.Add_SelectedIndexChanged({ Update-NFSectionNavigation; Update-NFActions; if ($mainTabs.SelectedTab -eq $movementTab) { Refresh-NFMovements }; if ($mainTabs.SelectedTab -eq $historyTab) { Refresh-NFHistory }; if ($mainTabs.SelectedTab -eq $securityTab) { Refresh-NFBackups } })''',
'selecao navegacao NF')

n += '\n# NF_SECTION_NAV_MAINTENANCE_STYLE_V02614\n'

for marker in ('$script:AppVersion = "0.21.45"', '$script:NFEntradaVersion = "2.6.14"'):
    if marker not in c:
        raise SystemExit('marcador Central ausente: ' + marker)
for marker in ('$script:ModuleVersion = "2.6.14"', 'NF_SECTION_NAV_MAINTENANCE_STYLE_V02614', 'Update-NFSectionNavigation', 'Sync-NFTabViewport'):
    if marker not in n:
        raise SystemExit('marcador NF ausente: ' + marker)
for forbidden in ('$mainTabs.Add_SizeChanged', '$mainTabs.Add_HandleCreated', 'OwnerDrawFixed', '$mainTabs.ItemSize'):
    if forbidden in n:
        raise SystemExit('mecanismo proibido de abas no NF: ' + forbidden)

cp.write_text(c, encoding='utf-8')
np.write_text(n, encoding='utf-8')
print('NF SECTION NAV: OK - navegacao em botoes no estilo da Manutencao, mantendo TabControl nativo internamente.')
