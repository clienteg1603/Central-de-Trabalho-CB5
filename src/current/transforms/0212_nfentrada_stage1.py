from pathlib import Path
import json

ROOT = Path('.')
core_path = ROOT / 'src/generated/Modulos/Controle-NF-Entrada/NFEntrada.Core.ps1'
ui_path = ROOT / 'src/generated/Modulos/Controle-NF-Entrada/Controle NF Entrada.ps1'
central_path = ROOT / 'src/generated/Central de Trabalho.ps1'
reg_path = ROOT / 'src/ci/regression_contracts.py'
version_path = ROOT / 'src/current/version.json'


def read(path):
    return path.read_text(encoding='utf-8-sig')


def write(path, text):
    path.write_text(text, encoding='utf-8')


def replace_once(text, old, new, label):
    if old not in text:
        raise SystemExit(f'Etapa NF Entrada: trecho não encontrado ({label})')
    return text.replace(old, new, 1)


# ---------- Core: histórico auditável + backup de segurança + importação protegida ----------
core = read(core_path)
anchor = '''function Get-NFEntradaTemplatePath {
    param([string]$DataDirectory = (Get-NFEntradaDefaultDataDirectory))
    return [IO.Path]::Combine($DataDirectory, "modelo-nf-entrada.xlsx")
}
'''
helpers = r'''

function Get-NFEntradaBackupsDirectory {
    param([string]$DataDirectory = (Get-NFEntradaDefaultDataDirectory))
    return [IO.Path]::Combine($DataDirectory, "Backups")
}

function Ensure-NFEntradaStoreShape {
    param([Parameter(Mandatory = $true)]$Store)
    if ($null -eq $Store.PSObject.Properties["Historico"]) {
        $Store | Add-Member -NotePropertyName Historico -NotePropertyValue @()
    }
    elseif ($null -eq $Store.Historico) {
        $Store.Historico = @()
    }
    if ($null -eq $Store.PSObject.Properties["Meta"]) {
        $Store | Add-Member -NotePropertyName Meta -NotePropertyValue ([pscustomobject]@{
            CriadoEm = [DateTime]::Now.ToString("o")
            UltimaAlteracaoEm = [DateTime]::Now.ToString("o")
        })
    }
    else {
        if ($null -eq $Store.Meta.PSObject.Properties["CriadoEm"]) {
            $Store.Meta | Add-Member -NotePropertyName CriadoEm -NotePropertyValue ([DateTime]::Now.ToString("o"))
        }
        if ($null -eq $Store.Meta.PSObject.Properties["UltimaAlteracaoEm"]) {
            $Store.Meta | Add-Member -NotePropertyName UltimaAlteracaoEm -NotePropertyValue ([DateTime]::Now.ToString("o"))
        }
    }
    return $Store
}

function Copy-NFEntradaRecordSnapshot {
    param($Record)
    if ($null -eq $Record) { return $null }
    return [pscustomobject]@{
        Id = [int]$Record.Id
        Ordem = [int]$Record.Ordem
        Data = ConvertTo-NFEntradaText $Record.Data
        QuantidadeNaNF = [int]$Record.QuantidadeNaNF
        NFEntrada = ConvertTo-NFEntradaText $Record.NFEntrada
        QuantidadeSaldo = [int]$Record.QuantidadeSaldo
        Codigo = ConvertTo-NFEntradaText $Record.Codigo
        NFSaida = ConvertTo-NFEntradaText $Record.NFSaida
    }
}

function Add-NFEntradaHistoryEvent {
    param(
        [Parameter(Mandatory = $true)]$Store,
        [Parameter(Mandatory = $true)][string]$Tipo,
        [string]$Produto = "",
        [int]$RegistroId = 0,
        [string]$NFEntrada = "",
        $Antes = $null,
        $Depois = $null,
        [string]$Detalhes = ""
    )
    [void](Ensure-NFEntradaStoreShape -Store $Store)
    $event = [pscustomobject]@{
        Id = [guid]::NewGuid().ToString("N")
        DataHora = [DateTime]::Now.ToString("o")
        Tipo = $Tipo
        Produto = $Produto
        RegistroId = $RegistroId
        NFEntrada = $NFEntrada
        Detalhes = $Detalhes
        Antes = $Antes
        Depois = $Depois
    }
    $Store.Historico = @($Store.Historico) + $event
    $Store.Meta.UltimaAlteracaoEm = $event.DataHora
    return $event
}

function Get-NFEntradaHistory {
    param([Parameter(Mandatory = $true)]$Store)
    [void](Ensure-NFEntradaStoreShape -Store $Store)
    return @($Store.Historico | Sort-Object { [DateTime]$_.DataHora } -Descending)
}

function New-NFEntradaSafetyBackup {
    param([string]$DataDirectory = (Get-NFEntradaDefaultDataDirectory))
    $storePath = Get-NFEntradaStorePath -DataDirectory $DataDirectory
    $templatePath = Get-NFEntradaTemplatePath -DataDirectory $DataDirectory
    $storeExists = [IO.File]::Exists($storePath)
    $templateExists = [IO.File]::Exists($templatePath)
    if (-not $storeExists -and -not $templateExists) { return $null }

    $backupRoot = Get-NFEntradaBackupsDirectory -DataDirectory $DataDirectory
    if (-not [IO.Directory]::Exists($backupRoot)) { [void][IO.Directory]::CreateDirectory($backupRoot) }
    $stamp = [DateTime]::Now.ToString("yyyyMMdd-HHmmss-fff")
    $backupDirectory = [IO.Path]::Combine($backupRoot, $stamp)
    [void][IO.Directory]::CreateDirectory($backupDirectory)
    if ($storeExists) { [IO.File]::Copy($storePath, [IO.Path]::Combine($backupDirectory, "nf-entrada.json"), $true) }
    if ($templateExists) { [IO.File]::Copy($templatePath, [IO.Path]::Combine($backupDirectory, "modelo-nf-entrada.xlsx"), $true) }
    return [pscustomobject]@{
        Directory = $backupDirectory
        StoreExisted = $storeExists
        TemplateExisted = $templateExists
    }
}

function Restore-NFEntradaSafetyBackup {
    param(
        [Parameter(Mandatory = $true)]$Backup,
        [string]$DataDirectory = (Get-NFEntradaDefaultDataDirectory)
    )
    $storePath = Get-NFEntradaStorePath -DataDirectory $DataDirectory
    $templatePath = Get-NFEntradaTemplatePath -DataDirectory $DataDirectory
    $backupStore = [IO.Path]::Combine([string]$Backup.Directory, "nf-entrada.json")
    $backupTemplate = [IO.Path]::Combine([string]$Backup.Directory, "modelo-nf-entrada.xlsx")
    if ([bool]$Backup.StoreExisted -and [IO.File]::Exists($backupStore)) { [IO.File]::Copy($backupStore, $storePath, $true) }
    elseif (-not [bool]$Backup.StoreExisted -and [IO.File]::Exists($storePath)) { [IO.File]::Delete($storePath) }
    if ([bool]$Backup.TemplateExisted -and [IO.File]::Exists($backupTemplate)) { [IO.File]::Copy($backupTemplate, $templatePath, $true) }
    elseif (-not [bool]$Backup.TemplateExisted -and [IO.File]::Exists($templatePath)) { [IO.File]::Delete($templatePath) }
}
'''
core = replace_once(core, anchor, anchor + helpers, 'helpers de segurança')

old_store_from_workbook = '''        return [pscustomobject]@{
            SchemaVersion = 1
            NextId = $next
            Produtos = [pscustomobject]@{
                'COMPUTADOR DE BORDO V5' = @($cb)
                'TECLADO V5' = @($tk)
            }
        }
'''
new_store_from_workbook = '''        $store = [pscustomobject]@{
            SchemaVersion = 1
            NextId = $next
            Produtos = [pscustomobject]@{
                'COMPUTADOR DE BORDO V5' = @($cb)
                'TECLADO V5' = @($tk)
            }
            Historico = @()
            Meta = [pscustomobject]@{
                CriadoEm = [DateTime]::Now.ToString("o")
                UltimaAlteracaoEm = [DateTime]::Now.ToString("o")
            }
        }
        return $store
'''
core = replace_once(core, old_store_from_workbook, new_store_from_workbook, 'store importado')

old_empty = '''function New-EmptyNFEntradaStore {
    return [pscustomobject]@{
        SchemaVersion = 1
        NextId = 1
        Produtos = [pscustomobject]@{
            'COMPUTADOR DE BORDO V5' = @()
            'TECLADO V5' = @()
        }
    }
}
'''
new_empty = '''function New-EmptyNFEntradaStore {
    return [pscustomobject]@{
        SchemaVersion = 1
        NextId = 1
        Produtos = [pscustomobject]@{
            'COMPUTADOR DE BORDO V5' = @()
            'TECLADO V5' = @()
        }
        Historico = @()
        Meta = [pscustomobject]@{
            CriadoEm = [DateTime]::Now.ToString("o")
            UltimaAlteracaoEm = [DateTime]::Now.ToString("o")
        }
    }
}
'''
core = replace_once(core, old_empty, new_empty, 'store vazio')

old_import = '''function Import-NFEntradaSourceWorkbook {
    param(
        [Parameter(Mandatory = $true)][string]$SourcePath,
        [string]$DataDirectory = (Get-NFEntradaDefaultDataDirectory)
    )
    if (-not [IO.File]::Exists($SourcePath)) { throw "A planilha selecionada não foi encontrada." }
    if ([IO.Path]::GetExtension($SourcePath) -ne ".xlsx") { throw "Selecione a planilha original no formato .xlsx." }
    if (-not [IO.Directory]::Exists($DataDirectory)) { [void][IO.Directory]::CreateDirectory($DataDirectory) }
    $store = New-NFEntradaStoreFromWorkbook -WorkbookPath $SourcePath
    $templatePath = Get-NFEntradaTemplatePath -DataDirectory $DataDirectory
    [IO.File]::Copy($SourcePath, $templatePath, $true)
    $storePath = Get-NFEntradaStorePath -DataDirectory $DataDirectory
    Write-NFEntradaStore -Store $store -Path $storePath
    return [pscustomobject]@{ Store = $store; StorePath = $storePath; TemplatePath = $templatePath }
}
'''
new_import = '''function Import-NFEntradaSourceWorkbook {
    param(
        [Parameter(Mandatory = $true)][string]$SourcePath,
        [string]$DataDirectory = (Get-NFEntradaDefaultDataDirectory)
    )
    if (-not [IO.File]::Exists($SourcePath)) { throw "A planilha selecionada não foi encontrada." }
    if ([IO.Path]::GetExtension($SourcePath) -ne ".xlsx") { throw "Selecione a planilha original no formato .xlsx." }
    if (-not [IO.Directory]::Exists($DataDirectory)) { [void][IO.Directory]::CreateDirectory($DataDirectory) }

    $storePath = Get-NFEntradaStorePath -DataDirectory $DataDirectory
    $templatePath = Get-NFEntradaTemplatePath -DataDirectory $DataDirectory
    $store = New-NFEntradaStoreFromWorkbook -WorkbookPath $SourcePath
    if ([IO.File]::Exists($storePath)) {
        try {
            $previous = Read-NFEntradaStore -Path $storePath
            [void](Ensure-NFEntradaStoreShape -Store $previous)
            $store.Historico = @($previous.Historico)
        }
        catch {}
    }
    [void](Add-NFEntradaHistoryEvent -Store $store -Tipo "Importacao" -Detalhes ("Planilha importada: " + [IO.Path]::GetFileName($SourcePath)))

    $backup = New-NFEntradaSafetyBackup -DataDirectory $DataDirectory
    $token = [guid]::NewGuid().ToString("N")
    $tempTemplate = $templatePath + "." + $token + ".tmp"
    $tempStore = $storePath + "." + $token + ".tmp"
    try {
        [IO.File]::Copy($SourcePath, $tempTemplate, $true)
        Write-NFEntradaStore -Store $store -Path $tempStore
        [void](Read-NFEntradaStore -Path $tempStore)
        [IO.File]::Copy($tempTemplate, $templatePath, $true)
        [IO.File]::Copy($tempStore, $storePath, $true)
    }
    catch {
        if ($null -ne $backup) {
            try { Restore-NFEntradaSafetyBackup -Backup $backup -DataDirectory $DataDirectory } catch {}
        }
        throw
    }
    finally {
        if ([IO.File]::Exists($tempTemplate)) { try { [IO.File]::Delete($tempTemplate) } catch {} }
        if ([IO.File]::Exists($tempStore)) { try { [IO.File]::Delete($tempStore) } catch {} }
        $tempBak = $tempStore + ".bak"
        if ([IO.File]::Exists($tempBak)) { try { [IO.File]::Delete($tempBak) } catch {} }
    }
    return [pscustomobject]@{
        Store = $store
        StorePath = $storePath
        TemplatePath = $templatePath
        BackupDirectory = if ($null -ne $backup) { [string]$backup.Directory } else { "" }
    }
}
'''
core = replace_once(core, old_import, new_import, 'importação transacional')

old_write = '''function Write-NFEntradaStore {
    param(
        [Parameter(Mandatory = $true)]$Store,
        [string]$Path = (Get-NFEntradaStorePath)
    )
    $directory = [IO.Path]::GetDirectoryName($Path)
    if (-not [IO.Directory]::Exists($directory)) { [void][IO.Directory]::CreateDirectory($directory) }
    $temp = $Path + ".tmp"
    $json = $Store | ConvertTo-Json -Depth 12
    [IO.File]::WriteAllText($temp, $json, ([Text.UTF8Encoding]::new($true)))
    if ([IO.File]::Exists($Path)) {
        $backup = $Path + ".bak"
        [IO.File]::Copy($Path, $backup, $true)
    }
    [IO.File]::Copy($temp, $Path, $true)
    [IO.File]::Delete($temp)
}
'''
new_write = '''function Write-NFEntradaStore {
    param(
        [Parameter(Mandatory = $true)]$Store,
        [string]$Path = (Get-NFEntradaStorePath)
    )
    [void](Ensure-NFEntradaStoreShape -Store $Store)
    $Store.Meta.UltimaAlteracaoEm = [DateTime]::Now.ToString("o")
    $directory = [IO.Path]::GetDirectoryName($Path)
    if (-not [IO.Directory]::Exists($directory)) { [void][IO.Directory]::CreateDirectory($directory) }
    $temp = $Path + ".tmp"
    $json = $Store | ConvertTo-Json -Depth 20
    [IO.File]::WriteAllText($temp, $json, ([Text.UTF8Encoding]::new($true)))
    if ([IO.File]::Exists($Path)) {
        $backup = $Path + ".bak"
        [IO.File]::Copy($Path, $backup, $true)
    }
    [IO.File]::Copy($temp, $Path, $true)
    [IO.File]::Delete($temp)
}
'''
core = replace_once(core, old_write, new_write, 'gravação da base')

old_read = '''    $store = ([IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8) | ConvertFrom-Json)
    if ($null -eq $store -or [int]$store.SchemaVersion -ne 1) { throw "A base de NF de Entrada possui formato incompatível." }
    return $store
'''
new_read = '''    $store = ([IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8) | ConvertFrom-Json)
    if ($null -eq $store -or [int]$store.SchemaVersion -ne 1) { throw "A base de NF de Entrada possui formato incompatível." }
    [void](Ensure-NFEntradaStoreShape -Store $store)
    return $store
'''
core = replace_once(core, old_read, new_read, 'leitura da base')

old_add_tail = '''    $property.Value = @($records + $newRecord)
    $Store.NextId = $id + 1
    return $newRecord
'''
new_add_tail = '''    $property.Value = @($records + $newRecord)
    $Store.NextId = $id + 1
    [void](Add-NFEntradaHistoryEvent -Store $Store -Tipo "Adicao" -Produto $Product -RegistroId $id -NFEntrada $newRecord.NFEntrada -Depois (Copy-NFEntradaRecordSnapshot $newRecord))
    return $newRecord
'''
core = replace_once(core, old_add_tail, new_add_tail, 'histórico de adição')

old_update_loop = '''    foreach ($existing in $records) {
        if ([int]$existing.Id -ne $Id) { continue }
        $existing.Data = ConvertTo-NFEntradaText $Record.Data
        $existing.QuantidadeNaNF = [int]$Record.QuantidadeNaNF
        $existing.NFEntrada = ConvertTo-NFEntradaText $Record.NFEntrada
        $existing.QuantidadeSaldo = [int]$Record.QuantidadeSaldo
        $existing.Codigo = ConvertTo-NFEntradaText $Record.Codigo
        $existing.NFSaida = ConvertTo-NFEntradaText $Record.NFSaida
        $found = $true
        break
    }
    if (-not $found) { throw "O registro selecionado não foi encontrado." }
    $Store.Produtos.PSObject.Properties[$Product].Value = @($records)
'''
new_update_loop = '''    $before = $null
    $after = $null
    foreach ($existing in $records) {
        if ([int]$existing.Id -ne $Id) { continue }
        $before = Copy-NFEntradaRecordSnapshot $existing
        $existing.Data = ConvertTo-NFEntradaText $Record.Data
        $existing.QuantidadeNaNF = [int]$Record.QuantidadeNaNF
        $existing.NFEntrada = ConvertTo-NFEntradaText $Record.NFEntrada
        $existing.QuantidadeSaldo = [int]$Record.QuantidadeSaldo
        $existing.Codigo = ConvertTo-NFEntradaText $Record.Codigo
        $existing.NFSaida = ConvertTo-NFEntradaText $Record.NFSaida
        $after = Copy-NFEntradaRecordSnapshot $existing
        $found = $true
        break
    }
    if (-not $found) { throw "O registro selecionado não foi encontrado." }
    $Store.Produtos.PSObject.Properties[$Product].Value = @($records)
    [void](Add-NFEntradaHistoryEvent -Store $Store -Tipo "Edicao" -Produto $Product -RegistroId $Id -NFEntrada $after.NFEntrada -Antes $before -Depois $after)
'''
core = replace_once(core, old_update_loop, new_update_loop, 'histórico de edição')

old_remove = '''    $records = @(Get-NFEntradaProductRecords -Store $Store -Product $Product)
    $remaining = @($records | Where-Object { [int]$_.Id -ne $Id })
    if ($remaining.Count -eq $records.Count) { throw "O registro selecionado não foi encontrado." }
    $Store.Produtos.PSObject.Properties[$Product].Value = @($remaining)
'''
new_remove = '''    $records = @(Get-NFEntradaProductRecords -Store $Store -Product $Product)
    $removed = @($records | Where-Object { [int]$_.Id -eq $Id } | Select-Object -First 1)
    $remaining = @($records | Where-Object { [int]$_.Id -ne $Id })
    if ($remaining.Count -eq $records.Count) { throw "O registro selecionado não foi encontrado." }
    $Store.Produtos.PSObject.Properties[$Product].Value = @($remaining)
    $snapshot = if ($removed.Count -gt 0) { Copy-NFEntradaRecordSnapshot $removed[0] } else { $null }
    $nf = if ($null -ne $snapshot) { [string]$snapshot.NFEntrada } else { "" }
    [void](Add-NFEntradaHistoryEvent -Store $Store -Tipo "Exclusao" -Produto $Product -RegistroId $Id -NFEntrada $nf -Antes $snapshot)
'''
core = replace_once(core, old_remove, new_remove, 'histórico de exclusão')
write(core_path, core)

# ---------- UI: clareza operacional, confirmação de reimportação e ações contextuais ----------
ui = read(ui_path)
ui = replace_once(ui, '$script:ModuleVersion = "1.0.1"', '$script:ModuleVersion = "1.1.0"', 'versão do módulo')

button_anchor = '''function Set-NFButtonStyle {
'''
status_fn = r'''function Set-NFStatus {
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

'''
ui = replace_once(ui, button_anchor, status_fn + button_anchor, 'status operacional')

old_summary_tail = '''    $generalStatusValue.Text = [string]$summary.Situacao
    $generalStatusValue.ForeColor = if ($summary.Situacao -eq "OK") { $script:CurrentPalette.Success } else { $script:CurrentPalette.Danger }
}

function Refresh-NFAll {
    Refresh-NFSummary
    Refresh-NFProductGrid -Product $script:ComputerProduct -Grid $computerGrid -FilterBox $computerFilter
    Refresh-NFProductGrid -Product $script:KeyboardProduct -Grid $keyboardGrid -FilterBox $keyboardFilter
    $footerStatus.Text = "Base local: $($script:DatabasePath)"
}
'''
new_summary_tail = '''    $generalStatusValue.Text = [string]$summary.Situacao
    $generalStatusValue.ForeColor = if ($summary.Situacao -eq "OK") { $script:CurrentPalette.Success } else { $script:CurrentPalette.Danger }
    $computerTab.Text = "COMPUTADOR DE BORDO V5 ($([int]$summary.Produtos[$script:ComputerProduct].Registros))"
    $keyboardTab.Text = "TECLADO V5 ($([int]$summary.Produtos[$script:KeyboardProduct].Registros))"
}

function Refresh-NFAll {
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
ui = replace_once(ui, old_summary_tail, new_summary_tail, 'resumo e status')

ui = replace_once(ui, '''        Save-NFStore
        Refresh-NFAll
    }
    catch { [Windows.Forms.MessageBox]::Show($_.Exception.Message, "Controle de NF de Entrada", 0, 48) | Out-Null }
}

function Edit-NFRecordFromUI''', '''        Save-NFStore
        Refresh-NFAll
        Set-NFStatus ("Registro " + $record.NFEntrada + " incluído com sucesso.") "Success"
    }
    catch { Set-NFStatus $_.Exception.Message "Error"; [Windows.Forms.MessageBox]::Show($_.Exception.Message, "Controle de NF de Entrada", 0, 48) | Out-Null }
}

function Edit-NFRecordFromUI''', 'status adição')

ui = replace_once(ui, '''        Update-NFEntradaRecord -Store $script:Store -Product $product -Id $id -Record $record
        Save-NFStore
        Refresh-NFAll
    }
    catch { [Windows.Forms.MessageBox]::Show($_.Exception.Message, "Controle de NF de Entrada", 0, 48) | Out-Null }
}

function Remove-NFRecordFromUI''', '''        Update-NFEntradaRecord -Store $script:Store -Product $product -Id $id -Record $record
        Save-NFStore
        Refresh-NFAll
        Set-NFStatus ("Registro " + $record.NFEntrada + " atualizado com sucesso.") "Success"
    }
    catch { Set-NFStatus $_.Exception.Message "Error"; [Windows.Forms.MessageBox]::Show($_.Exception.Message, "Controle de NF de Entrada", 0, 48) | Out-Null }
}

function Remove-NFRecordFromUI''', 'status edição')

ui = replace_once(ui, '''        Remove-NFEntradaRecord -Store $script:Store -Product $product -Id $id
        Save-NFStore
        Refresh-NFAll
    }
    catch { [Windows.Forms.MessageBox]::Show($_.Exception.Message, "Controle de NF de Entrada", 0, 48) | Out-Null }
}

function Import-NFSourceFromUI''', '''        Remove-NFEntradaRecord -Store $script:Store -Product $product -Id $id
        Save-NFStore
        Refresh-NFAll
        Set-NFStatus ("Registro " + $record.NFEntrada + " excluído; histórico preservado.") "Warning"
    }
    catch { Set-NFStatus $_.Exception.Message "Error"; [Windows.Forms.MessageBox]::Show($_.Exception.Message, "Controle de NF de Entrada", 0, 48) | Out-Null }
}

function Import-NFSourceFromUI''', 'status exclusão')

old_import_ui = '''    $source = $dialog.FileName
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
'''
new_import_ui = '''    $source = $dialog.FileName
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
'''
ui = replace_once(ui, old_import_ui, new_import_ui, 'confirmação de reimportação')

ui = replace_once(ui, '''        [Windows.Forms.MessageBox]::Show(
            "Planilha exportada com o modelo original, fórmulas, resumo e formatação preservados.`r`n`r`n$exported",
            "Exportação concluída",
            [Windows.Forms.MessageBoxButtons]::OK,
            [Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
    }
    catch { [Windows.Forms.MessageBox]::Show($_.Exception.Message, "Falha na exportação", 0, 16) | Out-Null }
''', '''        Set-NFStatus "Planilha exportada com sucesso." "Success"
        [Windows.Forms.MessageBox]::Show(
            "Planilha exportada com o modelo original, fórmulas, resumo e formatação preservados.`r`n`r`n$exported",
            "Exportação concluída",
            [Windows.Forms.MessageBoxButtons]::OK,
            [Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
    }
    catch { Set-NFStatus $_.Exception.Message "Error"; [Windows.Forms.MessageBox]::Show($_.Exception.Message, "Falha na exportação", 0, 16) | Out-Null }
''', 'status exportação')

old_actions = '''function Update-NFActions {
    $enabled = -not [string]::IsNullOrWhiteSpace((Get-SelectedProduct))
    $actionPanel.Visible = $enabled
    $newButton.Enabled = $enabled
    $editButton.Enabled = $enabled
    $deleteButton.Enabled = $enabled
}
'''
new_actions = '''function Update-NFActions {
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
}
'''
ui = replace_once(ui, old_actions, new_actions, 'ações contextuais')

ui = replace_once(ui, '''$computerGrid.Add_CellDoubleClick({ if ($_.RowIndex -ge 0) { Edit-NFRecordFromUI } })
$keyboardGrid.Add_CellDoubleClick({ if ($_.RowIndex -ge 0) { Edit-NFRecordFromUI } })
$mainTabs.Add_SelectedIndexChanged({ Update-NFActions })
''', '''$computerGrid.Add_CellDoubleClick({ if ($_.RowIndex -ge 0) { Edit-NFRecordFromUI } })
$keyboardGrid.Add_CellDoubleClick({ if ($_.RowIndex -ge 0) { Edit-NFRecordFromUI } })
$computerGrid.Add_SelectionChanged({ Update-NFActions })
$keyboardGrid.Add_SelectionChanged({ Update-NFActions })
$mainTabs.Add_SelectedIndexChanged({ Update-NFActions })
''', 'seleção das grades')
write(ui_path, ui)

# ---------- Central ----------
central = read(central_path)
central = replace_once(central, '$script:AppVersion = "0.21.1"', '$script:AppVersion = "0.21.2"', 'versão da Central')
central = replace_once(central, '$script:NFEntradaVersion = "1.0.1"', '$script:NFEntradaVersion = "1.1.0"', 'versão NF na Central')
write(central_path, central)

# ---------- Contratos permanentes de regressão ----------
reg = read(reg_path)
old_fns = 'for fn in ("Initialize-NFEntradaDataStore", "Import-NFEntradaSourceWorkbook", "Read-NFEntradaStore", "Write-NFEntradaStore", "Add-NFEntradaRecord", "Update-NFEntradaRecord", "Remove-NFEntradaRecord", "Get-NFEntradaSummary", "Export-NFEntradaWorkbook"):'
new_fns = 'for fn in ("Initialize-NFEntradaDataStore", "Import-NFEntradaSourceWorkbook", "Read-NFEntradaStore", "Write-NFEntradaStore", "Ensure-NFEntradaStoreShape", "Add-NFEntradaHistoryEvent", "Get-NFEntradaHistory", "New-NFEntradaSafetyBackup", "Restore-NFEntradaSafetyBackup", "Add-NFEntradaRecord", "Update-NFEntradaRecord", "Remove-NFEntradaRecord", "Get-NFEntradaSummary", "Export-NFEntradaWorkbook"):'
reg = replace_once(reg, old_fns, new_fns, 'funções críticas NF')
old_markers = '''    for marker in ('modelo-nf-entrada.xlsx', 'Range("A3:F298").ClearContents()', '$excel.Workbooks.Open($destinationFull, 0, $false)', '$excel.CalculateFullRebuild()'):
        require(errors, nf_core, marker, "NFEntrada.Core / exportação fiel")
'''
new_markers = '''    for marker in ('modelo-nf-entrada.xlsx', 'Range("A3:F298").ClearContents()', '$excel.Workbooks.Open($destinationFull, 0, $false)', '$excel.CalculateFullRebuild()'):
        require(errors, nf_core, marker, "NFEntrada.Core / exportação fiel")
    for marker in ('Historico = @()', 'Backups', 'BackupDirectory', '-Tipo "Adicao"', '-Tipo "Edicao"', '-Tipo "Exclusao"', '-Tipo "Importacao"'):
        require(errors, nf_core, marker, "NFEntrada.Core / histórico e segurança")
    for marker in ('Confirmar nova importação', 'backup da base e do modelo atuais', 'Set-NFStatus', '$editButton.Enabled = $hasSelection', '$deleteButton.Enabled = $hasSelection'):
        require(errors, nf, marker, "NF Entrada / operação segura")
'''
reg = replace_once(reg, old_markers, new_markers, 'marcadores de segurança NF')
write(reg_path, reg)

# ---------- Metadados da versão ----------
meta = {
    'version': '0.21.2',
    'buildRevision': 1,
    'releaseNotes': [
        'Inicia a Etapa 1 de evolução focada no Controle de NF de Entrada: segurança operacional, histórico auditável e clareza das ações.',
        'Inclusões, edições e exclusões passam a registrar histórico interno com data/hora, produto, NF, estado anterior e estado posterior quando aplicável.',
        'Uma nova importação agora exige confirmação quando já existe base ativa e cria automaticamente um backup da base e do modelo atuais antes de qualquer substituição.',
        'A importação passa a preparar os novos arquivos em temporários, validá-los e restaurar o backup automaticamente se a troca falhar.',
        'O histórico anterior é preservado mesmo após reimportar a planilha; o arquivo XLSX original continua no local escolhido e não é alterado.',
        'A interface passa a mostrar contagem de registros nas abas, mensagens operacionais no rodapé e só habilita Editar/Excluir quando existe uma linha selecionada.',
        'Exportar Excel fica indisponível enquanto não houver modelo importado, evitando uma tentativa inválida.',
        'Controle de NF de Entrada passa para v1.1.0; Gerenciador de Planilhas permanece v3.7.3 e Central de Manutenção permanece v0.6.1.',
        'A versão Estável permanece v0.20.2; a v0.21.2 é publicada somente no canal Teste.'
    ]
}
version_path.write_text(json.dumps(meta, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print('ETAPA 1 NF ENTRADA: transformação preparada para v0.21.2 / módulo v1.1.0')
