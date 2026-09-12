from pathlib import Path


def read(path):
    return Path(path).read_text(encoding='utf-8-sig')


def write(path, text):
    Path(path).write_text(text, encoding='utf-8')


def one(text, old, new, label):
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: esperado 1 marcador, encontrado {count}')
    return text.replace(old, new, 1)

# ---------------------------------------------------------------------------
# Central: versões do pacote otimizado. O transform zzz_fixed_theme.py roda
# antes deste e leva 0.21.33 -> 0.21.34; daqui seguimos para 0.21.36.
# ---------------------------------------------------------------------------
central_path = 'src/generated/Central de Trabalho.ps1'
central = read(central_path)
central = one(central, '$script:AppVersion = "0.21.34"', '$script:AppVersion = "0.21.36"', 'versão Central')
central = one(central, '$script:GeneratorVersion = "3.7.10"', '$script:GeneratorVersion = "3.7.11"', 'versão Gerenciador na Central')
central = one(central, '$script:MaintenanceVersion = "0.6.8"', '$script:MaintenanceVersion = "0.6.9"', 'versão Manutenção na Central')
central = one(central, '$script:NFEntradaVersion = "2.6.9"', '$script:NFEntradaVersion = "2.6.10"', 'preservação da versão hotfix do NF')
write(central_path, central)

# ---------------------------------------------------------------------------
# Gerenciador: bases SchemaVersion 3 já foram gravadas pelo formato atual.
# Evita renormalizar todos os movimentos/operações em toda abertura.
# ---------------------------------------------------------------------------
billing_path = 'src/generated/Modulos/Gerador-de-Planilhas-CB5-TV5/Componentes.Core.ps1'
billing = read(billing_path)
old_billing_read = '''function Read-BillingComponentStore {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not [IO.File]::Exists($Path)) { throw "A base de componentes a faturar não foi encontrada: $Path" }
    try {
        $raw = [IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8)
        if ([string]::IsNullOrWhiteSpace($raw)) { return New-BillingComponentStore }
        return Normalize-BillingComponentStore ($raw | ConvertFrom-Json)
    }
    catch {
        throw "Não foi possível ler a base de componentes a faturar. O arquivo foi preservado. Detalhe: $($_.Exception.Message)"
    }
}'''
new_billing_read = '''function Read-BillingComponentStore {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not [IO.File]::Exists($Path)) { throw "A base de componentes a faturar não foi encontrada: $Path" }
    try {
        $raw = [IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8)
        if ([string]::IsNullOrWhiteSpace($raw)) { return New-BillingComponentStore }
        $store = $raw | ConvertFrom-Json

        # FAST START: SchemaVersion 3 é exatamente o formato atualmente gravado
        # por Write-BillingComponentStore. Nessas bases não há motivo para
        # percorrer e renormalizar todo o histórico a cada abertura.
        $names = @($store.PSObject.Properties.Name)
        $isCurrent = ($names -contains "SchemaVersion") -and
                     ($names -contains "Componentes") -and
                     ($names -contains "Movimentos") -and
                     ($names -contains "Operacoes") -and
                     ([int]$store.SchemaVersion -eq 3)
        if ($isCurrent) {
            $store.Componentes = @($store.Componentes)
            $store.Movimentos = @($store.Movimentos)
            $store.Operacoes = @($store.Operacoes)
            return $store
        }

        # Bases antigas continuam passando pela migração completa, sem perda de
        # compatibilidade nem alteração retroativa do arquivo durante a leitura.
        return Normalize-BillingComponentStore $store
    }
    catch {
        throw "Não foi possível ler a base de componentes a faturar. O arquivo foi preservado. Detalhe: $($_.Exception.Message)"
    }
}'''
billing = one(billing, old_billing_read, new_billing_read, 'fast path da base do Gerenciador')
write(billing_path, billing)

# Gerenciador: corta reaplicações redundantes de tema durante a construção.
generator_path = 'src/generated/Modulos/Gerador-de-Planilhas-CB5-TV5/Gerador Planilhas.ps1'
generator = read(generator_path)
generator = one(generator, '$script:AppVersion = "3.7.10"', '$script:AppVersion = "3.7.11"', 'versão Gerenciador')
generator = one(
    generator,
    '''    Apply-AppTheme
    Update-LiveSummary
    if ($script:UiReady) { Save-AppSettings }
}

$productCombo.Add_SelectedIndexChanged({ Update-ProductInterface })''',
    '''    # Na criação hospedada a paleta inicial já é conhecida. A Central fará
    # a confirmação final de aparência depois de anexar o controle; evitar um
    # repaint completo aqui reduz o tempo até a primeira tela.
    if (-not $script:IsInProcessHosted -or $script:UiReady) { Apply-AppTheme }
    Update-LiveSummary
    if ($script:UiReady -and -not $script:IsInProcessHosted) { Save-AppSettings }
}

$productCombo.Add_SelectedIndexChanged({ Update-ProductInterface })''',
    'repaint dentro de Update-ProductInterface'
)
generator = one(
    generator,
    '''Update-ProductInterface
$script:UiReady = $true
Apply-AppTheme
Save-AppSettings''',
    '''Update-ProductInterface
$script:UiReady = $true
if (-not $script:IsInProcessHosted) {
    Apply-AppTheme
    Save-AppSettings
}''',
    'repaint/salvamento inicial do Gerenciador'
)
generator = one(
    generator,
    '''    $form.Add_HandleCreated({ try { Apply-AppTheme; Update-GeneratorResponsiveLayout; Update-RootLayout } catch {} })''',
    '''    # O host central confirma o tema logo após anexar o módulo. No evento de
    # HandleCreated basta acertar o layout; repintar toda a árvore aqui duplicava
    # trabalho exatamente no caminho crítico de abertura.
    $form.Add_HandleCreated({ try { Update-GeneratorResponsiveLayout; Update-RootLayout } catch {} })''',
    'HandleCreated do Gerenciador'
)
write(generator_path, generator)

# ---------------------------------------------------------------------------
# Manutenção: SchemaVersion 4 já é o formato atual. Evita percorrer todas as
# passagens/eventos em cada abertura quando nenhuma migração é necessária.
# ---------------------------------------------------------------------------
maint_core_path = 'src/generated/Modulos/Central-de-Manutencao-CB5/Manutencao.Core.ps1'
maint_core = read(maint_core_path)
old_maint_read = '''function Read-CB5Store {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not [IO.File]::Exists($Path)) {
        throw "O arquivo de dados não foi encontrado: $Path"
    }
    try {
        $raw = [IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8)
        if ([string]::IsNullOrWhiteSpace($raw)) { return New-CB5Store }
        return Normalize-CB5Store ($raw | ConvertFrom-Json)
    }
    catch {
        throw "Não foi possível ler a base da Central de Manutenção. O arquivo foi preservado sem alterações. Detalhe: $($_.Exception.Message)"
    }
}'''
new_maint_read = '''function Read-CB5Store {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not [IO.File]::Exists($Path)) {
        throw "O arquivo de dados não foi encontrado: $Path"
    }
    try {
        $raw = [IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8)
        if ([string]::IsNullOrWhiteSpace($raw)) { return New-CB5Store }
        $store = $raw | ConvertFrom-Json

        # FAST START: um arquivo SchemaVersion 4 foi gravado pelo formato atual
        # e já teve versões, status, eventos e esquemáticos normalizados. Mantém
        # somente as garantias de coleção sem reprocessar todo o histórico.
        $names = @($store.PSObject.Properties.Name)
        $isCurrent = ($names -contains "SchemaVersion") -and
                     ($names -contains "Passagens") -and
                     ($names -contains "Esquematicos") -and
                     ([int]$store.SchemaVersion -eq 4)
        if ($isCurrent) {
            $store.Passagens = @($store.Passagens)
            $store.Esquematicos = @($store.Esquematicos)
            return $store
        }

        # Formatos antigos continuam usando a migração completa existente.
        return Normalize-CB5Store $store
    }
    catch {
        throw "Não foi possível ler a base da Central de Manutenção. O arquivo foi preservado sem alterações. Detalhe: $($_.Exception.Message)"
    }
}'''
maint_core = one(maint_core, old_maint_read, new_maint_read, 'fast path da base de Manutenção')
write(maint_core_path, maint_core)

# Manutenção hospedada: não monta telas invisíveis antes de mostrar o módulo.
maintenance_path = 'src/generated/Modulos/Central-de-Manutencao-CB5/Central Manutencao CB5.ps1'
maintenance = read(maintenance_path)
maintenance = one(maintenance, '$script:AppVersion = "0.6.8"', '$script:AppVersion = "0.6.9"', 'versão Manutenção')
maintenance = one(
    maintenance,
    '$script:HostedThemeSyncInProgress = $false',
    '$script:HostedThemeSyncInProgress = $false\n$script:MaintenanceDataRefreshEnabled = $false',
    'flag de carga sob demanda da Manutenção'
)
maintenance = one(
    maintenance,
    '''function Refresh-AllViews {
    Refresh-Dashboard
    Refresh-HistoryGrid
    Refresh-CurrentSeriesHistory
    Refresh-Statistics
    Refresh-SchematicGrid
}

$settings = Get-MaintenanceSettings''',
    '''function Refresh-AllViews {
    Refresh-Dashboard
    Refresh-HistoryGrid
    Refresh-CurrentSeriesHistory
    Refresh-Statistics
    Refresh-SchematicGrid
}

function Refresh-MaintenanceSelectedView {
    if (-not $script:MaintenanceDataRefreshEnabled) { return }
    if ($mainTabs.SelectedTab -eq $dashboardTab) { Refresh-Dashboard; return }
    if ($mainTabs.SelectedTab -eq $historyTab) { Refresh-HistoryGrid; return }
    if ($mainTabs.SelectedTab -eq $statisticsTab) { Refresh-Statistics; return }
    if ($mainTabs.SelectedTab -eq $schematicsTab) { Refresh-SchematicGrid; return }
    if ($mainTabs.SelectedTab -eq $passageTab) { Refresh-CurrentSeriesHistory; return }
}

$settings = Get-MaintenanceSettings''',
    'carga sob demanda por aba'
)
maintenance = one(
    maintenance,
    '''$mainTabs.Add_SelectedIndexChanged({ Update-MaintenanceInternalNavigation; Update-MaintenanceSectionNavigation })''',
    '''$mainTabs.Add_SelectedIndexChanged({
    Update-MaintenanceInternalNavigation
    Update-MaintenanceSectionNavigation
    Refresh-MaintenanceSelectedView
})''',
    'evento de troca de aba da Manutenção'
)
maintenance = one(
    maintenance,
    '''    Apply-MaintenanceTheme
    Reset-PassageForm
    Refresh-AllViews
    $mainTabs.SelectedTab = $historyTab
    Update-MaintenanceResponsiveLayout
    Update-MaintenanceSectionNavigation''',
    '''    Apply-MaintenanceTheme
    Reset-PassageForm
    # Na Central, a primeira tela é o Histórico. Carregamos somente ela no
    # caminho crítico de abertura; Dashboard/Estatísticas/Esquemáticos são
    # atualizados quando o usuário realmente entra nessas áreas.
    $mainTabs.SelectedTab = $historyTab
    $script:MaintenanceDataRefreshEnabled = $true
    Refresh-MaintenanceSelectedView
    Update-MaintenanceResponsiveLayout
    Update-MaintenanceSectionNavigation''',
    'startup hospedado da Manutenção'
)
write(maintenance_path, maintenance)

print('STARTUP FASTPATH: OK - leitura atual otimizada, repaints redundantes removidos e telas pesadas da Manutenção sob demanda.')
