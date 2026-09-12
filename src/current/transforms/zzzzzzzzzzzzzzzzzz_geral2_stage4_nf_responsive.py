from pathlib import Path

cp = Path('src/generated/Central de Trabalho.ps1')
np = Path('src/generated/Modulos/Controle-NF-Entrada/Controle NF Entrada.ps1')
c = cp.read_text(encoding='utf-8-sig')
n = np.read_text(encoding='utf-8-sig')


def one(text, old, new, label):
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'GERAL2/E4 {label}: esperado 1, encontrado {count}')
    return text.replace(old, new, 1)


# ---------------------------------------------------------------------------
# Versões — somente Teste.
# ---------------------------------------------------------------------------
c = one(c, '$script:AppVersion = "0.21.51"', '$script:AppVersion = "0.21.52"', 'versao Central')
c = one(c, '$script:NFEntradaVersion = "2.6.17"', '$script:NFEntradaVersion = "2.6.18"', 'versao NF Central')
n = one(n, '$script:ModuleVersion = "2.6.17"', '$script:ModuleVersion = "2.6.18"', 'versao NF modulo')

# A janela independente passa a caber melhor em notebook. O conteúdo agora
# recalcula densidade e quebra de layout em vez de depender de um mínimo grande.
n = one(
    n,
    '$form.MinimumSize = [Drawing.Size]::new(980, 680)',
    '$form.MinimumSize = [Drawing.Size]::new(860, 600)',
    'minimum standalone'
)

responsive_block = r'''
# GERAL 2 / ETAPA 4 — motor responsivo do Controle de NF.
# Importante: o TabControl nativo permanece intocado. A adaptação acontece na
# casca, na navegação visual e no conteúdo de cada página.
$script:NFResponsiveBusy = $false
$script:NFResponsiveProfile = ""
$script:NFTopSummaryCards = @()

function Get-NFLogicalViewport {
    $dpi = 96
    try { if ($form.DeviceDpi -gt 0) { $dpi = [int]$form.DeviceDpi } } catch {}
    $w = [Math]::Max(1, [int]$form.ClientSize.Width)
    $h = [Math]::Max(1, [int]$form.ClientSize.Height)
    $logicalW = if ($script:IsInProcessHosted) { $w } else { [int][Math]::Round($w * 96.0 / $dpi) }
    $logicalH = if ($script:IsInProcessHosted) { $h } else { [int][Math]::Round($h * 96.0 / $dpi) }
    return [pscustomobject]@{ Width=$w; Height=$h; LogicalWidth=$logicalW; LogicalHeight=$logicalH; Dpi=$dpi }
}

function Set-NFTopSummaryLayout {
    param([int]$Columns)
    if ($script:NFTopSummaryCards.Count -ne 4) {
        $cache = @()
        for ($i = 0; $i -lt 4; $i++) {
            try {
                $control = $cards.GetControlFromPosition($i, 0)
                if ($null -ne $control) { $cache += $control }
            } catch {}
        }
        if ($cache.Count -eq 4) { $script:NFTopSummaryCards = $cache }
    }
    if ($script:NFTopSummaryCards.Count -ne 4) { return }

    try {
        $cards.SuspendLayout()
        $cards.ColumnStyles.Clear()
        $cards.RowStyles.Clear()
        $cards.ColumnCount = $Columns
        $rows = [int][Math]::Ceiling(4.0 / $Columns)
        $cards.RowCount = $rows
        for ($i = 0; $i -lt $Columns; $i++) {
            [void]$cards.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, (100.0 / $Columns))))
        }
        for ($i = 0; $i -lt $rows; $i++) {
            [void]$cards.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, (100.0 / $rows))))
        }
        for ($i = 0; $i -lt 4; $i++) {
            $col = $i % $Columns
            $row = [int][Math]::Floor($i / $Columns)
            $cards.SetCellPosition($script:NFTopSummaryCards[$i], [Windows.Forms.TableLayoutPanelCellPosition]::new($col, $row))
        }
    }
    finally { try { $cards.ResumeLayout($true) } catch {} }
}

function Set-NFVisualNavigationLayout {
    param([bool]$TwoRows, [string]$Profile)
    $buttons = @(
        $script:NFComputerNavButton,
        $script:NFKeyboardNavButton,
        $script:NFMovementNavButton,
        $script:NFHistoryNavButton,
        $script:NFSecurityNavButton,
        $script:NFSummaryNavButton
    )
    try {
        $nfSectionNav.SuspendLayout()
        $nfSectionNav.ColumnStyles.Clear()
        $nfSectionNav.RowStyles.Clear()
        if ($TwoRows) {
            $nfSectionNav.ColumnCount = 3
            $nfSectionNav.RowCount = 2
            for ($i=0; $i -lt 3; $i++) { [void]$nfSectionNav.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 33.3333))) }
            for ($i=0; $i -lt 2; $i++) { [void]$nfSectionNav.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 50))) }
            for ($i=0; $i -lt 6; $i++) {
                $nfSectionNav.SetCellPosition($buttons[$i], [Windows.Forms.TableLayoutPanelCellPosition]::new(($i % 3), [int][Math]::Floor($i / 3)))
            }
            $nfTabsShell.RowStyles[0].Height = 76
        }
        else {
            $nfSectionNav.ColumnCount = 6
            $nfSectionNav.RowCount = 1
            for ($i=0; $i -lt 6; $i++) { [void]$nfSectionNav.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 16.6667))) }
            [void]$nfSectionNav.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 100)))
            for ($i=0; $i -lt 6; $i++) {
                $nfSectionNav.SetCellPosition($buttons[$i], [Windows.Forms.TableLayoutPanelCellPosition]::new($i, 0))
            }
            $nfTabsShell.RowStyles[0].Height = if ($Profile -eq "Comfortable") { 46 } else { 43 }
        }
        $nfSectionNav.Padding = if ($Profile -eq "Tight") { [Windows.Forms.Padding]::new(3,2,3,2) } else { [Windows.Forms.Padding]::new(5,2,5,2) }
        foreach ($button in $buttons) {
            if ($null -eq $button) { continue }
            $button.Margin = if ($Profile -eq "Tight") { [Windows.Forms.Padding]::new(2) } else { [Windows.Forms.Padding]::new(3,2,3,2) }
            $button.Font = [Drawing.Font]::new("Segoe UI Semibold", $(if ($Profile -eq "Tight") { 7.5 } elseif ($Profile -eq "Compact") { 8.0 } else { 8.4 }))
        }
    }
    finally { try { $nfSectionNav.ResumeLayout($true) } catch {} }
}

function Set-NFProductPageResponsive {
    param([Windows.Forms.TabPage]$Tab, [string]$Profile)
    if ($null -eq $Tab) { return }
    $layout = @($Tab.Controls | Where-Object { $_ -is [Windows.Forms.TableLayoutPanel] } | Select-Object -First 1)
    if ($layout.Count -eq 0) { return }
    $page = $layout[0]
    try {
        $page.Padding = [Windows.Forms.Padding]::new($(if ($Profile -eq "Tight") { 5 } elseif ($Profile -eq "Compact") { 7 } else { 10 }))
        if ($page.RowStyles.Count -gt 0) { $page.RowStyles[0].Height = if ($Profile -eq "Tight") { 44 } elseif ($Profile -eq "Compact") { 47 } else { 50 } }
        $filterPanel = $page.GetControlFromPosition(0,0)
        if ($filterPanel -is [Windows.Forms.TableLayoutPanel] -and $filterPanel.ColumnStyles.Count -ge 7) {
            $widths = if ($Profile -eq "Tight") { @(52,0,44,106,36,82,70) } elseif ($Profile -eq "Compact") { @(60,0,50,116,40,90,80) } else { @(72,0,58,128,48,100,96) }
            for ($i=0; $i -lt 7; $i++) {
                if ($i -eq 1) {
                    $filterPanel.ColumnStyles[$i].SizeType = [Windows.Forms.SizeType]::Percent
                    $filterPanel.ColumnStyles[$i].Width = 100
                }
                else {
                    $filterPanel.ColumnStyles[$i].SizeType = [Windows.Forms.SizeType]::Absolute
                    $filterPanel.ColumnStyles[$i].Width = $widths[$i]
                }
            }
        }
    } catch {}
}

function Set-NFActivityResponsive {
    param([bool]$TwoRows)
    $a1 = try { $movementTodayValue.Parent.Parent } catch { $null }
    $a2 = try { $piecesTodayValue.Parent.Parent } catch { $null }
    $a3 = try { $piecesSevenValue.Parent.Parent } catch { $null }
    if ($null -eq $a1 -or $null -eq $a2 -or $null -eq $a3) { return }
    $items = @($a1,$a2,$a3,$lastPanel,$summaryActionPanel)
    try {
        $activityLayout.SuspendLayout()
        $activityLayout.ColumnStyles.Clear()
        $activityLayout.RowStyles.Clear()
        if ($TwoRows) {
            $activityLayout.ColumnCount = 3
            $activityLayout.RowCount = 2
            for ($i=0; $i -lt 3; $i++) { [void]$activityLayout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 33.3333))) }
            for ($i=0; $i -lt 2; $i++) { [void]$activityLayout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 50))) }
            $activityLayout.SetCellPosition($a1, [Windows.Forms.TableLayoutPanelCellPosition]::new(0,0))
            $activityLayout.SetCellPosition($a2, [Windows.Forms.TableLayoutPanelCellPosition]::new(1,0))
            $activityLayout.SetCellPosition($a3, [Windows.Forms.TableLayoutPanelCellPosition]::new(2,0))
            $activityLayout.SetCellPosition($lastPanel, [Windows.Forms.TableLayoutPanelCellPosition]::new(0,1))
            $activityLayout.SetColumnSpan($lastPanel, 2)
            $activityLayout.SetCellPosition($summaryActionPanel, [Windows.Forms.TableLayoutPanelCellPosition]::new(2,1))
        }
        else {
            $activityLayout.ColumnCount = 5
            $activityLayout.RowCount = 1
            foreach ($percent in @(17,17,17,32,17)) { [void]$activityLayout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, $percent))) }
            [void]$activityLayout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 100)))
            $activityLayout.SetColumnSpan($lastPanel, 1)
            for ($i=0; $i -lt 5; $i++) { $activityLayout.SetCellPosition($items[$i], [Windows.Forms.TableLayoutPanelCellPosition]::new($i,0)) }
        }
    }
    finally { try { $activityLayout.ResumeLayout($true) } catch {} }
}

function Update-NFResponsiveLayout {
    if ($script:NFResponsiveBusy -or $null -eq $form) { return }
    $script:NFResponsiveBusy = $true
    try {
        $m = Get-NFLogicalViewport
        $profile = if ($m.LogicalWidth -lt 930 -or $m.LogicalHeight -lt 620) { "Tight" } elseif ($m.LogicalWidth -lt 1220 -or $m.LogicalHeight -lt 760) { "Compact" } else { "Comfortable" }
        $script:NFResponsiveProfile = $profile

        $pad = if ($profile -eq "Tight") { 5 } elseif ($profile -eq "Compact") { 7 } else { $(if ($script:IsInProcessHosted) { 8 } else { 14 }) }
        $root.Padding = [Windows.Forms.Padding]::new($pad)

        # Cabeçalho usa menos área quando a janela diminui, mas mantém as duas ações visíveis.
        $root.RowStyles[0].Height = if ($profile -eq "Tight") { 60 } elseif ($profile -eq "Compact") { 66 } else { $(if ($script:IsInProcessHosted) { 68 } else { 92 }) }
        $actionW = if ($profile -eq "Tight") { 112 } elseif ($profile -eq "Compact") { 132 } else { $(if ($script:IsInProcessHosted) { 150 } else { 175 }) }
        $header.ColumnStyles[1].Width = $actionW
        $header.ColumnStyles[2].Width = $actionW
        $heading.RowStyles[0].Height = if ($profile -eq "Tight") { 34 } elseif ($profile -eq "Compact") { 38 } else { $(if ($script:IsInProcessHosted) { 39 } else { 54 }) }
        $title.Font = [Drawing.Font]::new("Segoe UI Semibold", $(if ($profile -eq "Tight") { 13.0 } elseif ($profile -eq "Compact") { 14.5 } else { $(if ($script:IsInProcessHosted) { 15.5 } else { 20 }) }))
        $subtitle.Font = [Drawing.Font]::new("Segoe UI", $(if ($profile -eq "Tight") { 7.4 } elseif ($profile -eq "Compact") { 7.9 } else { 8.2 }))
        $importButton.Margin = [Windows.Forms.Padding]::new(6, $(if ($profile -eq "Tight") { 8 } else { 10 }), 0, $(if ($profile -eq "Tight") { 7 } else { 9 }))
        $exportButton.Margin = $importButton.Margin

        # Resumo superior vira 2x2 somente quando a largura real pede isso.
        $summaryColumns = if ($m.LogicalWidth -lt 980) { 2 } else { 4 }
        Set-NFTopSummaryLayout -Columns $summaryColumns
        $root.RowStyles[1].Height = if ($summaryColumns -eq 2) { $(if ($profile -eq "Tight") { 154 } else { 166 }) } else { $(if ($profile -eq "Comfortable") { 104 } else { 96 }) }

        # Navegação visual pode quebrar em 2 linhas; o TabControl interno continua nativo.
        Set-NFVisualNavigationLayout -TwoRows:($m.LogicalWidth -lt 780) -Profile $profile
        Sync-NFTabViewport

        # Produtos: filtros cedem largura primeiro; a busca e a grade ficam com o restante.
        Set-NFProductPageResponsive -Tab $computerTab -Profile $profile
        Set-NFProductPageResponsive -Tab $keyboardTab -Profile $profile

        # Movimentações e Histórico: barras superiores acompanham o espaço real.
        $technicalPad = if ($profile -eq "Tight") { 5 } elseif ($profile -eq "Compact") { 7 } else { 10 }
        $movementLayout.Padding = [Windows.Forms.Padding]::new($technicalPad)
        $historyLayout.Padding = [Windows.Forms.Padding]::new($technicalPad)
        $securityLayout.Padding = [Windows.Forms.Padding]::new($technicalPad)
        $movementLayout.RowStyles[0].Height = if ($profile -eq "Tight") { 44 } elseif ($profile -eq "Compact") { 48 } else { 52 }
        $historyLayout.RowStyles[0].Height = if ($profile -eq "Tight") { 44 } elseif ($profile -eq "Compact") { 48 } else { 52 }
        $securityLayout.RowStyles[0].Height = if ($profile -eq "Tight") { 54 } elseif ($profile -eq "Compact") { 62 } else { 72 }
        $movementLayout.RowStyles[2].Height = if ($profile -eq "Tight") { 38 } else { 42 }
        $historyLayout.RowStyles[2].Height = if ($profile -eq "Tight") { 38 } else { 42 }
        $securityLayout.RowStyles[2].Height = if ($profile -eq "Tight") { 42 } else { 46 }

        $mw = if ($profile -eq "Tight") { @(54,0,48,142,46,122) } elseif ($profile -eq "Compact") { @(62,0,54,164,50,142) } else { @(74,0,62,190,58,165) }
        for ($i=0; $i -lt 6; $i++) {
            if ($i -eq 1) { $movementFilters.ColumnStyles[$i].SizeType=[Windows.Forms.SizeType]::Percent; $movementFilters.ColumnStyles[$i].Width=100 }
            else { $movementFilters.ColumnStyles[$i].SizeType=[Windows.Forms.SizeType]::Absolute; $movementFilters.ColumnStyles[$i].Width=$mw[$i] }
        }
        $hw = if ($profile -eq "Tight") { @(54,0,42,108,48,122,76) } elseif ($profile -eq "Compact") { @(62,0,46,126,54,140,94) } else { @(74,0,52,142,62,155,120) }
        for ($i=0; $i -lt 7; $i++) {
            if ($i -eq 1) { $historyFilters.ColumnStyles[$i].SizeType=[Windows.Forms.SizeType]::Percent; $historyFilters.ColumnStyles[$i].Width=100 }
            else { $historyFilters.ColumnStyles[$i].SizeType=[Windows.Forms.SizeType]::Absolute; $historyFilters.ColumnStyles[$i].Width=$hw[$i] }
        }

        # Resumo interno: em altura/largura menor, a atividade vira 3+2 em vez de cortar textos.
        $summaryLayout.Padding = [Windows.Forms.Padding]::new($(if ($profile -eq "Tight") { 5 } elseif ($profile -eq "Compact") { 7 } else { 8 }))
        if ($profile -eq "Tight") {
            $summaryLayout.RowStyles[0].Height = 30; $summaryLayout.RowStyles[1].Height = 32; $summaryLayout.RowStyles[2].Height = 38
        } elseif ($profile -eq "Compact") {
            $summaryLayout.RowStyles[0].Height = 32; $summaryLayout.RowStyles[1].Height = 35; $summaryLayout.RowStyles[2].Height = 33
        } else {
            $summaryLayout.RowStyles[0].Height = 34; $summaryLayout.RowStyles[1].Height = 38; $summaryLayout.RowStyles[2].Height = 28
        }
        Set-NFActivityResponsive -TwoRows:($profile -eq "Tight")
        $summaryActionPanel.Padding = if ($profile -eq "Tight") { [Windows.Forms.Padding]::new(3,6,3,3) } else { [Windows.Forms.Padding]::new(4,10,4,4) }
        $lastLayout.Padding = if ($profile -eq "Tight") { [Windows.Forms.Padding]::new(8,4,8,4) } else { [Windows.Forms.Padding]::new(12,8,12,8) }

        # Densidade das grades acompanha o perfil em TODAS as páginas.
        $headerH = if ($profile -eq "Tight") { 23 } elseif ($profile -eq "Compact") { 25 } else { 28 }
        $rowH = if ($profile -eq "Tight") { 20 } elseif ($profile -eq "Compact") { 22 } else { 25 }
        $gridFont = if ($profile -eq "Tight") { 7.5 } elseif ($profile -eq "Compact") { 8.1 } else { 8.8 }
        foreach ($grid in @($computerGrid,$keyboardGrid,$movementGrid,$historyGrid,$backupGrid)) {
            if ($null -eq $grid) { continue }
            try {
                $grid.ColumnHeadersHeight = $headerH
                $grid.RowTemplate.Height = $rowH
                $grid.DefaultCellStyle.Font = [Drawing.Font]::new("Segoe UI", $gridFont)
                $grid.ColumnHeadersDefaultCellStyle.Font = [Drawing.Font]::new("Segoe UI Semibold", $gridFont)
            } catch {}
        }
        foreach ($grid in @($productSummaryGrid,$codeSummaryGrid)) {
            if ($null -eq $grid) { continue }
            try {
                $grid.ColumnHeadersHeight = if ($profile -eq "Tight") { 22 } elseif ($profile -eq "Compact") { 24 } else { 26 }
                $grid.RowTemplate.Height = if ($profile -eq "Tight") { 19 } elseif ($profile -eq "Compact") { 20 } else { 21 }
            } catch {}
        }

        # Barra inferior: quebra somente quando realmente não cabe.
        $wrapActions = ($m.LogicalWidth -lt 760)
        $actionPanel.WrapContents = $wrapActions
        $root.RowStyles[3].Height = if ($wrapActions) { 78 } elseif ($profile -eq "Tight") { 48 } else { $(if ($script:IsInProcessHosted) { 52 } else { 58 }) }
        $footerHost.Padding = if ($profile -eq "Tight") { [Windows.Forms.Padding]::new(5,4,5,4) } else { [Windows.Forms.Padding]::new(8,6,8,6) }

        $securityInfo.Font = [Drawing.Font]::new("Segoe UI", $(if ($profile -eq "Tight") { 7.5 } elseif ($profile -eq "Compact") { 8.2 } else { 9.0 }))
        $backupButtons.WrapContents = ($m.LogicalWidth -lt 760)

        $form.PerformLayout()
        Sync-NFTabViewport
    }
    catch {}
    finally { $script:NFResponsiveBusy = $false }
}
'''

# Injeta o motor depois de toda a interface existir e antes da tematização final.
anchor = 'function Apply-NFEntradaThemeControl {'
if anchor not in n:
    raise SystemExit('GERAL2/E4 ancora responsiva ausente')
n = n.replace(anchor, responsive_block + '\n' + anchor, 1)

# O próprio controle/form dispara a rotina. Nenhum evento é adicionado ao TabControl.
old_tail = '''function Invoke-NFThemeBoundaryMarker { return }

if ($script:IsInProcessHosted) {'''
new_tail = '''function Invoke-NFThemeBoundaryMarker { return }

$form.Add_SizeChanged({ Update-NFResponsiveLayout })
try { $form.Add_DpiChanged({ Update-NFResponsiveLayout }) } catch {}
Update-NFResponsiveLayout

if ($script:IsInProcessHosted) {'''
n = one(n, old_tail, new_tail, 'eventos responsivos')

c += '\n# GERAL2_ETAPA4_NF_V02152\n'
n += '\n# GERAL2_ETAPA4_NF_RESPONSIVE_V02618\n'

for marker in ('$script:AppVersion = "0.21.52"', '$script:NFEntradaVersion = "2.6.18"', 'GERAL2_ETAPA4_NF_V02152'):
    if marker not in c:
        raise SystemExit('GERAL2/E4 Central marcador ausente: ' + marker)
for marker in ('$script:ModuleVersion = "2.6.18"', '$form.MinimumSize = [Drawing.Size]::new(860, 600)', 'Update-NFResponsiveLayout', 'Set-NFActivityResponsive', 'GERAL2_ETAPA4_NF_RESPONSIVE_V02618'):
    if marker not in n:
        raise SystemExit('GERAL2/E4 NF marcador ausente: ' + marker)

# Proteção permanente das abas nativas do NF.
for forbidden in (
    '$mainTabs.Add_SizeChanged',
    '$mainTabs.Add_HandleCreated',
    '$mainTabs.DrawMode = [Windows.Forms.TabDrawMode]::OwnerDrawFixed',
    '$mainTabs.ItemSize',
    'Update-NFMainTabStripLayout',
):
    if forbidden in n:
        raise SystemExit('GERAL2/E4 mecanismo proibido de abas reapareceu: ' + forbidden)

cp.write_text(c, encoding='utf-8')
np.write_text(n, encoding='utf-8')
print('GERAL 2 ETAPA 4: OK - NF v2.6.18 responsivo em produtos, movimentacoes, historico, seguranca e resumo; abas nativas preservadas.')
