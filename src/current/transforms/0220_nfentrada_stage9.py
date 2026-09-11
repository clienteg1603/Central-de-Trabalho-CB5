from pathlib import Path
import subprocess

ROOT = Path('.')
CORE = ROOT / 'src/generated/Modulos/Controle-NF-Entrada/NFEntrada.Core.ps1'
UI = ROOT / 'src/generated/Modulos/Controle-NF-Entrada/Controle NF Entrada.ps1'
CENTRAL = ROOT / 'src/generated/Central de Trabalho.ps1'
TEST = ROOT / 'src/ci/test_nfentrada_stage9.ps1'


def read(path):
    return path.read_text(encoding='utf-8-sig')


def write(path, text):
    path.write_text(text, encoding='utf-8')


def rep(text, old, new, label):
    if text.count(old) != 1:
        raise SystemExit(f'Etapa 9: marcador inesperado em {label}: {text.count(old)}')
    return text.replace(old, new, 1)


core = read(CORE)
ui = read(UI)
central = read(CENTRAL)
if 'function Register-NFEntradaReversal' in core:
    raise SystemExit('Etapa 9 já aplicada ao núcleo; abortando para evitar duplicação.')

# Núcleo: compatibilidade, estado da movimentação e estorno auditável.
old = '''    elseif ($null -eq $Store.Movimentacoes) {
        $Store.Movimentacoes = @()
    }
    if ($null -eq $Store.PSObject.Properties["Meta"]) {'''
new = '''    elseif ($null -eq $Store.Movimentacoes) {
        $Store.Movimentacoes = @()
    }
    foreach ($movement in @($Store.Movimentacoes)) {
        if ($null -eq $movement.PSObject.Properties["Estornada"]) { $movement | Add-Member -NotePropertyName Estornada -NotePropertyValue $false }
        if ($null -eq $movement.PSObject.Properties["EstornadaEm"]) { $movement | Add-Member -NotePropertyName EstornadaEm -NotePropertyValue "" }
        if ($null -eq $movement.PSObject.Properties["MotivoEstorno"]) { $movement | Add-Member -NotePropertyName MotivoEstorno -NotePropertyValue "" }
        if ($null -eq $movement.PSObject.Properties["EstornoSaldoAntes"]) { $movement | Add-Member -NotePropertyName EstornoSaldoAntes -NotePropertyValue 0 }
        if ($null -eq $movement.PSObject.Properties["EstornoSaldoDepois"]) { $movement | Add-Member -NotePropertyName EstornoSaldoDepois -NotePropertyValue 0 }
    }
    if ($null -eq $Store.PSObject.Properties["Meta"]) {'''
core = rep(core, old, new, 'migração de movimentações')

old = '''        SaldoAntes = $SaldoAntes
        SaldoDepois = $SaldoDepois
        Origem = "Operação"
    }'''
new = '''        SaldoAntes = $SaldoAntes
        SaldoDepois = $SaldoDepois
        Origem = "Operação"
        Estornada = $false
        EstornadaEm = ""
        MotivoEstorno = ""
        EstornoSaldoAntes = 0
        EstornoSaldoDepois = 0
    }'''
core = rep(core, old, new, 'campos da movimentação')

functions = r'''function Get-NFEntradaMovementById {
    param([Parameter(Mandatory = $true)]$Store,[Parameter(Mandatory = $true)][string]$MovementId)
    [void](Ensure-NFEntradaStoreShape -Store $Store)
    foreach ($movement in @($Store.Movimentacoes)) {
        if ([string]::Equals([string]$movement.Id, $MovementId, [StringComparison]::OrdinalIgnoreCase)) { return $movement }
    }
    return $null
}

function Get-NFEntradaMovementStatus {
    param([Parameter(Mandatory = $true)]$Movement)
    if ($null -ne $Movement.PSObject.Properties["Estornada"] -and [bool]$Movement.Estornada) { return "Estornada" }
    return "Ativa"
}

function Register-NFEntradaReversal {
    param(
        [Parameter(Mandatory = $true)]$Store,
        [Parameter(Mandatory = $true)][string]$MovementId,
        [Parameter(Mandatory = $true)][string]$Motivo
    )
    [void](Ensure-NFEntradaStoreShape -Store $Store)
    $reason = ConvertTo-NFEntradaText $Motivo
    if ([string]::IsNullOrWhiteSpace($reason)) { throw "Informe o motivo do estorno." }
    $movement = Get-NFEntradaMovementById -Store $Store -MovementId $MovementId
    if ($null -eq $movement) { throw "A movimentação selecionada não foi encontrada." }
    if ((Get-NFEntradaMovementStatus -Movement $movement) -eq "Estornada") { throw "Esta saída já foi estornada." }

    $product = ConvertTo-NFEntradaText $movement.Produto
    $records = @(Get-NFEntradaProductRecords -Store $Store -Product $product)
    $target = $null
    foreach ($record in $records) {
        if ([int]$record.Id -eq [int]$movement.RegistroId -and [string]::Equals((ConvertTo-NFEntradaText $record.NFEntrada), (ConvertTo-NFEntradaText $movement.NFEntrada), [StringComparison]::OrdinalIgnoreCase)) { $target = $record; break }
    }
    if ($null -eq $target) {
        foreach ($record in $records) {
            if ([string]::Equals((ConvertTo-NFEntradaText $record.NFEntrada), (ConvertTo-NFEntradaText $movement.NFEntrada), [StringComparison]::OrdinalIgnoreCase)) { $target = $record; break }
        }
    }
    if ($null -eq $target) { throw "A NF original desta saída não existe mais na base ativa. O estorno foi bloqueado para não alterar outro registro por engano." }

    $quantity = [int]$movement.Quantidade
    if ($quantity -le 0) { throw "A movimentação possui quantidade inválida e não pode ser estornada automaticamente." }
    $currentBalance = [int]$target.QuantidadeSaldo
    $newBalance = $currentBalance + $quantity
    if ($newBalance -gt [int]$target.QuantidadeNaNF) { throw "O estorno elevaria o saldo acima da quantidade original da NF. Revise a NF antes de estornar." }

    $before = Copy-NFEntradaRecordSnapshot $target
    $target.QuantidadeSaldo = $newBalance
    $after = Copy-NFEntradaRecordSnapshot $target
    $movement.Estornada = $true
    $movement.EstornadaEm = [DateTime]::Now.ToString("o")
    $movement.MotivoEstorno = $reason
    $movement.EstornoSaldoAntes = $currentBalance
    $movement.EstornoSaldoDepois = $newBalance
    $Store.Produtos.PSObject.Properties[$product].Value = @($records)
    [void](Add-NFEntradaHistoryEvent -Store $Store -Tipo "EstornoSaida" -Produto $product -RegistroId ([int]$target.Id) -NFEntrada ([string]$target.NFEntrada) -Antes $before -Depois $after -Detalhes ("Estorno de " + $quantity + " peça(s) • movimento " + [string]$movement.Id + " • motivo: " + $reason))
    return [pscustomobject]@{ Movement = $movement; Record = $after }
}

'''
core = rep(core, 'function Get-NFEntradaReviewItems {', functions + 'function Get-NFEntradaReviewItems {', 'funções de estorno')
core = rep(core, '    $piecesTotal = 0\n    $lastDate', '    $piecesTotal = 0\n    $activeMovements = 0\n    $lastDate', 'contador ativo')
core = rep(core, '    foreach ($movement in $movements) {\n        $piecesTotal += [int]$movement.Quantidade', '    foreach ($movement in $movements) {\n        if ((Get-NFEntradaMovementStatus -Movement $movement) -eq "Estornada") { continue }\n        $activeMovements++\n        $piecesTotal += [int]$movement.Quantidade', 'métricas líquidas')
core = rep(core, '        MovimentacoesTotal = $movements.Count', '        MovimentacoesTotal = $activeMovements', 'total líquido')

# Interface: status das movimentações, botão de estorno e histórico.
ui = rep(ui, '$script:ModuleVersion = "1.9.0"', '$script:ModuleVersion = "2.0.0"', 'versão da UI')
ui = rep(ui, '    $qtyShown = 0\n    $today = [DateTime]::Today', '    $qtyShown = 0\n    $reversedShown = 0\n    $today = [DateTime]::Today', 'contador visual')
ui = rep(ui, '        $displayProduct = Get-NFEntradaProductDisplayName ([string]$item.Produto)\n        if ($productFilter -ne "Todos" -and $displayProduct -ne $productFilter) { continue }\n        $search = (($displayProduct + " " + [string]$item.NFEntrada + " " + [string]$item.Referencia)).ToLowerInvariant()', '        $displayProduct = Get-NFEntradaProductDisplayName ([string]$item.Produto)\n        if ($productFilter -ne "Todos" -and $displayProduct -ne $productFilter) { continue }\n        $status = Get-NFEntradaMovementStatus -Movement $item\n        $search = (($displayProduct + " " + [string]$item.NFEntrada + " " + [string]$item.Referencia + " " + $status + " " + [string]$item.MotivoEstorno)).ToLowerInvariant()', 'status na pesquisa')
ui = rep(ui, '        [void]$movementGrid.Rows.Add(\n            [string]$item.Id,', '        $rowIndex = $movementGrid.Rows.Add(\n            [string]$item.Id,', 'índice da linha')
ui = rep(ui, '            [int]$item.SaldoDepois,\n            [string]$item.Referencia\n        )\n        $shown++\n        $qtyShown += [int]$item.Quantidade', '            [int]$item.SaldoDepois,\n            $status,\n            [string]$item.Referencia\n        )\n        $shown++\n        if ($status -eq "Estornada") {\n            $reversedShown++\n            $row = $movementGrid.Rows[$rowIndex]\n            $row.DefaultCellStyle.BackColor = $script:CurrentPalette.DangerBack\n            $row.DefaultCellStyle.ForeColor = $script:CurrentPalette.Danger\n        } else { $qtyShown += [int]$item.Quantidade }', 'linha estornada')
ui = rep(ui, '    $movementCountLabel.Text = "$shown movimentação(ões) • $qtyShown peça(s) • período: $periodFilter"', '    $movementCountLabel.Text = "$shown movimentação(ões) • $qtyShown peça(s) ativas • $reversedShown estornada(s) • período: $periodFilter • Ctrl+Z estorna a selecionada"', 'rodapé das movimentações')
ui = rep(ui, '    $movementOpenButton.Enabled = $false\n}', '    $movementOpenButton.Enabled = $false\n    if ($null -ne $movementReverseButton) { $movementReverseButton.Enabled = $false }\n}', 'reset de ações')

reverse_ui = r'''function Reverse-NFMovementFromUI {
    if ($movementGrid.SelectedRows.Count -eq 0) { return }
    $id = [string]$movementGrid.SelectedRows[0].Cells["MovementId"].Value
    $movement = Get-NFEntradaMovementById -Store $script:Store -MovementId $id
    if ($null -eq $movement) { return }
    if ((Get-NFEntradaMovementStatus -Movement $movement) -eq "Estornada") {
        [Windows.Forms.MessageBox]::Show("Esta saída já foi estornada e continua visível para auditoria.", "Controle de NF de Entrada", 0, 64) | Out-Null
        return
    }
    $answer = [Windows.Forms.MessageBox]::Show(
        "Estornar a saída de $([int]$movement.Quantidade) peça(s) da NF $([string]$movement.NFEntrada)?`r`n`r`nA quantidade voltará para o saldo. A movimentação original não será apagada e o estorno ficará registrado no Histórico.",
        "Confirmar estorno de saída",
        [Windows.Forms.MessageBoxButtons]::YesNo,
        [Windows.Forms.MessageBoxIcon]::Warning
    )
    if ($answer -ne [Windows.Forms.DialogResult]::Yes) { return }
    try {
        $result = Register-NFEntradaReversal -Store $script:Store -MovementId $id -Motivo "Correção operacional"
        Save-NFStore
        Refresh-NFAll
        Refresh-NFMovements
        Set-NFStatus ("Saída estornada. Saldo da NF " + [string]$result.Record.NFEntrada + ": " + [string]$result.Record.QuantidadeSaldo) "Warning"
    }
    catch { Set-NFStatus $_.Exception.Message "Error"; [Windows.Forms.MessageBox]::Show($_.Exception.Message, "Falha ao estornar saída", 0, 16) | Out-Null }
}

'''
ui = rep(ui, 'function Get-NFHistoryEventById {', reverse_ui + 'function Get-NFHistoryEventById {', 'ação de estorno')
ui = rep(ui, '            "Saida" { "Saída" }\n            "Exportacao"', '            "Saida" { "Saída" }\n            "EstornoSaida" { "Estorno de saída" }\n            "Exportacao"', 'rótulo no histórico')
ui = rep(ui, '[void]$historyTypeFilter.Items.AddRange(@("Todos", "Adição", "Edição", "Saída", "Exclusão", "Importação", "Restauração", "Exportação"))', '[void]$historyTypeFilter.Items.AddRange(@("Todos", "Adição", "Edição", "Saída", "Estorno de saída", "Exclusão", "Importação", "Restauração", "Exportação"))', 'filtro do histórico')
ui = rep(ui, 'Add-NFGridColumn $movementGrid "MovementAfter" "SALDO DEPOIS" 100\nAdd-NFGridColumn $movementGrid "MovementReference"', 'Add-NFGridColumn $movementGrid "MovementAfter" "SALDO DEPOIS" 100\nAdd-NFGridColumn $movementGrid "MovementStatus" "STATUS" 90\nAdd-NFGridColumn $movementGrid "MovementReference"', 'coluna status')

old_footer = '''$movementFooter=New-Object Windows.Forms.TableLayoutPanel
$movementFooter.Dock=[Windows.Forms.DockStyle]::Fill; $movementFooter.ColumnCount=2
[void]$movementFooter.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent,100)))
[void]$movementFooter.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::AutoSize)))
$movementCountLabel=New-Object Windows.Forms.Label
$movementCountLabel.Text="0 movimentação(ões)"; $movementCountLabel.Dock=[Windows.Forms.DockStyle]::Fill; $movementCountLabel.TextAlign=[Drawing.ContentAlignment]::MiddleLeft; $movementCountLabel.ForeColor=$script:CurrentPalette.Muted
$movementFooter.Controls.Add($movementCountLabel,0,0)
$movementOpenButton=New-Object Windows.Forms.Button
$movementOpenButton.Text="ABRIR NF"; $movementOpenButton.Width=110; $movementOpenButton.Height=32; $movementOpenButton.Enabled=$false; Set-NFButtonStyle $movementOpenButton "Secondary"
$movementFooter.Controls.Add($movementOpenButton,1,0)
$movementLayout.Controls.Add($movementFooter,0,2)'''
new_footer = '''$movementFooter=New-Object Windows.Forms.TableLayoutPanel
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
ui = rep(ui, old_footer, new_footer, 'botão de estorno')

ui = rep(ui, '$movementGrid.Add_SelectionChanged({ $movementOpenButton.Enabled = ($movementGrid.SelectedRows.Count -gt 0) })', '$movementGrid.Add_SelectionChanged({\n    $movementOpenButton.Enabled = ($movementGrid.SelectedRows.Count -gt 0)\n    $movementReverseButton.Enabled = ($movementGrid.SelectedRows.Count -gt 0 -and [string]$movementGrid.SelectedRows[0].Cells["MovementStatus"].Value -eq "Ativa")\n})', 'seleção de movimentação')
ui = rep(ui, '$movementGrid.Add_CellDoubleClick({ if ($_.RowIndex -ge 0) { Open-NFFromMovement } })\n$movementOpenButton.Add_Click({ Open-NFFromMovement })', '$movementGrid.Add_CellDoubleClick({ if ($_.RowIndex -ge 0) { Open-NFFromMovement } })\n$movementGrid.Add_KeyDown({ if ($_.Control -and $_.KeyCode -eq [Windows.Forms.Keys]::Z) { $_.SuppressKeyPress=$true; Reverse-NFMovementFromUI } })\n$movementOpenButton.Add_Click({ Open-NFFromMovement })\n$movementReverseButton.Add_Click({ Reverse-NFMovementFromUI })', 'eventos de estorno')

central = rep(central, '$script:AppVersion = "0.21.10"', '$script:AppVersion = "0.21.11"', 'versão da Central')
central = rep(central, '$script:NFEntradaVersion = "1.9.0"', '$script:NFEntradaVersion = "2.0.0"', 'versão NF na Central')

write(CORE, core)
write(UI, ui)
write(CENTRAL, central)

subprocess.run(['pwsh','-NoProfile','-NonInteractive','-File',str(TEST),'-CorePath',str(CORE)], check=True)
print('ETAPA 9 NF ENTRADA: OK - estorno seguro aplicado e testado.')
