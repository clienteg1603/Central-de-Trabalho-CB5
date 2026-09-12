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
central = one(central, '$script:AppVersion = "0.21.46"', '$script:AppVersion = "0.21.48"', 'versao Central')
central = one(central, '$script:MaintenanceVersion = "0.6.10"', '$script:MaintenanceVersion = "0.6.11"', 'versao Manutencao na Central')
central = one(central, '$script:NFEntradaVersion = "2.6.15"', '$script:NFEntradaVersion = "2.6.17"', 'versao NF na Central')
maintenance = one(maintenance, '$script:AppVersion = "0.6.10"', '$script:AppVersion = "0.6.11"', 'versao Manutencao')
nf = one(nf, '$script:ModuleVersion = "2.6.15"', '$script:ModuleVersion = "2.6.17"', 'versao NF')


# ---------------------------------------------------------------------------
# CENTRAL DE MANUTENÇÃO — traz de volta o resumo persistente acima da navegação.
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
# CONTROLE DE NF — cards superiores e cards compactos da atividade operacional.
# ---------------------------------------------------------------------------
new_summary_function = r'''function New-NFSummaryCard {
    param([string]$Title, [string]$Subtitle, [ref]$ValueLabel)

    $isActivityCard = @("MOVIMENTAÇÕES HOJE", "PEÇAS SAÍRAM HOJE", "PEÇAS EM 7 DIAS") -contains $Title

    $panel = New-Object Windows.Forms.Panel
    $panel.Dock = [Windows.Forms.DockStyle]::Fill
    $panel.Margin = if ($isActivityCard -and $script:IsInProcessHosted) { [Windows.Forms.Padding]::new(3) } elseif ($script:IsInProcessHosted) { [Windows.Forms.Padding]::new(4, 4, 4, 6) } else { [Windows.Forms.Padding]::new(6) }
    $panel.Padding = [Windows.Forms.Padding]::new(0)
    $panel.BackColor = $script:CurrentPalette.Card
    $panel.Tag = "Theme.Card"
    $panel.BorderStyle = if ($script:IsInProcessHosted) { [Windows.Forms.BorderStyle]::None } else { [Windows.Forms.BorderStyle]::FixedSingle }

    $layout = New-Object Windows.Forms.TableLayoutPanel
    $layout.Dock = [Windows.Forms.DockStyle]::Fill
    $layout.Margin = [Windows.Forms.Padding]::new(0)
    $layout.Padding = if ($isActivityCard -and $script:IsInProcessHosted) { [Windows.Forms.Padding]::new(6, 4, 6, 4) } elseif ($script:IsInProcessHosted) { [Windows.Forms.Padding]::new(13, 9, 13, 8) } else { [Windows.Forms.Padding]::new(14, 10, 14, 9) }
    $layout.BackColor = $script:CurrentPalette.Card
    $layout.ColumnCount = 2
    $layout.RowCount = 2
    [void]$layout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, $(if ($isActivityCard) { 32 } else { 34 }))))
    [void]$layout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, $(if ($isActivityCard) { 68 } else { 66 }))))
    [void]$layout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 56)))
    [void]$layout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 44)))
    $panel.Controls.Add($layout)

    $value = New-Object Windows.Forms.Label
    $value.Text = "0"
    $value.Dock = [Windows.Forms.DockStyle]::Fill
    $value.Margin = [Windows.Forms.Padding]::new(0)
    $value.Font = [Drawing.Font]::new("Segoe UI Semibold", $(if ($isActivityCard -and $script:IsInProcessHosted) { 15.5 } elseif ($script:IsInProcessHosted) { 19 } else { 21 }))
    $value.ForeColor = if ($script:IsInProcessHosted) { $script:CurrentPalette.Accent } else { $script:CurrentPalette.Text }
    $value.TextAlign = [Drawing.ContentAlignment]::MiddleLeft
    if ($script:IsInProcessHosted) { $value.Tag = "Theme.Accent" }
    $layout.Controls.Add($value, 0, 0)
    $layout.SetRowSpan($value, 2)

    $titleLabel = New-Object Windows.Forms.Label
    $titleLabel.Text = $Title
    $titleLabel.Dock = [Windows.Forms.DockStyle]::Fill
    $titleLabel.Margin = [Windows.Forms.Padding]::new(0)
    $titleLabel.Padding = [Windows.Forms.Padding]::new(0, 0, 1, 0)
    $titleLabel.Font = [Drawing.Font]::new("Segoe UI Semibold", $(if ($isActivityCard -and $script:IsInProcessHosted) { 7.7 } elseif ($script:IsInProcessHosted) { 8.8 } else { 9.2 }))
    $titleLabel.ForeColor = $script:CurrentPalette.Text
    $titleLabel.TextAlign = [Drawing.ContentAlignment]::BottomRight
    $titleLabel.AutoEllipsis = $true
    $layout.Controls.Add($titleLabel, 1, 0)

    $hintLabel = New-Object Windows.Forms.Label
    $hintLabel.Text = $Subtitle
    $hintLabel.Dock = [Windows.Forms.DockStyle]::Fill
    $hintLabel.Margin = [Windows.Forms.Padding]::new(0)
    $hintLabel.Padding = [Windows.Forms.Padding]::new(0, 1, 1, 0)
    $hintLabel.Font = [Drawing.Font]::new("Segoe UI", $(if ($isActivityCard -and $script:IsInProcessHosted) { 7.0 } elseif ($script:IsInProcessHosted) { 8.0 } else { 8.4 }))
    $hintLabel.ForeColor = $script:CurrentPalette.Muted
    $hintLabel.Tag = "Theme.Muted"
    $hintLabel.TextAlign = [Drawing.ContentAlignment]::TopRight
    $hintLabel.AutoEllipsis = $true
    $layout.Controls.Add($hintLabel, 1, 1)

    $ValueLabel.Value = $value
    return $panel
}
'''

pattern = r'function New-NFSummaryCard \{.*?\n\}\n(?=\nfunction )'
nf, count = re.subn(pattern, new_summary_function, nf, count=1, flags=re.S)
if count != 1:
    raise SystemExit(f'funcao New-NFSummaryCard: esperado 1 marcador, encontrado {count}')

# Cards superiores ganham alguns pixels para o complemento aparecer inteiro.
nf = one(
    nf,
    '$nfCardsHeight = if ($script:IsInProcessHosted) { 88 } else { 108 }',
    '$nfCardsHeight = if ($script:IsInProcessHosted) { 96 } else { 108 }',
    'altura dos cards NF'
)

# Resumo: mais área útil e nenhuma barra de rolagem onde o conteúdo é fechado.
nf = one(
    nf,
    '$summaryLayout.Padding = [Windows.Forms.Padding]::new(10)',
    '$summaryLayout.Padding = if ($script:IsInProcessHosted) { [Windows.Forms.Padding]::new(8, 6, 8, 6) } else { [Windows.Forms.Padding]::new(10) }',
    'padding da aba Resumo'
)
nf = one(
    nf,
    '$productGroup.Padding = [Windows.Forms.Padding]::new(10, 22, 10, 10)',
    '$productGroup.Padding = if ($script:IsInProcessHosted) { [Windows.Forms.Padding]::new(8, 18, 8, 6) } else { [Windows.Forms.Padding]::new(10, 22, 10, 10) }',
    'padding Saldo por produto'
)
nf = one(
    nf,
    '$productSummaryGrid = New-NFGrid\nAdd-NFGridColumn $productSummaryGrid "Produto" "PRODUTO" 200 $true',
    '''$productSummaryGrid = New-NFGrid
$productSummaryGrid.ScrollBars = [Windows.Forms.ScrollBars]::None
$productSummaryGrid.RowTemplate.Height = if ($script:IsInProcessHosted) { 21 } else { 27 }
$productSummaryGrid.ColumnHeadersHeight = if ($script:IsInProcessHosted) { 26 } else { 30 }
Add-NFGridColumn $productSummaryGrid "Produto" "PRODUTO" 200 $true''',
    'grade Saldo por produto sem rolagem'
)
nf = one(
    nf,
    '$codeGroup.Padding = [Windows.Forms.Padding]::new(10, 22, 10, 10)',
    '$codeGroup.Padding = if ($script:IsInProcessHosted) { [Windows.Forms.Padding]::new(8, 18, 8, 6) } else { [Windows.Forms.Padding]::new(10, 22, 10, 10) }',
    'padding Saldo por codigo'
)
nf = one(
    nf,
    '$codeSummaryGrid = New-NFGrid\nAdd-NFGridColumn $codeSummaryGrid "Codigo" "CÓDIGO" 110',
    '''$codeSummaryGrid = New-NFGrid
$codeSummaryGrid.ScrollBars = [Windows.Forms.ScrollBars]::None
$codeSummaryGrid.RowTemplate.Height = if ($script:IsInProcessHosted) { 21 } else { 27 }
$codeSummaryGrid.ColumnHeadersHeight = if ($script:IsInProcessHosted) { 26 } else { 30 }
Add-NFGridColumn $codeSummaryGrid "Codigo" "CÓDIGO" 110''',
    'grade Saldo por codigo sem rolagem'
)

# Atividade operacional: reduz margens/padding para os cards e textos caberem por inteiro.
nf = one(
    nf,
    '$activityGroup.Padding = [Windows.Forms.Padding]::new(8, 20, 8, 8)',
    '$activityGroup.Padding = if ($script:IsInProcessHosted) { [Windows.Forms.Padding]::new(8, 18, 8, 6) } else { [Windows.Forms.Padding]::new(8, 20, 8, 8) }',
    'padding Atividade operacional'
)
nf = one(
    nf,
    '$activityLayout.Dock = [Windows.Forms.DockStyle]::Fill\n$activityLayout.ColumnCount = 5',
    '$activityLayout.Dock = [Windows.Forms.DockStyle]::Fill\n$activityLayout.Margin = [Windows.Forms.Padding]::new(0)\n$activityLayout.ColumnCount = 5',
    'margem Atividade operacional'
)
nf = one(
    nf,
    '$lastPanel.Margin = [Windows.Forms.Padding]::new(6)',
    '$lastPanel.Margin = if ($script:IsInProcessHosted) { [Windows.Forms.Padding]::new(4) } else { [Windows.Forms.Padding]::new(6) }',
    'margem Ultima movimentacao'
)
nf = one(
    nf,
    '$summaryActionPanel.Padding = [Windows.Forms.Padding]::new(4, 22, 4, 4)',
    '$summaryActionPanel.Padding = if ($script:IsInProcessHosted) { [Windows.Forms.Padding]::new(4, 10, 4, 4) } else { [Windows.Forms.Padding]::new(4, 22, 4, 4) }',
    'padding Pendencias'
)

# Marcadores desta correção para auditoria futura.
maintenance += '\n# POST_CURE_RESUMO_MANUTENCAO_V0611\n'
nf += '\n# POST_CURE_NF_SUMMARY_FIT_V02617\n'
central += '\n# POST_CURE_UI_FIXES_V02148\n'

for marker in (
    '$script:AppVersion = "0.21.48"',
    '$script:MaintenanceVersion = "0.6.11"',
    '$script:NFEntradaVersion = "2.6.17"',
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
    '$script:ModuleVersion = "2.6.17"',
    'POST_CURE_NF_SUMMARY_FIT_V02617',
    '$productSummaryGrid.ScrollBars = [Windows.Forms.ScrollBars]::None',
    '$codeSummaryGrid.ScrollBars = [Windows.Forms.ScrollBars]::None',
    '$isActivityCard = @("MOVIMENTAÇÕES HOJE", "PEÇAS SAÍRAM HOJE", "PEÇAS EM 7 DIAS") -contains $Title',
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
print('POST-CURE UI: OK - resumo da Manutencao preservado; Resumo do NF sem rolagens desnecessarias e Atividade operacional sem cortes.')
