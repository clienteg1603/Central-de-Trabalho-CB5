from pathlib import Path

cp = Path('src/generated/Central de Trabalho.ps1')
mp = Path('src/generated/Modulos/Central-de-Manutencao-CB5/Central Manutencao CB5.ps1')

c = cp.read_text(encoding='utf-8-sig')
m = mp.read_text(encoding='utf-8-sig')


def one(text, old, new, label):
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'MAINT OVERVIEW REFRESH {label}: esperado 1, encontrado {count}')
    return text.replace(old, new, 1)

# Versões — Teste.
c = one(c, '$script:AppVersion = "0.21.63"', '$script:AppVersion = "0.21.64"', 'versao Central')
c = one(c, '$script:MaintenanceVersion = "0.6.16"', '$script:MaintenanceVersion = "0.6.17"', 'versao Manutencao Central')
m = one(m, '$script:AppVersion = "0.6.16"', '$script:AppVersion = "0.6.17"', 'versao modulo')

# A GERAL 2 manteve os quatro cards de resumo permanentemente visíveis no modo
# hospedado, enquanto o fast-start passou a carregar apenas a aba selecionada.
# Quando a primeira aba é Histórico, Refresh-Dashboard não roda e os cards ficam
# nos zeros de criação. Separar a parte leve do resumo resolve sem perder o fast-start.
overview_function = r'''
function Refresh-MaintenanceOverview {
    if ($null -eq $script:Store) { return }
    $summary = Get-CB5Summary -Store $script:Store
    if ($null -ne $seriesValue) { $seriesValue.Text = [string]$summary.Series }
    if ($null -ne $passagesValue) { $passagesValue.Text = [string]$summary.Passagens }
    if ($null -ne $openValue) { $openValue.Text = [string]$summary.EmAndamento }
    if ($null -ne $returnsValue) { $returnsValue.Text = [string]$summary.Retornos }
}

'''

m = one(
    m,
    'function Refresh-HistoryGrid {',
    overview_function + 'function Refresh-HistoryGrid {',
    'funcao resumo leve'
)

old_selected = '''function Refresh-MaintenanceSelectedView {
    if (-not $script:MaintenanceDataRefreshEnabled) { return }
    if ($mainTabs.SelectedTab -eq $dashboardTab) { Refresh-Dashboard; return }
    if ($mainTabs.SelectedTab -eq $historyTab) { Refresh-HistoryGrid; return }
    if ($mainTabs.SelectedTab -eq $statisticsTab) { Refresh-Statistics; return }
    if ($mainTabs.SelectedTab -eq $schematicsTab) { Refresh-SchematicGrid; return }
    if ($mainTabs.SelectedTab -eq $passageTab) { Refresh-CurrentSeriesHistory; return }
}'''
new_selected = '''function Refresh-MaintenanceSelectedView {
    if (-not $script:MaintenanceDataRefreshEnabled) { return }

    # Os cards do topo ficam visíveis em todas as seções hospedadas; portanto
    # acompanham a base em toda troca de aba, não apenas quando Dashboard abre.
    Refresh-MaintenanceOverview

    if ($mainTabs.SelectedTab -eq $dashboardTab) { Refresh-Dashboard; return }
    if ($mainTabs.SelectedTab -eq $historyTab) { Refresh-HistoryGrid; return }
    if ($mainTabs.SelectedTab -eq $statisticsTab) { Refresh-Statistics; return }
    if ($mainTabs.SelectedTab -eq $schematicsTab) { Refresh-SchematicGrid; return }
    if ($mainTabs.SelectedTab -eq $passageTab) { Refresh-CurrentSeriesHistory; return }
}'''
m = one(m, old_selected, new_selected, 'refresh por aba')

# Também sincroniza os cards em qualquer rotina de refresh geral, inclusive após
# salvar/editar/excluir uma passagem.
old_all = '''function Refresh-AllViews {
    Refresh-Dashboard
    Refresh-HistoryGrid
    Refresh-CurrentSeriesHistory
    Refresh-Statistics
    Refresh-SchematicGrid
}'''
new_all = '''function Refresh-AllViews {
    Refresh-MaintenanceOverview
    Refresh-Dashboard
    Refresh-HistoryGrid
    Refresh-CurrentSeriesHistory
    Refresh-Statistics
    Refresh-SchematicGrid
}'''
m = one(m, old_all, new_all, 'refresh geral')

# Contratos locais: a função leve precisa usar a mesma fonte real da tela de
# Histórico e ocorrer antes do refresh seletivo do Histórico.
if 'Get-CB5Summary -Store $script:Store' not in m:
    raise SystemExit('MAINT OVERVIEW REFRESH: resumo não usa a Store real')
selected_start = m.find('function Refresh-MaintenanceSelectedView {')
selected_end = m.find('\n}', selected_start)
selected_block = m[selected_start:selected_end + 2]
if selected_block.find('Refresh-MaintenanceOverview') < 0:
    raise SystemExit('MAINT OVERVIEW REFRESH: resumo não está no refresh seletivo')
if selected_block.find('Refresh-MaintenanceOverview') > selected_block.find('Refresh-HistoryGrid'):
    raise SystemExit('MAINT OVERVIEW REFRESH: resumo ocorre depois do Histórico')

c += '\n# MAINTENANCE_OVERVIEW_REFRESH_V02164\n'
m += '\n# MAINTENANCE_OVERVIEW_REFRESH_V00617\n'

for marker in ('$script:AppVersion = "0.21.64"', '$script:MaintenanceVersion = "0.6.17"', 'MAINTENANCE_OVERVIEW_REFRESH_V02164'):
    if marker not in c:
        raise SystemExit('MAINT OVERVIEW REFRESH Central marcador ausente: ' + marker)
for marker in ('$script:AppVersion = "0.6.17"', 'function Refresh-MaintenanceOverview', 'Refresh-MaintenanceOverview', 'MAINTENANCE_OVERVIEW_REFRESH_V00617'):
    if marker not in m:
        raise SystemExit('MAINT OVERVIEW REFRESH modulo marcador ausente: ' + marker)

cp.write_text(c, encoding='utf-8')
mp.write_text(m, encoding='utf-8')
print('MAINT OVERVIEW REFRESH: OK - cards do topo acompanham a Store mesmo quando Histórico é a primeira aba.')
