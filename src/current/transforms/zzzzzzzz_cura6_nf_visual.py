from pathlib import Path

central_path = Path('src/generated/Central de Trabalho.ps1')
nf_path = Path('src/generated/Modulos/Controle-NF-Entrada/Controle NF Entrada.ps1')

central = central_path.read_text(encoding='utf-8-sig')
nf = nf_path.read_text(encoding='utf-8-sig')


def one(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: esperado 1 marcador, encontrado {count}')
    return text.replace(old, new, 1)


# Versoes da CURA 6. Este transform roda depois da CURA 5.
central = one(central, '$script:AppVersion = "0.21.39"', '$script:AppVersion = "0.21.40"', 'versao Central')
central = one(central, '$script:NFEntradaVersion = "2.6.10"', '$script:NFEntradaVersion = "2.6.11"', 'versao NF na Central')
nf = one(nf, '$script:ModuleVersion = "2.6.10"', '$script:ModuleVersion = "2.6.11"', 'versao NF')

# Grades: no modo integrado a moldura quadrada externa e redundante. A grade,
# cabecalho, linhas e selecao continuam exatamente iguais.
nf = one(
    nf,
    '$grid.BorderStyle = [Windows.Forms.BorderStyle]::FixedSingle',
    '$grid.BorderStyle = if ($script:IsInProcessHosted) { [Windows.Forms.BorderStyle]::None } else { [Windows.Forms.BorderStyle]::FixedSingle }',
    'moldura das grades'
)

# Cards: mais compactos no host e sem a borda nativa pesada. Standalone mantem
# as dimensoes anteriores.
nf = one(
    nf,
    '''    $panel.Margin = [Windows.Forms.Padding]::new(6)\n    $panel.BackColor = $script:CurrentPalette.Card\n    $panel.Tag = "Theme.Card"\n    $panel.BorderStyle = [Windows.Forms.BorderStyle]::FixedSingle''',
    '''    $panel.Margin = if ($script:IsInProcessHosted) { [Windows.Forms.Padding]::new(4, 4, 4, 6) } else { [Windows.Forms.Padding]::new(6) }\n    $panel.BackColor = $script:CurrentPalette.Card\n    $panel.Tag = "Theme.Card"\n    $panel.BorderStyle = if ($script:IsInProcessHosted) { [Windows.Forms.BorderStyle]::None } else { [Windows.Forms.BorderStyle]::FixedSingle }''',
    'acabamento dos cards'
)
nf = one(
    nf,
    '$layout.Padding = [Windows.Forms.Padding]::new(13, 8, 13, 7)',
    '$layout.Padding = if ($script:IsInProcessHosted) { [Windows.Forms.Padding]::new(12, 6, 12, 5) } else { [Windows.Forms.Padding]::new(13, 8, 13, 7) }',
    'padding dos cards'
)
nf = one(
    nf,
    '''    $value.Font = [Drawing.Font]::new("Segoe UI Semibold", 21)\n    $value.ForeColor = $script:CurrentPalette.Text''',
    '''    $value.Font = [Drawing.Font]::new("Segoe UI Semibold", $(if ($script:IsInProcessHosted) { 18.5 } else { 21 }))\n    $value.ForeColor = if ($script:IsInProcessHosted) { $script:CurrentPalette.Accent } else { $script:CurrentPalette.Text }\n    if ($script:IsInProcessHosted) { $value.Tag = "Theme.Accent" }''',
    'hierarquia dos valores dos cards'
)

# A tematizacao semantica passa a reconhecer o papel Accent usado somente nos
# numeros principais do resumo hospedado.
nf = one(
    nf,
    '''    elseif ($Control -is [Windows.Forms.Label]) {\n        $Control.ForeColor = if ([string]$Control.Tag -eq "Theme.Muted") { $palette.Muted } else { $palette.Text }\n    }''',
    '''    elseif ($Control -is [Windows.Forms.Label]) {\n        $role = [string]$Control.Tag\n        if ($role -eq "Theme.Muted") { $Control.ForeColor = $palette.Muted }\n        elseif ($role -eq "Theme.Accent") { $Control.ForeColor = $palette.Accent }\n        else { $Control.ForeColor = $palette.Text }\n    }''',
    'papel visual Accent'
)

# Densidade da casca. Nao ha eventos de SizeChanged/HandleCreated nem mudanca
# de ItemSize das abas: preservamos deliberadamente o caminho estavel que
# resolveu o travamento anterior do Controle de NF.
nf = one(
    nf,
    '$root.Padding = [Windows.Forms.Padding]::new(14)',
    '$root.Padding = if ($script:IsInProcessHosted) { [Windows.Forms.Padding]::new(8, 6, 8, 6) } else { [Windows.Forms.Padding]::new(14) }',
    'padding da raiz'
)
nf = one(
    nf,
    '''[void]$root.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 92)))\n[void]$root.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 108)))\n[void]$root.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 100)))\n[void]$root.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 58)))''',
    '''$nfHeaderHeight = if ($script:IsInProcessHosted) { 68 } else { 92 }\n$nfCardsHeight = if ($script:IsInProcessHosted) { 88 } else { 108 }\n$nfFooterHeight = if ($script:IsInProcessHosted) { 52 } else { 58 }\n[void]$root.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, $nfHeaderHeight)))\n[void]$root.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, $nfCardsHeight)))\n[void]$root.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 100)))\n[void]$root.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, $nfFooterHeight)))''',
    'alturas da casca'
)

# Mais largura para o titulo no modo integrado; importacao/exportacao continuam
# no mesmo local e com os mesmos eventos.
nf = one(
    nf,
    '''[void]$header.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 100)))\n[void]$header.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Absolute, 175)))\n[void]$header.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Absolute, 175)))''',
    '''$nfHeaderActionWidth = if ($script:IsInProcessHosted) { 150 } else { 175 }\n[void]$header.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 100)))\n[void]$header.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Absolute, $nfHeaderActionWidth)))\n[void]$header.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Absolute, $nfHeaderActionWidth)))\n$header.Margin = [Windows.Forms.Padding]::new(0)''',
    'largura das acoes do cabecalho'
)
nf = one(
    nf,
    '''[void]$heading.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 54)))\n[void]$heading.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 100)))''',
    '''$nfHeadingTitleHeight = if ($script:IsInProcessHosted) { 39 } else { 54 }\n[void]$heading.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, $nfHeadingTitleHeight)))\n[void]$heading.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 100)))''',
    'densidade do titulo'
)
nf = one(
    nf,
    '$title.Font = [Drawing.Font]::new("Segoe UI Semibold", 20)',
    '$title.Font = [Drawing.Font]::new("Segoe UI Semibold", $(if ($script:IsInProcessHosted) { 15.5 } else { 20 }))',
    'fonte do titulo'
)
nf = one(
    nf,
    '''$subtitle.TextAlign = [Drawing.ContentAlignment]::TopLeft\n$subtitle.ForeColor = $script:CurrentPalette.Muted''',
    '''$subtitle.TextAlign = [Drawing.ContentAlignment]::TopLeft\n$subtitle.ForeColor = $script:CurrentPalette.Muted\nif ($script:IsInProcessHosted) { $subtitle.Font = [Drawing.Font]::new("Segoe UI", 8.2) }''',
    'subtitulo integrado'
)
nf = one(
    nf,
    '''$importButton.Margin = [Windows.Forms.Padding]::new(10, 16, 0, 14)''',
    '''$importButton.Margin = if ($script:IsInProcessHosted) { [Windows.Forms.Padding]::new(8, 11, 0, 9) } else { [Windows.Forms.Padding]::new(10, 16, 0, 14) }''',
    'margem do importar'
)
nf = one(
    nf,
    '''$exportButton.Margin = [Windows.Forms.Padding]::new(10, 16, 0, 14)''',
    '''$exportButton.Margin = if ($script:IsInProcessHosted) { [Windows.Forms.Padding]::new(8, 11, 0, 9) } else { [Windows.Forms.Padding]::new(10, 16, 0, 14) }''',
    'margem do exportar'
)

# Cards e abas usam a area disponivel sem reconfigurar o TabControl.
nf = one(
    nf,
    '''$cards.Dock = [Windows.Forms.DockStyle]::Fill\n$cards.ColumnCount = 4''',
    '''$cards.Dock = [Windows.Forms.DockStyle]::Fill\n$cards.Margin = if ($script:IsInProcessHosted) { [Windows.Forms.Padding]::new(0, 2, 0, 2) } else { [Windows.Forms.Padding]::new(3) }\n$cards.ColumnCount = 4''',
    'margem do resumo'
)
nf = one(
    nf,
    '''$mainTabs.Dock = [Windows.Forms.DockStyle]::Fill\n$mainTabs.Font = [Drawing.Font]::new("Segoe UI Semibold", 9)''',
    '''$mainTabs.Dock = [Windows.Forms.DockStyle]::Fill\n$mainTabs.Margin = if ($script:IsInProcessHosted) { [Windows.Forms.Padding]::new(0, 4, 0, 4) } else { [Windows.Forms.Padding]::new(3) }\n$mainTabs.Font = [Drawing.Font]::new("Segoe UI Semibold", $(if ($script:IsInProcessHosted) { 8.6 } else { 9 }))''',
    'margem das abas nativas'
)

# Ultima movimentacao segue o acabamento dos cards no host.
nf = one(
    nf,
    '$lastPanel.BorderStyle = [Windows.Forms.BorderStyle]::FixedSingle',
    '$lastPanel.BorderStyle = if ($script:IsInProcessHosted) { [Windows.Forms.BorderStyle]::None } else { [Windows.Forms.BorderStyle]::FixedSingle }',
    'card da ultima movimentacao'
)

# Rodape um pouco mais enxuto; nenhuma acao e removida.
nf = one(
    nf,
    '$footerHost.Padding = [Windows.Forms.Padding]::new(8, 8, 8, 8)',
    '$footerHost.Padding = if ($script:IsInProcessHosted) { [Windows.Forms.Padding]::new(8, 6, 8, 6) } else { [Windows.Forms.Padding]::new(8, 8, 8, 8) }',
    'padding do rodape'
)

# Marcador de contrato da CURA 6.
nf += '\n# CURA6_NF_VISUAL_V02611\n'

for marker in (
    '$script:AppVersion = "0.21.40"',
    '$script:NFEntradaVersion = "2.6.11"',
):
    if marker not in central:
        raise SystemExit('marcador ausente na Central: ' + marker)

for marker in (
    '$script:ModuleVersion = "2.6.11"',
    'CURA6_NF_VISUAL_V02611',
    'Theme.Accent',
    '$nfHeaderHeight = if ($script:IsInProcessHosted) { 68 } else { 92 }',
    '$grid.BorderStyle = if ($script:IsInProcessHosted)',
):
    if marker not in nf:
        raise SystemExit('marcador ausente no NF: ' + marker)

# Garantia explicita: a CURA 6 nao pode reintroduzir o caminho de tabstrip que
# causou reentrada de layout na versao anterior.
for forbidden in (
    '$mainTabs.Add_SizeChanged',
    '$mainTabs.Add_HandleCreated',
    '$mainTabs.DrawMode = [Windows.Forms.TabDrawMode]::OwnerDrawFixed',
):
    if forbidden in nf:
        raise SystemExit('CURA 6 reintroduziu mecanismo proibido de abas: ' + forbidden)

central_path.write_text(central, encoding='utf-8')
nf_path.write_text(nf, encoding='utf-8')
print('CURA 6 NF: OK - densidade integrada, cards e grades refinados sem tocar no mecanismo estavel das abas.')
