param(
    [Parameter(Mandatory = $true)][string]$GeneratedRoot
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$modulePath = Join-Path $GeneratedRoot 'Modulos\Controle-NF-Entrada\Controle NF Entrada.ps1'
if (-not (Test-Path -LiteralPath $modulePath -PathType Leaf)) {
    throw "Controle de NF ausente: $modulePath"
}

$tempRoot = if ([string]::IsNullOrWhiteSpace($env:RUNNER_TEMP)) { [IO.Path]::GetTempPath() } else { $env:RUNNER_TEMP }
$dataRoot = Join-Path $tempRoot ('nf-output-dialog-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $dataRoot | Out-Null
$previousRuntimeTest = $env:CENTRAL_THEME_RUNTIME_TEST
$previousDataRoot = $env:CENTRAL_THEME_TEST_DATA_ROOT
$env:CENTRAL_THEME_RUNTIME_TEST = '1'
$env:CENTRAL_THEME_TEST_DATA_ROOT = $dataRoot

$moduleInfo = $null
$hostForm = $null
$hostedControl = $null
try {
    $hostContext = [pscustomobject]@{
        Theme = 'Técnico industrial'
        Revision = 0
        LayoutRestoreActive = $false
    }

    $moduleInfo = New-Module -Name ('NFOutputDialog_' + [Guid]::NewGuid().ToString('N')) -ArgumentList @($modulePath, $hostContext) -ScriptBlock {
        param($scriptPath, $context)
        . $scriptPath -HostedInCentral -HostTheme ([string]$context.Theme) -HostThemeContext $context
    }
    if ($null -eq $moduleInfo) { throw 'Falha ao criar módulo isolado do Controle de NF.' }

    $hostedControl = & $moduleInfo {
        $v = Get-Variable -Name HostedControlExport -Scope Script -ErrorAction SilentlyContinue
        if ($null -ne $v) { return $v.Value }
        return $null
    }
    if ($null -eq $hostedControl -or -not ($hostedControl -is [Windows.Forms.Control])) {
        throw 'Controle de NF não exportou um controle hospedável.'
    }

    $hostForm = New-Object Windows.Forms.Form
    $hostForm.Size = [Drawing.Size]::new(1400, 850)
    $hostForm.StartPosition = [Windows.Forms.FormStartPosition]::Manual
    $hostForm.Location = [Drawing.Point]::new(-2400, -2400)
    $hostForm.ShowInTaskbar = $false
    $hostedControl.Dock = [Windows.Forms.DockStyle]::Fill
    $hostForm.Controls.Add($hostedControl)
    $hostForm.Show()
    $hostedControl.Visible = $true
    $hostedControl.PerformLayout()
    [Windows.Forms.Application]::DoEvents()

    $result = & $moduleInfo {
        $script:Store = New-EmptyNFEntradaStore
        $seed = [pscustomobject]@{
            Data = '2026-09-15'
            QuantidadeNaNF = 55
            NFEntrada = '692226'
            QuantidadeSaldo = 55
            Codigo = '800'
            NFSaida = ''
        }
        $created = Add-NFEntradaRecord -Store $script:Store -Product $script:ComputerProduct -Record $seed
        Refresh-NFAll
        $mainTabs.SelectedTab = $computerTab
        Refresh-NFProductGrid -Product $script:ComputerProduct -Grid $computerGrid -FilterBox $computerFilter -StatusFilter $computerStatusFilter -CodeFilter $computerCodeFilter -CountLabel $computerCountLabel
        [void](Select-NFRecordInGrid -Grid $computerGrid -Id ([int]$created.Id))
        Update-NFActions
        [Windows.Forms.Application]::DoEvents()

        if (-not $outputButton.Enabled) { throw 'SAÍDA não ficou habilitado para o registro de teste.' }

        $state = [pscustomobject]@{
            Opened = $false
            GeometryOk = $false
            Error = ''
        }
        $timer = New-Object Windows.Forms.Timer
        $timer.Interval = 300
        $timer.Add_Tick({
            try {
                foreach ($openForm in @([Windows.Forms.Application]::OpenForms)) {
                    if ($null -eq $openForm -or $openForm.IsDisposed) { continue }
                    if ([string]$openForm.Text -notlike 'Registrar saída*') { continue }

                    $state.Opened = $true
                    $layout = @($openForm.Controls | Where-Object { $_ -is [Windows.Forms.TableLayoutPanel] } | Select-Object -First 1)
                    if ($layout.Count -ne 1) { throw 'TableLayoutPanel do modal de saída não encontrado.' }
                    $qtyControl = @($layout[0].Controls | Where-Object { $_ -is [Windows.Forms.NumericUpDown] } | Select-Object -First 1)
                    $refControl = @($layout[0].Controls | Where-Object { $_ -is [Windows.Forms.TextBox] } | Select-Object -First 1)
                    $buttonPanel = @($layout[0].Controls | Where-Object { $_ -is [Windows.Forms.FlowLayoutPanel] } | Select-Object -First 1)
                    if ($qtyControl.Count -ne 1 -or $refControl.Count -ne 1 -or $buttonPanel.Count -ne 1) {
                        throw 'Controles principais do modal de saída não encontrados.'
                    }

                    $buttons = @($buttonPanel[0].Controls | Where-Object { $_ -is [Windows.Forms.Button] })
                    $saveButton = @($buttons | Where-Object { [string]$_.Text -eq 'REGISTRAR SAÍDA' } | Select-Object -First 1)
                    $cancelButton = @($buttons | Where-Object { [string]$_.Text -eq 'CANCELAR' } | Select-Object -First 1)
                    if ($saveButton.Count -ne 1 -or $cancelButton.Count -ne 1) { throw 'Botões do modal de saída não encontrados.' }

                    $alignedFields = ([Math]::Abs($qtyControl[0].Left - $refControl[0].Left) -le 2) -and ([Math]::Abs($qtyControl[0].Width - $refControl[0].Width) -le 2)
                    $orderedRows = $qtyControl[0].Top -lt $refControl[0].Top
                    $alignedButtons = [Math]::Abs($saveButton[0].Top - $cancelButton[0].Top) -le 2
                    $sanePadding = ($layout[0].Padding.Left -ge 20 -and $layout[0].Padding.Right -ge 20)
                    $state.GeometryOk = ($alignedFields -and $orderedRows -and $alignedButtons -and $sanePadding)
                    if (-not $state.GeometryOk) {
                        throw "Geometria desalinhada: qty=$($qtyControl[0].Bounds), ref=$($refControl[0].Bounds), save=$($saveButton[0].Bounds), cancel=$($cancelButton[0].Bounds), padding=$($layout[0].Padding)"
                    }

                    $qtyControl[0].Value = 49
                    $refControl[0].Text = '2327'
                    $openForm.DialogResult = [Windows.Forms.DialogResult]::OK
                    $openForm.Close()
                    break
                }
            }
            catch {
                $state.Error = $_.Exception.Message
                foreach ($openForm in @([Windows.Forms.Application]::OpenForms)) {
                    if ($null -ne $openForm -and -not $openForm.IsDisposed -and [string]$openForm.Text -like 'Registrar saída*') {
                        $openForm.DialogResult = [Windows.Forms.DialogResult]::Cancel
                        $openForm.Close()
                    }
                }
            }
        }.GetNewClosure())

        try {
            $timer.Start()
            Register-NFOutputFromUI
        }
        finally {
            $timer.Stop()
            $timer.Dispose()
        }

        if (-not [string]::IsNullOrWhiteSpace([string]$state.Error)) { throw $state.Error }
        if (-not $state.Opened) { throw 'A janela real de SAÍDA não chegou a abrir.' }
        if (-not $state.GeometryOk) { throw 'A janela real de SAÍDA abriu, mas a geometria não foi aprovada.' }

        $updated = Find-NFRecordById -Product $script:ComputerProduct -Id ([int]$created.Id)
        if ($null -eq $updated) { throw 'Registro desapareceu após registrar a saída.' }
        if ([int]$updated.QuantidadeSaldo -ne 6) { throw "Saldo esperado 6, recebido $($updated.QuantidadeSaldo)." }

        $expected = '(49 PÇS NF 2327)'
        if ([string]$updated.NFSaida -ne $expected) {
            throw "NFSaida persistida incorreta. Esperado '$expected', recebido '$([string]$updated.NFSaida)'."
        }
        $display = Get-NFEntradaOutputDisplayText -Store $script:Store -Product $script:ComputerProduct -Record $updated
        if ([string]$display -ne $expected) {
            throw "Texto de saída calculado incorreto. Esperado '$expected', recebido '$display'."
        }

        Refresh-NFProductGrid -Product $script:ComputerProduct -Grid $computerGrid -FilterBox $computerFilter -StatusFilter $computerStatusFilter -CodeFilter $computerCodeFilter -CountLabel $computerCountLabel
        [void](Select-NFRecordInGrid -Grid $computerGrid -Id ([int]$created.Id))
        $gridText = [string]$computerGrid.SelectedRows[0].Cells['NFSaida'].Value
        if ($gridText -ne $expected) {
            throw "Grade exibiu '$gridText' em vez de '$expected'."
        }

        $movements = @(Get-NFEntradaMovements -Store $script:Store | Where-Object { [int]$_.RegistroId -eq [int]$created.Id -and (Get-NFEntradaMovementStatus -Movement $_) -eq 'Ativa' })
        if ($movements.Count -ne 1 -or [int]$movements[0].Quantidade -ne 49 -or [string]$movements[0].Referencia -ne '2327') {
            throw 'Movimentação estruturada não preservou quantidade 49 e referência 2327.'
        }

        # Compatibilidade com o bug já gravado pelas versões anteriores: campo
        # cru "9999" + movimento estruturado de 7 peças deve aparecer formatado
        # sem exigir migração destrutiva da base.
        $legacy = [pscustomobject]@{
            Id = 999
            Ordem = 999
            Data = '2026-09-15'
            QuantidadeNaNF = 20
            NFEntrada = 'LEGACY-OUTPUT'
            QuantidadeSaldo = 13
            Codigo = '800'
            NFSaida = '9999'
        }
        $script:Store.Produtos.PSObject.Properties[$script:ComputerProduct].Value = @($script:Store.Produtos.PSObject.Properties[$script:ComputerProduct].Value) + $legacy
        [void](Add-NFEntradaMovement -Store $script:Store -Produto $script:ComputerProduct -RegistroId 999 -NFEntrada 'LEGACY-OUTPUT' -Quantidade 7 -Referencia '9999' -SaldoAntes 20 -SaldoDepois 13)
        $legacyDisplay = Get-NFEntradaOutputDisplayText -Store $script:Store -Product $script:ComputerProduct -Record $legacy
        if ([string]$legacyDisplay -ne '(7 PÇS NF 9999)') {
            throw "Compatibilidade do valor cru falhou: '$legacyDisplay'."
        }

        return $true
    }

    if (-not [bool]$result) { throw 'Fluxo real de SAÍDA não concluiu o teste.' }
    Write-Host 'NF OUTPUT DIALOG: OK — modal alinhado; saída de 49 peças/NF 2327 virou (49 PÇS NF 2327) na base e na grade; compatibilidade com registro cru validada.'
}
finally {
    try { if ($null -ne $hostForm -and -not $hostForm.IsDisposed) { $hostForm.Close(); $hostForm.Dispose() } } catch {}
    try { if ($null -ne $hostedControl -and -not $hostedControl.IsDisposed) { $hostedControl.Dispose() } } catch {}
    try { if ($null -ne $moduleInfo) { Remove-Module -ModuleInfo $moduleInfo -Force -ErrorAction SilentlyContinue } } catch {}
    try { if (Test-Path -LiteralPath $dataRoot) { Remove-Item -LiteralPath $dataRoot -Recurse -Force } } catch {}
    $env:CENTRAL_THEME_RUNTIME_TEST = $previousRuntimeTest
    $env:CENTRAL_THEME_TEST_DATA_ROOT = $previousDataRoot
}
