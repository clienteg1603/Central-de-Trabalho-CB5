from pathlib import Path

R = Path('src/generated')


def load(path):
    return path.read_text(encoding='utf-8-sig')


def save(path, text):
    path.write_text(text, encoding='utf-8')


def one(text, old, new, label):
    n = text.count(old)
    if n != 1:
        raise SystemExit(f'CURA2 runtime {label}: esperado 1, encontrado {n}')
    return text.replace(old, new, 1)

# 1) Manutenção: não pode confirmar tema se a raiz continuar com a cor padrão do Windows.
p = R / 'Modulos/Central-de-Manutencao-CB5/Central Manutencao CB5.ps1'
s = load(p)
s = one(
    s,
    '''        Apply-MaintenanceTheme\n        Update-MaintenanceResponsiveLayout\n        $form.PerformLayout()\n        $form.Invalidate($true)\n        $form.Update()\n        return $true''',
    '''        Apply-MaintenanceTheme\n        # A raiz precisa receber a paleta explicitamente. O teste runtime encontrou\n        # casos em que a árvore interna mudava, mas o Form permanecia no cinza padrão.\n        $script:CurrentPalette = Get-MaintenancePalette $mapped\n        $form.BackColor = $script:CurrentPalette.Background\n        $form.ForeColor = $script:CurrentPalette.Text\n        Update-MaintenanceResponsiveLayout\n        $form.PerformLayout()\n        $form.Invalidate($true)\n        $form.Update()\n        $form.Refresh()\n        [Windows.Forms.Application]::DoEvents()\n        if ([int]$form.BackColor.ToArgb() -ne [int]$script:CurrentPalette.Background.ToArgb()) { return $false }\n        return $true''',
    'raiz Manutenção'
)
save(p, s)

# 2) Central: adiciona um modo interno de autoteste visual que usa o MESMO fluxo de evento,
# Start-EmbeddedModule e Sync-HostedModuleTheme usado pelo usuário.
p = R / 'Central de Trabalho.ps1'
s = load(p)
if not s.startswith('param('):
    s = '''param(\n    [switch]$ThemeRuntimeSelfTest\n)\n\n''' + s
elif 'ThemeRuntimeSelfTest' not in s[:500]:
    raise SystemExit('CURA2 runtime: Central já possui param inesperado; revisar manualmente')

marker = '# Eventos\n'
if marker not in s:
    raise SystemExit('CURA2 runtime: marcador de eventos da Central não encontrado')

selftest = r'''function Invoke-CentralThemeRuntimeSelfTest {
    $themes = @("Escuro profissional", "Técnico industrial", "Claro corporativo", "Alto contraste")
    $modules = @("Generator", "Maintenance", "NFEntrada")

    $form.StartPosition = [Windows.Forms.FormStartPosition]::Manual
    $form.Location = [Drawing.Point]::new(-2200, -2200)
    $form.ShowInTaskbar = $false
    $form.Show()
    [Windows.Forms.Application]::DoEvents()

    try {
        foreach ($moduleName in $modules) {
            Write-Host "CENTRAL THEME TEST: abrindo $moduleName"
            Start-EmbeddedModule $moduleName
            [Windows.Forms.Application]::DoEvents()
            if ($script:EmbeddedModule -ne $moduleName -or $null -eq $script:HostedModule -or $null -eq $script:HostedForm) {
                throw "A Central não conseguiu hospedar $moduleName no autoteste de aparência."
            }

            foreach ($themeName in $themes) {
                Write-Host "CENTRAL THEME TEST: $moduleName -> $themeName"
                $themeCombo.SelectedItem = $themeName
                [Windows.Forms.Application]::DoEvents()

                if ((Get-CentralSelectedTheme) -ne $themeName) {
                    throw "O seletor da Central não permaneceu em '$themeName'."
                }
                $expectedCentral = Get-ThemePalette $themeName
                $expectedSidebar = Get-SidebarColor $themeName
                if ([int]$form.BackColor.ToArgb() -ne [int]$expectedCentral.Background.ToArgb()) {
                    throw "A raiz da Central não recebeu '$themeName'."
                }
                if ([int]$sidebar.BackColor.ToArgb() -ne [int]$expectedSidebar.ToArgb()) {
                    throw "A barra lateral da Central não recebeu '$themeName'."
                }

                $state = & $script:HostedModule {
                    param($targetModule, $hostTheme)
                    switch ($targetModule) {
                        "Generator" {
                            $mapped = Get-GeneratorThemeFromHost $hostTheme
                            $product = [string]$productCombo.SelectedItem
                            if (@("CB5", "TV5") -notcontains $product) { $product = "CB5" }
                            $p = Get-ThemePalette $mapped $product
                            return [pscustomobject]@{
                                Combo = [string]$themeCombo.SelectedItem
                                ExpectedCombo = $mapped
                                Root = [int]$form.BackColor.ToArgb()
                                ExpectedRoot = [int]$p.Background.ToArgb()
                            }
                        }
                        "Maintenance" {
                            $mapped = Get-MaintenanceThemeFromHost $hostTheme
                            $p = Get-MaintenancePalette $mapped
                            return [pscustomobject]@{
                                Combo = [string]$themeCombo.SelectedItem
                                ExpectedCombo = $mapped
                                Root = [int]$form.BackColor.ToArgb()
                                ExpectedRoot = [int]$p.Background.ToArgb()
                            }
                        }
                        "NFEntrada" {
                            $p = Get-NFEntradaPalette $hostTheme
                            return [pscustomobject]@{
                                Combo = $hostTheme
                                ExpectedCombo = $hostTheme
                                Root = [int]$form.BackColor.ToArgb()
                                ExpectedRoot = [int]$p.Background.ToArgb()
                            }
                        }
                    }
                } $moduleName $themeName

                if ($null -eq $state) { throw "$moduleName não retornou estado visual." }
                if ($state.Combo -ne $state.ExpectedCombo) {
                    throw "$moduleName não acompanhou o seletor em '$themeName': '$($state.Combo)' != '$($state.ExpectedCombo)'."
                }
                if ($state.Root -ne $state.ExpectedRoot) {
                    $detail = if ([string]::IsNullOrWhiteSpace($script:LastThemeSyncError)) { "sem detalhe de sincronização" } else { $script:LastThemeSyncError }
                    throw "$moduleName não acompanhou a paleta em '$themeName': $($state.Root) != $($state.ExpectedRoot). $detail"
                }
            }

            Close-EmbeddedModule -Force
            [Windows.Forms.Application]::DoEvents()
        }
        Write-Host "CENTRAL THEME RUNTIME: OK — Central + 3 módulos x 4 temas."
    }
    finally {
        try { Close-EmbeddedModule -Force } catch {}
        try { $form.Hide() } catch {}
        try { $form.Close() } catch {}
    }
}

'''
if 'function Invoke-CentralThemeRuntimeSelfTest' not in s:
    s = s.replace(marker, selftest + marker, 1)

s = one(
    s,
    '''    Apply-CentralTheme\n    [void]$form.ShowDialog()''',
    '''    Apply-CentralTheme\n    if ($ThemeRuntimeSelfTest) {\n        Invoke-CentralThemeRuntimeSelfTest\n        return\n    }\n    [void]$form.ShowDialog()''',
    'chamada do autoteste central'
)
save(p, s)

# Contratos mínimos.
central = load(R / 'Central de Trabalho.ps1')
maint = load(R / 'Modulos/Central-de-Manutencao-CB5/Central Manutencao CB5.ps1')
for marker, label in [
    ('[switch]$ThemeRuntimeSelfTest', 'switch selftest'),
    ('function Invoke-CentralThemeRuntimeSelfTest', 'função selftest'),
    ('CENTRAL THEME RUNTIME: OK', 'marcador selftest'),
]:
    if marker not in central:
        raise SystemExit(f'CURA2 runtime contrato Central ausente: {label}')
if '$form.BackColor = $script:CurrentPalette.Background' not in maint:
    raise SystemExit('CURA2 runtime contrato Manutenção ausente: raiz explícita')

print('CURA 2 runtime contract — OK')
