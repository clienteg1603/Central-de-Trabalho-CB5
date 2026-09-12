from pathlib import Path

R = Path('src/generated')


def load(path):
    return path.read_text(encoding='utf-8-sig')


def save(path, text):
    path.write_text(text, encoding='utf-8')


def one(text, old, new, label):
    n = text.count(old)
    if n != 1:
        raise SystemExit(f'CURA2 GEN {label}: esperado 1, encontrado {n}')
    return text.replace(old, new, 1)


def replace_function(text, name, new_body):
    marker = f'function {name} {{'
    start = text.find(marker)
    if start < 0:
        raise SystemExit(f'CURA2 GEN: função {name} não encontrada')
    nxt = text.find('\nfunction ', start + len(marker))
    if nxt < 0:
        raise SystemExit(f'CURA2 GEN: limite de {name} não encontrado')
    return text[:start] + new_body.rstrip() + '\n\n' + text[nxt + 1:]


# Central: apenas versões. A coordenação central já está na v0.21.28.
p = R / 'Central de Trabalho.ps1'
s = load(p)
s = one(s, '$script:AppVersion = "0.21.28"', '$script:AppVersion = "0.21.29"', 'versão Central')
s = one(s, '$script:GeneratorVersion = "3.7.7"', '$script:GeneratorVersion = "3.7.8"', 'versão Gerenciador na Central')
save(p, s)


# Gerenciador: quando hospedado, o tema da Central passa a ser a única fonte
# de verdade. O ComboBox interno deixa de poder manter um tema antigo.
p = R / 'Modulos/Gerador-de-Planilhas-CB5-TV5/Gerador Planilhas.ps1'
s = load(p)
s = one(s, '$script:AppVersion = "3.7.7"', '$script:AppVersion = "3.7.8"', 'versão Gerenciador')

s = one(
    s,
    '$script:HostedCentralTheme = ""\n$script:HostedThemeSyncInProgress = $false',
    '$script:HostedCentralTheme = $(if ($script:IsInProcessHosted -and -not [string]::IsNullOrWhiteSpace($HostTheme)) { [string]$HostTheme } else { "" })\n$script:HostedThemeSyncInProgress = $false',
    'tema hospedado inicial'
)

# O próprio Apply-AppTheme passa a respeitar sempre o tema do host. Assim,
# mesmo que algum evento interno, configuração salva ou troca de produto tente
# reaplicar a aparência, o Gerenciador volta para o tema escolhido na Central.
marker = 'function Apply-AppTheme {\n    $theme = [string]$themeCombo.SelectedItem\n    if ([string]::IsNullOrWhiteSpace($theme)) { $theme = "Claro moderno" }'
replacement = '''function Apply-AppTheme {
    $theme = [string]$themeCombo.SelectedItem

    if ($script:IsInProcessHosted -and -not [string]::IsNullOrWhiteSpace($script:HostedCentralTheme)) {
        $hostMappedTheme = Get-GeneratorThemeFromHost $script:HostedCentralTheme
        if (-not $themeCombo.Items.Contains($hostMappedTheme)) {
            throw "O tema hospedado '$hostMappedTheme' não existe no Gerenciador."
        }
        if ([string]$themeCombo.SelectedItem -ne $hostMappedTheme) {
            $oldSyncFlag = $script:HostedThemeSyncInProgress
            $script:HostedThemeSyncInProgress = $true
            try { $themeCombo.SelectedItem = $hostMappedTheme }
            finally { $script:HostedThemeSyncInProgress = $oldSyncFlag }
        }
        $theme = $hostMappedTheme
    }

    if ([string]::IsNullOrWhiteSpace($theme)) { $theme = "Claro moderno" }'''
s = one(s, marker, replacement, 'autoridade do host em Apply-AppTheme')

new_setter = r'''function Set-HostedGeneratorTheme {
    param([string]$CentralTheme)
    if (-not $script:IsInProcessHosted) { return $false }
    if ([string]::IsNullOrWhiteSpace($CentralTheme)) { $CentralTheme = "Escuro profissional" }

    $mapped = Get-GeneratorThemeFromHost $CentralTheme
    if (-not $themeCombo.Items.Contains($mapped)) { return $false }

    $script:HostedCentralTheme = $CentralTheme
    $script:HostedThemeSyncInProgress = $true
    try {
        # Atualiza o seletor interno e aplica explicitamente. O evento interno é
        # bloqueado durante esta operação para não criar um segundo ciclo.
        $themeCombo.SelectedItem = $mapped
        if ([string]$themeCombo.SelectedItem -ne $mapped) { return $false }

        Apply-AppTheme
        Update-GeneratorResponsiveLayout
        Update-RootLayout
        $form.PerformLayout()
        $form.Invalidate($true)
        $form.Update()
        $form.Refresh()
        [Windows.Forms.Application]::DoEvents()

        # Validação visual real: não basta o ComboBox ter mudado. A raiz do
        # Gerenciador precisa terminar com a cor da paleta correspondente.
        $product = [string]$productCombo.SelectedItem
        if (@("CB5", "TV5") -notcontains $product) { $product = "CB5" }
        $expectedPalette = Get-ThemePalette $mapped $product
        if ($null -eq $expectedPalette) { return $false }
        if ([int]$form.BackColor.ToArgb() -ne [int]$expectedPalette.Background.ToArgb()) { return $false }

        return $true
    }
    catch {
        return $false
    }
    finally {
        $script:HostedThemeSyncInProgress = $false
    }
}'''
s = replace_function(s, 'Set-HostedGeneratorTheme', new_setter)

# Quando integrado, o ComboBox interno não é fonte de verdade. Evita que um
# SelectedIndexChanged tardio reaplique o tema salvo anteriormente.
old_event = '''$themeCombo.Add_SelectedIndexChanged({
    if ($script:HostedThemeSyncInProgress) { return }
    if ($script:UiReady) {
        Apply-AppTheme
        Save-AppSettings
    }
})'''
new_event = '''$themeCombo.Add_SelectedIndexChanged({
    if ($script:IsInProcessHosted -or $script:HostedThemeSyncInProgress) { return }
    if ($script:UiReady) {
        Apply-AppTheme
        Save-AppSettings
    }
})'''
s = one(s, old_event, new_event, 'evento interno de tema')

save(p, s)

# Contratos do hotfix.
central = load(R / 'Central de Trabalho.ps1')
gen = load(R / 'Modulos/Gerador-de-Planilhas-CB5-TV5/Gerador Planilhas.ps1')
checks = [
    (central, '0.21.29', 'Central 0.21.29'),
    (central, '3.7.8', 'Gerenciador 3.7.8 na Central'),
    (gen, '$script:AppVersion = "3.7.8"', 'Gerenciador 3.7.8'),
    (gen, '$hostMappedTheme = Get-GeneratorThemeFromHost $script:HostedCentralTheme', 'host como autoridade'),
    (gen, 'if ($script:IsInProcessHosted -or $script:HostedThemeSyncInProgress) { return }', 'bloqueio de tema interno hospedado'),
    (gen, '$expectedPalette = Get-ThemePalette $mapped $product', 'validação de paleta'),
    (gen, '$form.BackColor.ToArgb()', 'validação RGB do Gerenciador'),
]
for text, marker, label in checks:
    if marker not in text:
        raise SystemExit(f'CURA2 GEN contrato ausente: {label}')

print('CURA 2 Gerenciador: tema da Central agora é autoridade única — OK')
