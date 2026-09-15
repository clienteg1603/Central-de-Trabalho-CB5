from pathlib import Path

central_path = Path('src/generated/Central de Trabalho.ps1')
nf_path = Path('src/generated/Modulos/Controle-NF-Entrada/Controle NF Entrada.ps1')
core_path = Path('src/generated/Modulos/Controle-NF-Entrada/NFEntrada.Core.ps1')

central = central_path.read_text(encoding='utf-8-sig')
nf = nf_path.read_text(encoding='utf-8-sig')
core = core_path.read_text(encoding='utf-8-sig')


def one(text, old, new, label):
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'NF OUTPUT V0222 {label}: esperado 1, encontrado {count}')
    return text.replace(old, new, 1)


# Versões: hotfix funcional do Controle de NF, preservando os demais módulos.
central = one(central, '$script:AppVersion = "0.22.1"', '$script:AppVersion = "0.22.2"', 'versao Central')
central = one(central, '$script:NFEntradaVersion = "2.6.26"', '$script:NFEntradaVersion = "2.6.27"', 'versao NF na Central')
nf = one(nf, '$script:ModuleVersion = "2.6.26"', '$script:ModuleVersion = "2.6.27"', 'versao NF')


# ---------------------------------------------------------------------------
# NÚCLEO — uma saída deixa de gravar somente a referência crua (ex.: 2327).
# O texto persistido passa a seguir o padrão visual da planilha histórica:
#     (49 PÇS NF 2327)
# Movimentacoes continua guardando Quantidade e Referencia separadamente.
# ---------------------------------------------------------------------------
register_anchor = '''function Register-NFEntradaOutput {
    param('''
helpers = r'''function Format-NFEntradaOutputMovementText {
    param(
        [Parameter(Mandatory = $true)][int]$Quantidade,
        [Parameter(Mandatory = $true)][string]$Referencia
    )
    $reference = ConvertTo-NFEntradaText $Referencia
    if ([string]::IsNullOrWhiteSpace($reference)) { return "" }
    # Se a pessoa já digitar "NF 2327", evita "NF NF 2327".
    if ($reference -match '^(?i:NF)\s+(.+)$') { $reference = $matches[1].Trim() }
    return "(" + $Quantidade + " PÇS NF " + $reference + ")"
}

function Get-NFEntradaOutputDisplayText {
    param(
        [Parameter(Mandatory = $true)]$Store,
        [Parameter(Mandatory = $true)][string]$Product,
        [Parameter(Mandatory = $true)]$Record
    )
    if ($null -eq $Record) { return "" }
    $stored = ConvertTo-NFEntradaText $Record.NFSaida
    if ([string]::IsNullOrWhiteSpace($stored)) { return "" }

    # Compatibilidade com saídas registradas pelas versões 2.6.25/2.6.26:
    # nessas versões o registro recebeu somente a referência (ex.: 2327), mas
    # Movimentacoes já contém quantidade=49 e referencia=2327. Substituímos a
    # linha crua apenas na apresentação/exportação, sem alterar a base antiga.
    $lines = [Collections.Generic.List[string]]::new()
    foreach ($line in @([regex]::Split($stored, '\r?\n'))) {
        $item = ([string]$line).Trim()
        if (-not [string]::IsNullOrWhiteSpace($item)) { [void]$lines.Add($item) }
    }

    $active = @(Get-NFEntradaMovements -Store $Store | Where-Object {
        [string]::Equals((ConvertTo-NFEntradaText $_.Produto), (ConvertTo-NFEntradaText $Product), [StringComparison]::OrdinalIgnoreCase) -and
        [int]$_.RegistroId -eq [int]$Record.Id -and
        (Get-NFEntradaMovementStatus -Movement $_) -eq "Ativa"
    })

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = [string]$lines[$i]
        # Textos que já estão no formato histórico não são tocados.
        if ($line -match '^\(\s*\d+\s+PÇS\s+NF\s+.+\)$') { continue }
        foreach ($movement in $active) {
            $rawReference = ConvertTo-NFEntradaText $movement.Referencia
            if ([string]::Equals($line, $rawReference, [StringComparison]::OrdinalIgnoreCase)) {
                $lines[$i] = Format-NFEntradaOutputMovementText -Quantidade ([int]$movement.Quantidade) -Referencia $rawReference
                break
            }
        }
    }

    # Uma única linha é mais legível na grade e preserva o padrão com "+" para
    # NFs que tiveram mais de uma saída.
    return (@($lines) -join " + ")
}

'''
core = one(core, register_anchor, helpers + register_anchor, 'helpers de saida')

old_store = '''        $existing.QuantidadeSaldo = $saldoAtual - $Quantidade
        $atual = ConvertTo-NFEntradaText $existing.NFSaida
        $existing.NFSaida = if ([string]::IsNullOrWhiteSpace($atual)) { $saida } else { $atual + [Environment]::NewLine + $saida }
        $after = Copy-NFEntradaRecordSnapshot $existing'''
new_store = '''        $existing.QuantidadeSaldo = $saldoAtual - $Quantidade
        $atual = ConvertTo-NFEntradaText $existing.NFSaida
        $movementText = Format-NFEntradaOutputMovementText -Quantidade $Quantidade -Referencia $saida
        $existing.NFSaida = if ([string]::IsNullOrWhiteSpace($atual)) { $movementText } else { $atual + " + " + $movementText }
        $after = Copy-NFEntradaRecordSnapshot $existing'''
core = one(core, old_store, new_store, 'persistencia formatada da saida')

core = one(
    core,
    '$sheet.Cells.Item($rowNumber, 6).Value2 = [string]$record.NFSaida',
    '$sheet.Cells.Item($rowNumber, 6).Value2 = Get-NFEntradaOutputDisplayText -Store $Store -Product ([string]$p.Name) -Record $record',
    'exportacao Excel formatada'
)


# ---------------------------------------------------------------------------
# GRADE — usa a apresentação calculada. Isso corrige imediatamente registros
# feitos na v0.22.0/v0.22.1 que já possuem a movimentação estruturada, mas cujo
# campo NFSaida ficou apenas como "2327".
# ---------------------------------------------------------------------------
old_grid = '''        $status = Get-NFEntradaRecordStatus -Record $record
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
        )'''
new_grid = '''        $status = Get-NFEntradaRecordStatus -Record $record
        if ($selectedStatus -ne "Todos" -and $status -ne $selectedStatus) { continue }
        if ($selectedCode -ne "Todos" -and ([string]$record.Codigo) -ne $selectedCode) { continue }
        $outputDisplay = Get-NFEntradaOutputDisplayText -Store $script:Store -Product $Product -Record $record
        $search = (([string]$record.NFEntrada) + " " + ([string]$record.Codigo) + " " + $outputDisplay + " " + (Format-NFDate ([string]$record.Data)) + " " + $status).ToLowerInvariant()
        if (-not [string]::IsNullOrWhiteSpace($filter) -and -not $search.Contains($filter)) { continue }
        $index = $Grid.Rows.Add(
            [int]$record.Id,
            (Format-NFDate ([string]$record.Data)),
            [int]$record.QuantidadeNaNF,
            [string]$record.NFEntrada,
            [int]$record.QuantidadeSaldo,
            [string]$record.Codigo,
            $status,
            $outputDisplay
        )'''
nf = one(nf, old_grid, new_grid, 'grade de produto')


# ---------------------------------------------------------------------------
# MODAL DE SAÍDA — layout alinhado, campos sem Dock=Fill vertical e aparência
# coerente com o Técnico industrial.
# ---------------------------------------------------------------------------
old_dialog = '''    $dialog = New-Object Windows.Forms.Form
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
    $dialog.AcceptButton=$save; $dialog.CancelButton=$cancel'''

new_dialog = '''    $dialog = New-Object Windows.Forms.Form
    $dialog.Text = "Registrar saída — NF $($record.NFEntrada)"
    $dialog.StartPosition = [Windows.Forms.FormStartPosition]::CenterParent
    $dialog.FormBorderStyle = [Windows.Forms.FormBorderStyle]::FixedDialog
    $dialog.MaximizeBox = $false
    $dialog.MinimizeBox = $false
    $dialog.ShowInTaskbar = $false
    $dialog.AutoScaleMode = [Windows.Forms.AutoScaleMode]::Dpi
    $dialog.Font = [Drawing.Font]::new("Segoe UI", 9)
    $dialog.ClientSize = [Drawing.Size]::new(620, 306)
    $dialog.BackColor = $script:CurrentPalette.Background
    $dialog.ForeColor = $script:CurrentPalette.Text

    $layout = New-Object Windows.Forms.TableLayoutPanel
    $layout.Dock = [Windows.Forms.DockStyle]::Fill
    $layout.Padding = [Windows.Forms.Padding]::new(24, 18, 24, 18)
    $layout.Margin = [Windows.Forms.Padding]::new(0)
    $layout.ColumnCount = 2
    $layout.RowCount = 5
    [void]$layout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Absolute, 176)))
    [void]$layout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 100)))
    foreach ($height in @(50, 50, 50, 64, 56)) {
        [void]$layout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, $height)))
    }
    $dialog.Controls.Add($layout)

    function Add-OutputLabel([string]$text, [int]$row) {
        $label = New-Object Windows.Forms.Label
        $label.Text = $text
        $label.Dock = [Windows.Forms.DockStyle]::Fill
        $label.Margin = [Windows.Forms.Padding]::new(0)
        $label.TextAlign = [Drawing.ContentAlignment]::MiddleLeft
        $label.ForeColor = $script:CurrentPalette.Text
        $layout.Controls.Add($label, 0, $row)
    }

    Add-OutputLabel "Saldo atual" 0
    $current = New-Object Windows.Forms.Label
    $current.Text = [string]$saldoAtual
    $current.Dock = [Windows.Forms.DockStyle]::Fill
    $current.Margin = [Windows.Forms.Padding]::new(8, 0, 0, 0)
    $current.TextAlign = [Drawing.ContentAlignment]::MiddleLeft
    $current.ForeColor = $script:CurrentPalette.Text
    $current.Font = [Drawing.Font]::new("Segoe UI Semibold", 9)
    $layout.Controls.Add($current, 1, 0)

    Add-OutputLabel "Quantidade da saída" 1
    $qty = New-Object Windows.Forms.NumericUpDown
    $qty.Minimum = 1
    $qty.Maximum = $saldoAtual
    $qty.Value = 1
    $qty.Anchor = [Windows.Forms.AnchorStyles]::Left -bor [Windows.Forms.AnchorStyles]::Right
    $qty.Margin = [Windows.Forms.Padding]::new(8, 12, 0, 10)
    $qty.BackColor = $script:CurrentPalette.Input
    $qty.ForeColor = $script:CurrentPalette.Text
    $layout.Controls.Add($qty, 1, 1)

    Add-OutputLabel "Saldo após saída" 2
    $after = New-Object Windows.Forms.Label
    $after.Text = [string]($saldoAtual - 1)
    $after.Dock = [Windows.Forms.DockStyle]::Fill
    $after.Margin = [Windows.Forms.Padding]::new(8, 0, 0, 0)
    $after.TextAlign = [Drawing.ContentAlignment]::MiddleLeft
    $after.ForeColor = $script:CurrentPalette.Accent
    $after.Font = [Drawing.Font]::new("Segoe UI Semibold", 9)
    $layout.Controls.Add($after, 1, 2)

    Add-OutputLabel "NF de saída / referência" 3
    $refBox = New-Object Windows.Forms.TextBox
    $refBox.MaxLength = 120
    $refBox.Anchor = [Windows.Forms.AnchorStyles]::Left -bor [Windows.Forms.AnchorStyles]::Right
    $refBox.Margin = [Windows.Forms.Padding]::new(8, 18, 0, 16)
    $refBox.BackColor = $script:CurrentPalette.Input
    $refBox.ForeColor = $script:CurrentPalette.Text
    $refBox.BorderStyle = [Windows.Forms.BorderStyle]::FixedSingle
    $layout.Controls.Add($refBox, 1, 3)

    $qty.Add_ValueChanged({ $after.Text = [string]($saldoAtual - [int]$qty.Value) })

    $buttons = New-Object Windows.Forms.FlowLayoutPanel
    $buttons.Dock = [Windows.Forms.DockStyle]::Fill
    $buttons.FlowDirection = [Windows.Forms.FlowDirection]::RightToLeft
    $buttons.WrapContents = $false
    $buttons.Padding = [Windows.Forms.Padding]::new(0, 10, 0, 0)
    $buttons.Margin = [Windows.Forms.Padding]::new(0)
    $layout.SetColumnSpan($buttons, 2)
    $layout.Controls.Add($buttons, 0, 4)

    $cancel = New-Object Windows.Forms.Button
    $cancel.Text = "CANCELAR"
    $cancel.Width = 112
    $cancel.Height = 36
    $cancel.Margin = [Windows.Forms.Padding]::new(8, 0, 0, 0)
    $cancel.DialogResult = [Windows.Forms.DialogResult]::Cancel
    Set-NFButtonStyle $cancel "Secondary"
    $buttons.Controls.Add($cancel)

    $save = New-Object Windows.Forms.Button
    $save.Text = "REGISTRAR SAÍDA"
    $save.Width = 144
    $save.Height = 36
    $save.Margin = [Windows.Forms.Padding]::new(8, 0, 0, 0)
    $save.DialogResult = [Windows.Forms.DialogResult]::OK
    Set-NFButtonStyle $save "Primary"
    $buttons.Controls.Add($save)

    $dialog.AcceptButton = $save
    $dialog.CancelButton = $cancel'''
nf = one(nf, old_dialog, new_dialog, 'layout do modal de saida')

core += '''
# NF_OUTPUT_FORMATTED_MOVEMENT_V02627
'''
nf += '''
# NF_OUTPUT_DIALOG_ALIGNED_V02627
'''
central += '''
# CENTRAL_NF_OUTPUT_HOTFIX_V0222
'''

for marker in (
    '$script:AppVersion = "0.22.2"',
    '$script:NFEntradaVersion = "2.6.27"',
    'CENTRAL_RESTORE_LIVE_HOST_REDRAW_STAGE3_V02169',
    'CENTRAL_NF_EDIT_HOTFIX_V0221',
    'CENTRAL_NF_OUTPUT_HOTFIX_V0222',
):
    if marker not in central:
        raise SystemExit('NF OUTPUT V0222 Central marcador ausente: ' + marker)

for marker in (
    '$script:ModuleVersion = "2.6.27"',
    '$outputDisplay = Get-NFEntradaOutputDisplayText',
    '$dialog.ClientSize = [Drawing.Size]::new(620, 306)',
    '$qty.Anchor = [Windows.Forms.AnchorStyles]::Left -bor [Windows.Forms.AnchorStyles]::Right',
    '$refBox.Anchor = [Windows.Forms.AnchorStyles]::Left -bor [Windows.Forms.AnchorStyles]::Right',
    'NF_OUTPUT_DIALOG_ALIGNED_V02627',
):
    if marker not in nf:
        raise SystemExit('NF OUTPUT V0222 UI marcador ausente: ' + marker)

for marker in (
    'function Format-NFEntradaOutputMovementText',
    'function Get-NFEntradaOutputDisplayText',
    'PÇS NF',
    '$movementText = Format-NFEntradaOutputMovementText',
    'Get-NFEntradaOutputDisplayText -Store $Store -Product ([string]$p.Name)',
    'NF_OUTPUT_FORMATTED_MOVEMENT_V02627',
):
    if marker not in core:
        raise SystemExit('NF OUTPUT V0222 Core marcador ausente: ' + marker)

central_path.write_text(central, encoding='utf-8')
nf_path.write_text(nf, encoding='utf-8')
core_path.write_text(core, encoding='utf-8')
print('NF OUTPUT V0222: OK - saida formatada, compatibilidade com registros crus, Excel e modal alinhado.')
