from pathlib import Path

ROOT = Path('.')
core_path = ROOT / 'src/generated/Modulos/Controle-NF-Entrada/NFEntrada.Core.ps1'
ui_path = ROOT / 'src/generated/Modulos/Controle-NF-Entrada/Controle NF Entrada.ps1'


def read(path):
    return path.read_text(encoding='utf-8-sig')


def write(path, text):
    path.write_text(text, encoding='utf-8')


def replace_once(text, old, new, label):
    if old not in text:
        raise SystemExit(f'Etapa 3 NF Entrada: trecho não encontrado ({label})')
    return text.replace(old, new, 1)

# Núcleo: backups passam a ter metadados, consulta e restauração transacional.
core = read(core_path)
core = replace_once(core,
'''function New-NFEntradaSafetyBackup {
    param([string]$DataDirectory = (Get-NFEntradaDefaultDataDirectory))
''',
'''function New-NFEntradaSafetyBackup {
    param(
        [string]$DataDirectory = (Get-NFEntradaDefaultDataDirectory),
        [string]$Reason = "Automático"
    )
''', 'assinatura do backup')

core = replace_once(core,
'''    if ($storeExists) { [IO.File]::Copy($storePath, [IO.Path]::Combine($backupDirectory, "nf-entrada.json"), $true) }
    if ($templateExists) { [IO.File]::Copy($templatePath, [IO.Path]::Combine($backupDirectory, "modelo-nf-entrada.xlsx"), $true) }
    return [pscustomobject]@{
        Directory = $backupDirectory
        StoreExisted = $storeExists
        TemplateExisted = $templateExists
    }
}
''',
'''    if ($storeExists) { [IO.File]::Copy($storePath, [IO.Path]::Combine($backupDirectory, "nf-entrada.json"), $true) }
    if ($templateExists) { [IO.File]::Copy($templatePath, [IO.Path]::Combine($backupDirectory, "modelo-nf-entrada.xlsx"), $true) }
    $info = [pscustomobject]@{
        SchemaVersion = 1
        DataHora = [DateTime]::Now.ToString("o")
        Motivo = $Reason
        StoreExisted = $storeExists
        TemplateExisted = $templateExists
    }
    [IO.File]::WriteAllText(
        [IO.Path]::Combine($backupDirectory, "backup-info.json"),
        ($info | ConvertTo-Json -Depth 4),
        ([Text.UTF8Encoding]::new($true))
    )
    return [pscustomobject]@{
        Directory = $backupDirectory
        StoreExisted = $storeExists
        TemplateExisted = $templateExists
        Reason = $Reason
    }
}
''', 'metadados do backup')

anchor = 'function Get-NFEntradaZipEntryText {\n'
helpers = r'''function Get-NFEntradaSafetyBackups {
    param([string]$DataDirectory = (Get-NFEntradaDefaultDataDirectory))
    $backupRoot = Get-NFEntradaBackupsDirectory -DataDirectory $DataDirectory
    if (-not [IO.Directory]::Exists($backupRoot)) { return @() }
    $result = [Collections.Generic.List[object]]::new()
    foreach ($directory in [IO.Directory]::GetDirectories($backupRoot)) {
        $storePath = [IO.Path]::Combine($directory, "nf-entrada.json")
        $templatePath = [IO.Path]::Combine($directory, "modelo-nf-entrada.xlsx")
        $infoPath = [IO.Path]::Combine($directory, "backup-info.json")
        $hasStore = [IO.File]::Exists($storePath)
        $hasTemplate = [IO.File]::Exists($templatePath)
        $validStore = $false
        $recordCount = 0
        if ($hasStore) {
            try {
                $stored = Read-NFEntradaStore -Path $storePath
                $recordCount = @(Get-NFEntradaProductRecords -Store $stored -Product "COMPUTADOR DE BORDO V5").Count + @(Get-NFEntradaProductRecords -Store $stored -Product "TECLADO V5").Count
                $validStore = $true
            }
            catch { $validStore = $false }
        }
        $date = [IO.DirectoryInfo]::new($directory).CreationTime
        $reason = "Automático / legado"
        if ([IO.File]::Exists($infoPath)) {
            try {
                $info = [IO.File]::ReadAllText($infoPath, [Text.Encoding]::UTF8) | ConvertFrom-Json
                $parsed = [DateTime]::MinValue
                if ([DateTime]::TryParse([string]$info.DataHora, [ref]$parsed)) { $date = $parsed }
                if (-not [string]::IsNullOrWhiteSpace([string]$info.Motivo)) { $reason = [string]$info.Motivo }
            }
            catch {}
        }
        else {
            $name = [IO.Path]::GetFileName($directory)
            $parsedName = [DateTime]::MinValue
            if ([DateTime]::TryParseExact($name, "yyyyMMdd-HHmmss-fff", [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::None, [ref]$parsedName)) { $date = $parsedName }
        }
        [void]$result.Add([pscustomobject]@{
            Directory = $directory
            DataHora = $date
            Motivo = $reason
            TemBase = $hasStore
            TemModelo = $hasTemplate
            BaseValida = $validStore
            Registros = $recordCount
            Situacao = if ($hasStore -and $validStore) { "Pronto" } else { "Inválido" }
        })
    }
    return @($result | Sort-Object DataHora -Descending)
}

function Restore-NFEntradaBackupSet {
    param(
        [Parameter(Mandatory = $true)][string]$BackupDirectory,
        [string]$DataDirectory = (Get-NFEntradaDefaultDataDirectory)
    )
    $backupRoot = [IO.Path]::GetFullPath((Get-NFEntradaBackupsDirectory -DataDirectory $DataDirectory)).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
    $selected = [IO.Path]::GetFullPath($BackupDirectory).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
    if (-not $selected.StartsWith($backupRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw "O backup selecionado não pertence ao Controle de NF de Entrada."
    }
    if (-not [IO.Directory]::Exists($selected)) { throw "O backup selecionado não foi encontrado." }
    $backupStore = [IO.Path]::Combine($selected, "nf-entrada.json")
    $backupTemplate = [IO.Path]::Combine($selected, "modelo-nf-entrada.xlsx")
    if (-not [IO.File]::Exists($backupStore)) { throw "O backup não contém a base de NF de Entrada." }
    [void](Read-NFEntradaStore -Path $backupStore)
    if ([IO.File]::Exists($backupTemplate) -and ([IO.FileInfo]::new($backupTemplate)).Length -le 0) { throw "O modelo Excel do backup está vazio." }

    $recovery = New-NFEntradaSafetyBackup -DataDirectory $DataDirectory -Reason "Antes de restaurar backup"
    $storePath = Get-NFEntradaStorePath -DataDirectory $DataDirectory
    $templatePath = Get-NFEntradaTemplatePath -DataDirectory $DataDirectory
    $token = [guid]::NewGuid().ToString("N")
    $tempStore = $storePath + ".restore-" + $token + ".tmp"
    $tempTemplate = $templatePath + ".restore-" + $token + ".tmp"
    try {
        [IO.File]::Copy($backupStore, $tempStore, $true)
        [void](Read-NFEntradaStore -Path $tempStore)
        $restoreTemplate = [IO.File]::Exists($backupTemplate)
        if ($restoreTemplate) { [IO.File]::Copy($backupTemplate, $tempTemplate, $true) }
        [IO.File]::Copy($tempStore, $storePath, $true)
        if ($restoreTemplate) { [IO.File]::Copy($tempTemplate, $templatePath, $true) }
        elseif ([IO.File]::Exists($templatePath)) { [IO.File]::Delete($templatePath) }
        $restored = Read-NFEntradaStore -Path $storePath
        [void](Add-NFEntradaHistoryEvent -Store $restored -Tipo "RestauracaoBackup" -Detalhes ("Backup restaurado: " + [IO.Path]::GetFileName($selected)))
        Write-NFEntradaStore -Store $restored -Path $storePath
        return [pscustomobject]@{
            Store = $restored
            StorePath = $storePath
            TemplatePath = $templatePath
            RecoveryBackupDirectory = if ($null -ne $recovery) { [string]$recovery.Directory } else { "" }
        }
    }
    catch {
        if ($null -ne $recovery) { try { Restore-NFEntradaSafetyBackup -Backup $recovery -DataDirectory $DataDirectory } catch {} }
        throw
    }
    finally {
        if ([IO.File]::Exists($tempStore)) { try { [IO.File]::Delete($tempStore) } catch {} }
        if ([IO.File]::Exists($tempTemplate)) { try { [IO.File]::Delete($tempTemplate) } catch {} }
    }
}

'''
core = replace_once(core, anchor, helpers + anchor, 'consulta e restauração de backups')
write(core_path, core)

# Interface: histórico consultável e segurança operável dentro do próprio módulo.
ui = read(ui_path)
ui = replace_once(ui, '$script:ModuleVersion = "1.2.0"', '$script:ModuleVersion = "1.3.0"', 'versão do módulo')

refresh_anchor = 'function Refresh-NFSummary {\n'
ui_helpers = r'''function Format-NFHistoryDate {
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
            default { [string]$event.Tipo }
        }
        if ($type -ne "Todos" -and $label -ne $type) { continue }
        $search = (($label + " " + [string]$event.Produto + " " + [string]$event.NFEntrada + " " + [string]$event.Detalhes)).ToLowerInvariant()
        if (-not [string]::IsNullOrWhiteSpace($filter) -and -not $search.Contains($filter)) { continue }
        [void]$historyGrid.Rows.Add([string]$event.Id, (Format-NFHistoryDate ([string]$event.DataHora)), $label, [string]$event.Produto, [string]$event.NFEntrada, [string]$event.Detalhes)
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
    $headerText.Text = (Format-NFHistoryDate ([string]$event.DataHora)) + "  •  " + [string]$event.Tipo + "`r`nNF: " + [string]$event.NFEntrada + "    Produto: " + [string]$event.Produto + $(if ([string]::IsNullOrWhiteSpace([string]$event.Detalhes)) { "" } else { "`r`n" + [string]$event.Detalhes })
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

'''
ui = replace_once(ui, refresh_anchor, ui_helpers + refresh_anchor, 'funções de histórico e segurança')

ui = replace_once(ui,
'''    Refresh-NFProductGrid -Product $script:KeyboardProduct -Grid $keyboardGrid -FilterBox $keyboardFilter -StatusFilter $keyboardStatusFilter -CodeFilter $keyboardCodeFilter -CountLabel $keyboardCountLabel
    $templateReady = [IO.File]::Exists((Get-NFEntradaTemplatePath -DataDirectory $script:DataDirectory))
''',
'''    Refresh-NFProductGrid -Product $script:KeyboardProduct -Grid $keyboardGrid -FilterBox $keyboardFilter -StatusFilter $keyboardStatusFilter -CodeFilter $keyboardCodeFilter -CountLabel $keyboardCountLabel
    if ($mainTabs.SelectedTab -eq $historyTab) { Refresh-NFHistory }
    if ($mainTabs.SelectedTab -eq $securityTab) { Refresh-NFBackups }
    $templateReady = [IO.File]::Exists((Get-NFEntradaTemplatePath -DataDirectory $script:DataDirectory))
''', 'refresh geral')

ui = replace_once(ui,
'''$keyboardTab = New-Object Windows.Forms.TabPage
$keyboardTab.Text = "TECLADO V5"
$keyboardTab.BackColor = $script:CurrentPalette.Background
$mainTabs.TabPages.Add($keyboardTab)
''',
'''$keyboardTab = New-Object Windows.Forms.TabPage
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
''', 'novas abas')

product_anchor = '$computerGrid = $null; $computerFilter = $null; $computerStatusFilter = $null; $computerCodeFilter = $null; $computerCountLabel = $null\n'
history_ui = r'''# HISTÓRICO — consulta auditável das alterações do módulo.
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
[void]$historyTypeFilter.Items.AddRange(@("Todos", "Adição", "Edição", "Exclusão", "Importação", "Restauração"))
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

'''
ui = replace_once(ui, product_anchor, history_ui + product_anchor, 'interface histórico/segurança')

ui = replace_once(ui,
'''$mainTabs.Add_SelectedIndexChanged({ Update-NFActions })
$newButton.Add_Click({ Add-NFRecordFromUI })
''',
'''$mainTabs.Add_SelectedIndexChanged({ Update-NFActions; if ($mainTabs.SelectedTab -eq $historyTab) { Refresh-NFHistory }; if ($mainTabs.SelectedTab -eq $securityTab) { Refresh-NFBackups } })
$historyFilter.Add_TextChanged({ Refresh-NFHistory })
$historyTypeFilter.Add_SelectedIndexChanged({ Refresh-NFHistory })
$historyGrid.Add_SelectionChanged({ $historyDetailsButton.Enabled = ($historyGrid.SelectedRows.Count -gt 0) })
$historyGrid.Add_CellDoubleClick({ if ($_.RowIndex -ge 0) { Show-NFHistoryDetails } })
$historyDetailsButton.Add_Click({ Show-NFHistoryDetails })
$backupGrid.Add_SelectionChanged({ $restoreBackupButton.Enabled = ($backupGrid.SelectedRows.Count -gt 0 -and [string]$backupGrid.SelectedRows[0].Cells["BackupStatus"].Value -eq "Pronto") })
$manualBackupButton.Add_Click({ New-NFManualBackupFromUI })
$restoreBackupButton.Add_Click({ Restore-NFBackupFromUI })
$newButton.Add_Click({ Add-NFRecordFromUI })
''', 'eventos histórico/segurança')
write(ui_path, ui)
print('Etapa 3 core/UI aplicada.')
