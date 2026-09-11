#!/usr/bin/env python3
import pathlib
import re
import sys


def read(path):
    return path.read_text(encoding="utf-8-sig", errors="strict")


def fail(errors):
    if not errors:
        return
    print("\nREGRESSÃO FUNCIONAL: FALHOU")
    for error in errors:
        print(f"  - {error}")
    raise SystemExit(1)


def require(errors, text, marker, label):
    if marker not in text:
        errors.append(f"{label}: marcador ausente: {marker}")


def require_regex(errors, text, pattern, label):
    if re.search(pattern, text, re.S | re.I) is None:
        errors.append(f"{label}: contrato não encontrado")


def require_function(errors, text, name, label):
    require_regex(errors, text, rf"function\s+{re.escape(name)}\b", f"{label}: função {name}")


def main():
    if len(sys.argv) != 2:
        raise SystemExit("uso: regression_contracts.py ROOT")

    root = pathlib.Path(sys.argv[1])
    errors = []

    paths = {
        "central": root / "Central de Trabalho.ps1",
        "generator": root / "Modulos/Gerador-de-Planilhas-CB5-TV5/Gerador Planilhas.ps1",
        "components": root / "Modulos/Gerador-de-Planilhas-CB5-TV5/Componentes.Core.ps1",
        "maintenance": root / "Modulos/Central-de-Manutencao-CB5/Central Manutencao CB5.ps1",
        "maintenance_core": root / "Modulos/Central-de-Manutencao-CB5/Manutencao.Core.ps1",
        "nf": root / "Modulos/Controle-NF-Entrada/Controle NF Entrada.ps1",
        "nf_core": root / "Modulos/Controle-NF-Entrada/NFEntrada.Core.ps1",
        "updater": root / "Atualizador/Central de Trabalho Updater.ps1",
        "updater_core": root / "Atualizador/Update.Core.ps1",
    }
    for name, path in paths.items():
        if not path.is_file():
            errors.append(f"arquivo ausente para regressão: {path.relative_to(root)}")
    fail(errors)

    central = read(paths["central"])
    generator = read(paths["generator"])
    components = read(paths["components"])
    maintenance = read(paths["maintenance"])
    maintenance_core = read(paths["maintenance_core"])
    nf = read(paths["nf"])
    nf_core = read(paths["nf_core"])
    updater = read(paths["updater"])
    updater_core = read(paths["updater_core"])

    # CENTRAL — integração, instância única, tema e saúde da instalação.
    for fn in ("Start-EmbeddedModule", "Close-EmbeddedModule", "Sync-HostedModuleTheme", "Update-CentralAvailabilityState", "Start-UpdaterModule"):
        require_function(errors, central, fn, "Central")
    for marker in (
        "New-Module -Name $dynamicName",
        "$hostedForm.Dock = [Windows.Forms.DockStyle]::Fill",
        "Get-Variable -Name HostedControlExport",
        "CentralDeTrabalho_Central",
        "Componentes.Core.ps1",
        "Manutencao.Core.ps1",
        "NFEntrada.Core.ps1",
        "Update.Core.ps1",
        "CANAIS.json",
        '"Escuro profissional"',
        '"Técnico industrial"',
        '"Claro corporativo"',
        '"Alto contraste"',
    ):
        require(errors, central, marker, "Central")

    # GERENCIADOR — caminhos CB5/TV5, validações de lote e gravação segura.
    for fn in ("Update-ProductInterface", "Update-CombinedProductInterface", "Update-CombineSummary", "Move-CombinedGridRow"):
        require_function(errors, generator, fn, "Gerenciador")
    for marker in (
        'if ($selectedProduct -eq "TV5")',
        'Save-TV5Workbook $excel $combinedItems $temporaryPath',
        'Save-CB5CombinedWorkbook $excel $combinedItems $temporaryPath',
        'throw "As planilhas selecionadas não possuem a mesma NF.',
        'throw "O lote $($masterData.Lot) aparece em mais de uma planilha selecionada.',
        'throw "A SÉRIE $($item.Series) aparece em mais de um lote selecionado.',
        'throw "O ICCID1 $($item.Iccid1) aparece em mais de um lote selecionado.',
        'throw "O ICCID2 $($item.Iccid2) aparece em mais de um lote selecionado.',
        'Assert-GeneratedFile $temporaryPath',
        '$committedTransactions = [Collections.Generic.List[object]]::new()',
        'RollbackPath = $record.RollbackMasterPath',
        'Copy-Item -LiteralPath $transaction.RollbackPath -Destination $transaction.TargetPath -Force',
    ):
        require(errors, generator, marker, "Gerenciador")

    # JUNTAR LOTES — uma única mestre é uma entrada válida.
    # A exigência de duas planilhas não pode voltar silenciosamente.
    if 'combineGrid.Rows.Count -lt 2' in generator:
        errors.append("Gerenciador / Juntar lotes: voltou a exigir pelo menos duas planilhas")
    if generator.count('if ($combineGrid.Rows.Count -lt 1)') < 2:
        errors.append("Gerenciador / Juntar lotes: validação e geração não aceitam de forma consistente uma única planilha")
    require(errors, generator, 'Selecione uma ou mais mestres $Product.', "Gerenciador / Juntar lotes com uma mestre")
    require(errors, generator, 'Adicione uma ou mais planilhas mestre $Product para conferir ou juntar os lotes.', "Gerenciador / instrução de uma mestre")

    # Regra crítica pedida pelo usuário: texto REPARO livre só sem consumo de saldo.
    require(errors, generator, 'Read-TV5MasterWorkbook $excel $masterPath -AllowUnknownRepair:(-not $consumeBalance)', "Gerenciador / REPARO TV5")
    require(errors, generator, 'Read-MasterWorkbook $excel $masterPath -RequireInvoices -AllowUnknownRepair:(-not $consumeBalance)', "Gerenciador / REPARO CB5")
    require(errors, generator, 'Get-BillingDeductionPlan -Store $script:BillingComponentStore', "Gerenciador / saldo marcado")
    require(errors, generator, 'Get-BillingNoDeductionPlan -Store $script:BillingComponentStore', "Gerenciador / saldo desmarcado")
    require(errors, generator, '$deductionPlan.JaAplicada', "Gerenciador / idempotência de baixa")
    require(errors, generator, 'Get-BillingOperationKey', "Gerenciador / chave da união")

    # Componentes — cadastro, saldo, histórico e prevenção de baixa duplicada.
    for fn in (
        "Get-BillingDeductionPlan", "Get-BillingNoDeductionPlan", "Apply-BillingDeductionPlan",
        "Get-BillingOperationKey", "Read-BillingComponentStore", "Write-BillingComponentStore",
        "Copy-BillingComponentStore", "Add-BillingManualQuantity", "Set-BillingManualBalance",
        "Add-BillingComponent", "Update-BillingComponent",
    ):
        require_function(errors, components, fn, "Componentes.Core")
    for marker in (
        '$componentBackupButton.Add_Click',
        '$componentRestoreButton.Add_Click',
        'Write-BillingComponentStore -Store $workingStore',
        'Read-BillingComponentStore -Path $dialog.FileName',
    ):
        require(errors, generator, marker, "Gerenciador / Componentes")

    # MANUTENÇÃO — ciclo completo: criar, continuar, concluir, corrigir e registrar retorno.
    for fn in (
        "Save-CurrentPassage", "Start-ReturnFromRecord", "Load-PassageIntoForm",
        "Refresh-HistoryGrid", "Refresh-CurrentSeriesHistory", "Save-StoreSafely",
    ):
        require_function(errors, maintenance, fn, "Manutenção")
    for marker in (
        'Get-CB5ValidationResult -Values $values -ForCompletion $validationForCompletion',
        'Get-CB5OpenPassageBySerial -Store $script:Store -Serial',
        'New-CB5Passage -Store $script:Store -Values $values',
        'Update-CB5Passage -Store $script:Store -Id $script:CurrentPassageId',
        'Complete-CB5Passage -Store $script:Store -Id $script:CurrentPassageId',
        'Correct-CB5Passage -Store $script:Store -Id $script:CurrentPassageId',
        'A série e o número da passagem não mudam.',
        '$mainTabs.SelectedTab = $historyTab',
        '$diagnosisRunButton',
        '$schemaOpenButton',
        '$dashboardNewButton.Add_Click',
        '$dashboardHistoryButton.Add_Click',
        '$dashboardStatsButton.Add_Click',
        '$dashboardDiagnosisButton.Add_Click',
        '$dashboardSchematicsButton.Add_Click',
        '$dashboardRulesButton.Add_Click',
    ):
        require(errors, maintenance, marker, "Manutenção")

    # Núcleo da manutenção — contratos que sustentam a persistência e o histórico.
    for fn in (
        "Test-CB5Serial", "Get-CB5ValidationResult", "New-CB5Passage", "Update-CB5Passage",
        "Complete-CB5Passage", "Correct-CB5Passage", "Get-CB5OpenPassageBySerial",
        "Get-CB5PassageById", "Get-CB5PassagesBySerial", "Read-CB5Store",
    ):
        require_function(errors, maintenance_core, fn, "Manutencao.Core")
    require_regex(errors, maintenance_core, r"function\s+Test-CB5Serial\b.{0,1600}(\{8\}|Length\s+-e[q|n]\s+8|Length\s+-ne\s+8)", "Manutencao.Core / série exatamente 8 dígitos")

    # NF DE ENTRADA — terceiro módulo integrado, base local e exportação fiel ao modelo original.
    for marker in ('Controle de NF de Entrada', 'IMPORTAR PLANILHA', 'EXPORTAR EXCEL', 'COMPUTADOR DE BORDO V5', 'TECLADO V5', '$script:HostedControlExport', '[switch]$HostedInCentral'):
        require(errors, nf, marker, "NF Entrada")
    for fn in ("Initialize-NFEntradaDataStore", "Import-NFEntradaSourceWorkbook", "Read-NFEntradaStore", "Write-NFEntradaStore", "Ensure-NFEntradaStoreShape", "Add-NFEntradaHistoryEvent", "Get-NFEntradaHistory", "New-NFEntradaSafetyBackup", "Restore-NFEntradaSafetyBackup", "Get-NFEntradaRecordStatus", "Add-NFEntradaRecord", "Update-NFEntradaRecord", "Remove-NFEntradaRecord", "Get-NFEntradaSummary", "Export-NFEntradaWorkbook"):
        require_function(errors, nf_core, fn, "NFEntrada.Core")
    for marker in ('modelo-nf-entrada.xlsx', 'Range("A3:F298").ClearContents()', '$excel.Workbooks.Open($destinationFull, 0, $false)', '$excel.CalculateFullRebuild()'):
        require(errors, nf_core, marker, "NFEntrada.Core / exportação fiel")
    for marker in ('Historico = @()', 'Backups', 'BackupDirectory', '-Tipo "Adicao"', '-Tipo "Edicao"', '-Tipo "Exclusao"', '-Tipo "Importacao"'):
        require(errors, nf_core, marker, "NFEntrada.Core / histórico e segurança")
    for marker in ('Confirmar nova importação', 'backup da base e do modelo atuais', 'Set-NFStatus', '$editButton.Enabled = $hasSelection', '$deleteButton.Enabled = $hasSelection'):
        require(errors, nf, marker, "NF Entrada / operação segura")
    for marker in ('"Todos", "Em estoque", "Encerrada", "Revisar"', '"Todos", "800", "100", "850", "Garantia"', 'Add-NFGridColumn $grid "Status" "STATUS"', '$CountLabel.Text = "$shown de $($records.Count)"', 'EDITAR SELEÇÃO'):
        require(errors, nf, marker, "NF Entrada / clareza visual e filtros")

    # ATUALIZADOR — preserva núcleo, hash do pacote, arquivos ocultos e recuperação real.
    require(errors, updater, "Update.Core.ps1", "Atualizador")
    for marker in ("PackageSha256", "PackageSize", "PACOTE-MANIFESTO.json"):
        if marker not in updater and marker not in updater_core:
            errors.append(f"Atualizador: contrato ausente entre script e Core: {marker}")
    if not re.search(r"function\s+[A-Za-z0-9_-]+", updater_core, re.I):
        errors.append("Atualizador: Update.Core.ps1 não contém funções executáveis")

    for fn in (
        "Resolve-CentralUpdateInstallRootPath",
        "Assert-CentralUpdateInstallRoot",
        "Clear-CentralUpdateBlockingAttributes",
        "Restore-CentralUpdateBackup",
        "Install-CentralUpdatePayload",
    ):
        require_function(errors, updater_core, fn, "Atualizador / recuperação")
    for marker in (
        '([IO.FileInfo]::new($path)).Length',
        'Clear-CentralUpdateBlockingAttributes -Path $destination',
        '$InstallRoot = Resolve-CentralUpdateInstallRootPath -InstallRoot $InstallRoot',
        '$originalError = $_',
        '$rollbackError = $null',
    ):
        require(errors, updater_core, marker, "Atualizador / arquivos ocultos e rollback")
    if '(Get-Item -LiteralPath $path).Length' in updater_core:
        errors.append("Atualizador: validação do pacote voltou a depender de Get-Item, que falha com arquivo oculto")
    require(errors, updater, 'O Atualizador tentou restaurar o backup automaticamente.', "Atualizador / mensagem de recuperação")

    fail(errors)
    print("REGRESSÃO FUNCIONAL: OK — contratos de Central, Gerenciador, Componentes, Manutenção, NF Entrada e Atualizador preservados.")


if __name__ == "__main__":
    main()
