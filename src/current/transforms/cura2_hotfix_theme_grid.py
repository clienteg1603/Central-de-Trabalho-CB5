from pathlib import Path

R = Path('src/generated')


def load(path):
    return path.read_text(encoding='utf-8-sig')


def save(path, text):
    path.write_text(text, encoding='utf-8')


def one(text, old, new, label):
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'CURA2 HOTFIX {label}: esperado 1, encontrado {count}')
    return text.replace(old, new, 1)


# Central: apenas versão/referências dos módulos tocados pelo hotfix.
p = R / 'Central de Trabalho.ps1'
s = load(p)
s = one(s, '$script:AppVersion = "0.21.24"', '$script:AppVersion = "0.21.25"', 'versão Central')
s = one(s, '$script:GeneratorVersion = "3.7.6"', '$script:GeneratorVersion = "3.7.7"', 'versão Gerenciador')
s = one(s, '$script:MaintenanceVersion = "0.6.5"', '$script:MaintenanceVersion = "0.6.6"', 'versão Manutenção')
save(p, s)

# Manutenção: evita aplicar o mesmo tema duas vezes quando a Central muda o ComboBox interno.
p = R / 'Modulos/Central-de-Manutencao-CB5/Central Manutencao CB5.ps1'
s = load(p)
s = one(s, '$script:AppVersion = "0.6.5"', '$script:AppVersion = "0.6.6"', 'versão Manutenção módulo')
s = one(s, '$script:HostedCentralTheme = ""', '$script:HostedCentralTheme = ""\n$script:HostedThemeSyncInProgress = $false', 'flag sync Manutenção')
old = '''    $script:HostedCentralTheme = $CentralTheme
    if ([string]$themeCombo.SelectedItem -ne $mapped) {
        $themeCombo.SelectedItem = $mapped
    }

    Apply-MaintenanceTheme
    Update-MaintenanceResponsiveLayout
    $form.PerformLayout()
    $form.Invalidate($true)
    $form.Update()
    return $true'''
new = '''    $script:HostedCentralTheme = $CentralTheme
    $script:HostedThemeSyncInProgress = $true
    try {
        if ([string]$themeCombo.SelectedItem -ne $mapped) {
            $themeCombo.SelectedItem = $mapped
        }

        Apply-MaintenanceTheme
        Update-MaintenanceResponsiveLayout
        $form.PerformLayout()
        $form.Invalidate($true)
        $form.Update()
        return $true
    }
    finally {
        $script:HostedThemeSyncInProgress = $false
    }'''
s = one(s, old, new, 'setter Manutenção sem reentrada')
s = one(
    s,
    '$themeCombo.Add_SelectedIndexChanged({ Apply-MaintenanceTheme; Update-MaintenanceResponsiveLayout; Update-MaintenanceInternalNavigation; Save-MaintenanceSettings })',
    '''$themeCombo.Add_SelectedIndexChanged({
    if ($script:HostedThemeSyncInProgress) { return }
    Apply-MaintenanceTheme
    Update-MaintenanceResponsiveLayout
    Update-MaintenanceInternalNavigation
    Save-MaintenanceSettings
})''',
    'evento Manutenção sem reentrada'
)
save(p, s)

# Gerenciador: a troca de aparência não pode recarregar dados em uma grade ainda sem colunas.
p = R / 'Modulos/Gerador-de-Planilhas-CB5-TV5/Gerador Planilhas.ps1'
s = load(p)
s = one(s, '$script:AppVersion = "3.7.6"', '$script:AppVersion = "3.7.7"', 'versão Gerenciador módulo')
s = one(s, '$script:HostedCentralTheme = ""', '$script:HostedCentralTheme = ""\n$script:HostedThemeSyncInProgress = $false', 'flag sync Gerenciador')
old = '''    $script:HostedCentralTheme = $CentralTheme
    if ([string]$themeCombo.SelectedItem -ne $mapped) {
        $themeCombo.SelectedItem = $mapped
    }

    Apply-AppTheme
    Update-GeneratorResponsiveLayout
    Update-RootLayout
    $form.PerformLayout()
    $form.Invalidate($true)
    $form.Update()
    return $true'''
new = '''    $script:HostedCentralTheme = $CentralTheme
    $script:HostedThemeSyncInProgress = $true
    try {
        if ([string]$themeCombo.SelectedItem -ne $mapped) {
            $themeCombo.SelectedItem = $mapped
        }

        Apply-AppTheme
        Update-GeneratorResponsiveLayout
        Update-RootLayout
        $form.PerformLayout()
        $form.Invalidate($true)
        $form.Update()
        return $true
    }
    finally {
        $script:HostedThemeSyncInProgress = $false
    }'''
s = one(s, old, new, 'setter Gerenciador sem reentrada')
s = one(
    s,
    '''$themeCombo.Add_SelectedIndexChanged({
    if ($script:UiReady) {
        Apply-AppTheme
        Save-AppSettings
    }
})''',
    '''$themeCombo.Add_SelectedIndexChanged({
    if ($script:HostedThemeSyncInProgress) { return }
    if ($script:UiReady) {
        Apply-AppTheme
        Save-AppSettings
    }
})''',
    'evento Gerenciador sem reentrada'
)

# Apply-AppTheme permanece visual; atualizações de dados só rodam quando a UI está pronta
# e a grade de componentes já possui colunas.
s = one(
    s,
    '''    Update-RootLayout
    $tabs.Invalidate()
    $componentTabs.Invalidate()
    Update-LiveSummary
    Update-CombineSummary
    Update-BillingComponentsView
}''',
    '''    Update-RootLayout
    $tabs.Invalidate()
    $componentTabs.Invalidate()
    if ($script:UiReady) {
        Update-LiveSummary
        Update-CombineSummary
        if ($null -ne $componentGrid -and $componentGrid.Columns.Count -gt 0) {
            Update-BillingComponentsView
        }
    }
}''',
    'tema Gerenciador sem recarga prematura'
)

# Defesa adicional: qualquer chamada futura à atualização da grade simplesmente aguarda
# a criação das colunas em vez de lançar exceção.
s = one(
    s,
    '''function Update-BillingComponentsView {
    $selectedId = ""''',
    '''function Update-BillingComponentsView {
    if ($componentGrid.Columns.Count -eq 0 -or $componentHistoryGrid.Columns.Count -eq 0 -or $componentOperationsGrid.Columns.Count -eq 0) {
        return
    }
    $selectedId = ""''',
    'guarda de colunas do faturamento'
)
save(p, s)

# Contratos do hotfix.
central = load(R / 'Central de Trabalho.ps1')
maintenance = load(R / 'Modulos/Central-de-Manutencao-CB5/Central Manutencao CB5.ps1')
generator = load(R / 'Modulos/Gerador-de-Planilhas-CB5-TV5/Gerador Planilhas.ps1')
for text, marker, label in [
    (central, '0.21.25', 'Central 0.21.25'),
    (central, '3.7.7', 'referência Gerenciador 3.7.7'),
    (central, '0.6.6', 'referência Manutenção 0.6.6'),
    (maintenance, '$script:HostedThemeSyncInProgress', 'flag Manutenção'),
    (generator, '$script:HostedThemeSyncInProgress', 'flag Gerenciador'),
    (generator, '$componentGrid.Columns.Count -eq 0', 'guarda DataGridView'),
    (generator, 'if ($script:UiReady) {\n        Update-LiveSummary', 'tema sem recarga prematura'),
]:
    if marker not in text:
        raise SystemExit(f'CURA2 HOTFIX contrato ausente: {label}')

print('CURA 2 HOTFIX OK: tema não recarrega grid sem colunas; Central 0.21.25 / Manutenção 0.6.6 / Gerenciador 3.7.7')
