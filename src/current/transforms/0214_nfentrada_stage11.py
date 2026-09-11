from pathlib import Path


def read(path):
    return path.read_text(encoding='utf-8-sig')


def write(path, text):
    path.write_text(text, encoding='utf-8')


def rep(text, old, new, label):
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: esperado 1 marcador, encontrado {count}')
    return text.replace(old, new, 1)

root = Path('.')
core_path = root / 'src/generated/Modulos/Controle-NF-Entrada/NFEntrada.Core.ps1'
ui_path = root / 'src/generated/Modulos/Controle-NF-Entrada/Controle NF Entrada.ps1'
central_path = root / 'src/generated/Central de Trabalho.ps1'

core = read(core_path)
ui = read(ui_path)
central = read(central_path)

if 'function Get-NFEntradaIntegrityReport' in core:
    raise SystemExit('Etapa 11 já aplicada ao núcleo.')

core = rep(core,
'''    [IO.File]::WriteAllText(
        [IO.Path]::Combine($backupDirectory, "backup-info.json"),
        ($info | ConvertTo-Json -Depth 4),
        ([Text.UTF8Encoding]::new($true))
    )
    return [pscustomobject]@{''',
'''    [IO.File]::WriteAllText(
        [IO.Path]::Combine($backupDirectory, "backup-info.json"),
        ($info | ConvertTo-Json -Depth 4),
        ([Text.UTF8Encoding]::new($true))
    )
    [void](Invoke-NFEntradaBackupRetention -DataDirectory $DataDirectory -MaxAutomaticBackups 20)
    return [pscustomobject]@{''',
'limpeza controlada após backup')

insert = r'''function Invoke-NFEntradaBackupRetention {
    param(
        [string]$DataDirectory = (Get-NFEntradaDefaultDataDirectory),
        [int]$MaxAutomaticBackups = 20
    )
    if ($MaxAutomaticBackups -lt 1) { $MaxAutomaticBackups = 1 }
    $backups = @(Get-NFEntradaSafetyBackups -DataDirectory $DataDirectory)
    $automatic = @($backups | Where-Object { [string]$_.Motivo -eq "Automático" } | Sort-Object DataHora -Descending)
    if ($automatic.Count -le $MaxAutomaticBackups) {
        return [pscustomobject]@{ Removidos = 0; MantidosAutomaticos = $automatic.Count; Limite = $MaxAutomaticBackups }
    }
    $removed = 0
    foreach ($backup in @($automatic | Select-Object -Skip $MaxAutomaticBackups)) {
        $directory = [IO.Path]::GetFullPath([string]$backup.Directory)
        $root = [IO.Path]::GetFullPath((Get-NFEntradaBackupsDirectory -DataDirectory $DataDirectory)).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
        if (-not $directory.StartsWith($root + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { continue }
        try {
            if ([IO.Directory]::Exists($directory)) {
                [IO.Directory]::Delete($directory, $true)
                $removed++
            }
        }
        catch {}
    }
    return [pscustomobject]@{ Removidos = $removed; MantidosAutomaticos = [Math]::Min($automatic.Count, $MaxAutomaticBackups); Limite = $MaxAutomaticBackups }
}

function Get-NFEntradaIntegrityReport {
    param(
        [Parameter(Mandatory = $true)]$Store,
        [string]$DataDirectory = (Get-NFEntradaDefaultDataDirectory)
    )
    [void](Ensure-NFEntradaStoreShape -Store $Store)
    $errors = [Collections.Generic.List[string]]::new()
    $warnings = [Collections.Generic.List[string]]::new()
    $details = [Collections.Generic.List[string]]::new()

    $storePath = Get-NFEntradaStorePath -DataDirectory $DataDirectory
    $templatePath = Get-NFEntradaTemplatePath -DataDirectory $DataDirectory
    if (-not [IO.File]::Exists($storePath)) {
        [void]$warnings.Add("A base local ainda não foi gravada no disco.")
    }
    else {
        try { [void](Read-NFEntradaStore -Path $storePath); [void]$details.Add("Base JSON: leitura válida") }
        catch { [void]$errors.Add("A base JSON atual não pôde ser lida: " + $_.Exception.Message) }
    }

    if (-not [IO.File]::Exists($templatePath)) {
        [void]$warnings.Add("O modelo Excel oficial não está disponível; a exportação ficará bloqueada.")
    }
    elseif ([IO.FileInfo]::new($templatePath).Length -le 0) {
        [void]$errors.Add("O modelo Excel oficial está vazio.")
    }
    else { [void]$details.Add("Modelo Excel: disponível") }

    $totalRecords = 0
    $duplicateCount = 0
    foreach ($product in @("COMPUTADOR DE BORDO V5", "TECLADO V5")) {
        $records = @(Get-NFEntradaProductRecords -Store $Store -Product $product)
        $totalRecords += $records.Count
        $groups = @($records | Where-Object { -not [string]::IsNullOrWhiteSpace((ConvertTo-NFEntradaText $_.NFEntrada)) } | Group-Object { (ConvertTo-NFEntradaText $_.NFEntrada).ToUpperInvariant() } | Where-Object { $_.Count -gt 1 })
        foreach ($group in $groups) {
            $duplicateCount++
            [void]$errors.Add((Get-NFEntradaProductDisplayName $product) + ": NF duplicada " + [string]$group.Name + ".")
        }
    }

    $review = @(Get-NFEntradaReviewItems -Store $Store)
    if ($review.Count -gt 0) { [void]$warnings.Add("Existem " + $review.Count + " NF(s) com dados para revisar.") }

    $backups = @(Get-NFEntradaSafetyBackups -DataDirectory $DataDirectory)
    $invalidBackups = @($backups | Where-Object { [string]$_.Situacao -ne "Pronto" })
    if ($invalidBackups.Count -gt 0) { [void]$warnings.Add("Existem " + $invalidBackups.Count + " backup(s) inválido(s) ou incompleto(s).") }
    $automaticBackups = @($backups | Where-Object { [string]$_.Motivo -eq "Automático" }).Count
    if ($automaticBackups -gt 20) { [void]$warnings.Add("Há mais de 20 backups automáticos; a próxima criação fará a retenção automática.") }

    $staleTemp = 0
    if ([IO.Directory]::Exists($DataDirectory)) {
        foreach ($file in [IO.Directory]::GetFiles($DataDirectory, "*.tmp")) { $staleTemp++ }
    }
    if ($staleTemp -gt 0) { [void]$warnings.Add("Foram encontrados " + $staleTemp + " arquivo(s) temporário(s) pendente(s).") }

    $status = if ($errors.Count -gt 0) { "ERRO" } elseif ($warnings.Count -gt 0) { "ATENÇÃO" } else { "OK" }
    return [pscustomobject]@{
        Situacao = $status
        Erros = @($errors)
        Avisos = @($warnings)
        Detalhes = @($details)
        Registros = $totalRecords
        Duplicidades = $duplicateCount
        Pendencias = $review.Count
        Backups = $backups.Count
        BackupsInvalidos = $invalidBackups.Count
        BackupsAutomaticos = $automaticBackups
        ArquivosTemporarios = $staleTemp
        ModeloDisponivel = ([IO.File]::Exists($templatePath) -and ([IO.FileInfo]::new($templatePath)).Length -gt 0)
    }
}

'''
core = rep(core, 'function Restore-NFEntradaBackupSet {', insert + 'function Restore-NFEntradaBackupSet {', 'funções de auditoria e retenção')

ui = rep(ui, '$script:ModuleVersion = "2.1.0"', '$script:ModuleVersion = "2.2.0"', 'versão UI')
ui = rep(ui,
    '$securityInfo.Text = "Os backups guardam a base e, quando disponível, o modelo Excel. Antes de restaurar um backup, o estado atual é salvo automaticamente em outra cópia de segurança."',
    '$securityInfo.Text = "Os backups guardam a base e o modelo Excel. O sistema mantém no máximo 20 backups automáticos; backups manuais e de recuperação não são removidos por essa retenção. Antes de restaurar, o estado atual é protegido."',
    'texto de retenção')

ui = rep(ui,
'''$manualBackupButton = New-Object Windows.Forms.Button
$manualBackupButton.Text = "CRIAR BACKUP AGORA"; $manualBackupButton.Width = 150; $manualBackupButton.Height = 32; Set-NFButtonStyle $manualBackupButton "Secondary"
$restoreBackupButton = New-Object Windows.Forms.Button''',
'''$integrityButton = New-Object Windows.Forms.Button
$integrityButton.Text = "VERIFICAR INTEGRIDADE"; $integrityButton.Width = 165; $integrityButton.Height = 32; Set-NFButtonStyle $integrityButton "Secondary"
$manualBackupButton = New-Object Windows.Forms.Button
$manualBackupButton.Text = "CRIAR BACKUP AGORA"; $manualBackupButton.Width = 150; $manualBackupButton.Height = 32; Set-NFButtonStyle $manualBackupButton "Secondary"
$restoreBackupButton = New-Object Windows.Forms.Button''',
'botão integridade')
ui = rep(ui,
    '$backupButtons.Controls.Add($manualBackupButton); $backupButtons.Controls.Add($restoreBackupButton)',
    '$backupButtons.Controls.Add($integrityButton); $backupButtons.Controls.Add($manualBackupButton); $backupButtons.Controls.Add($restoreBackupButton)',
    'ordem botões segurança')

show_integrity = r'''function Show-NFIntegrityReport {
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
        Set-NFStatus ("Integridade: " + [string]$report.Situacao + " • " + [string]$report.Erros.Count + " erro(s) • " + [string]$report.Avisos.Count + " aviso(s)") (if ($report.Situacao -eq "ERRO") { "Error" } elseif ($report.Situacao -eq "ATENÇÃO") { "Warning" } else { "Success" })
    }
    catch {
        Set-NFStatus $_.Exception.Message "Error"
        [Windows.Forms.MessageBox]::Show($_.Exception.Message, "Falha na verificação de integridade", 0, 16) | Out-Null
    }
}

'''
ui = rep(ui, 'function Refresh-NFBackups {', show_integrity + 'function Refresh-NFBackups {', 'função UI integridade')

ui = rep(ui,
    '$toolTip.SetToolTip($movementReverseButton, "Estorna a saída ativa sem apagar a movimentação original (Ctrl+Z).")',
    '$toolTip.SetToolTip($movementReverseButton, "Estorna a saída ativa sem apagar a movimentação original (Ctrl+Z).")\n$toolTip.SetToolTip($integrityButton, "Audita base, duplicidades, pendências, modelo Excel, backups e arquivos temporários.")',
    'tooltip integridade')
ui = rep(ui,
    '$manualBackupButton.Add_Click({ New-NFManualBackupFromUI })',
    '$integrityButton.Add_Click({ Show-NFIntegrityReport })\n$manualBackupButton.Add_Click({ New-NFManualBackupFromUI })',
    'evento integridade')

central = rep(central, '$script:AppVersion = "0.21.13"', '$script:AppVersion = "0.21.14"', 'versão Central')
central = rep(central, '$script:NFEntradaVersion = "2.1.0"', '$script:NFEntradaVersion = "2.2.0"', 'versão NF Central')

for marker in (
    'function Get-NFEntradaIntegrityReport',
    'function Invoke-NFEntradaBackupRetention',
    'MaxAutomaticBackups = 20',
    '$script:ModuleVersion = "2.2.0"',
    'VERIFICAR INTEGRIDADE',
    'function Show-NFIntegrityReport',
    '$script:AppVersion = "0.21.14"',
):
    if marker not in core and marker not in ui and marker not in central:
        raise SystemExit('Contrato ausente após etapa 11: ' + marker)

write(core_path, core)
write(ui_path, ui)
write(central_path, central)
print('ETAPA 11 NF ENTRADA: OK - auditoria final e proteção dos dados aplicadas.')
