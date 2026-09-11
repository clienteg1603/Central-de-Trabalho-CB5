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
$script:ModuleVersion = "1.0.0"
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
                Accent = [Drawing.Color]::FromArgb(96, 86, 196)
                AccentStrong = [Drawing.Color]::FromArgb(76, 67, 174)
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
                Accent = [Drawing.Color]::FromArgb(151, 112, 255)
                AccentStrong = [Drawing.Color]::FromArgb(122, 88, 226)
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
                Accent = [Drawing.Color]::Fuchsia
                AccentStrong = [Drawing.Color]::Fuchsia
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
                Accent = [Drawing.Color]::FromArgb(139, 111, 255)
                AccentStrong = [Drawing.Color]::FromArgb(111, 82, 226)
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
            $Button.BackColor = $script:CurrentPalette.Surface
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
    $grid.ColumnHeadersDefaultCellStyle.BackColor = $script:CurrentPalette.Surface
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

function Format-NFDate {
    param([string]$Text)
    $date = [DateTime]::MinValue
    if ([DateTime]::TryParseExact($Text, "yyyy-MM-dd", [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::None, [ref]$date)) {
        return $date.ToString("dd/MM/yyyy")
    }
    return $Text
}

function Refresh-NFProductGrid {
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

function Refresh-NFSummary {
    $summary = Get-NFEntradaSummary -Store $script:Store
    $saldoTotalValue.Text = ([int]$summary.SaldoTotal).ToString("N0")
    $computerBalanceValue.Text = ([int]$summary.Produtos[$script:ComputerProduct].Saldo).ToString("N0")
    $keyboardBalanceValue.Text = ([int]$summary.Produtos[$script:KeyboardProduct].Saldo).ToString("N0")
    $openNFsValue.Text = ([int]$summary.NFsAbertas).ToString("N0")

    $productSummaryGrid.Rows.Clear()
    [void]$productSummaryGrid.Rows.Add("Computador de bordo V5", [int]$summary.Produtos[$script:ComputerProduct].NFsAbertas, [int]$summary.Produtos[$script:ComputerProduct].Saldo)
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
}

function Refresh-NFAll {
    Refresh-NFSummary
    Refresh-NFProductGrid -Product $script:ComputerProduct -Grid $computerGrid -FilterBox $computerFilter
    Refresh-NFProductGrid -Product $script:KeyboardProduct -Grid $keyboardGrid -FilterBox $keyboardFilter
    $footerStatus.Text = "Base local: $($script:DatabasePath)"
}

function Show-NFRecordDialog {
    param([string]$Product, $Existing = $null)
    $dialog = New-Object Windows.Forms.Form
    $dialog.Text = if ($null -eq $Existing) { "Novo registro — $Product" } else { "Editar registro — $Product" }
    $dialog.StartPosition = [Windows.Forms.FormStartPosition]::CenterParent
    $dialog.FormBorderStyle = [Windows.Forms.FormBorderStyle]::FixedDialog
    $dialog.MaximizeBox = $false
    $dialog.MinimizeBox = $false
    $dialog.ShowInTaskbar = $false
    $dialog.ClientSize = [Drawing.Size]::new(620, 430)
    $dialog.BackColor = $script:CurrentPalette.Background
    $dialog.ForeColor = $script:CurrentPalette.Text

    $layout = New-Object Windows.Forms.TableLayoutPanel
    $layout.Dock = [Windows.Forms.DockStyle]::Fill
    $layout.Padding = [Windows.Forms.Padding]::new(18)
    $layout.ColumnCount = 2
    $layout.RowCount = 7
    [void]$layout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Absolute, 180)))
    [void]$layout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 100)))
    foreach ($i in 0..5) { [void]$layout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, $(if ($i -eq 5) { 112 } else { 44 })))) }
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

    $buttons = New-Object Windows.Forms.FlowLayoutPanel
    $buttons.FlowDirection = [Windows.Forms.FlowDirection]::RightToLeft
    $buttons.Dock = [Windows.Forms.DockStyle]::Fill
    $buttons.Padding = [Windows.Forms.Padding]::new(0, 12, 0, 0)
    $layout.SetColumnSpan($buttons, 2)
    $layout.Controls.Add($buttons, 0, 6)

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
        $datePicker.Value = [DateTime]::Today
        $codeCombo.SelectedItem = "800"
    }

    if ($dialog.ShowDialog() -ne [Windows.Forms.DialogResult]::OK) { $dialog.Dispose(); return $null }
    $result = [pscustomobject]@{
        Data = $datePicker.Value.ToString("yyyy-MM-dd")
        QuantidadeNaNF = [int]$qtyBox.Value
        NFEntrada = ([string]$nfBox.Text).Trim()
        QuantidadeSaldo = [int]$balanceBox.Value
        Codigo = [string]$codeCombo.SelectedItem
        NFSaida = ([string]$outBox.Text).Trim()
    }
    $dialog.Dispose()
    return $result
}

function Add-NFRecordFromUI {
    $product = Get-SelectedProduct
    if ([string]::IsNullOrWhiteSpace($product)) { return }
    $record = Show-NFRecordDialog -Product $product
    if ($null -eq $record) { return }
    try {
        [void](Add-NFEntradaRecord -Store $script:Store -Product $product -Record $record)
        Save-NFStore
        Refresh-NFAll
    }
    catch { [Windows.Forms.MessageBox]::Show($_.Exception.Message, "Controle de NF de Entrada", 0, 48) | Out-Null }
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
    }
    catch { [Windows.Forms.MessageBox]::Show($_.Exception.Message, "Controle de NF de Entrada", 0, 48) | Out-Null }
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
        "Excluir a NF de Entrada $($record.NFEntrada) de $product?`r`n`r`nEssa ação altera somente a base local do módulo e será refletida na próxima exportação.",
        "Confirmar exclusão",
        [Windows.Forms.MessageBoxButtons]::YesNo,
        [Windows.Forms.MessageBoxIcon]::Warning
    )
    if ($answer -ne [Windows.Forms.DialogResult]::Yes) { return }
    try {
        Remove-NFEntradaRecord -Store $script:Store -Product $product -Id $id
        Save-NFStore
        Refresh-NFAll
    }
    catch { [Windows.Forms.MessageBox]::Show($_.Exception.Message, "Controle de NF de Entrada", 0, 48) | Out-Null }
}

function Import-NFSourceFromUI {
    $dialog = New-Object Windows.Forms.OpenFileDialog
    $dialog.Title = "Selecionar planilha original de NF de Entrada"
    $dialog.Filter = "Planilha do Excel (*.xlsx)|*.xlsx"
    $dialog.Multiselect = $false
    if ($dialog.ShowDialog() -ne [Windows.Forms.DialogResult]::OK) { $dialog.Dispose(); return $false }
    $source = $dialog.FileName
    $dialog.Dispose()
    try {
        $result = Import-NFEntradaSourceWorkbook -SourcePath $source -DataDirectory $script:DataDirectory
        $script:DatabasePath = [string]$result.StorePath
        $script:Store = $result.Store
        Refresh-NFAll
        [Windows.Forms.MessageBox]::Show(
            "Planilha original importada com sucesso. A partir de agora o módulo usa uma cópia protegida como modelo de exportação e mantém os registros na base local.",
            "Controle de NF de Entrada",
            [Windows.Forms.MessageBoxButtons]::OK,
            [Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
        return $true
    }
    catch {
        [Windows.Forms.MessageBox]::Show($_.Exception.Message, "Falha ao importar planilha", 0, 16) | Out-Null
        return $false
    }
}

function Export-NFFromUI {
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
        [Windows.Forms.MessageBox]::Show(
            "Planilha exportada com o modelo original, fórmulas, resumo e formatação preservados.`r`n`r`n$exported",
            "Exportação concluída",
            [Windows.Forms.MessageBoxButtons]::OK,
            [Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
    }
    catch { [Windows.Forms.MessageBox]::Show($_.Exception.Message, "Falha na exportação", 0, 16) | Out-Null }
}

function New-NFSummaryCard {
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

function New-ProductTabContent {
    param([Windows.Forms.TabPage]$Tab, [ref]$GridRef, [ref]$FilterRef)
    $layout = New-Object Windows.Forms.TableLayoutPanel
    $layout.Dock = [Windows.Forms.DockStyle]::Fill
    $layout.Padding = [Windows.Forms.Padding]::new(10)
    $layout.RowCount = 2
    [void]$layout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 42)))
    [void]$layout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 100)))
    $Tab.Controls.Add($layout)

    $filterPanel = New-Object Windows.Forms.TableLayoutPanel
    $filterPanel.Dock = [Windows.Forms.DockStyle]::Fill
    $filterPanel.ColumnCount = 3
    [void]$filterPanel.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Absolute, 90)))
    [void]$filterPanel.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 100)))
    [void]$filterPanel.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Absolute, 220)))
    $layout.Controls.Add($filterPanel, 0, 0)

    $label = New-Object Windows.Forms.Label
    $label.Text = "Pesquisar"
    $label.Dock = [Windows.Forms.DockStyle]::Fill
    $label.TextAlign = [Drawing.ContentAlignment]::MiddleLeft
    $label.ForeColor = $script:CurrentPalette.Muted
    $filterPanel.Controls.Add($label, 0, 0)

    $filter = New-Object Windows.Forms.TextBox
    $filter.Dock = [Windows.Forms.DockStyle]::Fill
    $filter.Margin = [Windows.Forms.Padding]::new(0, 7, 10, 7)
    $filter.BackColor = $script:CurrentPalette.Input
    $filter.ForeColor = $script:CurrentPalette.Text
    $filterPanel.Controls.Add($filter, 1, 0)

    $legend = New-Object Windows.Forms.Label
    $legend.Text = "Verde: encerrada  •  Amarelo: em estoque  •  Vermelho: revisar"
    $legend.Dock = [Windows.Forms.DockStyle]::Fill
    $legend.TextAlign = [Drawing.ContentAlignment]::MiddleRight
    $legend.ForeColor = $script:CurrentPalette.Muted
    $legend.Font = [Drawing.Font]::new("Segoe UI", 8.3)
    $filterPanel.Controls.Add($legend, 2, 0)

    $grid = New-NFGrid
    $idCol = New-Object Windows.Forms.DataGridViewTextBoxColumn
    $idCol.Name = "Id"; $idCol.Visible = $false
    [void]$grid.Columns.Add($idCol)
    Add-NFGridColumn $grid "Data" "DATA" 92
    Add-NFGridColumn $grid "QuantidadeNaNF" "QUANTIDADE NA NF" 125
    Add-NFGridColumn $grid "NFEntrada" "NF DE ENTRADA" 115
    Add-NFGridColumn $grid "QuantidadeSaldo" "QUANTIDADE NO SALDO" 140
    Add-NFGridColumn $grid "Codigo" "CÓD" 78
    Add-NFGridColumn $grid "NFSaida" "NF DE SAÍDA" 260 $true
    $layout.Controls.Add($grid, 0, 1)
    $GridRef.Value = $grid
    $FilterRef.Value = $filter
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
[void]$root.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 72)))
[void]$root.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 100)))
[void]$root.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 100)))
[void]$root.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 30)))
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
[void]$heading.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 62)))
[void]$heading.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 38)))
$header.Controls.Add($heading, 0, 0)
$title = New-Object Windows.Forms.Label
$title.Text = "Controle de NF de Entrada"
$title.Dock = [Windows.Forms.DockStyle]::Fill
$title.TextAlign = [Drawing.ContentAlignment]::BottomLeft
$title.Font = [Drawing.Font]::new("Segoe UI Semibold", 20)
$title.ForeColor = $script:CurrentPalette.Text
$heading.Controls.Add($title, 0, 0)
$subtitle = New-Object Windows.Forms.Label
$subtitle.Text = "Computador de Bordo V5 e Teclado V5 • mesma regra e mesmo modelo da planilha original"
$subtitle.Dock = [Windows.Forms.DockStyle]::Fill
$subtitle.TextAlign = [Drawing.ContentAlignment]::TopLeft
$subtitle.ForeColor = $script:CurrentPalette.Muted
$heading.Controls.Add($subtitle, 0, 1)

$importButton = New-Object Windows.Forms.Button
$importButton.Text = "IMPORTAR PLANILHA"
$importButton.Dock = [Windows.Forms.DockStyle]::Fill
$importButton.Margin = [Windows.Forms.Padding]::new(10, 16, 0, 14)
Set-NFButtonStyle $importButton "Secondary"
$header.Controls.Add($importButton, 1, 0)

$exportButton = New-Object Windows.Forms.Button
$exportButton.Text = "EXPORTAR EXCEL"
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
$cards.Controls.Add((New-NFSummaryCard "SALDO TOTAL" ([ref]$saldoTotalValue)), 0, 0)
$cards.Controls.Add((New-NFSummaryCard "COMPUTADOR DE BORDO V5" ([ref]$computerBalanceValue)), 1, 0)
$cards.Controls.Add((New-NFSummaryCard "TECLADO V5" ([ref]$keyboardBalanceValue)), 2, 0)
$cards.Controls.Add((New-NFSummaryCard "NFs EM ABERTO" ([ref]$openNFsValue)), 3, 0)

$mainTabs = New-Object Windows.Forms.TabControl
$mainTabs.Dock = [Windows.Forms.DockStyle]::Fill
$mainTabs.Font = [Drawing.Font]::new("Segoe UI Semibold", 9)
$root.Controls.Add($mainTabs, 0, 2)

$summaryTab = New-Object Windows.Forms.TabPage
$summaryTab.Text = "RESUMO"
$summaryTab.BackColor = $script:CurrentPalette.Background
$mainTabs.TabPages.Add($summaryTab)
$computerTab = New-Object Windows.Forms.TabPage
$computerTab.Text = "COMPUTADOR DE BORDO V5"
$computerTab.BackColor = $script:CurrentPalette.Background
$mainTabs.TabPages.Add($computerTab)
$keyboardTab = New-Object Windows.Forms.TabPage
$keyboardTab.Text = "TECLADO V5"
$keyboardTab.BackColor = $script:CurrentPalette.Background
$mainTabs.TabPages.Add($keyboardTab)

$summaryLayout = New-Object Windows.Forms.TableLayoutPanel
$summaryLayout.Dock = [Windows.Forms.DockStyle]::Fill
$summaryLayout.Padding = [Windows.Forms.Padding]::new(10)
$summaryLayout.ColumnCount = 2
$summaryLayout.RowCount = 2
[void]$summaryLayout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 55)))
[void]$summaryLayout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 45)))
[void]$summaryLayout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 48)))
[void]$summaryLayout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 52)))
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
$conference.RowCount = 4
[void]$conference.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 70)))
[void]$conference.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 30)))
$conferenceGroup.Controls.Add($conference)
$missingDateValue = New-Object Windows.Forms.Label
$negativeValue = New-Object Windows.Forms.Label
$overEntryValue = New-Object Windows.Forms.Label
$generalStatusValue = New-Object Windows.Forms.Label
$conferenceRows = @(
    @("Datas ausentes", $missingDateValue),
    @("Saldos negativos", $negativeValue),
    @("Saldo maior que a entrada", $overEntryValue),
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
Add-NFGridColumn $codeSummaryGrid "Computador" "COMPUTADOR V5" 150
Add-NFGridColumn $codeSummaryGrid "Teclado" "TECLADO V5" 150
Add-NFGridColumn $codeSummaryGrid "Total" "TOTAL" 130 $true
$codeGroup.Controls.Add($codeSummaryGrid)

$computerGrid = $null; $computerFilter = $null
$keyboardGrid = $null; $keyboardFilter = $null
New-ProductTabContent -Tab $computerTab -GridRef ([ref]$computerGrid) -FilterRef ([ref]$computerFilter)
New-ProductTabContent -Tab $keyboardTab -GridRef ([ref]$keyboardGrid) -FilterRef ([ref]$keyboardFilter)

# Barra de ações dentro das abas de produto.
$actionPanel = New-Object Windows.Forms.FlowLayoutPanel
$actionPanel.AutoSize = $true
$actionPanel.WrapContents = $false
$actionPanel.FlowDirection = [Windows.Forms.FlowDirection]::LeftToRight
$actionPanel.BackColor = $script:CurrentPalette.Background
$newButton = New-Object Windows.Forms.Button
$newButton.Text = "+ NOVO REGISTRO"; $newButton.Width = 135; $newButton.Height = 32; Set-NFButtonStyle $newButton "Primary"
$editButton = New-Object Windows.Forms.Button
$editButton.Text = "EDITAR"; $editButton.Width = 90; $editButton.Height = 32; Set-NFButtonStyle $editButton "Secondary"
$deleteButton = New-Object Windows.Forms.Button
$deleteButton.Text = "EXCLUIR"; $deleteButton.Width = 90; $deleteButton.Height = 32; Set-NFButtonStyle $deleteButton "Danger"
$actionPanel.Controls.Add($newButton); $actionPanel.Controls.Add($editButton); $actionPanel.Controls.Add($deleteButton)
# A barra fica no rodapé geral e é ativada somente nas abas de produto.
$footerHost = New-Object Windows.Forms.TableLayoutPanel
$footerHost.Dock = [Windows.Forms.DockStyle]::Fill
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
    $enabled = -not [string]::IsNullOrWhiteSpace((Get-SelectedProduct))
    $actionPanel.Visible = $enabled
    $newButton.Enabled = $enabled
    $editButton.Enabled = $enabled
    $deleteButton.Enabled = $enabled
}

$computerFilter.Add_TextChanged({ Refresh-NFProductGrid -Product $script:ComputerProduct -Grid $computerGrid -FilterBox $computerFilter })
$keyboardFilter.Add_TextChanged({ Refresh-NFProductGrid -Product $script:KeyboardProduct -Grid $keyboardGrid -FilterBox $keyboardFilter })
$computerGrid.Add_CellDoubleClick({ if ($_.RowIndex -ge 0) { Edit-NFRecordFromUI } })
$keyboardGrid.Add_CellDoubleClick({ if ($_.RowIndex -ge 0) { Edit-NFRecordFromUI } })
$mainTabs.Add_SelectedIndexChanged({ Update-NFActions })
$newButton.Add_Click({ Add-NFRecordFromUI })
$editButton.Add_Click({ Edit-NFRecordFromUI })
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

if ($script:IsInProcessHosted) {
    $script:HostedControlExport = $form
    $script:HostedFormExport = $null
}
else {
    try { [void]$form.ShowDialog() }
    finally { try { $form.Dispose() } catch {} }
}
