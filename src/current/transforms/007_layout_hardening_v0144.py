from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
CENTRAL = ROOT / "generated" / "Central de Trabalho.ps1"
MAINT = ROOT / "generated" / "Modulos" / "Central-de-Manutencao-CB5" / "Central Manutencao CB5.ps1"


def read(path):
    return path.read_text(encoding="utf-8-sig")


def write(path, text):
    path.write_text(text, encoding="utf-8-sig")


def replace_once(text, old, new, label):
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: esperado 1 trecho, encontrado {count}")
    return text.replace(old, new, 1)


def regex_once(text, pattern, replacement, label):
    new_text, count = re.subn(pattern, replacement, text, count=1, flags=re.S)
    if count != 1:
        raise RuntimeError(f"{label}: esperado 1 trecho, encontrado {count}")
    return new_text


central = read(CENTRAL)
maint = read(MAINT)

central = replace_once(central, '$script:AppVersion = "0.14.3"', '$script:AppVersion = "0.14.4"', 'versao Central')
central = replace_once(central, '$script:MaintenanceVersion = "0.5.9"', '$script:MaintenanceVersion = "0.6.0"', 'versao Manutencao na Central')
maint = replace_once(maint, '$script:AppVersion = "0.5.9"', '$script:AppVersion = "0.6.0"', 'versao Manutencao')

# O ComboBox owner-draw da aparência podia ficar visualmente vazio quando o Windows
# pedia a pintura da área selecionada com Index = -1. Usamos SelectedIndex como fallback.
central = regex_once(
    central,
    r'\$themeCombo\.Add_DrawItem\(\{.*?\n\}\)\n\$sidebarBottom\.Controls\.Add\(\$themeCombo\)',
    r'''$themeCombo.Add_DrawItem({
    param($sender, $e)
    try {
        $index = [int]$e.Index
        if ($index -lt 0) { $index = [int]$sender.SelectedIndex }
        $palette = $script:CurrentPalette
        $back = if ($null -ne $palette) { $palette.Input } else { [Drawing.Color]::FromArgb(18,24,27) }
        $fore = if ($null -ne $palette) { $palette.Text } else { [Drawing.Color]::White }
        if (($e.State -band [Windows.Forms.DrawItemState]::Selected) -ne 0) {
            $back = if ($null -ne $palette) { $palette.AccentStrong } else { [Drawing.Color]::FromArgb(27,151,134) }
            $fore = if ($null -ne $palette) { $palette.AccentText } else { [Drawing.Color]::White }
        }
        $brush = New-Object Drawing.SolidBrush($back)
        $textBrush = New-Object Drawing.SolidBrush($fore)
        try {
            $e.Graphics.FillRectangle($brush, $e.Bounds)
            if ($index -ge 0 -and $index -lt $sender.Items.Count) {
                $textRect = [Drawing.Rectangle]::new($e.Bounds.X + 7, $e.Bounds.Y, [Math]::Max(1, $e.Bounds.Width - 10), $e.Bounds.Height)
                $format = New-Object Drawing.StringFormat
                try {
                    $format.LineAlignment = [Drawing.StringAlignment]::Center
                    $format.Trimming = [Drawing.StringTrimming]::EllipsisCharacter
                    $format.FormatFlags = [Drawing.StringFormatFlags]::NoWrap
                    $e.Graphics.DrawString([string]$sender.Items[$index], $sender.Font, $textBrush, $textRect, $format)
                } finally { $format.Dispose() }
            }
        } finally {
            $brush.Dispose()
            $textBrush.Dispose()
        }
        if (($e.State -band [Windows.Forms.DrawItemState]::Focus) -ne 0) { $e.DrawFocusRectangle() }
    } catch {}
})
$sidebarBottom.Controls.Add($themeCombo)''',
    'correcao do seletor de aparencia vazio'
)

# Reestrutura a área hospedada da Manutenção: os cartões e a navegação passam a ocupar
# blocos próprios, sem reutilizar o cabeçalho da antiga Visão geral. Isso elimina o corte
# do título e do botão Nova passagem e libera mais altura para todas as telas internas.
maint = regex_once(
    maint,
    r'if \(\$script:IsInProcessHosted\) \{\n    # Cabeçalho persistente:.*?\n\}\n\nfunction Update-MaintenanceSectionNavigation',
    r'''if ($script:IsInProcessHosted) {
    # Resumo persistente: somente os quatro cartões. O título/subtítulo antigo da
    # Visão geral não é repetido dentro do módulo integrado.
    $script:HostedOverviewPanel = New-Object Windows.Forms.Panel
    $script:HostedOverviewPanel.Margin = [Windows.Forms.Padding]::new(0)
    $script:HostedOverviewPanel.Padding = [Windows.Forms.Padding]::new(8, 5, 8, 5)
    $tabsViewport.Controls.Add($script:HostedOverviewPanel)

    $script:HostedOverviewLayout = New-Object Windows.Forms.TableLayoutPanel
    $script:HostedOverviewLayout.Dock = [Windows.Forms.DockStyle]::Fill
    $script:HostedOverviewLayout.Margin = [Windows.Forms.Padding]::new(0)
    $script:HostedOverviewLayout.Padding = [Windows.Forms.Padding]::new(4, 0, 4, 0)
    $script:HostedOverviewLayout.ColumnCount = 1
    $script:HostedOverviewLayout.RowCount = 1
    [void]$script:HostedOverviewLayout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 100)))
    [void]$script:HostedOverviewLayout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 100)))
    $script:HostedOverviewPanel.Controls.Add($script:HostedOverviewLayout)

    try { $dashboardRoot.Controls.Remove($cardsLayout) } catch {}
    $cardsLayout.Dock = [Windows.Forms.DockStyle]::Fill
    $cardsLayout.Margin = [Windows.Forms.Padding]::new(0)
    $script:HostedOverviewLayout.Controls.Add($cardsLayout, 0, 0)

    # O cabeçalho antigo continha o título repetido e o botão laranja que estava
    # sendo cortado. No modo integrado ele deixa de participar do layout.
    try { $dashboardRoot.Controls.Remove($dashboardIntro) } catch {}
    $dashboardIntro.Visible = $false

    # Navegação persistente com seis ações: Nova passagem + cinco áreas de consulta.
    $script:HostedSectionNavPanel = New-Object Windows.Forms.Panel
    $script:HostedSectionNavPanel.Margin = [Windows.Forms.Padding]::new(0)
    $script:HostedSectionNavPanel.Padding = [Windows.Forms.Padding]::new(8, 2, 8, 2)
    $tabsViewport.Controls.Add($script:HostedSectionNavPanel)

    try { $dashboardRoot.Controls.Remove($dashboardNavigation) } catch {}
    $dashboardNavigation.Dock = [Windows.Forms.DockStyle]::Fill
    $dashboardNavigation.Margin = [Windows.Forms.Padding]::new(0)
    $dashboardNavigation.ColumnCount = 6
    try { $dashboardNavigation.ColumnStyles.Clear() } catch {}
    for ($i = 0; $i -lt 6; $i++) {
        [void]$dashboardNavigation.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 16.6667)))
    }
    try { $dashboardNavigation.SetColumn($dashboardHistoryButton, 1) } catch {}
    try { $dashboardNavigation.SetColumn($dashboardStatsButton, 2) } catch {}
    try { $dashboardNavigation.SetColumn($dashboardDiagnosisButton, 3) } catch {}
    try { $dashboardNavigation.SetColumn($dashboardSchematicsButton, 4) } catch {}
    try { $dashboardNavigation.SetColumn($dashboardRulesButton, 5) } catch {}

    try { if ($null -ne $dashboardNewButton.Parent) { $dashboardNewButton.Parent.Controls.Remove($dashboardNewButton) } } catch {}
    $dashboardNewButton.Text = "+ NOVA PASSAGEM"
    $dashboardNewButton.Dock = [Windows.Forms.DockStyle]::Fill
    $dashboardNewButton.Margin = [Windows.Forms.Padding]::new(3, 2, 3, 2)
    $dashboardNewButton.Font = [Drawing.Font]::new("Segoe UI Semibold", 8.0)
    $dashboardNavigation.Controls.Add($dashboardNewButton, 0, 0)
    $script:HostedSectionNavPanel.Controls.Add($dashboardNavigation)

    if ($null -ne $script:InternalNavPanel) { $script:InternalNavPanel.Visible = $false }
    $script:HostedOverviewPanel.BringToFront()
    $script:HostedSectionNavPanel.BringToFront()
    Update-MaintenanceHostedViewport
}

function Update-MaintenanceSectionNavigation''',
    'reconstrucao do cabecalho persistente da Manutencao'
)

# Substitui a matemática do viewport hospedado. A página interna sempre começa depois
# dos cartões e da faixa de navegação; em Passagem os cartões recolhem, mas a faixa fica.
maint = regex_once(
    maint,
    r'    function Update-MaintenanceHostedViewport \{.*?\n    \}\n\n    \$tabsViewport\.Add_SizeChanged',
    r'''    function Update-MaintenanceHostedViewport {
        if (-not $script:IsInProcessHosted) { return }
        try {
            $hiddenTabStrip = 31
            $viewportW = [Math]::Max(1, $tabsViewport.ClientSize.Width)
            $viewportH = [Math]::Max(1, $tabsViewport.ClientSize.Height)

            $isPassage = $false
            $passageVar = Get-Variable -Name passageTab -ErrorAction SilentlyContinue
            if ($null -ne $passageVar -and $null -ne $passageVar.Value -and $mainTabs.SelectedTab -eq $passageVar.Value) {
                $isPassage = $true
            }

            $overviewHeight = 0
            if ($null -ne $script:HostedOverviewPanel) {
                # Em alturas muito baixas escondemos os cartões automaticamente para
                # nunca sacrificar os campos/botões da tela ativa.
                if (-not $isPassage -and $viewportH -ge 520) {
                    $overviewHeight = if ($viewportH -lt 650) { 94 } elseif ($viewportH -lt 820) { 104 } else { 112 }
                    $script:HostedOverviewPanel.Visible = $true
                    $script:HostedOverviewPanel.Location = [Drawing.Point]::new(0, 0)
                    $script:HostedOverviewPanel.Size = [Drawing.Size]::new($viewportW, $overviewHeight)
                }
                else {
                    $script:HostedOverviewPanel.Visible = $false
                }
            }

            $navHeight = if ($viewportH -lt 600) { 38 } else { 42 }
            if ($null -ne $script:HostedSectionNavPanel) {
                $script:HostedSectionNavPanel.Visible = $true
                $script:HostedSectionNavPanel.Location = [Drawing.Point]::new(0, $overviewHeight)
                $script:HostedSectionNavPanel.Size = [Drawing.Size]::new($viewportW, $navHeight)

                # Em larguras menores os textos ficam compactos para as seis ações
                # continuarem numa única linha sem corte.
                $compactNav = ($viewportW -lt 980)
                $dashboardNewButton.Text = if ($compactNav) { "+ PASSAGEM" } else { "+ NOVA PASSAGEM" }
                $navFont = if ($compactNav) { 7.2 } else { 8.0 }
                foreach ($button in @($dashboardNewButton, $dashboardHistoryButton, $dashboardStatsButton, $dashboardDiagnosisButton, $dashboardSchematicsButton, $dashboardRulesButton)) {
                    if ($null -ne $button) {
                        $button.Font = [Drawing.Font]::new("Segoe UI Semibold", $navFont)
                        $button.Margin = [Windows.Forms.Padding]::new(2, 2, 2, 2)
                    }
                }
            }

            $contentTop = $overviewHeight + $navHeight
            $mainTabs.Location = [Drawing.Point]::new(0, $contentTop - $hiddenTabStrip)
            $mainTabs.Size = [Drawing.Size]::new(
                $viewportW,
                [Math]::Max(1, $viewportH - $contentTop + $hiddenTabStrip)
            )

            if ($null -ne $script:HostedOverviewPanel -and $script:HostedOverviewPanel.Visible) { $script:HostedOverviewPanel.BringToFront() }
            if ($null -ne $script:HostedSectionNavPanel) { $script:HostedSectionNavPanel.BringToFront() }
        } catch {}
    }

    $tabsViewport.Add_SizeChanged''',
    'matematica do viewport hospedado'
)

# Garante que a troca de seção recalcula o espaço imediatamente, inclusive quando
# entra ou sai de Nova passagem.
maint = replace_once(
    maint,
    '        Update-MaintenanceSectionNavigation\n    } catch {}\n}',
    '        Update-MaintenanceSectionNavigation\n        Update-MaintenanceHostedViewport\n    } catch {}\n}',
    'recalculo na navegacao interna'
)

# Pequena compactação global dos botões de ação do Histórico para evitar corte em DPI alto.
maint = maint.replace(
    '$historyActions.Padding = [Windows.Forms.Padding]::new(0)',
    '$historyActions.Padding = [Windows.Forms.Padding]::new(0, 1, 0, 1)'
)

write(CENTRAL, central)
write(MAINT, maint)
print('Transformação v0.14.4 aplicada com sucesso.')
