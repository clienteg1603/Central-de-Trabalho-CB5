from pathlib import Path

ROOT = Path('.')
UI = ROOT / 'src/generated/Modulos/Controle-NF-Entrada/Controle NF Entrada.ps1'
CENTRAL = ROOT / 'src/generated/Central de Trabalho.ps1'


def read(path):
    return path.read_text(encoding='utf-8-sig')


def write(path, text):
    path.write_text(text, encoding='utf-8')


def rep(text, old, new, label):
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'Etapa 12: marcador inesperado em {label}: {count}')
    return text.replace(old, new, 1)


ui = read(UI)
central = read(CENTRAL)

if '$script:ModuleVersion = "2.3.0"' in ui:
    raise SystemExit('Etapa 12 já aplicada; abortando para evitar duplicação.')

ui = rep(
    ui,
    '$script:ModuleVersion = "2.2.0"',
    '$script:ModuleVersion = "2.3.0"',
    'versão do módulo'
)

csv_helpers = r'''function ConvertTo-NFCsvField {
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
        Set-NFStatus ("Falha ao exportar $Title: " + $_.Exception.Message) "Error"
        [Windows.Forms.MessageBox]::Show($_.Exception.Message, "Falha ao exportar CSV", 0, 16) | Out-Null
    }
    finally {
        $dialog.Dispose()
    }
}

'''
ui = rep(
    ui,
    'function Get-NFHistoryEventById {',
    csv_helpers + 'function Get-NFHistoryEventById {',
    'funções de exportação CSV'
)

old_movement_footer = '''$movementFooter=New-Object Windows.Forms.TableLayoutPanel
$movementFooter.Dock=[Windows.Forms.DockStyle]::Fill; $movementFooter.ColumnCount=3
[void]$movementFooter.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent,100)))
[void]$movementFooter.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::AutoSize)))
[void]$movementFooter.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::AutoSize)))
$movementCountLabel=New-Object Windows.Forms.Label
$movementCountLabel.Text="0 movimentação(ões)"; $movementCountLabel.Dock=[Windows.Forms.DockStyle]::Fill; $movementCountLabel.TextAlign=[Drawing.ContentAlignment]::MiddleLeft; $movementCountLabel.ForeColor=$script:CurrentPalette.Muted
$movementFooter.Controls.Add($movementCountLabel,0,0)
$movementOpenButton=New-Object Windows.Forms.Button
$movementOpenButton.Text="ABRIR NF"; $movementOpenButton.Width=110; $movementOpenButton.Height=32; $movementOpenButton.Enabled=$false; Set-NFButtonStyle $movementOpenButton "Secondary"
$movementFooter.Controls.Add($movementOpenButton,1,0)
$movementReverseButton=New-Object Windows.Forms.Button
$movementReverseButton.Text="ESTORNAR SAÍDA"; $movementReverseButton.Width=135; $movementReverseButton.Height=32; $movementReverseButton.Enabled=$false; Set-NFButtonStyle $movementReverseButton "Danger"
$movementFooter.Controls.Add($movementReverseButton,2,0)
$movementLayout.Controls.Add($movementFooter,0,2)'''
new_movement_footer = '''$movementFooter=New-Object Windows.Forms.TableLayoutPanel
$movementFooter.Dock=[Windows.Forms.DockStyle]::Fill; $movementFooter.ColumnCount=4
[void]$movementFooter.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent,100)))
[void]$movementFooter.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::AutoSize)))
[void]$movementFooter.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::AutoSize)))
[void]$movementFooter.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::AutoSize)))
$movementCountLabel=New-Object Windows.Forms.Label
$movementCountLabel.Text="0 movimentação(ões)"; $movementCountLabel.Dock=[Windows.Forms.DockStyle]::Fill; $movementCountLabel.TextAlign=[Drawing.ContentAlignment]::MiddleLeft; $movementCountLabel.ForeColor=$script:CurrentPalette.Muted
$movementFooter.Controls.Add($movementCountLabel,0,0)
$movementExportButton=New-Object Windows.Forms.Button
$movementExportButton.Text="EXPORTAR CSV"; $movementExportButton.Width=115; $movementExportButton.Height=32; Set-NFButtonStyle $movementExportButton "Secondary"
$movementFooter.Controls.Add($movementExportButton,1,0)
$movementOpenButton=New-Object Windows.Forms.Button
$movementOpenButton.Text="ABRIR NF"; $movementOpenButton.Width=110; $movementOpenButton.Height=32; $movementOpenButton.Enabled=$false; Set-NFButtonStyle $movementOpenButton "Secondary"
$movementFooter.Controls.Add($movementOpenButton,2,0)
$movementReverseButton=New-Object Windows.Forms.Button
$movementReverseButton.Text="ESTORNAR SAÍDA"; $movementReverseButton.Width=135; $movementReverseButton.Height=32; $movementReverseButton.Enabled=$false; Set-NFButtonStyle $movementReverseButton "Danger"
$movementFooter.Controls.Add($movementReverseButton,3,0)
$movementLayout.Controls.Add($movementFooter,0,2)'''
ui = rep(ui, old_movement_footer, new_movement_footer, 'botão exportar movimentações')

old_history_footer = '''$historyButtons = New-Object Windows.Forms.FlowLayoutPanel
$historyButtons.Dock = [Windows.Forms.DockStyle]::Fill; $historyButtons.FlowDirection = [Windows.Forms.FlowDirection]::RightToLeft
$historyDetailsButton = New-Object Windows.Forms.Button
$historyDetailsButton.Text = "VER DETALHES"; $historyDetailsButton.Width = 125; $historyDetailsButton.Height = 32; $historyDetailsButton.Enabled = $false; Set-NFButtonStyle $historyDetailsButton "Secondary"
$historyButtons.Controls.Add($historyDetailsButton); $historyLayout.Controls.Add($historyButtons, 0, 2)'''
new_history_footer = '''$historyButtons = New-Object Windows.Forms.FlowLayoutPanel
$historyButtons.Dock = [Windows.Forms.DockStyle]::Fill; $historyButtons.FlowDirection = [Windows.Forms.FlowDirection]::RightToLeft
$historyDetailsButton = New-Object Windows.Forms.Button
$historyDetailsButton.Text = "VER DETALHES"; $historyDetailsButton.Width = 125; $historyDetailsButton.Height = 32; $historyDetailsButton.Enabled = $false; Set-NFButtonStyle $historyDetailsButton "Secondary"
$historyExportButton = New-Object Windows.Forms.Button
$historyExportButton.Text = "EXPORTAR CSV"; $historyExportButton.Width = 115; $historyExportButton.Height = 32; Set-NFButtonStyle $historyExportButton "Secondary"
$historyButtons.Controls.Add($historyDetailsButton); $historyButtons.Controls.Add($historyExportButton); $historyLayout.Controls.Add($historyButtons, 0, 2)'''
ui = rep(ui, old_history_footer, new_history_footer, 'botão exportar histórico')

ui = rep(
    ui,
    '$toolTip.SetToolTip($movementReverseButton, "Estorna a saída ativa sem apagar a movimentação original (Ctrl+Z).")\n$toolTip.SetToolTip($integrityButton, "Audita base, duplicidades, pendências, modelo Excel, backups e arquivos temporários.")',
    '$toolTip.SetToolTip($movementReverseButton, "Estorna a saída ativa sem apagar a movimentação original (Ctrl+Z).")\n$toolTip.SetToolTip($movementExportButton, "Exporta somente as movimentações visíveis com os filtros atuais para CSV compatível com Excel.")\n$toolTip.SetToolTip($historyExportButton, "Exporta somente os eventos visíveis do Histórico para CSV compatível com Excel.")\n$toolTip.SetToolTip($integrityButton, "Audita base, duplicidades, pendências, modelo Excel, backups e arquivos temporários.")',
    'dicas dos botões de exportação'
)

ui = rep(
    ui,
    '$movementOpenButton.Add_Click({ Open-NFFromMovement })\n$movementReverseButton.Add_Click({ Reverse-NFMovementFromUI })',
    '$movementExportButton.Add_Click({ Export-NFGridViewToCsv -Grid $movementGrid -BaseName "Movimentacoes-NF-Entrada" -Title "Movimentações" })\n$movementOpenButton.Add_Click({ Open-NFFromMovement })\n$movementReverseButton.Add_Click({ Reverse-NFMovementFromUI })',
    'evento exportar movimentações'
)

ui = rep(
    ui,
    '$historyDetailsButton.Add_Click({ Show-NFHistoryDetails })',
    '$historyExportButton.Add_Click({ Export-NFGridViewToCsv -Grid $historyGrid -BaseName "Historico-NF-Entrada" -Title "Histórico" })\n$historyDetailsButton.Add_Click({ Show-NFHistoryDetails })',
    'evento exportar histórico'
)

central = rep(
    central,
    '$script:AppVersion = "0.21.14"',
    '$script:AppVersion = "0.21.15"',
    'versão da Central'
)
central = rep(
    central,
    '$script:NFEntradaVersion = "2.2.0"',
    '$script:NFEntradaVersion = "2.3.0"',
    'versão NF Entrada na Central'
)

required_ui = [
    '$script:ModuleVersion = "2.3.0"',
    'function Export-NFGridViewToCsv',
    '$movementExportButton.Text="EXPORTAR CSV"',
    '$historyExportButton.Text = "EXPORTAR CSV"',
    'Movimentacoes-NF-Entrada',
    'Historico-NF-Entrada',
    'UTF8Encoding($true)',
    'Foram exportadas apenas as linhas que estão visíveis com os filtros atuais.'
]
for marker in required_ui:
    if marker not in ui:
        raise SystemExit(f'Etapa 12: marcador final ausente na UI: {marker}')
if '$script:AppVersion = "0.21.15"' not in central or '$script:NFEntradaVersion = "2.3.0"' not in central:
    raise SystemExit('Etapa 12: versões finais não foram aplicadas na Central.')

write(UI, ui)
write(CENTRAL, central)
print('ETAPA 12: OK - exportação filtrada de Movimentações e Histórico para CSV adicionada; Central 0.21.15 / NF Entrada 2.3.0.')
