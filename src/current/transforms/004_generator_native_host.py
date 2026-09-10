from pathlib import Path

repo = Path('.')
central_path = repo / 'src/generated/Central de Trabalho.ps1'
generator_path = repo / 'src/generated/Modulos/Gerador-de-Planilhas-CB5-TV5/Gerador Planilhas.ps1'
central = central_path.read_text(encoding='utf-8-sig')
gen = generator_path.read_text(encoding='utf-8-sig')
marker = '# GENERATOR_NATIVE_HOST_V120'

if marker in gen:
    print('Integração nativa do Gerenciador já aplicada.')
    raise SystemExit(0)

def rep(text, old, new, label):
    n = text.count(old)
    if n != 1:
        raise RuntimeError(f'{label}: esperado 1 trecho, encontrado {n}')
    return text.replace(old, new, 1)

def span(text, start, end, replacement, label):
    a = text.find(start)
    if a < 0:
        raise RuntimeError(f'{label}: início não encontrado')
    b = text.find(end, a)
    if b < 0:
        raise RuntimeError(f'{label}: fim não encontrado')
    b += len(end)
    return text[:a] + replacement + text[b:]

# Central: versões e suporte genérico ao tema/responsividade do módulo hospedado.
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
central = rep(central, old_sync, new_sync, 'sincronização de tema')

old_initial = '''            & $moduleInfo {
                if (Get-Command Update-MaintenanceResponsiveLayout -ErrorAction SilentlyContinue) {
                    Update-MaintenanceResponsiveLayout
                }
            }'''
new_initial = '''            & $moduleInfo {
                if (Get-Command Update-MaintenanceResponsiveLayout -ErrorAction SilentlyContinue) {
                    Update-MaintenanceResponsiveLayout
                }
                elseif (Get-Command Update-GeneratorResponsiveLayout -ErrorAction SilentlyContinue) {
                    Update-GeneratorResponsiveLayout
                    if (Get-Command Update-RootLayout -ErrorAction SilentlyContinue) { Update-RootLayout }
                }
            }'''
central = rep(central, old_initial, new_initial, 'callback inicial')

old_resize = '''                & $script:HostedModule {
                    if (Get-Command Update-MaintenanceResponsiveLayout -ErrorAction SilentlyContinue) {
                        Update-MaintenanceResponsiveLayout
                    }
                }'''
new_resize = '''                & $script:HostedModule {
                    if (Get-Command Update-MaintenanceResponsiveLayout -ErrorAction SilentlyContinue) {
                        Update-MaintenanceResponsiveLayout
                    }
                    elseif (Get-Command Update-GeneratorResponsiveLayout -ErrorAction SilentlyContinue) {
                        Update-GeneratorResponsiveLayout
                        if (Get-Command Update-RootLayout -ErrorAction SilentlyContinue) { Update-RootLayout }
                    }
                }'''
central = rep(central, old_resize, new_resize, 'callback de redimensionamento')

# Gerenciador: contrato correto com a Central.
gen = rep(gen,
'''param(
    [Int64]$EmbeddedParentHandle = 0,
    [switch]$HostedInCentral
)''',
'''param(
    [Int64]$EmbeddedParentHandle = 0,
    [switch]$HostedInCentral,
    [string]$HostTheme = ""
)''',
'parâmetro HostTheme')

gen = rep(gen,
'''$script:IsInProcessHosted = [bool]$HostedInCentral
$script:IsEmbedded = (($EmbeddedParentHandle -gt 0) -and -not $script:IsInProcessHosted)
$script:HostedFormExport = $null''',
'''$script:IsInProcessHosted = [bool]$HostedInCentral
$script:IsEmbedded = (($EmbeddedParentHandle -gt 0) -and -not $script:IsInProcessHosted)
$script:HostedFormExport = $null
$script:HostedControlExport = $null''',
'HostedControlExport')

gen = rep(gen, '$script:AppVersion = "3.4.0"', '$script:AppVersion = "3.5.0"', 'versão interna')
gen = rep(gen,
'if (@("Claro moderno", "Escuro grafite", "Alto contraste") -contains [string]$saved.Theme) {',
'if (@("Claro moderno", "Escuro grafite", "Técnico industrial", "Alto contraste") -contains [string]$saved.Theme) {',
'tema nas preferências')

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

host_theme_functions = '''function Get-GeneratorThemeFromHost {
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
gen = rep(gen, 'function New-AppLogoBitmap {\n', host_theme_functions + 'function New-AppLogoBitmap {\n', 'funções de tema hospedado')

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
'tema inicial do host')

gen = rep(gen,
'''[void]$themeCombo.Items.Add("Claro moderno")
[void]$themeCombo.Items.Add("Escuro grafite")
[void]$themeCombo.Items.Add("Alto contraste")''',
'''[void]$themeCombo.Items.Add("Claro moderno")
[void]$themeCombo.Items.Add("Escuro grafite")
[void]$themeCombo.Items.Add("Técnico industrial")
[void]$themeCombo.Items.Add("Alto contraste")''',
'combo Técnico industrial')

# Substitui apenas o bloco de criação da janela principal. Em hospedagem vira UserControl.
form_start = '$form = New-Object Windows.Forms.Form\n'
form_end = '$form.Icon = $script:AppIcon\n'
new_form = '''$workingArea = [Windows.Forms.Screen]::PrimaryScreen.WorkingArea
$targetWidth = [Math]::Min($workingArea.Width, [Math]::Max(760, [int]($workingArea.Width * 0.94)))
$targetHeight = [Math]::Min($workingArea.Height, [Math]::Max(520, [int]($workingArea.Height * 0.94)))
$targetWidth = [Math]::Min($targetWidth, $workingArea.Width)
$targetHeight = [Math]::Min($targetHeight, $workingArea.Height)
$minimumWidth = [Math]::Min(820, $workingArea.Width)
$minimumHeight = [Math]::Min(560, $workingArea.Height)

if ($script:IsInProcessHosted) {
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
}
'''
gen = span(gen, form_start, form_end, new_form, 'raiz do Gerenciador')

# Viewport: no host, ClientSize já é a área final e não deve sofrer nova divisão por DPI.
viewport_start = 'function Get-GeneratorLogicalViewport {\n'
viewport_end = '\nfunction Update-GeneratorResponsiveLayout {\n'
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
}

function Update-GeneratorResponsiveLayout {
'''
gen = span(gen, viewport_start, viewport_end, new_viewport, 'viewport do Gerenciador')

# Ciclo de vida final: nenhuma API exclusiva de Form no ramo hospedado.
bottom_start = '$form.MinimumSize = [Drawing.Size]::new([int]$minimumWidth, [int]$minimumHeight)\n'
a = gen.rfind(bottom_start)
if a < 0:
    raise RuntimeError('ciclo final: início não encontrado')
new_bottom = '''if ($script:IsInProcessHosted) {
    $form.MinimumSize = [Drawing.Size]::new(1, 1)
    $form.Dock = [Windows.Forms.DockStyle]::Fill
    $form.Add_HandleCreated({ try { Update-GeneratorResponsiveLayout; Update-RootLayout } catch {} })
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
    try { [void]$form.ShowDialog() }
    finally {
        Save-AppSettings
        if ($null -ne $logoPicture.Image) { $logoPicture.Image.Dispose() }
        if ($null -ne $script:AppIcon) { $script:AppIcon.Dispose() }
        if ($null -ne $script:AppIconBitmap) { $script:AppIconBitmap.Dispose() }
        $toolTip.Dispose()
        $form.Dispose()
        Close-GeneratorSingleInstanceMutex
    }
}

# GENERATOR_NATIVE_HOST_V120
'''
gen = gen[:a] + new_bottom

# Validações de arquitetura antes de gravar os fontes gerados.
requirements = [
    ('$script:AppVersion = "0.12.0"' in central, 'Central 0.12.0 ausente'),
    ('$script:GeneratorVersion = "3.5.0"' in central, 'Gerenciador 3.5.0 ausente na Central'),
    ('Set-HostedGeneratorTheme' in central, 'sincronização de tema do Gerenciador ausente'),
    ('$script:AppVersion = "3.5.0"' in gen, 'versão interna 3.5.0 ausente'),
    ('[string]$HostTheme = ""' in gen, 'HostTheme ausente'),
    ('$form = New-Object Windows.Forms.UserControl' in gen, 'UserControl hospedado ausente'),
    ('$script:HostedControlExport = $form' in gen, 'HostedControlExport ausente'),
    ('$form.TopLevel = $false' not in gen, 'TopLevel antigo ainda presente'),
    ('$form.Add_FormClosed' not in gen, 'FormClosed antigo ainda presente'),
    ('$form.Add_Disposed' in gen, 'Disposed hospedado ausente'),
    ('[void]$form.ShowDialog()' in gen, 'ShowDialog standalone ausente'),
    ('LogicalWidth=if ($script:IsInProcessHosted) { $w }' in gen, 'viewport real hospedado ausente'),
]
for ok, message in requirements:
    if not ok:
        raise RuntimeError(message)

central_path.write_text(central, encoding='utf-8', newline='')
generator_path.write_text(gen, encoding='utf-8', newline='')
print('Gerenciador 3.5.0: UserControl nativo, DPI hospedado corrigido e tema sincronizado.')
