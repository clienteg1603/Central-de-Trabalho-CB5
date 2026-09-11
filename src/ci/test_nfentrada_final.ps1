param(
    [Parameter(Mandatory = $true)][string]$CorePath,
    [Parameter(Mandatory = $true)][string]$UiPath,
    [Parameter(Mandatory = $true)][string]$CentralPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Assert-NFFinal {
    param([bool]$Condition,[string]$Message)
    if (-not $Condition) { throw $Message }
}

foreach ($path in @($CorePath,$UiPath,$CentralPath)) {
    Assert-NFFinal (Test-Path -LiteralPath $path -PathType Leaf) ("Arquivo da auditoria final ausente: " + $path)
}

. $CorePath
$ui = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $UiPath),[Text.Encoding]::UTF8)
$central = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $CentralPath),[Text.Encoding]::UTF8)

# Contratos atuais da interface final. Estes marcadores protegem o comportamento real,
# sem depender dos rótulos antigos que foram substituídos durante o desenvolvimento.
foreach ($marker in @(
    '$importButton.Text = "IMPORTAR EXCEL"',
    '$exportButton.Text = "EXCEL OFICIAL"',
    '$clearFiltersButton.Text = "LIMPAR"',
    '$reviewIssuesButton.Text = "PENDÊNCIAS"',
    '$outBox.ReadOnly = $true',
    'NF de Saída / movimentações (automático)',
    'function Get-NFHistoryActionLabel',
    '$historyPeriodFilter',
    '"Últimos 30 dias"',
    'function Set-HostedNFEntradaTheme',
    '$movementReverseButton',
    '$integrityButton.Add_Click',
    '$restoreBackupButton.Add_Click',
    '$exportButton.Enabled = $true'
)) {
    Assert-NFFinal ($ui.Contains($marker)) ('Contrato final de interface ausente: ' + $marker)
}
Assert-NFFinal (-not $ui.Contains('$exportCheckButton = New-Object Windows.Forms.Button')) 'O botão redundante VALIDAR EXCEL voltou para a interface.'

$moduleMatch = [regex]::Match($ui,'\$script:ModuleVersion\s*=\s*"([0-9.]+)"')
$centralMatch = [regex]::Match($central,'\$script:NFEntradaVersion\s*=\s*"([0-9.]+)"')
Assert-NFFinal $moduleMatch.Success 'Versão do Controle de NF não encontrada.'
Assert-NFFinal $centralMatch.Success 'Versão do Controle de NF na Central não encontrada.'
Assert-NFFinal ([version]$moduleMatch.Groups[1].Value -ge [version]'2.6.1') 'Versão do módulo está abaixo da versão final auditada 2.6.1.'
Assert-NFFinal ([version]$centralMatch.Groups[1].Value -ge [version]'2.6.1') 'Versão do módulo na Central está abaixo da versão final auditada 2.6.1.'

$tempRoot = if ([string]::IsNullOrWhiteSpace($env:RUNNER_TEMP)) { [IO.Path]::GetTempPath() } else { $env:RUNNER_TEMP }
$temp = Join-Path $tempRoot ('nfentrada-final-' + [guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($temp)

try {
    # Fluxo operacional: criar -> editar -> saída -> estorno -> persistir.
    $store = New-EmptyNFEntradaStore
    $record = [pscustomobject]@{
        Data = '2026-09-11'; QuantidadeNaNF = 10; NFEntrada = 'FINAL-1001';
        QuantidadeSaldo = 10; Codigo = '800'; NFSaida = ''
    }
    $created = Add-NFEntradaRecord -Store $store -Product 'COMPUTADOR DE BORDO V5' -Record $record
    Assert-NFFinal ([int]$created.Id -gt 0) 'Cadastro final não gerou ID.'

    $edited = [pscustomobject]@{
        Data = '2026-09-11'; QuantidadeNaNF = 10; NFEntrada = 'FINAL-1001';
        QuantidadeSaldo = 10; Codigo = '850'; NFSaida = ''
    }
    [void](Update-NFEntradaRecord -Store $store -Product 'COMPUTADOR DE BORDO V5' -Id ([int]$created.Id) -Record $edited)
    $current = @(Get-NFEntradaProductRecords -Store $store -Product 'COMPUTADOR DE BORDO V5')[0]
    Assert-NFFinal ([string]$current.Codigo -eq '850') 'Edição final não foi aplicada.'

    [void](Register-NFEntradaOutput -Store $store -Product 'COMPUTADOR DE BORDO V5' -Id ([int]$created.Id) -Quantidade 4 -NFSaida 'FINAL-SAIDA')
    $movement = @(Get-NFEntradaMovements -Store $store)[0]
    Assert-NFFinal ([int]$movement.SaldoAntes -eq 10 -and [int]$movement.SaldoDepois -eq 6) 'Saída final não atualizou os saldos corretamente.'
    Assert-NFFinal ((Get-NFEntradaMovementStatus -Movement $movement) -eq 'Ativa') 'Movimentação recém-criada não ficou ativa.'

    $reversal = Register-NFEntradaReversal -Store $store -MovementId ([string]$movement.Id) -Motivo 'Auditoria final'
    Assert-NFFinal ([int]$reversal.Record.QuantidadeSaldo -eq 10) 'Estorno final não devolveu o saldo.'
    Assert-NFFinal ([bool]$reversal.Movement.Estornada) 'Movimentação não foi marcada como estornada.'

    $historyTypes = @(Get-NFEntradaHistory -Store $store | ForEach-Object { [string]$_.Tipo })
    foreach ($type in @('Adicao','Edicao','Saida','EstornoSaida')) {
        Assert-NFFinal ($historyTypes -contains $type) ('Histórico final não registrou: ' + $type)
    }

    $storePath = Get-NFEntradaStorePath -DataDirectory $temp
    $templatePath = Get-NFEntradaTemplatePath -DataDirectory $temp
    Write-NFEntradaStore -Store $store -Path $storePath
    [IO.File]::WriteAllText($templatePath,'modelo-final',[Text.Encoding]::UTF8)
    $loaded = Read-NFEntradaStore -Path $storePath
    Assert-NFFinal (@(Get-NFEntradaProductRecords -Store $loaded -Product 'COMPUTADOR DE BORDO V5').Count -eq 1) 'Persistência final perdeu o registro.'
    Assert-NFFinal (@(Get-NFEntradaMovements -Store $loaded).Count -eq 1) 'Persistência final perdeu a movimentação.'

    # Integridade e proteção de backup/restore.
    $integrity = Get-NFEntradaIntegrityReport -Store $loaded -DataDirectory $temp
    Assert-NFFinal ([string]$integrity.Situacao -eq 'OK') ('Integridade final deveria ser OK e retornou ' + [string]$integrity.Situacao)

    $backup = New-NFEntradaSafetyBackup -DataDirectory $temp -Reason 'Manual'
    Assert-NFFinal ($null -ne $backup) 'Backup final não foi criado.'
    $changed = Read-NFEntradaStore -Path $storePath
    $keyboard = [pscustomobject]@{
        Data = '2026-09-11'; QuantidadeNaNF = 5; NFEntrada = 'FINAL-2002';
        QuantidadeSaldo = 5; Codigo = '100'; NFSaida = ''
    }
    [void](Add-NFEntradaRecord -Store $changed -Product 'TECLADO V5' -Record $keyboard)
    Write-NFEntradaStore -Store $changed -Path $storePath

    $restoredResult = Restore-NFEntradaBackupSet -BackupDirectory $backup.Directory -DataDirectory $temp
    $restored = $restoredResult.Store
    Assert-NFFinal (@(Get-NFEntradaProductRecords -Store $restored -Product 'COMPUTADOR DE BORDO V5').Count -eq 1) 'Restauração final perdeu o CB5.'
    Assert-NFFinal (@(Get-NFEntradaProductRecords -Store $restored -Product 'TECLADO V5').Count -eq 0) 'Restauração final não voltou ao estado anterior.'
    Assert-NFFinal (@(Get-NFEntradaHistory -Store $restored | Where-Object { $_.Tipo -eq 'RestauracaoBackup' }).Count -ge 1) 'Restauração final não foi auditada no Histórico.'

    # Duplicidade continua sendo tratada como erro estrutural.
    $duplicate = New-EmptyNFEntradaStore
    $d1 = [pscustomobject]@{ Data='2026-09-11'; QuantidadeNaNF=2; NFEntrada='DUP-1'; QuantidadeSaldo=2; Codigo='800'; NFSaida='' }
    $d2 = [pscustomobject]@{ Data='2026-09-11'; QuantidadeNaNF=3; NFEntrada='DUP-1'; QuantidadeSaldo=3; Codigo='800'; NFSaida='' }
    [void](Add-NFEntradaRecord -Store $duplicate -Product 'COMPUTADOR DE BORDO V5' -Record $d1)
    # Injeta a segunda linha diretamente para auditar o detector, pois o cadastro normal bloqueia duplicidade antes.
    $direct = [pscustomobject]@{ Id=999; Ordem=999; Data='2026-09-11'; QuantidadeNaNF=3; NFEntrada='DUP-1'; QuantidadeSaldo=3; Codigo='800'; NFSaida='' }
    $duplicate.Produtos.'COMPUTADOR DE BORDO V5' = @($duplicate.Produtos.'COMPUTADOR DE BORDO V5') + @($direct)
    $dupReport = Get-NFEntradaIntegrityReport -Store $duplicate -DataDirectory $temp
    Assert-NFFinal ([string]$dupReport.Situacao -eq 'ERRO' -and [int]$dupReport.Duplicidades -ge 1) 'Auditoria final não detectou duplicidade estrutural.'

    Write-Host 'NF ENTRADA FINAL: OK - cadastro, edição, saída, estorno, histórico, persistência, integridade, backup, restauração e contratos atuais validados.'
}
finally {
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force }
}
