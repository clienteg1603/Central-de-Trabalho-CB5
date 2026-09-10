from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CENTRAL = ROOT / "generated" / "Central de Trabalho.ps1"


def read(path):
    return path.read_text(encoding="utf-8-sig")


def write(path, text):
    path.write_text(text, encoding="utf-8-sig")


def replace_once(text, old, new, label):
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: esperado 1 trecho, encontrado {count}")
    return text.replace(old, new, 1)


central = read(CENTRAL)
central = replace_once(central, '$script:AppVersion = "0.14.1"', '$script:AppVersion = "0.14.2"', "versao Central")

# A barra de título passa a acompanhar os temas escuros no Windows 10/11.
marker = '[System.Windows.Forms.Application]::SetCompatibleTextRenderingDefault($false)\n'
insert = marker + r'''
if (-not ("CentralWindowStyle.Native" -as [type])) {
    try {
        Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
namespace CentralWindowStyle {
    public static class Native {
        [DllImport("dwmapi.dll")]
        public static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int value, int size);
    }
}
"@
    } catch {}
}

function Set-CentralTitleBarTheme {
    param([bool]$Dark)
    try {
        if ($null -eq $form -or -not $form.IsHandleCreated -or -not ("CentralWindowStyle.Native" -as [type])) { return }
        $value = if ($Dark) { 1 } else { 0 }
        $result = [CentralWindowStyle.Native]::DwmSetWindowAttribute($form.Handle, 20, [ref]$value, 4)
        if ($result -ne 0) {
            [void][CentralWindowStyle.Native]::DwmSetWindowAttribute($form.Handle, 19, [ref]$value, 4)
        }
    } catch {}
}
'''
central = replace_once(central, marker, insert, "tema da barra de titulo")

# Combobox de aparência deixa de ficar branco nos temas escuros.
old_combo = '''$themeCombo = New-Object Windows.Forms.ComboBox
$themeCombo.Location = [Drawing.Point]::new(4, 27)
$themeCombo.Size = [Drawing.Size]::new(184, 30)
$themeCombo.DropDownStyle = [Windows.Forms.ComboBoxStyle]::DropDownList
[void]$themeCombo.Items.AddRange(@("Escuro profissional", "Técnico industrial", "Claro corporativo", "Alto contraste"))
$themeCombo.SelectedItem = $settings.Theme
if ($themeCombo.SelectedIndex -lt 0) { $themeCombo.SelectedIndex = 0 }
$sidebarBottom.Controls.Add($themeCombo)'''
new_combo = '''$themeCombo = New-Object Windows.Forms.ComboBox
$themeCombo.Location = [Drawing.Point]::new(4, 27)
$themeCombo.Size = [Drawing.Size]::new(184, 30)
$themeCombo.DropDownStyle = [Windows.Forms.ComboBoxStyle]::DropDownList
$themeCombo.DrawMode = [Windows.Forms.DrawMode]::OwnerDrawFixed
$themeCombo.ItemHeight = 23
$themeCombo.FlatStyle = [Windows.Forms.FlatStyle]::Flat
[void]$themeCombo.Items.AddRange(@("Escuro profissional", "Técnico industrial", "Claro corporativo", "Alto contraste"))
$themeCombo.SelectedItem = $settings.Theme
if ($themeCombo.SelectedIndex -lt 0) { $themeCombo.SelectedIndex = 0 }
$themeCombo.Add_DrawItem({
    param($sender, $e)
    try {
        if ($e.Index -lt 0) { return }
        $palette = $script:CurrentPalette
        $back = if ($null -ne $palette) { $palette.Input } else { [Drawing.Color]::FromArgb(18,24,27) }
        $fore = if ($null -ne $palette) { $palette.Text } else { [Drawing.Color]::White }
        if (($e.State -band [Windows.Forms.DrawItemState]::Selected) -ne 0) {
            $back = if ($null -ne $palette) { $palette.AccentStrong } else { [Drawing.Color]::FromArgb(27,151,134) }
            $fore = if ($null -ne $palette) { $palette.AccentText } else { [Drawing.Color]::White }
        }
        $brush = New-Object Drawing.SolidBrush($back)
        $textBrush = New-Object Drawing.SolidBrush($fore)
        try {
            $e.Graphics.FillRectangle($brush, $e.Bounds)
            $textRect = [Drawing.Rectangle]::new($e.Bounds.X + 6, $e.Bounds.Y, [Math]::Max(1, $e.Bounds.Width - 8), $e.Bounds.Height)
            $format = New-Object Drawing.StringFormat
            try {
                $format.LineAlignment = [Drawing.StringAlignment]::Center
                $format.Trimming = [Drawing.StringTrimming]::EllipsisCharacter
                $e.Graphics.DrawString([string]$sender.Items[$e.Index], $sender.Font, $textBrush, $textRect, $format)
            } finally { $format.Dispose() }
        } finally {
            $brush.Dispose()
            $textBrush.Dispose()
        }
        $e.DrawFocusRectangle()
    } catch {}
})
$sidebarBottom.Controls.Add($themeCombo)'''
central = replace_once(central, old_combo, new_combo, "combo de aparencia integrado ao tema")

# Linha de identidade na barra do módulo hospedado.
marker = '$embeddedLayout.Controls.Add($embeddedToolbar, 0, 0)\n'
insert = marker + '''\n$embeddedAccentLine = New-Object Windows.Forms.Panel\n$embeddedAccentLine.Dock = [Windows.Forms.DockStyle]::Bottom\n$embeddedAccentLine.Height = 2\n$embeddedToolbar.Controls.Add($embeddedAccentLine)\n$embeddedAccentLine.BringToFront()\n'''
central = replace_once(central, marker, insert, "linha de identidade do modulo")

# Barra de título, combo e linha integrada acompanham a paleta atual.
old_theme_head = '''    $selectedTheme = [string]$themeCombo.SelectedItem
    $script:CurrentPalette = Get-ThemePalette $selectedTheme
    $sidebarColor = Get-SidebarColor $selectedTheme
    $generatorAccent = Get-ModuleAccent "Generator"
    $maintenanceAccent = Get-ModuleAccent "Maintenance"'''
new_theme_head = '''    $selectedTheme = [string]$themeCombo.SelectedItem
    $script:CurrentPalette = Get-ThemePalette $selectedTheme
    $sidebarColor = Get-SidebarColor $selectedTheme
    $generatorAccent = Get-ModuleAccent "Generator"
    $maintenanceAccent = Get-ModuleAccent "Maintenance"
    Set-CentralTitleBarTheme ($selectedTheme -ne "Claro corporativo")'''
central = replace_once(central, old_theme_head, new_theme_head, "sincronizacao da barra de titulo")

central = replace_once(
    central,
    '    $themeCombo.BackColor = $script:CurrentPalette.Input\n    $themeCombo.ForeColor = $script:CurrentPalette.Text\n',
    '    $themeCombo.BackColor = $script:CurrentPalette.Input\n    $themeCombo.ForeColor = $script:CurrentPalette.Text\n    $themeCombo.Invalidate()\n',
    "repintura do seletor de aparencia"
)

central = replace_once(
    central,
    '    $headerAccent.BackColor = $script:CurrentPalette.Accent\n',
    '    $headerAccent.BackColor = $script:CurrentPalette.Accent\n    if ($null -ne $embeddedAccentLine) {\n        $embeddedAccentLine.BackColor = if ($script:EmbeddedModule -eq "Generator") { $generatorAccent } elseif ($script:EmbeddedModule -eq "Maintenance") { $maintenanceAccent } else { $script:CurrentPalette.Accent }\n    }\n',
    "cor da linha do modulo"
)

# O estado normal já aparece na lateral; o rodapé fica reservado para ações e alertas.
central = replace_once(
    central,
    '        Set-StatusMessage "Sistema pronto. Todos os módulos principais foram localizados." "Success"\n        $sidebarStatus.Text = "●  Sistema pronto"',
    '        $sidebarStatus.Text = "●  Sistema pronto"',
    "remove status duplicado no rodape"
)

# Ao abrir um módulo, a linha da toolbar adota imediatamente a identidade do módulo.
central = replace_once(
    central,
    '        $script:EmbeddedModule = $Module\n\n        if ($hostedForm -is [Windows.Forms.Form]) {',
    '        $script:EmbeddedModule = $Module\n        try {\n            if ($null -ne $embeddedAccentLine) {\n                $embeddedAccentLine.BackColor = if ($Module -eq "Generator") { Get-ModuleAccent "Generator" } else { Get-ModuleAccent "Maintenance" }\n            }\n        } catch {}\n\n        if ($hostedForm -is [Windows.Forms.Form]) {',
    "identidade imediata do modulo hospedado"
)

write(CENTRAL, central)
print("Transformação v0.14.2 aplicada com sucesso.")
