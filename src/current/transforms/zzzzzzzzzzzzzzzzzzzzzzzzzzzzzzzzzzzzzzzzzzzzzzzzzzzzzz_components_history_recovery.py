from pathlib import Path

cp = Path('src/generated/Central de Trabalho.ps1')
gp = Path('src/generated/Modulos/Gerador-de-Planilhas-CB5-TV5/Gerador Planilhas.ps1')
corep = Path('src/generated/Modulos/Gerador-de-Planilhas-CB5-TV5/Componentes.Core.ps1')

c = cp.read_text(encoding='utf-8-sig')
g = gp.read_text(encoding='utf-8-sig')
core = corep.read_text(encoding='utf-8-sig')


def one(text, old, new, label):
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'COMPONENT RECOVERY {label}: esperado 1, encontrado {count}')
    return text.replace(old, new, 1)


# ---------------------------------------------------------------------------
# Versões — somente Teste.
# ---------------------------------------------------------------------------
c = one(c, '$script:AppVersion = "0.21.61"', '$script:AppVersion = "0.21.62"', 'versao Central')
c = one(c, '$script:GeneratorVersion = "3.7.18"', '$script:GeneratorVersion = "3.7.19"', 'versao Gerenciador Central')
g = one(g, '$script:AppVersion = "3.7.18"', '$script:AppVersion = "3.7.19"', 'versao Gerenciador')
core = one(core, '$script:BillingComponentsCoreVersion = "1.3.0"', '$script:BillingComponentsCoreVersion = "1.4.0"', 'versao Core')


# ---------------------------------------------------------------------------
# Proteção daqui para frente: snapshot persistente da base ANTES de cada escrita
# no arquivo oficial. O antigo .swap-backup era apenas transacional e era apagado
# depois da gravação; agora mantemos até 40 cópias recuperáveis.
# ---------------------------------------------------------------------------
backup_helper = r'''
function Backup-BillingComponentStoreSnapshot {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [string]$Reason = "automatico"
    )
    try {
        if (-not [IO.File]::Exists($Path)) { return "" }
        if (-not [string]::Equals([IO.Path]::GetFileName($Path), "componentes-a-faturar.json", [StringComparison]::OrdinalIgnoreCase)) { return "" }
        $directory = [IO.Path]::GetDirectoryName($Path)
        $backupDirectory = [IO.Path]::Combine($directory, "Backups-Automaticos")
        if (-not [IO.Directory]::Exists($backupDirectory)) { [void][IO.Directory]::CreateDirectory($backupDirectory) }
        $safeReason = ([regex]::Replace(([string]$Reason), '[^A-Za-z0-9_-]+', '-')).Trim('-')
        if ([string]::IsNullOrWhiteSpace($safeReason)) { $safeReason = "automatico" }
        $stamp = [DateTime]::Now.ToString("yyyyMMdd-HHmmss-fff")
        $target = [IO.Path]::Combine($backupDirectory, "componentes-a-faturar-$stamp-$safeReason.json")
        [IO.File]::Copy($Path, $target, $false)
        $old = @([IO.Directory]::GetFiles($backupDirectory, "componentes-a-faturar-*.json") | ForEach-Object { [IO.FileInfo]::new($_) } | Sort-Object LastWriteTime -Descending | Select-Object -Skip 40)
        foreach ($item in $old) { try { $item.Delete() } catch {} }
        return $target
    }
    catch { return "" }
}

'''
core = one(core, 'function Write-BillingComponentStore {', backup_helper + 'function Write-BillingComponentStore {', 'helper snapshot')
core = one(
    core,
    '''    $directory = [IO.Path]::GetDirectoryName($Path)
    if (-not [IO.Directory]::Exists($directory)) { [void][IO.Directory]::CreateDirectory($directory) }
    $Store.SchemaVersion = 3''',
    '''    $directory = [IO.Path]::GetDirectoryName($Path)
    if (-not [IO.Directory]::Exists($directory)) { [void][IO.Directory]::CreateDirectory($directory) }
    if ([IO.File]::Exists($Path) -and [string]::Equals([IO.Path]::GetFileName($Path), "componentes-a-faturar.json", [StringComparison]::OrdinalIgnoreCase)) {
        [void](Backup-BillingComponentStoreSnapshot -Path $Path -Reason "antes-gravacao")
    }
    $Store.SchemaVersion = 3''',
    'snapshot antes da escrita'
)


# ---------------------------------------------------------------------------
# Recuperação. Procura bases antigas/temporárias/backups e escolhe a que contém
# MAIS histórico real. A base atual nunca é sobrescrita sem snapshot prévio.
# ---------------------------------------------------------------------------
recovery_code = r'''
$script:BillingRecoveryLastResult = $null
$script:BillingRecoveryNoticeShown = $false

function Get-BillingRecoveryStoreStats {
    param([AllowNull()][object]$Store)
    if ($null -eq $Store) { return [pscustomobject]@{ Componentes=0; Movimentos=0; Operacoes=0; Score=[Int64]0 } }
    $components = @($Store.Componentes).Count
    $movements = @($Store.Movimentos).Count
    $operations = @($Store.Operacoes).Count
    $score = ([Int64]$movements * 1000000000L) + ([Int64]$operations * 1000000L) + ([Int64]$components * 1000L)
    return [pscustomobject]@{ Componentes=$components; Movimentos=$movements; Operacoes=$operations; Score=$score }
}

function Read-BillingRecoveryCandidate {
    param([Parameter(Mandatory = $true)][string]$Path)
    try {
        if (-not [IO.File]::Exists($Path)) { return $null }
        if ([string]::Equals([IO.Path]::GetFullPath($Path), [IO.Path]::GetFullPath($script:BillingComponentStorePath), [StringComparison]::OrdinalIgnoreCase)) { return $null }
        $rawText = [IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8)
        if ([string]::IsNullOrWhiteSpace($rawText)) { return $null }
        $raw = $rawText | ConvertFrom-Json
        $props = @($raw.PSObject.Properties.Name)
        if ($props -notcontains "Componentes") { return $null }
        if (($props -notcontains "Movimentos") -and ($props -notcontains "Operacoes")) { return $null }
        $store = Normalize-BillingComponentStore $raw
        $stats = Get-BillingRecoveryStoreStats $store
        $updated = [DateTime]::MinValue
        try { [void][DateTime]::TryParse(([string]$store.AtualizadoEm), [ref]$updated) } catch {}
        return [pscustomobject]@{ Path=[IO.Path]::GetFullPath($Path); Store=$store; Stats=$stats; Updated=$updated }
    }
    catch { return $null }
}

function Get-BillingRecoveryCandidatePaths {
    param([switch]$Deep)
    $paths = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $addPath = {
        param([string]$candidate)
        if ([string]::IsNullOrWhiteSpace($candidate)) { return }
        try {
            if ([IO.File]::Exists($candidate)) { [void]$paths.Add([IO.Path]::GetFullPath($candidate)) }
        } catch {}
    }
    $addDirectory = {
        param([string]$directory, [bool]$recurse)
        if ([string]::IsNullOrWhiteSpace($directory) -or -not [IO.Directory]::Exists($directory)) { return }
        try {
            $option = if ($recurse) { [IO.SearchOption]::AllDirectories } else { [IO.SearchOption]::TopDirectoryOnly }
            foreach ($pattern in @("componentes-a-faturar*.json", "*componentes*faturar*.json", "componentes*.json")) {
                foreach ($file in @([IO.Directory]::GetFiles($directory, $pattern, $option))) { [void]$paths.Add([IO.Path]::GetFullPath($file)) }
            }
        } catch {}
    }

    # Locais conhecidos usados pelo Gerenciador e pelas versões integradas.
    & $addDirectory $script:SettingsDirectory $true
    $local = [Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData)
    $roaming = [Environment]::GetFolderPath([Environment+SpecialFolder]::ApplicationData)
    foreach ($base in @($local, $roaming)) {
        if ([string]::IsNullOrWhiteSpace($base)) { continue }
        foreach ($relative in @(
            "GeradorPlanilhasCB5TV5",
            "CentralDeTrabalho\GeradorPlanilhasCB5TV5",
            "Central de Trabalho\GeradorPlanilhasCB5TV5",
            "CentralDeTrabalho\Dados\GeradorPlanilhasCB5TV5",
            "Central de Trabalho\Dados\GeradorPlanilhasCB5TV5"
        )) { & $addDirectory ([IO.Path]::Combine($base, $relative)) $true }
    }

    # Diretório do módulo e pais: cobre instalações antigas/portáteis que ainda
    # possam ter deixado a base ao lado do programa.
    $walk = [IO.DirectoryInfo]::new($PSScriptRoot)
    for ($i=0; $i -lt 4 -and $null -ne $walk; $i++) {
        & $addDirectory $walk.FullName $false
        $walk = $walk.Parent
    }

    # Varredura profunda só quando o usuário pede: AppData + Documentos + Downloads.
    if ($Deep -and $env:CENTRAL_THEME_RUNTIME_TEST -ne "1") {
        $documents = [Environment]::GetFolderPath([Environment+SpecialFolder]::MyDocuments)
        $downloads = if ([string]::IsNullOrWhiteSpace($env:USERPROFILE)) { "" } else { [IO.Path]::Combine($env:USERPROFILE, "Downloads") }
        foreach ($root in @($local, $roaming, $documents, $downloads)) { & $addDirectory $root $true }
    }
    return @($paths)
}

function Merge-BillingRecoveryArray {
    param([object[]]$Primary, [object[]]$Secondary)
    $result = New-Object Collections.ArrayList
    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($item in @($Primary) + @($Secondary)) {
        if ($null -eq $item) { continue }
        $id = ""
        try { if ($item.PSObject.Properties.Name -contains "Id") { $id = [string]$item.Id } } catch {}
        $key = if (-not [string]::IsNullOrWhiteSpace($id)) { "id:" + $id } else { "json:" + ($item | ConvertTo-Json -Depth 12 -Compress) }
        if ($seen.Add($key)) { [void]$result.Add($item) }
    }
    return @($result)
}

function Merge-BillingRecoveryStores {
    param([Parameter(Mandatory = $true)][object]$Recovered, [Parameter(Mandatory = $true)][object]$Current)
    $merged = Copy-BillingComponentStore $Recovered
    $componentKeys = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($component in @($merged.Componentes)) {
        $key = if (-not [string]::IsNullOrWhiteSpace([string]$component.Id)) { "id:" + [string]$component.Id } else { ([string]$component.Produto) + "|" + ([string]$component.Componente) }
        [void]$componentKeys.Add($key)
    }
    foreach ($component in @($Current.Componentes)) {
        $key = if (-not [string]::IsNullOrWhiteSpace([string]$component.Id)) { "id:" + [string]$component.Id } else { ([string]$component.Produto) + "|" + ([string]$component.Componente) }
        if ($componentKeys.Add($key)) { $merged.Componentes = @($merged.Componentes) + @($component) }
    }
    $merged.Movimentos = @(Merge-BillingRecoveryArray -Primary @($Recovered.Movimentos) -Secondary @($Current.Movimentos))
    $merged.Operacoes = @(Merge-BillingRecoveryArray -Primary @($Recovered.Operacoes) -Secondary @($Current.Operacoes))
    return Normalize-BillingComponentStore $merged
}

function Invoke-BillingComponentRecovery {
    param([switch]$Deep, [switch]$Silent)
    $currentStats = Get-BillingRecoveryStoreStats $script:BillingComponentStore
    $best = $null
    foreach ($path in @(Get-BillingRecoveryCandidatePaths -Deep:$Deep)) {
        $candidate = Read-BillingRecoveryCandidate $path
        if ($null -eq $candidate) { continue }
        if ($null -eq $best -or $candidate.Stats.Score -gt $best.Stats.Score -or ($candidate.Stats.Score -eq $best.Stats.Score -and $candidate.Updated -gt $best.Updated)) { $best = $candidate }
    }

    if ($null -eq $best -or $best.Stats.Score -le $currentStats.Score) {
        $result = [pscustomobject]@{ Recovered=$false; Source=""; Backup=""; Before=$currentStats; After=$currentStats; CandidatesFound=if($null -eq $best){0}else{1} }
        $script:BillingRecoveryLastResult = $result
        return $result
    }

    $backup = Backup-BillingComponentStoreSnapshot -Path $script:BillingComponentStorePath -Reason "antes-recuperacao"
    $merged = Merge-BillingRecoveryStores -Recovered $best.Store -Current $script:BillingComponentStore
    $afterStats = Get-BillingRecoveryStoreStats $merged
    if ($afterStats.Score -le $currentStats.Score) {
        $result = [pscustomobject]@{ Recovered=$false; Source=$best.Path; Backup=$backup; Before=$currentStats; After=$currentStats; CandidatesFound=1 }
        $script:BillingRecoveryLastResult = $result
        return $result
    }

    Write-BillingComponentStore -Store $merged -Path $script:BillingComponentStorePath
    $script:BillingComponentStore = Read-BillingComponentStore -Path $script:BillingComponentStorePath
    $result = [pscustomobject]@{ Recovered=$true; Source=$best.Path; Backup=$backup; Before=$currentStats; After=(Get-BillingRecoveryStoreStats $script:BillingComponentStore); CandidatesFound=1 }
    $script:BillingRecoveryLastResult = $result
    return $result
}

# Busca rápida e segura a cada abertura. Só troca a base se achar outra cópia
# objetivamente mais rica em movimentos/operações. Nos testes automatizados a
# busca fica confinada ao diretório temporário do próprio teste.
try { [void](Invoke-BillingComponentRecovery -Silent) } catch {}
'''

startup_anchor = '$script:BillingComponentStore = Read-BillingComponentStore -Path $script:BillingComponentStorePath'
g = one(g, startup_anchor, startup_anchor + '\n' + recovery_code, 'motor de recuperacao')


# ---------------------------------------------------------------------------
# Botão manual para varredura profunda. Fica ao lado de Backup/Restaurar.
# ---------------------------------------------------------------------------
recovery_button = r'''
$componentRecoveryButton = New-Object Windows.Forms.Button
$componentRecoveryButton.Text = "Recuperar dados"
$componentRecoveryButton.Location = New-Object Drawing.Point(538, 118)
$componentRecoveryButton.Size = New-Object Drawing.Size(142, 31)
$componentRecoveryButton.Anchor = "Top,Right"
$componentRecoveryButton.Tag = "Secondary"
$tabComponents.Controls.Add($componentRecoveryButton)
'''
g = one(
    g,
    '$tabComponents.Controls.Add($componentRestoreButton)',
    '$tabComponents.Controls.Add($componentRestoreButton)\n' + recovery_button,
    'botao recuperar'
)

click_handler = r'''$componentRecoveryButton.Add_Click({
    try {
        $componentRecoveryButton.Enabled = $false
        $componentsSummaryLabel.Text = "Procurando bases antigas e backups..."
        [Windows.Forms.Application]::DoEvents()
        $result = Invoke-BillingComponentRecovery -Deep
        Update-BillingComponentsView
        if ($result.Recovered) {
            $message = "Dados recuperados com sucesso.`r`n`r`nOrigem: $($result.Source)`r`nMovimentos: $($result.Before.Movimentos) -> $($result.After.Movimentos)`r`nOperações: $($result.Before.Operacoes) -> $($result.After.Operacoes)`r`nComponentes: $($result.Before.Componentes) -> $($result.After.Componentes)"
            if (-not [string]::IsNullOrWhiteSpace([string]$result.Backup)) { $message += "`r`n`r`nCópia de segurança da base anterior:`r`n$($result.Backup)" }
            [Windows.Forms.MessageBox]::Show($message, "Recuperação de componentes", "OK", "Information") | Out-Null
        }
        else {
            [Windows.Forms.MessageBox]::Show("A varredura terminou, mas não encontrou uma base de componentes com mais histórico do que a atual.`r`n`r`nForam verificados os locais antigos do Gerenciador, AppData, Documentos, Downloads, arquivos temporários e backups automáticos.", "Recuperação de componentes", "OK", "Information") | Out-Null
        }
    }
    catch {
        [Windows.Forms.MessageBox]::Show("Não foi possível concluir a recuperação.`r`n`r`n$($_.Exception.Message)", "Recuperação de componentes", "OK", "Error") | Out-Null
    }
    finally { $componentRecoveryButton.Enabled = $true }
})

'''
g = one(g, '$componentRestoreButton.Add_Click({', click_handler + '$componentRestoreButton.Add_Click({', 'click recuperar')

# Inclui o novo botão na mesma autoridade visual dos demais.
g = one(
    g,
    '$componentBackupButton, $componentRestoreButton,',
    '$componentBackupButton, $componentRecoveryButton, $componentRestoreButton,',
    'tema do recuperar'
)

# Três ações responsivas no canto direito.
layout_old = '''        $actionW = if ($cw -lt 850) { 92 } else { 118 }
        $gap = 8
        $right = $cw - 18
        $componentRestoreButton.Width = $actionW
        $componentBackupButton.Width = $actionW
        $componentRestoreButton.Left = [Math]::Max(18, $right - $actionW)
        $componentBackupButton.Left = [Math]::Max(18, $componentRestoreButton.Left - $gap - $actionW)'''
layout_new = '''        $actionW = if ($cw -lt 850) { 92 } else { 118 }
        $gap = 8
        $right = $cw - 18
        $componentRestoreButton.Width = $actionW
        $componentRecoveryButton.Width = $actionW
        $componentBackupButton.Width = $actionW
        $componentRestoreButton.Left = [Math]::Max(18, $right - $actionW)
        $componentRecoveryButton.Left = [Math]::Max(18, $componentRestoreButton.Left - $gap - $actionW)
        $componentBackupButton.Left = [Math]::Max(18, $componentRecoveryButton.Left - $gap - $actionW)
        $componentRecoveryButton.Text = if ($cw -lt 850) { "Recuperar" } else { "Recuperar dados" }'''
g = one(g, layout_old, layout_new, 'layout tres acoes')

# O print do usuário mostrou "Carregando componentes..." permanente. A base pode
# ainda estar intacta e a tela simplesmente não ter recebido o refresh inicial.
# Forçamos refresh ao entrar em Componentes e ao trocar a subaba.
event_old = '$componentTabs.Add_SelectedIndexChanged({ Update-GeneratorInternalLayouts; $componentTabs.Invalidate() })'
event_new = '''$componentTabs.Add_SelectedIndexChanged({ Update-GeneratorInternalLayouts; $componentTabs.Invalidate(); try { Update-BillingComponentsView } catch {} })
$tabComponents.Add_Enter({
    try {
        Update-BillingComponentsView
        if ($null -ne $script:BillingRecoveryLastResult -and $script:BillingRecoveryLastResult.Recovered -and -not $script:BillingRecoveryNoticeShown) {
            $script:BillingRecoveryNoticeShown = $true
            [Windows.Forms.MessageBox]::Show("Uma base antiga de componentes com mais histórico foi encontrada e recuperada automaticamente.`r`n`r`nOrigem: $($script:BillingRecoveryLastResult.Source)`r`nMovimentos recuperados: $($script:BillingRecoveryLastResult.After.Movimentos)", "Histórico de componentes recuperado", "OK", "Information") | Out-Null
        }
    } catch {}
})'''
g = one(g, event_old, event_new, 'refresh inicial componentes')

c += '\n# COMPONENTES_RECOVERY_V02162\n'
g += '\n# COMPONENTES_RECOVERY_V03719\n'
core += '\n# COMPONENTES_RECOVERY_CORE_V140\n'

for marker in ('$script:AppVersion = "0.21.62"', '$script:GeneratorVersion = "3.7.19"', 'COMPONENTES_RECOVERY_V02162'):
    if marker not in c:
        raise SystemExit('COMPONENT RECOVERY Central marcador ausente: ' + marker)
for marker in ('$script:AppVersion = "3.7.19"', 'function Invoke-BillingComponentRecovery', '$componentRecoveryButton.Text', '$tabComponents.Add_Enter', 'COMPONENTES_RECOVERY_V03719'):
    if marker not in g:
        raise SystemExit('COMPONENT RECOVERY Gerenciador marcador ausente: ' + marker)
for marker in ('$script:BillingComponentsCoreVersion = "1.4.0"', 'function Backup-BillingComponentStoreSnapshot', 'Backups-Automaticos', 'COMPONENTES_RECOVERY_CORE_V140'):
    if marker not in core:
        raise SystemExit('COMPONENT RECOVERY Core marcador ausente: ' + marker)

cp.write_text(c, encoding='utf-8')
gp.write_text(g, encoding='utf-8')
corep.write_text(core, encoding='utf-8')
print('COMPONENTES RECOVERY: OK - refresh inicial, recuperação automática/profunda e snapshots persistentes habilitados.')
