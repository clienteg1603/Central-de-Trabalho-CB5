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
$script:ModuleVersion = "1.5.0"
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
    $events = @(Get-NFEntradaHistory -Store $script:Store)
    $shown = 0
    $historyGrid.Rows.Clear()
    foreach ($event in $events) {
        $label = switch ([string]$event.Tipo) {
            "Adicao" { "Adição" }
            "Edicao" { "Edição" }
            "Exclusao" { "Exclusão" }
            "Importacao" { "Importação" }
            "RestauracaoBackup" { "Restauração" }
            "Saida" { "Saída" }
            default { [string]$event.Tipo }
        }
        if ($type -ne "Todos" -and $label -ne $type) { continue }
        $search = (($label + " " + (Get-NFEntradaProductDisplayName ([string]$event.Produto)) + " " + [string]$event.NFEntrada + " " + [string]$event.Detalhes)).ToLowerInvariant()
        if (-not [string]::IsNullOrWhiteSpace($filter) -and -not $search.Contains($filter)) { continue }
        [void]$historyGrid.Rows.Add([string]$event.Id, (Format-NFHistoryDate ([string]$event.DataHora)), $label, (Get-NFEntradaProductDisplayName ([string]$event.Produto)), [string]$event.NFEntrada, [string]$event.Detalhes)
        $shown++
    }
    $historyCountLabel.Text = "$shown de $($events.Count)"
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
    $saldoTotalValue.Text = ([int]$summary.SaldoTotal).ToString("N0")
    $computerBalanceValue.Text = ([int]$summary.Produtos[$script:ComputerProduct].Saldo).ToString("N0")
    $keyboardBalanceValue.Text = ([int]$summary.Produtos[$script:KeyboardProduct].Saldo).ToString("N0")
    $openNFsValue.Text = ([int]$summary.NFsAbertas).ToString("N0")

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
    if ($mainTabs.SelectedTab -eq $historyTab) { Refresh-NFHistory }
    if ($mainTabs.SelectedTab -eq $securityTab) { Refresh-NFBackups }
    $templateReady = [IO.File]::Exists((Get-NFEntradaTemplatePath -DataDirectory $script:DataDirectory))
    $exportButton.Enabled = $templateReady
    $summary = Get-NFEntradaSummary -Store $script:Store
    $totalRecords = [int]$summary.Produtos[$script:ComputerProduct].Registros + [int]$summary.Produtos[$script:KeyboardProduct].Registros
    Set-NFStatus ("Pronto • " + $totalRecords + " registro(s) • abas operacionais iniciam em Em estoque") "Normal"
}

function Show-NFRecordDialog {
    param([string]$Product, $Existing = $null)
    $dialog = New-Object Windows.Forms.Form
    $displayProduct = Get-NFEntradaProductDisplayName $Product
    $dialog.Text = if ($null -eq $Existing) { "Novo registro — $displayProduct" } else { "Editar registro — $displayProduct" }
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
        Set-NFStatus ("Registro " + $record.NFEntrada + " incluído com sucesso.") "Success"
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
        Set-NFStatus "Planilha exportada com sucesso." "Success"
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
[void]$root.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 78)))
[void]$root.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 112)))
[void]$root.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 100)))
[void]$root.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 46)))
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
$subtitle.Text = "Saldos, NFs e exportação no mesmo padrão da planilha oficial"
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
$historyFilters.ColumnCount = 5
[void]$historyFilters.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Absolute, 74)))
[void]$historyFilters.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 100)))
[void]$historyFilters.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Absolute, 52)))
[void]$historyFilters.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Absolute, 142)))
[void]$historyFilters.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Absolute, 108)))
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
[void]$historyTypeFilter.Items.AddRange(@("Todos", "Adição", "Edição", "Saída", "Exclusão", "Importação", "Restauração"))
$historyTypeFilter.SelectedIndex = 0; $historyTypeFilter.Dock = [Windows.Forms.DockStyle]::Fill; $historyTypeFilter.Margin = [Windows.Forms.Padding]::new(0, 8, 8, 8); $historyTypeFilter.BackColor = $script:CurrentPalette.Input; $historyTypeFilter.ForeColor = $script:CurrentPalette.Text
$historyFilters.Controls.Add($historyTypeFilter, 3, 0)
$historyCountLabel = New-Object Windows.Forms.Label
$historyCountLabel.Text = "0 de 0"; $historyCountLabel.Dock = [Windows.Forms.DockStyle]::Fill; $historyCountLabel.TextAlign = [Drawing.ContentAlignment]::MiddleRight; $historyCountLabel.ForeColor = $script:CurrentPalette.Muted
$historyFilters.Controls.Add($historyCountLabel, 4, 0)
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
$historyDetailsButton.Text = "VER DETALHES"; $historyDetailsButton.Width = 125; $historyDetailsButton.Height = 32; $historyDetailsButton.Enabled = $false; Set-NFButtonStyle $historyDetailsButton "Secondary"
$historyButtons.Controls.Add($historyDetailsButton); $historyLayout.Controls.Add($historyButtons, 0, 2)

# SEGURANÇA — backups internos e restauração protegida.
$securityLayout = New-Object Windows.Forms.TableLayoutPanel
$securityLayout.Dock = [Windows.Forms.DockStyle]::Fill; $securityLayout.Padding = [Windows.Forms.Padding]::new(10); $securityLayout.RowCount = 3
[void]$securityLayout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 72)))
[void]$securityLayout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 100)))
[void]$securityLayout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 46)))
$securityTab.Controls.Add($securityLayout)
$securityInfo = New-Object Windows.Forms.Label
$securityInfo.Text = "Os backups guardam a base e, quando disponível, o modelo Excel. Antes de restaurar um backup, o estado atual é salvo automaticamente em outra cópia de segurança."
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
$manualBackupButton = New-Object Windows.Forms.Button
$manualBackupButton.Text = "CRIAR BACKUP AGORA"; $manualBackupButton.Width = 150; $manualBackupButton.Height = 32; Set-NFButtonStyle $manualBackupButton "Secondary"
$restoreBackupButton = New-Object Windows.Forms.Button
$restoreBackupButton.Text = "RESTAURAR SELECIONADO"; $restoreBackupButton.Width = 175; $restoreBackupButton.Height = 32; $restoreBackupButton.Enabled = $false; Set-NFButtonStyle $restoreBackupButton "Primary"
$backupButtons.Controls.Add($manualBackupButton); $backupButtons.Controls.Add($restoreBackupButton)
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
$actionPanel.Padding = [Windows.Forms.Padding]::new(0, 3, 0, 0)
$newButton = New-Object Windows.Forms.Button
$newButton.Text = "+ NOVO REGISTRO"; $newButton.Width = 145; $newButton.Height = 34; Set-NFButtonStyle $newButton "Primary"
$editButton = New-Object Windows.Forms.Button
$editButton.Text = "EDITAR SELEÇÃO"; $editButton.Width = 125; $editButton.Height = 34; Set-NFButtonStyle $editButton "Secondary"
$outputButton = New-Object Windows.Forms.Button
$outputButton.Text = "REGISTRAR SAÍDA"; $outputButton.Width = 135; $outputButton.Height = 34; Set-NFButtonStyle $outputButton "Secondary"
$deleteButton = New-Object Windows.Forms.Button
$deleteButton.Text = "EXCLUIR"; $deleteButton.Width = 95; $deleteButton.Height = 34; Set-NFButtonStyle $deleteButton "Danger"
$actionPanel.Controls.Add($newButton); $actionPanel.Controls.Add($editButton); $actionPanel.Controls.Add($outputButton); $actionPanel.Controls.Add($deleteButton)
# A barra fica no rodapé geral e é ativada somente nas abas de produto.
$footerHost = New-Object Windows.Forms.TableLayoutPanel
$footerHost.Dock = [Windows.Forms.DockStyle]::Fill
$footerHost.BackColor = $script:CurrentPalette.Surface
$footerHost.Padding = [Windows.Forms.Padding]::new(8, 3, 8, 3)
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

$computerFilter.Add_TextChanged({ Refresh-NFProductGrid -Product $script:ComputerProduct -Grid $computerGrid -FilterBox $computerFilter -StatusFilter $computerStatusFilter -CodeFilter $computerCodeFilter -CountLabel $computerCountLabel })
$computerStatusFilter.Add_SelectedIndexChanged({ Refresh-NFProductGrid -Product $script:ComputerProduct -Grid $computerGrid -FilterBox $computerFilter -StatusFilter $computerStatusFilter -CodeFilter $computerCodeFilter -CountLabel $computerCountLabel })
$computerCodeFilter.Add_SelectedIndexChanged({ Refresh-NFProductGrid -Product $script:ComputerProduct -Grid $computerGrid -FilterBox $computerFilter -StatusFilter $computerStatusFilter -CodeFilter $computerCodeFilter -CountLabel $computerCountLabel })
$keyboardFilter.Add_TextChanged({ Refresh-NFProductGrid -Product $script:KeyboardProduct -Grid $keyboardGrid -FilterBox $keyboardFilter -StatusFilter $keyboardStatusFilter -CodeFilter $keyboardCodeFilter -CountLabel $keyboardCountLabel })
$keyboardStatusFilter.Add_SelectedIndexChanged({ Refresh-NFProductGrid -Product $script:KeyboardProduct -Grid $keyboardGrid -FilterBox $keyboardFilter -StatusFilter $keyboardStatusFilter -CodeFilter $keyboardCodeFilter -CountLabel $keyboardCountLabel })
$keyboardCodeFilter.Add_SelectedIndexChanged({ Refresh-NFProductGrid -Product $script:KeyboardProduct -Grid $keyboardGrid -FilterBox $keyboardFilter -StatusFilter $keyboardStatusFilter -CodeFilter $keyboardCodeFilter -CountLabel $keyboardCountLabel })
$computerGrid.Add_CellDoubleClick({ if ($_.RowIndex -ge 0) { Edit-NFRecordFromUI } })
$computerGrid.Add_KeyDown({ if ($_.Control -and $_.KeyCode -eq [Windows.Forms.Keys]::N) { $_.SuppressKeyPress=$true; Add-NFRecordFromUI } elseif ($_.KeyCode -eq [Windows.Forms.Keys]::Enter) { $_.SuppressKeyPress=$true; Edit-NFRecordFromUI } elseif ($_.Control -and $_.KeyCode -eq [Windows.Forms.Keys]::F) { $_.SuppressKeyPress=$true; $computerFilter.Focus() } })
$keyboardGrid.Add_CellDoubleClick({ if ($_.RowIndex -ge 0) { Edit-NFRecordFromUI } })
$keyboardGrid.Add_KeyDown({ if ($_.Control -and $_.KeyCode -eq [Windows.Forms.Keys]::N) { $_.SuppressKeyPress=$true; Add-NFRecordFromUI } elseif ($_.KeyCode -eq [Windows.Forms.Keys]::Enter) { $_.SuppressKeyPress=$true; Edit-NFRecordFromUI } elseif ($_.Control -and $_.KeyCode -eq [Windows.Forms.Keys]::F) { $_.SuppressKeyPress=$true; $keyboardFilter.Focus() } })
$computerGrid.Add_SelectionChanged({ Update-NFActions })
$keyboardGrid.Add_SelectionChanged({ Update-NFActions })
$mainTabs.Add_SelectedIndexChanged({ Update-NFActions; if ($mainTabs.SelectedTab -eq $historyTab) { Refresh-NFHistory }; if ($mainTabs.SelectedTab -eq $securityTab) { Refresh-NFBackups } })
$historyFilter.Add_TextChanged({ Refresh-NFHistory })
$historyTypeFilter.Add_SelectedIndexChanged({ Refresh-NFHistory })
$historyGrid.Add_SelectionChanged({ $historyDetailsButton.Enabled = ($historyGrid.SelectedRows.Count -gt 0) })
$historyGrid.Add_CellDoubleClick({ if ($_.RowIndex -ge 0) { Show-NFHistoryDetails } })
$historyDetailsButton.Add_Click({ Show-NFHistoryDetails })
$backupGrid.Add_SelectionChanged({ $restoreBackupButton.Enabled = ($backupGrid.SelectedRows.Count -gt 0 -and [string]$backupGrid.SelectedRows[0].Cells["BackupStatus"].Value -eq "Pronto") })
$manualBackupButton.Add_Click({ New-NFManualBackupFromUI })
$restoreBackupButton.Add_Click({ Restore-NFBackupFromUI })
$newButton.Add_Click({ Add-NFRecordFromUI })
$editButton.Add_Click({ Edit-NFRecordFromUI })
$outputButton.Add_Click({ Register-NFOutputFromUI })
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
