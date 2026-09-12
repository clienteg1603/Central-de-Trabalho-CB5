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

# 1) GERENCIADOR — aparência precisa ser uma operação puramente visual.
# Antes, Apply-AppTheme também atualizava resumo, união e a grade de componentes.
# Em bases reais, qualquer exceção nessas rotinas de dados abortava a troca de tema
# e deixava a Central em um tema e o módulo em outro.
p = R / 'Modulos/Gerador-de-Planilhas-CB5-TV5/Gerador Planilhas.ps1'
s = load(p)
s = one(
    s,
    '''    if ($script:UiReady) {\n        Update-LiveSummary\n        Update-CombineSummary\n        if ($null -ne $componentGrid -and $componentGrid.Columns.Count -gt 0) {\n            Update-BillingComponentsView\n        }\n    }''',
    '''    # Aparência não recarrega dados. Resumos, união e componentes são\n    # atualizados apenas pelos seus próprios eventos operacionais. Isso impede\n    # que uma falha de dados interrompa uma troca puramente visual.''',
    'desacoplamento visual do Gerenciador'
)

# Valida também controles internos que aparecem no print do usuário.
s = one(
    s,
    '''        if ($null -eq $expectedPalette) { return $false }\n        if ([int]$form.BackColor.ToArgb() -ne [int]$expectedPalette.Background.ToArgb()) { return $false }\n\n        return $true''',
    '''        if ($null -eq $expectedPalette) { return $false }\n        if ([int]$form.BackColor.ToArgb() -ne [int]$expectedPalette.Background.ToArgb()) { return $false }\n        if ([int]$headerPanel.BackColor.ToArgb() -ne [int]$expectedPalette.Surface.ToArgb()) { return $false }\n        if ([int]$masterCard.BackColor.ToArgb() -ne [int]$expectedPalette.Surface.ToArgb()) { return $false }\n        if ([int]$infoBox.BackColor.ToArgb() -ne [int]$expectedPalette.Info.ToArgb()) { return $false }\n        if ([int]$tabGenerate.BackColor.ToArgb() -ne [int]$expectedPalette.Background.ToArgb()) { return $false }\n\n        return $true''',
    'validação interna do Gerenciador'
)
save(p, s)

# 2) MANUTENÇÃO — não pode confirmar tema se a raiz continuar no cinza padrão.
p = R / 'Modulos/Central-de-Manutencao-CB5/Central Manutencao CB5.ps1'
s = load(p)
s = one(
    s,
    '''        Apply-MaintenanceTheme\n        Update-MaintenanceResponsiveLayout\n        $form.PerformLayout()\n        $form.Invalidate($true)\n        $form.Update()\n        return $true''',
    '''        Apply-MaintenanceTheme\n        # A raiz precisa receber a paleta explicitamente. O teste runtime encontrou\n        # casos em que a árvore interna mudava, mas o Form permanecia no cinza padrão.\n        $script:CurrentPalette = Get-MaintenancePalette $mapped\n        $form.BackColor = $script:CurrentPalette.Background\n        $form.ForeColor = $script:CurrentPalette.Text\n        Update-MaintenanceResponsiveLayout\n        $form.PerformLayout()\n        $form.Invalidate($true)\n        $form.Update()\n        $form.Refresh()\n        [Windows.Forms.Application]::DoEvents()\n        if ([int]$form.BackColor.ToArgb() -ne [int]$script:CurrentPalette.Background.ToArgb()) { return $false }\n        return $true''',
    'raiz Manutenção'
)
save(p, s)

# 3) NF ENTRADA — em modo integrado, erros de inicialização precisam subir para a
# Central em vez de abrir MessageBox modal invisível. Isso também torna o teste runtime
# determinístico e evita uma janela escondida travar a Central.
p = R / 'Modulos/Controle-NF-Entrada/Controle NF Entrada.ps1'
s = load(p)
s = one(
    s,
    '''if (-not [IO.File]::Exists($script:CorePath)) {\n    [Windows.Forms.MessageBox]::Show(\n        "O núcleo do Controle de NF de Entrada não foi encontrado.`r`n`r`n$($script:CorePath)",\n        "Controle de NF de Entrada",\n        [Windows.Forms.MessageBoxButtons]::OK,\n        [Windows.Forms.MessageBoxIcon]::Error\n    ) | Out-Null\n    return\n}''',
    '''if (-not [IO.File]::Exists($script:CorePath)) {\n    $message = "O núcleo do Controle de NF de Entrada não foi encontrado.`r`n`r`n$($script:CorePath)"\n    if ($script:IsInProcessHosted) { throw $message }\n    [Windows.Forms.MessageBox]::Show(\n        $message,\n        "Controle de NF de Entrada",\n        [Windows.Forms.MessageBoxButtons]::OK,\n        [Windows.Forms.MessageBoxIcon]::Error\n    ) | Out-Null\n    return\n}''',
    'erro de core NF hospedado'
)
s = one(
    s,
    '''catch {\n    [Windows.Forms.MessageBox]::Show(\n        "Não foi possível preparar a base do Controle de NF de Entrada.`r`n`r`n$($_.Exception.Message)",\n        "Controle de NF de Entrada — base preservada",\n        [Windows.Forms.MessageBoxButtons]::OK,\n        [Windows.Forms.MessageBoxIcon]::Error\n    ) | Out-Null\n    return\n}\n\nfunction Get-NFEntradaPalette''',
    '''catch {\n    $message = "Não foi possível preparar a base do Controle de NF de Entrada.`r`n`r`n$($_.Exception.Message)"\n    if ($script:IsInProcessHosted) { throw $message }\n    [Windows.Forms.MessageBox]::Show(\n        $message,\n        "Controle de NF de Entrada — base preservada",\n        [Windows.Forms.MessageBoxButtons]::OK,\n        [Windows.Forms.MessageBoxIcon]::Error\n    ) | Out-Null\n    return\n}\n\nfunction Get-NFEntradaPalette''',
    'erro de base NF hospedado'
)
save(p, s)

# 4) CENTRAL — autoteste visual pelo MESMO fluxo usado pelo usuário.
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

            # Reproduz o cenário real do print: Gerenciador aberto em TV5.
            if ($moduleName -eq "Generator") {
                & $script:HostedModule {
                    if ([string]$productCombo.SelectedItem -ne "TV5") { $productCombo.SelectedItem = "TV5" }
                }
                [Windows.Forms.Application]::DoEvents()
            }

            foreach ($themeName in $themes) {
                Write-Host "CENTRAL THEME TEST: $moduleName -> $themeName"
                $themeCombo.SelectedItem = $themeName

                # Mantém o loop de mensagens ativo por tempo suficiente para capturar
                # timers/eventos tardios que poderiam reaplicar a aparência anterior.
                for ($wait = 0; $wait -lt 6; $wait++) {
                    [Windows.Forms.Application]::DoEvents()
                    Start-Sleep -Milliseconds 100
                }

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
                                HostTheme = [string]$script:HostedCentralTheme
                                Root = [int]$form.BackColor.ToArgb()
                                ExpectedRoot = [int]$p.Background.ToArgb()
                                Header = [int]$headerPanel.BackColor.ToArgb()
                                ExpectedHeader = [int]$p.Surface.ToArgb()
                                Card = [int]$masterCard.BackColor.ToArgb()
                                ExpectedCard = [int]$p.Surface.ToArgb()
                                Info = [int]$infoBox.BackColor.ToArgb()
                                ExpectedInfo = [int]$p.Info.ToArgb()
                                Page = [int]$tabGenerate.BackColor.ToArgb()
                                ExpectedPage = [int]$p.Background.ToArgb()
                            }
                        }
                        "Maintenance" {
                            $mapped = Get-MaintenanceThemeFromHost $hostTheme
                            $p = Get-MaintenancePalette $mapped
                            return [pscustomobject]@{
                                Combo = [string]$themeCombo.SelectedItem
                                ExpectedCombo = $mapped
                                HostTheme = [string]$script:HostedCentralTheme
                                Root = [int]$form.BackColor.ToArgb()
                                ExpectedRoot = [int]$p.Background.ToArgb()
                            }
                        }
                        "NFEntrada" {
                            $p = Get-NFEntradaPalette $hostTheme
                            return [pscustomobject]@{
                                Combo = $hostTheme
                                ExpectedCombo = $hostTheme
                                HostTheme = $hostTheme
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
                if ($moduleName -ne "NFEntrada" -and $state.HostTheme -ne $themeName) {
                    throw "$moduleName perdeu a autoridade do tema da Central: '$($state.HostTheme)' != '$themeName'."
                }
                if ($state.Root -ne $state.ExpectedRoot) {
                    $detail = if ([string]::IsNullOrWhiteSpace($script:LastThemeSyncError)) { "sem detalhe de sincronização" } else { $script:LastThemeSyncError }
                    throw "$moduleName não acompanhou a paleta em '$themeName': $($state.Root) != $($state.ExpectedRoot). $detail"
                }
                if ($moduleName -eq "Generator") {
                    if ($state.Header -ne $state.ExpectedHeader) { throw "Gerenciador: cabeçalho não acompanhou '$themeName'." }
                    if ($state.Card -ne $state.ExpectedCard) { throw "Gerenciador: card principal não acompanhou '$themeName'." }
                    if ($state.Info -ne $state.ExpectedInfo) { throw "Gerenciador: aviso informativo não acompanhou '$themeName'." }
                    if ($state.Page -ne $state.ExpectedPage) { throw "Gerenciador: página Gerar não acompanhou '$themeName'." }
                }
            }

            Close-EmbeddedModule -Force
            [Windows.Forms.Application]::DoEvents()
        }
        Write-Host "CENTRAL THEME RUNTIME: OK — Central + 3 módulos x 4 temas, com validação tardia."
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
gen = load(R / 'Modulos/Gerador-de-Planilhas-CB5-TV5/Gerador Planilhas.ps1')
maint = load(R / 'Modulos/Central-de-Manutencao-CB5/Central Manutencao CB5.ps1')
nf = load(R / 'Modulos/Controle-NF-Entrada/Controle NF Entrada.ps1')
for marker, label in [
    ('[switch]$ThemeRuntimeSelfTest', 'switch selftest'),
    ('function Invoke-CentralThemeRuntimeSelfTest', 'função selftest'),
    ('CENTRAL THEME RUNTIME: OK', 'marcador selftest'),
    ('ExpectedCard', 'validação de card'),
]:
    if marker not in central:
        raise SystemExit(f'CURA2 runtime contrato Central ausente: {label}')
if 'Aparência não recarrega dados' not in gen:
    raise SystemExit('CURA2 runtime contrato Gerenciador ausente: tema desacoplado de dados')
if '$form.BackColor = $script:CurrentPalette.Background' not in maint:
    raise SystemExit('CURA2 runtime contrato Manutenção ausente: raiz explícita')
if 'if ($script:IsInProcessHosted) { throw $message }' not in nf:
    raise SystemExit('CURA2 runtime contrato NF ausente: erro hospedado sem modal')

print('CURA 2 runtime contract — OK')
