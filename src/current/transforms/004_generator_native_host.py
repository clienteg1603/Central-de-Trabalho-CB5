from pathlib import Path

repo = Path('.')
central_path = repo / 'src/generated/Central de Trabalho.ps1'
generator_path = repo / 'src/generated/Modulos/Gerador-de-Planilhas-CB5-TV5/Gerador Planilhas.ps1'

central = central_path.read_text(encoding='utf-8-sig')
gen = generator_path.read_text(encoding='utf-8-sig')
marker = '# GENERATOR_NATIVE_HOST_V120'

if marker in gen:
    print('Integração nativa do Gerenciador v3.5.0 já aplicada.')
    raise SystemExit(0)

def rep(text, old, new, label, count=1):
    n = text.count(old)
    if n != count:
        raise RuntimeError(f'{label}: esperado {count} trecho(s), encontrado {n}')
    return text.replace(old, new, count)

# ---------------------------------------------------------------------------
# Central de Trabalho: nova versão, versão do Gerenciador e callbacks genéricos
# ---------------------------------------------------------------------------
central = rep(central, '$script:AppVersion = "0.11.5"', '$script:AppVersion = "0.12.0"', 'versão Central')
central = rep(central, '$script:GeneratorVersion = "3.4.0"', '$script:GeneratorVersion = "3.5.0"', 'versão Gerenciador na Central')

old_sync = '''function Sync-HostedModuleTheme {
    if ($null -eq $script:HostedModule -or [string]::IsNullOrWhiteSpace($script:EmbeddedModule)) { return }
    $theme = [string]$themeCombo.SelectedItem
    try {
        & $script:HostedModule {
            param($hostTheme)
            $cmd = Get-Command -Name Set-HostedMaintenanceTheme -ErrorAction SilentlyContinue
            if ($null -ne $cmd) { Set-HostedMaintenanceTheme $hostTheme }
        } $theme
    } catch {}
}'''
new_sync = '''function Sync-HostedModuleTheme {
    if ($null -eq $script:HostedModule -or [string]::IsNullOrWhiteSpace($script:EmbeddedModule)) { return }
    $theme = [string]$themeCombo.SelectedItem
    try {
        & $script:HostedModule {
            param($hostTheme)
            $maintenanceCmd = Get-Command -Name Set-HostedMaintenanceTheme -ErrorAction SilentlyContinue
            if ($null -ne $maintenanceCmd) {
                Set-HostedMaintenanceTheme $hostTheme
                return
            }
            $generatorCmd = Get-Command -Name Set-HostedGeneratorTheme -ErrorAction SilentlyContinue
            if ($null -ne $generatorCmd) { Set-HostedGeneratorTheme $hostTheme }
        } $theme
    } catch {}
}'''
central = rep(central, old_sync, new_sync, 'sincronização de tema hospedado')

old_initial_callback = '''            & $moduleInfo {
                if (Get-Command Update-MaintenanceResponsiveLayout -ErrorAction SilentlyContinue) {
                    Update-MaintenanceResponsiveLayout
                }
            }'''
new_initial_callback = '''            & $moduleInfo {
                if (Get-Command Update-MaintenanceResponsiveLayout -ErrorAction SilentlyContinue) {
                    Update-MaintenanceResponsiveLayout
                }
                elseif (Get-Command Update-GeneratorResponsiveLayout -ErrorAction SilentlyContinue) {
                    Update-GeneratorResponsiveLayout
                    if (Get-Command Update-RootLayout -ErrorAction SilentlyContinue) { Update-RootLayout }
                }
            }'''
# Esse bloco aparece no encaixe inicial e no SizeChanged do host.
central = rep(central, old_initial_callback, new_initial_callback, 'callbacks responsivos da Central', count=2)

# ---------------------------------------------------------------------------
# Gerenciador: contrato do host e versão
# ---------------------------------------------------------------------------
old_param = '''param(
    [Int64]$EmbeddedParentHandle = 0,
    [switch]$HostedInCentral
)'''
new_param = '''param(
    [Int64]$EmbeddedParentHandle = 0,
    [switch]$HostedInCentral,
    [string]$HostTheme = ""
)'''
gen = rep(gen, old_param, new_param, 'parâmetro HostTheme')

gen = rep(gen,
'''$script:IsInProcessHosted = [bool]$HostedInCentral
$script:IsEmbedded = (($EmbeddedParentHandle -gt 0) -and -not $script:IsInProcessHosted)
$script:HostedFormExport = $null''',
'''$script:IsInProcessHosted = [bool]$HostedInCentral
$script:IsEmbedded = (($EmbeddedParentHandle -gt 0) -and -not $script:IsInProcessHosted)
$script:HostedFormExport = $null
$script:HostedControlExport = $null''',
'export de UserControl')

gen = rep(gen, '$script:AppVersion = "3.4.0"', '$script:AppVersion = "3.5.0"', 'versão interna Gerenciador')

# A preferência também passa a reconhecer a quarta paleta da Central.
gen = rep(gen,
'if (@("Claro moderno", "Escuro grafite", "Alto contraste") -contains [string]$saved.Theme) {',
'if (@("Claro moderno", "Escuro grafite", "Técnico industrial", "Alto contraste") -contains [string]$saved.Theme) {',
'preferência Técnico industrial')

# Insere a paleta técnico-industrial antes de Alto contraste.
technical_case = '''        "Técnico industrial" {
            $accent = if ($Product -eq "TV5") { [Drawing.Color]::FromArgb(72, 202, 143) } else { [Drawing.Color]::FromArgb(44, 189, 197) }
            return [pscustomobject]@{
                Background = [Drawing.Color]::FromArgb(18, 23, 25)
                Surface = [Drawing.Color]::FromArgb(27, 35, 38)
                Panel = [Drawing.Color]::FromArgb(34, 43, 46)
                Input = [Drawing.Color]::FromArgb(18, 23, 25)
                Text = [Drawing.Color]::FromArgb(242, 246, 245)
                Muted = [Drawing.Color]::FromArgb(174, 188, 186)
                Border = [Drawing.Color]::FromArgb(62, 77, 80)
                Accent = $accent
                AccentText = [Drawing.Color]::FromArgb(9, 24, 28)
                Info = [Drawing.Color]::FromArgb(27, 55, 59)
                Quantity = [Drawing.Color]::FromArgb(86, 59, 13)
                SelectedRow = [Drawing.Color]::FromArgb(39, 55, 57)
                SelectedQuantity = [Drawing.Color]::FromArgb(112, 75, 18)
                Invalid = [Drawing.Color]::FromArgb(78, 28, 26)
                Success = [Drawing.Color]::FromArgb(72, 202, 143)
                Error = [Drawing.Color]::FromArgb(239, 108, 102)
                Warning = [Drawing.Color]::FromArgb(246, 186, 68)
            }
        }
'''
gen = rep(gen, '        "Alto contraste" {\n', technical_case + '        "Alto contraste" {\n', 'paleta Técnico industrial')

# Mapeamento da aparência da Central para a nomenclatura histórica do Gerenciador.
map_function = '''
function Get-GeneratorThemeFromHost {
    param([string]$Theme)
    switch ($Theme) {
        "Escuro profissional" { return "Escuro grafite" }
        "Técnico industrial" { return "Técnico industrial" }
        "Claro corporativo" { return "Claro moderno" }
        "Alto contraste" { return "Alto contraste" }
        default { return "Escuro grafite" }
    }
}

function Set-HostedGeneratorTheme {
    param([string]$CentralTheme)
    if (-not $script:IsInProcessHosted) { return }
    $mapped = Get-GeneratorThemeFromHost $CentralTheme
    try {
        if ($themeCombo.Items.Contains($mapped)) { $themeCombo.SelectedItem = $mapped }
        else { $themeCombo.SelectedItem = "Escuro grafite" }
        Apply-AppTheme
        Update-GeneratorResponsiveLayout
        Update-RootLayout
    } catch {}
}

'''
gen = rep(gen, 'function New-AppLogoBitmap {\n', map_function + 'function New-AppLogoBitmap {\n', 'funções de tema hospedado')

# O tema recebido da Central tem prioridade visual no modo integrado.
gen = rep(gen,
'''$script:AppSettings = Get-AppSettings
$script:LastInputDirectory = [string]$script:AppSettings.LastInputDirectory
$initialPalette = Get-ThemePalette $script:AppSettings.Theme $script:AppSettings.Product''',
'''$script:AppSettings = Get-AppSettings
if ($script:IsInProcessHosted -and -not [string]::IsNullOrWhiteSpace($HostTheme)) {
    $script:AppSettings.Theme = Get-GeneratorThemeFromHost $HostTheme
}
$script:LastInputDirectory = [string]$script:AppSettings.LastInputDirectory
$initialPalette = Get-ThemePalette $script:AppSettings.Theme $script:AppSettings.Product''',
'tema inicial herdado')

# ---------------------------------------------------------------------------
# Raiz hospedada: UserControl real, sem Form dimensionado pelo monitor.
# ---------------------------------------------------------------------------
old_form_block = '''$form = New-Object Windows.Forms.Form
$form.Text = "Gerenciador de Planilhas CB5 e TV5"
$form.StartPosition = [Windows.Forms.FormStartPosition]::CenterScreen
if ($script:IsInProcessHosted) {
    $form.AutoScaleMode = [Windows.Forms.AutoScaleMode]::None
}
else {
    $form.AutoScaleMode = [Windows.Forms.AutoScaleMode]::Dpi
}
$form.AutoScaleDimensions = New-Object Drawing.SizeF(96, 96)
$form.FormBorderStyle = [Windows.Forms.FormBorderStyle]::Sizable
$form.MaximizeBox = $true
$form.MinimizeBox = $true
$form.Size = New-Object Drawing.Size(1080, 780)
$form.MinimumSize = New-Object Drawing.Size(820, 560)
$workingArea = [Windows.Forms.Screen]::PrimaryScreen.WorkingArea
$targetWidth = [Math]::Min($workingArea.Width, [Math]::Max(760, [int]($workingArea.Width * 0.94)))
$targetHeight = [Math]::Min($workingArea.Height, [Math]::Max(520, [int]($workingArea.Height * 0.94)))
$targetWidth = [Math]::Min($targetWidth, $workingArea.Width)
$targetHeight = [Math]::Min($targetHeight, $workingArea.Height)
$minimumWidth = [Math]::Min(820, $workingArea.Width)
$minimumHeight = [Math]::Min(560, $workingArea.Height)
$form.Font = New-Object Drawing.Font("Segoe UI", 10)
$form.BackColor = $initialPalette.Background
$form.KeyPreview = $true
$script:AppIconBitmap = New-AppLogoBitmap $initialPalette.Accent 32
$script:AppIcon = [Drawing.Icon]::FromHandle($script:AppIconBitmap.GetHicon())
$form.Icon = $script:AppIcon'''
new_form_block = '''$workingArea = [Windows.Forms.Screen]::PrimaryScreen.WorkingArea
$targetWidth = [Math]::Min($workingArea.Width, [Math]::Max(760, [int]($workingArea.Width * 0.94)))
$targetHeight = [Math]::Min($workingArea.Height, [Math]::Max(520, [int]($workingArea.Height * 0.94)))
$targetWidth = [Math]::Min($targetWidth, $workingArea.Width)
$targetHeight = [Math]::Min($targetHeight, $workingArea.Height)
$minimumWidth = [Math]::Min(820, $workingArea.Width)
$minimumHeight = [Math]::Min(560, $workingArea.Height)

if ($script:IsInProcessHosted) {
    # Dentro da Central o Gerenciador é um controle nativo. Não nasce como uma
    # janela do tamanho do monitor para depois tentar caber em um painel menor.
    $form = New-Object Windows.Forms.UserControl
    $form.Name = "GeneratorHostedControl"
    $form.AutoScaleMode = [Windows.Forms.AutoScaleMode]::None
    $form.AutoScaleDimensions = New-Object Drawing.SizeF(96, 96)
    $form.MinimumSize = New-Object Drawing.Size(1, 1)
    $form.Margin = New-Object Windows.Forms.Padding(0)
    $form.Dock = [Windows.Forms.DockStyle]::Fill
    $form.Font = New-Object Drawing.Font("Segoe UI", 9.25)
    $form.BackColor = $initialPalette.Background
    $script:AppIconBitmap = $null
    $script:AppIcon = $null
}
else {
    $form = New-Object Windows.Forms.Form
    $form.Text = "Gerenciador de Planilhas CB5 e TV5"
    $form.StartPosition = [Windows.Forms.FormStartPosition]::CenterScreen
    $form.AutoScaleMode = [Windows.Forms.AutoScaleMode]::Dpi
    $form.AutoScaleDimensions = New-Object Drawing.SizeF(96, 96)
    $form.FormBorderStyle = [Windows.Forms.FormBorderStyle]::Sizable
    $form.MaximizeBox = $true
    $form.MinimizeBox = $true
    $form.Size = New-Object Drawing.Size(1080, 780)
    $form.MinimumSize = New-Object Drawing.Size(820, 560)
    $form.Font = New-Object Drawing.Font("Segoe UI", 10)
    $form.BackColor = $initialPalette.Background
    $form.KeyPreview = $true
    $script:AppIconBitmap = New-AppLogoBitmap $initialPalette.Accent 32
    $script:AppIcon = [Drawing.Icon]::FromHandle($script:AppIconBitmap.GetHicon())
    $form.Icon = $script:AppIcon
}'''
gen = rep(gen, old_form_block, new_form_block, 'raiz Form/UserControl')

# O Gerenciador integrado passa a oferecer a mesma quarta opção de aparência.
gen = rep(gen,
'''[void]$themeCombo.Items.Add("Claro moderno")
[void]$themeCombo.Items.Add("Escuro grafite")
[void]$themeCombo.Items.Add("Alto contraste")''',
'''[void]$themeCombo.Items.Add("Claro moderno")
[void]$themeCombo.Items.Add("Escuro grafite")
[void]$themeCombo.Items.Add("Técnico industrial")
[void]$themeCombo.Items.Add("Alto contraste")''',
'combo de aparência')

# No modo hospedado o tamanho do controle já é a medida final fornecida pela Central.
old_viewport = '''function Get-GeneratorLogicalViewport {
    $dpi = 96
    try { if ($form.DeviceDpi -gt 0) { $dpi = [int]$form.DeviceDpi } } catch {}
    $w = [Math]::Max(1,[int]$form.ClientSize.Width)
    $h = [Math]::Max(1,[int]$form.ClientSize.Height)
    [pscustomobject]@{
        Dpi=$dpi
        LogicalWidth=[int][Math]::Round($w*96.0/$dpi)
        LogicalHeight=[int][Math]::Round($h*96.0/$dpi)
    }
}'''
new_viewport = '''function Get-GeneratorLogicalViewport {
    $dpi = 96
    try { if ($form.DeviceDpi -gt 0) { $dpi = [int]$form.DeviceDpi } } catch {}
    $w = [Math]::Max(1,[int]$form.ClientSize.Width)
    $h = [Math]::Max(1,[int]$form.ClientSize.Height)
    [pscustomobject]@{
        Dpi=$dpi
        Scale=[Math]::Round($dpi/96.0, 2)
        Width=$w
        Height=$h
        LogicalWidth=if ($script:IsInProcessHosted) { $w } else { [int][Math]::Round($w*96.0/$dpi) }
        LogicalHeight=if ($script:IsInProcessHosted) { $h } else { [int][Math]::Round($h*96.0/$dpi) }
    }
}'''
gen = rep(gen, old_viewport, new_viewport, 'viewport hospedado')

# ---------------------------------------------------------------------------
# Ciclo de vida: Control.Dispose no host; ShowDialog continua só no standalone.
# ---------------------------------------------------------------------------
old_bottom = '''$form.MinimumSize = [Drawing.Size]::new([int]$minimumWidth, [int]$minimumHeight)
$form.Size = [Drawing.Size]::new([int]$targetWidth, [int]$targetHeight)
if ($script:IsInProcessHosted) {
    $form.TopLevel = $false
    $form.FormBorderStyle = [Windows.Forms.FormBorderStyle]::None
    $form.ShowInTaskbar = $false
    $form.ControlBox = $false
    $form.MinimizeBox = $false
    $form.MaximizeBox = $false
    $form.MinimumSize = [Drawing.Size]::new(1, 1)
    $form.Dock = [Windows.Forms.DockStyle]::Fill
}
else {
    Initialize-EmbeddedModuleWindow $form
}
$form.Add_Shown({
    if (-not $script:IsEmbedded -and -not $script:IsInProcessHosted) {
        $visibleArea = [Windows.Forms.Screen]::FromControl($form).WorkingArea
        if ($form.WindowState -eq [Windows.Forms.FormWindowState]::Normal) {
            $fittedWidth = [Math]::Min($form.Width, $visibleArea.Width)
            $fittedHeight = [Math]::Min($form.Height, $visibleArea.Height)
            $form.Size = [Drawing.Size]::new([int]$fittedWidth, [int]$fittedHeight)
        }
    }
    Update-RootLayout
})

if ($script:IsInProcessHosted) {
    $form.Add_FormClosed({
        try { Save-AppSettings } catch {}
        try { if ($null -ne $logoPicture.Image) { $logoPicture.Image.Dispose() } } catch {}
        try { if ($null -ne $script:AppIcon) { $script:AppIcon.Dispose() } } catch {}
        try { if ($null -ne $script:AppIconBitmap) { $script:AppIconBitmap.Dispose() } } catch {}
        try { $toolTip.Dispose() } catch {}
        try { Close-GeneratorSingleInstanceMutex } catch {}
    })
    $script:HostedFormExport = $form
}
else {
    if (-not $script:IsEmbedded) { Show-AppSplash }
    try {
        [void]$form.ShowDialog()
    }
    finally {
        Save-AppSettings
        if ($null -ne $logoPicture.Image) { $logoPicture.Image.Dispose() }
        if ($null -ne $script:AppIcon) { $script:AppIcon.Dispose() }
        if ($null -ne $script:AppIconBitmap) { $script:AppIconBitmap.Dispose() }
        $toolTip.Dispose()
        $form.Dispose()
        Close-GeneratorSingleInstanceMutex
    }
}'''
new_bottom = '''if ($script:IsInProcessHosted) {
    $form.MinimumSize = [Drawing.Size]::new(1, 1)
    $form.Dock = [Windows.Forms.DockStyle]::Fill
    $form.Add_HandleCreated({
        try { Update-GeneratorResponsiveLayout; Update-RootLayout } catch {}
    })
    $form.Add_Disposed({
        try { Save-AppSettings } catch {}
        try { if ($null -ne $logoPicture.Image) { $logoPicture.Image.Dispose() } } catch {}
        try { if ($null -ne $script:AppIcon) { $script:AppIcon.Dispose() } } catch {}
        try { if ($null -ne $script:AppIconBitmap) { $script:AppIconBitmap.Dispose() } } catch {}
        try { $toolTip.Dispose() } catch {}
        try { Close-GeneratorSingleInstanceMutex } catch {}
    })
    try { Update-GeneratorResponsiveLayout; Update-RootLayout } catch {}
    $script:HostedControlExport = $form
    $script:HostedFormExport = $null
}
else {
    $form.MinimumSize = [Drawing.Size]::new([int]$minimumWidth, [int]$minimumHeight)
    $form.Size = [Drawing.Size]::new([int]$targetWidth, [int]$targetHeight)
    Initialize-EmbeddedModuleWindow $form
    $form.Add_Shown({
        if (-not $script:IsEmbedded) {
            $visibleArea = [Windows.Forms.Screen]::FromControl($form).WorkingArea
            if ($form.WindowState -eq [Windows.Forms.FormWindowState]::Normal) {
                $fittedWidth = [Math]::Min($form.Width, $visibleArea.Width)
                $fittedHeight = [Math]::Min($form.Height, $visibleArea.Height)
                $form.Size = [Drawing.Size]::new([int]$fittedWidth, [int]$fittedHeight)
            }
        }
        Update-RootLayout
    })
    if (-not $script:IsEmbedded) { Show-AppSplash }
    try {
        [void]$form.ShowDialog()
    }
    finally {
        Save-AppSettings
        if ($null -ne $logoPicture.Image) { $logoPicture.Image.Dispose() }
        if ($null -ne $script:AppIcon) { $script:AppIcon.Dispose() }
        if ($null -ne $script:AppIconBitmap) { $script:AppIconBitmap.Dispose() }
        $toolTip.Dispose()
        $form.Dispose()
        Close-GeneratorSingleInstanceMutex
    }
}'''
gen = rep(gen, old_bottom, new_bottom, 'ciclo de vida hospedado')

# Marca permanente da migração arquitetural.
gen += '\n' + marker + '\n'

# ---------------------------------------------------------------------------
# Verificações estáticas antes de permitir que o workflow empacote a versão.
# ---------------------------------------------------------------------------
checks = [
    ('$script:AppVersion = "0.12.0"' in central, 'Central não ficou em v0.12.0'),
    ('$script:GeneratorVersion = "3.5.0"' in central, 'Central não referencia Gerenciador 3.5.0'),
    ('Set-HostedGeneratorTheme' in central, 'Central não sincroniza tema do Gerenciador'),
    ('$script:AppVersion = "3.5.0"' in gen, 'Gerenciador não ficou em v3.5.0'),
    ('[string]$HostTheme = ""' in gen, 'Gerenciador não aceita HostTheme'),
    ('$form = New-Object Windows.Forms.UserControl' in gen, 'UserControl hospedado ausente'),
    ('$script:HostedControlExport = $form' in gen, 'HostedControlExport ausente'),
    ('$form.TopLevel = $false' not in gen, 'Ainda existe TopLevel no Gerenciador hospedado'),
    ('$form.Add_FormClosed' not in gen, 'Ainda existe FormClosed no ciclo hospedado'),
    ('$form.Add_Disposed' in gen, 'Limpeza por Disposed ausente'),
    ('[void]$form.ShowDialog()' in gen, 'Modo standalone perdeu ShowDialog'),
    ('LogicalWidth=if ($script:IsInProcessHosted) { $w }' in gen, 'viewport real hospedado não aplicado'),
    ('"Técnico industrial"' in gen, 'paleta Técnico industrial ausente'),
]
for ok, msg in checks:
    if not ok:
        raise RuntimeError(msg)

# Checagem simples de delimitadores, ignorando comentários/strings não é parser,
# mas captura acidentes grosseiros do transform antes do pacote.
for name, content in [('Central', central), ('Gerenciador', gen)]:
    if content.count('{') != content.count('}'):
        raise RuntimeError(f'{name}: chaves desbalanceadas após transformação')
    if content.count('(') != content.count(')'):
        raise RuntimeError(f'{name}: parênteses desbalanceados após transformação')

central_path.write_text(central, encoding='utf-8', newline='')
generator_path.write_text(gen, encoding='utf-8', newline='')
print('Gerenciador v3.5.0 migrado para UserControl nativo no modo integrado.')
