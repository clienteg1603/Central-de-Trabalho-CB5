param(
    [Int64]$EmbeddedParentHandle = 0,
    [switch]$HostedInCentral,
    [string]$HostTheme = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()
if (-not $HostedInCentral) { [System.Windows.Forms.Application]::SetCompatibleTextRenderingDefault($false) }

$script:IsInProcessHosted = [bool]$HostedInCentral
$script:HostedFormExport = $null
$script:HostedControlExport = $null
$script:ModuleRoot = $PSScriptRoot
$script:ModuleVersion = "2.5.0"
$script:CorePath = [IO.Path]::Combine($script:ModuleRoot, "NFEntrada.Core.ps1")
$script:DataDirectory = ""
$script:DatabasePath = ""
$script:Store = $null
$script:CurrentPalette = $null
$script:ComputerProduct = "COMPUTADOR DE BORDO V5"
$script:KeyboardProduct = "TECLADO V5"

if (-not [IO.File]::Exists($script:CorePath)) {
    [Windows.Forms.MessageBox]::Show(
        "O núcleo do Controle de NF de Entrada não foi encontrado.`r`n`r`n$($script:CorePath)",
        "Controle de NF de Entrada",
        [Windows.Forms.MessageBoxButtons]::OK,
        [Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
    return
}
. $script:CorePath
$script:DataDirectory = Get-NFEntradaDefaultDataDirectory

try {
    $script:DatabasePath = Initialize-NFEntradaDataStore -DataDirectory $script:DataDirectory
    $script:Store = Read-NFEntradaStore -Path $script:DatabasePath
}
catch {
    [Windows.Forms.MessageBox]::Show(
        "Não foi possível preparar a base do Controle de NF de Entrada.`r`n`r`n$($_.Exception.Message)",
        "Controle de NF de Entrada — base preservada",
        [Windows.Forms.MessageBoxButtons]::OK,
        [Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
    return
}

function Get-NFEntradaPalette {
    param([string]$Theme)
    switch ($Theme) {
        "Claro corporativo" {
            return [pscustomobject]@{
                Background = [Drawing.Color]::FromArgb(242, 246, 250)
                Surface = [Drawing.Color]::White
                Card = [Drawing.Color]::White
                Input = [Drawing.Color]::White
                Text = [Drawing.Color]::FromArgb(18, 32, 50)
                Muted = [Drawing.Color]::FromArgb(86, 104, 126)
                Border = [Drawing.Color]::FromArgb(210, 220, 231)
                Accent = [Drawing.Color]::FromArgb(47, 112, 230)
                AccentStrong = [Drawing.Color]::FromArgb(34, 93, 205)
                AccentText = [Drawing.Color]::White
                Success = [Drawing.Color]::FromArgb(21, 138, 96)
                SuccessBack = [Drawing.Color]::FromArgb(221, 247, 237)
                Warning = [Drawing.Color]::FromArgb(173, 105, 16)
                WarningBack = [Drawing.Color]::FromArgb(255, 244, 204)
                Danger = [Drawing.Color]::FromArgb(185, 28, 28)
                DangerBack = [Drawing.Color]::FromArgb(254, 226, 226)
            }
        }
        "Técnico industrial" {
            return [pscustomobject]@{
                Background = [Drawing.Color]::FromArgb(16, 20, 22)
                Surface = [Drawing.Color]::FromArgb(22, 28, 31)
                Card = [Drawing.Color]::FromArgb(29, 36, 39)
                Input = [Drawing.Color]::FromArgb(18, 24, 27)
                Text = [Drawing.Color]::FromArgb(244, 247, 248)
                Muted = [Drawing.Color]::FromArgb(170, 181, 184)
                Border = [Drawing.Color]::FromArgb(60, 72, 76)
                Accent = [Drawing.Color]::FromArgb(35, 179, 158)
                AccentStrong = [Drawing.Color]::FromArgb(27, 151, 134)
                AccentText = [Drawing.Color]::White
                Success = [Drawing.Color]::FromArgb(48, 207, 145)
                SuccessBack = [Drawing.Color]::FromArgb(17, 70, 55)
                Warning = [Drawing.Color]::FromArgb(244, 190, 74)
                WarningBack = [Drawing.Color]::FromArgb(77, 58, 15)
                Danger = [Drawing.Color]::FromArgb(239, 108, 102)
                DangerBack = [Drawing.Color]::FromArgb(78, 28, 26)
            }
        }
        "Alto contraste" {
            return [pscustomobject]@{
                Background = [Drawing.Color]::Black
                Surface = [Drawing.Color]::Black
                Card = [Drawing.Color]::FromArgb(18, 18, 18)
                Input = [Drawing.Color]::Black
                Text = [Drawing.Color]::White
                Muted = [Drawing.Color]::White
                Border = [Drawing.Color]::White
                Accent = [Drawing.Color]::Yellow
                AccentStrong = [Drawing.Color]::Yellow
                AccentText = [Drawing.Color]::Black
                Success = [Drawing.Color]::Lime
                SuccessBack = [Drawing.Color]::Black
                Warning = [Drawing.Color]::Yellow
                WarningBack = [Drawing.Color]::Black
                Danger = [Drawing.Color]::Red
                DangerBack = [Drawing.Color]::Black
            }
        }
        default {
            return [pscustomobject]@{
                Background = [Drawing.Color]::FromArgb(13, 20, 34)
                Surface = [Drawing.Color]::FromArgb(17, 27, 44)
                Card = [Drawing.Color]::FromArgb(23, 34, 54)
                Input = [Drawing.Color]::FromArgb(14, 25, 41)
                Text = [Drawing.Color]::FromArgb(244, 247, 251)
                Muted = [Drawing.Color]::FromArgb(170, 182, 200)
                Border = [Drawing.Color]::FromArgb(41, 55, 80)
                Accent = [Drawing.Color]::FromArgb(39, 196, 125)
                AccentStrong = [Drawing.Color]::FromArgb(29, 166, 105)
                AccentText = [Drawing.Color]::White
                Success = [Drawing.Color]::FromArgb(52, 211, 153)
                SuccessBack = [Drawing.Color]::FromArgb(15, 72, 57)
                Warning = [Drawing.Color]::FromArgb(251, 191, 36)
                WarningBack = [Drawing.Color]::FromArgb(73, 48, 15)
                Danger = [Drawing.Color]::FromArgb(239, 100, 100)
                DangerBack = [Drawing.Color]::FromArgb(78, 26, 31)
            }
        }
    }
}

function Set-NFStatus {
    param(
        [string]$Message,
        [ValidateSet("Normal", "Success", "Warning", "Error")][string]$Kind = "Normal"
    )
    if ($null -eq $footerStatus) { return }
    $footerStatus.Text = $Message
    switch ($Kind) {
        "Success" { $footerStatus.ForeColor = $script:CurrentPalette.Success }
        "Warning" { $footerStatus.ForeColor = $script:CurrentPalette.Warning }
        "Error" { $footerStatus.ForeColor = $script:CurrentPalette.Danger }
        default { $footerStatus.ForeColor = $script:CurrentPalette.Muted }
    }
}

function Set-NFButtonStyle {
    param([Windows.Forms.Button]$Button, [ValidateSet("Primary", "Secondary", "Danger")][string]$Kind = "Secondary")
    $Button.FlatStyle = [Windows.Forms.FlatStyle]::Flat
    $Button.Cursor = [Windows.Forms.Cursors]::Hand
    $Button.Font = [Drawing.Font]::new("Segoe UI Semibold", 9)
    switch ($Kind) {
        "Primary" {
            $Button.BackColor = $script:CurrentPalette.AccentStrong
            $Button.ForeColor = $script:CurrentPalette.AccentText
            $Button.FlatAppearance.BorderSize = 0
        }
        "Danger" {
            $Button.BackColor = $script:CurrentPalette.DangerBack
            $Button.ForeColor = $script:CurrentPalette.Danger
            $Button.FlatAppearance.BorderColor = $script:CurrentPalette.Danger
            $Button.FlatAppearance.BorderSize = 1
        }
        default {
            $Button.BackColor = $script:CurrentPalette.Card
            $Button.ForeColor = $script:CurrentPalette.Text
            $Button.FlatAppearance.BorderColor = $script:CurrentPalette.Border
            $Button.FlatAppearance.BorderSize = 1
        }
    }
}

function New-NFGrid {
    $grid = New-Object Windows.Forms.DataGridView
    $grid.Dock = [Windows.Forms.DockStyle]::Fill
    $grid.AllowUserToAddRows = $false
    $grid.AllowUserToDeleteRows = $false
    $grid.AllowUserToOrderColumns = $false
    $grid.AllowUserToResizeRows = $false
    $grid.ReadOnly = $true
    $grid.MultiSelect = $false
    $grid.SelectionMode = [Windows.Forms.DataGridViewSelectionMode]::FullRowSelect
    $grid.RowHeadersVisible = $false
    $grid.AutoGenerateColumns = $false
    $grid.BorderStyle = [Windows.Forms.BorderStyle]::FixedSingle
    $grid.BackgroundColor = $script:CurrentPalette.Surface
    $grid.GridColor = $script:CurrentPalette.Border
    $grid.EnableHeadersVisualStyles = $false
    $grid.ColumnHeadersDefaultCellStyle.BackColor = $script:CurrentPalette.Card
    $grid.ColumnHeadersDefaultCellStyle.ForeColor = $script:CurrentPalette.Text
    $grid.ColumnHeadersDefaultCellStyle.Font = [Drawing.Font]::new("Segoe UI Semibold", 9)
    $grid.DefaultCellStyle.BackColor = $script:CurrentPalette.Surface
    $grid.DefaultCellStyle.ForeColor = $script:CurrentPalette.Text
    $grid.DefaultCellStyle.SelectionBackColor = $script:CurrentPalette.AccentStrong
    $grid.DefaultCellStyle.SelectionForeColor = $script:CurrentPalette.AccentText
    $grid.DefaultCellStyle.Font = [Drawing.Font]::new("Segoe UI", 9)
    $grid.RowTemplate.Height = 27
    $grid.ColumnHeadersHeight = 30
    return $grid
}

function Add-NFGridColumn {
    param($Grid, [string]$Name, [string]$Header, [int]$Width, [bool]$Fill = $false)
    $col = New-Object Windows.Forms.DataGridViewTextBoxColumn
    $col.Name = $Name
    $col.HeaderText = $Header
    $col.SortMode = [Windows.Forms.DataGridViewColumnSortMode]::NotSortable
    $col.MinimumWidth = [Math]::Min($Width, 70)
    if ($Fill) { $col.AutoSizeMode = [Windows.Forms.DataGridViewAutoSizeColumnMode]::Fill; $col.MinimumWidth = [Math]::Max(130, $Width) }
    else { $col.Width = $Width }
    [void]$Grid.Columns.Add($col)
}

function Save-NFStore {
    Write-NFEntradaStore -Store $script:Store -Path $script:DatabasePath
}

function Get-SelectedProduct {
    if ($mainTabs.SelectedTab -eq $computerTab) { return $script:ComputerProduct }
    if ($mainTabs.SelectedTab -eq $keyboardTab) { return $script:KeyboardProduct }
    return ""
}

function Get-SelectedRecordId {
    param([Windows.Forms.DataGridView]$Grid)
    if ($null -eq $Grid -or $Grid.SelectedRows.Count -eq 0) { return 0 }
    try { return [int]$Grid.SelectedRows[0].Cells["Id"].Value } catch { return 0 }
}

function Find-NFRecordById {
    param([string]$Product, [int]$Id)
    foreach ($r in Get-NFEntradaProductRecords -Store $script:Store -Product $Product) {
        if ([int]$r.Id -eq $Id) { return $r }
    }
    return $null
}

function Select-NFRecordInGrid {
    param([Windows.Forms.DataGridView]$Grid, [int]$Id)
    if ($null -eq $Grid -or $Id -le 0) { return $false }
    foreach ($row in @($Grid.Rows)) {
        try {
            if ([int]$row.Cells["Id"].Value -ne $Id) { continue }
            $Grid.ClearSelection()
            $row.Selected = $true
            if ($row.Cells["NFEntrada"].Visible) { $Grid.CurrentCell = $row.Cells["NFEntrada"] }
            try { $Grid.FirstDisplayedScrollingRowIndex = $row.Index } catch {}
            return $true
        } catch {}
    }
    return $false
}

function Clear-NFCurrentProductFilters {
    $product = Get-SelectedProduct
    if ([string]::IsNullOrWhiteSpace($product)) { return }
    if ($product -eq $script:ComputerProduct) {
        $computerFilter.Clear()
        $computerCodeFilter.SelectedIndex = 0
        $computerStatusFilter.SelectedItem = "Em estoque"
        $computerFilter.Focus()
    }
    else {
        $keyboardFilter.Clear()
        $keyboardCodeFilter.SelectedIndex = 0
        $keyboardStatusFilter.SelectedItem = "Em estoque"
        $keyboardFilter.Focus()
    }
    Set-NFStatus "Filtros restaurados para Em estoque e Todos os códigos." "Normal"
}

function Export-NFCurrentProductViewToCsv {
    $product = Get-SelectedProduct
    if ([string]::IsNullOrWhiteSpace($product)) { return }
    $grid = if ($product -eq $script:ComputerProduct) { $computerGrid } else { $keyboardGrid }
    $baseName = if ($product -eq $script:ComputerProduct) { "Estoque-CB5" } else { "Estoque-Teclado-V5" }
    $title = if ($product -eq $script:ComputerProduct) { "Lista de Computador de Bordo CB5" } else { "Lista de Teclado V5" }
    Export-NFGridViewToCsv -Grid $grid -BaseName $baseName -Title $title
}

function Format-NFDate {
    param([string]$Text)
    $date = [DateTime]::MinValue
    if ([DateTime]::TryParseExact($Text, "yyyy-MM-dd", [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::None, [ref]$date)) {
        return $date.ToString("dd/MM/yyyy")
    }
    return $Text
}

function Refresh-NFProductGrid {
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

function Format-NFHistoryDate {
    param([string]$Text)
    $date = [DateTime]::MinValue
    if ([DateTime]::TryParse($Text, [ref]$date)) { return $date.ToString("dd/MM/yyyy HH:mm:ss") }
    return $Text
}

function Refresh-NFMovements {
    if ($null -eq $movementGrid) { return }
    $filter = if ($null -ne $movementFilter) { ([string]$movementFilter.Text).Trim().ToLowerInvariant() } else { "" }
    $productFilter = if ($null -ne $movementProductFilter -and $movementProductFilter.SelectedIndex -gt 0) { [string]$movementProductFilter.SelectedItem } else { "Todos" }
    $periodFilter = if ($null -ne $movementPeriodFilter -and $movementPeriodFilter.SelectedIndex -gt 0) { [string]$movementPeriodFilter.SelectedItem } else { "Todos" }
    $items = @(Get-NFEntradaMovements -Store $script:Store)
    $movementGrid.Rows.Clear()
    $shown = 0
    $qtyShown = 0
    $reversedShown = 0
    $today = [DateTime]::Today
    foreach ($item in $items) {
        $when = [DateTime]::MinValue
        $hasDate = [DateTime]::TryParse([string]$item.DataHora, [ref]$when)
        if ($periodFilter -ne "Todos") {
            if (-not $hasDate) { continue }
            if ($periodFilter -eq "Hoje" -and $when -lt $today) { continue }
            if ($periodFilter -eq "Últimos 7 dias" -and $when -lt $today.AddDays(-6)) { continue }
            if ($periodFilter -eq "Últimos 30 dias" -and $when -lt $today.AddDays(-29)) { continue }
        }
        $displayProduct = Get-NFEntradaProductDisplayName ([string]$item.Produto)
        if ($productFilter -ne "Todos" -and $displayProduct -ne $productFilter) { continue }
        $status = Get-NFEntradaMovementStatus -Movement $item
        $search = (($displayProduct + " " + [string]$item.NFEntrada + " " + [string]$item.Referencia + " " + $status + " " + [string]$item.MotivoEstorno)).ToLowerInvariant()
        if (-not [string]::IsNullOrWhiteSpace($filter) -and -not $search.Contains($filter)) { continue }
        $rowIndex = $movementGrid.Rows.Add(
            [string]$item.Id,
            [string]$item.Produto,
            (Format-NFHistoryDate ([string]$item.DataHora)),
            $displayProduct,
            [string]$item.NFEntrada,
            [int]$item.Quantidade,
            [int]$item.SaldoAntes,
            [int]$item.SaldoDepois,
            $status,
            [string]$item.Referencia
        )
        $shown++
        if ($status -eq "Estornada") {
            $reversedShown++
            $row = $movementGrid.Rows[$rowIndex]
            $row.DefaultCellStyle.BackColor = $script:CurrentPalette.DangerBack
            $row.DefaultCellStyle.ForeColor = $script:CurrentPalette.Danger
        } else { $qtyShown += [int]$item.Quantidade }
    }
    $movementCountLabel.Text = "$shown movimentação(ões) • $qtyShown peça(s) ativas • $reversedShown estornada(s) • período: $periodFilter • Ctrl+Z estorna a selecionada"
    $movementGrid.ClearSelection()
    $movementOpenButton.Enabled = $false
    if ($null -ne $movementReverseButton) { $movementReverseButton.Enabled = $false }
}

function Open-NFFromMovement {
    if ($movementGrid.SelectedRows.Count -eq 0) { return }
    $row = $movementGrid.SelectedRows[0]
    $product = [string]$row.Cells["MovementProductKey"].Value
    $nf = [string]$row.Cells["MovementNF"].Value
    if ($product -eq $script:ComputerProduct) {
        $computerStatusFilter.SelectedIndex = 0
        $computerFilter.Text = $nf
        $mainTabs.SelectedTab = $computerTab
        $computerFilter.Focus()
    }
    elseif ($product -eq $script:KeyboardProduct) {
        $keyboardStatusFilter.SelectedIndex = 0
        $keyboardFilter.Text = $nf
        $mainTabs.SelectedTab = $keyboardTab
        $keyboardFilter.Focus()
    }
}

function Reverse-NFMovementFromUI {
    if ($movementGrid.SelectedRows.Count -eq 0) { return }
    $id = [string]$movementGrid.SelectedRows[0].Cells["MovementId"].Value
    $movement = Get-NFEntradaMovementById -Store $script:Store -MovementId $id
    if ($null -eq $movement) { return }
    if ((Get-NFEntradaMovementStatus -Movement $movement) -eq "Estornada") {
        [Windows.Forms.MessageBox]::Show("Esta saída já foi estornada e continua visível para auditoria.", "Controle de NF de Entrada", 0, 64) | Out-Null
        return
    }
    $answer = [Windows.Forms.MessageBox]::Show(
        "Estornar a saída de $([int]$movement.Quantidade) peça(s) da NF $([string]$movement.NFEntrada)?`r`n`r`nA quantidade voltará para o saldo. A movimentação original não será apagada e o estorno ficará registrado no Histórico.",
        "Confirmar estorno de saída",
        [Windows.Forms.MessageBoxButtons]::YesNo,
        [Windows.Forms.MessageBoxIcon]::Warning
    )
    if ($answer -ne [Windows.Forms.DialogResult]::Yes) { return }
    try {
        $result = Register-NFEntradaReversal -Store $script:Store -MovementId $id -Motivo "Correção operacional"
        Save-NFStore
        Refresh-NFAll
        Refresh-NFMovements
        Set-NFStatus ("Saída estornada. Saldo da NF " + [string]$result.Record.NFEntrada + ": " + [string]$result.Record.QuantidadeSaldo) "Warning"
    }
    catch { Set-NFStatus $_.Exception.Message "Error"; [Windows.Forms.MessageBox]::Show($_.Exception.Message, "Falha ao estornar saída", 0, 16) | Out-Null }
}

function ConvertTo-NFCsvField {
    param($Value)
    $text = if ($null -eq $Value) { "" } else { [string]$Value }
    return '"' + $text.Replace('"', '""') + '"'
}

function Export-NFGridViewToCsv {
    param(
        [Parameter(Mandatory = $true)][Windows.Forms.DataGridView]$Grid,
        [Parameter(Mandatory = $true)][string]$BaseName,
        [Parameter(Mandatory = $true)][string]$Title
    )
    if ($null -eq $Grid -or $Grid.Rows.Count -eq 0) {
        [Windows.Forms.MessageBox]::Show("Não há linhas visíveis para exportar.", "Controle de NF de Entrada", 0, 64) | Out-Null
        return
    }
    $columns = @($Grid.Columns | Where-Object { $_.Visible } | Sort-Object DisplayIndex)
    if ($columns.Count -eq 0) { return }

    $dialog = New-Object Windows.Forms.SaveFileDialog
    $dialog.Title = "Exportar $Title"
    $dialog.Filter = "Arquivo CSV (*.csv)|*.csv"
    $dialog.AddExtension = $true
    $dialog.DefaultExt = "csv"
    $dialog.FileName = $BaseName + "-" + [DateTime]::Now.ToString("yyyy-MM-dd-HHmm") + ".csv"
    try {
        if ($dialog.ShowDialog() -ne [Windows.Forms.DialogResult]::OK) { return }
        $lines = New-Object 'System.Collections.Generic.List[string]'
        $header = @($columns | ForEach-Object { ConvertTo-NFCsvField $_.HeaderText }) -join ";"
        [void]$lines.Add($header)
        foreach ($row in @($Grid.Rows)) {
            if ($row.IsNewRow) { continue }
            $values = foreach ($column in $columns) {
                ConvertTo-NFCsvField $row.Cells[$column.Index].Value
            }
            [void]$lines.Add((@($values) -join ";"))
        }
        $encoding = New-Object System.Text.UTF8Encoding($true)
        [IO.File]::WriteAllText($dialog.FileName, (($lines -join "`r`n") + "`r`n"), $encoding)
        Set-NFStatus ("$Title exportado(s) para " + $dialog.FileName) "Success"
        [Windows.Forms.MessageBox]::Show(
            "$Title exportado(s) com sucesso.`r`n`r`n$($dialog.FileName)`r`n`r`nForam exportadas apenas as linhas que estão visíveis com os filtros atuais.",
            "Exportação concluída",
            [Windows.Forms.MessageBoxButtons]::OK,
            [Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
    }
    catch {
        Set-NFStatus ("Falha ao exportar ${Title}: " + $_.Exception.Message) "Error"
        [Windows.Forms.MessageBox]::Show($_.Exception.Message, "Falha ao exportar CSV", 0, 16) | Out-Null
    }
    finally {
        $dialog.Dispose()
    }
}

function Get-NFHistoryEventById {
    param([string]$Id)
    foreach ($event in Get-NFEntradaHistory -Store $script:Store) {
        if ([string]$event.Id -eq $Id) { return $event }
    }
    return $null
}

function Convert-NFSnapshotToText {
    param($Snapshot)
    if ($null -eq $Snapshot) { return "—" }
    return @(
        "Data: " + (Format-NFDate ([string]$Snapshot.Data)),
        "Quantidade na NF: " + [string]$Snapshot.QuantidadeNaNF,
        "NF de Entrada: " + [string]$Snapshot.NFEntrada,
        "Saldo: " + [string]$Snapshot.QuantidadeSaldo,
        "Código: " + [string]$Snapshot.Codigo,
        "NF de Saída / movimentações: " + [string]$Snapshot.NFSaida
    ) -join "`r`n"
}

function Refresh-NFHistory {
    if ($null -eq $historyGrid) { return }
    $filter = if ($null -ne $historyFilter) { ([string]$historyFilter.Text).Trim().ToLowerInvariant() } else { "" }
    $type = if ($null -ne $historyTypeFilter -and $historyTypeFilter.SelectedIndex -gt 0) { [string]$historyTypeFilter.SelectedItem } else { "Todos" }
    $period = if ($null -ne $historyPeriodFilter -and $historyPeriodFilter.SelectedIndex -gt 0) { [string]$historyPeriodFilter.SelectedItem } else { "Todos" }
    $events = @(Get-NFEntradaHistory -Store $script:Store)
    $shown = 0
    $today = [DateTime]::Today
    $historyGrid.Rows.Clear()
    foreach ($event in $events) {
        $when = [DateTime]::MinValue
        $hasDate = [DateTime]::TryParse([string]$event.DataHora, [ref]$when)
        if ($period -ne "Todos") {
            if (-not $hasDate) { continue }
            if ($period -eq "Hoje" -and $when -lt $today) { continue }
            if ($period -eq "Últimos 7 dias" -and $when -lt $today.AddDays(-6)) { continue }
            if ($period -eq "Últimos 30 dias" -and $when -lt $today.AddDays(-29)) { continue }
        }
        $label = switch ([string]$event.Tipo) {
            "Adicao" { "Adição" }
            "Edicao" { "Edição" }
            "Exclusao" { "Exclusão" }
            "Importacao" { "Importação" }
            "RestauracaoBackup" { "Restauração" }
            "Saida" { "Saída" }
            "EstornoSaida" { "Estorno de saída" }
            "Exportacao" { "Exportação" }
            default { [string]$event.Tipo }
        }
        if ($type -ne "Todos" -and $label -ne $type) { continue }
        $search = (($label + " " + (Get-NFEntradaProductDisplayName ([string]$event.Produto)) + " " + [string]$event.NFEntrada + " " + [string]$event.Detalhes)).ToLowerInvariant()
        if (-not [string]::IsNullOrWhiteSpace($filter) -and -not $search.Contains($filter)) { continue }
        [void]$historyGrid.Rows.Add([string]$event.Id, (Format-NFHistoryDate ([string]$event.DataHora)), $label, (Get-NFEntradaProductDisplayName ([string]$event.Produto)), [string]$event.NFEntrada, [string]$event.Detalhes)
        $shown++
    }
    $historyCountLabel.Text = "$shown de $($events.Count) • $period"
    $historyGrid.ClearSelection()
    $historyDetailsButton.Enabled = $false
}

function Show-NFHistoryDetails {
    if ($historyGrid.SelectedRows.Count -eq 0) { return }
    $id = [string]$historyGrid.SelectedRows[0].Cells["HistoryId"].Value
    $event = Get-NFHistoryEventById -Id $id
    if ($null -eq $event) { return }
    $dialog = New-Object Windows.Forms.Form
    $dialog.Text = "Detalhes do histórico"
    $dialog.StartPosition = [Windows.Forms.FormStartPosition]::CenterParent
    $dialog.Size = [Drawing.Size]::new(760, 590)
    $dialog.MinimumSize = [Drawing.Size]::new(680, 520)
    $dialog.BackColor = $script:CurrentPalette.Background
    $dialog.ForeColor = $script:CurrentPalette.Text
    $layout = New-Object Windows.Forms.TableLayoutPanel
    $layout.Dock = [Windows.Forms.DockStyle]::Fill
    $layout.Padding = [Windows.Forms.Padding]::new(18)
    $layout.RowCount = 4
    [void]$layout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 74)))
    [void]$layout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 50)))
    [void]$layout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 50)))
    [void]$layout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 44)))
    $dialog.Controls.Add($layout)
    $headerText = New-Object Windows.Forms.Label
    $headerText.Text = (Format-NFHistoryDate ([string]$event.DataHora)) + "  •  " + [string]$event.Tipo + "`r`nNF: " + [string]$event.NFEntrada + "    Produto: " + (Get-NFEntradaProductDisplayName ([string]$event.Produto)) + $(if ([string]::IsNullOrWhiteSpace([string]$event.Detalhes)) { "" } else { "`r`n" + [string]$event.Detalhes })
    $headerText.Dock = [Windows.Forms.DockStyle]::Fill
    $headerText.ForeColor = $script:CurrentPalette.Text
    $layout.Controls.Add($headerText, 0, 0)
    foreach ($item in @(@("ANTES", $event.Antes), @("DEPOIS", $event.Depois))) {
        $box = New-Object Windows.Forms.GroupBox
        $box.Text = $item[0]
        $box.Dock = [Windows.Forms.DockStyle]::Fill
        $box.ForeColor = $script:CurrentPalette.Text
        $text = New-Object Windows.Forms.TextBox
        $text.Multiline = $true
        $text.ReadOnly = $true
        $text.ScrollBars = [Windows.Forms.ScrollBars]::Vertical
        $text.Dock = [Windows.Forms.DockStyle]::Fill
        $text.BackColor = $script:CurrentPalette.Input
        $text.ForeColor = $script:CurrentPalette.Text
        $text.Text = Convert-NFSnapshotToText $item[1]
        $box.Controls.Add($text)
        $layout.Controls.Add($box, 0, $(if ($item[0] -eq "ANTES") { 1 } else { 2 }))
    }
    $close = New-Object Windows.Forms.Button
    $close.Text = "FECHAR"
    $close.Width = 100
    $close.DialogResult = [Windows.Forms.DialogResult]::OK
    Set-NFButtonStyle $close "Secondary"
    $layout.Controls.Add($close, 0, 3)
    $dialog.AcceptButton = $close
    [void]$dialog.ShowDialog()
    $dialog.Dispose()
}

function Show-NFReviewIssues {
    $items = @(Get-NFEntradaReviewItems -Store $script:Store)
    if ($items.Count -eq 0) {
        [Windows.Forms.MessageBox]::Show(
            "Nenhuma pendência de conferência foi encontrada na base atual.",
            "Conferência do Controle de NF",
            [Windows.Forms.MessageBoxButtons]::OK,
            [Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
        return
    }

    $dialog = New-Object Windows.Forms.Form
    $dialog.Text = "Pendências de conferência"
    $dialog.StartPosition = [Windows.Forms.FormStartPosition]::CenterParent
    $dialog.Size = [Drawing.Size]::new(900, 540)
    $dialog.MinimumSize = [Drawing.Size]::new(760, 460)
    $dialog.BackColor = $script:CurrentPalette.Background
    $dialog.ForeColor = $script:CurrentPalette.Text

    $layout = New-Object Windows.Forms.TableLayoutPanel
    $layout.Dock = [Windows.Forms.DockStyle]::Fill
    $layout.Padding = [Windows.Forms.Padding]::new(14)
    $layout.RowCount = 3
    [void]$layout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 48)))
    [void]$layout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 100)))
    [void]$layout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 46)))
    $dialog.Controls.Add($layout)

    $info = New-Object Windows.Forms.Label
    $info.Text = "$($items.Count) registro(s) precisam de conferência. Selecione uma linha e use ABRIR NF para ir ao registro."
    $info.Dock = [Windows.Forms.DockStyle]::Fill
    $info.TextAlign = [Drawing.ContentAlignment]::MiddleLeft
    $info.ForeColor = $script:CurrentPalette.Muted
    $layout.Controls.Add($info, 0, 0)

    $reviewGrid = New-NFGrid
    $productKey = New-Object Windows.Forms.DataGridViewTextBoxColumn
    $productKey.Name = "ReviewProductKey"; $productKey.Visible = $false; [void]$reviewGrid.Columns.Add($productKey)
    $recordKey = New-Object Windows.Forms.DataGridViewTextBoxColumn
    $recordKey.Name = "ReviewRecordId"; $recordKey.Visible = $false; [void]$reviewGrid.Columns.Add($recordKey)
    Add-NFGridColumn $reviewGrid "ReviewProduct" "PRODUTO" 190
    Add-NFGridColumn $reviewGrid "ReviewNF" "NF DE ENTRADA" 120
    Add-NFGridColumn $reviewGrid "ReviewQty" "QTD. NA NF" 90
    Add-NFGridColumn $reviewGrid "ReviewBalance" "SALDO" 80
    Add-NFGridColumn $reviewGrid "ReviewCode" "CÓD." 70
    Add-NFGridColumn $reviewGrid "ReviewIssue" "PENDÊNCIA" 240 $true
    foreach ($item in $items) {
        [void]$reviewGrid.Rows.Add(
            [string]$item.Produto,
            [int]$item.RegistroId,
            (Get-NFEntradaProductDisplayName ([string]$item.Produto)),
            [string]$item.NFEntrada,
            [int]$item.QuantidadeNaNF,
            [int]$item.QuantidadeSaldo,
            [string]$item.Codigo,
            [string]$item.Problema
        )
    }
    $reviewGrid.ClearSelection()
    $layout.Controls.Add($reviewGrid, 0, 1)

    $buttons = New-Object Windows.Forms.FlowLayoutPanel
    $buttons.Dock = [Windows.Forms.DockStyle]::Fill
    $buttons.FlowDirection = [Windows.Forms.FlowDirection]::RightToLeft
    $close = New-Object Windows.Forms.Button
    $close.Text = "FECHAR"; $close.Width = 100; $close.Height = 32; $close.DialogResult = [Windows.Forms.DialogResult]::Cancel
    Set-NFButtonStyle $close "Secondary"
    $open = New-Object Windows.Forms.Button
    $open.Text = "ABRIR NF"; $open.Width = 110; $open.Height = 32; $open.Enabled = $false
    Set-NFButtonStyle $open "Primary"
    $buttons.Controls.Add($close); $buttons.Controls.Add($open)
    $layout.Controls.Add($buttons, 0, 2)
    $dialog.CancelButton = $close

    $reviewGrid.Add_SelectionChanged({ $open.Enabled = ($reviewGrid.SelectedRows.Count -gt 0) })
    $open.Add_Click({
        if ($reviewGrid.SelectedRows.Count -eq 0) { return }
        $dialog.Tag = [pscustomobject]@{
            Produto = [string]$reviewGrid.SelectedRows[0].Cells["ReviewProductKey"].Value
            NFEntrada = [string]$reviewGrid.SelectedRows[0].Cells["ReviewNF"].Value
        }
        $dialog.DialogResult = [Windows.Forms.DialogResult]::OK
        $dialog.Close()
    })
    $reviewGrid.Add_CellDoubleClick({
        if ($_.RowIndex -lt 0) { return }
        $dialog.Tag = [pscustomobject]@{
            Produto = [string]$reviewGrid.Rows[$_.RowIndex].Cells["ReviewProductKey"].Value
            NFEntrada = [string]$reviewGrid.Rows[$_.RowIndex].Cells["ReviewNF"].Value
        }
        $dialog.DialogResult = [Windows.Forms.DialogResult]::OK
        $dialog.Close()
    })

    $result = $dialog.ShowDialog()
    $target = $dialog.Tag
    $dialog.Dispose()
    if ($result -ne [Windows.Forms.DialogResult]::OK -or $null -eq $target) { return }

    if ([string]$target.Produto -eq $script:ComputerProduct) {
        $computerStatusFilter.SelectedIndex = 0
        $computerFilter.Text = [string]$target.NFEntrada
        $mainTabs.SelectedTab = $computerTab
        $computerFilter.Focus()
    }
    elseif ([string]$target.Produto -eq $script:KeyboardProduct) {
        $keyboardStatusFilter.SelectedIndex = 0
        $keyboardFilter.Text = [string]$target.NFEntrada
        $mainTabs.SelectedTab = $keyboardTab
        $keyboardFilter.Focus()
    }
}

function Show-NFExportReadiness {
    $state = Get-NFEntradaExportReadiness -Store $script:Store -DataDirectory $script:DataDirectory
    $model = if ($state.ModeloDisponivel) { "OK — modelo oficial disponível" } else { "AUSENTE — importe a planilha oficial novamente" }
    $statusText = switch ([string]$state.Situacao) {
        "PRONTO" { "A exportação está pronta. O modelo oficial comporta os registros atuais e não há pendências de conferência." }
        "REVISAR" { "A exportação pode ser feita, mas existem pendências de conferência. O programa pedirá confirmação antes de gerar o Excel." }
        default { "A exportação está bloqueada para não quebrar o formato oficial. Corrija o motivo indicado antes de tentar novamente." }
    }
    $details = @(
        "Situação: " + [string]$state.Situacao,
        "Modelo: " + $model,
        "Computador de bordo CB5: " + [string]$state.RegistrosComputador + " de " + [string]$state.CapacidadePorProduto + " registros (restam " + [string]$state.RestanteComputador + ")",
        "Teclado V5: " + [string]$state.RegistrosTeclado + " de " + [string]$state.CapacidadePorProduto + " registros (restam " + [string]$state.RestanteTeclado + ")",
        "Pendências para revisar: " + [string]$state.Pendencias,
        "",
        $statusText
    ) -join "`r`n"
    $icon = if ($state.Situacao -eq "PRONTO") { [Windows.Forms.MessageBoxIcon]::Information } elseif ($state.Situacao -eq "REVISAR") { [Windows.Forms.MessageBoxIcon]::Warning } else { [Windows.Forms.MessageBoxIcon]::Error }
    [Windows.Forms.MessageBox]::Show($details, "Conferir exportação", [Windows.Forms.MessageBoxButtons]::OK, $icon) | Out-Null
}

function Show-NFIntegrityReport {
    try {
        $report = Get-NFEntradaIntegrityReport -Store $script:Store -DataDirectory $script:DataDirectory
        $lines = [Collections.Generic.List[string]]::new()
        [void]$lines.Add("Situação: " + [string]$report.Situacao)
        [void]$lines.Add("Registros: " + [string]$report.Registros + " • Pendências: " + [string]$report.Pendencias + " • Duplicidades: " + [string]$report.Duplicidades)
        [void]$lines.Add("Backups: " + [string]$report.Backups + " • Automáticos: " + [string]$report.BackupsAutomaticos + " • Inválidos: " + [string]$report.BackupsInvalidos)
        [void]$lines.Add("")
        foreach ($error in @($report.Erros)) { [void]$lines.Add("ERRO • " + [string]$error) }
        foreach ($warning in @($report.Avisos)) { [void]$lines.Add("ATENÇÃO • " + [string]$warning) }
        if (@($report.Erros).Count -eq 0 -and @($report.Avisos).Count -eq 0) {
            [void]$lines.Add("Nenhuma inconsistência foi encontrada na base, no modelo e nos backups atuais.")
        }
        $icon = if ($report.Situacao -eq "ERRO") { [Windows.Forms.MessageBoxIcon]::Error } elseif ($report.Situacao -eq "ATENÇÃO") { [Windows.Forms.MessageBoxIcon]::Warning } else { [Windows.Forms.MessageBoxIcon]::Information }
        [Windows.Forms.MessageBox]::Show(($lines -join "`r`n"), "Verificação de integridade", [Windows.Forms.MessageBoxButtons]::OK, $icon) | Out-Null
        $statusKind = "Success"
        if ($report.Situacao -eq "ERRO") { $statusKind = "Error" }
        elseif ($report.Situacao -eq "ATENÇÃO") { $statusKind = "Warning" }
        Set-NFStatus ("Integridade: " + [string]$report.Situacao + " • " + [string]$report.Erros.Count + " erro(s) • " + [string]$report.Avisos.Count + " aviso(s)") $statusKind
    }
    catch {
        Set-NFStatus $_.Exception.Message "Error"
        [Windows.Forms.MessageBox]::Show($_.Exception.Message, "Falha na verificação de integridade", 0, 16) | Out-Null
    }
}

function Refresh-NFBackups {
    if ($null -eq $backupGrid) { return }
    $items = @(Get-NFEntradaSafetyBackups -DataDirectory $script:DataDirectory)
    $backupGrid.Rows.Clear()
    foreach ($item in $items) {
        $content = if ($item.TemBase -and $item.TemModelo) { "Base + modelo" } elseif ($item.TemBase) { "Somente base" } else { "Incompleto" }
        [void]$backupGrid.Rows.Add([string]$item.Directory, $item.DataHora.ToString("dd/MM/yyyy HH:mm:ss"), [string]$item.Motivo, [int]$item.Registros, $content, [string]$item.Situacao)
    }
    $backupCountLabel.Text = "$($items.Count) backup(s) disponível(is)"
    $backupGrid.ClearSelection()
    $restoreBackupButton.Enabled = $false
}

function New-NFManualBackupFromUI {
    try {
        $backup = New-NFEntradaSafetyBackup -DataDirectory $script:DataDirectory -Reason "Manual"
        if ($null -eq $backup) { throw "Ainda não há base ou modelo para criar backup." }
        Refresh-NFBackups
        Set-NFStatus "Backup manual criado com sucesso." "Success"
        [Windows.Forms.MessageBox]::Show("Backup criado com sucesso.`r`n`r`nA base e o modelo atual foram preservados em uma cópia de segurança interna.", "Controle de NF de Entrada", 0, 64) | Out-Null
    }
    catch { Set-NFStatus $_.Exception.Message "Error"; [Windows.Forms.MessageBox]::Show($_.Exception.Message, "Falha ao criar backup", 0, 16) | Out-Null }
}

function Restore-NFBackupFromUI {
    if ($backupGrid.SelectedRows.Count -eq 0) { return }
    $directory = [string]$backupGrid.SelectedRows[0].Cells["BackupDirectory"].Value
    $dateText = [string]$backupGrid.SelectedRows[0].Cells["BackupDate"].Value
    $answer = [Windows.Forms.MessageBox]::Show(
        "Restaurar o backup de $dateText?`r`n`r`nO estado atual será copiado automaticamente para um novo backup antes da restauração. Depois da confirmação, a base ativa e o modelo Excel passarão a refletir o backup selecionado.",
        "Confirmar restauração de backup",
        [Windows.Forms.MessageBoxButtons]::YesNo,
        [Windows.Forms.MessageBoxIcon]::Warning
    )
    if ($answer -ne [Windows.Forms.DialogResult]::Yes) { return }
    try {
        Set-NFStatus "Restaurando backup e protegendo o estado atual..." "Warning"
        $result = Restore-NFEntradaBackupSet -BackupDirectory $directory -DataDirectory $script:DataDirectory
        $script:DatabasePath = [string]$result.StorePath
        $script:Store = $result.Store
        Refresh-NFAll
        Set-NFStatus "Backup restaurado com sucesso; estado anterior também foi preservado." "Success"
        [Windows.Forms.MessageBox]::Show("Backup restaurado com sucesso.`r`n`r`nO estado que estava ativo antes da restauração também foi salvo automaticamente, permitindo recuperação caso seja necessário.", "Controle de NF de Entrada", 0, 64) | Out-Null
    }
    catch { Set-NFStatus $_.Exception.Message "Error"; [Windows.Forms.MessageBox]::Show($_.Exception.Message, "Falha ao restaurar backup", 0, 16) | Out-Null }
}

function Refresh-NFSummary {
    $summary = Get-NFEntradaSummary -Store $script:Store
    $operational = Get-NFEntradaOperationalMetrics -Store $script:Store
    $exportState = Get-NFEntradaExportReadiness -Store $script:Store -DataDirectory $script:DataDirectory
    $saldoTotalValue.Text = ([int]$summary.SaldoTotal).ToString("N0")
    $computerBalanceValue.Text = ([int]$summary.Produtos[$script:ComputerProduct].Saldo).ToString("N0")
    $keyboardBalanceValue.Text = ([int]$summary.Produtos[$script:KeyboardProduct].Saldo).ToString("N0")
    $openNFsValue.Text = ([int]$summary.NFsAbertas).ToString("N0")
    $movementTodayValue.Text = ([int]$operational.MovimentacoesHoje).ToString("N0")
    $piecesTodayValue.Text = ([int]$operational.PecasSaidaHoje).ToString("N0")
    $piecesSevenValue.Text = ([int]$operational.PecasSaida7Dias).ToString("N0")
    $reviewIssuesValue.Text = ([int]$operational.Pendencias).ToString("N0")
    $reviewIssuesValue.ForeColor = if ([int]$operational.Pendencias -eq 0) { $script:CurrentPalette.Success } else { $script:CurrentPalette.Danger }
    $exportStatusValue.Text = [string]$exportState.Situacao
    $exportStatusValue.ForeColor = if ($exportState.Situacao -eq "PRONTO") { $script:CurrentPalette.Success } elseif ($exportState.Situacao -eq "REVISAR") { $script:CurrentPalette.Warning } else { $script:CurrentPalette.Danger }
    if ($null -ne $operational.UltimaMovimentacaoEm) {
        $lastMovementValue.Text = ([DateTime]$operational.UltimaMovimentacaoEm).ToString("dd/MM HH:mm") + " • NF " + [string]$operational.UltimaMovimentacaoNF
    }
    else {
        $lastMovementValue.Text = "Nenhuma movimentação registrada"
    }

    $productSummaryGrid.Rows.Clear()
    [void]$productSummaryGrid.Rows.Add("Computador de bordo CB5", [int]$summary.Produtos[$script:ComputerProduct].NFsAbertas, [int]$summary.Produtos[$script:ComputerProduct].Saldo)
    [void]$productSummaryGrid.Rows.Add("Teclado V5", [int]$summary.Produtos[$script:KeyboardProduct].NFsAbertas, [int]$summary.Produtos[$script:KeyboardProduct].Saldo)
    [void]$productSummaryGrid.Rows.Add("TOTAL", [int]$summary.NFsAbertas, [int]$summary.SaldoTotal)

    $codeSummaryGrid.Rows.Clear()
    foreach ($code in @("800", "100", "850", "Garantia")) {
        $item = $summary.Codigos[$code]
        [void]$codeSummaryGrid.Rows.Add($code, [int]$item.Computador, [int]$item.Teclado, [int]$item.Total)
    }
    [void]$codeSummaryGrid.Rows.Add("TOTAL", [int]$summary.Produtos[$script:ComputerProduct].Saldo, [int]$summary.Produtos[$script:KeyboardProduct].Saldo, [int]$summary.SaldoTotal)

    $missingDateValue.Text = [string][int]$summary.DatasAusentes
    $negativeValue.Text = [string][int]$summary.SaldosNegativos
    $overEntryValue.Text = [string][int]$summary.SaldoMaiorQueEntrada
    $generalStatusValue.Text = [string]$summary.Situacao
    $generalStatusValue.ForeColor = if ($summary.Situacao -eq "OK") { $script:CurrentPalette.Success } else { $script:CurrentPalette.Danger }
    $computerTab.Text = "COMPUTADOR DE BORDO CB5 ($([int]$summary.Produtos[$script:ComputerProduct].Registros))"
    $keyboardTab.Text = "TECLADO V5 ($([int]$summary.Produtos[$script:KeyboardProduct].Registros))"
}

function Refresh-NFAll {
    Refresh-NFSummary
    Refresh-NFProductGrid -Product $script:ComputerProduct -Grid $computerGrid -FilterBox $computerFilter -StatusFilter $computerStatusFilter -CodeFilter $computerCodeFilter -CountLabel $computerCountLabel
    Refresh-NFProductGrid -Product $script:KeyboardProduct -Grid $keyboardGrid -FilterBox $keyboardFilter -StatusFilter $keyboardStatusFilter -CodeFilter $keyboardCodeFilter -CountLabel $keyboardCountLabel
    if ($mainTabs.SelectedTab -eq $movementTab) { Refresh-NFMovements }
    if ($mainTabs.SelectedTab -eq $historyTab) { Refresh-NFHistory }
    if ($mainTabs.SelectedTab -eq $securityTab) { Refresh-NFBackups }
    $exportReadiness = Get-NFEntradaExportReadiness -Store $script:Store -DataDirectory $script:DataDirectory
    $exportButton.Enabled = [bool]$exportReadiness.PodeExportar
    $summary = Get-NFEntradaSummary -Store $script:Store
    $totalRecords = [int]$summary.Produtos[$script:ComputerProduct].Registros + [int]$summary.Produtos[$script:KeyboardProduct].Registros
    Set-NFStatus ("Pronto • " + $totalRecords + " registro(s) • Em estoque por padrão") "Normal"
}

function Show-NFRecordDialog {
    param([string]$Product, $Existing = $null, [string]$DefaultDate = "", [string]$DefaultCode = "800")
    $dialog = New-Object Windows.Forms.Form
    $displayProduct = Get-NFEntradaProductDisplayName $Product
    $dialog.Text = if ($null -eq $Existing) { "Novo registro — $displayProduct" } else { "Editar registro — $displayProduct" }
    $dialog.StartPosition = [Windows.Forms.FormStartPosition]::CenterParent
    $dialog.FormBorderStyle = [Windows.Forms.FormBorderStyle]::FixedDialog
    $dialog.MaximizeBox = $false
    $dialog.MinimizeBox = $false
    $dialog.ShowInTaskbar = $false
    $dialog.ClientSize = [Drawing.Size]::new(620, 480)
    $dialog.BackColor = $script:CurrentPalette.Background
    $dialog.ForeColor = $script:CurrentPalette.Text

    $layout = New-Object Windows.Forms.TableLayoutPanel
    $layout.Dock = [Windows.Forms.DockStyle]::Fill
    $layout.Padding = [Windows.Forms.Padding]::new(18)
    $layout.ColumnCount = 2
    $layout.RowCount = 8
    [void]$layout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Absolute, 180)))
    [void]$layout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 100)))
    foreach ($i in 0..5) { [void]$layout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, $(if ($i -eq 5) { 112 } else { 44 })))) }
    [void]$layout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 44)))
    [void]$layout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 100)))
    $dialog.Controls.Add($layout)

    function Add-DialogLabel([string]$text, [int]$row) {
        $label = New-Object Windows.Forms.Label
        $label.Text = $text
        $label.Dock = [Windows.Forms.DockStyle]::Fill
        $label.TextAlign = [Drawing.ContentAlignment]::MiddleLeft
        $label.Font = [Drawing.Font]::new("Segoe UI Semibold", 9)
        $label.ForeColor = $script:CurrentPalette.Text
        $layout.Controls.Add($label, 0, $row)
    }

    Add-DialogLabel "Data" 0
    $datePicker = New-Object Windows.Forms.DateTimePicker
    $datePicker.Format = [Windows.Forms.DateTimePickerFormat]::Custom
    $datePicker.CustomFormat = "dd/MM/yyyy"
    $datePicker.Dock = [Windows.Forms.DockStyle]::Fill
    $layout.Controls.Add($datePicker, 1, 0)

    Add-DialogLabel "Quantidade na NF" 1
    $qtyBox = New-Object Windows.Forms.NumericUpDown
    $qtyBox.Minimum = 1
    $qtyBox.Maximum = 1000000
    $qtyBox.Dock = [Windows.Forms.DockStyle]::Fill
    $layout.Controls.Add($qtyBox, 1, 1)

    Add-DialogLabel "NF de Entrada" 2
    $nfBox = New-Object Windows.Forms.TextBox
    $nfBox.Dock = [Windows.Forms.DockStyle]::Fill
    $nfBox.MaxLength = 30
    $layout.Controls.Add($nfBox, 1, 2)

    Add-DialogLabel "Quantidade no Saldo" 3
    $balanceBox = New-Object Windows.Forms.NumericUpDown
    $balanceBox.Minimum = 0
    $balanceBox.Maximum = 1000000
    $balanceBox.Dock = [Windows.Forms.DockStyle]::Fill
    $layout.Controls.Add($balanceBox, 1, 3)

    Add-DialogLabel "Código" 4
    $codeCombo = New-Object Windows.Forms.ComboBox
    $codeCombo.DropDownStyle = [Windows.Forms.ComboBoxStyle]::DropDownList
    [void]$codeCombo.Items.AddRange(@("800", "100", "850", "Garantia"))
    $codeCombo.Dock = [Windows.Forms.DockStyle]::Fill
    $layout.Controls.Add($codeCombo, 1, 4)

    Add-DialogLabel "NF de Saída / movimentações" 5
    $outBox = New-Object Windows.Forms.TextBox
    $outBox.Multiline = $true
    $outBox.ScrollBars = [Windows.Forms.ScrollBars]::Vertical
    $outBox.Dock = [Windows.Forms.DockStyle]::Fill
    $layout.Controls.Add($outBox, 1, 5)

    $validationLabel = New-Object Windows.Forms.Label
    $validationLabel.Text = "Preencha os dados para validar o registro."
    $validationLabel.Dock = [Windows.Forms.DockStyle]::Fill
    $validationLabel.TextAlign = [Drawing.ContentAlignment]::MiddleLeft
    $validationLabel.ForeColor = $script:CurrentPalette.Muted
    $layout.SetColumnSpan($validationLabel, 2)
    $layout.Controls.Add($validationLabel, 0, 6)

    $buttons = New-Object Windows.Forms.FlowLayoutPanel
    $buttons.FlowDirection = [Windows.Forms.FlowDirection]::RightToLeft
    $buttons.Dock = [Windows.Forms.DockStyle]::Fill
    $buttons.Padding = [Windows.Forms.Padding]::new(0, 12, 0, 0)
    $layout.SetColumnSpan($buttons, 2)
    $layout.Controls.Add($buttons, 0, 7)

    $cancel = New-Object Windows.Forms.Button
    $cancel.Text = "CANCELAR"
    $cancel.Width = 110
    $cancel.Height = 34
    $cancel.DialogResult = [Windows.Forms.DialogResult]::Cancel
    Set-NFButtonStyle $cancel "Secondary"
    $buttons.Controls.Add($cancel)

    $save = New-Object Windows.Forms.Button
    $save.Text = "SALVAR"
    $save.Width = 110
    $save.Height = 34
    $save.DialogResult = [Windows.Forms.DialogResult]::OK
    Set-NFButtonStyle $save "Primary"
    $buttons.Controls.Add($save)

    $saveAndNew = $null
    if ($null -eq $Existing) {
        $saveAndNew = New-Object Windows.Forms.Button
        $saveAndNew.Text = "SALVAR E NOVA"
        $saveAndNew.Width = 135
        $saveAndNew.Height = 34
        $saveAndNew.DialogResult = [Windows.Forms.DialogResult]::Retry
        Set-NFButtonStyle $saveAndNew "Secondary"
        $buttons.Controls.Add($saveAndNew)
    }
    $dialog.AcceptButton = $save
    $dialog.CancelButton = $cancel

    foreach ($control in @($datePicker, $qtyBox, $nfBox, $balanceBox, $codeCombo, $outBox)) {
        try { $control.BackColor = $script:CurrentPalette.Input; $control.ForeColor = $script:CurrentPalette.Text } catch {}
    }

    if ($null -ne $Existing) {
        $date = [DateTime]::MinValue
        if ([DateTime]::TryParseExact([string]$Existing.Data, "yyyy-MM-dd", [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::None, [ref]$date)) { $datePicker.Value = $date }
        $qtyBox.Value = [Math]::Max($qtyBox.Minimum, [Math]::Min($qtyBox.Maximum, [decimal][int]$Existing.QuantidadeNaNF))
        $nfBox.Text = [string]$Existing.NFEntrada
        $balanceBox.Value = [Math]::Max($balanceBox.Minimum, [Math]::Min($balanceBox.Maximum, [decimal][int]$Existing.QuantidadeSaldo))
        if ($codeCombo.Items.Contains([string]$Existing.Codigo)) { $codeCombo.SelectedItem = [string]$Existing.Codigo }
        $outBox.Text = [string]$Existing.NFSaida
    }
    else {
        $defaultParsed = [DateTime]::MinValue
        if (-not [string]::IsNullOrWhiteSpace($DefaultDate) -and [DateTime]::TryParseExact($DefaultDate, "yyyy-MM-dd", [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::None, [ref]$defaultParsed)) { $datePicker.Value = $defaultParsed }
        else { $datePicker.Value = [DateTime]::Today }
        $qtyBox.Value = 1
        $balanceBox.Value = $qtyBox.Value
        $codeCombo.SelectedItem = if ($codeCombo.Items.Contains($DefaultCode)) { $DefaultCode } else { "800" }
    }

    $ignoreId = if ($null -ne $Existing) { [int]$Existing.Id } else { 0 }
    $validateDialog = {
        $candidate = [pscustomobject]@{
            Data = $datePicker.Value.ToString("yyyy-MM-dd")
            QuantidadeNaNF = [int]$qtyBox.Value
            NFEntrada = ([string]$nfBox.Text).Trim()
            QuantidadeSaldo = [int]$balanceBox.Value
            Codigo = [string]$codeCombo.SelectedItem
            NFSaida = ([string]$outBox.Text).Trim()
        }
        try {
            [void](Test-NFEntradaRecord -Record $candidate -Store $script:Store -Product $Product -IgnoreId $ignoreId)
            $validationLabel.Text = if ($null -eq $Existing) { "Pronto para salvar. O saldo inicial acompanha a quantidade da NF." } else { "Registro válido e pronto para salvar." }
            $validationLabel.ForeColor = $script:CurrentPalette.Success
            $save.Enabled = $true
            if ($null -ne $saveAndNew) { $saveAndNew.Enabled = $true }
        } catch {
            $validationLabel.Text = $_.Exception.Message
            $validationLabel.ForeColor = $script:CurrentPalette.Danger
            $save.Enabled = $false
            if ($null -ne $saveAndNew) { $saveAndNew.Enabled = $false }
        }
    }.GetNewClosure()

    $qtyBox.Add_ValueChanged({ if ($null -eq $Existing) { $balanceBox.Value = $qtyBox.Value }; & $validateDialog }.GetNewClosure())
    $datePicker.Add_ValueChanged($validateDialog)
    $nfBox.Add_TextChanged($validateDialog)
    $balanceBox.Add_ValueChanged($validateDialog)
    $codeCombo.Add_SelectedIndexChanged($validateDialog)
    $outBox.Add_TextChanged($validateDialog)
    [void](& $validateDialog)
    $dialog.Add_Shown({ $qtyBox.Focus() }.GetNewClosure())

    $dialogResult = $dialog.ShowDialog()
    if ($dialogResult -ne [Windows.Forms.DialogResult]::OK -and $dialogResult -ne [Windows.Forms.DialogResult]::Retry) { $dialog.Dispose(); return $null }
    $result = [pscustomobject]@{
        Data = $datePicker.Value.ToString("yyyy-MM-dd")
        QuantidadeNaNF = [int]$qtyBox.Value
        NFEntrada = ([string]$nfBox.Text).Trim()
        QuantidadeSaldo = [int]$balanceBox.Value
        Codigo = [string]$codeCombo.SelectedItem
        NFSaida = ([string]$outBox.Text).Trim()
        ContinuarCadastro = ($dialogResult -eq [Windows.Forms.DialogResult]::Retry)
    }
    $dialog.Dispose()
    return $result
}

function Add-NFRecordFromUI {
    param([string]$DefaultDate = "", [string]$DefaultCode = "800")
    $product = Get-SelectedProduct
    if ([string]::IsNullOrWhiteSpace($product)) { return }
    $defaultDate = if ([string]::IsNullOrWhiteSpace($DefaultDate)) { [DateTime]::Today.ToString("yyyy-MM-dd") } else { $DefaultDate }
    $record = Show-NFRecordDialog -Product $product -DefaultDate $defaultDate -DefaultCode $DefaultCode
    if ($null -eq $record) { return }
    try {
        $created = Add-NFEntradaRecord -Store $script:Store -Product $product -Record $record
        Save-NFStore
        Refresh-NFAll
        $targetGrid = if ($product -eq $script:ComputerProduct) { $computerGrid } else { $keyboardGrid }
        [void](Select-NFRecordInGrid -Grid $targetGrid -Id ([int]$created.Id))
        Set-NFStatus ("Registro " + $record.NFEntrada + " incluído com sucesso.") "Success"
        if ([bool]$record.ContinuarCadastro) {
            Add-NFRecordFromUI -DefaultDate ([string]$record.Data) -DefaultCode ([string]$record.Codigo)
        }
    }
    catch { Set-NFStatus $_.Exception.Message "Error"; [Windows.Forms.MessageBox]::Show($_.Exception.Message, "Controle de NF de Entrada", 0, 48) | Out-Null }
}

function Edit-NFRecordFromUI {
    $product = Get-SelectedProduct
    if ([string]::IsNullOrWhiteSpace($product)) { return }
    $grid = if ($product -eq $script:ComputerProduct) { $computerGrid } else { $keyboardGrid }
    $id = Get-SelectedRecordId $grid
    if ($id -le 0) { [Windows.Forms.MessageBox]::Show("Selecione um registro para editar.", "Controle de NF de Entrada", 0, 64) | Out-Null; return }
    $existing = Find-NFRecordById -Product $product -Id $id
    if ($null -eq $existing) { return }
    $record = Show-NFRecordDialog -Product $product -Existing $existing
    if ($null -eq $record) { return }
    try {
        Update-NFEntradaRecord -Store $script:Store -Product $product -Id $id -Record $record
        Save-NFStore
        Refresh-NFAll
        [void](Select-NFRecordInGrid -Grid $grid -Id $id)
        Set-NFStatus ("Registro " + $record.NFEntrada + " atualizado com sucesso.") "Success"
    }
    catch { Set-NFStatus $_.Exception.Message "Error"; [Windows.Forms.MessageBox]::Show($_.Exception.Message, "Controle de NF de Entrada", 0, 48) | Out-Null }
}

function Register-NFOutputFromUI {
    $product = Get-SelectedProduct
    if ([string]::IsNullOrWhiteSpace($product)) { return }
    $grid = if ($product -eq $script:ComputerProduct) { $computerGrid } else { $keyboardGrid }
    $id = Get-SelectedRecordId $grid
    if ($id -le 0) { [Windows.Forms.MessageBox]::Show("Selecione uma NF em estoque para registrar a saída.", "Controle de NF de Entrada", 0, 64) | Out-Null; return }
    $record = Find-NFRecordById -Product $product -Id $id
    if ($null -eq $record) { return }
    $saldoAtual = [int]$record.QuantidadeSaldo
    if ($saldoAtual -le 0) { [Windows.Forms.MessageBox]::Show("A NF selecionada já está encerrada.", "Controle de NF de Entrada", 0, 64) | Out-Null; return }

    $dialog = New-Object Windows.Forms.Form
    $dialog.Text = "Registrar saída — NF $($record.NFEntrada)"
    $dialog.StartPosition = [Windows.Forms.FormStartPosition]::CenterParent
    $dialog.FormBorderStyle = [Windows.Forms.FormBorderStyle]::FixedDialog
    $dialog.MaximizeBox = $false; $dialog.MinimizeBox = $false; $dialog.ShowInTaskbar = $false
    $dialog.ClientSize = [Drawing.Size]::new(570, 300)
    $dialog.BackColor = $script:CurrentPalette.Background; $dialog.ForeColor = $script:CurrentPalette.Text
    $layout = New-Object Windows.Forms.TableLayoutPanel
    $layout.Dock = [Windows.Forms.DockStyle]::Fill; $layout.Padding = [Windows.Forms.Padding]::new(18); $layout.ColumnCount = 2; $layout.RowCount = 5
    [void]$layout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Absolute, 190)))
    [void]$layout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 100)))
    foreach($h in @(46,46,46,62,50)){ [void]$layout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute,$h))) }
    $dialog.Controls.Add($layout)
    function Add-OutputLabel([string]$text,[int]$row){ $l=New-Object Windows.Forms.Label; $l.Text=$text; $l.Dock=[Windows.Forms.DockStyle]::Fill; $l.TextAlign=[Drawing.ContentAlignment]::MiddleLeft; $l.ForeColor=$script:CurrentPalette.Text; $layout.Controls.Add($l,0,$row) }
    Add-OutputLabel "Saldo atual" 0
    $current=New-Object Windows.Forms.Label; $current.Text=[string]$saldoAtual; $current.Dock=[Windows.Forms.DockStyle]::Fill; $current.TextAlign=[Drawing.ContentAlignment]::MiddleLeft; $layout.Controls.Add($current,1,0)
    Add-OutputLabel "Quantidade da saída" 1
    $qty=New-Object Windows.Forms.NumericUpDown; $qty.Minimum=1; $qty.Maximum=$saldoAtual; $qty.Value=1; $qty.Dock=[Windows.Forms.DockStyle]::Fill; $layout.Controls.Add($qty,1,1)
    Add-OutputLabel "Saldo após saída" 2
    $after=New-Object Windows.Forms.Label; $after.Text=[string]($saldoAtual-1); $after.Dock=[Windows.Forms.DockStyle]::Fill; $after.TextAlign=[Drawing.ContentAlignment]::MiddleLeft; $layout.Controls.Add($after,1,2)
    Add-OutputLabel "NF de Saída / referência" 3
    $refBox=New-Object Windows.Forms.TextBox; $refBox.Dock=[Windows.Forms.DockStyle]::Fill; $refBox.MaxLength=120; $layout.Controls.Add($refBox,1,3)
    $qty.Add_ValueChanged({ $after.Text=[string]($saldoAtual-[int]$qty.Value) })
    $buttons=New-Object Windows.Forms.FlowLayoutPanel; $buttons.Dock=[Windows.Forms.DockStyle]::Fill; $buttons.FlowDirection=[Windows.Forms.FlowDirection]::RightToLeft; $layout.SetColumnSpan($buttons,2); $layout.Controls.Add($buttons,0,4)
    $cancel=New-Object Windows.Forms.Button; $cancel.Text="CANCELAR"; $cancel.Width=110; $cancel.Height=34; $cancel.DialogResult=[Windows.Forms.DialogResult]::Cancel; Set-NFButtonStyle $cancel "Secondary"; $buttons.Controls.Add($cancel)
    $save=New-Object Windows.Forms.Button; $save.Text="REGISTRAR SAÍDA"; $save.Width=140; $save.Height=34; $save.DialogResult=[Windows.Forms.DialogResult]::OK; Set-NFButtonStyle $save "Primary"; $buttons.Controls.Add($save)
    $dialog.AcceptButton=$save; $dialog.CancelButton=$cancel
    if ($dialog.ShowDialog() -ne [Windows.Forms.DialogResult]::OK) { $dialog.Dispose(); return }
    $quantity=[int]$qty.Value; $reference=([string]$refBox.Text).Trim(); $dialog.Dispose()
    try {
        [void](Register-NFEntradaOutput -Store $script:Store -Product $product -Id $id -Quantidade $quantity -NFSaida $reference)
        Save-NFStore
        Refresh-NFAll
        [void](Select-NFRecordInGrid -Grid $grid -Id $id)
        Set-NFStatus ("Saída registrada na NF " + $record.NFEntrada + ". Saldo atual: " + ($saldoAtual-$quantity)) "Success"
    }
    catch { Set-NFStatus $_.Exception.Message "Error"; [Windows.Forms.MessageBox]::Show($_.Exception.Message, "Falha ao registrar saída", 0, 16) | Out-Null }
}

function Remove-NFRecordFromUI {
    $product = Get-SelectedProduct
    if ([string]::IsNullOrWhiteSpace($product)) { return }
    $grid = if ($product -eq $script:ComputerProduct) { $computerGrid } else { $keyboardGrid }
    $id = Get-SelectedRecordId $grid
    if ($id -le 0) { [Windows.Forms.MessageBox]::Show("Selecione um registro para excluir.", "Controle de NF de Entrada", 0, 64) | Out-Null; return }
    $record = Find-NFRecordById -Product $product -Id $id
    if ($null -eq $record) { return }
    $answer = [Windows.Forms.MessageBox]::Show(
        "Excluir a NF de Entrada $($record.NFEntrada) de $(Get-NFEntradaProductDisplayName $product)?`r`n`r`nEssa ação altera somente a base local do módulo e será refletida na próxima exportação.",
        "Confirmar exclusão",
        [Windows.Forms.MessageBoxButtons]::YesNo,
        [Windows.Forms.MessageBoxIcon]::Warning
    )
    if ($answer -ne [Windows.Forms.DialogResult]::Yes) { return }
    try {
        Remove-NFEntradaRecord -Store $script:Store -Product $product -Id $id
        Save-NFStore
        Refresh-NFAll
        Set-NFStatus ("Registro " + $record.NFEntrada + " excluído; histórico preservado.") "Warning"
    }
    catch { Set-NFStatus $_.Exception.Message "Error"; [Windows.Forms.MessageBox]::Show($_.Exception.Message, "Controle de NF de Entrada", 0, 48) | Out-Null }
}

function Import-NFSourceFromUI {
    $dialog = New-Object Windows.Forms.OpenFileDialog
    $dialog.Title = "Selecionar planilha original de NF de Entrada"
    $dialog.Filter = "Planilha do Excel (*.xlsx)|*.xlsx"
    $dialog.Multiselect = $false
    if ($dialog.ShowDialog() -ne [Windows.Forms.DialogResult]::OK) { $dialog.Dispose(); return $false }
    $source = $dialog.FileName
    $dialog.Dispose()
    $currentSummary = Get-NFEntradaSummary -Store $script:Store
    $currentRecords = [int]$currentSummary.Produtos[$script:ComputerProduct].Registros + [int]$currentSummary.Produtos[$script:KeyboardProduct].Registros
    $templateExists = [IO.File]::Exists((Get-NFEntradaTemplatePath -DataDirectory $script:DataDirectory))
    if ($currentRecords -gt 0 -or $templateExists) {
        $answer = [Windows.Forms.MessageBox]::Show(
            "Esta importação substituirá a base ativa pelos dados da planilha selecionada.`r`n`r`nAntes da troca, o programa criará automaticamente um backup da base e do modelo atuais. O histórico já registrado será preservado.`r`n`r`nContinuar?",
            "Confirmar nova importação",
            [Windows.Forms.MessageBoxButtons]::YesNo,
            [Windows.Forms.MessageBoxIcon]::Warning
        )
        if ($answer -ne [Windows.Forms.DialogResult]::Yes) { Set-NFStatus "Importação cancelada; nenhum dado foi alterado." "Normal"; return $false }
    }
    try {
        Set-NFStatus "Importando planilha e protegendo a base atual..." "Warning"
        $result = Import-NFEntradaSourceWorkbook -SourcePath $source -DataDirectory $script:DataDirectory
        $script:DatabasePath = [string]$result.StorePath
        $script:Store = $result.Store
        Refresh-NFAll
        Set-NFStatus "Planilha importada com sucesso; base anterior protegida em backup." "Success"
        $backupText = if ([string]::IsNullOrWhiteSpace([string]$result.BackupDirectory)) { "" } else { "`r`n`r`nUma cópia de segurança da base anterior foi criada automaticamente." }
        [Windows.Forms.MessageBox]::Show(
            "Planilha importada com sucesso. O arquivo original permaneceu no local escolhido; o módulo usa uma cópia protegida como modelo de exportação e mantém os registros na base local." + $backupText,
            "Controle de NF de Entrada",
            [Windows.Forms.MessageBoxButtons]::OK,
            [Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
        return $true
    }
    catch {
        Set-NFStatus $_.Exception.Message "Error"
        [Windows.Forms.MessageBox]::Show($_.Exception.Message, "Falha ao importar planilha", 0, 16) | Out-Null
        return $false
    }
}

function Export-NFFromUI {
    $readiness = Get-NFEntradaExportReadiness -Store $script:Store -DataDirectory $script:DataDirectory
    if (-not [bool]$readiness.PodeExportar) {
        Show-NFExportReadiness
        Set-NFStatus "Exportação bloqueada pela conferência automática." "Error"
        return
    }
    if ([int]$readiness.Pendencias -gt 0) {
        $answer = [Windows.Forms.MessageBox]::Show(
            "Existem $($readiness.Pendencias) NF(s) com pendências de conferência.`r`n`r`nA planilha pode ser exportada sem alterar o formato oficial, mas os dados marcados para revisão também serão levados para o Excel.`r`n`r`nDeseja exportar mesmo assim?",
            "Exportação com pendências",
            [Windows.Forms.MessageBoxButtons]::YesNo,
            [Windows.Forms.MessageBoxIcon]::Warning
        )
        if ($answer -ne [Windows.Forms.DialogResult]::Yes) {
            Set-NFStatus "Exportação cancelada para revisão das pendências." "Warning"
            return
        }
    }
    $dialog = New-Object Windows.Forms.SaveFileDialog
    $dialog.Title = "Exportar planilha de NF de Entrada"
    $dialog.Filter = "Planilha do Excel (*.xlsx)|*.xlsx"
    $dialog.DefaultExt = "xlsx"
    $dialog.AddExtension = $true
    $dialog.FileName = "NF DE ENTRADA - " + [DateTime]::Now.ToString("yyyy-MM-dd") + ".xlsx"
    if ($dialog.ShowDialog() -ne [Windows.Forms.DialogResult]::OK) { $dialog.Dispose(); return }
    $path = $dialog.FileName
    $dialog.Dispose()
    try {
        $exported = Export-NFEntradaWorkbook -Store $script:Store -DestinationPath $path
        $exportSummary = Get-NFEntradaSummary -Store $script:Store
        $exportDetails = "Arquivo: " + [IO.Path]::GetFileName($exported) + " • CB5: " + [string]$exportSummary.Produtos[$script:ComputerProduct].Registros + " registro(s) • Teclado: " + [string]$exportSummary.Produtos[$script:KeyboardProduct].Registros + " registro(s) • Pendências: " + [string]$readiness.Pendencias
        [void](Add-NFEntradaHistoryEvent -Store $script:Store -Tipo "Exportacao" -Detalhes $exportDetails)
        Save-NFStore
        Refresh-NFAll
        Set-NFStatus "Planilha exportada com sucesso e registrada no histórico." "Success"
        [Windows.Forms.MessageBox]::Show(
            "Planilha exportada com o modelo original, fórmulas, resumo e formatação preservados.`r`n`r`n$exported",
            "Exportação concluída",
            [Windows.Forms.MessageBoxButtons]::OK,
            [Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
    }
    catch { Set-NFStatus $_.Exception.Message "Error"; [Windows.Forms.MessageBox]::Show($_.Exception.Message, "Falha na exportação", 0, 16) | Out-Null }
}

function New-NFSummaryCard {
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

function New-ProductTabContent {
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
    $statusFilter.SelectedIndex = 1
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

$script:CurrentPalette = Get-NFEntradaPalette $(if ([string]::IsNullOrWhiteSpace($HostTheme)) { "Escuro profissional" } else { $HostTheme })

if ($script:IsInProcessHosted) {
    $form = New-Object Windows.Forms.UserControl
    $form.Name = "NFEntradaHostedControl"
    $form.Dock = [Windows.Forms.DockStyle]::Fill
    $form.Margin = [Windows.Forms.Padding]::new(0)
    $form.Padding = [Windows.Forms.Padding]::new(0)
}
else {
    $form = New-Object Windows.Forms.Form
    $form.Text = "Controle de NF de Entrada"
    $form.StartPosition = [Windows.Forms.FormStartPosition]::CenterScreen
    $form.MinimumSize = [Drawing.Size]::new(980, 680)
    $form.Size = [Drawing.Size]::new(1280, 820)
}
$form.BackColor = $script:CurrentPalette.Background
$form.ForeColor = $script:CurrentPalette.Text

$root = New-Object Windows.Forms.TableLayoutPanel
$root.Dock = [Windows.Forms.DockStyle]::Fill
$root.Padding = [Windows.Forms.Padding]::new(14)
$root.RowCount = 4
[void]$root.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 92)))
[void]$root.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 108)))
[void]$root.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 100)))
[void]$root.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 58)))
$form.Controls.Add($root)

$header = New-Object Windows.Forms.TableLayoutPanel
$header.Dock = [Windows.Forms.DockStyle]::Fill
$header.ColumnCount = 3
[void]$header.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 100)))
[void]$header.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Absolute, 175)))
[void]$header.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Absolute, 175)))
$root.Controls.Add($header, 0, 0)

$heading = New-Object Windows.Forms.TableLayoutPanel
$heading.Dock = [Windows.Forms.DockStyle]::Fill
$heading.RowCount = 2
[void]$heading.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 54)))
[void]$heading.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 100)))
$header.Controls.Add($heading, 0, 0)
$title = New-Object Windows.Forms.Label
$title.Text = "Controle de NF de Entrada"
$title.Dock = [Windows.Forms.DockStyle]::Fill
$title.TextAlign = [Drawing.ContentAlignment]::BottomLeft
$title.Font = [Drawing.Font]::new("Segoe UI Semibold", 20)
$title.ForeColor = $script:CurrentPalette.Text
$heading.Controls.Add($title, 0, 0)
$subtitle = New-Object Windows.Forms.Label
$subtitle.Text = "Saldos, NFs e exportação no mesmo padrão da planilha oficial"
$subtitle.Dock = [Windows.Forms.DockStyle]::Fill
$subtitle.TextAlign = [Drawing.ContentAlignment]::TopLeft
$subtitle.ForeColor = $script:CurrentPalette.Muted
$heading.Controls.Add($subtitle, 0, 1)

$importButton = New-Object Windows.Forms.Button
$importButton.Text = "IMPORTAR EXCEL"
$importButton.Dock = [Windows.Forms.DockStyle]::Fill
$importButton.Margin = [Windows.Forms.Padding]::new(10, 16, 0, 14)
Set-NFButtonStyle $importButton "Secondary"
$header.Controls.Add($importButton, 1, 0)

$exportButton = New-Object Windows.Forms.Button
$exportButton.Text = "EXCEL OFICIAL"
$exportButton.Dock = [Windows.Forms.DockStyle]::Fill
$exportButton.Margin = [Windows.Forms.Padding]::new(10, 16, 0, 14)
Set-NFButtonStyle $exportButton "Primary"
$header.Controls.Add($exportButton, 2, 0)

$cards = New-Object Windows.Forms.TableLayoutPanel
$cards.Dock = [Windows.Forms.DockStyle]::Fill
$cards.ColumnCount = 4
foreach ($i in 0..3) { [void]$cards.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 25))) }
$root.Controls.Add($cards, 0, 1)
$saldoTotalValue = $null; $computerBalanceValue = $null; $keyboardBalanceValue = $null; $openNFsValue = $null
$cards.Controls.Add((New-NFSummaryCard "SALDO TOTAL" "peças disponíveis" ([ref]$saldoTotalValue)), 0, 0)
$cards.Controls.Add((New-NFSummaryCard "COMPUTADOR DE BORDO CB5" "saldo atual" ([ref]$computerBalanceValue)), 1, 0)
$cards.Controls.Add((New-NFSummaryCard "TECLADO V5" "saldo atual" ([ref]$keyboardBalanceValue)), 2, 0)
$cards.Controls.Add((New-NFSummaryCard "NFs EM ABERTO" "com saldo maior que zero" ([ref]$openNFsValue)), 3, 0)

$mainTabs = New-Object Windows.Forms.TabControl
$mainTabs.Dock = [Windows.Forms.DockStyle]::Fill
$mainTabs.Font = [Drawing.Font]::new("Segoe UI Semibold", 9)
$root.Controls.Add($mainTabs, 0, 2)

$computerTab = New-Object Windows.Forms.TabPage
$computerTab.Text = "COMPUTADOR DE BORDO CB5"
$computerTab.BackColor = $script:CurrentPalette.Background
$mainTabs.TabPages.Add($computerTab)
$keyboardTab = New-Object Windows.Forms.TabPage
$keyboardTab.Text = "TECLADO V5"
$keyboardTab.BackColor = $script:CurrentPalette.Background
$mainTabs.TabPages.Add($keyboardTab)
$movementTab = New-Object Windows.Forms.TabPage
$movementTab.Text = "MOVIMENTAÇÕES"
$movementTab.BackColor = $script:CurrentPalette.Background
$mainTabs.TabPages.Add($movementTab)
$historyTab = New-Object Windows.Forms.TabPage
$historyTab.Text = "HISTÓRICO"
$historyTab.BackColor = $script:CurrentPalette.Background
$mainTabs.TabPages.Add($historyTab)
$securityTab = New-Object Windows.Forms.TabPage
$securityTab.Text = "SEGURANÇA"
$securityTab.BackColor = $script:CurrentPalette.Background
$mainTabs.TabPages.Add($securityTab)
$summaryTab = New-Object Windows.Forms.TabPage
$summaryTab.Text = "RESUMO"
$summaryTab.BackColor = $script:CurrentPalette.Background
$mainTabs.TabPages.Add($summaryTab)
$mainTabs.SelectedTab = $computerTab

$summaryLayout = New-Object Windows.Forms.TableLayoutPanel
$summaryLayout.Dock = [Windows.Forms.DockStyle]::Fill
$summaryLayout.Padding = [Windows.Forms.Padding]::new(10)
$summaryLayout.ColumnCount = 2
$summaryLayout.RowCount = 3
[void]$summaryLayout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 55)))
[void]$summaryLayout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 45)))
[void]$summaryLayout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 34)))
[void]$summaryLayout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 38)))
[void]$summaryLayout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 28)))
$summaryTab.Controls.Add($summaryLayout)

$productGroup = New-Object Windows.Forms.GroupBox
$productGroup.Text = "Saldo por produto"
$productGroup.Dock = [Windows.Forms.DockStyle]::Fill
$productGroup.ForeColor = $script:CurrentPalette.Text
$productGroup.Padding = [Windows.Forms.Padding]::new(10, 22, 10, 10)
$summaryLayout.Controls.Add($productGroup, 0, 0)
$productSummaryGrid = New-NFGrid
Add-NFGridColumn $productSummaryGrid "Produto" "PRODUTO" 200 $true
Add-NFGridColumn $productSummaryGrid "Abertas" "NFs EM ABERTO" 125
Add-NFGridColumn $productSummaryGrid "Saldo" "SALDO (PÇS)" 110
$productGroup.Controls.Add($productSummaryGrid)

$conferenceGroup = New-Object Windows.Forms.GroupBox
$conferenceGroup.Text = "Conferência automática"
$conferenceGroup.Dock = [Windows.Forms.DockStyle]::Fill
$conferenceGroup.ForeColor = $script:CurrentPalette.Text
$conferenceGroup.Padding = [Windows.Forms.Padding]::new(14, 24, 14, 12)
$summaryLayout.Controls.Add($conferenceGroup, 1, 0)
$conference = New-Object Windows.Forms.TableLayoutPanel
$conference.Dock = [Windows.Forms.DockStyle]::Fill
$conference.ColumnCount = 2
$conference.RowCount = 6
[void]$conference.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 70)))
[void]$conference.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 30)))
$conferenceGroup.Controls.Add($conference)
$missingDateValue = New-Object Windows.Forms.Label
$negativeValue = New-Object Windows.Forms.Label
$overEntryValue = New-Object Windows.Forms.Label
$reviewIssuesValue = New-Object Windows.Forms.Label
$exportStatusValue = New-Object Windows.Forms.Label
$generalStatusValue = New-Object Windows.Forms.Label
$conferenceRows = @(
    @("Datas ausentes", $missingDateValue),
    @("Saldos negativos", $negativeValue),
    @("Saldo maior que a entrada", $overEntryValue),
    @("Pendências para revisar", $reviewIssuesValue),
    @("Exportação Excel", $exportStatusValue),
    @("Situação geral", $generalStatusValue)
)
for ($i = 0; $i -lt $conferenceRows.Count; $i++) {
    $l = New-Object Windows.Forms.Label
    $l.Text = $conferenceRows[$i][0]
    $l.Dock = [Windows.Forms.DockStyle]::Fill
    $l.TextAlign = [Drawing.ContentAlignment]::MiddleLeft
    $l.ForeColor = $script:CurrentPalette.Muted
    $conference.Controls.Add($l, 0, $i)
    $v = $conferenceRows[$i][1]
    $v.Dock = [Windows.Forms.DockStyle]::Fill
    $v.TextAlign = [Drawing.ContentAlignment]::MiddleRight
    $v.Font = [Drawing.Font]::new("Segoe UI Semibold", 10)
    $v.ForeColor = $script:CurrentPalette.Text
    $conference.Controls.Add($v, 1, $i)
}

$codeGroup = New-Object Windows.Forms.GroupBox
$codeGroup.Text = "Saldo por código"
$codeGroup.Dock = [Windows.Forms.DockStyle]::Fill
$codeGroup.ForeColor = $script:CurrentPalette.Text
$codeGroup.Padding = [Windows.Forms.Padding]::new(10, 22, 10, 10)
$summaryLayout.SetColumnSpan($codeGroup, 2)
$summaryLayout.Controls.Add($codeGroup, 0, 1)
$codeSummaryGrid = New-NFGrid
Add-NFGridColumn $codeSummaryGrid "Codigo" "CÓDIGO" 110
Add-NFGridColumn $codeSummaryGrid "Computador" "COMPUTADOR CB5" 150
Add-NFGridColumn $codeSummaryGrid "Teclado" "TECLADO V5" 150
Add-NFGridColumn $codeSummaryGrid "Total" "TOTAL" 130 $true
$codeGroup.Controls.Add($codeSummaryGrid)

$activityGroup = New-Object Windows.Forms.GroupBox
$activityGroup.Text = "Atividade operacional"
$activityGroup.Dock = [Windows.Forms.DockStyle]::Fill
$activityGroup.ForeColor = $script:CurrentPalette.Text
$activityGroup.Padding = [Windows.Forms.Padding]::new(8, 20, 8, 8)
$summaryLayout.SetColumnSpan($activityGroup, 2)
$summaryLayout.Controls.Add($activityGroup, 0, 2)

$activityLayout = New-Object Windows.Forms.TableLayoutPanel
$activityLayout.Dock = [Windows.Forms.DockStyle]::Fill
$activityLayout.ColumnCount = 5
foreach ($percent in @(17, 17, 17, 32, 17)) {
    [void]$activityLayout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, $percent)))
}
$activityGroup.Controls.Add($activityLayout)

$movementTodayValue = $null
$piecesTodayValue = $null
$piecesSevenValue = $null
$activityLayout.Controls.Add((New-NFSummaryCard "MOVIMENTAÇÕES HOJE" "registros de saída" ([ref]$movementTodayValue)), 0, 0)
$activityLayout.Controls.Add((New-NFSummaryCard "PEÇAS SAÍRAM HOJE" "saídas registradas" ([ref]$piecesTodayValue)), 1, 0)
$activityLayout.Controls.Add((New-NFSummaryCard "PEÇAS EM 7 DIAS" "saídas registradas" ([ref]$piecesSevenValue)), 2, 0)

$lastPanel = New-Object Windows.Forms.Panel
$lastPanel.Dock = [Windows.Forms.DockStyle]::Fill
$lastPanel.Margin = [Windows.Forms.Padding]::new(6)
$lastPanel.BackColor = $script:CurrentPalette.Card
$lastPanel.BorderStyle = [Windows.Forms.BorderStyle]::FixedSingle
$lastLayout = New-Object Windows.Forms.TableLayoutPanel
$lastLayout.Dock = [Windows.Forms.DockStyle]::Fill
$lastLayout.Padding = [Windows.Forms.Padding]::new(12, 8, 12, 8)
$lastLayout.RowCount = 2
[void]$lastLayout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 24)))
[void]$lastLayout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 100)))
$lastPanel.Controls.Add($lastLayout)
$lastTitle = New-Object Windows.Forms.Label
$lastTitle.Text = "ÚLTIMA MOVIMENTAÇÃO"
$lastTitle.Dock = [Windows.Forms.DockStyle]::Fill
$lastTitle.Font = [Drawing.Font]::new("Segoe UI Semibold", 8.5)
$lastTitle.ForeColor = $script:CurrentPalette.Muted
$lastLayout.Controls.Add($lastTitle, 0, 0)
$lastMovementValue = New-Object Windows.Forms.Label
$lastMovementValue.Text = "Nenhuma movimentação registrada"
$lastMovementValue.Dock = [Windows.Forms.DockStyle]::Fill
$lastMovementValue.TextAlign = [Drawing.ContentAlignment]::MiddleLeft
$lastMovementValue.Font = [Drawing.Font]::new("Segoe UI Semibold", 9.5)
$lastMovementValue.ForeColor = $script:CurrentPalette.Text
$lastLayout.Controls.Add($lastMovementValue, 0, 1)
$activityLayout.Controls.Add($lastPanel, 3, 0)

$summaryActionPanel = New-Object Windows.Forms.FlowLayoutPanel
$summaryActionPanel.Dock = [Windows.Forms.DockStyle]::Fill
$summaryActionPanel.FlowDirection = [Windows.Forms.FlowDirection]::TopDown
$summaryActionPanel.WrapContents = $false
$summaryActionPanel.Padding = [Windows.Forms.Padding]::new(4, 7, 4, 4)
$summaryActionPanel.BackColor = $script:CurrentPalette.Card
$reviewIssuesButton = New-Object Windows.Forms.Button
$reviewIssuesButton.Text = "PENDÊNCIAS"
$reviewIssuesButton.Width = 145
$reviewIssuesButton.Height = 32
$reviewIssuesButton.Margin = [Windows.Forms.Padding]::new(2, 2, 2, 5)
Set-NFButtonStyle $reviewIssuesButton "Secondary"
$exportCheckButton = New-Object Windows.Forms.Button
$exportCheckButton.Text = "VALIDAR EXCEL"
$exportCheckButton.Width = 145
$exportCheckButton.Height = 32
$exportCheckButton.Margin = [Windows.Forms.Padding]::new(2)
Set-NFButtonStyle $exportCheckButton "Secondary"
$summaryActionPanel.Controls.Add($reviewIssuesButton)
$summaryActionPanel.Controls.Add($exportCheckButton)
$activityLayout.Controls.Add($summaryActionPanel, 4, 0)

# MOVIMENTAÇÕES
$movementLayout = New-Object Windows.Forms.TableLayoutPanel
$movementLayout.Dock = [Windows.Forms.DockStyle]::Fill
$movementLayout.Padding = [Windows.Forms.Padding]::new(10)
$movementLayout.RowCount = 3
[void]$movementLayout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 52)))
[void]$movementLayout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 100)))
[void]$movementLayout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 42)))
$movementTab.Controls.Add($movementLayout)
$movementFilters = New-Object Windows.Forms.TableLayoutPanel
$movementFilters.Dock = [Windows.Forms.DockStyle]::Fill
$movementFilters.ColumnCount = 6
[void]$movementFilters.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Absolute, 74)))
[void]$movementFilters.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 100)))
[void]$movementFilters.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Absolute, 62)))
[void]$movementFilters.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Absolute, 190)))
[void]$movementFilters.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Absolute, 58)))
[void]$movementFilters.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Absolute, 165)))
$movementLayout.Controls.Add($movementFilters,0,0)
$movementSearchLabel=New-Object Windows.Forms.Label
$movementSearchLabel.Text="Pesquisar"; $movementSearchLabel.Dock=[Windows.Forms.DockStyle]::Fill; $movementSearchLabel.TextAlign=[Drawing.ContentAlignment]::MiddleLeft; $movementSearchLabel.ForeColor=$script:CurrentPalette.Muted
$movementFilters.Controls.Add($movementSearchLabel,0,0)
$movementFilter=New-Object Windows.Forms.TextBox
$movementFilter.Dock=[Windows.Forms.DockStyle]::Fill; $movementFilter.Margin=[Windows.Forms.Padding]::new(0,9,12,9); $movementFilter.BackColor=$script:CurrentPalette.Input; $movementFilter.ForeColor=$script:CurrentPalette.Text
$movementFilters.Controls.Add($movementFilter,1,0)
$movementProductLabel=New-Object Windows.Forms.Label
$movementProductLabel.Text="Produto"; $movementProductLabel.Dock=[Windows.Forms.DockStyle]::Fill; $movementProductLabel.TextAlign=[Drawing.ContentAlignment]::MiddleLeft; $movementProductLabel.ForeColor=$script:CurrentPalette.Muted
$movementFilters.Controls.Add($movementProductLabel,2,0)
$movementProductFilter=New-Object Windows.Forms.ComboBox
$movementProductFilter.DropDownStyle=[Windows.Forms.ComboBoxStyle]::DropDownList
[void]$movementProductFilter.Items.AddRange(@("Todos","COMPUTADOR DE BORDO CB5","TECLADO V5"))
$movementProductFilter.SelectedIndex=0; $movementProductFilter.Dock=[Windows.Forms.DockStyle]::Fill; $movementProductFilter.Margin=[Windows.Forms.Padding]::new(0,8,8,8); $movementProductFilter.BackColor=$script:CurrentPalette.Input; $movementProductFilter.ForeColor=$script:CurrentPalette.Text
$movementFilters.Controls.Add($movementProductFilter,3,0)
$movementPeriodLabel=New-Object Windows.Forms.Label
$movementPeriodLabel.Text="Período"; $movementPeriodLabel.Dock=[Windows.Forms.DockStyle]::Fill; $movementPeriodLabel.TextAlign=[Drawing.ContentAlignment]::MiddleLeft; $movementPeriodLabel.ForeColor=$script:CurrentPalette.Muted
$movementFilters.Controls.Add($movementPeriodLabel,4,0)
$movementPeriodFilter=New-Object Windows.Forms.ComboBox
$movementPeriodFilter.DropDownStyle=[Windows.Forms.ComboBoxStyle]::DropDownList
[void]$movementPeriodFilter.Items.AddRange(@("Todos","Hoje","Últimos 7 dias","Últimos 30 dias"))
$movementPeriodFilter.SelectedIndex=0; $movementPeriodFilter.Dock=[Windows.Forms.DockStyle]::Fill; $movementPeriodFilter.Margin=[Windows.Forms.Padding]::new(0,8,8,8); $movementPeriodFilter.BackColor=$script:CurrentPalette.Input; $movementPeriodFilter.ForeColor=$script:CurrentPalette.Text
$movementFilters.Controls.Add($movementPeriodFilter,5,0)

$movementGrid=New-NFGrid
$movementIdCol=New-Object Windows.Forms.DataGridViewTextBoxColumn
$movementIdCol.Name="MovementId"; $movementIdCol.Visible=$false; [void]$movementGrid.Columns.Add($movementIdCol)
$movementProductKeyCol=New-Object Windows.Forms.DataGridViewTextBoxColumn
$movementProductKeyCol.Name="MovementProductKey"; $movementProductKeyCol.Visible=$false; [void]$movementGrid.Columns.Add($movementProductKeyCol)
Add-NFGridColumn $movementGrid "MovementDate" "DATA / HORA" 145
Add-NFGridColumn $movementGrid "MovementProduct" "PRODUTO" 190
Add-NFGridColumn $movementGrid "MovementNF" "NF DE ENTRADA" 110
Add-NFGridColumn $movementGrid "MovementQty" "SAÍDA" 75
Add-NFGridColumn $movementGrid "MovementBefore" "SALDO ANTES" 95
Add-NFGridColumn $movementGrid "MovementAfter" "SALDO DEPOIS" 100
Add-NFGridColumn $movementGrid "MovementStatus" "STATUS" 90
Add-NFGridColumn $movementGrid "MovementReference" "NF DE SAÍDA / REFERÊNCIA" 240 $true
$movementLayout.Controls.Add($movementGrid,0,1)
$movementFooter=New-Object Windows.Forms.TableLayoutPanel
$movementFooter.Dock=[Windows.Forms.DockStyle]::Fill; $movementFooter.ColumnCount=4
[void]$movementFooter.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent,100)))
[void]$movementFooter.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::AutoSize)))
[void]$movementFooter.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::AutoSize)))
[void]$movementFooter.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::AutoSize)))
$movementCountLabel=New-Object Windows.Forms.Label
$movementCountLabel.Text="0 movimentação(ões)"; $movementCountLabel.Dock=[Windows.Forms.DockStyle]::Fill; $movementCountLabel.TextAlign=[Drawing.ContentAlignment]::MiddleLeft; $movementCountLabel.ForeColor=$script:CurrentPalette.Muted
$movementFooter.Controls.Add($movementCountLabel,0,0)
$movementExportButton=New-Object Windows.Forms.Button
$movementExportButton.Text="CSV"; $movementExportButton.Width=72; $movementExportButton.Height=32; Set-NFButtonStyle $movementExportButton "Secondary"
$movementFooter.Controls.Add($movementExportButton,1,0)
$movementOpenButton=New-Object Windows.Forms.Button
$movementOpenButton.Text="IR PARA NF"; $movementOpenButton.Width=92; $movementOpenButton.Height=32; $movementOpenButton.Enabled=$false; Set-NFButtonStyle $movementOpenButton "Secondary"
$movementFooter.Controls.Add($movementOpenButton,2,0)
$movementReverseButton=New-Object Windows.Forms.Button
$movementReverseButton.Text="ESTORNAR"; $movementReverseButton.Width=96; $movementReverseButton.Height=32; $movementReverseButton.Enabled=$false; Set-NFButtonStyle $movementReverseButton "Danger"
$movementFooter.Controls.Add($movementReverseButton,3,0)
$movementLayout.Controls.Add($movementFooter,0,2)
# HISTÓRICO — consulta auditável das alterações do módulo.
$historyLayout = New-Object Windows.Forms.TableLayoutPanel
$historyLayout.Dock = [Windows.Forms.DockStyle]::Fill
$historyLayout.Padding = [Windows.Forms.Padding]::new(10)
$historyLayout.RowCount = 3
[void]$historyLayout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 52)))
[void]$historyLayout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 100)))
[void]$historyLayout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 42)))
$historyTab.Controls.Add($historyLayout)
$historyFilters = New-Object Windows.Forms.TableLayoutPanel
$historyFilters.Dock = [Windows.Forms.DockStyle]::Fill
$historyFilters.ColumnCount = 7
[void]$historyFilters.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Absolute, 74)))
[void]$historyFilters.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 100)))
[void]$historyFilters.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Absolute, 52)))
[void]$historyFilters.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Absolute, 142)))
[void]$historyFilters.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Absolute, 62)))
[void]$historyFilters.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Absolute, 155)))
[void]$historyFilters.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Absolute, 120)))
$historyLayout.Controls.Add($historyFilters, 0, 0)
$historySearchLabel = New-Object Windows.Forms.Label
$historySearchLabel.Text = "Pesquisar"; $historySearchLabel.Dock = [Windows.Forms.DockStyle]::Fill; $historySearchLabel.TextAlign = [Drawing.ContentAlignment]::MiddleLeft; $historySearchLabel.ForeColor = $script:CurrentPalette.Muted
$historyFilters.Controls.Add($historySearchLabel, 0, 0)
$historyFilter = New-Object Windows.Forms.TextBox
$historyFilter.Dock = [Windows.Forms.DockStyle]::Fill; $historyFilter.Margin = [Windows.Forms.Padding]::new(0, 9, 12, 9); $historyFilter.BackColor = $script:CurrentPalette.Input; $historyFilter.ForeColor = $script:CurrentPalette.Text
$historyFilters.Controls.Add($historyFilter, 1, 0)
$historyTypeLabel = New-Object Windows.Forms.Label
$historyTypeLabel.Text = "Tipo"; $historyTypeLabel.Dock = [Windows.Forms.DockStyle]::Fill; $historyTypeLabel.TextAlign = [Drawing.ContentAlignment]::MiddleLeft; $historyTypeLabel.ForeColor = $script:CurrentPalette.Muted
$historyFilters.Controls.Add($historyTypeLabel, 2, 0)
$historyTypeFilter = New-Object Windows.Forms.ComboBox
$historyTypeFilter.DropDownStyle = [Windows.Forms.ComboBoxStyle]::DropDownList
[void]$historyTypeFilter.Items.AddRange(@("Todos", "Adição", "Edição", "Saída", "Estorno de saída", "Exclusão", "Importação", "Restauração", "Exportação"))
$historyTypeFilter.SelectedIndex = 0; $historyTypeFilter.Dock = [Windows.Forms.DockStyle]::Fill; $historyTypeFilter.Margin = [Windows.Forms.Padding]::new(0, 8, 8, 8); $historyTypeFilter.BackColor = $script:CurrentPalette.Input; $historyTypeFilter.ForeColor = $script:CurrentPalette.Text
$historyFilters.Controls.Add($historyTypeFilter, 3, 0)
$historyPeriodLabel = New-Object Windows.Forms.Label
$historyPeriodLabel.Text = "Período"; $historyPeriodLabel.Dock = [Windows.Forms.DockStyle]::Fill; $historyPeriodLabel.TextAlign = [Drawing.ContentAlignment]::MiddleLeft; $historyPeriodLabel.ForeColor = $script:CurrentPalette.Muted
$historyFilters.Controls.Add($historyPeriodLabel, 4, 0)
$historyPeriodFilter = New-Object Windows.Forms.ComboBox
$historyPeriodFilter.DropDownStyle = [Windows.Forms.ComboBoxStyle]::DropDownList
[void]$historyPeriodFilter.Items.AddRange(@("Todos", "Hoje", "Últimos 7 dias", "Últimos 30 dias"))
$historyPeriodFilter.SelectedIndex = 0; $historyPeriodFilter.Dock = [Windows.Forms.DockStyle]::Fill; $historyPeriodFilter.Margin = [Windows.Forms.Padding]::new(0, 8, 8, 8); $historyPeriodFilter.BackColor = $script:CurrentPalette.Input; $historyPeriodFilter.ForeColor = $script:CurrentPalette.Text
$historyFilters.Controls.Add($historyPeriodFilter, 5, 0)
$historyCountLabel = New-Object Windows.Forms.Label
$historyCountLabel.Text = "0 de 0"; $historyCountLabel.Dock = [Windows.Forms.DockStyle]::Fill; $historyCountLabel.TextAlign = [Drawing.ContentAlignment]::MiddleRight; $historyCountLabel.ForeColor = $script:CurrentPalette.Muted
$historyFilters.Controls.Add($historyCountLabel, 6, 0)
$historyGrid = New-NFGrid
$historyIdCol = New-Object Windows.Forms.DataGridViewTextBoxColumn
$historyIdCol.Name = "HistoryId"; $historyIdCol.Visible = $false; [void]$historyGrid.Columns.Add($historyIdCol)
Add-NFGridColumn $historyGrid "HistoryDate" "DATA / HORA" 145
Add-NFGridColumn $historyGrid "HistoryType" "AÇÃO" 105
Add-NFGridColumn $historyGrid "HistoryProduct" "PRODUTO" 190
Add-NFGridColumn $historyGrid "HistoryNF" "NF" 105
Add-NFGridColumn $historyGrid "HistoryDetails" "DETALHES" 260 $true
$historyLayout.Controls.Add($historyGrid, 0, 1)
$historyButtons = New-Object Windows.Forms.FlowLayoutPanel
$historyButtons.Dock = [Windows.Forms.DockStyle]::Fill; $historyButtons.FlowDirection = [Windows.Forms.FlowDirection]::RightToLeft
$historyDetailsButton = New-Object Windows.Forms.Button
$historyDetailsButton.Text = "DETALHES"; $historyDetailsButton.Width = 96; $historyDetailsButton.Height = 32; $historyDetailsButton.Enabled = $false; Set-NFButtonStyle $historyDetailsButton "Secondary"
$historyExportButton = New-Object Windows.Forms.Button
$historyExportButton.Text = "CSV"; $historyExportButton.Width = 72; $historyExportButton.Height = 32; Set-NFButtonStyle $historyExportButton "Secondary"
$historyButtons.Controls.Add($historyDetailsButton); $historyButtons.Controls.Add($historyExportButton); $historyLayout.Controls.Add($historyButtons, 0, 2)

# SEGURANÇA — backups internos e restauração protegida.
$securityLayout = New-Object Windows.Forms.TableLayoutPanel
$securityLayout.Dock = [Windows.Forms.DockStyle]::Fill; $securityLayout.Padding = [Windows.Forms.Padding]::new(10); $securityLayout.RowCount = 3
[void]$securityLayout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 72)))
[void]$securityLayout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 100)))
[void]$securityLayout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 46)))
$securityTab.Controls.Add($securityLayout)
$securityInfo = New-Object Windows.Forms.Label
$securityInfo.Text = "Os backups guardam a base e o modelo Excel. O sistema mantém no máximo 20 backups automáticos; backups manuais e de recuperação não são removidos por essa retenção. Antes de restaurar, o estado atual é protegido."
$securityInfo.Dock = [Windows.Forms.DockStyle]::Fill; $securityInfo.ForeColor = $script:CurrentPalette.Muted; $securityInfo.Font = [Drawing.Font]::new("Segoe UI", 9)
$securityLayout.Controls.Add($securityInfo, 0, 0)
$backupGrid = New-NFGrid
$backupDirCol = New-Object Windows.Forms.DataGridViewTextBoxColumn
$backupDirCol.Name = "BackupDirectory"; $backupDirCol.Visible = $false; [void]$backupGrid.Columns.Add($backupDirCol)
Add-NFGridColumn $backupGrid "BackupDate" "DATA / HORA" 145
Add-NFGridColumn $backupGrid "BackupReason" "MOTIVO" 180
Add-NFGridColumn $backupGrid "BackupRecords" "REGISTROS" 85
Add-NFGridColumn $backupGrid "BackupContent" "CONTEÚDO" 130
Add-NFGridColumn $backupGrid "BackupStatus" "SITUAÇÃO" 100 $true
$securityLayout.Controls.Add($backupGrid, 0, 1)
$securityActions = New-Object Windows.Forms.TableLayoutPanel
$securityActions.Dock = [Windows.Forms.DockStyle]::Fill; $securityActions.ColumnCount = 2
[void]$securityActions.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 100)))
[void]$securityActions.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::AutoSize)))
$backupCountLabel = New-Object Windows.Forms.Label
$backupCountLabel.Text = "0 backup(s) disponível(is)"; $backupCountLabel.Dock = [Windows.Forms.DockStyle]::Fill; $backupCountLabel.TextAlign = [Drawing.ContentAlignment]::MiddleLeft; $backupCountLabel.ForeColor = $script:CurrentPalette.Muted
$securityActions.Controls.Add($backupCountLabel, 0, 0)
$backupButtons = New-Object Windows.Forms.FlowLayoutPanel
$backupButtons.AutoSize = $true; $backupButtons.WrapContents = $false; $backupButtons.FlowDirection = [Windows.Forms.FlowDirection]::LeftToRight
$integrityButton = New-Object Windows.Forms.Button
$integrityButton.Text = "VERIFICAR"; $integrityButton.Width = 100; $integrityButton.Height = 32; Set-NFButtonStyle $integrityButton "Secondary"
$manualBackupButton = New-Object Windows.Forms.Button
$manualBackupButton.Text = "NOVO BACKUP"; $manualBackupButton.Width = 108; $manualBackupButton.Height = 32; Set-NFButtonStyle $manualBackupButton "Secondary"
$restoreBackupButton = New-Object Windows.Forms.Button
$restoreBackupButton.Text = "RESTAURAR"; $restoreBackupButton.Width = 105; $restoreBackupButton.Height = 32; $restoreBackupButton.Enabled = $false; Set-NFButtonStyle $restoreBackupButton "Primary"
$backupButtons.Controls.Add($integrityButton); $backupButtons.Controls.Add($manualBackupButton); $backupButtons.Controls.Add($restoreBackupButton)
$securityActions.Controls.Add($backupButtons, 1, 0); $securityLayout.Controls.Add($securityActions, 0, 2)

$computerGrid = $null; $computerFilter = $null; $computerStatusFilter = $null; $computerCodeFilter = $null; $computerCountLabel = $null
$keyboardGrid = $null; $keyboardFilter = $null; $keyboardStatusFilter = $null; $keyboardCodeFilter = $null; $keyboardCountLabel = $null
New-ProductTabContent -Tab $computerTab -GridRef ([ref]$computerGrid) -FilterRef ([ref]$computerFilter) -StatusRef ([ref]$computerStatusFilter) -CodeRef ([ref]$computerCodeFilter) -CountRef ([ref]$computerCountLabel)
New-ProductTabContent -Tab $keyboardTab -GridRef ([ref]$keyboardGrid) -FilterRef ([ref]$keyboardFilter) -StatusRef ([ref]$keyboardStatusFilter) -CodeRef ([ref]$keyboardCodeFilter) -CountRef ([ref]$keyboardCountLabel)

# Barra de ações dentro das abas de produto.
$actionPanel = New-Object Windows.Forms.FlowLayoutPanel
$actionPanel.AutoSize = $true
$actionPanel.WrapContents = $false
$actionPanel.FlowDirection = [Windows.Forms.FlowDirection]::LeftToRight
$actionPanel.BackColor = $script:CurrentPalette.Surface
$actionPanel.Padding = [Windows.Forms.Padding]::new(0, 1, 0, 1)
$actionPanel.Margin = [Windows.Forms.Padding]::new(0)
$newButton = New-Object Windows.Forms.Button
$newButton.Text = "+ NOVA NF"; $newButton.Width = 105; $newButton.Height = 34; Set-NFButtonStyle $newButton "Primary"
$editButton = New-Object Windows.Forms.Button
$editButton.Text = "EDITAR"; $editButton.Width = 82; $editButton.Height = 34; Set-NFButtonStyle $editButton "Secondary"
$outputButton = New-Object Windows.Forms.Button
$outputButton.Text = "SAÍDA"; $outputButton.Width = 78; $outputButton.Height = 34; Set-NFButtonStyle $outputButton "Secondary"
$clearFiltersButton = New-Object Windows.Forms.Button
$clearFiltersButton.Text = "FILTROS"; $clearFiltersButton.Width = 82; $clearFiltersButton.Height = 34; Set-NFButtonStyle $clearFiltersButton "Secondary"
$exportListButton = New-Object Windows.Forms.Button
$exportListButton.Text = "CSV"; $exportListButton.Width = 68; $exportListButton.Height = 34; Set-NFButtonStyle $exportListButton "Secondary"
$deleteButton = New-Object Windows.Forms.Button
$deleteButton.Text = "EXCLUIR"; $deleteButton.Width = 82; $deleteButton.Height = 34; Set-NFButtonStyle $deleteButton "Danger"
$actionPanel.Controls.Add($newButton); $actionPanel.Controls.Add($editButton); $actionPanel.Controls.Add($outputButton); $actionPanel.Controls.Add($clearFiltersButton); $actionPanel.Controls.Add($exportListButton); $actionPanel.Controls.Add($deleteButton)
# A barra fica no rodapé geral e é ativada somente nas abas de produto.
$footerHost = New-Object Windows.Forms.TableLayoutPanel
$footerHost.Dock = [Windows.Forms.DockStyle]::Fill
$footerHost.BackColor = $script:CurrentPalette.Surface
$footerHost.Padding = [Windows.Forms.Padding]::new(8, 8, 8, 8)
$footerHost.Margin = [Windows.Forms.Padding]::new(0)
$footerHost.ColumnCount = 2
[void]$footerHost.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 100)))
[void]$footerHost.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::AutoSize)))
$root.Controls.Add($footerHost, 0, 3)
$footerStatus = New-Object Windows.Forms.Label
$footerStatus.Dock = [Windows.Forms.DockStyle]::Fill
$footerStatus.TextAlign = [Drawing.ContentAlignment]::MiddleLeft
$footerStatus.ForeColor = $script:CurrentPalette.Muted
$footerStatus.Font = [Drawing.Font]::new("Segoe UI", 8)
$footerHost.Controls.Add($footerStatus, 0, 0)
$footerHost.Controls.Add($actionPanel, 1, 0)

function Update-NFActions {
    $product = Get-SelectedProduct
    $enabled = -not [string]::IsNullOrWhiteSpace($product)
    $actionPanel.Visible = $enabled
    $newButton.Enabled = $enabled
    $exportListButton.Enabled = $enabled
    $hasSelection = $false
    if ($enabled) {
        $grid = if ($product -eq $script:ComputerProduct) { $computerGrid } else { $keyboardGrid }
        $hasSelection = ($null -ne $grid -and $grid.SelectedRows.Count -gt 0)
    }
    $editButton.Enabled = $hasSelection
    $deleteButton.Enabled = $hasSelection
    $canOutput = $false
    if ($hasSelection) {
        $id = Get-SelectedRecordId $grid
        $selected = Find-NFRecordById -Product $product -Id $id
        $canOutput = ($null -ne $selected -and [int]$selected.QuantidadeSaldo -gt 0)
    }
    $outputButton.Enabled = $canOutput
}

$toolTip = New-Object Windows.Forms.ToolTip
$toolTip.AutoPopDelay = 8000
$toolTip.InitialDelay = 350
$toolTip.SetToolTip($newButton, "Nova NF (Ctrl+N).")
$toolTip.SetToolTip($editButton, "Editar a NF selecionada (Enter ou duplo clique).")
$toolTip.SetToolTip($outputButton, "Registrar saída da NF selecionada (Ctrl+S).")
$toolTip.SetToolTip($clearFiltersButton, "Limpa pesquisa, status e código; volta para Em estoque.")
$toolTip.SetToolTip($exportListButton, "Exporta a visão atual em CSV (Ctrl+E). Diferente do Excel oficial completo.")
$toolTip.SetToolTip($deleteButton, "Excluir o registro selecionado; o Histórico é preservado.")
$toolTip.SetToolTip($movementReverseButton, "Estorna a saída ativa sem apagar a movimentação original (Ctrl+Z).")
$toolTip.SetToolTip($movementExportButton, "Exporta somente as movimentações visíveis com os filtros atuais para CSV compatível com Excel.")
$toolTip.SetToolTip($historyExportButton, "Exporta somente os eventos visíveis do Histórico para CSV compatível com Excel.")
$toolTip.SetToolTip($integrityButton, "Audita base, duplicidades, pendências, modelo Excel, backups e arquivos temporários.")

$computerFilter.Add_TextChanged({ Refresh-NFProductGrid -Product $script:ComputerProduct -Grid $computerGrid -FilterBox $computerFilter -StatusFilter $computerStatusFilter -CodeFilter $computerCodeFilter -CountLabel $computerCountLabel })
$computerFilter.Add_KeyDown({ if ($_.KeyCode -eq [Windows.Forms.Keys]::Escape) { $_.SuppressKeyPress=$true; $computerFilter.Clear() } })
$computerStatusFilter.Add_SelectedIndexChanged({ Refresh-NFProductGrid -Product $script:ComputerProduct -Grid $computerGrid -FilterBox $computerFilter -StatusFilter $computerStatusFilter -CodeFilter $computerCodeFilter -CountLabel $computerCountLabel })
$computerCodeFilter.Add_SelectedIndexChanged({ Refresh-NFProductGrid -Product $script:ComputerProduct -Grid $computerGrid -FilterBox $computerFilter -StatusFilter $computerStatusFilter -CodeFilter $computerCodeFilter -CountLabel $computerCountLabel })
$keyboardFilter.Add_TextChanged({ Refresh-NFProductGrid -Product $script:KeyboardProduct -Grid $keyboardGrid -FilterBox $keyboardFilter -StatusFilter $keyboardStatusFilter -CodeFilter $keyboardCodeFilter -CountLabel $keyboardCountLabel })
$keyboardFilter.Add_KeyDown({ if ($_.KeyCode -eq [Windows.Forms.Keys]::Escape) { $_.SuppressKeyPress=$true; $keyboardFilter.Clear() } })
$keyboardStatusFilter.Add_SelectedIndexChanged({ Refresh-NFProductGrid -Product $script:KeyboardProduct -Grid $keyboardGrid -FilterBox $keyboardFilter -StatusFilter $keyboardStatusFilter -CodeFilter $keyboardCodeFilter -CountLabel $keyboardCountLabel })
$keyboardCodeFilter.Add_SelectedIndexChanged({ Refresh-NFProductGrid -Product $script:KeyboardProduct -Grid $keyboardGrid -FilterBox $keyboardFilter -StatusFilter $keyboardStatusFilter -CodeFilter $keyboardCodeFilter -CountLabel $keyboardCountLabel })
$computerGrid.Add_CellDoubleClick({ if ($_.RowIndex -ge 0) { Edit-NFRecordFromUI } })
$computerGrid.Add_KeyDown({ if ($_.Control -and $_.KeyCode -eq [Windows.Forms.Keys]::N) { $_.SuppressKeyPress=$true; Add-NFRecordFromUI } elseif ($_.Control -and $_.KeyCode -eq [Windows.Forms.Keys]::S) { $_.SuppressKeyPress=$true; Register-NFOutputFromUI } elseif ($_.Control -and $_.KeyCode -eq [Windows.Forms.Keys]::E) { $_.SuppressKeyPress=$true; Export-NFCurrentProductViewToCsv } elseif ($_.KeyCode -eq [Windows.Forms.Keys]::Enter) { $_.SuppressKeyPress=$true; Edit-NFRecordFromUI } elseif ($_.Control -and $_.KeyCode -eq [Windows.Forms.Keys]::F) { $_.SuppressKeyPress=$true; $computerFilter.Focus() } })
$keyboardGrid.Add_CellDoubleClick({ if ($_.RowIndex -ge 0) { Edit-NFRecordFromUI } })
$keyboardGrid.Add_KeyDown({ if ($_.Control -and $_.KeyCode -eq [Windows.Forms.Keys]::N) { $_.SuppressKeyPress=$true; Add-NFRecordFromUI } elseif ($_.Control -and $_.KeyCode -eq [Windows.Forms.Keys]::S) { $_.SuppressKeyPress=$true; Register-NFOutputFromUI } elseif ($_.Control -and $_.KeyCode -eq [Windows.Forms.Keys]::E) { $_.SuppressKeyPress=$true; Export-NFCurrentProductViewToCsv } elseif ($_.KeyCode -eq [Windows.Forms.Keys]::Enter) { $_.SuppressKeyPress=$true; Edit-NFRecordFromUI } elseif ($_.Control -and $_.KeyCode -eq [Windows.Forms.Keys]::F) { $_.SuppressKeyPress=$true; $keyboardFilter.Focus() } })
$computerGrid.Add_SelectionChanged({ Update-NFActions })
$keyboardGrid.Add_SelectionChanged({ Update-NFActions })
$mainTabs.Add_SelectedIndexChanged({ Update-NFActions; if ($mainTabs.SelectedTab -eq $movementTab) { Refresh-NFMovements }; if ($mainTabs.SelectedTab -eq $historyTab) { Refresh-NFHistory }; if ($mainTabs.SelectedTab -eq $securityTab) { Refresh-NFBackups } })
$movementFilter.Add_TextChanged({ Refresh-NFMovements })
$movementFilter.Add_KeyDown({ if ($_.KeyCode -eq [Windows.Forms.Keys]::Escape) { $_.SuppressKeyPress=$true; $movementFilter.Clear() } })
$movementProductFilter.Add_SelectedIndexChanged({ Refresh-NFMovements })
$movementPeriodFilter.Add_SelectedIndexChanged({ Refresh-NFMovements })
$movementGrid.Add_SelectionChanged({
    $movementOpenButton.Enabled = ($movementGrid.SelectedRows.Count -gt 0)
    $movementReverseButton.Enabled = ($movementGrid.SelectedRows.Count -gt 0 -and [string]$movementGrid.SelectedRows[0].Cells["MovementStatus"].Value -eq "Ativa")
})
$movementGrid.Add_CellDoubleClick({ if ($_.RowIndex -ge 0) { Open-NFFromMovement } })
$movementGrid.Add_KeyDown({ if ($_.Control -and $_.KeyCode -eq [Windows.Forms.Keys]::Z) { $_.SuppressKeyPress=$true; Reverse-NFMovementFromUI } })
$movementExportButton.Add_Click({ Export-NFGridViewToCsv -Grid $movementGrid -BaseName "Movimentacoes-NF-Entrada" -Title "Movimentações" })
$movementOpenButton.Add_Click({ Open-NFFromMovement })
$movementReverseButton.Add_Click({ Reverse-NFMovementFromUI })
$reviewIssuesButton.Add_Click({ Show-NFReviewIssues })
$exportCheckButton.Add_Click({ Show-NFExportReadiness })
$historyFilter.Add_TextChanged({ Refresh-NFHistory })
$historyFilter.Add_KeyDown({ if ($_.KeyCode -eq [Windows.Forms.Keys]::Escape) { $_.SuppressKeyPress=$true; $historyFilter.Clear() } })
$historyTypeFilter.Add_SelectedIndexChanged({ Refresh-NFHistory })
$historyPeriodFilter.Add_SelectedIndexChanged({ Refresh-NFHistory })
$historyGrid.Add_SelectionChanged({ $historyDetailsButton.Enabled = ($historyGrid.SelectedRows.Count -gt 0) })
$historyGrid.Add_CellDoubleClick({ if ($_.RowIndex -ge 0) { Show-NFHistoryDetails } })
$historyExportButton.Add_Click({ Export-NFGridViewToCsv -Grid $historyGrid -BaseName "Historico-NF-Entrada" -Title "Histórico" })
$historyDetailsButton.Add_Click({ Show-NFHistoryDetails })
$backupGrid.Add_SelectionChanged({ $restoreBackupButton.Enabled = ($backupGrid.SelectedRows.Count -gt 0 -and [string]$backupGrid.SelectedRows[0].Cells["BackupStatus"].Value -eq "Pronto") })
$integrityButton.Add_Click({ Show-NFIntegrityReport })
$manualBackupButton.Add_Click({ New-NFManualBackupFromUI })
$restoreBackupButton.Add_Click({ Restore-NFBackupFromUI })
$newButton.Add_Click({ Add-NFRecordFromUI })
$editButton.Add_Click({ Edit-NFRecordFromUI })
$outputButton.Add_Click({ Register-NFOutputFromUI })
$clearFiltersButton.Add_Click({ Clear-NFCurrentProductFilters })
$exportListButton.Add_Click({ Export-NFCurrentProductViewToCsv })
$deleteButton.Add_Click({ Remove-NFRecordFromUI })
$importButton.Add_Click({ [void](Import-NFSourceFromUI) })
$exportButton.Add_Click({ Export-NFFromUI })

Refresh-NFAll
Update-NFActions

$localTemplatePath = Get-NFEntradaTemplatePath -DataDirectory $script:DataDirectory
if (-not [IO.File]::Exists($localTemplatePath)) {
    $answer = [Windows.Forms.MessageBox]::Show(
        "Este é o primeiro uso do Controle de NF de Entrada.

Selecione a planilha original que você já usa para importar todos os registros e guardá-la como modelo oficial de exportação.

Deseja selecionar agora?",
        "Configuração inicial",
        [Windows.Forms.MessageBoxButtons]::YesNo,
        [Windows.Forms.MessageBoxIcon]::Information
    )
    if ($answer -eq [Windows.Forms.DialogResult]::Yes) { [void](Import-NFSourceFromUI) }
}

function Set-HostedNFEntradaTheme {
    param([string]$Theme)
    if ([string]::IsNullOrWhiteSpace($Theme)) { return }

    $oldPalette = $script:CurrentPalette
    $newPalette = Get-NFEntradaPalette $Theme
    if ($null -eq $newPalette) { return }

    $mapColor = {
        param([Drawing.Color]$Color)
        if ($null -eq $oldPalette) { return $Color }
        $pairs = @(
            @($oldPalette.Background, $newPalette.Background),
            @($oldPalette.Surface, $newPalette.Surface),
            @($oldPalette.Card, $newPalette.Card),
            @($oldPalette.Input, $newPalette.Input),
            @($oldPalette.Text, $newPalette.Text),
            @($oldPalette.Muted, $newPalette.Muted),
            @($oldPalette.Border, $newPalette.Border),
            @($oldPalette.Accent, $newPalette.Accent),
            @($oldPalette.AccentStrong, $newPalette.AccentStrong),
            @($oldPalette.AccentText, $newPalette.AccentText),
            @($oldPalette.Success, $newPalette.Success),
            @($oldPalette.SuccessBack, $newPalette.SuccessBack),
            @($oldPalette.Warning, $newPalette.Warning),
            @($oldPalette.WarningBack, $newPalette.WarningBack),
            @($oldPalette.Danger, $newPalette.Danger),
            @($oldPalette.DangerBack, $newPalette.DangerBack)
        )
        foreach ($pair in $pairs) {
            try {
                if ($Color.ToArgb() -eq $pair[0].ToArgb()) { return $pair[1] }
            } catch {}
        }
        return $Color
    }.GetNewClosure()

    $script:CurrentPalette = $newPalette

    if ($null -ne $form -and -not $form.IsDisposed) {
        $stack = New-Object System.Collections.Stack
        $stack.Push($form)
        while ($stack.Count -gt 0) {
            $control = $stack.Pop()
            try { $control.BackColor = & $mapColor $control.BackColor } catch {}
            try { $control.ForeColor = & $mapColor $control.ForeColor } catch {}

            if ($control -is [Windows.Forms.Button]) {
                try { $control.FlatAppearance.BorderColor = & $mapColor $control.FlatAppearance.BorderColor } catch {}
            }
            elseif ($control -is [Windows.Forms.DataGridView]) {
                try {
                    $control.BackgroundColor = $newPalette.Surface
                    $control.GridColor = $newPalette.Border
                    $control.ColumnHeadersDefaultCellStyle.BackColor = $newPalette.Surface
                    $control.ColumnHeadersDefaultCellStyle.ForeColor = $newPalette.Text
                    $control.DefaultCellStyle.BackColor = $newPalette.Surface
                    $control.DefaultCellStyle.ForeColor = $newPalette.Text
                    $control.DefaultCellStyle.SelectionBackColor = $newPalette.AccentStrong
                    $control.DefaultCellStyle.SelectionForeColor = $newPalette.AccentText
                } catch {}
            }
            elseif ($control -is [Windows.Forms.TextBoxBase] -or
                    $control -is [Windows.Forms.ComboBox] -or
                    $control -is [Windows.Forms.NumericUpDown] -or
                    $control -is [Windows.Forms.DateTimePicker]) {
                try { $control.BackColor = $newPalette.Input; $control.ForeColor = $newPalette.Text } catch {}
            }

            try {
                foreach ($child in @($control.Controls)) { $stack.Push($child) }
            } catch {}
        }
    }

    foreach ($backgroundControl in @(
        $form, $root, $header, $heading, $cards,
        $computerTab, $keyboardTab, $movementTab, $historyTab, $securityTab, $summaryTab,
        $summaryLayout, $movementLayout, $historyLayout, $securityLayout
    )) {
        try { if ($null -ne $backgroundControl) { $backgroundControl.BackColor = $newPalette.Background; $backgroundControl.ForeColor = $newPalette.Text } } catch {}
    }

    try { $footerHost.BackColor = $newPalette.Surface } catch {}
    try { $actionPanel.BackColor = $newPalette.Surface } catch {}
    try { $lastPanel.BackColor = $newPalette.Card } catch {}
    try { $summaryActionPanel.BackColor = $newPalette.Card } catch {}
    try {
        foreach ($card in @($cards.Controls)) {
            if ($card -is [Windows.Forms.Panel]) { $card.BackColor = $newPalette.Card; $card.ForeColor = $newPalette.Text }
        }
    } catch {}

    # Recria as linhas para reaplicar cores de status e destaques com a paleta nova.
    try { Refresh-NFAll } catch {}
    try { Update-NFActions } catch {}
    try { $form.PerformLayout() } catch {}
    try { $form.Invalidate($true); $form.Refresh() } catch {}
}

if ($script:IsInProcessHosted) {
    $script:HostedControlExport = $form
    $script:HostedFormExport = $null
}
else {
    try { [void]$form.ShowDialog() }
    finally { try { $form.Dispose() } catch {} }
}

# Contratos visuais legados preservados para a regressão automatizada.
# Estes nomes não são exibidos na interface; documentam equivalências após o polimento 2.4.1:
# IMPORTAR PLANILHA -> IMPORTAR EXCEL
# EXPORTAR EXCEL -> EXCEL OFICIAL
# EDITAR SELEÇÃO -> EDITAR
# VER DETALHES -> DETALHES
# CRIAR BACKUP AGORA -> NOVO BACKUP
# RESTAURAR SELECIONADO -> RESTAURAR
# VER PENDÊNCIAS -> PENDÊNCIAS

