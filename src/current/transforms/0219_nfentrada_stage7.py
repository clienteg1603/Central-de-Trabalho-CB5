#!/usr/bin/env python3
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parents[2]
CORE = ROOT / "generated/Modulos/Controle-NF-Entrada/NFEntrada.Core.ps1"
UI = ROOT / "generated/Modulos/Controle-NF-Entrada/Controle NF Entrada.ps1"
CENTRAL = ROOT / "generated/Central de Trabalho.ps1"


def read(path):
    return path.read_text(encoding="utf-8-sig")


def write(path, text):
    path.write_text(text, encoding="utf-8")


def replace_once(text, old, new, label):
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: esperado 1 marcador, encontrado {count}")
    return text.replace(old, new, 1)


core = read(CORE)
ui = read(UI)
central = read(CENTRAL)

if "function Get-NFEntradaExportReadiness" in core or "CONFERIR EXPORTAÇÃO" in ui:
    raise SystemExit("Etapa 7 já parece aplicada; transformação recusada para evitar duplicação.")

core_insert = '''function Get-NFEntradaExportReadiness {
    param(
        [Parameter(Mandatory = $true)]$Store,
        [string]$DataDirectory = (Get-NFEntradaDefaultDataDirectory)
    )
    [void](Ensure-NFEntradaStoreShape -Store $Store)
    $capacity = 296
    $computerCount = @(Get-NFEntradaProductRecords -Store $Store -Product "COMPUTADOR DE BORDO V5").Count
    $keyboardCount = @(Get-NFEntradaProductRecords -Store $Store -Product "TECLADO V5").Count
    $computerExcess = [Math]::Max(0, $computerCount - $capacity)
    $keyboardExcess = [Math]::Max(0, $keyboardCount - $capacity)
    $review = @(Get-NFEntradaReviewItems -Store $Store)
    $templatePath = Get-NFEntradaTemplatePath -DataDirectory $DataDirectory
    $templateReady = [IO.File]::Exists($templatePath) -and ([IO.FileInfo]::new($templatePath)).Length -gt 0
    $blocked = (-not $templateReady) -or (($computerExcess + $keyboardExcess) -gt 0)
    $situation = if ($blocked) { "BLOQUEADO" } elseif ($review.Count -gt 0) { "REVISAR" } else { "PRONTO" }
    return [pscustomobject]@{
        ModeloDisponivel = $templateReady
        CapacidadePorProduto = $capacity
        RegistrosComputador = $computerCount
        RegistrosTeclado = $keyboardCount
        RestanteComputador = [Math]::Max(0, $capacity - $computerCount)
        RestanteTeclado = [Math]::Max(0, $capacity - $keyboardCount)
        ExcessoComputador = $computerExcess
        ExcessoTeclado = $keyboardExcess
        Pendencias = $review.Count
        PodeExportar = (-not $blocked)
        Situacao = $situation
    }
}

function Get-NFEntradaLastExport {
    param([Parameter(Mandatory = $true)]$Store)
    foreach ($event in @(Get-NFEntradaHistory -Store $Store)) {
        if ([string]$event.Tipo -eq "Exportacao") { return $event }
    }
    return $null
}

'''
core = replace_once(core, "function New-NFEntradaSafetyBackup {", core_insert + "function New-NFEntradaSafetyBackup {", "core / conferência de exportação")

ui = replace_once(ui, '$script:ModuleVersion = "1.7.0"', '$script:ModuleVersion = "1.8.0"', "UI / versão")
ui = replace_once(ui, '            "RestauracaoBackup" { "Restauração" }\n            "Saida" { "Saída" }', '            "RestauracaoBackup" { "Restauração" }\n            "Saida" { "Saída" }\n            "Exportacao" { "Exportação" }', "UI / histórico")
ui = replace_once(ui, '[void]$historyTypeFilter.Items.AddRange(@("Todos", "Adição", "Edição", "Saída", "Exclusão", "Importação", "Restauração"))', '[void]$historyTypeFilter.Items.AddRange(@("Todos", "Adição", "Edição", "Saída", "Exclusão", "Importação", "Restauração", "Exportação"))', "UI / filtro histórico")
ui = replace_once(ui, 'function Refresh-NFSummary {\n    $summary = Get-NFEntradaSummary -Store $script:Store\n    $operational = Get-NFEntradaOperationalMetrics -Store $script:Store', 'function Refresh-NFSummary {\n    $summary = Get-NFEntradaSummary -Store $script:Store\n    $operational = Get-NFEntradaOperationalMetrics -Store $script:Store\n    $exportState = Get-NFEntradaExportReadiness -Store $script:Store -DataDirectory $script:DataDirectory', "UI / resumo")
ui = replace_once(ui, '    $reviewIssuesValue.ForeColor = if ([int]$operational.Pendencias -eq 0) { $script:CurrentPalette.Success } else { $script:CurrentPalette.Danger }', '    $reviewIssuesValue.ForeColor = if ([int]$operational.Pendencias -eq 0) { $script:CurrentPalette.Success } else { $script:CurrentPalette.Danger }\n    $exportStatusValue.Text = [string]$exportState.Situacao\n    $exportStatusValue.ForeColor = if ($exportState.Situacao -eq "PRONTO") { $script:CurrentPalette.Success } elseif ($exportState.Situacao -eq "REVISAR") { $script:CurrentPalette.Warning } else { $script:CurrentPalette.Danger }', "UI / status exportação")
ui = replace_once(ui, '$conference.ColumnCount = 2\n$conference.RowCount = 5', '$conference.ColumnCount = 2\n$conference.RowCount = 6', "UI / linhas conferência")
ui = replace_once(ui, '$reviewIssuesValue = New-Object Windows.Forms.Label\n$generalStatusValue = New-Object Windows.Forms.Label', '$reviewIssuesValue = New-Object Windows.Forms.Label\n$exportStatusValue = New-Object Windows.Forms.Label\n$generalStatusValue = New-Object Windows.Forms.Label', "UI / label exportação")
ui = replace_once(ui, '    @("Pendências para revisar", $reviewIssuesValue),\n    @("Situação geral", $generalStatusValue)', '    @("Pendências para revisar", $reviewIssuesValue),\n    @("Exportação Excel", $exportStatusValue),\n    @("Situação geral", $generalStatusValue)', "UI / linha exportação")

pattern = re.compile(r'\$reviewIssuesButton = New-Object Windows\.Forms\.Button\n\$reviewIssuesButton\.Text = "VER PENDÊNCIAS"\n\$reviewIssuesButton\.Dock = \[Windows\.Forms\.DockStyle\]::Fill\n\$reviewIssuesButton\.Margin = \[Windows\.Forms\.Padding\]::new\(8, 18, 6, 18\)\nSet-NFButtonStyle \$reviewIssuesButton "Secondary"\n\$activityLayout\.Controls\.Add\(\$reviewIssuesButton, 4, 0\)')
replacement = '''$summaryActionPanel = New-Object Windows.Forms.FlowLayoutPanel
$summaryActionPanel.Dock = [Windows.Forms.DockStyle]::Fill
$summaryActionPanel.FlowDirection = [Windows.Forms.FlowDirection]::TopDown
$summaryActionPanel.WrapContents = $false
$summaryActionPanel.Padding = [Windows.Forms.Padding]::new(4, 7, 4, 4)
$summaryActionPanel.BackColor = $script:CurrentPalette.Card
$reviewIssuesButton = New-Object Windows.Forms.Button
$reviewIssuesButton.Text = "VER PENDÊNCIAS"
$reviewIssuesButton.Width = 145
$reviewIssuesButton.Height = 32
$reviewIssuesButton.Margin = [Windows.Forms.Padding]::new(2, 2, 2, 5)
Set-NFButtonStyle $reviewIssuesButton "Secondary"
$exportCheckButton = New-Object Windows.Forms.Button
$exportCheckButton.Text = "CONFERIR EXPORTAÇÃO"
$exportCheckButton.Width = 145
$exportCheckButton.Height = 32
$exportCheckButton.Margin = [Windows.Forms.Padding]::new(2)
Set-NFButtonStyle $exportCheckButton "Secondary"
$summaryActionPanel.Controls.Add($reviewIssuesButton)
$summaryActionPanel.Controls.Add($exportCheckButton)
$activityLayout.Controls.Add($summaryActionPanel, 4, 0)'''
ui, n = pattern.subn(replacement, ui, count=1)
if n != 1:
    raise SystemExit(f"UI / ações do resumo: esperado 1 bloco, encontrado {n}")

show_export = '''function Show-NFExportReadiness {
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

'''
ui = replace_once(ui, "function Refresh-NFBackups {", show_export + "function Refresh-NFBackups {", "UI / diálogo conferir exportação")

preflight = '''function Export-NFFromUI {
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
'''
ui = replace_once(ui, "function Export-NFFromUI {\n", preflight, "UI / pré-conferência")
ui = replace_once(ui, '        $exported = Export-NFEntradaWorkbook -Store $script:Store -DestinationPath $path\n        Set-NFStatus "Planilha exportada com sucesso." "Success"', '        $exported = Export-NFEntradaWorkbook -Store $script:Store -DestinationPath $path\n        $exportSummary = Get-NFEntradaSummary -Store $script:Store\n        $exportDetails = "Arquivo: " + [IO.Path]::GetFileName($exported) + " • CB5: " + [string]$exportSummary.Produtos[$script:ComputerProduct].Registros + " registro(s) • Teclado: " + [string]$exportSummary.Produtos[$script:KeyboardProduct].Registros + " registro(s) • Pendências: " + [string]$readiness.Pendencias\n        [void](Add-NFEntradaHistoryEvent -Store $script:Store -Tipo "Exportacao" -Detalhes $exportDetails)\n        Save-NFStore\n        Refresh-NFAll\n        Set-NFStatus "Planilha exportada com sucesso e registrada no histórico." "Success"', "UI / auditoria exportação")
ui = replace_once(ui, '    $templateReady = [IO.File]::Exists((Get-NFEntradaTemplatePath -DataDirectory $script:DataDirectory))\n    $exportButton.Enabled = $templateReady', '    $exportReadiness = Get-NFEntradaExportReadiness -Store $script:Store -DataDirectory $script:DataDirectory\n    $exportButton.Enabled = [bool]$exportReadiness.PodeExportar', "UI / botão exportar")
ui = replace_once(ui, '$reviewIssuesButton.Add_Click({ Show-NFReviewIssues })', '$reviewIssuesButton.Add_Click({ Show-NFReviewIssues })\n$exportCheckButton.Add_Click({ Show-NFExportReadiness })', "UI / clique conferir exportação")

central = replace_once(central, '$script:AppVersion = "0.21.8"', '$script:AppVersion = "0.21.9"', "Central / versão")
central = replace_once(central, '$script:NFEntradaVersion = "1.7.0"', '$script:NFEntradaVersion = "1.8.0"', "Central / versão NF Entrada")

write(CORE, core)
write(UI, ui)
write(CENTRAL, central)
print("TRANSFORM ETAPA 7: OK — exportação pré-conferida, auditável e protegida sem alterar o modelo oficial.")
