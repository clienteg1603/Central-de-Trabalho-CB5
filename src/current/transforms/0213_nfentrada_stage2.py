from pathlib import Path
import json

ROOT = Path('.')
ui_path = ROOT / 'src/generated/Modulos/Controle-NF-Entrada/Controle NF Entrada.ps1'
core_path = ROOT / 'src/generated/Modulos/Controle-NF-Entrada/NFEntrada.Core.ps1'
central_path = ROOT / 'src/generated/Central de Trabalho.ps1'
reg_path = ROOT / 'src/ci/regression_contracts.py'
version_path = ROOT / 'src/current/version.json'


def read(path):
    return path.read_text(encoding='utf-8-sig')


def write(path, text):
    path.write_text(text, encoding='utf-8')


def replace_once(text, old, new, label):
    if old not in text:
        raise SystemExit(f'Etapa 2 NF Entrada: trecho não encontrado ({label})')
    return text.replace(old, new, 1)


# ---------- Núcleo: estado operacional único para tela e filtros ----------
core = read(core_path)
anchor = '''function Get-NFEntradaProductRecords {
'''
status_fn = r'''function Get-NFEntradaRecordStatus {
    param([Parameter(Mandatory = $true)]$Record)
    $qty = [int]$Record.QuantidadeNaNF
    $saldo = [int]$Record.QuantidadeSaldo
    if ($saldo -lt 0 -or $saldo -gt $qty) { return "Revisar" }
    if ($saldo -eq 0) { return "Encerrada" }
    return "Em estoque"
}

'''
core = replace_once(core, anchor, status_fn + anchor, 'estado operacional')
write(core_path, core)

# ---------- Interface: filtros claros, status visível, cards e rodapé ----------
ui = read(ui_path)
ui = replace_once(ui, '$script:ModuleVersion = "1.1.0"', '$script:ModuleVersion = "1.2.0"', 'versão do módulo')

old_refresh = r'''function Refresh-NFProductGrid {
    param([string]$Product, [Windows.Forms.DataGridView]$Grid, [Windows.Forms.TextBox]$FilterBox)
    $filter = if ($null -ne $FilterBox) { ([string]$FilterBox.Text).Trim().ToLowerInvariant() } else { "" }
    $Grid.Rows.Clear()
    foreach ($record in Get-NFEntradaProductRecords -Store $script:Store -Product $Product) {
        $search = (([string]$record.NFEntrada) + " " + ([string]$record.Codigo) + " " + ([string]$record.NFSaida) + " " + (Format-NFDate ([string]$record.Data))).ToLowerInvariant()
        if (-not [string]::IsNullOrWhiteSpace($filter) -and -not $search.Contains($filter)) { continue }
        $index = $Grid.Rows.Add(
            [int]$record.Id,
            (Format-NFDate ([string]$record.Data)),
            [int]$record.QuantidadeNaNF,
            [string]$record.NFEntrada,
            [int]$record.QuantidadeSaldo,
            [string]$record.Codigo,
            [string]$record.NFSaida
        )
        $row = $Grid.Rows[$index]
        $qty = [int]$record.QuantidadeNaNF
        $saldo = [int]$record.QuantidadeSaldo
        if ($saldo -lt 0 -or $saldo -gt $qty) {
            $row.DefaultCellStyle.BackColor = $script:CurrentPalette.DangerBack
            $row.DefaultCellStyle.ForeColor = $script:CurrentPalette.Danger
        }
        elseif ($saldo -eq 0) {
            $row.DefaultCellStyle.BackColor = $script:CurrentPalette.SuccessBack
            $row.DefaultCellStyle.ForeColor = $script:CurrentPalette.Success
        }
        else {
            $row.DefaultCellStyle.BackColor = $script:CurrentPalette.WarningBack
            $row.DefaultCellStyle.ForeColor = $script:CurrentPalette.Warning
        }
    }
    $Grid.ClearSelection()
}
'''
new_refresh = r'''function Refresh-NFProductGrid {
    param(
        [string]$Product,
        [Windows.Forms.DataGridView]$Grid,
        [Windows.Forms.TextBox]$FilterBox,
        [Windows.Forms.ComboBox]$StatusFilter,
        [Windows.Forms.ComboBox]$CodeFilter,
        [Windows.Forms.Label]$CountLabel
    )
    $filter = if ($null -ne $FilterBox) { ([string]$FilterBox.Text).Trim().ToLowerInvariant() } else { "" }
    $selectedStatus = if ($null -ne $StatusFilter -and $StatusFilter.SelectedIndex -gt 0) { [string]$StatusFilter.SelectedItem } else { "Todos" }
    $selectedCode = if ($null -ne $CodeFilter -and $CodeFilter.SelectedIndex -gt 0) { [string]$CodeFilter.SelectedItem } else { "Todos" }
    $records = @(Get-NFEntradaProductRecords -Store $script:Store -Product $Product)
    $shown = 0
    $Grid.Rows.Clear()
    foreach ($record in $records) {
        $status = Get-NFEntradaRecordStatus -Record $record
        if ($selectedStatus -ne "Todos" -and $status -ne $selectedStatus) { continue }
        if ($selectedCode -ne "Todos" -and ([string]$record.Codigo) -ne $selectedCode) { continue }
        $search = (([string]$record.NFEntrada) + " " + ([string]$record.Codigo) + " " + ([string]$record.NFSaida) + " " + (Format-NFDate ([string]$record.Data)) + " " + $status).ToLowerInvariant()
        if (-not [string]::IsNullOrWhiteSpace($filter) -and -not $search.Contains($filter)) { continue }
        $index = $Grid.Rows.Add(
            [int]$record.Id,
            (Format-NFDate ([string]$record.Data)),
            [int]$record.QuantidadeNaNF,
            [string]$record.NFEntrada,
            [int]$record.QuantidadeSaldo,
            [string]$record.Codigo,
            $status,
            [string]$record.NFSaida
        )
        $shown++
        $row = $Grid.Rows[$index]
        switch ($status) {
            "Revisar" {
                $row.DefaultCellStyle.BackColor = $script:CurrentPalette.DangerBack
                $row.DefaultCellStyle.ForeColor = $script:CurrentPalette.Danger
            }
            "Encerrada" {
                $row.DefaultCellStyle.BackColor = $script:CurrentPalette.SuccessBack
                $row.DefaultCellStyle.ForeColor = $script:CurrentPalette.Success
            }
            default {
                $row.DefaultCellStyle.BackColor = $script:CurrentPalette.WarningBack
                $row.DefaultCellStyle.ForeColor = $script:CurrentPalette.Warning
            }
        }
    }
    if ($null -ne $CountLabel) { $CountLabel.Text = "$shown de $($records.Count)" }
    $Grid.ClearSelection()
}
'''
ui = replace_once(ui, old_refresh, new_refresh, 'grade filtrável')

old_refresh_all = r'''function Refresh-NFAll {
    Refresh-NFSummary
    Refresh-NFProductGrid -Product $script:ComputerProduct -Grid $computerGrid -FilterBox $computerFilter
    Refresh-NFProductGrid -Product $script:KeyboardProduct -Grid $keyboardGrid -FilterBox $keyboardFilter
    $templateReady = [IO.File]::Exists((Get-NFEntradaTemplatePath -DataDirectory $script:DataDirectory))
    $exportButton.Enabled = $templateReady
    $summary = Get-NFEntradaSummary -Store $script:Store
    $totalRecords = [int]$summary.Produtos[$script:ComputerProduct].Registros + [int]$summary.Produtos[$script:KeyboardProduct].Registros
    Set-NFStatus ("Pronto • " + $totalRecords + " registro(s) • base local protegida") "Normal"
}
'''
new_refresh_all = r'''function Refresh-NFAll {
    Refresh-NFSummary
    Refresh-NFProductGrid -Product $script:ComputerProduct -Grid $computerGrid -FilterBox $computerFilter -StatusFilter $computerStatusFilter -CodeFilter $computerCodeFilter -CountLabel $computerCountLabel
    Refresh-NFProductGrid -Product $script:KeyboardProduct -Grid $keyboardGrid -FilterBox $keyboardFilter -StatusFilter $keyboardStatusFilter -CodeFilter $keyboardCodeFilter -CountLabel $keyboardCountLabel
    $templateReady = [IO.File]::Exists((Get-NFEntradaTemplatePath -DataDirectory $script:DataDirectory))
    $exportButton.Enabled = $templateReady
    $summary = Get-NFEntradaSummary -Store $script:Store
    $totalRecords = [int]$summary.Produtos[$script:ComputerProduct].Registros + [int]$summary.Produtos[$script:KeyboardProduct].Registros
    Set-NFStatus ("Pronto • " + $totalRecords + " registro(s) • base local protegida") "Normal"
}
'''
ui = replace_once(ui, old_refresh_all, new_refresh_all, 'atualização completa')

old_card = r'''function New-NFSummaryCard {
    param([string]$Title, [ref]$ValueLabel)
    $panel = New-Object Windows.Forms.Panel
    $panel.Dock = [Windows.Forms.DockStyle]::Fill
    $panel.Margin = [Windows.Forms.Padding]::new(5)
    $panel.BackColor = $script:CurrentPalette.Card
    $panel.BorderStyle = [Windows.Forms.BorderStyle]::FixedSingle
    $layout = New-Object Windows.Forms.TableLayoutPanel
    $layout.Dock = [Windows.Forms.DockStyle]::Fill
    $layout.Padding = [Windows.Forms.Padding]::new(12, 8, 12, 7)
    $layout.RowCount = 2
    [void]$layout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 62)))
    [void]$layout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 38)))
    $panel.Controls.Add($layout)
    $value = New-Object Windows.Forms.Label
    $value.Text = "0"
    $value.Dock = [Windows.Forms.DockStyle]::Fill
    $value.TextAlign = [Drawing.ContentAlignment]::BottomLeft
    $value.Font = [Drawing.Font]::new("Segoe UI Semibold", 22)
    $value.ForeColor = $script:CurrentPalette.Text
    $layout.Controls.Add($value, 0, 0)
    $label = New-Object Windows.Forms.Label
    $label.Text = $Title
    $label.Dock = [Windows.Forms.DockStyle]::Fill
    $label.TextAlign = [Drawing.ContentAlignment]::TopLeft
    $label.Font = [Drawing.Font]::new("Segoe UI Semibold", 8.8)
    $label.ForeColor = $script:CurrentPalette.Muted
    $layout.Controls.Add($label, 0, 1)
    $ValueLabel.Value = $value
    return $panel
}
'''
new_card = r'''function New-NFSummaryCard {
    param([string]$Title, [string]$Subtitle, [ref]$ValueLabel)
    $panel = New-Object Windows.Forms.Panel
    $panel.Dock = [Windows.Forms.DockStyle]::Fill
    $panel.Margin = [Windows.Forms.Padding]::new(6)
    $panel.BackColor = $script:CurrentPalette.Card
    $panel.BorderStyle = [Windows.Forms.BorderStyle]::FixedSingle
    $layout = New-Object Windows.Forms.TableLayoutPanel
    $layout.Dock = [Windows.Forms.DockStyle]::Fill
    $layout.Padding = [Windows.Forms.Padding]::new(13, 8, 13, 7)
    $layout.RowCount = 3
    [void]$layout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 50)))
    [void]$layout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 27)))
    [void]$layout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 23)))
    $panel.Controls.Add($layout)
    $value = New-Object Windows.Forms.Label
    $value.Text = "0"
    $value.Dock = [Windows.Forms.DockStyle]::Fill
    $value.TextAlign = [Drawing.ContentAlignment]::BottomLeft
    $value.Font = [Drawing.Font]::new("Segoe UI Semibold", 21)
    $value.ForeColor = $script:CurrentPalette.Text
    $layout.Controls.Add($value, 0, 0)
    $label = New-Object Windows.Forms.Label
    $label.Text = $Title
    $label.Dock = [Windows.Forms.DockStyle]::Fill
    $label.TextAlign = [Drawing.ContentAlignment]::MiddleLeft
    $label.Font = [Drawing.Font]::new("Segoe UI Semibold", 8.6)
    $label.ForeColor = $script:CurrentPalette.Text
    $layout.Controls.Add($label, 0, 1)
    $hint = New-Object Windows.Forms.Label
    $hint.Text = $Subtitle
    $hint.Dock = [Windows.Forms.DockStyle]::Fill
    $hint.TextAlign = [Drawing.ContentAlignment]::TopLeft
    $hint.Font = [Drawing.Font]::new("Segoe UI", 7.9)
    $hint.ForeColor = $script:CurrentPalette.Muted
    $layout.Controls.Add($hint, 0, 2)
    $ValueLabel.Value = $value
    return $panel
}
'''
ui = replace_once(ui, old_card, new_card, 'cards de resumo')

start = ui.index('function New-ProductTabContent {')
end_marker = '\n$script:CurrentPalette = Get-NFEntradaPalette'
end = ui.index(end_marker, start)
new_product_tab = r'''function New-ProductTabContent {
    param(
        [Windows.Forms.TabPage]$Tab,
        [ref]$GridRef,
        [ref]$FilterRef,
        [ref]$StatusRef,
        [ref]$CodeRef,
        [ref]$CountRef
    )
    $layout = New-Object Windows.Forms.TableLayoutPanel
    $layout.Dock = [Windows.Forms.DockStyle]::Fill
    $layout.Padding = [Windows.Forms.Padding]::new(10)
    $layout.RowCount = 2
    [void]$layout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 50)))
    [void]$layout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 100)))
    $Tab.Controls.Add($layout)

    $filterPanel = New-Object Windows.Forms.TableLayoutPanel
    $filterPanel.Dock = [Windows.Forms.DockStyle]::Fill
    $filterPanel.ColumnCount = 7
    [void]$filterPanel.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Absolute, 72)))
    [void]$filterPanel.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 100)))
    [void]$filterPanel.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Absolute, 58)))
    [void]$filterPanel.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Absolute, 128)))
    [void]$filterPanel.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Absolute, 48)))
    [void]$filterPanel.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Absolute, 100)))
    [void]$filterPanel.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Absolute, 96)))
    $layout.Controls.Add($filterPanel, 0, 0)

    $searchLabel = New-Object Windows.Forms.Label
    $searchLabel.Text = "Pesquisar"
    $searchLabel.Dock = [Windows.Forms.DockStyle]::Fill
    $searchLabel.TextAlign = [Drawing.ContentAlignment]::MiddleLeft
    $searchLabel.ForeColor = $script:CurrentPalette.Muted
    $filterPanel.Controls.Add($searchLabel, 0, 0)

    $filter = New-Object Windows.Forms.TextBox
    $filter.Dock = [Windows.Forms.DockStyle]::Fill
    $filter.Margin = [Windows.Forms.Padding]::new(0, 9, 12, 9)
    $filter.BackColor = $script:CurrentPalette.Input
    $filter.ForeColor = $script:CurrentPalette.Text
    $filterPanel.Controls.Add($filter, 1, 0)

    $statusLabel = New-Object Windows.Forms.Label
    $statusLabel.Text = "Status"
    $statusLabel.Dock = [Windows.Forms.DockStyle]::Fill
    $statusLabel.TextAlign = [Drawing.ContentAlignment]::MiddleLeft
    $statusLabel.ForeColor = $script:CurrentPalette.Muted
    $filterPanel.Controls.Add($statusLabel, 2, 0)

    $statusFilter = New-Object Windows.Forms.ComboBox
    $statusFilter.DropDownStyle = [Windows.Forms.ComboBoxStyle]::DropDownList
    [void]$statusFilter.Items.AddRange(@("Todos", "Em estoque", "Encerrada", "Revisar"))
    $statusFilter.SelectedIndex = 0
    $statusFilter.Dock = [Windows.Forms.DockStyle]::Fill
    $statusFilter.Margin = [Windows.Forms.Padding]::new(0, 8, 12, 8)
    $statusFilter.BackColor = $script:CurrentPalette.Input
    $statusFilter.ForeColor = $script:CurrentPalette.Text
    $filterPanel.Controls.Add($statusFilter, 3, 0)

    $codeLabel = New-Object Windows.Forms.Label
    $codeLabel.Text = "Cód."
    $codeLabel.Dock = [Windows.Forms.DockStyle]::Fill
    $codeLabel.TextAlign = [Drawing.ContentAlignment]::MiddleLeft
    $codeLabel.ForeColor = $script:CurrentPalette.Muted
    $filterPanel.Controls.Add($codeLabel, 4, 0)

    $codeFilter = New-Object Windows.Forms.ComboBox
    $codeFilter.DropDownStyle = [Windows.Forms.ComboBoxStyle]::DropDownList
    [void]$codeFilter.Items.AddRange(@("Todos", "800", "100", "850", "Garantia"))
    $codeFilter.SelectedIndex = 0
    $codeFilter.Dock = [Windows.Forms.DockStyle]::Fill
    $codeFilter.Margin = [Windows.Forms.Padding]::new(0, 8, 10, 8)
    $codeFilter.BackColor = $script:CurrentPalette.Input
    $codeFilter.ForeColor = $script:CurrentPalette.Text
    $filterPanel.Controls.Add($codeFilter, 5, 0)

    $countLabel = New-Object Windows.Forms.Label
    $countLabel.Text = "0 de 0"
    $countLabel.Dock = [Windows.Forms.DockStyle]::Fill
    $countLabel.TextAlign = [Drawing.ContentAlignment]::MiddleRight
    $countLabel.ForeColor = $script:CurrentPalette.Muted
    $countLabel.Font = [Drawing.Font]::new("Segoe UI Semibold", 8.5)
    $filterPanel.Controls.Add($countLabel, 6, 0)

    $grid = New-NFGrid
    $idCol = New-Object Windows.Forms.DataGridViewTextBoxColumn
    $idCol.Name = "Id"; $idCol.Visible = $false
    [void]$grid.Columns.Add($idCol)
    Add-NFGridColumn $grid "Data" "DATA" 92
    Add-NFGridColumn $grid "QuantidadeNaNF" "QTD. NA NF" 105
    Add-NFGridColumn $grid "NFEntrada" "NF DE ENTRADA" 120
    Add-NFGridColumn $grid "QuantidadeSaldo" "SALDO" 88
    Add-NFGridColumn $grid "Codigo" "CÓD." 76
    Add-NFGridColumn $grid "Status" "STATUS" 100
    Add-NFGridColumn $grid "NFSaida" "NF DE SAÍDA / MOVIMENTAÇÕES" 280 $true
    $layout.Controls.Add($grid, 0, 1)
    $GridRef.Value = $grid
    $FilterRef.Value = $filter
    $StatusRef.Value = $statusFilter
    $CodeRef.Value = $codeFilter
    $CountRef.Value = $countLabel
}
'''
ui = ui[:start] + new_product_tab + ui[end:]

ui = replace_once(ui, '''[void]$root.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 72)))
[void]$root.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 100)))
[void]$root.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 100)))
[void]$root.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 30)))
''', '''[void]$root.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 78)))
[void]$root.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 112)))
[void]$root.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 100)))
[void]$root.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 46)))
''', 'proporções da tela')

ui = replace_once(ui, '$subtitle.Text = "Computador de Bordo V5 e Teclado V5 • mesma regra e mesmo modelo da planilha original"', '$subtitle.Text = "Saldos, NFs e exportação no mesmo padrão da planilha oficial"', 'subtítulo')

old_cards = '''$cards.Controls.Add((New-NFSummaryCard "SALDO TOTAL" ([ref]$saldoTotalValue)), 0, 0)
$cards.Controls.Add((New-NFSummaryCard "COMPUTADOR DE BORDO V5" ([ref]$computerBalanceValue)), 1, 0)
$cards.Controls.Add((New-NFSummaryCard "TECLADO V5" ([ref]$keyboardBalanceValue)), 2, 0)
$cards.Controls.Add((New-NFSummaryCard "NFs EM ABERTO" ([ref]$openNFsValue)), 3, 0)
'''
new_cards = '''$cards.Controls.Add((New-NFSummaryCard "SALDO TOTAL" "peças disponíveis" ([ref]$saldoTotalValue)), 0, 0)
$cards.Controls.Add((New-NFSummaryCard "COMPUTADOR DE BORDO V5" "saldo atual" ([ref]$computerBalanceValue)), 1, 0)
$cards.Controls.Add((New-NFSummaryCard "TECLADO V5" "saldo atual" ([ref]$keyboardBalanceValue)), 2, 0)
$cards.Controls.Add((New-NFSummaryCard "NFs EM ABERTO" "com saldo maior que zero" ([ref]$openNFsValue)), 3, 0)
'''
ui = replace_once(ui, old_cards, new_cards, 'cards principais')

old_refs = '''$computerGrid = $null; $computerFilter = $null
$keyboardGrid = $null; $keyboardFilter = $null
New-ProductTabContent -Tab $computerTab -GridRef ([ref]$computerGrid) -FilterRef ([ref]$computerFilter)
New-ProductTabContent -Tab $keyboardTab -GridRef ([ref]$keyboardGrid) -FilterRef ([ref]$keyboardFilter)
'''
new_refs = '''$computerGrid = $null; $computerFilter = $null; $computerStatusFilter = $null; $computerCodeFilter = $null; $computerCountLabel = $null
$keyboardGrid = $null; $keyboardFilter = $null; $keyboardStatusFilter = $null; $keyboardCodeFilter = $null; $keyboardCountLabel = $null
New-ProductTabContent -Tab $computerTab -GridRef ([ref]$computerGrid) -FilterRef ([ref]$computerFilter) -StatusRef ([ref]$computerStatusFilter) -CodeRef ([ref]$computerCodeFilter) -CountRef ([ref]$computerCountLabel)
New-ProductTabContent -Tab $keyboardTab -GridRef ([ref]$keyboardGrid) -FilterRef ([ref]$keyboardFilter) -StatusRef ([ref]$keyboardStatusFilter) -CodeRef ([ref]$keyboardCodeFilter) -CountRef ([ref]$keyboardCountLabel)
'''
ui = replace_once(ui, old_refs, new_refs, 'controles de filtro')

ui = replace_once(ui, '''$actionPanel.BackColor = $script:CurrentPalette.Background
$newButton = New-Object Windows.Forms.Button
$newButton.Text = "+ NOVO REGISTRO"; $newButton.Width = 135; $newButton.Height = 32; Set-NFButtonStyle $newButton "Primary"
$editButton = New-Object Windows.Forms.Button
$editButton.Text = "EDITAR"; $editButton.Width = 90; $editButton.Height = 32; Set-NFButtonStyle $editButton "Secondary"
$deleteButton = New-Object Windows.Forms.Button
$deleteButton.Text = "EXCLUIR"; $deleteButton.Width = 90; $deleteButton.Height = 32; Set-NFButtonStyle $deleteButton "Danger"
''', '''$actionPanel.BackColor = $script:CurrentPalette.Surface
$actionPanel.Padding = [Windows.Forms.Padding]::new(0, 3, 0, 0)
$newButton = New-Object Windows.Forms.Button
$newButton.Text = "+ NOVO REGISTRO"; $newButton.Width = 145; $newButton.Height = 34; Set-NFButtonStyle $newButton "Primary"
$editButton = New-Object Windows.Forms.Button
$editButton.Text = "EDITAR SELEÇÃO"; $editButton.Width = 125; $editButton.Height = 34; Set-NFButtonStyle $editButton "Secondary"
$deleteButton = New-Object Windows.Forms.Button
$deleteButton.Text = "EXCLUIR"; $deleteButton.Width = 95; $deleteButton.Height = 34; Set-NFButtonStyle $deleteButton "Danger"
''', 'barra de ações')

ui = replace_once(ui, '''$footerHost.Dock = [Windows.Forms.DockStyle]::Fill
$footerHost.ColumnCount = 2
''', '''$footerHost.Dock = [Windows.Forms.DockStyle]::Fill
$footerHost.BackColor = $script:CurrentPalette.Surface
$footerHost.Padding = [Windows.Forms.Padding]::new(8, 3, 8, 3)
$footerHost.ColumnCount = 2
''', 'rodapé')

old_events = '''$computerFilter.Add_TextChanged({ Refresh-NFProductGrid -Product $script:ComputerProduct -Grid $computerGrid -FilterBox $computerFilter })
$keyboardFilter.Add_TextChanged({ Refresh-NFProductGrid -Product $script:KeyboardProduct -Grid $keyboardGrid -FilterBox $keyboardFilter })
'''
new_events = '''$computerFilter.Add_TextChanged({ Refresh-NFProductGrid -Product $script:ComputerProduct -Grid $computerGrid -FilterBox $computerFilter -StatusFilter $computerStatusFilter -CodeFilter $computerCodeFilter -CountLabel $computerCountLabel })
$computerStatusFilter.Add_SelectedIndexChanged({ Refresh-NFProductGrid -Product $script:ComputerProduct -Grid $computerGrid -FilterBox $computerFilter -StatusFilter $computerStatusFilter -CodeFilter $computerCodeFilter -CountLabel $computerCountLabel })
$computerCodeFilter.Add_SelectedIndexChanged({ Refresh-NFProductGrid -Product $script:ComputerProduct -Grid $computerGrid -FilterBox $computerFilter -StatusFilter $computerStatusFilter -CodeFilter $computerCodeFilter -CountLabel $computerCountLabel })
$keyboardFilter.Add_TextChanged({ Refresh-NFProductGrid -Product $script:KeyboardProduct -Grid $keyboardGrid -FilterBox $keyboardFilter -StatusFilter $keyboardStatusFilter -CodeFilter $keyboardCodeFilter -CountLabel $keyboardCountLabel })
$keyboardStatusFilter.Add_SelectedIndexChanged({ Refresh-NFProductGrid -Product $script:KeyboardProduct -Grid $keyboardGrid -FilterBox $keyboardFilter -StatusFilter $keyboardStatusFilter -CodeFilter $keyboardCodeFilter -CountLabel $keyboardCountLabel })
$keyboardCodeFilter.Add_SelectedIndexChanged({ Refresh-NFProductGrid -Product $script:KeyboardProduct -Grid $keyboardGrid -FilterBox $keyboardFilter -StatusFilter $keyboardStatusFilter -CodeFilter $keyboardCodeFilter -CountLabel $keyboardCountLabel })
'''
ui = replace_once(ui, old_events, new_events, 'eventos de filtros')
write(ui_path, ui)

# ---------- Central ----------
central = read(central_path)
central = replace_once(central, '$script:AppVersion = "0.21.2"', '$script:AppVersion = "0.21.3"', 'versão da Central')
central = replace_once(central, '$script:NFEntradaVersion = "1.1.0"', '$script:NFEntradaVersion = "1.2.0"', 'versão NF na Central')
write(central_path, central)

# ---------- Contratos permanentes ----------
reg = read(reg_path)
reg = replace_once(reg,
'''    for fn in ("Initialize-NFEntradaDataStore", "Import-NFEntradaSourceWorkbook", "Read-NFEntradaStore", "Write-NFEntradaStore", "Ensure-NFEntradaStoreShape", "Add-NFEntradaHistoryEvent", "Get-NFEntradaHistory", "New-NFEntradaSafetyBackup", "Restore-NFEntradaSafetyBackup", "Add-NFEntradaRecord", "Update-NFEntradaRecord", "Remove-NFEntradaRecord", "Get-NFEntradaSummary", "Export-NFEntradaWorkbook"):
''',
'''    for fn in ("Initialize-NFEntradaDataStore", "Import-NFEntradaSourceWorkbook", "Read-NFEntradaStore", "Write-NFEntradaStore", "Ensure-NFEntradaStoreShape", "Add-NFEntradaHistoryEvent", "Get-NFEntradaHistory", "New-NFEntradaSafetyBackup", "Restore-NFEntradaSafetyBackup", "Get-NFEntradaRecordStatus", "Add-NFEntradaRecord", "Update-NFEntradaRecord", "Remove-NFEntradaRecord", "Get-NFEntradaSummary", "Export-NFEntradaWorkbook"):
''', 'contrato da função de status')
reg = replace_once(reg,
'''    for marker in ('Confirmar nova importação', 'backup da base e do modelo atuais', 'Set-NFStatus', '$editButton.Enabled = $hasSelection', '$deleteButton.Enabled = $hasSelection'):
        require(errors, nf, marker, "NF Entrada / operação segura")
''',
'''    for marker in ('Confirmar nova importação', 'backup da base e do modelo atuais', 'Set-NFStatus', '$editButton.Enabled = $hasSelection', '$deleteButton.Enabled = $hasSelection'):
        require(errors, nf, marker, "NF Entrada / operação segura")
    for marker in ('"Todos", "Em estoque", "Encerrada", "Revisar"', '"Todos", "800", "100", "850", "Garantia"', 'Add-NFGridColumn $grid "Status" "STATUS"', '$CountLabel.Text = "$shown de $($records.Count)"', 'EDITAR SELEÇÃO'):
        require(errors, nf, marker, "NF Entrada / clareza visual e filtros")
''', 'contratos de usabilidade')
write(reg_path, reg)

meta = {
    'version': '0.21.3',
    'buildRevision': 1,
    'releaseNotes': [
        'Etapa 2 do Controle de NF de Entrada: reorganiza a leitura da tela e melhora o conforto de uso sem alterar as regras da planilha.',
        'As abas de Computador de Bordo V5 e Teclado V5 ganham filtros combináveis por texto, status e código, além de contador visível de registros exibidos.',
        'Cada NF passa a mostrar uma coluna STATUS com Em estoque, Encerrada ou Revisar; a mesma classificação centraliza as cores já usadas pela tela.',
        'Os cards superiores ganham subtítulos operacionais para deixar claro o significado de cada número e recebem espaçamento mais confortável.',
        'A grade ganha títulos mais compactos para saldo e quantidade e amplia a área de NF de saída/movimentações.',
        'O rodapé e a barra de ações foram ampliados; Editar passa a aparecer como Editar seleção e permanece desabilitado sem linha selecionada.',
        'A regra de importação protegida, histórico auditável, backup automático e exportação fiel ao XLSX original permanece inalterada.',
        'Controle de NF de Entrada passa para v1.2.0; Gerenciador de Planilhas permanece v3.7.3 e Central de Manutenção permanece v0.6.1.',
        'A versão Estável permanece v0.20.2; a v0.21.3 é publicada somente no canal Teste.'
    ]
}
version_path.write_text(json.dumps(meta, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print('ETAPA 2 NF ENTRADA: transformação preparada para v0.21.3 / módulo v1.2.0')
