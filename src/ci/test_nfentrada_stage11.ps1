param(
    [Parameter(Mandatory = $true)][string]$CorePath,
    [Parameter(Mandatory = $true)][string]$UiPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
. $CorePath

function Assert-S11 {
    param([bool]$Condition,[string]$Message)
    if (-not $Condition) { throw $Message }
}

function New-S11Record {
    param([int]$Id,[string]$NF,[int]$Qty=10,[int]$Saldo=10,[string]$Data='2026-09-11')
    return [pscustomobject]@{
        Id=$Id; Ordem=$Id; Data=$Data; QuantidadeNaNF=$Qty; NFEntrada=$NF;
        QuantidadeSaldo=$Saldo; Codigo='800'; NFSaida=''
    }
}

$temp = Join-Path ([IO.Path]::GetTempPath()) ('nfentrada-stage11-' + [guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($temp)
try {
    $store = New-EmptyNFEntradaStore
    $store.Produtos.'COMPUTADOR DE BORDO V5' = @((New-S11Record -Id 1 -NF '1001'))
    $store.NextId = 2
    $storePath = Get-NFEntradaStorePath -DataDirectory $temp
    Write-NFEntradaStore -Store $store -Path $storePath
    $template = Get-NFEntradaTemplatePath -DataDirectory $temp
    [IO.File]::WriteAllBytes($template,[byte[]](1,2,3,4))

    $report = Get-NFEntradaIntegrityReport -Store $store -DataDirectory $temp
    Assert-S11 ([string]$report.Situacao -eq 'OK') 'Base valida deveria passar na auditoria com situacao OK.'
    Assert-S11 ([int]$report.Registros -eq 1) 'Auditoria nao contou os registros corretamente.'
    Assert-S11 ([bool]$report.ModeloDisponivel) 'Auditoria nao reconheceu o modelo disponivel.'

    $duplicate = New-EmptyNFEntradaStore
    $duplicate.Produtos.'COMPUTADOR DE BORDO V5' = @(
        (New-S11Record -Id 1 -NF '2002'),
        (New-S11Record -Id 2 -NF '2002')
    )
    $dupReport = Get-NFEntradaIntegrityReport -Store $duplicate -DataDirectory $temp
    Assert-S11 ([string]$dupReport.Situacao -eq 'ERRO') 'Duplicidade deveria elevar a auditoria para ERRO.'
    Assert-S11 ([int]$dupReport.Duplicidades -eq 1) 'Duplicidade nao foi contabilizada.'

    $review = New-EmptyNFEntradaStore
    $review.Produtos.'TECLADO V5' = @((New-S11Record -Id 1 -NF '3003' -Qty 5 -Saldo 6 -Data ''))
    $reviewReport = Get-NFEntradaIntegrityReport -Store $review -DataDirectory $temp
    Assert-S11 ([string]$reviewReport.Situacao -ne 'ERRO') 'Pendencia sem erro estrutural nao deve resultar em ERRO.'
    Assert-S11 ([int]$reviewReport.Pendencias -eq 1) 'Pendencia nao foi contabilizada.'
    Assert-S11 (@($reviewReport.Avisos).Count -ge 1) 'Pendencia deveria produzir pelo menos um aviso.'

    foreach ($i in 1..22) {
        [void](New-NFEntradaSafetyBackup -DataDirectory $temp -Reason 'Automatico')
        Start-Sleep -Milliseconds 3
    }
    [void](New-NFEntradaSafetyBackup -DataDirectory $temp -Reason 'Manual')
    $backups = @(Get-NFEntradaSafetyBackups -DataDirectory $temp)
    $automatic = @($backups | Where-Object { [string]$_.Motivo -eq 'Automatico' })
    $manual = @($backups | Where-Object { [string]$_.Motivo -eq 'Manual' })
    [void](Invoke-NFEntradaBackupRetention -DataDirectory $temp -MaxAutomaticBackups 20)
    $afterTwenty = @(Get-NFEntradaSafetyBackups -DataDirectory $temp)
    Assert-S11 (@($afterTwenty | Where-Object { [string]$_.Motivo -eq 'Automatico' }).Count -le 20) 'Retencao deixou mais de 20 backups automaticos.'
    Assert-S11 (@($afterTwenty | Where-Object { [string]$_.Motivo -eq 'Manual' }).Count -ge 1) 'Retencao removeu backup manual.'

    [void](Invoke-NFEntradaBackupRetention -DataDirectory $temp -MaxAutomaticBackups 10)
    $afterRetention = @(Get-NFEntradaSafetyBackups -DataDirectory $temp)
    Assert-S11 (@($afterRetention | Where-Object { [string]$_.Motivo -eq 'Automatico' }).Count -le 10) 'Retencao explicita nao respeitou o limite solicitado.'
    Assert-S11 (@($afterRetention | Where-Object { [string]$_.Motivo -eq 'Manual' }).Count -ge 1) 'Retencao explicita removeu backup manual.'

    $ui = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $UiPath),[Text.Encoding]::UTF8)
    foreach ($marker in @(
        '$script:ModuleVersion = "2.2.0"',
        'VERIFICAR INTEGRIDADE',
        'function Show-NFIntegrityReport',
        '$integrityButton.Add_Click',
        '20 backups autom'
    )) {
        Assert-S11 ($ui.Contains($marker)) ('Marcador da Etapa 11 ausente na interface: ' + $marker)
    }

    Write-Host 'NF ENTRADA ETAPA 11: OK - auditoria, duplicidades, pendencias, retencao e protecao de backups validadas.'
}
finally {
    if ([IO.Directory]::Exists($temp)) { [IO.Directory]::Delete($temp,$true) }
}
