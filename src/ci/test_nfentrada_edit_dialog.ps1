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
$dataRoot = Join-Path $tempRoot ('nf-edit-dialog-' + [Guid]::NewGuid().ToString('N'))
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

    $moduleInfo = New-Module -Name ('NFEditDialog_' + [Guid]::NewGuid().ToString('N')) -ArgumentList @($modulePath, $hostContext) -ScriptBlock {
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
            Data = '2026-09-09'
            QuantidadeNaNF = 35
            NFEntrada = '697758'
            QuantidadeSaldo = 35
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

        if (-not $editButton.Enabled) { throw 'EDITAR não ficou habilitado para o registro de teste.' }

        # GetNewClosure cria seu próprio escopo de script. Para o próprio teste
        # não cair na mesma armadilha do bug que estamos auditando, usamos um
        # objeto local compartilhado, preservado por referência pelo closure.
        $dialogState = [pscustomobject]@{ ClosedByTest = $false }
        $timer = New-Object Windows.Forms.Timer
        $timer.Interval = 350
        $timer.Add_Tick({
            foreach ($openForm in @([Windows.Forms.Application]::OpenForms)) {
                if ($null -eq $openForm -or $openForm.IsDisposed) { continue }
                if ([string]$openForm.Text -like 'Editar registro*') {
                    $dialogState.ClosedByTest = $true
                    $openForm.DialogResult = [Windows.Forms.DialogResult]::Cancel
                    $openForm.Close()
                    break
                }
            }
        }.GetNewClosure())

        try {
            $timer.Start()
            try {
                Edit-NFRecordFromUI
            }
            catch {
                $details = @(
                    'NF EDIT DIALOG EXCEPTION',
                    ('Type: ' + $_.Exception.GetType().FullName),
                    ('Message: ' + $_.Exception.Message),
                    ('Position: ' + [string]$_.InvocationInfo.PositionMessage),
                    ('ScriptStackTrace: ' + [string]$_.ScriptStackTrace),
                    ('ErrorRecord: ' + [string]$_)
                ) -join "`r`n"
                throw $details
            }
        }
        finally {
            $timer.Stop()
            $timer.Dispose()
        }

        if (-not [bool]$dialogState.ClosedByTest) {
            throw 'A janela real de EDITAR não chegou a abrir para o registro de teste.'
        }
        return $true
    }

    if (-not [bool]$result) { throw 'Fluxo real de EDITAR não concluiu o teste.' }
    Write-Host 'NF EDIT DIALOG: OK — seleção real abriu a janela Editar registro sem exceção e o teste a fechou automaticamente.'
}
finally {
    try { if ($null -ne $hostForm -and -not $hostForm.IsDisposed) { $hostForm.Close(); $hostForm.Dispose() } } catch {}
    try { if ($null -ne $hostedControl -and -not $hostedControl.IsDisposed) { $hostedControl.Dispose() } } catch {}
    try { if ($null -ne $moduleInfo) { Remove-Module -ModuleInfo $moduleInfo -Force -ErrorAction SilentlyContinue } } catch {}
    try { if (Test-Path -LiteralPath $dataRoot) { Remove-Item -LiteralPath $dataRoot -Recurse -Force } } catch {}
    $env:CENTRAL_THEME_RUNTIME_TEST = $previousRuntimeTest
    $env:CENTRAL_THEME_TEST_DATA_ROOT = $previousDataRoot
}
