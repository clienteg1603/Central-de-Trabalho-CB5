from pathlib import Path

cp = Path('src/generated/Central de Trabalho.ps1')
np = Path('src/generated/Modulos/Controle-NF-Entrada/Controle NF Entrada.ps1')

c = cp.read_text(encoding='utf-8-sig')
n = np.read_text(encoding='utf-8-sig')


def one(text, old, new, label):
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'NF FULL FIT {label}: esperado 1, encontrado {count}')
    return text.replace(old, new, 1)


# Versões — somente canal Teste.
c = one(c, '$script:AppVersion = "0.21.59"', '$script:AppVersion = "0.21.60"', 'versao Central')
c = one(c, '$script:NFEntradaVersion = "2.6.23"', '$script:NFEntradaVersion = "2.6.24"', 'versao NF Central')
n = one(n, '$script:ModuleVersion = "2.6.23"', '$script:ModuleVersion = "2.6.24"', 'versao NF modulo')

# Cabeçalho: os dois comandos precisam de largura real suficiente em DPI/host.
# Antes, 150 px no modo hospedado era pouco para IMPORTAR EXCEL com padding e
# arredondamento, produzindo o recorte visto no uso real.
n = one(
    n,
    '''        $actionW = if ($profile -eq "Tight") { 112 } elseif ($profile -eq "Compact") { 132 } else { $(if ($script:IsInProcessHosted) { 150 } else { 175 }) }
        $header.ColumnStyles[1].Width = $actionW
        $header.ColumnStyles[2].Width = $actionW''',
    '''        $actionW = if ($profile -eq "Tight") { 138 } elseif ($profile -eq "Compact") { 158 } else { $(if ($script:IsInProcessHosted) { 176 } else { 190 }) }
        $header.ColumnStyles[1].Width = $actionW
        $header.ColumnStyles[2].Width = $actionW''',
    'largura das acoes do cabecalho'
)

n = one(
    n,
    '''        $importButton.Margin = [Windows.Forms.Padding]::new(6, $(if ($profile -eq "Tight") { 8 } else { 10 }), 0, $(if ($profile -eq "Tight") { 7 } else { 9 }))
        $exportButton.Margin = $importButton.Margin''',
    '''        $buttonTop = if ($profile -eq "Tight") { 7 } else { 9 }
        $buttonBottom = if ($profile -eq "Tight") { 6 } else { 8 }
        $importButton.Margin = [Windows.Forms.Padding]::new(5, $buttonTop, 5, $buttonBottom)
        $exportButton.Margin = [Windows.Forms.Padding]::new(5, $buttonTop, 5, $buttonBottom)
        $importButton.Padding = [Windows.Forms.Padding]::new(4,0,4,0)
        $exportButton.Padding = [Windows.Forms.Padding]::new(4,0,4,0)
        $headerButtonFont = if ($profile -eq "Tight") { 7.8 } elseif ($profile -eq "Compact") { 8.0 } else { 8.3 }
        $importButton.Font = [Drawing.Font]::new("Segoe UI Semibold", $headerButtonFont)
        $exportButton.Font = [Drawing.Font]::new("Segoe UI Semibold", $headerButtonFont)
        $importButton.AutoEllipsis = $false
        $exportButton.AutoEllipsis = $false''',
    'geometria das acoes do cabecalho'
)

# Navegação: o nome completo continua na aba interna, mas o botão visual usa um
# rótulo curto e inequívoco. Assim fica centralizado e nunca depende de reticências.
n = one(
    n,
    '$script:NFComputerNavButton = New-NFSectionNavButton "COMPUTADOR DE BORDO CB5 (0)"',
    '$script:NFComputerNavButton = New-NFSectionNavButton "COMPUTADOR CB5 (0)"',
    'rotulo inicial computador'
)
n = one(
    n,
    '$button.AutoEllipsis = $true',
    '$button.AutoEllipsis = $false',
    'reticencias da navegacao'
)
n = one(
    n,
    'if ($null -ne $script:NFComputerNavButton) { $script:NFComputerNavButton.Text = $computerTab.Text }',
    'if ($null -ne $script:NFComputerNavButton) { $script:NFComputerNavButton.Text = "COMPUTADOR CB5 ($([int]$summary.Produtos[$script:ComputerProduct].Registros))" }',
    'contador do computador na navegacao'
)

# Resumo: em vez de repartir uma altura curta por percentuais e cortar linhas,
# as três faixas recebem mínimos absolutos. Se a viewport for menor, a rolagem é
# da página do Resumo como um todo; as grades internas continuam sem scrollbar.
old_summary = r'''        $summaryLayout.RowStyles[0].SizeType = [Windows.Forms.SizeType]::Percent
        $summaryLayout.RowStyles[1].SizeType = [Windows.Forms.SizeType]::Absolute
        $summaryLayout.RowStyles[2].SizeType = [Windows.Forms.SizeType]::Percent
        if ($profile -eq "Tight") {
            $summaryLayout.RowStyles[0].Height = 52; $summaryLayout.RowStyles[1].Height = 176; $summaryLayout.RowStyles[2].Height = 48
        } elseif ($profile -eq "Compact") {
            $summaryLayout.RowStyles[0].Height = 53; $summaryLayout.RowStyles[1].Height = 184; $summaryLayout.RowStyles[2].Height = 47
        } else {
            $summaryLayout.RowStyles[0].Height = 54; $summaryLayout.RowStyles[1].Height = 190; $summaryLayout.RowStyles[2].Height = 46
        }
        $codeGroup.Padding=if($profile -eq "Tight"){[Windows.Forms.Padding]::new(7,17,7,5)}elseif($profile -eq "Compact"){[Windows.Forms.Padding]::new(8,18,8,6)}else{[Windows.Forms.Padding]::new(9,19,9,7)}'''
new_summary = r'''        $summaryLayout.AutoScroll = $true
        $summaryLayout.RowStyles[0].SizeType = [Windows.Forms.SizeType]::Absolute
        $summaryLayout.RowStyles[1].SizeType = [Windows.Forms.SizeType]::Absolute
        $summaryLayout.RowStyles[2].SizeType = [Windows.Forms.SizeType]::Absolute

        $summaryTopMin = if ($profile -eq "Tight") { 142 } elseif ($profile -eq "Compact") { 150 } else { 158 }
        $summaryCodeMin = if ($profile -eq "Tight") { 158 } elseif ($profile -eq "Compact") { 168 } else { 178 }
        $summaryActivityMin = if ($profile -eq "Tight") { 126 } elseif ($profile -eq "Compact") { 132 } else { 138 }
        $summaryBaseHeight = $summaryTopMin + $summaryCodeMin + $summaryActivityMin
        $summaryAvailableHeight = [Math]::Max(0, [int]$summaryLayout.ClientSize.Height - [int]$summaryLayout.Padding.Vertical)
        $summaryExtra = [Math]::Max(0, $summaryAvailableHeight - $summaryBaseHeight)

        $summaryLayout.RowStyles[0].Height = $summaryTopMin
        $summaryLayout.RowStyles[1].Height = $summaryCodeMin
        $summaryLayout.RowStyles[2].Height = $summaryActivityMin + $summaryExtra
        $summaryLayout.AutoScrollMinSize = [Drawing.Size]::new(0, $summaryBaseHeight + [int]$summaryLayout.Padding.Vertical)

        $productGroup.Padding = if ($profile -eq "Tight") {
            [Windows.Forms.Padding]::new(7,17,7,5)
        } elseif ($profile -eq "Compact") {
            [Windows.Forms.Padding]::new(8,19,8,6)
        } else {
            [Windows.Forms.Padding]::new(9,21,9,7)
        }
        $codeGroup.Padding=if($profile -eq "Tight"){[Windows.Forms.Padding]::new(7,17,7,5)}elseif($profile -eq "Compact"){[Windows.Forms.Padding]::new(8,18,8,6)}else{[Windows.Forms.Padding]::new(9,19,9,7)}'''
n = one(n, old_summary, new_summary, 'faixas minimas do Resumo')

# A grade de produto possui exatamente três linhas de dados. Mantemos todas
# visíveis sem scroll interno e reservamos uma densidade segura para notebook.
anchor = '''        foreach ($grid in @($productSummaryGrid,$codeSummaryGrid)) {
            if ($null -eq $grid) { continue }
            try {
                $grid.ColumnHeadersHeight = if ($profile -eq "Tight") { 21 } elseif ($profile -eq "Compact") { 23 } else { 25 }
                $grid.RowTemplate.Height = if ($profile -eq "Tight") { 18 } elseif ($profile -eq "Compact") { 19 } else { 20 }
            } catch {}
        }'''
replacement = '''        foreach ($grid in @($productSummaryGrid,$codeSummaryGrid)) {
            if ($null -eq $grid) { continue }
            try {
                $grid.ColumnHeadersHeight = if ($profile -eq "Tight") { 22 } elseif ($profile -eq "Compact") { 23 } else { 25 }
                $grid.RowTemplate.Height = if ($profile -eq "Tight") { 20 } elseif ($profile -eq "Compact") { 21 } else { 22 }
            } catch {}
        }
        try {
            $productSummaryGrid.ScrollBars = [Windows.Forms.ScrollBars]::None
            $productSummaryGrid.AutoSizeRowsMode = [Windows.Forms.DataGridViewAutoSizeRowsMode]::None
            foreach ($row in @($productSummaryGrid.Rows)) {
                if (-not $row.IsNewRow) { $row.Height = if ($profile -eq "Tight") { 20 } elseif ($profile -eq "Compact") { 21 } else { 22 } }
            }
        } catch {}'''
n = one(n, anchor, replacement, 'densidade da grade Saldo por produto')

# A Conferência precisa das seis linhas completas; nada de elipse vertical.
conf_anchor = '''            if ($null -ne $conferenceLabel) {
                $conferenceLabel.Margin = [Windows.Forms.Padding]::new(0)
                $conferenceLabel.AutoEllipsis = $true
                $conferenceLabel.Font = [Drawing.Font]::new("Segoe UI", $conferenceLabelFont)
            }
            if ($null -ne $conferenceValue) {
                $conferenceValue.Margin = [Windows.Forms.Padding]::new(0)
                $conferenceValue.AutoEllipsis = $true
                $conferenceValue.Font = [Drawing.Font]::new("Segoe UI Semibold", $conferenceValueFont)
            }'''
conf_replacement = '''            if ($null -ne $conferenceLabel) {
                $conferenceLabel.Margin = [Windows.Forms.Padding]::new(0)
                $conferenceLabel.AutoEllipsis = $false
                $conferenceLabel.Font = [Drawing.Font]::new("Segoe UI", $conferenceLabelFont)
            }
            if ($null -ne $conferenceValue) {
                $conferenceValue.Margin = [Windows.Forms.Padding]::new(0)
                $conferenceValue.AutoEllipsis = $false
                $conferenceValue.Font = [Drawing.Font]::new("Segoe UI Semibold", $conferenceValueFont)
            }'''
n = one(n, conf_anchor, conf_replacement, 'conferencia sem recorte por elipse')

c += '\n# NF_FULL_FIT_V02160\n'
n += '\n# NF_FULL_FIT_V02624\n'

for marker in (
    '$script:AppVersion = "0.21.60"',
    '$script:NFEntradaVersion = "2.6.24"',
    'NF_FULL_FIT_V02160',
):
    if marker not in c:
        raise SystemExit('NF FULL FIT Central marcador ausente: ' + marker)

for marker in (
    '$script:ModuleVersion = "2.6.24"',
    '$actionW = if ($profile -eq "Tight") { 138 }',
    'New-NFSectionNavButton "COMPUTADOR CB5 (0)"',
    '$summaryLayout.AutoScroll = $true',
    '$summaryTopMin = if ($profile -eq "Tight") { 142 }',
    '$productSummaryGrid.ScrollBars = [Windows.Forms.ScrollBars]::None',
    'NF_FULL_FIT_V02624',
):
    if marker not in n:
        raise SystemExit('NF FULL FIT marcador ausente: ' + marker)

for forbidden in (
    '$mainTabs.Add_SizeChanged',
    '$mainTabs.Add_HandleCreated',
    '$mainTabs.DrawMode = [Windows.Forms.TabDrawMode]::OwnerDrawFixed',
    '$mainTabs.ItemSize',
    'Update-NFMainTabStripLayout',
):
    if forbidden in n:
        raise SystemExit('NF FULL FIT mecanismo proibido reapareceu: ' + forbidden)

cp.write_text(c, encoding='utf-8')
np.write_text(n, encoding='utf-8')
print('NF FULL FIT: OK - cabecalho, navegacao e Resumo protegidos contra cortes em tela pequena/DPI.')
