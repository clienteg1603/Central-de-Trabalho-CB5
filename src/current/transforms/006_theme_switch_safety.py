from pathlib import Path

ROOT = Path('src/generated')
central_path = ROOT / 'Central de Trabalho.ps1'
maint_path = ROOT / 'Modulos/Central-de-Manutencao-CB5/Central Manutencao CB5.ps1'
gen_path = ROOT / 'Modulos/Gerador-de-Planilhas-CB5-TV5/Gerador Planilhas.ps1'

central = central_path.read_text(encoding='utf-8-sig')
maint = maint_path.read_text(encoding='utf-8-sig')
gen = gen_path.read_text(encoding='utf-8-sig')


def one(text, old, new, label):
    n = text.count(old)
    if n != 1:
        raise RuntimeError(f'{label}: esperado 1 trecho, encontrado {n}')
    return text.replace(old, new, 1)

# Versões
central = one(central, '$script:AppVersion = "0.12.1"', '$script:AppVersion = "0.12.2"', 'versão Central')
central = one(central, '$script:GeneratorVersion = "3.5.0"', '$script:GeneratorVersion = "3.5.1"', 'versão Gerenciador na Central')
central = one(central, '$script:MaintenanceVersion = "0.5.6"', '$script:MaintenanceVersion = "0.5.7"', 'versão Manutenção na Central')
maint = one(maint, '$script:AppVersion = "0.5.6"', '$script:AppVersion = "0.5.7"', 'versão Manutenção')
gen = one(gen, '$script:AppVersion = "3.5.0"', '$script:AppVersion = "3.5.1"', 'versão Gerenciador')

# ---------------------------------------------------------------------------
# Central: só tenta sincronizar tema com módulo realmente vivo e hospedado.
# Isso evita que uma referência de módulo já fechada/disposta receba mudança de tema.
# ---------------------------------------------------------------------------
old_sync_guard = '    if ($null -eq $script:HostedModule -or [string]::IsNullOrWhiteSpace($script:EmbeddedModule)) { return }'
new_sync_guard = '''    if ($null -eq $script:HostedModule -or [string]::IsNullOrWhiteSpace($script:EmbeddedModule)) { return }
    if ($null -eq $script:HostedForm) { return }
    try {
        if ($script:HostedForm.IsDisposed -or $script:HostedForm.Disposing -or $null -eq $script:HostedForm.Parent) { return }
    }
    catch { return }'''
central = one(central, old_sync_guard, new_sync_guard, 'proteção de módulo hospedado')

old_theme_event = '$themeCombo.Add_SelectedIndexChanged({ Apply-AppTheme; Sync-HostedModuleTheme; Save-AppSettings })'
new_theme_event = '''$themeCombo.Add_SelectedIndexChanged({
    # A aparência da Central deve sempre mudar mesmo que um módulo hospedado
    # esteja em processo de fechamento. Erro de tema de módulo não pode abrir
    # a caixa de exceção do WinForms nem interromper a troca de aparência.
    try {
        Apply-AppTheme
        Save-AppSettings
    }
    catch {
        try { Set-StatusMessage "Não foi possível aplicar completamente a aparência da Central." "Error" } catch {}
        return
    }
    try { Sync-HostedModuleTheme }
    catch {
        try { Set-StatusMessage "A aparência da Central foi aplicada; o módulo aberto será atualizado ao reabrir." "Warning" } catch {}
    }
})'''
central = one(central, old_theme_event, new_theme_event, 'evento seguro de aparência')

# ---------------------------------------------------------------------------
# Manutenção: o GridColor foi exatamente a propriedade reportada na exceção.
# DataGridView descartado ou em descarte não deve receber atualização visual.
# O setter também fica isolado porque WinForms pode lançar durante recriação do handle.
# ---------------------------------------------------------------------------
old_maint_grid = '''    elseif ($Control -is [Windows.Forms.DataGridView]) {
        $Control.BackgroundColor = $script:CurrentPalette.Card
        $Control.GridColor = $script:CurrentPalette.Border'''
new_maint_grid = '''    elseif ($Control -is [Windows.Forms.DataGridView]) {
        if ($Control.IsDisposed -or $Control.Disposing) { return }
        $Control.BackgroundColor = $script:CurrentPalette.Card
        try { $Control.GridColor = $script:CurrentPalette.Border } catch {}'''
maint = one(maint, old_maint_grid, new_maint_grid, 'GridColor seguro da Manutenção')

# Não deixa a recursão de tema tocar controles já descartados.
old_tree_start = '''function Apply-ThemeToTree {
    param([Windows.Forms.Control]$Control)

    if ($Control -is [Windows.Forms.Form] -or $Control -is [Windows.Forms.TabPage]) {'''
new_tree_start = '''function Apply-ThemeToTree {
    param([Windows.Forms.Control]$Control)

    if ($null -eq $Control) { return }
    try { if ($Control.IsDisposed -or $Control.Disposing) { return } } catch { return }

    if ($Control -is [Windows.Forms.Form] -or $Control -is [Windows.Forms.TabPage]) {'''
maint = one(maint, old_tree_start, new_tree_start, 'árvore de tema segura da Manutenção')

# ---------------------------------------------------------------------------
# Gerenciador: mesma defesa no Set-GridTheme, pois ele também acompanha o tema
# da Central e usa DataGridView em várias telas.
# ---------------------------------------------------------------------------
old_gen_grid = '''function Set-GridTheme {
    param($Grid, $Palette)
    $Grid.EnableHeadersVisualStyles = $false
    $Grid.BackgroundColor = $Palette.Surface
    $Grid.GridColor = $Palette.Border'''
new_gen_grid = '''function Set-GridTheme {
    param($Grid, $Palette)
    if ($null -eq $Grid -or $null -eq $Palette) { return }
    try { if ($Grid.IsDisposed -or $Grid.Disposing) { return } } catch { return }
    $Grid.EnableHeadersVisualStyles = $false
    $Grid.BackgroundColor = $Palette.Surface
    try { $Grid.GridColor = $Palette.Border } catch {}'''
gen = one(gen, old_gen_grid, new_gen_grid, 'GridColor seguro do Gerenciador')

# Checagens mínimas antes de gravar.
checks = [
    ('$script:AppVersion = "0.12.2"' in central, 'Central 0.12.2 ausente'),
    ('$script:MaintenanceVersion = "0.5.7"' in central, 'referência Manutenção 0.5.7 ausente'),
    ('$script:GeneratorVersion = "3.5.1"' in central, 'referência Gerenciador 3.5.1 ausente'),
    ('IsDisposed -or $script:HostedForm.Disposing' in central, 'proteção de módulo hospedado ausente'),
    ('try { Sync-HostedModuleTheme }' in central, 'sincronização segura ausente'),
    ('try { $Control.GridColor = $script:CurrentPalette.Border } catch {}' in maint, 'proteção GridColor Manutenção ausente'),
    ('try { $Grid.GridColor = $Palette.Border } catch {}' in gen, 'proteção GridColor Gerenciador ausente'),
]
for ok, msg in checks:
    if not ok:
        raise RuntimeError(msg)

central_path.write_text(central, encoding='utf-8-sig')
maint_path.write_text(maint, encoding='utf-8-sig')
gen_path.write_text(gen, encoding='utf-8-sig')
print('OK: proteção de troca de aparência aplicada à Central, Manutenção e Gerenciador')
