from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CENTRAL = ROOT / "generated" / "Central de Trabalho.ps1"


def read(path):
    return path.read_text(encoding="utf-8-sig")


def write(path, text):
    path.write_text(text, encoding="utf-8-sig")


def replace_once(text, old, new, label):
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: esperado 1 trecho, encontrado {count}")
    return text.replace(old, new, 1)


central = read(CENTRAL)
central = replace_once(central, '$script:AppVersion = "0.16.3"', '$script:AppVersion = "0.16.4"', 'versao Central')

# Registra os arquivos estruturais que cada área realmente precisa para funcionar.
central = replace_once(
    central,
    '$script:GeneratorScript = [IO.Path]::Combine($script:GeneratorDirectory, "Gerador Planilhas.ps1")',
    '$script:GeneratorScript = [IO.Path]::Combine($script:GeneratorDirectory, "Gerador Planilhas.ps1")\n$script:GeneratorCore = [IO.Path]::Combine($script:GeneratorDirectory, "Componentes.Core.ps1")',
    'core do Gerenciador'
)
central = replace_once(
    central,
    '$script:MaintenanceScript = [IO.Path]::Combine($script:MaintenanceDirectory, "Central Manutencao CB5.ps1")',
    '$script:MaintenanceScript = [IO.Path]::Combine($script:MaintenanceDirectory, "Central Manutencao CB5.ps1")\n$script:MaintenanceCore = [IO.Path]::Combine($script:MaintenanceDirectory, "Manutencao.Core.ps1")',
    'core da Manutencao'
)
central = replace_once(
    central,
    '$script:UpdaterScript = [IO.Path]::Combine($script:UpdaterDirectory, "Central de Trabalho Updater.ps1")',
    '$script:UpdaterScript = [IO.Path]::Combine($script:UpdaterDirectory, "Central de Trabalho Updater.ps1")\n$script:UpdaterCore = [IO.Path]::Combine($script:UpdaterDirectory, "Update.Core.ps1")\n$script:UpdaterChannels = [IO.Path]::Combine($script:UpdaterDirectory, "CANAIS.json")',
    'arquivos do Atualizador'
)

# Uma única leitura descreve a integridade real da instalação.
health_helper = r'''
function Get-CentralHealthSnapshot {
    $generatorRequired = @($script:GeneratorScript, $script:GeneratorCore)
    $maintenanceRequired = @($script:MaintenanceScript, $script:MaintenanceCore)
    $updaterRequired = @($script:UpdaterScript, $script:UpdaterCore, $script:UpdaterChannels)

    $generatorMissing = @($generatorRequired | Where-Object { -not [IO.File]::Exists($_) })
    $maintenanceMissing = @($maintenanceRequired | Where-Object { -not [IO.File]::Exists($_) })
    $updaterMissing = @($updaterRequired | Where-Object { -not [IO.File]::Exists($_) })

    [pscustomobject]@{
        GeneratorAvailable = ($generatorMissing.Count -eq 0)
        MaintenanceAvailable = ($maintenanceMissing.Count -eq 0)
        UpdaterAvailable = ($updaterMissing.Count -eq 0)
        GeneratorMissing = $generatorMissing
        MaintenanceMissing = $maintenanceMissing
        UpdaterMissing = $updaterMissing
    }
}

function Format-MissingCentralFiles {
    param([object[]]$Paths)
    if ($null -eq $Paths -or $Paths.Count -eq 0) { return "" }
    return (($Paths | ForEach-Object { "• " + [IO.Path]::GetFileName([string]$_) }) -join "`r`n")
}

'''
marker = '# Integração real dos módulos na própria árvore WinForms da Central.\n'
if central.count(marker) != 1:
    raise RuntimeError('marcador da integracao nao localizado de forma unica')
central = central.replace(marker, health_helper + marker, 1)

# Antes de abrir um módulo, verifica também seu arquivo Core, não apenas o script principal.
old_module_guard = r'''    if (-not [IO.File]::Exists($moduleScript)) {
        Set-StatusMessage "Não foi possível abrir: arquivo do módulo ausente." "Error"
        [Windows.Forms.MessageBox]::Show(
            "O arquivo de $moduleName não foi encontrado.`r`n`r`n$moduleScript",
            "Central de Trabalho",
            [Windows.Forms.MessageBoxButtons]::OK,
            [Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
        return
    }
'''
new_module_guard = r'''    $health = Get-CentralHealthSnapshot
    $moduleAvailable = if ($Module -eq "Generator") { $health.GeneratorAvailable } else { $health.MaintenanceAvailable }
    $moduleMissing = if ($Module -eq "Generator") { @($health.GeneratorMissing) } else { @($health.MaintenanceMissing) }
    if (-not $moduleAvailable) {
        $missingText = Format-MissingCentralFiles $moduleMissing
        Set-StatusMessage "Não foi possível abrir: instalação do módulo incompleta." "Error"
        [Windows.Forms.MessageBox]::Show(
            "A instalação de $moduleName está incompleta.`r`n`r`nArquivos necessários que não foram encontrados:`r`n$missingText`r`n`r`nUse Atualizações para reparar ou reinstalar a versão atual.",
            "Central de Trabalho",
            [Windows.Forms.MessageBoxButtons]::OK,
            [Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
        return
    }
'''
central = replace_once(central, old_module_guard, new_module_guard, 'guarda de integridade dos modulos')

# O Atualizador também precisa de Core + configuração de canais.
old_updater_guard = r'''    if (-not [IO.File]::Exists($script:UpdaterScript)) {
        Set-StatusMessage "Não foi possível abrir: arquivo do Atualizador ausente." "Error"
        [Windows.Forms.MessageBox]::Show(
            "O arquivo do Atualizador não foi encontrado.`r`n`r`n$($script:UpdaterScript)",
            "Central de Trabalho",
            [Windows.Forms.MessageBoxButtons]::OK,
            [Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
        return
    }
'''
new_updater_guard = r'''    $health = Get-CentralHealthSnapshot
    if (-not $health.UpdaterAvailable) {
        $missingText = Format-MissingCentralFiles @($health.UpdaterMissing)
        Set-StatusMessage "Não foi possível abrir: instalação do Atualizador incompleta." "Error"
        [Windows.Forms.MessageBox]::Show(
            "A instalação do Atualizador está incompleta.`r`n`r`nArquivos necessários que não foram encontrados:`r`n$missingText",
            "Central de Trabalho",
            [Windows.Forms.MessageBoxButtons]::OK,
            [Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
        return
    }
'''
central = replace_once(central, old_updater_guard, new_updater_guard, 'guarda de integridade do Atualizador')

# A saúde exibida nos cartões e na lateral passa a considerar o conjunto completo.
old_health_head = r'''        $generatorAvailable = [IO.File]::Exists($script:GeneratorScript)
        $maintenanceAvailable = [IO.File]::Exists($script:MaintenanceScript)
        $updaterAvailable = [IO.File]::Exists($script:UpdaterScript)
        $generatorFolderAvailable = [IO.Directory]::Exists($script:GeneratorDirectory)
        $maintenanceFolderAvailable = [IO.Directory]::Exists($script:MaintenanceDirectory)
        $moduleCount = ([int]$generatorAvailable + [int]$maintenanceAvailable)'''
new_health_head = r'''        $health = Get-CentralHealthSnapshot
        $generatorAvailable = [bool]$health.GeneratorAvailable
        $maintenanceAvailable = [bool]$health.MaintenanceAvailable
        $updaterAvailable = [bool]$health.UpdaterAvailable
        $generatorFolderAvailable = [IO.Directory]::Exists($script:GeneratorDirectory)
        $maintenanceFolderAvailable = [IO.Directory]::Exists($script:MaintenanceDirectory)
        $moduleCount = ([int]$generatorAvailable + [int]$maintenanceAvailable)'''
central = replace_once(central, old_health_head, new_health_head, 'cabecalho da saude')

# Diferencia instalação incompleta de módulo totalmente ausente.
old_generator_status = r'''        if ($null -ne $generatorStatus) {
            $generatorStatus.Text = if ($generatorAvailable) { "  DISPONÍVEL  " } else { "  INDISPONÍVEL  " }
            $generatorStatus.BackColor = if ($generatorAvailable) { $script:CurrentPalette.SuccessBack } else { $script:CurrentPalette.PlannedBack }
            $generatorStatus.ForeColor = if ($generatorAvailable) { $script:CurrentPalette.Success } else { $script:CurrentPalette.Planned }
        }
        if ($null -ne $maintenanceStatus) {
            $maintenanceStatus.Text = if ($maintenanceAvailable) { "  DISPONÍVEL  " } else { "  INDISPONÍVEL  " }
            $maintenanceStatus.BackColor = if ($maintenanceAvailable) { $script:CurrentPalette.SuccessBack } else { $script:CurrentPalette.PlannedBack }
            $maintenanceStatus.ForeColor = if ($maintenanceAvailable) { $script:CurrentPalette.Success } else { $script:CurrentPalette.Planned }
        }'''
new_generator_status = r'''        if ($null -ne $generatorStatus) {
            $generatorStatus.Text = if ($generatorAvailable) { "  DISPONÍVEL  " } elseif ($generatorFolderAvailable) { "  INCOMPLETO  " } else { "  INDISPONÍVEL  " }
            $generatorStatus.BackColor = if ($generatorAvailable) { $script:CurrentPalette.SuccessBack } else { $script:CurrentPalette.PlannedBack }
            $generatorStatus.ForeColor = if ($generatorAvailable) { $script:CurrentPalette.Success } else { $script:CurrentPalette.Planned }
        }
        if ($null -ne $maintenanceStatus) {
            $maintenanceStatus.Text = if ($maintenanceAvailable) { "  DISPONÍVEL  " } elseif ($maintenanceFolderAvailable) { "  INCOMPLETO  " } else { "  INDISPONÍVEL  " }
            $maintenanceStatus.BackColor = if ($maintenanceAvailable) { $script:CurrentPalette.SuccessBack } else { $script:CurrentPalette.PlannedBack }
            $maintenanceStatus.ForeColor = if ($maintenanceAvailable) { $script:CurrentPalette.Success } else { $script:CurrentPalette.Planned }
        }'''
central = replace_once(central, old_generator_status, new_generator_status, 'status detalhado dos modulos')

# A assinatura inclui os arquivos faltantes para refletir imediatamente qualquer reparo parcial.
old_signature = '$signature = "$generatorAvailable|$maintenanceAvailable|$updaterAvailable|$generatorFolderAvailable|$maintenanceFolderAvailable|$($script:ModuleLoading)"'
new_signature = '$signature = "$generatorAvailable|$maintenanceAvailable|$updaterAvailable|$generatorFolderAvailable|$maintenanceFolderAvailable|$(@($health.GeneratorMissing).Count)|$(@($health.MaintenanceMissing).Count)|$(@($health.UpdaterMissing).Count)|$($script:ModuleLoading)"'
central = replace_once(central, old_signature, new_signature, 'assinatura de integridade')

write(CENTRAL, central)
