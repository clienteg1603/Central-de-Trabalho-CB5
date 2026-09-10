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
$script:IsEmbedded = (($EmbeddedParentHandle -gt 0) -and -not $script:IsInProcessHosted)
$script:HostedFormExport = $null
$script:HostedControlExport = $null
$script:EmbeddedParentHandle = [IntPtr]::new($EmbeddedParentHandle)
$script:EmbeddedResizeTimer = $null

if ($script:IsEmbedded -and -not ("CentralModuleEmbed.Native" -as [type])) {
    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
namespace CentralModuleEmbed {
    public static class Native {
        public const int GWL_STYLE = -16;
        public const int WS_CHILD = 0x40000000;
        public const int WS_POPUP = unchecked((int)0x80000000);
        [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
        [DllImport("user32.dll", SetLastError=true)] public static extern IntPtr SetParent(IntPtr child, IntPtr newParent);
        [DllImport("user32.dll", SetLastError=true)] public static extern int GetWindowLong(IntPtr hWnd, int nIndex);
        [DllImport("user32.dll", SetLastError=true)] public static extern int SetWindowLong(IntPtr hWnd, int nIndex, int value);
        [DllImport("user32.dll", SetLastError=true)] [return: MarshalAs(UnmanagedType.Bool)] public static extern bool GetClientRect(IntPtr hWnd, out RECT rect);
        [DllImport("user32.dll", SetLastError=true)] [return: MarshalAs(UnmanagedType.Bool)] public static extern bool MoveWindow(IntPtr hWnd, int x, int y, int width, int height, bool repaint);
        public static void Attach(IntPtr child, IntPtr parent) {
            SetParent(child, parent);
            int style = GetWindowLong(child, GWL_STYLE);
            style = (style & ~WS_POPUP) | WS_CHILD;
            SetWindowLong(child, GWL_STYLE, style);
            Fit(child, parent);
        }
        public static void Fit(IntPtr child, IntPtr parent) {
            RECT r;
            if (GetClientRect(parent, out r)) MoveWindow(child, 0, 0, Math.Max(1, r.Right-r.Left), Math.Max(1, r.Bottom-r.Top), true);
        }
    }
}
"@
}

function Initialize-EmbeddedModuleWindow {
    param([Windows.Forms.Form]$TargetForm)
    if (-not $script:IsEmbedded) { return }
    try {
        $TargetForm.FormBorderStyle = [Windows.Forms.FormBorderStyle]::None
        $TargetForm.ShowInTaskbar = $false
        $TargetForm.ControlBox = $false
        $TargetForm.MinimizeBox = $false
        $TargetForm.MaximizeBox = $false
        $TargetForm.StartPosition = [Windows.Forms.FormStartPosition]::Manual
        $TargetForm.MinimumSize = [Drawing.Size]::new(1, 1)
        $TargetForm.Add_Shown({
            try {
                [CentralModuleEmbed.Native]::Attach($TargetForm.Handle, $script:EmbeddedParentHandle)
                $script:EmbeddedResizeTimer = New-Object Windows.Forms.Timer
                $script:EmbeddedResizeTimer.Interval = 180
                $script:EmbeddedResizeTimer.Add_Tick({
                    try { [CentralModuleEmbed.Native]::Fit($TargetForm.Handle, $script:EmbeddedParentHandle) } catch {}
                })
                $script:EmbeddedResizeTimer.Start()
            } catch {}
        }.GetNewClosure())
        $TargetForm.Add_FormClosed({
            try { if ($null -ne $script:EmbeddedResizeTimer) { $script:EmbeddedResizeTimer.Stop(); $script:EmbeddedResizeTimer.Dispose(); $script:EmbeddedResizeTimer = $null } } catch {}
        })
    } catch {}
}


$script:AppVersion = "0.5.5"
$script:ModuleRoot = $PSScriptRoot
$script:CorePath = [IO.Path]::Combine($script:ModuleRoot, "Manutencao.Core.ps1")
if (-not [IO.File]::Exists($script:CorePath)) {
    [Windows.Forms.MessageBox]::Show(
        "O núcleo da Central de Manutenção não foi encontrado.`r`n`r`n$($script:CorePath)",
        "Central de Manutenção CB5",
        [Windows.Forms.MessageBoxButtons]::OK,
        [Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
    return
}
. $script:CorePath

$script:SingleInstanceMutex = $null
$script:OwnsSingleInstanceMutex = $false
$createdNewMutex = $false
try {
    $script:SingleInstanceMutex = [Threading.Mutex]::new($true, "CentralDeTrabalho_ManutencaoCB5", ([ref]$createdNewMutex))
    $script:OwnsSingleInstanceMutex = $createdNewMutex
}
catch {}

if ($null -ne $script:SingleInstanceMutex -and -not $script:OwnsSingleInstanceMutex) {
    [Windows.Forms.MessageBox]::Show(
        "A Central de Manutenção CB5 já está aberta.`r`n`r`nUse a janela que já está em execução para evitar dois salvamentos simultâneos na mesma base.",
        "Central de Manutenção CB5",
        [Windows.Forms.MessageBoxButtons]::OK,
        [Windows.Forms.MessageBoxIcon]::Information
    ) | Out-Null
    $script:SingleInstanceMutex.Dispose()
    return
}

function Close-SingleInstanceMutex {
    if ($null -eq $script:SingleInstanceMutex) { return }
    try {
        if ($script:OwnsSingleInstanceMutex) { $script:SingleInstanceMutex.ReleaseMutex() }
    }
    catch {}
    try { $script:SingleInstanceMutex.Dispose() }
    catch {}
    $script:SingleInstanceMutex = $null
    $script:OwnsSingleInstanceMutex = $false
}

$script:DataDirectory = Get-CB5DefaultDataDirectory
$script:DatabasePath = ""
$script:SettingsPath = [IO.Path]::Combine($script:DataDirectory, "preferencias.json")
$script:Store = $null
$script:CurrentPassageId = ""
$script:FilteredPassages = @()
$script:CurrentPalette = $null
$script:IsLoadingForm = $false
$script:CorrectionMode = $false

try {
    $script:DatabasePath = Initialize-CB5DataStore -DataDirectory $script:DataDirectory
    $script:Store = Read-CB5Store -Path $script:DatabasePath
}
catch {
    [Windows.Forms.MessageBox]::Show(
        $_.Exception.Message,
        "Central de Manutenção CB5 — base preservada",
        [Windows.Forms.MessageBoxButtons]::OK,
        [Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
    Close-SingleInstanceMutex
    return
}

function Get-MaintenanceSettings {
    $settings = [pscustomobject]@{ Theme = "Claro moderno" }
    try {
        if ([IO.File]::Exists($script:SettingsPath)) {
            $saved = [IO.File]::ReadAllText($script:SettingsPath, [Text.Encoding]::UTF8) | ConvertFrom-Json
            if (@("Claro moderno", "Escuro grafite", "Técnico industrial", "Alto contraste") -contains [string]$saved.Theme) {
                $settings.Theme = [string]$saved.Theme
            }
        }
    }
    catch {}
    return $settings
}

function Save-MaintenanceSettings {
    try {
        if (-not [IO.Directory]::Exists($script:DataDirectory)) {
            [void][IO.Directory]::CreateDirectory($script:DataDirectory)
        }
        $json = [pscustomobject]@{ Theme = [string]$themeCombo.SelectedItem } | ConvertTo-Json
        [IO.File]::WriteAllText($script:SettingsPath, $json, ([Text.UTF8Encoding]::new($true)))
    }
    catch {}
}

function Get-MaintenancePalette {
    param([string]$Theme)
    switch ($Theme) {
        "Escuro grafite" {
            return [pscustomobject]@{
                Background = [Drawing.Color]::FromArgb(13, 20, 34)
                Surface = [Drawing.Color]::FromArgb(17, 27, 44)
                Card = [Drawing.Color]::FromArgb(23, 34, 54)
                Input = [Drawing.Color]::FromArgb(13, 20, 34)
                Text = [Drawing.Color]::FromArgb(244, 247, 251)
                Muted = [Drawing.Color]::FromArgb(170, 182, 200)
                Border = [Drawing.Color]::FromArgb(41, 55, 80)
                Accent = [Drawing.Color]::FromArgb(32, 169, 149)
                Action = [Drawing.Color]::FromArgb(244, 166, 42)
                Info = [Drawing.Color]::FromArgb(58, 130, 247)
                AccentText = [Drawing.Color]::White
                ActionText = [Drawing.Color]::FromArgb(18, 23, 29)
                Success = [Drawing.Color]::FromArgb(39, 196, 125)
                SuccessBack = [Drawing.Color]::FromArgb(6, 78, 59)
                Warning = [Drawing.Color]::FromArgb(251, 191, 36)
                WarningBack = [Drawing.Color]::FromArgb(92, 62, 8)
                Danger = [Drawing.Color]::FromArgb(233, 90, 90)
                DangerBack = [Drawing.Color]::FromArgb(69, 10, 10)
            }
        }
        "Técnico industrial" {
            return [pscustomobject]@{
                Background = [Drawing.Color]::FromArgb(18, 23, 25)
                Surface = [Drawing.Color]::FromArgb(27, 35, 38)
                Card = [Drawing.Color]::FromArgb(34, 43, 46)
                Input = [Drawing.Color]::FromArgb(18, 23, 25)
                Text = [Drawing.Color]::FromArgb(242, 246, 245)
                Muted = [Drawing.Color]::FromArgb(174, 188, 186)
                Border = [Drawing.Color]::FromArgb(62, 77, 80)
                Accent = [Drawing.Color]::FromArgb(44, 189, 197)
                Action = [Drawing.Color]::FromArgb(244, 142, 40)
                Info = [Drawing.Color]::FromArgb(89, 154, 219)
                AccentText = [Drawing.Color]::FromArgb(9, 24, 28)
                ActionText = [Drawing.Color]::FromArgb(27, 24, 17)
                Success = [Drawing.Color]::FromArgb(72, 202, 143)
                SuccessBack = [Drawing.Color]::FromArgb(22, 72, 57)
                Warning = [Drawing.Color]::FromArgb(246, 186, 68)
                WarningBack = [Drawing.Color]::FromArgb(86, 59, 13)
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
                Accent = [Drawing.Color]::Cyan
                Action = [Drawing.Color]::Yellow
                Info = [Drawing.Color]::Cyan
                AccentText = [Drawing.Color]::Black
                ActionText = [Drawing.Color]::Black
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
                Background = [Drawing.Color]::FromArgb(243, 246, 250)
                Surface = [Drawing.Color]::White
                Card = [Drawing.Color]::White
                Input = [Drawing.Color]::White
                Text = [Drawing.Color]::FromArgb(15, 23, 42)
                Muted = [Drawing.Color]::FromArgb(71, 85, 105)
                Border = [Drawing.Color]::FromArgb(203, 213, 225)
                Accent = [Drawing.Color]::FromArgb(13, 142, 158)
                Action = [Drawing.Color]::FromArgb(220, 111, 24)
                Info = [Drawing.Color]::FromArgb(48, 112, 190)
                AccentText = [Drawing.Color]::White
                ActionText = [Drawing.Color]::White
                Success = [Drawing.Color]::FromArgb(4, 120, 87)
                SuccessBack = [Drawing.Color]::FromArgb(209, 250, 229)
                Warning = [Drawing.Color]::FromArgb(180, 83, 9)
                WarningBack = [Drawing.Color]::FromArgb(254, 243, 199)
                Danger = [Drawing.Color]::FromArgb(185, 28, 28)
                DangerBack = [Drawing.Color]::FromArgb(254, 226, 226)
            }
        }
    }
}

function Set-MaintenanceRoundedRegion {
    param([Windows.Forms.Control]$Control, [int]$Radius = 10)
    if ($null -eq $Control -or $Control.Width -le 2 -or $Control.Height -le 2) { return }
    try {
        $diameter = [Math]::Max(2, $Radius * 2)
        $rect = [Drawing.Rectangle]::new(0, 0, $Control.Width - 1, $Control.Height - 1)
        $path = New-Object Drawing.Drawing2D.GraphicsPath
        $path.AddArc($rect.Left, $rect.Top, $diameter, $diameter, 180, 90)
        $path.AddArc($rect.Right - $diameter, $rect.Top, $diameter, $diameter, 270, 90)
        $path.AddArc($rect.Right - $diameter, $rect.Bottom - $diameter, $diameter, $diameter, 0, 90)
        $path.AddArc($rect.Left, $rect.Bottom - $diameter, $diameter, $diameter, 90, 90)
        $path.CloseFigure()
        $old = $Control.Region
        $Control.Region = New-Object Drawing.Region($path)
        $path.Dispose()
        if ($null -ne $old) { $old.Dispose() }
    } catch {}
}

function Get-MaintenanceThemeFromHost {
    param([string]$Theme)
    switch ($Theme) {
        "Escuro profissional" { return "Escuro grafite" }
        "Técnico industrial" { return "Técnico industrial" }
        "Claro corporativo" { return "Claro moderno" }
        "Alto contraste" { return "Alto contraste" }
        default { return "Escuro grafite" }
    }
}

function Set-HostedMaintenanceTheme {
    param([string]$CentralTheme)
    if (-not $script:IsInProcessHosted) { return }
    $mapped = Get-MaintenanceThemeFromHost $CentralTheme
    try {
        if ($themeCombo.Items.Contains($mapped)) { $themeCombo.SelectedItem = $mapped }
        else { $themeCombo.SelectedItem = "Escuro grafite" }
        Apply-MaintenanceTheme
        Update-MaintenanceResponsiveLayout
    } catch {}
}

function Set-MaintenanceButtonStyle {
    param([Windows.Forms.Button]$Button)
    $Button.FlatStyle = [Windows.Forms.FlatStyle]::Flat
    $Button.Cursor = [Windows.Forms.Cursors]::Hand
    $kind = ConvertTo-CB5Text $Button.Tag
    switch ($kind) {
        "Primary" {
            $Button.FlatAppearance.BorderSize = 0
            $Button.BackColor = $script:CurrentPalette.Accent
            $Button.ForeColor = $script:CurrentPalette.AccentText
        }
        "Action" {
            $Button.FlatAppearance.BorderSize = 0
            $Button.BackColor = $script:CurrentPalette.Action
            $Button.ForeColor = $script:CurrentPalette.ActionText
        }
        "Danger" {
            $Button.FlatAppearance.BorderSize = 1
            $Button.FlatAppearance.BorderColor = $script:CurrentPalette.Danger
            $Button.BackColor = $script:CurrentPalette.DangerBack
            $Button.ForeColor = $script:CurrentPalette.Danger
        }
        default {
            $Button.FlatAppearance.BorderSize = 1
            $Button.FlatAppearance.BorderColor = $script:CurrentPalette.Border
            $Button.BackColor = $script:CurrentPalette.Surface
            $Button.ForeColor = $script:CurrentPalette.Text
        }
    }
}

function Apply-ThemeToTree {
    param([Windows.Forms.Control]$Control)

    if ($Control -is [Windows.Forms.Form] -or $Control -is [Windows.Forms.TabPage]) {
        $Control.BackColor = $script:CurrentPalette.Background
        $Control.ForeColor = $script:CurrentPalette.Text
    }
    elseif ($Control -is [Windows.Forms.Panel] -or
            $Control -is [Windows.Forms.TableLayoutPanel] -or
            $Control -is [Windows.Forms.FlowLayoutPanel]) {
        if ($null -ne $Control.Parent) { $Control.BackColor = $Control.Parent.BackColor }
        else { $Control.BackColor = $script:CurrentPalette.Background }
        $Control.ForeColor = $script:CurrentPalette.Text
    }
    elseif ($Control -is [Windows.Forms.GroupBox]) {
        $Control.BackColor = $script:CurrentPalette.Card
        $Control.ForeColor = $script:CurrentPalette.Text
        $Control.FlatStyle = [Windows.Forms.FlatStyle]::Flat
    }
    elseif ($Control -is [Windows.Forms.TextBox] -or
            $Control -is [Windows.Forms.MaskedTextBox] -or
            $Control -is [Windows.Forms.ComboBox] -or
            $Control -is [Windows.Forms.DateTimePicker] -or
            $Control -is [Windows.Forms.NumericUpDown]) {
        $Control.BackColor = $script:CurrentPalette.Input
        $Control.ForeColor = $script:CurrentPalette.Text
    }
    elseif ($Control -is [Windows.Forms.Button]) {
        Set-MaintenanceButtonStyle $Control
    }
    elseif ($Control -is [Windows.Forms.DataGridView]) {
        $Control.BackgroundColor = $script:CurrentPalette.Card
        $Control.GridColor = $script:CurrentPalette.Border
        $Control.DefaultCellStyle.BackColor = $script:CurrentPalette.Card
        $Control.DefaultCellStyle.ForeColor = $script:CurrentPalette.Text
        $Control.DefaultCellStyle.SelectionBackColor = $script:CurrentPalette.Accent
        $Control.DefaultCellStyle.SelectionForeColor = $script:CurrentPalette.AccentText
        $Control.ColumnHeadersDefaultCellStyle.BackColor = $script:CurrentPalette.Surface
        $Control.ColumnHeadersDefaultCellStyle.ForeColor = $script:CurrentPalette.Text
        $Control.AlternatingRowsDefaultCellStyle.BackColor = $script:CurrentPalette.Background
        $Control.AlternatingRowsDefaultCellStyle.ForeColor = $script:CurrentPalette.Text
        $Control.BorderStyle = [Windows.Forms.BorderStyle]::None
        $Control.CellBorderStyle = [Windows.Forms.DataGridViewCellBorderStyle]::SingleHorizontal
        $Control.ColumnHeadersBorderStyle = [Windows.Forms.DataGridViewHeaderBorderStyle]::None
        $Control.DefaultCellStyle.Padding = [Windows.Forms.Padding]::new(4, 2, 4, 2)
        $Control.EnableHeadersVisualStyles = $false
    }
    else {
        $Control.ForeColor = $script:CurrentPalette.Text
    }

    foreach ($child in $Control.Controls) { Apply-ThemeToTree $child }
}

function Apply-MaintenanceTheme {
    $script:CurrentPalette = Get-MaintenancePalette ([string]$themeCombo.SelectedItem)
    Apply-ThemeToTree $form
    $headerPanel.BackColor = $script:CurrentPalette.Surface
    $footerPanel.BackColor = $script:CurrentPalette.Surface
    foreach ($card in @($cardSeries, $cardPassages, $cardOpen, $cardReturns)) {
        $card.BackColor = $script:CurrentPalette.Card
        $card.BorderStyle = [Windows.Forms.BorderStyle]::None
        Set-MaintenanceRoundedRegion $card 10
    }
    foreach ($d in @($script:SummaryCardDecorations)) {
        $color = switch ($d.Kind) {
            "Info" { $script:CurrentPalette.Info }
            "Action" { $script:CurrentPalette.Action }
            "Success" { $script:CurrentPalette.Success }
            default { $script:CurrentPalette.Accent }
        }
        $d.Bar.BackColor = $color
        $d.Value.ForeColor = $color
    }
    if ($null -ne $dashboardSubtitle) { $dashboardSubtitle.ForeColor = $script:CurrentPalette.Muted }
    if ($null -ne $statisticsSubtitle) { $statisticsSubtitle.ForeColor = $script:CurrentPalette.Muted }
    $versionBadge.BackColor = $script:CurrentPalette.SuccessBack
    $versionBadge.ForeColor = $script:CurrentPalette.Success
    $modePanel.BackColor = $script:CurrentPalette.Surface
    $formModeLabel.ForeColor = $script:CurrentPalette.Accent
    Set-MaintenanceRoundedRegion $modePanel 9
    $automaticFlowLabel.BackColor = $script:CurrentPalette.Surface
    $automaticFlowLabel.ForeColor = $script:CurrentPalette.Muted
    Set-MaintenanceRoundedRegion $automaticFlowLabel 8
    $finalResultHelp.BackColor = $script:CurrentPalette.Surface
    Set-MaintenanceRoundedRegion $finalResultHelp 8
    $recordBanner.BackColor = $script:CurrentPalette.SuccessBack
    $recordBanner.ForeColor = $script:CurrentPalette.Success
    Set-MaintenanceRoundedRegion $recordBanner 9
    $updateInfo.BackColor = $script:CurrentPalette.WarningBack
    $updateInfo.ForeColor = $script:CurrentPalette.Warning
    Set-MaintenanceRoundedRegion $updateInfo 8
    $codeRuleLabel.BackColor = $script:CurrentPalette.Surface
    $codeRuleLabel.ForeColor = $script:CurrentPalette.Muted
    Set-MaintenanceRoundedRegion $codeRuleLabel 8
    $seriesHistoryStateLabel.ForeColor = $script:CurrentPalette.Muted
    $hypothesisNotice.BackColor = $script:CurrentPalette.WarningBack
    $hypothesisNotice.ForeColor = $script:CurrentPalette.Warning
    Set-MaintenanceRoundedRegion $hypothesisNotice 10
    $diagnosisResultLabel.BackColor = $script:CurrentPalette.Surface
    $diagnosisResultLabel.ForeColor = $script:CurrentPalette.Muted
    Set-MaintenanceRoundedRegion $diagnosisResultLabel 8
    $schemaNotice.BackColor = $script:CurrentPalette.SuccessBack
    $schemaNotice.ForeColor = $script:CurrentPalette.Success
    Set-MaintenanceRoundedRegion $schemaNotice 10
    $codeRulesText.BackColor = $script:CurrentPalette.Card
    $codeRulesText.ForeColor = $script:CurrentPalette.Text
    $codeRulesText.BorderStyle = [Windows.Forms.BorderStyle]::None
    $statusLabel.ForeColor = $script:CurrentPalette.Muted
    $statsTabs.Invalidate()
    Refresh-CurrentSeriesHistory
    $mainTabs.Invalidate()
    $form.Invalidate($true)
}

function Set-ModuleStatus {
    param(
        [string]$Message,
        [ValidateSet("Normal", "Success", "Warning", "Error")][string]$Kind = "Normal"
    )
    $statusLabel.Text = $Message
    switch ($Kind) {
        "Success" { $statusLabel.ForeColor = $script:CurrentPalette.Success }
        "Warning" { $statusLabel.ForeColor = $script:CurrentPalette.Warning }
        "Error" { $statusLabel.ForeColor = $script:CurrentPalette.Danger }
        default { $statusLabel.ForeColor = $script:CurrentPalette.Muted }
    }
}

function New-Grid {
    $grid = New-Object Windows.Forms.DataGridView
    $grid.Dock = [Windows.Forms.DockStyle]::Fill
    $grid.AllowUserToAddRows = $false
    $grid.AllowUserToDeleteRows = $false
    $grid.AllowUserToResizeRows = $false
    $grid.ReadOnly = $true
    $grid.MultiSelect = $false
    $grid.SelectionMode = [Windows.Forms.DataGridViewSelectionMode]::FullRowSelect
    $grid.RowHeadersVisible = $false
    $grid.AutoSizeColumnsMode = [Windows.Forms.DataGridViewAutoSizeColumnsMode]::None
    $grid.AllowUserToResizeColumns = $true
    $grid.ScrollBars = [Windows.Forms.ScrollBars]::Both
    $grid.BorderStyle = [Windows.Forms.BorderStyle]::FixedSingle
    if ($script:IsInProcessHosted) {
        $grid.ColumnHeadersHeightSizeMode = [Windows.Forms.DataGridViewColumnHeadersHeightSizeMode]::DisableResizing
        $grid.ColumnHeadersHeight = 28
        $grid.RowTemplate.Height = 25
        $grid.DefaultCellStyle.Font = [Drawing.Font]::new("Segoe UI", 8.8)
        $grid.ColumnHeadersDefaultCellStyle.Font = [Drawing.Font]::new("Segoe UI Semibold", 8.8)
    }
    return $grid
}

function Add-GridColumn {
    param(
        [Windows.Forms.DataGridView]$Grid,
        [string]$Name,
        [string]$Header,
        [int]$Width = 100,
        [ValidateSet("Fixed", "Fill")][string]$Sizing = "Fixed",
        [int]$MinimumWidth = 45
    )
    $column = New-Object Windows.Forms.DataGridViewTextBoxColumn
    $column.Name = $Name
    $column.HeaderText = $Header
    $column.MinimumWidth = [Math]::Max(20, $MinimumWidth)
    if ($Sizing -eq "Fill") {
        $column.FillWeight = [Math]::Max(1, $Width)
        $column.AutoSizeMode = [Windows.Forms.DataGridViewAutoSizeColumnMode]::Fill
    }
    else {
        $column.AutoSizeMode = [Windows.Forms.DataGridViewAutoSizeColumnMode]::None
        $column.Width = [Math]::Max($column.MinimumWidth, $Width)
    }
    [void]$Grid.Columns.Add($column)
}

function Add-ComboItems {
    param(
        [Windows.Forms.ComboBox]$Combo,
        [object[]]$Items
    )
    $Combo.BeginUpdate()
    try {
        $Combo.Items.Clear()
        foreach ($item in $Items) { [void]$Combo.Items.Add($item) }
    }
    finally { $Combo.EndUpdate() }
}

function Set-ComboValue {
    param(
        [Windows.Forms.ComboBox]$Combo,
        [string]$Value,
        [int]$FallbackIndex = 0
    )
    $index = $Combo.FindStringExact($Value)
    if ($index -ge 0) { $Combo.SelectedIndex = $index }
    elseif ($Combo.Items.Count -gt $FallbackIndex) { $Combo.SelectedIndex = $FallbackIndex }
}

function Get-DatePickerValue {
    param([Windows.Forms.DateTimePicker]$Picker)
    if ($Picker.ShowCheckBox -and -not $Picker.Checked) { return "" }
    return $Picker.Value.ToString("yyyy-MM-dd")
}

function Set-DatePickerValue {
    param(
        [Windows.Forms.DateTimePicker]$Picker,
        [string]$Value
    )
    if ([string]::IsNullOrWhiteSpace($Value)) {
        if ($Picker.ShowCheckBox) { $Picker.Checked = $false }
        return
    }
    try {
        $Picker.Value = [datetime]$Value
        if ($Picker.ShowCheckBox) { $Picker.Checked = $true }
    }
    catch {
        if ($Picker.ShowCheckBox) { $Picker.Checked = $false }
    }
}

function Save-StoreSafely {
    try {
        Write-CB5Store -Store $script:Store -Path $script:DatabasePath
        return $true
    }
    catch {
        [Windows.Forms.MessageBox]::Show(
            "Não foi possível salvar os dados. A versão anterior da base foi preservada.`r`n`r`n$($_.Exception.Message)",
            "Central de Manutenção CB5",
            [Windows.Forms.MessageBoxButtons]::OK,
            [Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
        Set-ModuleStatus "Falha ao salvar. A base anterior foi preservada." "Error"
        return $false
    }
}

function Get-SelectedRecordFromGrid {
    param([Windows.Forms.DataGridView]$Grid)
    if ($Grid.SelectedRows.Count -eq 0) { return $null }
    $id = ConvertTo-CB5Text $Grid.SelectedRows[0].Tag
    if ([string]::IsNullOrWhiteSpace($id)) { return $null }
    return Get-CB5PassageById -Store $script:Store -Id $id
}

function Get-PassageDetailText {
    param([object]$Record)
    $returnText = if (ConvertTo-CB5Boolean $Record.EhRetorno) { "SIM" } else { "NÃO" }
    $completedText = if (ConvertTo-CB5Boolean $Record.Concluida) { "SIM" } else { "NÃO" }
    $events = New-Object Text.StringBuilder
    foreach ($event in @($Record.Eventos)) {
        [void]$events.AppendLine("• $($event.Em) — $($event.Tipo): $($event.Descricao)")
        if ($event.PSObject.Properties.Name -contains "Alteracoes") {
            foreach ($change in @($event.Alteracoes)) {
                $before = if ([string]::IsNullOrWhiteSpace([string]$change.Antes)) { "(vazio)" } else { [string]$change.Antes }
                $after = if ([string]::IsNullOrWhiteSpace([string]$change.Depois)) { "(vazio)" } else { [string]$change.Depois }
                [void]$events.AppendLine("    - $($change.Campo): $before → $after")
            }
        }
    }
    return @"
SÉRIE: $($Record.Serie)          PASSAGEM: $($Record.Passagem)          RETORNO: $returnText

Código: $($Record.Codigo)
Versão de entrada: $($Record.VersaoEntrada)
Versão de saída: $($Record.VersaoSaida)
Data de entrada: $($Record.DataEntrada)
Status: $($Record.Status)
Concluída: $completedText
Data de conclusão: $($Record.DataConclusao)

DEFEITO REPORTADO
$($Record.DefeitoReportado)

DEFEITO ENCONTRADO
$($Record.DefeitoEncontrado)

OUTROS DEFEITOS
$($Record.OutrosDefeitos)

MANUTENÇÃO REALIZADA
$($Record.ManutencaoRealizada)

RESULTADO FINAL
$($Record.ResultadoFinal)

ATUALIZAÇÃO EXTERNA PREVISTA
Atualização indicada: $($Record.AtualizacaoIndicada)
Componentes externos: $($Record.ComponentesExternos)

OBSERVAÇÕES
$($Record.Observacoes)

EVENTOS PRESERVADOS
$($events.ToString())
"@
}

function Show-PassageDetails {
    param([object]$Record)
    if ($null -eq $Record) { return }
    $detailForm = New-Object Windows.Forms.Form
    $detailForm.Text = "Série $($Record.Serie) — passagem $($Record.Passagem)"
    $detailForm.StartPosition = [Windows.Forms.FormStartPosition]::CenterParent
    $detailForm.Size = [Drawing.Size]::new(820, 720)
    $detailForm.MinimumSize = [Drawing.Size]::new(620, 500)
    $detailForm.AutoScaleMode = [Windows.Forms.AutoScaleMode]::Dpi
    $detailForm.BackColor = $script:CurrentPalette.Background

    $detailRoot = New-Object Windows.Forms.TableLayoutPanel
    $detailRoot.Dock = [Windows.Forms.DockStyle]::Fill
    $detailRoot.Padding = [Windows.Forms.Padding]::new(18)
    $detailRoot.RowCount = 2
    $detailRoot.ColumnCount = 1
    [void]$detailRoot.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 100)))
    [void]$detailRoot.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 50)))
    $detailForm.Controls.Add($detailRoot)

    $detailText = New-Object Windows.Forms.TextBox
    $detailText.Dock = [Windows.Forms.DockStyle]::Fill
    $detailText.Multiline = $true
    $detailText.ReadOnly = $true
    $detailText.ScrollBars = [Windows.Forms.ScrollBars]::Both
    $detailText.Font = [Drawing.Font]::new("Consolas", 10)
    $detailText.WordWrap = $true
    $detailText.Text = Get-PassageDetailText $Record
    $detailRoot.Controls.Add($detailText, 0, 0)

    $closeButton = New-Object Windows.Forms.Button
    $closeButton.Text = "FECHAR"
    $closeButton.Width = 130
    $closeButton.Height = 36
    $closeButton.Anchor = [Windows.Forms.AnchorStyles]::Right
    $closeButton.Tag = "Primary"
    $closeButton.Add_Click({ $detailForm.Close() })
    $detailRoot.Controls.Add($closeButton, 0, 1)
    Apply-ThemeToTree $detailForm
    [void]$detailForm.ShowDialog($form)
    $detailForm.Dispose()
}

function Update-ReturnBanner {
    if ($script:IsLoadingForm) { return }
    if ($script:CorrectionMode) {
        $recordBanner.Text = "MODO CORREÇÃO: a série e a passagem permanecem fixas. Toda alteração será registrada nos eventos com o valor anterior e o novo."
        $recordBanner.BackColor = $script:CurrentPalette.WarningBack
        $recordBanner.ForeColor = $script:CurrentPalette.Warning
        return
    }
    $serial = $serialBox.Text.Trim()
    if (-not (Test-CB5Serial $serial)) {
        $recordBanner.Text = "Digite os 8 dígitos da série para consultar o histórico automaticamente."
        $recordBanner.BackColor = $script:CurrentPalette.SuccessBack
        $recordBanner.ForeColor = $script:CurrentPalette.Success
        return
    }

    $passages = @(Get-CB5PassagesBySerial -Store $script:Store -Serial $serial)
    $openRecord = Get-CB5OpenPassageBySerial -Store $script:Store -Serial $serial
    if ($null -ne $openRecord -and [string]$openRecord.Id -ne $script:CurrentPassageId) {
        $recordBanner.Text = "ATENÇÃO: esta série já possui a passagem $($openRecord.Passagem) em aberto. Use o Histórico para continuar sem duplicar o registro."
        $recordBanner.BackColor = $script:CurrentPalette.DangerBack
        $recordBanner.ForeColor = $script:CurrentPalette.Danger
    }
    elseif ($passages.Count -gt 0 -and [string]::IsNullOrWhiteSpace($script:CurrentPassageId)) {
        $recordBanner.Text = "RETORNO IDENTIFICADO: existem $($passages.Count) passagem(ns). O novo registro será a passagem $($passages.Count + 1), sem alterar as anteriores."
        $recordBanner.BackColor = $script:CurrentPalette.WarningBack
        $recordBanner.ForeColor = $script:CurrentPalette.Warning
    }
    elseif ($passages.Count -gt 0) {
        $recordBanner.Text = "Editando a passagem atual. As passagens antigas e os eventos já registrados permanecem preservados."
        $recordBanner.BackColor = $script:CurrentPalette.SuccessBack
        $recordBanner.ForeColor = $script:CurrentPalette.Success
    }
    else {
        $recordBanner.Text = "Série nova: nenhuma passagem anterior foi encontrada."
        $recordBanner.BackColor = $script:CurrentPalette.SuccessBack
        $recordBanner.ForeColor = $script:CurrentPalette.Success
    }
}

function Update-CodeRuleUI {
    if ($script:IsLoadingForm) { return }
    $code = ConvertTo-CB5Text $codeCombo.SelectedItem
    $previousResult = ConvertTo-CB5Text $finalResultCombo.SelectedItem
    Add-ComboItems $finalResultCombo (@("Selecione...") + @(Get-CB5FinalResultCatalog))
    if ((Get-CB5FinalResultCatalog) -contains $previousResult) {
        Set-ComboValue $finalResultCombo $previousResult
    }
    else {
        Set-ComboValue $finalResultCombo "Selecione..."
    }

    $maintenanceBox.ReadOnly = $false
    $codeRuleLabel.Text = if ($code -eq "800") {
        "Código 800: sem restrição ao período do mês."
    }
    else {
        "Código ${code}: somente pode ser trabalhado entre os dias 1 e 20."
    }
    Update-FinalResultUI
}

function Update-FinalResultUI {
    if ($script:IsLoadingForm) { return }
    $result = ConvertTo-CB5Text $finalResultCombo.SelectedItem
    switch ($result) {
        "Aprovado" {
            $finalResultHelp.Text = "APROVADO: conclui sua etapa e a peça segue automaticamente para o próximo setor. Não é necessário registrar teste ou Ping."
            $finalResultHelp.ForeColor = $script:CurrentPalette.Success
        }
        "PT" {
            $finalResultHelp.Text = "PT: encerra a passagem com o resultado PT. Use Defeito encontrado e Observações para registrar os detalhes necessários."
            $finalResultHelp.ForeColor = $script:CurrentPalette.Danger
        }
        default {
            $finalResultHelp.Text = "Escolha o resultado somente ao finalizar: Aprovado ou PT."
            $finalResultHelp.ForeColor = $script:CurrentPalette.Muted
        }
    }
}

function Update-VersionRuleUI {
    if ($script:IsLoadingForm) { return }
    $version = ConvertTo-CB5Text $inputVersionCombo.SelectedItem
    if ([string]::IsNullOrWhiteSpace($version)) { return }
    $rule = Get-CB5UpdateRule -Version $version -ModemDefectConfirmed $false

    if ($rule.Encontrada -and $rule.CondicionalAoModem) {
        $updateInfo.Text = "INFORMAÇÃO AUTOMÁTICA: $version → $($rule.Destino) somente se o outro setor confirmar defeito no modem. Nenhuma ação é necessária nesta tela."
    }
    elseif ($rule.Encontrada) {
        $updateInfo.Text = "PRÓXIMA ETAPA EXTERNA: $version → $($rule.Destino) | $($rule.Componentes). A troca pertence ao setor responsável; aqui fica apenas o aviso."
    }
    else {
        $updateInfo.Text = "Nenhuma atualização externa prevista para esta versão."
    }

    if ([string]::IsNullOrWhiteSpace((ConvertTo-CB5Text $outputVersionCombo.SelectedItem)) -or
        ([string]::IsNullOrWhiteSpace($script:CurrentPassageId) -and $outputVersionCombo.SelectedItem -ne $version)) {
        Set-ComboValue $outputVersionCombo $version
    }
}

function Reset-PassageForm {
    $previousCode = ConvertTo-CB5Text $codeCombo.SelectedItem
    $keepCode = (Get-CB5CodeCatalog) -contains $previousCode
    $script:IsLoadingForm = $true
    try {
        $script:CurrentPassageId = ""
        $script:CorrectionMode = $false
        $serialBox.Text = ""
        if ($keepCode) { Set-ComboValue $codeCombo $previousCode }
        else { Set-ComboValue $codeCombo "800" }
        $inputVersionCombo.SelectedIndex = 0
        $outputVersionCombo.SelectedIndex = 0
        $entryDatePicker.Value = [DateTime]::Today
        $reportedDefectBox.Clear()
        $foundDefectBox.Clear()
        $otherDefectsBox.Clear()
        $maintenanceBox.Clear()
        $maintenanceBox.ReadOnly = $false
        Set-ComboValue $finalResultCombo "Selecione..."
        $notesBox.Clear()
        $formModeLabel.Text = "NOVA PASSAGEM"
        $serialBox.ReadOnly = $false
        $newPassageButton.Enabled = $true
        $savePassageButton.Enabled = $true
        $savePassageButton.Text = "SALVAR ANDAMENTO"
        $savePassageButton.Tag = "Secondary"
        $completePassageButton.Enabled = $true
    }
    finally { $script:IsLoadingForm = $false }
    if ($null -ne $script:CurrentPalette) { Set-MaintenanceButtonStyle $savePassageButton }
    Update-CodeRuleUI
    Update-VersionRuleUI
    Update-ReturnBanner
    Refresh-CurrentSeriesHistory
    if ($keepCode) { $serialBox.Focus() }
    else { $codeCombo.Focus() }
}

function Load-PassageIntoForm {
    param([object]$Record)
    if ($null -eq $Record) { return }
    if (-not ((Get-CB5CodeCatalog) -contains [string]$Record.Codigo) -or
        ((ConvertTo-CB5Boolean $Record.Concluida) -and -not ((Get-CB5FinalResultCatalog) -contains [string]$Record.ResultadoFinal))) {
        [Windows.Forms.MessageBox]::Show(
            "Este é um registro antigo de uma regra que não existe mais na rotina atual. Ele será preservado e pode ser consultado, mas não será regravado pela tela nova.",
            "Registro antigo preservado",
            [Windows.Forms.MessageBoxButtons]::OK,
            [Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
        Show-PassageDetails $Record
        return
    }

    $script:IsLoadingForm = $true
    try {
        $script:CurrentPassageId = [string]$Record.Id
        $script:CorrectionMode = ConvertTo-CB5Boolean $Record.Concluida
        $serialBox.Text = [string]$Record.Serie
        $serialBox.ReadOnly = $true
        Set-ComboValue $codeCombo ([string]$Record.Codigo)
        Set-ComboValue $inputVersionCombo ([string]$Record.VersaoEntrada)
        Set-ComboValue $outputVersionCombo ([string]$Record.VersaoSaida)
        Set-DatePickerValue $entryDatePicker ([string]$Record.DataEntrada)
        $reportedDefectBox.Text = [string]$Record.DefeitoReportado
        $foundDefectBox.Text = [string]$Record.DefeitoEncontrado
        $otherDefectsBox.Text = [string]$Record.OutrosDefeitos
        $maintenanceBox.Text = [string]$Record.ManutencaoRealizada
        $notesBox.Text = [string]$Record.Observacoes
        if ($script:CorrectionMode) {
            $formModeLabel.Text = "CORRIGINDO SÉRIE $($Record.Serie) — PASSAGEM $($Record.Passagem)"
            $savePassageButton.Text = "SALVAR CORREÇÃO"
            $savePassageButton.Tag = "Primary"
            $completePassageButton.Enabled = $false
        }
        else {
            $formModeLabel.Text = "EDITANDO SÉRIE $($Record.Serie) — PASSAGEM $($Record.Passagem)"
            $savePassageButton.Text = "SALVAR ANDAMENTO"
            $savePassageButton.Tag = "Secondary"
            $completePassageButton.Enabled = $true
        }
    }
    finally { $script:IsLoadingForm = $false }
    Update-CodeRuleUI
    Set-ComboValue $finalResultCombo ([string]$Record.ResultadoFinal)
    Update-FinalResultUI
    Update-VersionRuleUI
    Update-ReturnBanner
    Refresh-CurrentSeriesHistory
    if ($null -ne $script:CurrentPalette) { Set-MaintenanceButtonStyle $savePassageButton }
    $mainTabs.SelectedTab = $passageTab
}

function Start-ReturnFromRecord {
    param([object]$Record)
    if ($null -eq $Record) { return }
    if (-not (ConvertTo-CB5Boolean $Record.Concluida)) {
        [Windows.Forms.MessageBox]::Show(
            "Esta passagem ainda está aberta. Continue o registro existente em vez de criar um retorno.",
            "Passagem em aberto",
            [Windows.Forms.MessageBoxButtons]::OK,
            [Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
        Load-PassageIntoForm $Record
        return
    }
    Reset-PassageForm
    $serialBox.Text = [string]$Record.Serie
    Set-ComboValue $codeCombo ([string]$Record.Codigo)
    $sourceVersion = [string]$Record.VersaoSaida
    if ([string]::IsNullOrWhiteSpace($sourceVersion)) { $sourceVersion = [string]$Record.VersaoEntrada }
    Set-ComboValue $inputVersionCombo $sourceVersion
    Set-ComboValue $outputVersionCombo $sourceVersion
    $formModeLabel.Text = "NOVO RETORNO — PRÓXIMA PASSAGEM DA SÉRIE $($Record.Serie)"
    Update-ReturnBanner
    $mainTabs.SelectedTab = $passageTab
    $reportedDefectBox.Focus()
}

function Get-PassageFormValues {
    $version = ConvertTo-CB5Text $inputVersionCombo.SelectedItem
    $rule = Get-CB5UpdateRule -Version $version -ModemDefectConfirmed $false
    $indicated = ""
    $components = ""
    if ($rule.Encontrada) {
        $indicated = "$($rule.Origem) → $($rule.Destino)"
        if ($rule.CondicionalAoModem) { $indicated += " (decisão do outro setor se houver defeito no modem)" }
        $components = $rule.Componentes
    }
    $finalResult = ConvertTo-CB5Text $finalResultCombo.SelectedItem
    if ($finalResult -eq "Selecione...") { $finalResult = "" }

    return @{
        Serie = $serialBox.Text.Trim()
        Codigo = ConvertTo-CB5Text $codeCombo.SelectedItem
        VersaoEntrada = $version
        VersaoSaida = ConvertTo-CB5Text $outputVersionCombo.SelectedItem
        DataEntrada = $entryDatePicker.Value.Date
        DefeitoReportado = $reportedDefectBox.Text.Trim()
        DefeitoEncontrado = $foundDefectBox.Text.Trim()
        OutrosDefeitos = $otherDefectsBox.Text.Trim()
        ManutencaoRealizada = $maintenanceBox.Text.Trim()
        ResultadoFinal = $finalResult
        DefeitoModemConfirmado = $false
        AtualizacaoIndicada = $indicated
        ComponentesExternos = $components
        Encaminhamento = ""
        DataEncaminhamento = ""
        DataRetornoSetor = ""
        InspecaoVisual = $false
        TesteAlimentacao = $false
        TesteComunicacao = $false
        PingResultado = ""
        PTResultado = ""
        OutrosTestes = ""
        Observacoes = $notesBox.Text.Trim()
    }
}

function Show-ValidationErrors {
    param([object]$Validation)
    if ($Validation.Valido) { return $true }
    [Windows.Forms.MessageBox]::Show(
        "Corrija os pontos abaixo:`r`n`r`n• " + ($Validation.Erros -join "`r`n• "),
        "Não foi possível salvar",
        [Windows.Forms.MessageBoxButtons]::OK,
        [Windows.Forms.MessageBoxIcon]::Warning
    ) | Out-Null
    return $false
}

function Save-CurrentPassage {
    param([bool]$Complete = $false)

    $values = Get-PassageFormValues
    $validationForCompletion = $Complete
    if ($script:CorrectionMode) {
        $currentRecord = Get-CB5PassageById -Store $script:Store -Id $script:CurrentPassageId
        if ($null -eq $currentRecord) {
            [Windows.Forms.MessageBox]::Show("O registro selecionado não existe mais na base.", "Correção", "OK", "Error") | Out-Null
            return
        }
        $validationForCompletion = ConvertTo-CB5Boolean $currentRecord.Concluida
    }
    $validation = Get-CB5ValidationResult -Values $values -ForCompletion $validationForCompletion
    if (-not (Show-ValidationErrors $validation)) { return }

    if ($Complete -and @($validation.Avisos).Count -gt 0) {
        $answer = [Windows.Forms.MessageBox]::Show(
            "Há avisos antes da conclusão:`r`n`r`n• " + ($validation.Avisos -join "`r`n• ") + "`r`n`r`nDeseja concluir mesmo assim?",
            "Confirmar conclusão",
            [Windows.Forms.MessageBoxButtons]::YesNo,
            [Windows.Forms.MessageBoxIcon]::Warning
        )
        if ($answer -ne [Windows.Forms.DialogResult]::Yes) { return }
    }

    try {
        if ($script:CorrectionMode) {
            $answer = [Windows.Forms.MessageBox]::Show(
                "Salvar esta correção?`r`n`r`nA série e o número da passagem não mudam. O programa guardará nos eventos quais campos foram alterados, com o valor anterior e o novo.",
                "Confirmar correção",
                [Windows.Forms.MessageBoxButtons]::YesNo,
                [Windows.Forms.MessageBoxIcon]::Question
            )
            if ($answer -ne [Windows.Forms.DialogResult]::Yes) { return }
            $record = Correct-CB5Passage -Store $script:Store -Id $script:CurrentPassageId -Values $values
            if (-not (Save-StoreSafely)) { return }
            Refresh-AllViews
            Set-ModuleStatus "Correção salva com histórico do valor anterior e do novo." "Success"
            [Windows.Forms.MessageBox]::Show(
                "A passagem $($record.Passagem) da série $($record.Serie) foi corrigida.`r`n`r`nA alteração ficou registrada nos eventos e não apagou o histórico.",
                "Correção salva",
                [Windows.Forms.MessageBoxButtons]::OK,
                [Windows.Forms.MessageBoxIcon]::Information
            ) | Out-Null
            Reset-PassageForm
            return
        }
        elseif ([string]::IsNullOrWhiteSpace($script:CurrentPassageId)) {
            $openRecord = Get-CB5OpenPassageBySerial -Store $script:Store -Serial ([string]$values.Serie)
            if ($null -ne $openRecord) {
                [Windows.Forms.MessageBox]::Show(
                    "Esta série já possui uma passagem em aberto. Ela será carregada para você continuar sem duplicar o histórico.",
                    "Passagem já existente",
                    [Windows.Forms.MessageBoxButtons]::OK,
                    [Windows.Forms.MessageBoxIcon]::Information
                ) | Out-Null
                Load-PassageIntoForm $openRecord
                return
            }
            $record = New-CB5Passage -Store $script:Store -Values $values
            $script:CurrentPassageId = [string]$record.Id
        }
        elseif (-not $Complete) {
            $record = Update-CB5Passage -Store $script:Store -Id $script:CurrentPassageId -Values $values -EventType "Atualização" -EventDescription "Dados salvos durante o andamento da passagem."
        }

        if ($Complete) {
            $record = Complete-CB5Passage -Store $script:Store -Id $script:CurrentPassageId -Values $values
        }

        if (-not (Save-StoreSafely)) { return }
        Refresh-AllViews
        if ($Complete) {
            Set-ModuleStatus "Passagem concluída. O histórico anterior da série foi preservado." "Success"
            $resultMessage = switch ([string]$record.ResultadoFinal) {
                "Aprovado" { "Resultado: APROVADO. A peça segue para o próximo setor pelo fluxo normal." }
                "PT" { "Resultado: PT." }
                default { "Passagem encerrada." }
            }
            [Windows.Forms.MessageBox]::Show(
                "Passagem $($record.Passagem) da série $($record.Serie) concluída com sucesso.`r`n`r`n$resultMessage`r`n`r`nO código $($record.Codigo) permanecerá selecionado para a próxima peça do lote.",
                "Registro concluído",
                [Windows.Forms.MessageBoxButtons]::OK,
                [Windows.Forms.MessageBoxIcon]::Information
            ) | Out-Null
            Reset-PassageForm
        }
        else {
            $formModeLabel.Text = "EDITANDO SÉRIE $($record.Serie) — PASSAGEM $($record.Passagem)"
            $serialBox.ReadOnly = $true
            Set-ModuleStatus "Passagem salva. Você pode continuar o trabalho mais tarde." "Success"
            Update-ReturnBanner
        }
    }
    catch {
        [Windows.Forms.MessageBox]::Show(
            $_.Exception.Message,
            "Central de Manutenção CB5",
            [Windows.Forms.MessageBoxButtons]::OK,
            [Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
        Set-ModuleStatus "Não foi possível registrar a passagem." "Error"
    }
}

function Fill-PassageGrid {
    param(
        [Windows.Forms.DataGridView]$Grid,
        [object[]]$Records,
        [int]$Limit = 0
    )
    $Grid.Rows.Clear()
    $items = @($Records | Sort-Object @{Expression = "DataEntrada"; Descending = $true}, @{Expression = "AtualizadoEm"; Descending = $true})
    if ($Limit -gt 0) { $items = @($items | Select-Object -First $Limit) }
    foreach ($record in $items) {
        $returnText = if (ConvertTo-CB5Boolean $record.EhRetorno) { "SIM" } else { "—" }
        $index = $Grid.Rows.Add(
            [string]$record.DataEntrada,
            [string]$record.Serie,
            [string]$record.Passagem,
            $returnText,
            [string]$record.Codigo,
            [string]$record.VersaoEntrada,
            [string]$record.Status,
            [string]$record.DefeitoReportado
        )
        $Grid.Rows[$index].Tag = [string]$record.Id
        if (ConvertTo-CB5Boolean $record.EhRetorno) {
            $Grid.Rows[$index].Cells[3].Style.ForeColor = $script:CurrentPalette.Warning
        }
    }
}

function Refresh-CurrentSeriesHistory {
    $seriesHistoryGrid.Rows.Clear()
    $seriesHistoryDetailsButton.Enabled = $false
    $seriesHistoryFullButton.Enabled = $false

    $serial = $serialBox.Text.Trim()
    if (-not (Test-CB5Serial $serial)) {
        $seriesHistoryStateLabel.Text = "Digite os 8 números da série para consultar suas passagens."
        if ($null -ne $script:CurrentPalette) { $seriesHistoryStateLabel.ForeColor = $script:CurrentPalette.Muted }
        return
    }

    $records = @(Get-CB5PassagesBySerial -Store $script:Store -Serial $serial | Sort-Object @{ Expression = { [int]$_.Passagem }; Descending = $true })
    if ($records.Count -eq 0) {
        $seriesHistoryStateLabel.Text = "Série nova — nenhuma passagem anterior."
        if ($null -ne $script:CurrentPalette) { $seriesHistoryStateLabel.ForeColor = $script:CurrentPalette.Success }
        return
    }

    foreach ($record in $records) {
        $result = ConvertTo-CB5Text $record.ResultadoFinal
        if ([string]::IsNullOrWhiteSpace($result)) { $result = ConvertTo-CB5Text $record.Status }
        if ([string]::IsNullOrWhiteSpace($result)) { $result = "Em aberto" }

        $summary = ConvertTo-CB5Text $record.DefeitoEncontrado
        if ([string]::IsNullOrWhiteSpace($summary)) { $summary = ConvertTo-CB5Text $record.DefeitoReportado }
        if ([string]::IsNullOrWhiteSpace($summary)) { $summary = "Sem defeito descrito" }

        $rowIndex = $seriesHistoryGrid.Rows.Add(
            [string]$record.Passagem,
            [string]$record.DataEntrada,
            $result,
            $summary
        )
        $row = $seriesHistoryGrid.Rows[$rowIndex]
        $row.Tag = [string]$record.Id
        $row.Cells[3].ToolTipText = "Manutenção: " + $(if ([string]::IsNullOrWhiteSpace((ConvertTo-CB5Text $record.ManutencaoRealizada))) { "não informada" } else { [string]$record.ManutencaoRealizada })
        if ($null -ne $script:CurrentPalette) {
            switch ($result) {
                "Aprovado" { $row.Cells[2].Style.ForeColor = $script:CurrentPalette.Success }
                "PT" { $row.Cells[2].Style.ForeColor = $script:CurrentPalette.Danger }
                default { $row.Cells[2].Style.ForeColor = $script:CurrentPalette.Warning }
            }
        }
    }

    if ($seriesHistoryGrid.Rows.Count -gt 0) {
        $seriesHistoryGrid.CurrentCell = $seriesHistoryGrid.Rows[0].Cells[0]
        $seriesHistoryDetailsButton.Enabled = $true
        $seriesHistoryFullButton.Enabled = $true
    }
    $seriesHistoryStateLabel.Text = "$($records.Count) passagem(ns) encontrada(s). A mais recente aparece primeiro."
    if ($null -ne $script:CurrentPalette) { $seriesHistoryStateLabel.ForeColor = $script:CurrentPalette.Accent }
}

function Open-CurrentSeriesHistory {
    $serial = $serialBox.Text.Trim()
    if (-not (Test-CB5Serial $serial)) { return }
    $script:IsLoadingForm = $true
    try {
        $historySerialBox.Text = $serial
        $historyCodeCombo.SelectedIndex = 0
        $historyStatusCombo.SelectedIndex = 0
        $historyVersionCombo.SelectedIndex = 0
    }
    finally { $script:IsLoadingForm = $false }
    Refresh-HistoryGrid
    $mainTabs.SelectedTab = $historyTab
}

function Refresh-Dashboard {
    $summary = Get-CB5Summary -Store $script:Store
    $seriesValue.Text = [string]$summary.Series
    $passagesValue.Text = [string]$summary.Passagens
    $openValue.Text = [string]$summary.EmAndamento
    $returnsValue.Text = [string]$summary.Retornos
    Fill-PassageGrid -Grid $recentGrid -Records @($script:Store.Passagens) -Limit 12
    $recentGroup.Text = if (@($script:Store.Passagens).Count -eq 0) {
        "Atividade recente — nenhum registro ainda"
    }
    else {
        "Atividade recente — dê dois cliques para abrir detalhes"
    }
}

function Refresh-HistoryGrid {
    $serialFilter = $historySerialBox.Text.Trim()
    $codeFilter = ConvertTo-CB5Text $historyCodeCombo.SelectedItem
    $statusFilter = ConvertTo-CB5Text $historyStatusCombo.SelectedItem
    $versionFilter = ConvertTo-CB5Text $historyVersionCombo.SelectedItem

    $records = @($script:Store.Passagens | Where-Object {
        ([string]::IsNullOrWhiteSpace($serialFilter) -or [string]$_.Serie -like "*$serialFilter*") -and
        ($codeFilter -eq "Todos" -or [string]$_.Codigo -eq $codeFilter) -and
        ($statusFilter -eq "Todos" -or [string]$_.Status -eq $statusFilter) -and
        ($versionFilter -eq "Todas" -or [string]$_.VersaoEntrada -eq $versionFilter -or [string]$_.VersaoSaida -eq $versionFilter)
    })
    $script:FilteredPassages = $records
    Fill-PassageGrid -Grid $historyGrid -Records $records
    $historyCountLabel.Text = if ($records.Count -eq 0) {
        "Nenhuma passagem encontrada com estes filtros."
    }
    else {
        "$($records.Count) passagem(ns) encontrada(s)"
    }
}

function Fill-StatisticsGrid {
    param(
        [Windows.Forms.DataGridView]$Grid,
        [object[]]$Rows
    )
    $Grid.Rows.Clear()
    foreach ($row in @($Rows)) {
        [void]$Grid.Rows.Add([string]$row.Item, [string]$row.Quantidade, ("{0:N1}%" -f [double]$row.Percentual))
    }
}

function Refresh-Statistics {
    Fill-StatisticsGrid $statsVersionGrid @(Get-CB5StatisticsRows -Store $script:Store -Field "VersaoEntrada")
    Fill-StatisticsGrid $statsCodeGrid @(Get-CB5StatisticsRows -Store $script:Store -Field "Codigo")
    Fill-StatisticsGrid $statsResultGrid @(Get-CB5StatisticsRows -Store $script:Store -Field "ResultadoFinal")
    Fill-StatisticsGrid $statsStatusGrid @(Get-CB5StatisticsRows -Store $script:Store -Field "Status")
    Fill-StatisticsGrid $statsDefectGrid @(Get-CB5StatisticsRows -Store $script:Store -Field "DefeitoEncontrado")
    Fill-StatisticsGrid $statsRepairGrid @(Get-CB5StatisticsRows -Store $script:Store -Field "ManutencaoRealizada")
}

function Fill-DiagnosisGrid {
    param(
        [Windows.Forms.DataGridView]$Grid,
        [object[]]$Suggestions
    )
    $Grid.Rows.Clear()
    foreach ($item in @($Suggestions)) {
        [void]$Grid.Rows.Add(
            [string]$item.Tipo,
            [string]$item.ReparoSugerido,
            [string]$item.DefeitoAssociado,
            [string]$item.Casos,
            [string]$item.Nivel,
            [string]$item.Evidencia
        )
    }
}

function Run-FullDiagnosis {
    $version = ConvertTo-CB5Text $diagnosisVersionCombo.SelectedItem
    $suggestions = @(Get-CB5DiagnosticSuggestions -Store $script:Store -Version $version -ReportedDefect $diagnosisReportedBox.Text -FoundDefect $diagnosisFoundBox.Text)
    Fill-DiagnosisGrid -Grid $diagnosisGrid -Suggestions $suggestions
    $diagnosisResultLabel.Text = if ($suggestions.Count -eq 0) {
        "Nenhum caso semelhante suficiente. O sistema não criará uma sugestão sem base real."
    }
    else {
        "$($suggestions.Count) hipótese(s) baseada(s) em passagens concluídas. Isso não confirma o diagnóstico."
    }
}

function Load-SeriesForDiagnosis {
    $serial = $diagnosisSerialBox.Text.Trim()
    if (-not (Test-CB5Serial $serial)) {
        [Windows.Forms.MessageBox]::Show("Informe uma série com exatamente 8 dígitos.", "Série inválida") | Out-Null
        return
    }
    $records = @(Get-CB5PassagesBySerial -Store $script:Store -Serial $serial)
    if ($records.Count -eq 0) {
        [Windows.Forms.MessageBox]::Show("Nenhuma passagem foi encontrada para esta série.", "Histórico") | Out-Null
        return
    }
    $last = $records[-1]
    $version = [string]$last.VersaoSaida
    if ([string]::IsNullOrWhiteSpace($version)) { $version = [string]$last.VersaoEntrada }
    Set-ComboValue $diagnosisVersionCombo $version
    $diagnosisReportedBox.Text = [string]$last.DefeitoReportado
    $diagnosisFoundBox.Text = [string]$last.DefeitoEncontrado
    Run-FullDiagnosis
}

function Refresh-SchematicGrid {
    $version = ConvertTo-CB5Text $schemaSearchVersionCombo.SelectedItem
    if ($version -eq "Todas") { $version = "" }
    $records = @(Search-CB5SchematicEntries -Store $script:Store -Version $version -Designator $schemaSearchBox.Text)
    $schemaGrid.Rows.Clear()
    foreach ($entry in $records) {
        $fileName = [IO.Path]::GetFileName([string]$entry.Arquivo)
        $index = $schemaGrid.Rows.Add([string]$entry.Versao, [string]$entry.Designador, $fileName, [string]$entry.Pagina, [string]$entry.Area, [string]$entry.Observacoes)
        $schemaGrid.Rows[$index].Tag = [string]$entry.Id
    }
    $schemaCountLabel.Text = "$($records.Count) referência(s) encontrada(s)"
}

function Get-SelectedSchematicEntry {
    if ($schemaGrid.SelectedRows.Count -eq 0) { return $null }
    $id = ConvertTo-CB5Text $schemaGrid.SelectedRows[0].Tag
    return $script:Store.Esquematicos | Where-Object { [string]$_.Id -eq $id } | Select-Object -First 1
}

function Open-SelectedSchematic {
    $entry = Get-SelectedSchematicEntry
    if ($null -eq $entry) {
        [Windows.Forms.MessageBox]::Show("Selecione uma referência na lista.", "Esquemáticos") | Out-Null
        return
    }
    if (-not [IO.File]::Exists([string]$entry.Arquivo)) {
        [Windows.Forms.MessageBox]::Show(
            "O arquivo não foi encontrado no caminho cadastrado:`r`n`r`n$($entry.Arquivo)",
            "Arquivo indisponível",
            [Windows.Forms.MessageBoxButtons]::OK,
            [Windows.Forms.MessageBoxIcon]::Warning
        ) | Out-Null
        return
    }
    $page = ConvertTo-CB5Text $entry.Pagina
    $area = ConvertTo-CB5Text $entry.Area
    if (-not [string]::IsNullOrWhiteSpace($page) -or -not [string]::IsNullOrWhiteSpace($area)) {
        [Windows.Forms.MessageBox]::Show(
            "Local indicado para $($entry.Designador):`r`nPágina: $page`r`nÁrea: $area`r`n`r`nO arquivo será aberto agora. Para PDF com página numérica, a Central tentará abrir diretamente nessa página.",
            "Localização no esquemático",
            [Windows.Forms.MessageBoxButtons]::OK,
            [Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
    }

    $filePath = [string]$entry.Arquivo
    if ([IO.Path]::GetExtension($filePath).ToLowerInvariant() -eq ".pdf" -and $page -match '^\d+$') {
        $fileUri = [Uri]::new($filePath)
        Start-Process -FilePath ($fileUri.AbsoluteUri + "#page=" + $page)
    }
    else {
        Start-Process -FilePath $filePath
    }
}

function Add-SchematicFromForm {
    $version = ConvertTo-CB5Text $schemaEntryVersionCombo.SelectedItem
    $path = $schemaFileBox.Text.Trim()
    if (-not [IO.File]::Exists($path)) {
        [Windows.Forms.MessageBox]::Show("Selecione um arquivo de esquemático existente.", "Arquivo inválido") | Out-Null
        return
    }
    try {
        [void](Add-CB5SchematicEntry -Store $script:Store -Version $version -Designator $schemaDesignatorBox.Text -FilePath $path -Page $schemaPageBox.Text -Area $schemaAreaBox.Text -Notes $schemaNotesBox.Text)
        if (Save-StoreSafely) {
            Refresh-SchematicGrid
            $schemaDesignatorBox.Clear()
            $schemaPageBox.Clear()
            $schemaAreaBox.Clear()
            $schemaNotesBox.Clear()
            Set-ModuleStatus "Referência de esquemático cadastrada." "Success"
        }
    }
    catch {
        [Windows.Forms.MessageBox]::Show($_.Exception.Message, "Esquemáticos") | Out-Null
    }
}

function Remove-SelectedSchematic {
    $entry = Get-SelectedSchematicEntry
    if ($null -eq $entry) { return }
    $answer = [Windows.Forms.MessageBox]::Show(
        "Remover somente esta referência do índice? O arquivo original não será apagado.",
        "Confirmar remoção",
        [Windows.Forms.MessageBoxButtons]::YesNo,
        [Windows.Forms.MessageBoxIcon]::Question
    )
    if ($answer -ne [Windows.Forms.DialogResult]::Yes) { return }
    if (Remove-CB5SchematicEntry -Store $script:Store -Id ([string]$entry.Id)) {
        if (Save-StoreSafely) { Refresh-SchematicGrid }
    }
}

function Export-FilteredHistory {
    if (@($script:FilteredPassages).Count -eq 0) {
        [Windows.Forms.MessageBox]::Show("Não há registros filtrados para exportar.", "Exportação") | Out-Null
        return
    }
    $dialog = New-Object Windows.Forms.SaveFileDialog
    $dialog.Title = "Exportar histórico da Manutenção CB5"
    $dialog.Filter = "Arquivo CSV (*.csv)|*.csv"
    $dialog.FileName = "Historico-Manutencao-CB5-$(Get-Date -Format 'yyyy-MM-dd').csv"
    if ($dialog.ShowDialog($form) -ne [Windows.Forms.DialogResult]::OK) { return }
    try {
        Export-CB5PassagesCsv -Passages @($script:FilteredPassages) -Path $dialog.FileName
        Set-ModuleStatus "Histórico exportado em CSV com sucesso." "Success"
    }
    catch {
        [Windows.Forms.MessageBox]::Show($_.Exception.Message, "Falha na exportação") | Out-Null
    }
    finally { $dialog.Dispose() }
}

function Refresh-AllViews {
    Refresh-Dashboard
    Refresh-HistoryGrid
    Refresh-CurrentSeriesHistory
    Refresh-Statistics
    Refresh-SchematicGrid
}

$settings = Get-MaintenanceSettings
if ($script:IsInProcessHosted -and -not [string]::IsNullOrWhiteSpace($HostTheme)) {
    $settings.Theme = Get-MaintenanceThemeFromHost $HostTheme
}

if ($script:IsInProcessHosted) {
    # Hospedagem real: a Manutenção deixa de ser um Form com tamanho próprio e
    # passa a ser um UserControl. Assim ela não conhece o tamanho do monitor:
    # conhece somente a área EXATA que a Central de Trabalho reservou para ela.
    $form = New-Object Windows.Forms.UserControl
    $form.Name = "MaintenanceHostedControl"
    $form.AutoScaleMode = [Windows.Forms.AutoScaleMode]::None
    $form.Font = [Drawing.Font]::new("Segoe UI", 9.0)
    $form.MinimumSize = [Drawing.Size]::new(1, 1)
    $form.Margin = [Windows.Forms.Padding]::new(0)
    $form.Dock = [Windows.Forms.DockStyle]::Fill
}
else {
    $form = New-Object Windows.Forms.Form
    $form.Text = "Central de Manutenção CB5"
    $form.StartPosition = [Windows.Forms.FormStartPosition]::CenterScreen
    $form.AutoScaleMode = [Windows.Forms.AutoScaleMode]::Dpi
    $form.Font = [Drawing.Font]::new("Segoe UI", 9.5)
    $form.MinimumSize = [Drawing.Size]::new(1000, 650)
    $form.MaximizeBox = $true
    $form.MinimizeBox = $true
    $form.SizeGripStyle = [Windows.Forms.SizeGripStyle]::Show

    $workingArea = [Windows.Forms.Screen]::PrimaryScreen.WorkingArea
    $targetWidth = [Math]::Min($workingArea.Width, [Math]::Max(900, [int]($workingArea.Width * 0.94)))
    $targetHeight = [Math]::Min($workingArea.Height, [Math]::Max(600, [int]($workingArea.Height * 0.94)))
    $form.Size = [Drawing.Size]::new([int]$targetWidth, [int]$targetHeight)
    Initialize-EmbeddedModuleWindow $form
}

$rootLayout = New-Object Windows.Forms.TableLayoutPanel
$rootLayout.Dock = [Windows.Forms.DockStyle]::Fill
$rootLayout.ColumnCount = 1
$rootLayout.RowCount = 3
$rootLayout.Margin = [Windows.Forms.Padding]::new(0)
$rootLayout.Padding = [Windows.Forms.Padding]::new(0)
[void]$rootLayout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 92)))
[void]$rootLayout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 100)))
[void]$rootLayout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 46)))
$form.Controls.Add($rootLayout)

$headerPanel = New-Object Windows.Forms.Panel
$headerPanel.Dock = [Windows.Forms.DockStyle]::Fill
$headerPanel.Padding = [Windows.Forms.Padding]::new(24, 12, 20, 10)
$rootLayout.Controls.Add($headerPanel, 0, 0)

$headerLayout = New-Object Windows.Forms.TableLayoutPanel
$headerLayout.Dock = [Windows.Forms.DockStyle]::Fill
$headerLayout.ColumnCount = 3
[void]$headerLayout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 100)))
[void]$headerLayout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Absolute, 190)))
[void]$headerLayout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Absolute, 170)))
$headerPanel.Controls.Add($headerLayout)

$titleLayout = New-Object Windows.Forms.TableLayoutPanel
$titleLayout.Dock = [Windows.Forms.DockStyle]::Fill
$titleLayout.RowCount = 2
$titleLayout.ColumnCount = 1
[void]$titleLayout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 62)))
[void]$titleLayout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 38)))
$headerLayout.Controls.Add($titleLayout, 0, 0)

$appTitle = New-Object Windows.Forms.Label
$appTitle.Text = "Central de Manutenção CB5"
$appTitle.Dock = [Windows.Forms.DockStyle]::Fill
$appTitle.TextAlign = [Drawing.ContentAlignment]::BottomLeft
$appTitle.Font = [Drawing.Font]::new("Segoe UI Semibold", 22)
$titleLayout.Controls.Add($appTitle, 0, 0)

$appSubtitle = New-Object Windows.Forms.Label
$appSubtitle.Text = "Registro, assistência técnica, retornos e apoio ao diagnóstico — sem cronômetro"
$appSubtitle.Dock = [Windows.Forms.DockStyle]::Fill
$appSubtitle.TextAlign = [Drawing.ContentAlignment]::TopLeft
$titleLayout.Controls.Add($appSubtitle, 0, 1)

$themePanel = New-Object Windows.Forms.TableLayoutPanel
$themePanel.Dock = [Windows.Forms.DockStyle]::Fill
$themePanel.Padding = [Windows.Forms.Padding]::new(8, 3, 8, 3)
$themePanel.RowCount = 2
[void]$themePanel.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 26)))
[void]$themePanel.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 34)))
$headerLayout.Controls.Add($themePanel, 1, 0)

$themeLabel = New-Object Windows.Forms.Label
$themeLabel.Text = "Aparência"
$themeLabel.Dock = [Windows.Forms.DockStyle]::Fill
$themeLabel.TextAlign = [Drawing.ContentAlignment]::BottomLeft
$themePanel.Controls.Add($themeLabel, 0, 0)

$themeCombo = New-Object Windows.Forms.ComboBox
$themeCombo.Dock = [Windows.Forms.DockStyle]::Fill
$themeCombo.DropDownStyle = [Windows.Forms.ComboBoxStyle]::DropDownList
[void]$themeCombo.Items.AddRange(@("Claro moderno", "Escuro grafite", "Técnico industrial", "Alto contraste"))
$themeCombo.SelectedItem = $settings.Theme
if ($themeCombo.SelectedIndex -lt 0) { $themeCombo.SelectedIndex = 0 }
$themePanel.Controls.Add($themeCombo, 0, 1)

$versionBadge = New-Object Windows.Forms.Label
$versionBadge.Text = "  VERSÃO $($script:AppVersion)  "
$versionBadge.AutoSize = $true
$versionBadge.Anchor = [Windows.Forms.AnchorStyles]::None
$versionBadge.Font = [Drawing.Font]::new("Segoe UI Semibold", 10)
$versionBadge.Padding = [Windows.Forms.Padding]::new(8, 7, 8, 7)
$headerLayout.Controls.Add($versionBadge, 2, 0)

$mainTabs = New-Object Windows.Forms.TabControl
$mainTabs.Dock = [Windows.Forms.DockStyle]::Fill
$mainTabs.Margin = [Windows.Forms.Padding]::new(0)
$mainTabs.Alignment = [Windows.Forms.TabAlignment]::Top
$mainTabs.Appearance = [Windows.Forms.TabAppearance]::Normal
$mainTabs.DrawMode = [Windows.Forms.TabDrawMode]::OwnerDrawFixed
$mainTabs.HotTrack = $true
$mainTabs.ShowToolTips = $true
if ($script:IsInProcessHosted) {
    # Tamanho fixo evita o desaparecimento visual da faixa de navegação do
    # TabControl quando ele está hospedado. Multiline quebra em duas linhas
    # apenas quando realmente necessário.
    $mainTabs.SizeMode = [Windows.Forms.TabSizeMode]::Fixed
    $mainTabs.ItemSize = [Drawing.Size]::new(138, 28)
    $mainTabs.Multiline = $true
    $mainTabs.Padding = [Drawing.Point]::new(4, 2)
}
else {
    $mainTabs.SizeMode = [Windows.Forms.TabSizeMode]::Normal
    $mainTabs.Padding = [Drawing.Point]::new(14, 7)
}
if ($script:IsInProcessHosted) {
    $tabsViewport = New-Object Windows.Forms.Panel
    $tabsViewport.Dock = [Windows.Forms.DockStyle]::Fill
    $tabsViewport.Margin = [Windows.Forms.Padding]::new(0)
    $tabsViewport.Padding = [Windows.Forms.Padding]::new(0)
    $tabsViewport.AutoScroll = $false
    $rootLayout.Controls.Add($tabsViewport, 0, 1)

    $mainTabs.Dock = [Windows.Forms.DockStyle]::None
    $mainTabs.Anchor = [Windows.Forms.AnchorStyles]::Top -bor [Windows.Forms.AnchorStyles]::Bottom -bor [Windows.Forms.AnchorStyles]::Left -bor [Windows.Forms.AnchorStyles]::Right
    $tabsViewport.Controls.Add($mainTabs)
    $tabsViewport.Add_SizeChanged({
        try {
            $hiddenTabStrip = 31
            $mainTabs.Location = [Drawing.Point]::new(0, -$hiddenTabStrip)
            $mainTabs.Size = [Drawing.Size]::new([Math]::Max(1, $tabsViewport.ClientSize.Width), [Math]::Max(1, $tabsViewport.ClientSize.Height + $hiddenTabStrip))
        } catch {}
    })
    try {
        $hiddenTabStrip = 31
        $mainTabs.Location = [Drawing.Point]::new(0, -$hiddenTabStrip)
        $mainTabs.Size = [Drawing.Size]::new([Math]::Max(1, $tabsViewport.ClientSize.Width), [Math]::Max(1, $tabsViewport.ClientSize.Height + $hiddenTabStrip))
    } catch {}
}
else {
    $rootLayout.Controls.Add($mainTabs, 0, 1)
}

$dashboardTab = New-Object Windows.Forms.TabPage
$dashboardTab.Text = "Visão geral"
$dashboardTab.ToolTipText = "Visão geral da Central de Manutenção"
$mainTabs.TabPages.Add($dashboardTab)

$dashboardRoot = New-Object Windows.Forms.TableLayoutPanel
$dashboardRoot.Dock = [Windows.Forms.DockStyle]::Fill
$dashboardRoot.Padding = if ($script:IsInProcessHosted) { [Windows.Forms.Padding]::new(12) } else { [Windows.Forms.Padding]::new(18) }
$dashboardRoot.RowCount = 4
$dashboardRoot.ColumnCount = 1
$dashboardIntroHeight = if ($script:IsInProcessHosted) { 56 } else { 68 }
$dashboardCardsHeight = if ($script:IsInProcessHosted) { 122 } else { 138 }
[void]$dashboardRoot.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, $dashboardIntroHeight)))
[void]$dashboardRoot.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, $dashboardCardsHeight)))
[void]$dashboardRoot.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 46)))
[void]$dashboardRoot.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 100)))
$dashboardTab.Controls.Add($dashboardRoot)

$dashboardIntro = New-Object Windows.Forms.TableLayoutPanel
$dashboardIntro.Dock = [Windows.Forms.DockStyle]::Fill
$dashboardIntro.ColumnCount = 2
[void]$dashboardIntro.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 100)))
$dashboardActionWidth = if ($script:IsInProcessHosted) { 170 } else { 190 }
[void]$dashboardIntro.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Absolute, $dashboardActionWidth)))
$dashboardRoot.Controls.Add($dashboardIntro, 0, 0)

$dashboardHeading = New-Object Windows.Forms.TableLayoutPanel
$dashboardHeading.Dock = [Windows.Forms.DockStyle]::Fill
$dashboardHeading.RowCount = 2
$dashboardHeading.ColumnCount = 1
$dashboardHeading.Margin = [Windows.Forms.Padding]::new(0)
[void]$dashboardHeading.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 58)))
[void]$dashboardHeading.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 42)))
$dashboardIntro.Controls.Add($dashboardHeading, 0, 0)

$dashboardTitle = New-Object Windows.Forms.Label
$dashboardTitle.Text = "Visão geral da manutenção"
$dashboardTitle.Dock = [Windows.Forms.DockStyle]::Fill
$dashboardTitle.TextAlign = [Drawing.ContentAlignment]::BottomLeft
$dashboardTitle.Font = [Drawing.Font]::new("Segoe UI Semibold", $(if ($script:IsInProcessHosted) { 15.5 } else { 17 }))
$dashboardHeading.Controls.Add($dashboardTitle, 0, 0)

$dashboardSubtitle = New-Object Windows.Forms.Label
$dashboardSubtitle.Text = "Acompanhe passagens, pendências, retornos e atividade recente."
$dashboardSubtitle.Dock = [Windows.Forms.DockStyle]::Fill
$dashboardSubtitle.TextAlign = [Drawing.ContentAlignment]::TopLeft
$dashboardSubtitle.AutoEllipsis = $true
$dashboardHeading.Controls.Add($dashboardSubtitle, 0, 1)

$dashboardNewButton = New-Object Windows.Forms.Button
$dashboardNewButton.Text = "+  NOVA PASSAGEM"
$dashboardNewButton.Dock = [Windows.Forms.DockStyle]::Fill
$dashboardNewButton.Margin = if ($script:IsInProcessHosted) { [Windows.Forms.Padding]::new(8, 7, 0, 7) } else { [Windows.Forms.Padding]::new(8, 10, 0, 10) }
$dashboardNewButton.Tag = "Action"
$dashboardIntro.Controls.Add($dashboardNewButton, 1, 0)

$cardsLayout = New-Object Windows.Forms.TableLayoutPanel
$cardsLayout.Dock = [Windows.Forms.DockStyle]::Fill
$cardsLayout.ColumnCount = 4
for ($i = 0; $i -lt 4; $i++) { [void]$cardsLayout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 25))) }
$dashboardRoot.Controls.Add($cardsLayout, 0, 1)

$script:SummaryCardDecorations = @()
function New-SummaryCard {
    param([string]$Title, [string]$Kind, [ref]$ValueLabel)
    $card = New-Object Windows.Forms.Panel
    $card.Dock = [Windows.Forms.DockStyle]::Fill
    $card.Margin = [Windows.Forms.Padding]::new(5)
    $card.Padding = [Windows.Forms.Padding]::new(0)
    $card.Tag = "SummaryCard"

    $frame = New-Object Windows.Forms.TableLayoutPanel
    $frame.Dock = [Windows.Forms.DockStyle]::Fill
    $frame.Margin = [Windows.Forms.Padding]::new(0)
    $frame.Padding = [Windows.Forms.Padding]::new(0)
    $frame.ColumnCount = 2
    $frame.RowCount = 1
    [void]$frame.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Absolute, 5)))
    [void]$frame.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 100)))
    $card.Controls.Add($frame)

    $accentBar = New-Object Windows.Forms.Panel
    $accentBar.Dock = [Windows.Forms.DockStyle]::Fill
    $accentBar.Margin = [Windows.Forms.Padding]::new(0)
    $frame.Controls.Add($accentBar, 0, 0)

    $content = New-Object Windows.Forms.TableLayoutPanel
    $content.Dock = [Windows.Forms.DockStyle]::Fill
    $content.Margin = [Windows.Forms.Padding]::new(0)
    $content.Padding = if ($script:IsInProcessHosted) { [Windows.Forms.Padding]::new(13, 8, 10, 7) } else { [Windows.Forms.Padding]::new(16, 11, 12, 9) }
    $content.RowCount = 2
    [void]$content.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 58)))
    [void]$content.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 42)))
    $frame.Controls.Add($content, 1, 0)

    $value = New-Object Windows.Forms.Label
    $value.Text = "0"
    $value.Dock = [Windows.Forms.DockStyle]::Fill
    $value.TextAlign = [Drawing.ContentAlignment]::BottomLeft
    $value.Font = [Drawing.Font]::new("Segoe UI Semibold", $(if ($script:IsInProcessHosted) { 22 } else { 25 }))
    $content.Controls.Add($value, 0, 0)

    $label = New-Object Windows.Forms.Label
    $label.Text = $Title
    $label.Dock = [Windows.Forms.DockStyle]::Fill
    $label.TextAlign = [Drawing.ContentAlignment]::TopLeft
    $label.AutoEllipsis = $true
    $content.Controls.Add($label, 0, 1)

    $script:SummaryCardDecorations += [pscustomobject]@{ Card = $card; Bar = $accentBar; Value = $value; Kind = $Kind }
    $card.Add_Resize({ Set-MaintenanceRoundedRegion $this 10 })
    $ValueLabel.Value = $value
    return $card
}

$seriesValue = $null
$cardSeries = New-SummaryCard "Séries diferentes" "Accent" ([ref]$seriesValue)
$cardsLayout.Controls.Add($cardSeries, 0, 0)
$passagesValue = $null
$cardPassages = New-SummaryCard "Passagens registradas" "Info" ([ref]$passagesValue)
$cardsLayout.Controls.Add($cardPassages, 1, 0)
$openValue = $null
$cardOpen = New-SummaryCard "Em aberto" "Action" ([ref]$openValue)
$cardsLayout.Controls.Add($cardOpen, 2, 0)
$returnsValue = $null
$cardReturns = New-SummaryCard "Retornos identificados" "Success" ([ref]$returnsValue)
$cardsLayout.Controls.Add($cardReturns, 3, 0)

$dashboardNavigation = New-Object Windows.Forms.TableLayoutPanel
$dashboardNavigation.Dock = [Windows.Forms.DockStyle]::Fill
$dashboardNavigation.ColumnCount = 5
$dashboardNavigation.RowCount = 1
$dashboardNavigation.Margin = [Windows.Forms.Padding]::new(4, 3, 4, 3)
for ($i = 0; $i -lt 5; $i++) { [void]$dashboardNavigation.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 20))) }
$dashboardRoot.Controls.Add($dashboardNavigation, 0, 2)

function New-DashboardNavButton([string]$Text) {
    $button = New-Object Windows.Forms.Button
    $button.Text = $Text
    $button.Dock = [Windows.Forms.DockStyle]::Fill
    $button.Margin = [Windows.Forms.Padding]::new(3, 2, 3, 2)
    $button.Font = [Drawing.Font]::new("Segoe UI Semibold", 8.0)
    $button.Tag = "Secondary"
    return $button
}

$dashboardHistoryButton = New-DashboardNavButton "HISTÓRICO"
$dashboardStatsButton = New-DashboardNavButton "ESTATÍSTICAS"
$dashboardDiagnosisButton = New-DashboardNavButton "DIAGNÓSTICO"
$dashboardSchematicsButton = New-DashboardNavButton "ESQUEMÁTICOS"
$dashboardRulesButton = New-DashboardNavButton "REGRAS / DADOS"
$dashboardNavigation.Controls.Add($dashboardHistoryButton, 0, 0)
$dashboardNavigation.Controls.Add($dashboardStatsButton, 1, 0)
$dashboardNavigation.Controls.Add($dashboardDiagnosisButton, 2, 0)
$dashboardNavigation.Controls.Add($dashboardSchematicsButton, 3, 0)
$dashboardNavigation.Controls.Add($dashboardRulesButton, 4, 0)

$recentGroup = New-Object Windows.Forms.GroupBox
$recentGroup.Text = "Atividade recente"
$recentGroup.Dock = [Windows.Forms.DockStyle]::Fill
$recentGroup.Padding = if ($script:IsInProcessHosted) { [Windows.Forms.Padding]::new(8, 18, 8, 8) } else { [Windows.Forms.Padding]::new(10, 20, 10, 10) }
$dashboardRoot.Controls.Add($recentGroup, 0, 3)
$recentGrid = New-Grid
foreach ($column in @(
    @("Data", "Data", 115, "Fixed", 100), @("Serie", "Série", 95, "Fixed", 85), @("Passagem", "Passagem", 80, "Fixed", 70),
    @("Retorno", "Retorno", 70, "Fixed", 65), @("Codigo", "Código", 75, "Fixed", 65), @("Versao", "Versão", 95, "Fixed", 80),
    @("Status", "Situação", 105, "Fixed", 90), @("Defeito", "Defeito reportado", 100, "Fill", 190)
)) { Add-GridColumn $recentGrid $column[0] $column[1] $column[2] $column[3] $column[4] }
$recentGroup.Controls.Add($recentGrid)

$passageTab = New-Object Windows.Forms.TabPage
$passageTab.Text = "Passagem"
$passageTab.ToolTipText = "Passagem e manutenção"
$mainTabs.TabPages.Add($passageTab)

$passageRoot = New-Object Windows.Forms.TableLayoutPanel
$passageRoot.Dock = [Windows.Forms.DockStyle]::Fill
$passageRoot.Padding = [Windows.Forms.Padding]::new(12)
$passageRoot.ColumnCount = 2
$passageRoot.RowCount = 1
[void]$passageRoot.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 66)))
[void]$passageRoot.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 34)))
$passageTab.Controls.Add($passageRoot)

$passageScroll = New-Object Windows.Forms.Panel
$passageScroll.Dock = [Windows.Forms.DockStyle]::Fill
$passageScroll.AutoScroll = $true
$passageScroll.Padding = [Windows.Forms.Padding]::new(0, 0, 10, 0)
$passageRoot.Controls.Add($passageScroll, 0, 0)

$passageContent = New-Object Windows.Forms.TableLayoutPanel
$passageContent.Dock = [Windows.Forms.DockStyle]::Top
$passageContent.AutoSize = $true
$passageContent.AutoSizeMode = [Windows.Forms.AutoSizeMode]::GrowAndShrink
$passageContent.ColumnCount = 1
$passageContent.RowCount = 6
$passageScroll.Controls.Add($passageContent)

$modePanel = New-Object Windows.Forms.Panel
$modePanel.Dock = [Windows.Forms.DockStyle]::Top
$modePanel.Height = 48
$modePanel.Margin = [Windows.Forms.Padding]::new(0, 0, 0, 6)
$modePanel.Padding = [Windows.Forms.Padding]::new(10, 0, 10, 0)
$modePanel.Add_SizeChanged({ Set-MaintenanceRoundedRegion $this 9 })
$formModeLabel = New-Object Windows.Forms.Label
$formModeLabel.Text = "NOVA PASSAGEM"
$formModeLabel.Dock = [Windows.Forms.DockStyle]::Fill
$formModeLabel.Padding = [Windows.Forms.Padding]::new(4, 0, 4, 0)
$formModeLabel.TextAlign = [Drawing.ContentAlignment]::MiddleLeft
if ($script:IsInProcessHosted) {
    $formModeLabel.Font = [Drawing.Font]::new("Segoe UI Semibold", 13.5)
}
else {
    $formModeLabel.Font = [Drawing.Font]::new("Segoe UI Semibold", 15)
}
$modePanel.Controls.Add($formModeLabel)
$passageContent.Controls.Add($modePanel, 0, 0)

$identityGroup = New-Object Windows.Forms.GroupBox
$identityGroup.Text = "1. Identificação"
$identityGroup.Dock = [Windows.Forms.DockStyle]::Top
$identityGroup.Height = 205
$identityGroup.Padding = [Windows.Forms.Padding]::new(12, 22, 12, 10)
$identityGroup.Margin = [Windows.Forms.Padding]::new(0, 0, 0, 10)
$passageContent.Controls.Add($identityGroup, 0, 1)

$identityLayout = New-Object Windows.Forms.TableLayoutPanel
$identityLayout.Dock = [Windows.Forms.DockStyle]::Fill
$identityLayout.ColumnCount = 4
$identityLayout.RowCount = 4
for ($i = 0; $i -lt 4; $i++) { [void]$identityLayout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 25))) }
[void]$identityLayout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 26)))
[void]$identityLayout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 38)))
[void]$identityLayout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 26)))
[void]$identityLayout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 40)))
$identityGroup.Controls.Add($identityLayout)

$identityLabels = @("Código", "Série", "Versão de entrada", "Data de entrada")
for ($i = 0; $i -lt 4; $i++) {
    $label = New-Object Windows.Forms.Label
    $label.Text = $identityLabels[$i]
    $label.Dock = [Windows.Forms.DockStyle]::Fill
    $label.TextAlign = [Drawing.ContentAlignment]::BottomLeft
    $identityLayout.Controls.Add($label, $i, 0)
}

$codeCombo = New-Object Windows.Forms.ComboBox
$codeCombo.Dock = [Windows.Forms.DockStyle]::Fill
$codeCombo.DropDownStyle = [Windows.Forms.ComboBoxStyle]::DropDownList
Add-ComboItems $codeCombo @(Get-CB5CodeCatalog)
$identityLayout.Controls.Add($codeCombo, 0, 1)

$serialBox = New-Object Windows.Forms.TextBox
$serialBox.MaxLength = 8
$serialBox.Dock = [Windows.Forms.DockStyle]::Fill
if ($script:IsInProcessHosted) {
    $serialBox.Font = [Drawing.Font]::new("Consolas", 11)
}
else {
    $serialBox.Font = [Drawing.Font]::new("Consolas", 12)
}
$identityLayout.Controls.Add($serialBox, 1, 1)

$inputVersionCombo = New-Object Windows.Forms.ComboBox
$inputVersionCombo.Dock = [Windows.Forms.DockStyle]::Fill
$inputVersionCombo.DropDownStyle = [Windows.Forms.ComboBoxStyle]::DropDownList
Add-ComboItems $inputVersionCombo @(Get-CB5VersionCatalog)
$identityLayout.Controls.Add($inputVersionCombo, 2, 1)

$entryDatePicker = New-Object Windows.Forms.DateTimePicker
$entryDatePicker.Dock = [Windows.Forms.DockStyle]::Fill
$entryDatePicker.Format = [Windows.Forms.DateTimePickerFormat]::Custom
$entryDatePicker.CustomFormat = "dd/MM/yyyy"
$identityLayout.Controls.Add($entryDatePicker, 3, 1)

$outputLabel = New-Object Windows.Forms.Label
$outputLabel.Text = "Versão de saída"
$outputLabel.Dock = [Windows.Forms.DockStyle]::Fill
$outputLabel.TextAlign = [Drawing.ContentAlignment]::BottomLeft
$identityLayout.Controls.Add($outputLabel, 0, 2)

$outputVersionCombo = New-Object Windows.Forms.ComboBox
$outputVersionCombo.Dock = [Windows.Forms.DockStyle]::Fill
$outputVersionCombo.DropDownStyle = [Windows.Forms.ComboBoxStyle]::DropDownList
Add-ComboItems $outputVersionCombo @(Get-CB5VersionCatalog)
$identityLayout.Controls.Add($outputVersionCombo, 0, 3)
$identityLayout.SetColumnSpan($outputVersionCombo, 2)

$automaticFlowLabel = New-Object Windows.Forms.Label
$automaticFlowLabel.Text = "A passagem fica aberta até a conclusão como Aprovado ou PT."
$automaticFlowLabel.Dock = [Windows.Forms.DockStyle]::Fill
$automaticFlowLabel.Margin = [Windows.Forms.Padding]::new(8, 2, 0, 2)
$automaticFlowLabel.Padding = [Windows.Forms.Padding]::new(10, 3, 8, 3)
$automaticFlowLabel.TextAlign = [Drawing.ContentAlignment]::MiddleLeft
$automaticFlowLabel.Add_SizeChanged({ Set-MaintenanceRoundedRegion $this 8 })
$identityLayout.Controls.Add($automaticFlowLabel, 2, 2)
$identityLayout.SetColumnSpan($automaticFlowLabel, 2)
$identityLayout.SetRowSpan($automaticFlowLabel, 2)

$defectsGroup = New-Object Windows.Forms.GroupBox
$defectsGroup.Text = "2. Defeitos e diagnóstico"
$defectsGroup.Dock = [Windows.Forms.DockStyle]::Top
$defectsGroup.Height = 245
$defectsGroup.Padding = [Windows.Forms.Padding]::new(12, 22, 12, 10)
$defectsGroup.Margin = [Windows.Forms.Padding]::new(0, 0, 0, 10)
$passageContent.Controls.Add($defectsGroup, 0, 2)

$defectsLayout = New-Object Windows.Forms.TableLayoutPanel
$defectsLayout.Dock = [Windows.Forms.DockStyle]::Fill
$defectsLayout.ColumnCount = 3
$defectsLayout.RowCount = 2
for ($i = 0; $i -lt 3; $i++) { [void]$defectsLayout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 33.333))) }
[void]$defectsLayout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 30)))
[void]$defectsLayout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 100)))
$defectsGroup.Controls.Add($defectsLayout)

foreach ($item in @(@("Defeito reportado *", 0), @("Defeito encontrado", 1), @("Outros defeitos", 2))) {
    $label = New-Object Windows.Forms.Label
    $label.Text = $item[0]
    $label.Dock = [Windows.Forms.DockStyle]::Fill
    $label.TextAlign = [Drawing.ContentAlignment]::BottomLeft
    $defectsLayout.Controls.Add($label, $item[1], 0)
}
$reportedDefectBox = New-Object Windows.Forms.TextBox
$reportedDefectBox.Multiline = $true
$reportedDefectBox.ScrollBars = [Windows.Forms.ScrollBars]::Vertical
$reportedDefectBox.Dock = [Windows.Forms.DockStyle]::Fill
$reportedDefectBox.Margin = [Windows.Forms.Padding]::new(3, 3, 7, 3)
$defectsLayout.Controls.Add($reportedDefectBox, 0, 1)
$foundDefectBox = New-Object Windows.Forms.TextBox
$foundDefectBox.Multiline = $true
$foundDefectBox.ScrollBars = [Windows.Forms.ScrollBars]::Vertical
$foundDefectBox.Dock = [Windows.Forms.DockStyle]::Fill
$foundDefectBox.Margin = [Windows.Forms.Padding]::new(7, 3, 7, 3)
$defectsLayout.Controls.Add($foundDefectBox, 1, 1)
$otherDefectsBox = New-Object Windows.Forms.TextBox
$otherDefectsBox.Multiline = $true
$otherDefectsBox.ScrollBars = [Windows.Forms.ScrollBars]::Vertical
$otherDefectsBox.Dock = [Windows.Forms.DockStyle]::Fill
$otherDefectsBox.Margin = [Windows.Forms.Padding]::new(7, 3, 3, 3)
$defectsLayout.Controls.Add($otherDefectsBox, 2, 1)

$maintenanceGroup = New-Object Windows.Forms.GroupBox
$maintenanceGroup.Text = "3. Manutenção realizada"
$maintenanceGroup.Dock = [Windows.Forms.DockStyle]::Top
$maintenanceGroup.Height = 205
$maintenanceGroup.Padding = [Windows.Forms.Padding]::new(12, 22, 12, 10)
$maintenanceGroup.Margin = [Windows.Forms.Padding]::new(0, 0, 0, 10)
$passageContent.Controls.Add($maintenanceGroup, 0, 3)

$maintenanceLayout = New-Object Windows.Forms.TableLayoutPanel
$maintenanceLayout.Dock = [Windows.Forms.DockStyle]::Fill
$maintenanceLayout.ColumnCount = 1
$maintenanceLayout.RowCount = 2
[void]$maintenanceLayout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 28)))
[void]$maintenanceLayout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 100)))
$maintenanceGroup.Controls.Add($maintenanceLayout)

$maintenanceLabel = New-Object Windows.Forms.Label
$maintenanceLabel.Text = "Manutenção realizada"
$maintenanceLabel.Dock = [Windows.Forms.DockStyle]::Fill
$maintenanceLabel.TextAlign = [Drawing.ContentAlignment]::BottomLeft
$maintenanceLayout.Controls.Add($maintenanceLabel, 0, 0)
$maintenanceBox = New-Object Windows.Forms.TextBox
$maintenanceBox.Multiline = $true
$maintenanceBox.ScrollBars = [Windows.Forms.ScrollBars]::Vertical
$maintenanceBox.Dock = [Windows.Forms.DockStyle]::Fill
$maintenanceLayout.Controls.Add($maintenanceBox, 0, 1)

$finalResultGroup = New-Object Windows.Forms.GroupBox
$finalResultGroup.Text = "4. Conclusão"
$finalResultGroup.Dock = [Windows.Forms.DockStyle]::Top
$finalResultGroup.Height = 150
$finalResultGroup.Padding = [Windows.Forms.Padding]::new(12, 22, 12, 10)
$finalResultGroup.Margin = [Windows.Forms.Padding]::new(0, 0, 0, 10)
$passageContent.Controls.Add($finalResultGroup, 0, 4)

$finalResultLayout = New-Object Windows.Forms.TableLayoutPanel
$finalResultLayout.Dock = [Windows.Forms.DockStyle]::Fill
$finalResultLayout.ColumnCount = 2
$finalResultLayout.RowCount = 2
[void]$finalResultLayout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 34)))
[void]$finalResultLayout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 66)))
[void]$finalResultLayout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 28)))
[void]$finalResultLayout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 100)))
$finalResultGroup.Controls.Add($finalResultLayout)

$finalResultLabel = New-Object Windows.Forms.Label
$finalResultLabel.Text = "Resultado ao concluir"
$finalResultLabel.Dock = [Windows.Forms.DockStyle]::Fill
$finalResultLabel.TextAlign = [Drawing.ContentAlignment]::BottomLeft
$finalResultLayout.Controls.Add($finalResultLabel, 0, 0)

$finalResultCombo = New-Object Windows.Forms.ComboBox
$finalResultCombo.Dock = [Windows.Forms.DockStyle]::Top
$finalResultCombo.DropDownStyle = [Windows.Forms.ComboBoxStyle]::DropDownList
Add-ComboItems $finalResultCombo @("Selecione...", "Aprovado", "PT")
$finalResultCombo.SelectedIndex = 0
$finalResultLayout.Controls.Add($finalResultCombo, 0, 1)

$finalResultHelp = New-Object Windows.Forms.Label
$finalResultHelp.Dock = [Windows.Forms.DockStyle]::Fill
$finalResultHelp.Margin = [Windows.Forms.Padding]::new(10, 2, 0, 2)
$finalResultHelp.Padding = [Windows.Forms.Padding]::new(10, 4, 8, 4)
$finalResultHelp.TextAlign = [Drawing.ContentAlignment]::MiddleLeft
$finalResultHelp.Text = "Escolha o resultado somente ao finalizar."
$finalResultHelp.Add_SizeChanged({ Set-MaintenanceRoundedRegion $this 8 })
$finalResultLayout.Controls.Add($finalResultHelp, 1, 0)
$finalResultLayout.SetRowSpan($finalResultHelp, 2)

$notesGroup = New-Object Windows.Forms.GroupBox
$notesGroup.Text = "5. Observações"
$notesGroup.Dock = [Windows.Forms.DockStyle]::Top
$notesGroup.Height = 155
$notesGroup.Padding = [Windows.Forms.Padding]::new(12, 22, 12, 10)
$notesGroup.Margin = [Windows.Forms.Padding]::new(0, 0, 0, 10)
$passageContent.Controls.Add($notesGroup, 0, 5)
$notesBox = New-Object Windows.Forms.TextBox
$notesBox.Multiline = $true
$notesBox.ScrollBars = [Windows.Forms.ScrollBars]::Vertical
$notesBox.Dock = [Windows.Forms.DockStyle]::Fill
$notesGroup.Controls.Add($notesBox)

$passageSide = New-Object Windows.Forms.TableLayoutPanel
$passageSide.Dock = [Windows.Forms.DockStyle]::Fill
$passageSide.Padding = [Windows.Forms.Padding]::new(8, 0, 0, 0)
$passageSide.ColumnCount = 1
$passageSide.RowCount = 6
[void]$passageSide.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 88)))
[void]$passageSide.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 118)))
[void]$passageSide.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 58)))
[void]$passageSide.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 100)))
[void]$passageSide.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 48)))
[void]$passageSide.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 132)))
$passageRoot.Controls.Add($passageSide, 1, 0)

$recordBanner = New-Object Windows.Forms.Label
$recordBanner.Dock = [Windows.Forms.DockStyle]::Fill
$recordBanner.Margin = [Windows.Forms.Padding]::new(0, 0, 0, 6)
$recordBanner.Padding = [Windows.Forms.Padding]::new(11, 7, 11, 7)
$recordBanner.TextAlign = [Drawing.ContentAlignment]::MiddleLeft
$recordBanner.Add_SizeChanged({ Set-MaintenanceRoundedRegion $this 9 })
$recordBanner.Font = [Drawing.Font]::new("Segoe UI Semibold", 9.5)
$passageSide.Controls.Add($recordBanner, 0, 0)

$updateGroup = New-Object Windows.Forms.GroupBox
$updateGroup.Text = "Atualização / próxima etapa"
$updateGroup.Dock = [Windows.Forms.DockStyle]::Fill
$updateGroup.Padding = [Windows.Forms.Padding]::new(10, 22, 10, 10)
$passageSide.Controls.Add($updateGroup, 0, 1)
$updateLayout = New-Object Windows.Forms.TableLayoutPanel
$updateLayout.Dock = [Windows.Forms.DockStyle]::Fill
$updateLayout.RowCount = 1
$updateLayout.ColumnCount = 1
[void]$updateLayout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 100)))
$updateGroup.Controls.Add($updateLayout)
$updateInfo = New-Object Windows.Forms.Label
$updateInfo.Dock = [Windows.Forms.DockStyle]::Fill
$updateInfo.Margin = [Windows.Forms.Padding]::new(0, 0, 0, 2)
$updateInfo.Padding = [Windows.Forms.Padding]::new(9, 6, 9, 6)
$updateInfo.TextAlign = [Drawing.ContentAlignment]::MiddleLeft
$updateInfo.AutoEllipsis = $false
$updateInfo.Add_SizeChanged({ Set-MaintenanceRoundedRegion $this 8 })
$updateLayout.Controls.Add($updateInfo, 0, 0)

$codeRuleLabel = New-Object Windows.Forms.Label
$codeRuleLabel.Dock = [Windows.Forms.DockStyle]::Fill
$codeRuleLabel.Margin = [Windows.Forms.Padding]::new(0, 4, 0, 4)
$codeRuleLabel.Padding = [Windows.Forms.Padding]::new(9, 4, 9, 4)
$codeRuleLabel.TextAlign = [Drawing.ContentAlignment]::MiddleLeft
$codeRuleLabel.Add_SizeChanged({ Set-MaintenanceRoundedRegion $this 8 })
$passageSide.Controls.Add($codeRuleLabel, 0, 2)

$seriesHistoryGroup = New-Object Windows.Forms.GroupBox
$seriesHistoryGroup.Text = "Histórico da série"
$seriesHistoryGroup.Dock = [Windows.Forms.DockStyle]::Fill
$seriesHistoryGroup.Padding = [Windows.Forms.Padding]::new(8, 20, 8, 8)
$passageSide.Controls.Add($seriesHistoryGroup, 0, 3)
$seriesHistoryLayout = New-Object Windows.Forms.TableLayoutPanel
$seriesHistoryLayout.Dock = [Windows.Forms.DockStyle]::Fill
$seriesHistoryLayout.ColumnCount = 1
$seriesHistoryLayout.RowCount = 2
[void]$seriesHistoryLayout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 48)))
[void]$seriesHistoryLayout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 100)))
$seriesHistoryGroup.Controls.Add($seriesHistoryLayout)

$seriesHistoryStateLabel = New-Object Windows.Forms.Label
$seriesHistoryStateLabel.Text = "Digite os 8 números da série para consultar suas passagens."
$seriesHistoryStateLabel.Dock = [Windows.Forms.DockStyle]::Fill
$seriesHistoryStateLabel.Padding = [Windows.Forms.Padding]::new(6, 2, 6, 4)
$seriesHistoryStateLabel.TextAlign = [Drawing.ContentAlignment]::MiddleLeft
$seriesHistoryStateLabel.AutoEllipsis = $true
$seriesHistoryLayout.Controls.Add($seriesHistoryStateLabel, 0, 0)

$seriesHistoryGrid = New-Grid
foreach ($column in @(
    @("Passagem", "Pass.", 64, "Fixed", 58), @("Data", "Data", 92, "Fixed", 82),
    @("Resultado", "Resultado", 88, "Fixed", 78), @("Resumo", "Defeito", 100, "Fill", 130)
)) { Add-GridColumn $seriesHistoryGrid $column[0] $column[1] $column[2] $column[3] $column[4] }
if ($script:IsInProcessHosted) {
    # A coluna lateral integrada é bem menor que a janela independente. As
    # larguras antigas somavam mais que o painel e criavam rolagem horizontal
    # permanente, dando a impressão de conteúdo cortado.
    $seriesHistoryGrid.Columns["Passagem"].MinimumWidth = 40
    $seriesHistoryGrid.Columns["Passagem"].Width = 46
    $seriesHistoryGrid.Columns["Data"].MinimumWidth = 62
    $seriesHistoryGrid.Columns["Data"].Width = 68
    $seriesHistoryGrid.Columns["Resultado"].MinimumWidth = 58
    $seriesHistoryGrid.Columns["Resultado"].Width = 66
    $seriesHistoryGrid.Columns["Resumo"].MinimumWidth = 72
    $seriesHistoryGrid.ScrollBars = [Windows.Forms.ScrollBars]::Vertical
}
$seriesHistoryLayout.Controls.Add($seriesHistoryGrid, 0, 1)

$seriesHistoryActions = New-Object Windows.Forms.TableLayoutPanel
$seriesHistoryActions.Dock = [Windows.Forms.DockStyle]::Fill
$seriesHistoryActions.ColumnCount = 2
$seriesHistoryActions.RowCount = 1
[void]$seriesHistoryActions.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 45)))
[void]$seriesHistoryActions.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 55)))
$passageSide.Controls.Add($seriesHistoryActions, 0, 4)

$seriesHistoryDetailsButton = New-Object Windows.Forms.Button
$seriesHistoryDetailsButton.Text = "VER DETALHES"
$seriesHistoryDetailsButton.Dock = [Windows.Forms.DockStyle]::Fill
$seriesHistoryDetailsButton.Margin = [Windows.Forms.Padding]::new(0, 5, 4, 5)
$seriesHistoryDetailsButton.Tag = "Secondary"
$seriesHistoryDetailsButton.Enabled = $false
$seriesHistoryActions.Controls.Add($seriesHistoryDetailsButton, 0, 0)

$seriesHistoryFullButton = New-Object Windows.Forms.Button
$seriesHistoryFullButton.Text = "ABRIR HISTÓRICO"
$seriesHistoryFullButton.Dock = [Windows.Forms.DockStyle]::Fill
$seriesHistoryFullButton.Margin = [Windows.Forms.Padding]::new(4, 5, 0, 5)
$seriesHistoryFullButton.Tag = "Secondary"
$seriesHistoryFullButton.Enabled = $false
$seriesHistoryActions.Controls.Add($seriesHistoryFullButton, 1, 0)

$actionsLayout = New-Object Windows.Forms.TableLayoutPanel
$actionsLayout.Dock = [Windows.Forms.DockStyle]::Fill
$actionsLayout.RowCount = 3
$actionsLayout.ColumnCount = 1
for ($i = 0; $i -lt 3; $i++) { [void]$actionsLayout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 33.333))) }
$passageSide.Controls.Add($actionsLayout, 0, 5)
$newPassageButton = New-Object Windows.Forms.Button
$newPassageButton.Text = "NOVA / LIMPAR"
$newPassageButton.Dock = [Windows.Forms.DockStyle]::Fill
$newPassageButton.Margin = [Windows.Forms.Padding]::new(0, 2, 0, 2)
$newPassageButton.Tag = "Secondary"
$actionsLayout.Controls.Add($newPassageButton, 0, 0)
$savePassageButton = New-Object Windows.Forms.Button
$savePassageButton.Text = "SALVAR ANDAMENTO"
$savePassageButton.Dock = [Windows.Forms.DockStyle]::Fill
$savePassageButton.Margin = [Windows.Forms.Padding]::new(0, 2, 0, 2)
$savePassageButton.Tag = "Secondary"
$actionsLayout.Controls.Add($savePassageButton, 0, 1)
$completePassageButton = New-Object Windows.Forms.Button
$completePassageButton.Text = "CONCLUIR PASSAGEM"
$completePassageButton.Dock = [Windows.Forms.DockStyle]::Fill
$completePassageButton.Margin = [Windows.Forms.Padding]::new(0, 2, 0, 0)
$completePassageButton.Tag = "Action"
$actionsLayout.Controls.Add($completePassageButton, 0, 2)

$passageToolTip = New-Object Windows.Forms.ToolTip
$passageToolTip.AutoPopDelay = 5000
$passageToolTip.InitialDelay = 350
$passageToolTip.ReshowDelay = 100
$passageToolTip.SetToolTip($serialBox, "Série obrigatória com exatamente 8 dígitos")
$passageToolTip.SetToolTip($inputVersionCombo, "Versão recebida nesta passagem")
$passageToolTip.SetToolTip($outputVersionCombo, "Versão que ficará registrada ao final da passagem")
$passageToolTip.SetToolTip($newPassageButton, "Limpa os campos e inicia uma nova passagem")
$passageToolTip.SetToolTip($savePassageButton, "Salva o andamento sem concluir a passagem")
$passageToolTip.SetToolTip($completePassageButton, "Conclui a passagem com o resultado selecionado")
$passageToolTip.SetToolTip($seriesHistoryDetailsButton, "Mostra os detalhes da passagem selecionada")
$passageToolTip.SetToolTip($seriesHistoryFullButton, "Abre o histórico completo desta série")

$historyTab = New-Object Windows.Forms.TabPage
$historyTab.Text = "Histórico"
$historyTab.ToolTipText = "Histórico de passagens por série"
$mainTabs.TabPages.Add($historyTab)
$historyRoot = New-Object Windows.Forms.TableLayoutPanel
$historyRoot.Dock = [Windows.Forms.DockStyle]::Fill
$historyRoot.Padding = [Windows.Forms.Padding]::new(16)
$historyRoot.RowCount = 3
$historyRoot.ColumnCount = 1
[void]$historyRoot.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 88)))
[void]$historyRoot.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 100)))
[void]$historyRoot.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 58)))
$historyTab.Controls.Add($historyRoot)

$historyFilterGroup = New-Object Windows.Forms.GroupBox
$historyFilterGroup.Text = "Filtros"
$historyFilterGroup.Dock = [Windows.Forms.DockStyle]::Fill
$historyFilterGroup.Padding = [Windows.Forms.Padding]::new(10, 20, 10, 8)
$historyRoot.Controls.Add($historyFilterGroup, 0, 0)
$historyFilterLayout = New-Object Windows.Forms.TableLayoutPanel
$historyFilterLayout.Dock = [Windows.Forms.DockStyle]::Fill
$historyFilterLayout.ColumnCount = 5
[void]$historyFilterLayout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 24)))
[void]$historyFilterLayout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 17)))
[void]$historyFilterLayout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 22)))
[void]$historyFilterLayout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 17)))
[void]$historyFilterLayout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 20)))
$historyFilterGroup.Controls.Add($historyFilterLayout)

$historySerialBox = New-Object Windows.Forms.TextBox
$historySerialBox.Dock = [Windows.Forms.DockStyle]::Fill
$historySerialBox.Tag = "Série"
$historyFilterLayout.Controls.Add($historySerialBox, 0, 0)
$historyCodeCombo = New-Object Windows.Forms.ComboBox
$historyCodeCombo.Dock = [Windows.Forms.DockStyle]::Fill
$historyCodeCombo.DropDownStyle = [Windows.Forms.ComboBoxStyle]::DropDownList
Add-ComboItems $historyCodeCombo (@("Todos") + @(Get-CB5CodeCatalog))
$historyFilterLayout.Controls.Add($historyCodeCombo, 1, 0)
$historyStatusCombo = New-Object Windows.Forms.ComboBox
$historyStatusCombo.Dock = [Windows.Forms.DockStyle]::Fill
$historyStatusCombo.DropDownStyle = [Windows.Forms.ComboBoxStyle]::DropDownList
Add-ComboItems $historyStatusCombo (@("Todos") + @(Get-CB5StatusCatalog))
$historyFilterLayout.Controls.Add($historyStatusCombo, 2, 0)
$historyVersionCombo = New-Object Windows.Forms.ComboBox
$historyVersionCombo.Dock = [Windows.Forms.DockStyle]::Fill
$historyVersionCombo.DropDownStyle = [Windows.Forms.ComboBoxStyle]::DropDownList
Add-ComboItems $historyVersionCombo (@("Todas") + @(Get-CB5VersionCatalog))
$historyFilterLayout.Controls.Add($historyVersionCombo, 3, 0)
$historyClearButton = New-Object Windows.Forms.Button
$historyClearButton.Text = "LIMPAR FILTROS"
$historyClearButton.Dock = [Windows.Forms.DockStyle]::Fill
$historyClearButton.Tag = "Secondary"
$historyFilterLayout.Controls.Add($historyClearButton, 4, 0)

$historyGrid = New-Grid
foreach ($column in @(
    @("Data", "Data", 115, "Fixed", 100), @("Serie", "Série", 95, "Fixed", 85), @("Passagem", "Passagem", 80, "Fixed", 70),
    @("Retorno", "Retorno", 70, "Fixed", 65), @("Codigo", "Código", 75, "Fixed", 65), @("Versao", "Versão", 95, "Fixed", 80),
    @("Status", "Situação", 105, "Fixed", 90), @("Defeito", "Defeito reportado", 100, "Fill", 190)
)) { Add-GridColumn $historyGrid $column[0] $column[1] $column[2] $column[3] $column[4] }
$historyRoot.Controls.Add($historyGrid, 0, 1)

$historyActions = New-Object Windows.Forms.TableLayoutPanel
$historyActions.Dock = [Windows.Forms.DockStyle]::Fill
$historyActions.ColumnCount = 5
[void]$historyActions.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 100)))
for ($i = 1; $i -lt 5; $i++) { [void]$historyActions.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Absolute, 170))) }
$historyRoot.Controls.Add($historyActions, 0, 2)
$historyCountLabel = New-Object Windows.Forms.Label
$historyCountLabel.Dock = [Windows.Forms.DockStyle]::Fill
$historyCountLabel.TextAlign = [Drawing.ContentAlignment]::MiddleLeft
$historyActions.Controls.Add($historyCountLabel, 0, 0)
$viewHistoryButton = New-Object Windows.Forms.Button
$viewHistoryButton.Text = "VISUALIZAR"
$viewHistoryButton.Dock = [Windows.Forms.DockStyle]::Fill
$viewHistoryButton.Margin = [Windows.Forms.Padding]::new(4, 8, 4, 8)
$historyActions.Controls.Add($viewHistoryButton, 1, 0)
$editHistoryButton = New-Object Windows.Forms.Button
$editHistoryButton.Text = "EDITAR / CORRIGIR"
$editHistoryButton.Dock = [Windows.Forms.DockStyle]::Fill
$editHistoryButton.Margin = [Windows.Forms.Padding]::new(4, 8, 4, 8)
$historyActions.Controls.Add($editHistoryButton, 2, 0)
$returnHistoryButton = New-Object Windows.Forms.Button
$returnHistoryButton.Text = "REGISTRAR RETORNO"
$returnHistoryButton.Dock = [Windows.Forms.DockStyle]::Fill
$returnHistoryButton.Margin = [Windows.Forms.Padding]::new(4, 8, 4, 8)
$returnHistoryButton.Tag = "Primary"
$historyActions.Controls.Add($returnHistoryButton, 3, 0)
$exportHistoryButton = New-Object Windows.Forms.Button
$exportHistoryButton.Text = "EXPORTAR CSV"
$exportHistoryButton.Dock = [Windows.Forms.DockStyle]::Fill
$exportHistoryButton.Margin = [Windows.Forms.Padding]::new(4, 8, 0, 8)
$historyActions.Controls.Add($exportHistoryButton, 4, 0)

$statisticsTab = New-Object Windows.Forms.TabPage
$statisticsTab.Text = "Estatísticas"
$statisticsTab.ToolTipText = "Estatísticas da assistência técnica"
$mainTabs.TabPages.Add($statisticsTab)
$statisticsRoot = New-Object Windows.Forms.TableLayoutPanel
$statisticsRoot.Dock = [Windows.Forms.DockStyle]::Fill
$statisticsRoot.Padding = [Windows.Forms.Padding]::new(16)
$statisticsRoot.RowCount = 2
[void]$statisticsRoot.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 66)))
[void]$statisticsRoot.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 100)))
$statisticsTab.Controls.Add($statisticsRoot)

$statisticsHeader = New-Object Windows.Forms.TableLayoutPanel
$statisticsHeader.Dock = [Windows.Forms.DockStyle]::Fill
$statisticsHeader.Margin = [Windows.Forms.Padding]::new(0)
$statisticsHeader.RowCount = 2
$statisticsHeader.ColumnCount = 1
[void]$statisticsHeader.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 58)))
[void]$statisticsHeader.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 42)))
$statisticsRoot.Controls.Add($statisticsHeader, 0, 0)

$statisticsTitle = New-Object Windows.Forms.Label
$statisticsTitle.Text = "Estatísticas da manutenção"
$statisticsTitle.Dock = [Windows.Forms.DockStyle]::Fill
$statisticsTitle.TextAlign = [Drawing.ContentAlignment]::BottomLeft
$statisticsTitle.Font = [Drawing.Font]::new("Segoe UI Semibold", 15)
$statisticsHeader.Controls.Add($statisticsTitle, 0, 0)

$statisticsSubtitle = New-Object Windows.Forms.Label
$statisticsSubtitle.Text = "Distribuições calculadas somente com o histórico real acumulado."
$statisticsSubtitle.Dock = [Windows.Forms.DockStyle]::Fill
$statisticsSubtitle.TextAlign = [Drawing.ContentAlignment]::TopLeft
$statisticsSubtitle.Font = [Drawing.Font]::new("Segoe UI", 8.8)
$statisticsHeader.Controls.Add($statisticsSubtitle, 0, 1)

$statsTabs = New-Object Windows.Forms.TabControl
$statsTabs.Dock = [Windows.Forms.DockStyle]::Fill
$statsTabs.DrawMode = [Windows.Forms.TabDrawMode]::OwnerDrawFixed
$statsTabs.SizeMode = [Windows.Forms.TabSizeMode]::Fixed
$statsTabs.ItemSize = [Drawing.Size]::new(132, 28)
$statsTabs.Multiline = $true
$statsTabs.HotTrack = $true
$statsTabs.Padding = [Drawing.Point]::new(5, 2)
$statisticsRoot.Controls.Add($statsTabs, 0, 1)

function New-StatisticsPage {
    param([string]$Title, [ref]$GridReference)
    $page = New-Object Windows.Forms.TabPage
    $page.Text = $Title
    $grid = New-Grid
    Add-GridColumn $grid "Item" "Item" 100 "Fill" 200
    Add-GridColumn $grid "Quantidade" "Quantidade" 105 "Fixed" 95
    Add-GridColumn $grid "Percentual" "% das passagens" 135 "Fixed" 120
    $page.Controls.Add($grid)
    $GridReference.Value = $grid
    $statsTabs.TabPages.Add($page)
}
$statsVersionGrid = $null
New-StatisticsPage "Por versão" ([ref]$statsVersionGrid)
$statsCodeGrid = $null
New-StatisticsPage "Por código" ([ref]$statsCodeGrid)
$statsResultGrid = $null
New-StatisticsPage "Por resultado final" ([ref]$statsResultGrid)
$statsStatusGrid = $null
New-StatisticsPage "Por status" ([ref]$statsStatusGrid)
$statsDefectGrid = $null
New-StatisticsPage "Por defeito encontrado" ([ref]$statsDefectGrid)
$statsRepairGrid = $null
New-StatisticsPage "Por manutenção" ([ref]$statsRepairGrid)

$diagnosisTab = New-Object Windows.Forms.TabPage
$diagnosisTab.Text = "Diagnóstico"
$diagnosisTab.ToolTipText = "Apoio ao diagnóstico"
$mainTabs.TabPages.Add($diagnosisTab)
$diagnosisRoot = New-Object Windows.Forms.TableLayoutPanel
$diagnosisRoot.Dock = [Windows.Forms.DockStyle]::Fill
$diagnosisRoot.Padding = [Windows.Forms.Padding]::new(16)
$diagnosisRoot.RowCount = 4
[void]$diagnosisRoot.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 82)))
[void]$diagnosisRoot.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 165)))
[void]$diagnosisRoot.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 50)))
[void]$diagnosisRoot.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 100)))
$diagnosisTab.Controls.Add($diagnosisRoot)
$hypothesisNotice = New-Object Windows.Forms.Label
$hypothesisNotice.Text = "IMPORTANTE: toda indicação desta aba é apenas uma HIPÓTESE baseada em casos anteriores. O defeito só deve ser tratado como confirmado após o diagnóstico técnico."
$hypothesisNotice.Dock = [Windows.Forms.DockStyle]::Fill
$hypothesisNotice.Margin = [Windows.Forms.Padding]::new(2, 2, 2, 8)
$hypothesisNotice.Padding = [Windows.Forms.Padding]::new(14, 10, 14, 10)
$hypothesisNotice.TextAlign = [Drawing.ContentAlignment]::MiddleLeft
$hypothesisNotice.Font = [Drawing.Font]::new("Segoe UI Semibold", 9.4)
$hypothesisNotice.Add_SizeChanged({ Set-MaintenanceRoundedRegion $this 10 })
$diagnosisRoot.Controls.Add($hypothesisNotice, 0, 0)

$diagnosisInput = New-Object Windows.Forms.GroupBox
$diagnosisInput.Text = "Dados para procurar casos semelhantes"
$diagnosisInput.Dock = [Windows.Forms.DockStyle]::Fill
$diagnosisInput.Padding = [Windows.Forms.Padding]::new(10, 22, 10, 10)
$diagnosisRoot.Controls.Add($diagnosisInput, 0, 1)
$diagnosisInputLayout = New-Object Windows.Forms.TableLayoutPanel
$diagnosisInputLayout.Dock = [Windows.Forms.DockStyle]::Fill
$diagnosisInputLayout.ColumnCount = 6
$diagnosisInputLayout.RowCount = 2
[void]$diagnosisInputLayout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 16)))
[void]$diagnosisInputLayout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 12)))
[void]$diagnosisInputLayout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 28)))
[void]$diagnosisInputLayout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 28)))
[void]$diagnosisInputLayout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 8)))
[void]$diagnosisInputLayout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 8)))
[void]$diagnosisInputLayout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 34)))
[void]$diagnosisInputLayout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 100)))
$diagnosisInput.Controls.Add($diagnosisInputLayout)
foreach ($item in @(@("Série opcional", 0), @("Versão", 1), @("Defeito reportado", 2), @("Defeito encontrado", 3))) {
    $label = New-Object Windows.Forms.Label
    $label.Text = $item[0]
    $label.Dock = [Windows.Forms.DockStyle]::Fill
    $label.TextAlign = [Drawing.ContentAlignment]::BottomLeft
    $diagnosisInputLayout.Controls.Add($label, $item[1], 0)
}
$diagnosisSerialBox = New-Object Windows.Forms.MaskedTextBox
$diagnosisSerialBox.Mask = "00000000"
$diagnosisSerialBox.TextMaskFormat = [Windows.Forms.MaskFormat]::ExcludePromptAndLiterals
$diagnosisSerialBox.Dock = [Windows.Forms.DockStyle]::Fill
$diagnosisInputLayout.Controls.Add($diagnosisSerialBox, 0, 1)
$diagnosisVersionCombo = New-Object Windows.Forms.ComboBox
$diagnosisVersionCombo.Dock = [Windows.Forms.DockStyle]::Fill
$diagnosisVersionCombo.DropDownStyle = [Windows.Forms.ComboBoxStyle]::DropDownList
Add-ComboItems $diagnosisVersionCombo @(Get-CB5VersionCatalog)
$diagnosisInputLayout.Controls.Add($diagnosisVersionCombo, 1, 1)
$diagnosisReportedBox = New-Object Windows.Forms.TextBox
$diagnosisReportedBox.Multiline = $true
$diagnosisReportedBox.Dock = [Windows.Forms.DockStyle]::Fill
$diagnosisInputLayout.Controls.Add($diagnosisReportedBox, 2, 1)
$diagnosisFoundBox = New-Object Windows.Forms.TextBox
$diagnosisFoundBox.Multiline = $true
$diagnosisFoundBox.Dock = [Windows.Forms.DockStyle]::Fill
$diagnosisInputLayout.Controls.Add($diagnosisFoundBox, 3, 1)
$diagnosisLoadButton = New-Object Windows.Forms.Button
$diagnosisLoadButton.Text = "CARREGAR`nSÉRIE"
$diagnosisLoadButton.Dock = [Windows.Forms.DockStyle]::Fill
$diagnosisLoadButton.Tag = "Secondary"
$diagnosisInputLayout.Controls.Add($diagnosisLoadButton, 4, 1)
$diagnosisRunButton = New-Object Windows.Forms.Button
$diagnosisRunButton.Text = "ANALISAR"
$diagnosisRunButton.Dock = [Windows.Forms.DockStyle]::Fill
$diagnosisRunButton.Tag = "Primary"
$diagnosisInputLayout.Controls.Add($diagnosisRunButton, 5, 1)

$diagnosisResultLabel = New-Object Windows.Forms.Label
$diagnosisResultLabel.Text = "Preencha a versão e o defeito para consultar o histórico."
$diagnosisResultLabel.Dock = [Windows.Forms.DockStyle]::Fill
$diagnosisResultLabel.Margin = [Windows.Forms.Padding]::new(2, 5, 2, 5)
$diagnosisResultLabel.Padding = [Windows.Forms.Padding]::new(10, 4, 10, 4)
$diagnosisResultLabel.TextAlign = [Drawing.ContentAlignment]::MiddleLeft
$diagnosisResultLabel.Add_SizeChanged({ Set-MaintenanceRoundedRegion $this 8 })
$diagnosisRoot.Controls.Add($diagnosisResultLabel, 0, 2)
$diagnosisGrid = New-Grid
foreach ($column in @(
    @("Tipo", "Tipo", 70, "Fixed", 60), @("Reparo", "Reparo observado", 100, "Fill", 180), @("Defeito", "Defeito associado", 160, "Fixed", 130),
    @("Casos", "Casos", 55, "Fixed", 50), @("Nivel", "Nível de evidência", 120, "Fixed", 105), @("Base", "Base da relação", 100, "Fill", 190)
)) { Add-GridColumn $diagnosisGrid $column[0] $column[1] $column[2] $column[3] $column[4] }
$diagnosisRoot.Controls.Add($diagnosisGrid, 0, 3)

$schematicsTab = New-Object Windows.Forms.TabPage
$schematicsTab.Text = "Esquemáticos"
$schematicsTab.ToolTipText = "Referências e esquemáticos"
$mainTabs.TabPages.Add($schematicsTab)
$schemaRoot = New-Object Windows.Forms.TableLayoutPanel
$schemaRoot.Dock = [Windows.Forms.DockStyle]::Fill
$schemaRoot.Padding = [Windows.Forms.Padding]::new(16)
$schemaRoot.RowCount = 4
[void]$schemaRoot.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 76)))
[void]$schemaRoot.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 70)))
[void]$schemaRoot.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 100)))
[void]$schemaRoot.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 210)))
$schematicsTab.Controls.Add($schemaRoot)
$schemaNotice = New-Object Windows.Forms.Label
$schemaNotice.Text = "Cadastre o arquivo de cada versão e o índice de designadores (por exemplo, C40). A busca mostra a página e a área cadastradas; o esquemático original não é alterado."
$schemaNotice.Dock = [Windows.Forms.DockStyle]::Fill
$schemaNotice.Margin = [Windows.Forms.Padding]::new(2, 2, 2, 8)
$schemaNotice.Padding = [Windows.Forms.Padding]::new(14, 10, 14, 10)
$schemaNotice.TextAlign = [Drawing.ContentAlignment]::MiddleLeft
$schemaNotice.Font = [Drawing.Font]::new("Segoe UI", 8.8)
$schemaNotice.Add_SizeChanged({ Set-MaintenanceRoundedRegion $this 10 })
$schemaRoot.Controls.Add($schemaNotice, 0, 0)

$schemaSearchLayout = New-Object Windows.Forms.TableLayoutPanel
$schemaSearchLayout.Dock = [Windows.Forms.DockStyle]::Fill
$schemaSearchLayout.ColumnCount = 4
[void]$schemaSearchLayout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Absolute, 180)))
[void]$schemaSearchLayout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 100)))
[void]$schemaSearchLayout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Absolute, 190)))
[void]$schemaSearchLayout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Absolute, 150)))
$schemaRoot.Controls.Add($schemaSearchLayout, 0, 1)
$schemaSearchVersionCombo = New-Object Windows.Forms.ComboBox
$schemaSearchVersionCombo.Dock = [Windows.Forms.DockStyle]::Fill
$schemaSearchVersionCombo.DropDownStyle = [Windows.Forms.ComboBoxStyle]::DropDownList
$schemaSearchVersionCombo.Margin = [Windows.Forms.Padding]::new(0, 14, 8, 14)
Add-ComboItems $schemaSearchVersionCombo (@("Todas") + @(Get-CB5VersionCatalog))
$schemaSearchLayout.Controls.Add($schemaSearchVersionCombo, 0, 0)
$schemaSearchBox = New-Object Windows.Forms.TextBox
$schemaSearchBox.Dock = [Windows.Forms.DockStyle]::Fill
$schemaSearchBox.Margin = [Windows.Forms.Padding]::new(8, 14, 8, 14)
$schemaSearchLayout.Controls.Add($schemaSearchBox, 1, 0)
$schemaOpenButton = New-Object Windows.Forms.Button
$schemaOpenButton.Text = "ABRIR SELECIONADO"
$schemaOpenButton.Dock = [Windows.Forms.DockStyle]::Fill
$schemaOpenButton.Margin = [Windows.Forms.Padding]::new(8, 10, 8, 10)
$schemaSearchLayout.Controls.Add($schemaOpenButton, 2, 0)
$schemaRemoveButton = New-Object Windows.Forms.Button
$schemaRemoveButton.Text = "REMOVER ÍNDICE"
$schemaRemoveButton.Dock = [Windows.Forms.DockStyle]::Fill
$schemaRemoveButton.Margin = [Windows.Forms.Padding]::new(8, 10, 0, 10)
$schemaRemoveButton.Tag = "Danger"
$schemaSearchLayout.Controls.Add($schemaRemoveButton, 3, 0)

$schemaGrid = New-Grid
foreach ($column in @(
    @("Versao", "Versão", 100, "Fixed", 85), @("Designador", "Designador", 110, "Fixed", 95), @("Arquivo", "Arquivo", 220, "Fixed", 170),
    @("Pagina", "Página", 75, "Fixed", 65), @("Area", "Área", 120, "Fixed", 95), @("Notas", "Observações", 100, "Fill", 200)
)) { Add-GridColumn $schemaGrid $column[0] $column[1] $column[2] $column[3] $column[4] }
$schemaRoot.Controls.Add($schemaGrid, 0, 2)

$schemaEntryGroup = New-Object Windows.Forms.GroupBox
$schemaEntryGroup.Text = "Cadastrar uma referência no índice"
$schemaEntryGroup.Dock = [Windows.Forms.DockStyle]::Fill
$schemaEntryGroup.Padding = [Windows.Forms.Padding]::new(10, 22, 10, 10)
$schemaRoot.Controls.Add($schemaEntryGroup, 0, 3)
$schemaEntryLayout = New-Object Windows.Forms.TableLayoutPanel
$schemaEntryLayout.Dock = [Windows.Forms.DockStyle]::Fill
$schemaEntryLayout.ColumnCount = 6
$schemaEntryLayout.RowCount = 4
[void]$schemaEntryLayout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Absolute, 120)))
[void]$schemaEntryLayout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Absolute, 150)))
[void]$schemaEntryLayout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 100)))
[void]$schemaEntryLayout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Absolute, 90)))
[void]$schemaEntryLayout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Absolute, 150)))
[void]$schemaEntryLayout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Absolute, 170)))
[void]$schemaEntryLayout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 27)))
[void]$schemaEntryLayout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 38)))
[void]$schemaEntryLayout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 27)))
[void]$schemaEntryLayout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 100)))
$schemaEntryGroup.Controls.Add($schemaEntryLayout)
foreach ($item in @(@("Versão", 0), @("Designador", 1), @("Arquivo do esquemático", 2), @("Página", 3), @("Área", 4))) {
    $label = New-Object Windows.Forms.Label
    $label.Text = $item[0]
    $label.Dock = [Windows.Forms.DockStyle]::Fill
    $label.TextAlign = [Drawing.ContentAlignment]::BottomLeft
    $schemaEntryLayout.Controls.Add($label, $item[1], 0)
}
$schemaEntryVersionCombo = New-Object Windows.Forms.ComboBox
$schemaEntryVersionCombo.Dock = [Windows.Forms.DockStyle]::Fill
$schemaEntryVersionCombo.DropDownStyle = [Windows.Forms.ComboBoxStyle]::DropDownList
Add-ComboItems $schemaEntryVersionCombo @(Get-CB5VersionCatalog)
$schemaEntryLayout.Controls.Add($schemaEntryVersionCombo, 0, 1)
$schemaDesignatorBox = New-Object Windows.Forms.TextBox
$schemaDesignatorBox.Dock = [Windows.Forms.DockStyle]::Fill
$schemaEntryLayout.Controls.Add($schemaDesignatorBox, 1, 1)
$schemaFileBox = New-Object Windows.Forms.TextBox
$schemaFileBox.Dock = [Windows.Forms.DockStyle]::Fill
$schemaEntryLayout.Controls.Add($schemaFileBox, 2, 1)
$schemaPageBox = New-Object Windows.Forms.TextBox
$schemaPageBox.Dock = [Windows.Forms.DockStyle]::Fill
$schemaEntryLayout.Controls.Add($schemaPageBox, 3, 1)
$schemaAreaBox = New-Object Windows.Forms.TextBox
$schemaAreaBox.Dock = [Windows.Forms.DockStyle]::Fill
$schemaEntryLayout.Controls.Add($schemaAreaBox, 4, 1)
$schemaBrowseButton = New-Object Windows.Forms.Button
$schemaBrowseButton.Text = "SELECIONAR ARQUIVO"
$schemaBrowseButton.Dock = [Windows.Forms.DockStyle]::Fill
$schemaBrowseButton.Tag = "Secondary"
$schemaEntryLayout.Controls.Add($schemaBrowseButton, 5, 1)
$schemaNotesLabel = New-Object Windows.Forms.Label
$schemaNotesLabel.Text = "Observações sobre o circuito ou a localização"
$schemaNotesLabel.Dock = [Windows.Forms.DockStyle]::Fill
$schemaNotesLabel.TextAlign = [Drawing.ContentAlignment]::BottomLeft
$schemaEntryLayout.Controls.Add($schemaNotesLabel, 0, 2)
$schemaEntryLayout.SetColumnSpan($schemaNotesLabel, 5)
$schemaNotesBox = New-Object Windows.Forms.TextBox
$schemaNotesBox.Multiline = $true
$schemaNotesBox.Dock = [Windows.Forms.DockStyle]::Fill
$schemaEntryLayout.Controls.Add($schemaNotesBox, 0, 3)
$schemaEntryLayout.SetColumnSpan($schemaNotesBox, 5)
$schemaAddButton = New-Object Windows.Forms.Button
$schemaAddButton.Text = "CADASTRAR REFERÊNCIA"
$schemaAddButton.Dock = [Windows.Forms.DockStyle]::Fill
$schemaAddButton.Margin = [Windows.Forms.Padding]::new(8, 8, 0, 0)
$schemaAddButton.Tag = "Primary"
$schemaEntryLayout.Controls.Add($schemaAddButton, 5, 3)

$schemaCountLabel = New-Object Windows.Forms.Label
$schemaCountLabel.Text = "0 referência(s) encontrada(s)"
$schemaCountLabel.Visible = $false

$rulesTab = New-Object Windows.Forms.TabPage
$rulesTab.Text = "Regras e dados"
$rulesTab.ToolTipText = "Regras operacionais e pasta de dados"
$mainTabs.TabPages.Add($rulesTab)
$rulesRoot = New-Object Windows.Forms.TableLayoutPanel
$rulesRoot.Dock = [Windows.Forms.DockStyle]::Fill
$rulesRoot.Padding = [Windows.Forms.Padding]::new(16)
$rulesRoot.ColumnCount = 2
$rulesRoot.RowCount = 2
[void]$rulesRoot.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 43)))
[void]$rulesRoot.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 57)))
[void]$rulesRoot.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 100)))
[void]$rulesRoot.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 92)))
$rulesTab.Controls.Add($rulesRoot)

$codeRulesGroup = New-Object Windows.Forms.GroupBox
$codeRulesGroup.Text = "Regras operacionais confirmadas"
$codeRulesGroup.Dock = [Windows.Forms.DockStyle]::Fill
$codeRulesGroup.Padding = [Windows.Forms.Padding]::new(10, 22, 10, 10)
$rulesRoot.Controls.Add($codeRulesGroup, 0, 0)
$codeRulesText = New-Object Windows.Forms.TextBox
$codeRulesText.Dock = [Windows.Forms.DockStyle]::Fill
$codeRulesText.Multiline = $true
$codeRulesText.ReadOnly = $true
$codeRulesText.ScrollBars = [Windows.Forms.ScrollBars]::Vertical
$codeRulesText.Text = @"
SÉRIE
• Obrigatória e sempre com exatamente 8 dígitos numéricos.

CÓDIGOS
• 800, 850 e 100 nunca são misturados.
• 800 não tem restrição ao período do mês.
• 850 e 100 só são trabalhados do dia 1 ao dia 20.
• Garantia não aparece porque este setor não faz manutenção dessas peças.

RESULTADO FINAL
• Aprovado: conclui esta etapa e segue automaticamente ao próximo setor.
• PT: encerra a passagem como PT.
• Não é necessário registrar testes ou Ping na Central.

HISTÓRICO E RETORNOS
• Cada retorno cria uma nova passagem da mesma série.
• Uma passagem concluída pode ser corrigida sem apagar o valor anterior.
• Toda correção registra os campos alterados nos eventos da passagem.
• Cada salvamento gera um evento dentro da passagem aberta.

TROCAS EXTERNAS
• Modem 4G, Bluetooth e LoRa são trocados pelo setor responsável, não por este setor.
• A Central mostra apenas um aviso automático; não exige encaminhamento ou confirmação do modem nesta tela.

DIAGNÓSTICO
• Sugestões são hipóteses calculadas somente com o histórico real.
• Hipótese nunca aparece como defeito confirmado.
"@
$codeRulesGroup.Controls.Add($codeRulesText)

$versionRulesGroup = New-Object Windows.Forms.GroupBox
$versionRulesGroup.Text = "Mapa de atualização das versões"
$versionRulesGroup.Dock = [Windows.Forms.DockStyle]::Fill
$versionRulesGroup.Padding = [Windows.Forms.Padding]::new(10, 22, 10, 10)
$rulesRoot.Controls.Add($versionRulesGroup, 1, 0)
$versionRulesGrid = New-Grid
foreach ($column in @(
    @("Origem", "Origem", 90, "Fixed", 80), @("Destino", "Destino", 90, "Fixed", 80), @("Componentes", "Troca externa", 160, "Fixed", 130),
    @("Condicao", "Condição", 100, "Fill", 180), @("Observacao", "Observação", 100, "Fill", 180)
)) { Add-GridColumn $versionRulesGrid $column[0] $column[1] $column[2] $column[3] $column[4] }
foreach ($rule in @(Get-CB5UpdateRules)) {
    $condition = if ($rule.CondicionalAoModem) { "Decisão do outro setor se houver defeito no modem" } else { "Atualização prevista no outro setor" }
    [void]$versionRulesGrid.Rows.Add([string]$rule.Origem, [string]$rule.Destino, [string]$rule.Componentes, $condition, [string]$rule.Observacao)
}
$versionRulesGroup.Controls.Add($versionRulesGrid)

$dataPanel = New-Object Windows.Forms.TableLayoutPanel
$dataPanel.Dock = [Windows.Forms.DockStyle]::Fill
$dataPanel.ColumnCount = 3
[void]$dataPanel.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Absolute, 170)))
[void]$dataPanel.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 100)))
[void]$dataPanel.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Absolute, 180)))
$rulesRoot.Controls.Add($dataPanel, 0, 1)
$rulesRoot.SetColumnSpan($dataPanel, 2)
$dataLabel = New-Object Windows.Forms.Label
$dataLabel.Text = "Base local do histórico:"
$dataLabel.Dock = [Windows.Forms.DockStyle]::Fill
$dataLabel.TextAlign = [Drawing.ContentAlignment]::MiddleLeft
$dataPanel.Controls.Add($dataLabel, 0, 0)
$dataPathBox = New-Object Windows.Forms.TextBox
$dataPathBox.Text = $script:DatabasePath
$dataPathBox.ReadOnly = $true
$dataPathBox.Dock = [Windows.Forms.DockStyle]::Fill
$dataPathBox.Margin = [Windows.Forms.Padding]::new(0, 24, 10, 24)
$dataPanel.Controls.Add($dataPathBox, 1, 0)
$openDataFolderButton = New-Object Windows.Forms.Button
$openDataFolderButton.Text = "ABRIR PASTA DOS DADOS"
$openDataFolderButton.Dock = [Windows.Forms.DockStyle]::Fill
$openDataFolderButton.Margin = [Windows.Forms.Padding]::new(0, 20, 0, 20)
$dataPanel.Controls.Add($openDataFolderButton, 2, 0)

$footerPanel = New-Object Windows.Forms.Panel
$footerPanel.Dock = [Windows.Forms.DockStyle]::Fill
$footerPanel.Padding = [Windows.Forms.Padding]::new(20, 7, 20, 7)
$rootLayout.Controls.Add($footerPanel, 0, 2)
$footerLayout = New-Object Windows.Forms.TableLayoutPanel
$footerLayout.Dock = [Windows.Forms.DockStyle]::Fill
$footerLayout.ColumnCount = 3
[void]$footerLayout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 100)))
[void]$footerLayout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Absolute, 132)))
[void]$footerLayout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::AutoSize)))
$footerPanel.Controls.Add($footerLayout)
$statusLabel = New-Object Windows.Forms.Label
$statusLabel.Text = "Pronto. Base carregada sem registros de exemplo."
$statusLabel.Dock = [Windows.Forms.DockStyle]::Fill
$statusLabel.TextAlign = [Drawing.ContentAlignment]::MiddleLeft
$statusLabel.AutoEllipsis = $true
$footerLayout.Controls.Add($statusLabel, 0, 0)
$footerHomeButton = New-Object Windows.Forms.Button
$footerHomeButton.Text = "← VISÃO GERAL"
$footerHomeButton.Dock = [Windows.Forms.DockStyle]::Fill
$footerHomeButton.Margin = [Windows.Forms.Padding]::new(4, 0, 4, 0)
$footerHomeButton.Font = [Drawing.Font]::new("Segoe UI Semibold", 8.0)
$footerHomeButton.Tag = "Secondary"
$footerHomeButton.Visible = $false
$footerLayout.Controls.Add($footerHomeButton, 1, 0)
$footerVersion = New-Object Windows.Forms.Label
$footerVersion.Text = "Manutenção CB5 v$($script:AppVersion)"
$footerVersion.AutoSize = $true
$footerVersion.Anchor = [Windows.Forms.AnchorStyles]::Right
$footerVersion.TextAlign = [Drawing.ContentAlignment]::MiddleRight
$footerLayout.Controls.Add($footerVersion, 2, 0)


$script:MaintenanceResponsiveBusy = $false
$script:MaintenanceResponsiveProfile = ""
$script:DashboardSummaryColumns = 0

function Get-MaintenanceLogicalViewport {
    $dpi = 96
    try { if ($form.DeviceDpi -gt 0) { $dpi = [int]$form.DeviceDpi } } catch {}
    $w = [Math]::Max(1, [int]$form.ClientSize.Width)
    $h = [Math]::Max(1, [int]$form.ClientSize.Height)

    # Em modo hospedado as coordenadas já são as coordenadas finais do controle
    # dentro da Central; dividir novamente pelo DPI fazia o módulo acreditar que
    # tinha menos espaço e, pior, mascarava o fato de o Form antigo estar maior
    # do que seu painel pai.
    $logicalW = if ($script:IsInProcessHosted) { $w } else { [int][Math]::Round($w * 96.0 / $dpi) }
    $logicalH = if ($script:IsInProcessHosted) { $h } else { [int][Math]::Round($h * 96.0 / $dpi) }

    [pscustomobject]@{
        Dpi = $dpi
        Scale = [Math]::Round($dpi / 96.0, 2)
        Width = $w
        Height = $h
        LogicalWidth = $logicalW
        LogicalHeight = $logicalH
    }
}

function Set-DashboardSummaryLayout {
    param([ValidateSet(1,2,4)][int]$Columns)
    if ($script:DashboardSummaryColumns -eq $Columns) { return }
    $script:DashboardSummaryColumns = $Columns
    try {
        $cardsLayout.SuspendLayout()
        $cardsLayout.Controls.Clear()
        $cardsLayout.ColumnStyles.Clear()
        $cardsLayout.RowStyles.Clear()
        $cardsLayout.ColumnCount = $Columns
        $rows = [int][Math]::Ceiling(4.0 / $Columns)
        $cardsLayout.RowCount = $rows
        for ($i=0; $i -lt $Columns; $i++) {
            [void]$cardsLayout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, (100.0 / $Columns))))
        }
        for ($i=0; $i -lt $rows; $i++) {
            [void]$cardsLayout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, (100.0 / $rows))))
        }
        $cards = @($cardSeries,$cardPassages,$cardOpen,$cardReturns)
        for ($i=0; $i -lt $cards.Count; $i++) {
            $col = $i % $Columns
            $row = [int][Math]::Floor($i / $Columns)
            $cardsLayout.Controls.Add($cards[$i], $col, $row)
        }
    }
    finally {
        try { $cardsLayout.ResumeLayout($true) } catch {}
    }
}

function Update-MaintenanceResponsiveLayout {
    if (-not $script:IsInProcessHosted -or $script:MaintenanceResponsiveBusy -or $null -eq $form) { return }
    $script:MaintenanceResponsiveBusy = $true
    try {
        $m = Get-MaintenanceLogicalViewport

        # Perfis baseados na área REAL do módulo já encaixado na Central.
        # Em notebook / 125% / 150% preferimos densidade menor e quebra de layout,
        # em vez de deixar controles escaparem para fora da área visível.
        $profile = if ($m.LogicalWidth -lt 980 -or $m.LogicalHeight -lt 620) { "Tight" } elseif ($m.LogicalWidth -lt 1320 -or $m.LogicalHeight -lt 780) { "Compact" } else { "Comfortable" }
        $changed = ($profile -ne $script:MaintenanceResponsiveProfile)
        $script:MaintenanceResponsiveProfile = $profile

        switch ($profile) {
            "Tight" {
                $baseFont = 7.75; $titleFont = 11.3; $serialFont = 9.0
                $passagePadding = 4; $rightWidth = 300
                $modeH = 30; $identityH = 124; $defectsH = 122; $maintH = 90; $finalH = 82; $notesH = 74; $gap = 4
                $side = @(48, 94, 30, 30, 84)
                $groupPadTop = 16; $gridHeader = 23; $gridRow = 21
                $dashIntro = 42
            }
            "Compact" {
                $baseFont = 8.15; $titleFont = 12.0; $serialFont = 9.5
                $passagePadding = 6; $rightWidth = 322
                $modeH = 32; $identityH = 132; $defectsH = 132; $maintH = 98; $finalH = 88; $notesH = 78; $gap = 5
                $side = @(52, 102, 34, 34, 94)
                $groupPadTop = 17; $gridHeader = 24; $gridRow = 22
                $dashIntro = 46
            }
            default {
                $baseFont = 8.8; $titleFont = 13.0; $serialFont = 10.3
                $passagePadding = 8; $rightWidth = 350
                $modeH = 35; $identityH = 142; $defectsH = 150; $maintH = 112; $finalH = 96; $notesH = 86; $gap = 6
                $side = @(58, 112, 38, 38, 104)
                $groupPadTop = 19; $gridHeader = 26; $gridRow = 23
                $dashIntro = 50
            }
        }

        if ($changed) {
            $form.Font = [Drawing.Font]::new("Segoe UI", $baseFont)
            $formModeLabel.Font = [Drawing.Font]::new("Segoe UI Semibold", $titleFont)
            $serialBox.Font = [Drawing.Font]::new("Consolas", $serialFont)
            $recordBanner.Font = [Drawing.Font]::new("Segoe UI Semibold", [Math]::Max(7.2, $baseFont - 0.1))
            $updateInfo.Font = [Drawing.Font]::new("Segoe UI Semibold", [Math]::Max(7.2, $baseFont - 0.1))
            $codeRuleLabel.Font = [Drawing.Font]::new("Segoe UI", [Math]::Max(7.2, $baseFont - 0.15))
            $seriesHistoryStateLabel.Font = [Drawing.Font]::new("Segoe UI", [Math]::Max(7.2, $baseFont - 0.15))
        }

        # Passagem: as linhas internas também precisam caber dentro das alturas externas.
        if ($profile -eq "Tight") {
            $identityLayout.RowStyles[0].Height = 18
            $identityLayout.RowStyles[1].Height = 28
            $identityLayout.RowStyles[2].Height = 18
            $identityLayout.RowStyles[3].Height = 28
            $finalResultLayout.RowStyles[0].Height = 18
        }
        elseif ($profile -eq "Compact") {
            $identityLayout.RowStyles[0].Height = 20
            $identityLayout.RowStyles[1].Height = 30
            $identityLayout.RowStyles[2].Height = 20
            $identityLayout.RowStyles[3].Height = 30
            $finalResultLayout.RowStyles[0].Height = 20
        }
        else {
            $identityLayout.RowStyles[0].Height = 22
            $identityLayout.RowStyles[1].Height = 32
            $identityLayout.RowStyles[2].Height = 22
            $identityLayout.RowStyles[3].Height = 32
            $finalResultLayout.RowStyles[0].Height = 22
        }
        $identityGroup.Padding = [Windows.Forms.Padding]::new([Math]::Max(7,$passagePadding + 3), [Math]::Max(17,$groupPadTop), [Math]::Max(7,$passagePadding + 3), [Math]::Max(5,$passagePadding))
        $finalResultGroup.Padding = [Windows.Forms.Padding]::new([Math]::Max(7,$passagePadding + 3), [Math]::Max(17,$groupPadTop), [Math]::Max(7,$passagePadding + 3), [Math]::Max(5,$passagePadding))
        $automaticFlowLabel.Font = [Drawing.Font]::new("Segoe UI", [Math]::Max(7.2, $baseFont - 0.1))
        $finalResultHelp.Font = [Drawing.Font]::new("Segoe UI", [Math]::Max(7.2, $baseFont - 0.05))

        # Telas técnicas também acompanham o perfil da área real hospedada.
        $technicalPadding = if ($profile -eq "Tight") { 7 } elseif ($profile -eq "Compact") { 10 } else { 14 }
        $historyRoot.Padding = [Windows.Forms.Padding]::new($technicalPadding)
        $statisticsRoot.Padding = [Windows.Forms.Padding]::new($technicalPadding)
        $diagnosisRoot.Padding = [Windows.Forms.Padding]::new($technicalPadding)
        $schemaRoot.Padding = [Windows.Forms.Padding]::new($technicalPadding)
        $rulesRoot.Padding = [Windows.Forms.Padding]::new($technicalPadding)
        $statisticsRoot.RowStyles[0].Height = if ($profile -eq "Tight") { 50 } elseif ($profile -eq "Compact") { 58 } else { 66 }
        $diagnosisRoot.RowStyles[0].Height = if ($profile -eq "Tight") { 64 } elseif ($profile -eq "Compact") { 72 } else { 82 }
        $diagnosisRoot.RowStyles[1].Height = if ($profile -eq "Tight") { 128 } elseif ($profile -eq "Compact") { 145 } else { 165 }
        $diagnosisRoot.RowStyles[2].Height = if ($profile -eq "Tight") { 42 } elseif ($profile -eq "Compact") { 46 } else { 50 }
        $schemaRoot.RowStyles[0].Height = if ($profile -eq "Tight") { 58 } elseif ($profile -eq "Compact") { 66 } else { 76 }
        $schemaRoot.RowStyles[1].Height = if ($profile -eq "Tight") { 52 } elseif ($profile -eq "Compact") { 60 } else { 70 }
        $schemaRoot.RowStyles[3].Height = if ($profile -eq "Tight") { 168 } elseif ($profile -eq "Compact") { 188 } else { 210 }
        $rulesRoot.RowStyles[1].Height = if ($profile -eq "Tight") { 70 } elseif ($profile -eq "Compact") { 80 } else { 92 }
        $statisticsTitle.Font = [Drawing.Font]::new("Segoe UI Semibold", $(if ($profile -eq "Tight") { 11.5 } elseif ($profile -eq "Compact") { 12.5 } else { 14.0 }))
        $statisticsSubtitle.Font = [Drawing.Font]::new("Segoe UI", $(if ($profile -eq "Tight") { 7.4 } elseif ($profile -eq "Compact") { 7.9 } else { 8.5 }))
        $statsTabs.ItemSize = [Drawing.Size]::new($(if ($profile -eq "Tight") { 108 } elseif ($profile -eq "Compact") { 120 } else { 132 }), $(if ($profile -eq "Tight") { 24 } elseif ($profile -eq "Compact") { 26 } else { 28 }))

        # Dashboard: 4 cards só quando realmente há largura. Nos tamanhos mais comuns
        # da Central integrada, vira 2x2 para evitar cartão truncado.
        $summaryColumns = if ($m.LogicalWidth -lt 720) { 1 } elseif ($m.LogicalWidth -lt 1380) { 2 } else { 4 }
        Set-DashboardSummaryLayout -Columns $summaryColumns
        $summaryRows = [int][Math]::Ceiling(4.0 / $summaryColumns)
        $dashboardCardsH = if ($summaryColumns -eq 4) {
            if ($profile -eq "Tight") { 90 } elseif ($profile -eq "Compact") { 98 } else { 108 }
        } elseif ($summaryColumns -eq 2) {
            if ($profile -eq "Tight") { 148 } elseif ($profile -eq "Compact") { 160 } else { 174 }
        } else {
            if ($profile -eq "Tight") { 260 } elseif ($profile -eq "Compact") { 284 } else { 304 }
        }
        $dashboardRoot.Padding = [Windows.Forms.Padding]::new([Math]::Max(5,$passagePadding))
        $dashboardRoot.RowStyles[0].Height = $dashIntro
        $dashboardRoot.RowStyles[1].Height = $dashboardCardsH
        $dashboardRoot.RowStyles[2].Height = if ($profile -eq "Tight") { 38 } elseif ($profile -eq "Compact") { 42 } else { 46 }
        $dashboardRoot.AutoScroll = ($summaryColumns -eq 1)
        $dashboardActionWidthNow = if ($profile -eq "Tight") { 126 } elseif ($profile -eq "Compact") { 142 } else { 158 }
        $dashboardIntro.ColumnStyles[1].Width = $dashboardActionWidthNow
        $dashboardTitle.Font = [Drawing.Font]::new("Segoe UI Semibold", $(if ($profile -eq "Tight") { 11.4 } elseif ($profile -eq "Compact") { 12.5 } else { 13.8 }))
        if ($null -ne $dashboardSubtitle) { $dashboardSubtitle.Font = [Drawing.Font]::new("Segoe UI", $(if ($profile -eq "Tight") { 7.6 } elseif ($profile -eq "Compact") { 8.1 } else { 8.6 })) }
        foreach ($v in @($seriesValue,$passagesValue,$openValue,$returnsValue)) {
            $v.Font = [Drawing.Font]::new("Segoe UI Semibold", $(if ($profile -eq "Tight") { 17 } elseif ($profile -eq "Compact") { 19 } else { 21 }))
        }
        foreach ($card in @($cardSeries,$cardPassages,$cardOpen,$cardReturns)) {
            if ($null -ne $card) {
                $card.Margin = [Windows.Forms.Padding]::new(4)
                $card.Padding = [Windows.Forms.Padding]::new(10,6,10,5)
            }
        }

        # Nova passagem: coluna lateral recebe largura mínima previsível e a coluna
        # principal usa todo o restante. Isso evita campos estreitos demais em DPI alto.
        $passageRoot.Padding = [Windows.Forms.Padding]::new($passagePadding)
        $passageRoot.ColumnStyles[0].SizeType = [Windows.Forms.SizeType]::Percent
        $passageRoot.ColumnStyles[0].Width = 100
        $passageRoot.ColumnStyles[1].SizeType = [Windows.Forms.SizeType]::Absolute
        $passageRoot.ColumnStyles[1].Width = [Math]::Min($rightWidth, [Math]::Max(250, [int]($form.ClientSize.Width * 0.38)))
        $passageSide.Padding = [Windows.Forms.Padding]::new([Math]::Max(3,$passagePadding),0,0,0)
        $passageScroll.Padding = [Windows.Forms.Padding]::new(0,0,[Math]::Max(4,$passagePadding),0)

        $modePanel.Height = $modeH
        $identityGroup.Height = $identityH
        $defectsGroup.Height = $defectsH
        $maintenanceGroup.Height = $maintH
        $finalResultGroup.Height = $finalH
        $notesGroup.Height = $notesH
        foreach ($g in @($identityGroup,$defectsGroup,$maintenanceGroup,$finalResultGroup,$notesGroup)) {
            $g.Margin = [Windows.Forms.Padding]::new(0,0,0,$gap)
            $g.Padding = [Windows.Forms.Padding]::new(7,$groupPadTop,7,5)
        }

        $identityLayout.RowStyles[0].Height = if ($profile -eq "Tight") { 16 } elseif ($profile -eq "Compact") { 18 } else { 20 }
        $identityLayout.RowStyles[1].Height = if ($profile -eq "Tight") { 25 } elseif ($profile -eq "Compact") { 27 } else { 30 }
        $identityLayout.RowStyles[2].Height = if ($profile -eq "Tight") { 16 } elseif ($profile -eq "Compact") { 18 } else { 20 }
        $identityLayout.RowStyles[3].Height = if ($profile -eq "Tight") { 27 } elseif ($profile -eq "Compact") { 29 } else { 32 }
        $defectsLayout.RowStyles[0].Height = if ($profile -eq "Tight") { 19 } elseif ($profile -eq "Compact") { 21 } else { 24 }
        $maintenanceLayout.RowStyles[0].Height = if ($profile -eq "Tight") { 18 } elseif ($profile -eq "Compact") { 20 } else { 23 }
        $finalResultLayout.RowStyles[0].Height = if ($profile -eq "Tight") { 18 } elseif ($profile -eq "Compact") { 20 } else { 23 }

        $passageSide.RowStyles[0].Height = $side[0]
        $passageSide.RowStyles[1].Height = $side[1]
        $passageSide.RowStyles[2].Height = $side[2]
        $passageSide.RowStyles[4].Height = $side[3]
        $passageSide.RowStyles[5].Height = $side[4]
        $seriesHistoryLayout.RowStyles[0].Height = if ($profile -eq "Tight") { 32 } elseif ($profile -eq "Compact") { 36 } else { 40 }

        foreach ($grid in @($recentGrid,$seriesHistoryGrid,$historyGrid,$schemaGrid)) {
            if ($null -ne $grid) {
                try {
                    $grid.ColumnHeadersHeight = $gridHeader
                    $grid.RowTemplate.Height = $gridRow
                    $grid.DefaultCellStyle.Font = [Drawing.Font]::new("Segoe UI", [Math]::Max(7.2,$baseFont - 0.1))
                    $grid.ColumnHeadersDefaultCellStyle.Font = [Drawing.Font]::new("Segoe UI Semibold", [Math]::Max(7.2,$baseFont - 0.1))
                } catch {}
            }
        }

        # Faixa de navegação da Manutenção. Em modo integrado calculamos a
        # largura a partir do espaço REAL do TabControl para manter todas as 7
        # áreas visíveis. Só usamos duas linhas quando nem 86 px por aba cabem.
        if ($script:IsInProcessHosted) {
            $tabCount = [Math]::Max(1, $mainTabs.TabPages.Count)
            $tabsAvailable = [Math]::Max(1, $mainTabs.ClientSize.Width - 8)
            $singleWidth = [int][Math]::Floor($tabsAvailable / $tabCount)
            if ($singleWidth -ge 86) {
                $mainTabs.Multiline = $false
                $tabWidth = [Math]::Min(142, [Math]::Max(86, $singleWidth))
            }
            else {
                $mainTabs.Multiline = $true
                $tabWidth = if ($profile -eq "Tight") { 96 } else { 104 }
            }
            $tabHeight = if ($profile -eq "Tight") { 24 } elseif ($profile -eq "Compact") { 26 } else { 28 }
            $mainTabs.SizeMode = [Windows.Forms.TabSizeMode]::Fixed
            $mainTabs.ItemSize = [Drawing.Size]::new([int]$tabWidth, [int]$tabHeight)
            $mainTabs.Padding = [Drawing.Point]::new(3,2)
        }
        else {
            $mainTabs.Multiline = ($m.LogicalWidth -lt 1320)
            $mainTabs.Padding = if ($profile -eq "Tight") { [Drawing.Point]::new(6,2) } elseif ($profile -eq "Compact") { [Drawing.Point]::new(7,3) } else { [Drawing.Point]::new(9,4) }
        }

# PASSAGE_POLISH_V0115
        # Scroll é fallback, nunca o mecanismo principal de encaixe.
        $passageScroll.AutoScroll = $true
        $passageTab.AutoScroll = $false
        $form.PerformLayout()
    }
    catch {}
    finally { $script:MaintenanceResponsiveBusy = $false }
}

$statsTabs.Add_DrawItem({
    param($sender, $eventArgs)
    if ($null -eq $script:CurrentPalette) { return }
    $page = $sender.TabPages[$eventArgs.Index]
    $selected = ($eventArgs.Index -eq $sender.SelectedIndex)
    $background = if ($selected) { $script:CurrentPalette.Card } else { $script:CurrentPalette.Surface }
    $foreground = if ($selected) { $script:CurrentPalette.Text } else { $script:CurrentPalette.Muted }
    $brush = New-Object Drawing.SolidBrush($background)
    $lineBrush = New-Object Drawing.SolidBrush($(if ($selected) { $script:CurrentPalette.Accent } else { $script:CurrentPalette.Border }))
    try {
        $eventArgs.Graphics.FillRectangle($brush, $eventArgs.Bounds)
        $lineHeight = if ($selected) { 3 } else { 1 }
        $lineRect = [Drawing.Rectangle]::new($eventArgs.Bounds.Left + 4, $eventArgs.Bounds.Bottom - $lineHeight, [Math]::Max(1,$eventArgs.Bounds.Width - 8), $lineHeight)
        $eventArgs.Graphics.FillRectangle($lineBrush, $lineRect)
        [Windows.Forms.TextRenderer]::DrawText(
            $eventArgs.Graphics,
            $page.Text,
            $form.Font,
            $eventArgs.Bounds,
            $foreground,
            ([Windows.Forms.TextFormatFlags]::HorizontalCenter -bor [Windows.Forms.TextFormatFlags]::VerticalCenter -bor [Windows.Forms.TextFormatFlags]::EndEllipsis)
        )
    }
    finally { $brush.Dispose(); $lineBrush.Dispose() }
})

$mainTabs.Add_DrawItem({
    param($sender, $eventArgs)
    if ($null -eq $script:CurrentPalette) { return }
    $page = $sender.TabPages[$eventArgs.Index]
    $selected = ($eventArgs.Index -eq $sender.SelectedIndex)
    $background = if ($selected) { $script:CurrentPalette.Card } else { $script:CurrentPalette.Surface }
    $foreground = if ($selected) { $script:CurrentPalette.Text } else { $script:CurrentPalette.Muted }
    $brush = New-Object Drawing.SolidBrush($background)
    $lineBrush = New-Object Drawing.SolidBrush($(if ($selected) { $script:CurrentPalette.Accent } else { $script:CurrentPalette.Border }))
    try {
        $eventArgs.Graphics.FillRectangle($brush, $eventArgs.Bounds)
        $lineHeight = if ($selected) { 3 } else { 1 }
        $lineRect = [Drawing.Rectangle]::new($eventArgs.Bounds.Left + 4, $eventArgs.Bounds.Bottom - $lineHeight, [Math]::Max(1,$eventArgs.Bounds.Width - 8), $lineHeight)
        $eventArgs.Graphics.FillRectangle($lineBrush, $lineRect)
        [Windows.Forms.TextRenderer]::DrawText(
            $eventArgs.Graphics,
            $page.Text,
            $form.Font,
            $eventArgs.Bounds,
            $foreground,
            ([Windows.Forms.TextFormatFlags]::HorizontalCenter -bor [Windows.Forms.TextFormatFlags]::VerticalCenter -bor [Windows.Forms.TextFormatFlags]::EndEllipsis)
        )
    }
    finally { $brush.Dispose(); $lineBrush.Dispose() }
})

$themeCombo.Add_SelectedIndexChanged({ Apply-MaintenanceTheme; Update-MaintenanceResponsiveLayout; Save-MaintenanceSettings })
$dashboardNewButton.Add_Click({ Reset-PassageForm; $mainTabs.SelectedTab = $passageTab })
$dashboardHistoryButton.Add_Click({ $mainTabs.SelectedTab = $historyTab })
$dashboardStatsButton.Add_Click({ $mainTabs.SelectedTab = $statisticsTab })
$dashboardDiagnosisButton.Add_Click({ $mainTabs.SelectedTab = $diagnosisTab })
$dashboardSchematicsButton.Add_Click({ $mainTabs.SelectedTab = $schematicsTab })
$dashboardRulesButton.Add_Click({ $mainTabs.SelectedTab = $rulesTab })
$footerHomeButton.Add_Click({ $mainTabs.SelectedTab = $dashboardTab })
$mainTabs.Add_SelectedIndexChanged({
    try {
        if ($script:IsInProcessHosted) {
            $footerHomeButton.Visible = ($mainTabs.SelectedTab -ne $dashboardTab)
        }
    } catch {}
})
$recentGrid.Add_CellDoubleClick({ Show-PassageDetails (Get-SelectedRecordFromGrid $recentGrid) })
$serialBox.Add_KeyPress({
    param($sender, $eventArgs)
    if (-not [char]::IsControl($eventArgs.KeyChar) -and -not [char]::IsDigit($eventArgs.KeyChar)) {
        $eventArgs.Handled = $true
    }
})
$serialBox.Add_TextChanged({
    if ($script:IsLoadingForm) { return }
    $cleanSeries = [regex]::Replace($serialBox.Text, '[^0-9]', '')
    if ($cleanSeries.Length -gt 8) { $cleanSeries = $cleanSeries.Substring(0, 8) }
    if ($serialBox.Text -ne $cleanSeries) {
        $cursorPosition = [Math]::Min($serialBox.SelectionStart, $cleanSeries.Length)
        $script:IsLoadingForm = $true
        try {
            $serialBox.Text = $cleanSeries
            $serialBox.SelectionStart = $cursorPosition
        }
        finally { $script:IsLoadingForm = $false }
    }
    Update-ReturnBanner
    Refresh-CurrentSeriesHistory
})
$codeCombo.Add_SelectedIndexChanged({ Update-CodeRuleUI })
$inputVersionCombo.Add_SelectedIndexChanged({ Update-VersionRuleUI })
$finalResultCombo.Add_SelectedIndexChanged({ Update-FinalResultUI })
$seriesHistoryGrid.Add_CellDoubleClick({ Show-PassageDetails (Get-SelectedRecordFromGrid $seriesHistoryGrid) })
$seriesHistoryGrid.Add_SelectionChanged({
    $seriesHistoryDetailsButton.Enabled = ($null -ne (Get-SelectedRecordFromGrid $seriesHistoryGrid))
})
$seriesHistoryDetailsButton.Add_Click({ Show-PassageDetails (Get-SelectedRecordFromGrid $seriesHistoryGrid) })
$seriesHistoryFullButton.Add_Click({ Open-CurrentSeriesHistory })
$newPassageButton.Add_Click({ Reset-PassageForm })
$savePassageButton.Add_Click({ Save-CurrentPassage -Complete $false })
$completePassageButton.Add_Click({ Save-CurrentPassage -Complete $true })
$historySerialBox.Add_TextChanged({ Refresh-HistoryGrid })
$historyCodeCombo.Add_SelectedIndexChanged({ if (-not $script:IsLoadingForm) { Refresh-HistoryGrid } })
$historyStatusCombo.Add_SelectedIndexChanged({ if (-not $script:IsLoadingForm) { Refresh-HistoryGrid } })
$historyVersionCombo.Add_SelectedIndexChanged({ if (-not $script:IsLoadingForm) { Refresh-HistoryGrid } })
$historyClearButton.Add_Click({
    $script:IsLoadingForm = $true
    try {
        $historySerialBox.Clear()
        $historyCodeCombo.SelectedIndex = 0
        $historyStatusCombo.SelectedIndex = 0
        $historyVersionCombo.SelectedIndex = 0
    }
    finally { $script:IsLoadingForm = $false }
    Refresh-HistoryGrid
})
$historyGrid.Add_CellDoubleClick({ Show-PassageDetails (Get-SelectedRecordFromGrid $historyGrid) })
$viewHistoryButton.Add_Click({ Show-PassageDetails (Get-SelectedRecordFromGrid $historyGrid) })
$editHistoryButton.Add_Click({ Load-PassageIntoForm (Get-SelectedRecordFromGrid $historyGrid) })
$returnHistoryButton.Add_Click({ Start-ReturnFromRecord (Get-SelectedRecordFromGrid $historyGrid) })
$exportHistoryButton.Add_Click({ Export-FilteredHistory })
$diagnosisLoadButton.Add_Click({ Load-SeriesForDiagnosis })
$diagnosisRunButton.Add_Click({ Run-FullDiagnosis })
$schemaSearchBox.Add_TextChanged({ Refresh-SchematicGrid })
$schemaSearchVersionCombo.Add_SelectedIndexChanged({ if (-not $script:IsLoadingForm) { Refresh-SchematicGrid } })
$schemaGrid.Add_CellDoubleClick({ Open-SelectedSchematic })
$schemaOpenButton.Add_Click({ Open-SelectedSchematic })
$schemaRemoveButton.Add_Click({ Remove-SelectedSchematic })
$schemaBrowseButton.Add_Click({
    $dialog = New-Object Windows.Forms.OpenFileDialog
    $dialog.Title = "Selecionar esquemático"
    $dialog.Filter = "PDF e imagens (*.pdf;*.png;*.jpg;*.jpeg)|*.pdf;*.png;*.jpg;*.jpeg|Todos os arquivos (*.*)|*.*"
    if ($dialog.ShowDialog($form) -eq [Windows.Forms.DialogResult]::OK) { $schemaFileBox.Text = $dialog.FileName }
    $dialog.Dispose()
})
$schemaAddButton.Add_Click({ Add-SchematicFromForm })
# TECH_PAGES_V0114
$openDataFolderButton.Add_Click({ Start-Process -FilePath "explorer.exe" -ArgumentList ('"' + $script:DataDirectory + '"') })
if ($script:IsInProcessHosted) {
    $form.Add_HandleCreated({
        Apply-MaintenanceTheme
        Update-MaintenanceResponsiveLayout
    })
}
else {
    $form.Add_FormClosing({ Save-MaintenanceSettings })
    $form.Add_Shown({
        Apply-MaintenanceTheme
        Update-MaintenanceResponsiveLayout
        Reset-PassageForm
        Refresh-AllViews
    })
}

$script:IsLoadingForm = $true
try {
    $historyCodeCombo.SelectedIndex = 0
    $historyStatusCombo.SelectedIndex = 0
    $historyVersionCombo.SelectedIndex = 0
    $schemaSearchVersionCombo.SelectedIndex = 0
    $schemaEntryVersionCombo.SelectedIndex = 0
    $diagnosisVersionCombo.SelectedIndex = 0
}
finally { $script:IsLoadingForm = $false }

Apply-MaintenanceTheme
try { if ($mainTabs.TabPages.Count -gt 0) { $mainTabs.SelectedIndex = 0 } } catch {}
# UI_DEDUP_V0112
if ($script:IsInProcessHosted) {
    # A Central de Trabalho já fornece título, versão e navegação.
    # O módulo é um UserControl de verdade; não existe mais um Form do tamanho
    # do monitor escondido por trás do painel integrado.
    try {
        $headerPanel.Visible = $false
        $rootLayout.RowStyles[0].SizeType = [Windows.Forms.SizeType]::Absolute
        $rootLayout.RowStyles[0].Height = 0
        $rootLayout.RowStyles[2].SizeType = [Windows.Forms.SizeType]::Absolute
        $rootLayout.RowStyles[2].Height = 28
        $footerPanel.Padding = [Windows.Forms.Padding]::new(8, 1, 8, 1)
        $footerVersion.Visible = $false
    } catch {}

    $form.Add_SizeChanged({ Update-MaintenanceResponsiveLayout })
    $form.MinimumSize = [Drawing.Size]::new(1, 1)
    $form.Dock = [Windows.Forms.DockStyle]::Fill

    Apply-MaintenanceTheme
    Reset-PassageForm
    Refresh-AllViews
    Update-MaintenanceResponsiveLayout

    $form.Add_Disposed({
        try { Save-MaintenanceSettings } catch {}
        try { Close-SingleInstanceMutex } catch {}
    })
    $script:HostedControlExport = $form
    $script:HostedFormExport = $null
}
else {
    try {
        [void]$form.ShowDialog()
    }
    finally {
        Save-MaintenanceSettings
        $form.Dispose()
        Close-SingleInstanceMutex
    }
}

# UI_DEDUP_MAINTENANCE_V0113
