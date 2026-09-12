from pathlib import Path
import re

central_path = Path('src/generated/Central de Trabalho.ps1')
maintenance_path = Path('src/generated/Modulos/Central-de-Manutencao-CB5/Central Manutencao CB5.ps1')
nf_path = Path('src/generated/Modulos/Controle-NF-Entrada/Controle NF Entrada.ps1')

central = central_path.read_text(encoding='utf-8-sig')
maintenance = maintenance_path.read_text(encoding='utf-8-sig')
nf = nf_path.read_text(encoding='utf-8-sig')


def one(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: esperado 1 marcador, encontrado {count}')
    return text.replace(old, new, 1)


# ---------------------------------------------------------------------------
# VERSÕES — publicação somente no canal Teste.
# ---------------------------------------------------------------------------
central = one(central, '$script:AppVersion = "0.21.46"', '$script:AppVersion = "0.21.47"', 'versao Central')
central = one(central, '$script:MaintenanceVersion = "0.6.10"', '$script:MaintenanceVersion = "0.6.11"', 'versao Manutencao na Central')
central = one(central, '$script:NFEntradaVersion = "2.6.15"', '$script:NFEntradaVersion = "2.6.16"', 'versao NF na Central')
maintenance = one(maintenance, '$script:AppVersion = "0.6.10"', '$script:AppVersion = "0.6.11"', 'versao Manutencao')
nf = one(nf, '$script:ModuleVersion = "2.6.15"', '$script:ModuleVersion = "2.6.16"', 'versao NF')


# ---------------------------------------------------------------------------
# CENTRAL DE MANUTENÇÃO — traz de volta o resumo persistente acima da navegação.
# O painel e os quatro cards nunca foram removidos; em alturas menores o layout
# podia zerar a linha deles. Agora sempre existe uma faixa útil para o resumo.
# ---------------------------------------------------------------------------
maintenance = one(
    maintenance,
    '''            $overviewHeight = 0
            if ($shellH -ge 650) {''',
    '''            # O resumo de séries/passagens/em andamento/retornos deve permanecer visível
            # também no modo integrado da Central.
            $overviewHeight = if ($shellH -lt 620) { 84 } elseif ($shellH -lt 760) { 94 } else { 104 }
            if ($shellH -ge 650) {''',
    'altura persistente do resumo da Manutencao'
)
maintenance = one(
    maintenance,
    'if ($null -ne $script:HostedOverviewPanel) { $script:HostedOverviewPanel.Visible = ($overviewHeight -gt 0) }',
    'if ($null -ne $script:HostedOverviewPanel) { $script:HostedOverviewPanel.Visible = $true }',
    'visibilidade persistente do resumo da Manutencao'
)


# ---------------------------------------------------------------------------
# CONTROLE DE NF — corrige os cards superiores.
# Título vai para o canto superior direito, complemento fica visível logo abaixo
# e o número permanece destacado à esquerda. Assim não sobra texto cortado.
# ---------------------------------------------------------------------------
new_summary_function = r'''function New-NFSummaryCard {
    param([string]$Title, [string]$Subtitle, [ref]$ValueLabel)

    $panel = New-Object Windows.Forms.Panel
    $panel.Dock = [Windows.Forms.DockStyle]::Fill
    $panel.Margin = if ($script:IsInProcessHosted) { [Windows.Forms.Padding]::new(4, 4, 4, 6) } else { [Windows.Forms.Padding]::new(6) }
    $panel.Padding = [Windows.Forms.Padding]::new(0)
    $panel.BackColor = $script:CurrentPalette.Card
    $panel.Tag = "Theme.Card"
    $panel.BorderStyle = if ($script:IsInProcessHosted) { [Windows.Forms.BorderStyle]::None } else { [Windows.Forms.BorderStyle]::FixedSingle }

    $layout = New-Object Windows.Forms.TableLayoutPanel
    $layout.Dock = [Windows.Forms.DockStyle]::Fill
    $layout.Margin = [Windows.Forms.Padding]::new(0)
    $layout.Padding = if ($script:IsInProcessHosted) { [Windows.Forms.Padding]::new(13, 9, 13, 8) } else { [Windows.Forms.Padding]::new(14, 10, 14, 9) }
    $layout.BackColor = $script:CurrentPalette.Card
    $layout.ColumnCount = 2
    $layout.RowCount = 2
    [void]$layout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 34)))
    [void]$layout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 66)))
    [void]$layout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 56)))
    [void]$layout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 44)))
    $panel.Controls.Add($layout)

    $value = New-Object Windows.Forms.Label
    $value.Text = "0"
    $value.Dock = [Windows.Forms.DockStyle]::Fill
    $value.Margin = [Windows.Forms.Padding]::new(0)
    $value.Font = [Drawing.Font]::new("Segoe UI Semibold", $(if ($script:IsInProcessHosted) { 19 } else { 21 }))
    $value.ForeColor = if ($script:IsInProcessHosted) { $script:CurrentPalette.Accent } else { $script:CurrentPalette.Text }
    $value.TextAlign = [Drawing.ContentAlignment]::MiddleLeft
    if ($script:IsInProcessHosted) { $value.Tag = "Theme.Accent" }
    $layout.Controls.Add($value, 0, 0)
    $layout.SetRowSpan($value, 2)

    $title = New-Object Windows.Forms.Label
    $title.Text = $Title
    $title.Dock = [Windows.Forms.DockStyle]::Fill
    $title.Margin = [Windows.Forms.Padding]::new(0)
    $title.Padding = [Windows.Forms.Padding]::new(0, 0, 1, 0)
    $title.Font = [Drawing.Font]::new("Segoe UI Semibold", $(if ($script:IsInProcessHosted) { 8.8 } else { 9.2 }))
    $title.ForeColor = $script:CurrentPalette.Text
    $title.TextAlign = [Drawing.ContentAlignment]::BottomRight
    $title.AutoEllipsis = $true
    $layout.Controls.Add($title, 1, 0)

    $hint = New-Object Windows.Forms.Label
    $hint.Text = $Subtitle
    $hint.Dock = [Windows.Forms.DockStyle]::Fill
    $hint.Margin = [Windows.Forms.Padding]::new(0)
    $hint.Padding = [Windows.Forms.Padding]::new(0, 1, 1, 0)
    $hint.Font = [Drawing.Font]::new("Segoe UI", $(if ($script:IsInProcessHosted) { 8.0 } else { 8.4 }))
    $hint.ForeColor = $script:CurrentPalette.Muted
    $hint.Tag = "Theme.Muted"
    $hint.TextAlign = [Drawing.ContentAlignment]::TopRight
    $hint.AutoEllipsis = $true
    $layout.Controls.Add($hint, 1, 1)

    $ValueLabel.Value = $value
    return $panel
}
'''

pattern = r'function New-NFSummaryCard \{.*?\n\}\n(?=\nfunction )'
nf, count = re.subn(pattern, new_summary_function, nf, count=1, flags=re.S)
if count != 1:
    raise SystemExit(f'funcao New-NFSummaryCard: esperado 1 marcador, encontrado {count}')

# Dá alguns pixels a mais aos cards no host para o complemento aparecer inteiro.
nf = one(
    nf,
    '$nfCardsHeight = if ($script:IsInProcessHosted) { 88 } else { 108 }',
    '$nfCardsHeight = if ($script:IsInProcessHosted) { 96 } else { 108 }',
    'altura dos cards NF'
)

# Marcadores desta correção para auditoria futura.
maintenance += '\n# POST_CURE_RESUMO_MANUTENCAO_V0611\n'
nf += '\n# POST_CURE_NF_SUMMARY_CARDS_V02616\n'
central += '\n# POST_CURE_UI_FIXES_V02147\n'

for marker in (
    '$script:AppVersion = "0.21.47"',
    '$script:MaintenanceVersion = "0.6.11"',
    '$script:NFEntradaVersion = "2.6.16"',
):
    if marker not in central:
        raise SystemExit('marcador ausente na Central: ' + marker)

for marker in (
    '$script:AppVersion = "0.6.11"',
    'POST_CURE_RESUMO_MANUTENCAO_V0611',
    '$script:HostedOverviewPanel.Visible = $true',
    '$overviewHeight = if ($shellH -lt 620)',
):
    if marker not in maintenance:
        raise SystemExit('marcador ausente na Manutencao: ' + marker)

for marker in (
    '$script:ModuleVersion = "2.6.16"',
    'POST_CURE_NF_SUMMARY_CARDS_V02616',
    '$title.TextAlign = [Drawing.ContentAlignment]::BottomRight',
    '$hint.TextAlign = [Drawing.ContentAlignment]::TopRight',
    '$nfCardsHeight = if ($script:IsInProcessHosted) { 96 } else { 108 }',
):
    if marker not in nf:
        raise SystemExit('marcador ausente no NF: ' + marker)

# Proteção permanente do caminho estável das abas do NF.
for forbidden in (
    '$mainTabs.Add_SizeChanged',
    '$mainTabs.Add_HandleCreated',
    '$mainTabs.DrawMode = [Windows.Forms.TabDrawMode]::OwnerDrawFixed',
    '$mainTabs.ItemSize',
):
    if forbidden in nf:
        raise SystemExit('mecanismo proibido de abas reapareceu no NF: ' + forbidden)

central_path.write_text(central, encoding='utf-8')
maintenance_path.write_text(maintenance, encoding='utf-8')
nf_path.write_text(nf, encoding='utf-8')
print('POST-CURE UI: OK - resumo da Manutencao restaurado e cards superiores do NF reorganizados sem texto cortado.')
