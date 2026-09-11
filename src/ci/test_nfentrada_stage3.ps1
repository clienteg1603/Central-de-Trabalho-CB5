param(
    [string]$CorePath = ".\src\generated\Modulos\Controle-NF-Entrada\NFEntrada.Core.ps1"
)
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
if (-not (Test-Path -LiteralPath $CorePath -PathType Leaf)) { throw "NFEntrada.Core.ps1 não encontrado: $CorePath" }
. $CorePath
$root = Join-Path $env:RUNNER_TEMP ("nfentrada-stage3-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $root | Out-Null
try {
    $store = New-EmptyNFEntradaStore
    $record = [pscustomobject]@{ Data="2026-09-11"; QuantidadeNaNF=20; NFEntrada="9001"; QuantidadeSaldo=15; Codigo="800"; NFSaida="" }
    [void](Add-NFEntradaRecord -Store $store -Product "COMPUTADOR DE BORDO V5" -Record $record)
    $storePath = Get-NFEntradaStorePath -DataDirectory $root
    $templatePath = Get-NFEntradaTemplatePath -DataDirectory $root
    Write-NFEntradaStore -Store $store -Path $storePath
    [IO.File]::WriteAllText($templatePath, "modelo-a", [Text.Encoding]::UTF8)

    $backup = New-NFEntradaSafetyBackup -DataDirectory $root -Reason "Manual"
    if ($null -eq $backup) { throw "Backup manual não foi criado." }
    $infoPath = Join-Path $backup.Directory "backup-info.json"
    if (-not (Test-Path -LiteralPath $infoPath -PathType Leaf)) { throw "Metadados do backup não foram criados." }
    $list = @(Get-NFEntradaSafetyBackups -DataDirectory $root)
    if ($list.Count -ne 1) { throw "Listagem de backups não retornou o backup criado." }
    if ([string]$list[0].Motivo -ne "Manual" -or [string]$list[0].Situacao -ne "Pronto") { throw "Metadados/listagem do backup incorretos." }
    if ([int]$list[0].Registros -ne 1) { throw "Contagem de registros do backup incorreta." }

    $changed = New-EmptyNFEntradaStore
    $record2 = [pscustomobject]@{ Data="2026-09-11"; QuantidadeNaNF=9; NFEntrada="9002"; QuantidadeSaldo=9; Codigo="850"; NFSaida="" }
    [void](Add-NFEntradaRecord -Store $changed -Product "TECLADO V5" -Record $record2)
    Write-NFEntradaStore -Store $changed -Path $storePath
    [IO.File]::WriteAllText($templatePath, "modelo-b", [Text.Encoding]::UTF8)

    $restoredResult = Restore-NFEntradaBackupSet -BackupDirectory $backup.Directory -DataDirectory $root
    $restored = $restoredResult.Store
    $cb = @(Get-NFEntradaProductRecords -Store $restored -Product "COMPUTADOR DE BORDO V5")
    $tk = @(Get-NFEntradaProductRecords -Store $restored -Product "TECLADO V5")
    if ($cb.Count -ne 1 -or [string]$cb[0].NFEntrada -ne "9001" -or $tk.Count -ne 0) { throw "Restauração não recuperou a base selecionada." }
    if ([IO.File]::ReadAllText($templatePath, [Text.Encoding]::UTF8) -ne "modelo-a") { throw "Restauração não recuperou o modelo selecionado." }
    $history = @(Get-NFEntradaHistory -Store $restored)
    if (-not ($history | Where-Object { [string]$_.Tipo -eq "RestauracaoBackup" })) { throw "Restauração não foi registrada no histórico." }
    if ([string]::IsNullOrWhiteSpace([string]$restoredResult.RecoveryBackupDirectory) -or -not (Test-Path -LiteralPath $restoredResult.RecoveryBackupDirectory -PathType Container)) { throw "Backup preventivo antes da restauração não foi criado." }
    $all = @(Get-NFEntradaSafetyBackups -DataDirectory $root)
    if ($all.Count -lt 2) { throw "Restauração não preservou o estado anterior em um novo backup." }
    if (-not ($all | Where-Object { [string]$_.Motivo -eq "Antes de restaurar backup" })) { throw "Motivo do backup preventivo não foi preservado." }

    $outside = Join-Path $env:RUNNER_TEMP "fora-backup"
    $blocked = $false
    try { [void](Restore-NFEntradaBackupSet -BackupDirectory $outside -DataDirectory $root) } catch { $blocked = $true }
    if (-not $blocked) { throw "Restauração aceitou caminho externo ao diretório de backups." }
    Write-Host "NF ENTRADA ETAPA 3: OK - listagem, metadados, restauração transacional e backup preventivo validados."
}
finally {
    if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
}
