Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()
[System.Windows.Forms.Application]::SetCompatibleTextRenderingDefault($false)

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

$script:AppVersion = "0.20.0"
$script:RootPath = $PSScriptRoot
$script:GeneratorVersion = "3.7.3"
$script:MaintenanceVersion = "0.6.1"
$script:UpdaterVersion = "1.0.0"
$script:GeneratorDirectory = [IO.Path]::Combine(
    $script:RootPath,
    "Modulos",
    "Gerador-de-Planilhas-CB5-TV5"
)
$script:GeneratorScript = [IO.Path]::Combine($script:GeneratorDirectory, "Gerador Planilhas.ps1")
$script:GeneratorCore = [IO.Path]::Combine($script:GeneratorDirectory, "Componentes.Core.ps1")
$script:MaintenanceDirectory = [IO.Path]::Combine(
    $script:RootPath,
    "Modulos",
    "Central-de-Manutencao-CB5"
)
$script:MaintenanceScript = [IO.Path]::Combine($script:MaintenanceDirectory, "Central Manutencao CB5.ps1")
$script:MaintenanceCore = [IO.Path]::Combine($script:MaintenanceDirectory, "Manutencao.Core.ps1")
$script:UpdaterDirectory = [IO.Path]::Combine($script:RootPath, "Atualizador")
$script:UpdaterExecutable = [IO.Path]::Combine($script:UpdaterDirectory, "Central de Trabalho Updater.exe")
$script:UpdaterScript = [IO.Path]::Combine($script:UpdaterDirectory, "Central de Trabalho Updater.ps1")
$script:UpdaterCore = [IO.Path]::Combine($script:UpdaterDirectory, "Update.Core.ps1")
$script:UpdaterChannels = [IO.Path]::Combine($script:UpdaterDirectory, "CANAIS.json")
$script:SettingsDirectory = [IO.Path]::Combine(
    [Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData),
    "CentralDeTrabalho"
)
$script:SettingsPath = [IO.Path]::Combine($script:SettingsDirectory, "preferencias.json")

# Desde a linha 0.17.x a Central possui um host Windows gráfico próprio. O VBS antigo
# deixou de participar da inicialização e é removido somente depois que a nova Central
# já conseguiu iniciar, evitando apagar o fallback antes de uma atualização concluída.
function Remove-LegacyLauncherArtifact {
    try {
        $legacyLauncher = [IO.Path]::Combine($script:RootPath, "ABRIR CENTRAL DE TRABALHO.vbs")
        if ([IO.File]::Exists($legacyLauncher)) {
            [IO.File]::Delete($legacyLauncher)
        }
    }
    catch {
        # A limpeza é auxiliar e nunca deve impedir a Central de abrir.
    }
}
Remove-LegacyLauncherArtifact

# Mantém a pasta de instalação limpa para o usuário sem remover nenhum arquivo
# necessário ao funcionamento. Os itens internos continuam no mesmo lugar para
# preservar compatibilidade com o host, módulos e Atualizador; apenas recebem o
# atributo Hidden do Windows depois que a Central já iniciou com sucesso.
function Set-InternalRuntimeArtifactsHidden {
    try {
        $internalPaths = @(
            [IO.Path]::Combine($script:RootPath, "Central de Trabalho.ps1"),
            [IO.Path]::Combine($script:RootPath, "PACOTE-MANIFESTO.json"),
            [IO.Path]::Combine($script:RootPath, "Atualizador"),
            [IO.Path]::Combine($script:RootPath, "Modulos")
        )

        foreach ($internalPath in $internalPaths) {
            if ([IO.File]::Exists($internalPath) -or [IO.Directory]::Exists($internalPath)) {
                $attributes = [IO.File]::GetAttributes($internalPath)
                if (($attributes -band [IO.FileAttributes]::Hidden) -eq 0) {
                    [IO.File]::SetAttributes($internalPath, ($attributes -bor [IO.FileAttributes]::Hidden))
                }
            }
        }
    }
    catch {
        # A limpeza visual é auxiliar e nunca deve impedir a Central de abrir.
    }
}
Set-InternalRuntimeArtifactsHidden

$script:CurrentPalette = $null
$script:ActiveNavName = "Home"
$script:HostedModule = $null
$script:HostedForm = $null
$script:EmbeddedModule = ""
$script:EmbeddedClosing = $false
$script:ModuleLoading = $false
$script:UpdaterProcess = $null
$script:LastAvailabilitySignature = ""

$script:SingleInstanceMutex = $null
$script:OwnsSingleInstanceMutex = $false
$createdNewMutex = $false
try {
    $script:SingleInstanceMutex = [Threading.Mutex]::new($true, "CentralDeTrabalho_Central", ([ref]$createdNewMutex))
    $script:OwnsSingleInstanceMutex = $createdNewMutex
}
catch {}

if ($null -ne $script:SingleInstanceMutex -and -not $script:OwnsSingleInstanceMutex) {
    [Windows.Forms.MessageBox]::Show(
        "A Central de Trabalho já está aberta.",
        "Central de Trabalho",
        [Windows.Forms.MessageBoxButtons]::OK,
        [Windows.Forms.MessageBoxIcon]::Information
    ) | Out-Null
    $script:SingleInstanceMutex.Dispose()
    return
}

function Close-CentralSingleInstanceMutex {
    if ($null -eq $script:SingleInstanceMutex) { return }
    try {
        if ($script:OwnsSingleInstanceMutex) { $script:SingleInstanceMutex.ReleaseMutex() }
    }
    catch {}
    try { $script:SingleInstanceMutex.Dispose() }
    catch {}
    $script:SingleInstanceMutex = $null
    $script:OwnsSingleInstanceMutex = $false
}

function Get-AppSettings {
    $settings = [pscustomobject]@{ Theme = "Escuro profissional" }
    try {
        if ([IO.File]::Exists($script:SettingsPath)) {
            $saved = Get-Content -LiteralPath $script:SettingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
            $theme = [string]$saved.Theme
            switch ($theme) {
                "Escuro grafite" { $theme = "Escuro profissional" }
                "Claro moderno" { $theme = "Claro corporativo" }
            }
            if (@("Escuro profissional", "Técnico industrial", "Claro corporativo", "Alto contraste") -contains $theme) {
                $settings.Theme = $theme
            }
        }
    }
    catch {}
    return $settings
}

function Save-AppSettings {
    try {
        if (-not [IO.Directory]::Exists($script:SettingsDirectory)) {
            [void][IO.Directory]::CreateDirectory($script:SettingsDirectory)
        }
        [pscustomobject]@{
            Theme = [string]$themeCombo.SelectedItem
        } | ConvertTo-Json | Set-Content -LiteralPath $script:SettingsPath -Encoding UTF8
    }
    catch {}
}

function Get-ThemePalette {
    param([string]$Theme)

    switch ($Theme) {
        "Técnico industrial" {
            return [pscustomobject]@{
                Background = [Drawing.Color]::FromArgb(16, 20, 22)
                Surface = [Drawing.Color]::FromArgb(22, 28, 31)
                Card = [Drawing.Color]::FromArgb(29, 36, 39)
                Input = [Drawing.Color]::FromArgb(18, 24, 27)
                Text = [Drawing.Color]::FromArgb(244, 247, 248)
                Muted = [Drawing.Color]::FromArgb(170, 181, 184)
                Border = [Drawing.Color]::FromArgb(60, 72, 76)
                Accent = [Drawing.Color]::FromArgb(35, 179, 158)
                AccentStrong = [Drawing.Color]::FromArgb(27, 151, 134)
                AccentText = [Drawing.Color]::White
                Blue = [Drawing.Color]::FromArgb(56, 189, 248)
                Success = [Drawing.Color]::FromArgb(48, 207, 145)
                SuccessBack = [Drawing.Color]::FromArgb(17, 70, 55)
                Planned = [Drawing.Color]::FromArgb(244, 166, 42)
                PlannedBack = [Drawing.Color]::FromArgb(77, 50, 15)
                Footer = [Drawing.Color]::FromArgb(18, 23, 25)
            }
        }
        "Claro corporativo" {
            return [pscustomobject]@{
                Background = [Drawing.Color]::FromArgb(242, 246, 250)
                Surface = [Drawing.Color]::White
                Card = [Drawing.Color]::White
                Input = [Drawing.Color]::White
                Text = [Drawing.Color]::FromArgb(18, 32, 50)
                Muted = [Drawing.Color]::FromArgb(86, 104, 126)
                Border = [Drawing.Color]::FromArgb(210, 220, 231)
                Accent = [Drawing.Color]::FromArgb(47, 112, 230)
                AccentStrong = [Drawing.Color]::FromArgb(34, 93, 205)
                AccentText = [Drawing.Color]::White
                Blue = [Drawing.Color]::FromArgb(47, 112, 230)
                Success = [Drawing.Color]::FromArgb(21, 138, 96)
                SuccessBack = [Drawing.Color]::FromArgb(221, 247, 237)
                Planned = [Drawing.Color]::FromArgb(191, 111, 20)
                PlannedBack = [Drawing.Color]::FromArgb(255, 241, 219)
                Footer = [Drawing.Color]::FromArgb(231, 237, 244)
            }
        }
        "Alto contraste" {
            return [pscustomobject]@{
                Background = [Drawing.Color]::Black
                Surface = [Drawing.Color]::Black
                Card = [Drawing.Color]::FromArgb(18, 18, 18)
                Input = [Drawing.Color]::Black
                Text = [Drawing.Color]::White
                Muted = [Drawing.Color]::White
                Border = [Drawing.Color]::White
                Accent = [Drawing.Color]::Yellow
                AccentStrong = [Drawing.Color]::Yellow
                AccentText = [Drawing.Color]::Black
                Blue = [Drawing.Color]::Cyan
                Success = [Drawing.Color]::Lime
                SuccessBack = [Drawing.Color]::Black
                Planned = [Drawing.Color]::Yellow
                PlannedBack = [Drawing.Color]::Black
                Footer = [Drawing.Color]::Black
            }
        }
        default {
            return [pscustomobject]@{
                Background = [Drawing.Color]::FromArgb(13, 20, 34)
                Surface = [Drawing.Color]::FromArgb(17, 27, 44)
                Card = [Drawing.Color]::FromArgb(23, 34, 54)
                Input = [Drawing.Color]::FromArgb(14, 25, 41)
                Text = [Drawing.Color]::FromArgb(244, 247, 251)
                Muted = [Drawing.Color]::FromArgb(170, 182, 200)
                Border = [Drawing.Color]::FromArgb(41, 55, 80)
                Accent = [Drawing.Color]::FromArgb(39, 196, 125)
                AccentStrong = [Drawing.Color]::FromArgb(29, 166, 105)
                AccentText = [Drawing.Color]::White
                Blue = [Drawing.Color]::FromArgb(58, 130, 247)
                Success = [Drawing.Color]::FromArgb(52, 211, 153)
                SuccessBack = [Drawing.Color]::FromArgb(15, 72, 57)
                Planned = [Drawing.Color]::FromArgb(244, 166, 42)
                PlannedBack = [Drawing.Color]::FromArgb(73, 48, 15)
                Footer = [Drawing.Color]::FromArgb(10, 22, 38)
            }
        }
    }
}

function Set-PrimaryButtonStyle {
    param([Windows.Forms.Button]$Button)

    $Button.FlatStyle = [Windows.Forms.FlatStyle]::Flat
    $Button.FlatAppearance.BorderSize = 0
    $Button.BackColor = $script:CurrentPalette.AccentStrong
    $Button.ForeColor = $script:CurrentPalette.AccentText
    $Button.Cursor = [Windows.Forms.Cursors]::Hand
}

function Set-SecondaryButtonStyle {
    param([Windows.Forms.Button]$Button)

    $Button.FlatStyle = [Windows.Forms.FlatStyle]::Flat
    $Button.FlatAppearance.BorderSize = 1
    $Button.FlatAppearance.BorderColor = $script:CurrentPalette.Border
    $Button.BackColor = $script:CurrentPalette.Surface
    $Button.ForeColor = $script:CurrentPalette.Text
    $Button.Cursor = [Windows.Forms.Cursors]::Hand
}

function Set-StatusMessage {
    param(
        [string]$Message,
        [ValidateSet("Normal", "Success", "Warning", "Error")][string]$Kind = "Normal"
    )

    $footerStatus.Text = $Message
    switch ($Kind) {
        "Success" { $footerStatus.ForeColor = $script:CurrentPalette.Success }
        "Warning" { $footerStatus.ForeColor = $script:CurrentPalette.Planned }
        "Error" { $footerStatus.ForeColor = [Drawing.Color]::FromArgb(220, 38, 38) }
        default { $footerStatus.ForeColor = $script:CurrentPalette.Muted }
    }
}


function Get-CentralHealthSnapshot {
    $generatorRequired = @($script:GeneratorScript, $script:GeneratorCore)
    $maintenanceRequired = @($script:MaintenanceScript, $script:MaintenanceCore)
    $updaterRequired = @($script:UpdaterExecutable, $script:UpdaterScript, $script:UpdaterCore, $script:UpdaterChannels)

    $generatorMissing = @($generatorRequired | Where-Object { -not [IO.File]::Exists($_) })
    $maintenanceMissing = @($maintenanceRequired | Where-Object { -not [IO.File]::Exists($_) })
    $updaterMissing = @($updaterRequired | Where-Object { -not [IO.File]::Exists($_) })

    [pscustomobject]@{
        GeneratorAvailable = ($generatorMissing.Count -eq 0)
        MaintenanceAvailable = ($maintenanceMissing.Count -eq 0)
        UpdaterAvailable = ($updaterMissing.Count -eq 0)
        GeneratorMissing = $generatorMissing
        MaintenanceMissing = $maintenanceMissing
        UpdaterMissing = $updaterMissing
    }
}

function Format-MissingCentralFiles {
    param([object[]]$Paths)
    if ($null -eq $Paths -or $Paths.Count -eq 0) { return "" }
    return (($Paths | ForEach-Object { "• " + [IO.Path]::GetFileName([string]$_) }) -join "`r`n")
}

# Integração real dos módulos na própria árvore WinForms da Central.
# Em vez de anexar uma janela externa com SetParent, cada módulo é carregado
# em um módulo PowerShell isolado e devolve seu Form como controle filho.
function Close-EmbeddedModule {
    param([switch]$Force)

    if ($script:EmbeddedClosing) { return }
    $script:EmbeddedClosing = $true
    try {
        if ($null -ne $script:HostedForm) {
            try {
                if (-not $script:HostedForm.IsDisposed -and $script:HostedForm -is [Windows.Forms.Form]) {
                    $script:HostedForm.Close()
                }
            } catch {}
            try {
                if (-not $script:HostedForm.IsDisposed) { $script:HostedForm.Dispose() }
            } catch {}
        }
        if ($null -ne $embeddedContent) {
            try { $embeddedContent.Controls.Clear() } catch {}
        }
        if ($null -ne $script:HostedModule) {
            try { Remove-Module -ModuleInfo $script:HostedModule -Force -ErrorAction SilentlyContinue } catch {}
        }
    }
    finally {
        $script:HostedForm = $null
        $script:HostedModule = $null
        $script:EmbeddedModule = ""
        $script:EmbeddedClosing = $false
    }
}

function Sync-HostedModuleTheme {
    if ($null -eq $script:HostedModule -or [string]::IsNullOrWhiteSpace($script:EmbeddedModule)) { return }
    if ($null -eq $script:HostedForm) { return }
    try {
        if ($script:HostedForm.IsDisposed -or $script:HostedForm.Disposing -or $null -eq $script:HostedForm.Parent) { return }
    }
    catch { return }
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
}

function Show-Dashboard {
    param([switch]$SkipClose)
    if (-not $SkipClose) { Close-EmbeddedModule }
    if ($null -ne $embeddedHost) { $embeddedHost.Visible = $false }
    if ($null -ne $mainLayout) { $mainLayout.Visible = $true; $mainLayout.BringToFront() }
    Set-ActiveNavigation "Home"
    Set-StatusMessage "Visão geral da Central de Trabalho." "Normal"
    try { if ($null -ne $openGeneratorButton -and $openGeneratorButton.Enabled) { $openGeneratorButton.Select() } } catch {}
}

function Start-EmbeddedModule {
    param([ValidateSet("Generator", "Maintenance")][string]$Module)

    $moduleScript = if ($Module -eq "Generator") { $script:GeneratorScript } else { $script:MaintenanceScript }
    $moduleName = if ($Module -eq "Generator") { "Gerenciador de Planilhas" } else { "Central de Manutenção CB5" }
    $moduleVersion = if ($Module -eq "Generator") { $script:GeneratorVersion } else { $script:MaintenanceVersion }

    $health = Get-CentralHealthSnapshot
    $moduleAvailable = if ($Module -eq "Generator") { $health.GeneratorAvailable } else { $health.MaintenanceAvailable }
    $moduleMissing = if ($Module -eq "Generator") { @($health.GeneratorMissing) } else { @($health.MaintenanceMissing) }
    if (-not $moduleAvailable) {
        $missingText = Format-MissingCentralFiles $moduleMissing
        Set-StatusMessage "Não foi possível abrir: instalação do módulo incompleta." "Error"
        [Windows.Forms.MessageBox]::Show(
            "A instalação de $moduleName está incompleta.`r`n`r`nArquivos necessários que não foram encontrados:`r`n$missingText`r`n`r`nUse Atualizações para reparar ou reinstalar a versão atual.",
            "Central de Trabalho",
            [Windows.Forms.MessageBoxButtons]::OK,
            [Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
        return
    }

    if ($script:ModuleLoading) { return }
    $script:ModuleLoading = $true
    try { Update-CentralAvailabilityState } catch {}

    try {
        Close-EmbeddedModule
        $mainLayout.Visible = $false
        $embeddedHost.Visible = $true
        $embeddedHost.BringToFront()
        Set-ActiveNavigation ""
        $embeddedTitle.Text = $moduleName
        $embeddedSubtitle.Text = "Módulo v$moduleVersion integrado à Central de Trabalho"
        $embeddedContent.BackColor = $script:CurrentPalette.Background
        $embeddedContent.Controls.Clear()
        $embeddedLoading.Text = "Carregando $moduleName...`r`nAguarde um instante."
        $embeddedContent.Controls.Add($embeddedLoading)
        $embeddedLoading.Visible = $true
        $embeddedLoading.BringToFront()
        $form.UseWaitCursor = $true
        $embeddedContent.Cursor = [Windows.Forms.Cursors]::WaitCursor
        Set-StatusMessage "Carregando $moduleName..." "Normal"
        [Windows.Forms.Application]::DoEvents()

        # New-Module mantém um escopo de script vivo para os eventos do módulo.
        # Módulos novos podem exportar um UserControl (preferido) e módulos antigos
        # continuam compatíveis exportando um Form filho.
        $dynamicName = "CentralHosted_{0}_{1}" -f $Module, ([Guid]::NewGuid().ToString("N"))
        $hostTheme = [string]$themeCombo.SelectedItem
        $moduleInfo = New-Module -Name $dynamicName -ArgumentList @($moduleScript, $hostTheme) -ScriptBlock {
            param($scriptPath, $hostTheme)
            . $scriptPath -HostedInCentral -HostTheme $hostTheme
        }
        if ($null -eq $moduleInfo) { throw "Não foi possível criar o escopo isolado do módulo." }

        $hostedForm = & $moduleInfo {
            $controlVar = Get-Variable -Name HostedControlExport -Scope Script -ErrorAction SilentlyContinue
            if ($null -ne $controlVar -and $null -ne $controlVar.Value) { return $controlVar.Value }
            $formVar = Get-Variable -Name HostedFormExport -Scope Script -ErrorAction SilentlyContinue
            if ($null -ne $formVar) { return $formVar.Value }
            return $null
        }
        if ($null -eq $hostedForm -or -not ($hostedForm -is [Windows.Forms.Control])) {
            try { Remove-Module -ModuleInfo $moduleInfo -Force -ErrorAction SilentlyContinue } catch {}
            throw "O módulo não forneceu uma interface integrável." 
        }

        $script:HostedModule = $moduleInfo
        $script:HostedForm = $hostedForm
        $script:EmbeddedModule = $Module
        try {
            if ($null -ne $embeddedAccentLine) {
                $embeddedAccentLine.BackColor = if ($Module -eq "Generator") { Get-ModuleAccent "Generator" } else { Get-ModuleAccent "Maintenance" }
            }
        } catch {}

        if ($hostedForm -is [Windows.Forms.Form]) {
            $hostedForm.TopLevel = $false
            $hostedForm.FormBorderStyle = [Windows.Forms.FormBorderStyle]::None
            $hostedForm.ShowInTaskbar = $false
        }
        $hostedForm.Dock = [Windows.Forms.DockStyle]::Fill
        $hostedForm.MinimumSize = [Drawing.Size]::new(1, 1)
        $hostedForm.Margin = [Windows.Forms.Padding]::new(0)
        $embeddedContent.Controls.Add($hostedForm)

        if ($hostedForm -is [Windows.Forms.Form]) { $hostedForm.Show() }
        else { $hostedForm.Visible = $true }

        try {
            # O controle integrado recebe exatamente o ClientRectangle do host.
            # Para a Manutenção, isto elimina o Form com tamanho de monitor que
            # continuava maior que a área útil da Central.
            $hostedForm.Bounds = $embeddedContent.ClientRectangle
            $hostedForm.PerformLayout()
            & $moduleInfo {
                if (Get-Command Update-MaintenanceResponsiveLayout -ErrorAction SilentlyContinue) {
                    Update-MaintenanceResponsiveLayout
                }
                elseif (Get-Command Update-GeneratorResponsiveLayout -ErrorAction SilentlyContinue) {
                    Update-GeneratorResponsiveLayout
                    if (Get-Command Update-RootLayout -ErrorAction SilentlyContinue) { Update-RootLayout }
                }
            }
        } catch {}
        $hostedForm.BringToFront()
        $embeddedLoading.Visible = $false

        Set-StatusMessage "$moduleName integrado à Central." "Success"
    }
    catch {
        try { Close-EmbeddedModule -Force } catch {}
        Show-Dashboard -SkipClose
        Set-StatusMessage "Falha ao integrar $moduleName à Central." "Error"
        [Windows.Forms.MessageBox]::Show(
            "Não foi possível integrar $moduleName à Central.`r`n`r`n$($_.Exception.Message)",
            "Central de Trabalho",
            [Windows.Forms.MessageBoxButtons]::OK,
            [Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
    }
    finally {
        $script:ModuleLoading = $false
        try { $form.UseWaitCursor = $false } catch {}
        try { $embeddedContent.Cursor = [Windows.Forms.Cursors]::Default } catch {}
        try { Update-CentralAvailabilityState } catch {}
    }
}

function Start-GeneratorModule {
    Start-EmbeddedModule "Generator"
}

function Start-MaintenanceModule {
    Start-EmbeddedModule "Maintenance"
}

function Start-UpdaterModule {
    if ($null -ne $script:UpdaterProcess) {
        try {
            if (-not $script:UpdaterProcess.HasExited) {
                Set-StatusMessage "A tela de atualizações já está aberta." "Normal"
                return
            }
        } catch {}
        try { $script:UpdaterProcess.Dispose() } catch {}
        $script:UpdaterProcess = $null
    }

    $health = Get-CentralHealthSnapshot
    if (-not $health.UpdaterAvailable) {
        $missingText = Format-MissingCentralFiles @($health.UpdaterMissing)
        Set-StatusMessage "Não foi possível abrir: instalação do Atualizador incompleta." "Error"
        [Windows.Forms.MessageBox]::Show(
            "A instalação do Atualizador está incompleta.`r`n`r`nArquivos necessários que não foram encontrados:`r`n$missingText",
            "Central de Trabalho",
            [Windows.Forms.MessageBoxButtons]::OK,
            [Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
        return
    }

    try {
        $startInfo = New-Object Diagnostics.ProcessStartInfo
        $startInfo.FileName = $script:UpdaterExecutable
        $startInfo.WorkingDirectory = $script:UpdaterDirectory
        $startInfo.Arguments = '-InstallRoot "' + $script:RootPath + '" -CurrentVersion "' + $script:AppVersion + '" -ParentProcessId ' + $PID
        $startInfo.UseShellExecute = $true
        $script:UpdaterProcess = [Diagnostics.Process]::Start($startInfo)
        Set-StatusMessage "Tela de atualizações aberta pelo Atualizador nativo." "Success"
    }
    catch {
        Set-StatusMessage "Falha ao iniciar o Atualizador." "Error"
        [Windows.Forms.MessageBox]::Show(
            "Não foi possível iniciar o Atualizador.`r`n`r`n$($_.Exception.Message)",
            "Central de Trabalho",
            [Windows.Forms.MessageBoxButtons]::OK,
            [Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
    }
}

function Get-SidebarColor {
    param([string]$Theme)
    switch ($Theme) {
        "Claro corporativo" { return [Drawing.Color]::FromArgb(22, 37, 59) }
        "Alto contraste" { return [Drawing.Color]::Black }
        "Técnico industrial" { return [Drawing.Color]::FromArgb(18, 23, 25) }
        default { return [Drawing.Color]::FromArgb(9, 24, 41) }
    }
}

function Get-ModuleAccent {
    param([ValidateSet("Generator", "Maintenance")][string]$Module)
    $theme = [string]$themeCombo.SelectedItem
    if ($Module -eq "Generator") {
        if ($theme -eq "Claro corporativo") { return [Drawing.Color]::FromArgb(13, 142, 158) }
        if ($theme -eq "Técnico industrial") { return [Drawing.Color]::FromArgb(44, 189, 197) }
        if ($theme -eq "Alto contraste") { return [Drawing.Color]::Cyan }
        return [Drawing.Color]::FromArgb(33, 156, 211)
    }
    if ($theme -eq "Claro corporativo") { return [Drawing.Color]::FromArgb(220, 111, 24) }
    if ($theme -eq "Técnico industrial") { return [Drawing.Color]::FromArgb(244, 142, 40) }
    if ($theme -eq "Alto contraste") { return [Drawing.Color]::Orange }
    return [Drawing.Color]::FromArgb(222, 132, 28)
}


function Get-CardHoverColor {
    param([string]$Theme)
    switch ($Theme) {
        "Claro corporativo" { return [Drawing.Color]::FromArgb(246, 249, 253) }
        "Alto contraste" { return [Drawing.Color]::FromArgb(28, 28, 28) }
        "Técnico industrial" { return [Drawing.Color]::FromArgb(35, 43, 46) }
        default { return [Drawing.Color]::FromArgb(29, 43, 66) }
    }
}

function Set-RoundedRegion {
    param(
        [Windows.Forms.Control]$Control,
        [int]$Radius = 12
    )
    if ($null -eq $Control -or $Control.Width -le 2 -or $Control.Height -le 2) { return }
    try {
        $diameter = [Math]::Max(2, $Radius * 2)
        $rect = [Drawing.Rectangle]::new(0, 0, $Control.Width, $Control.Height)
        $path = New-Object Drawing.Drawing2D.GraphicsPath
        $path.AddArc($rect.Left, $rect.Top, $diameter, $diameter, 180, 90)
        $path.AddArc($rect.Right - $diameter, $rect.Top, $diameter, $diameter, 270, 90)
        $path.AddArc($rect.Right - $diameter, $rect.Bottom - $diameter, $diameter, $diameter, 0, 90)
        $path.AddArc($rect.Left, $rect.Bottom - $diameter, $diameter, $diameter, 90, 90)
        $path.CloseFigure()
        $oldRegion = $Control.Region
        $Control.Region = New-Object Drawing.Region($path)
        if ($null -ne $oldRegion) { try { $oldRegion.Dispose() } catch {} }
        $path.Dispose()
    }
    catch {}
}

function Enable-RoundedControl {
    param(
        [Windows.Forms.Control]$Control,
        [int]$Radius = 12
    )
    if ($null -eq $Control) { return }
    $r = $Radius
    $target = $Control
    # O callback pode disparar depois que a criação inicial da janela terminou.
    # Capturamos o ScriptBlock da função para não depender da resolução de nome
    # dentro do módulo dinâmico criado por GetNewClosure().
    $roundAction = ${function:Set-RoundedRegion}
    $Control.Add_SizeChanged({ & $roundAction $target $r }.GetNewClosure())
    Set-RoundedRegion $Control $Radius
}

function Enable-CardHover {
    param([Windows.Forms.Panel]$Panel)
    if ($null -eq $Panel) { return }
    $target = $Panel
    $Panel.Add_MouseEnter({
        try { $target.BackColor = Get-CardHoverColor ([string]$themeCombo.SelectedItem) } catch {}
    }.GetNewClosure())
    $Panel.Add_MouseLeave({
        try { $target.BackColor = $script:CurrentPalette.Card } catch {}
    }.GetNewClosure())
}

function Set-ActiveNavigation {
    param([string]$Name)
    $script:ActiveNavName = $Name
    $map = @{
        Home = $navHome
        Updates = $navUpdates
        Folder = $navFolder
        About = $navAbout
    }
    foreach ($key in $map.Keys) {
        if ($null -ne $map[$key]) { Set-NavButtonStyle $map[$key] ($key -eq $Name) }
    }
}

function Open-ModuleFolder {
    param([string]$Path, [string]$Name)
    try {
        if (-not [IO.Directory]::Exists($Path)) { throw "Pasta não encontrada: $Path" }
        Start-Process -FilePath "explorer.exe" -ArgumentList ('"' + $Path + '"')
        Set-StatusMessage "Pasta de $Name aberta." "Success"
    }
    catch {
        Set-StatusMessage "Não foi possível abrir a pasta de $Name." "Error"
    }
}

function Set-NavButtonStyle {
    param(
        [Windows.Forms.Button]$Button,
        [bool]$Active = $false
    )
    $Button.FlatStyle = [Windows.Forms.FlatStyle]::Flat
    $Button.FlatAppearance.BorderSize = 0
    $Button.TextAlign = [Drawing.ContentAlignment]::MiddleLeft
    $Button.Cursor = [Windows.Forms.Cursors]::Hand
    $Button.Font = [Drawing.Font]::new("Segoe UI Semibold", 9.5)
    if ($Active) {
        $Button.BackColor = $script:CurrentPalette.AccentStrong
        $Button.ForeColor = [Drawing.Color]::White
    }
    else {
        $Button.BackColor = Get-SidebarColor ([string]$themeCombo.SelectedItem)
        $Button.ForeColor = [Drawing.Color]::FromArgb(210, 222, 236)
    }
}

function Update-CentralAvailabilityState {
    try {
        $health = Get-CentralHealthSnapshot
        $generatorAvailable = [bool]$health.GeneratorAvailable
        $maintenanceAvailable = [bool]$health.MaintenanceAvailable
        $updaterAvailable = [bool]$health.UpdaterAvailable
        $generatorFolderAvailable = [IO.Directory]::Exists($script:GeneratorDirectory)
        $maintenanceFolderAvailable = [IO.Directory]::Exists($script:MaintenanceDirectory)
        $moduleCount = ([int]$generatorAvailable + [int]$maintenanceAvailable)

        if ($null -ne $script:UpdaterProcess) {
            try {
                if ($script:UpdaterProcess.HasExited) {
                    try { $script:UpdaterProcess.Dispose() } catch {}
                    $script:UpdaterProcess = $null
                }
            } catch { $script:UpdaterProcess = $null }
        }

        if ($null -ne $openGeneratorButton) {
            $openGeneratorButton.Enabled = ($generatorAvailable -and -not $script:ModuleLoading)
            $openGeneratorButton.Cursor = if ($openGeneratorButton.Enabled) { [Windows.Forms.Cursors]::Hand } else { [Windows.Forms.Cursors]::Default }
        }
        if ($null -ne $openMaintenanceButton) {
            $openMaintenanceButton.Enabled = ($maintenanceAvailable -and -not $script:ModuleLoading)
            $openMaintenanceButton.Cursor = if ($openMaintenanceButton.Enabled) { [Windows.Forms.Cursors]::Hand } else { [Windows.Forms.Cursors]::Default }
        }
        if ($null -ne $openGeneratorFolderButton) {
            $openGeneratorFolderButton.Enabled = ($generatorFolderAvailable -and -not $script:ModuleLoading)
            $openGeneratorFolderButton.Cursor = if ($openGeneratorFolderButton.Enabled) { [Windows.Forms.Cursors]::Hand } else { [Windows.Forms.Cursors]::Default }
        }
        if ($null -ne $openMaintenanceFolderButton) {
            $openMaintenanceFolderButton.Enabled = ($maintenanceFolderAvailable -and -not $script:ModuleLoading)
            $openMaintenanceFolderButton.Cursor = if ($openMaintenanceFolderButton.Enabled) { [Windows.Forms.Cursors]::Hand } else { [Windows.Forms.Cursors]::Default }
        }
        if ($null -ne $navUpdates) {
            $navUpdates.Enabled = ($updaterAvailable -and -not $script:ModuleLoading)
            $navUpdates.Cursor = if ($navUpdates.Enabled) { [Windows.Forms.Cursors]::Hand } else { [Windows.Forms.Cursors]::Default }
        }
        foreach ($navAction in @($navHome,$navFolder,$navAbout)) {
            if ($null -ne $navAction) {
                $navAction.Enabled = (-not $script:ModuleLoading)
                $navAction.Cursor = if ($navAction.Enabled) { [Windows.Forms.Cursors]::Hand } else { [Windows.Forms.Cursors]::Default }
            }
        }
        if ($null -ne $themeCombo) { $themeCombo.Enabled = (-not $script:ModuleLoading) }

        if ($null -ne $generatorStatus) {
            $generatorStatus.Text = if ($generatorAvailable) { "  DISPONÍVEL  " } elseif ($generatorFolderAvailable) { "  INCOMPLETO  " } else { "  INDISPONÍVEL  " }
            $generatorStatus.BackColor = if ($generatorAvailable) { $script:CurrentPalette.SuccessBack } else { $script:CurrentPalette.PlannedBack }
            $generatorStatus.ForeColor = if ($generatorAvailable) { $script:CurrentPalette.Success } else { $script:CurrentPalette.Planned }
        }
        if ($null -ne $maintenanceStatus) {
            $maintenanceStatus.Text = if ($maintenanceAvailable) { "  DISPONÍVEL  " } elseif ($maintenanceFolderAvailable) { "  INCOMPLETO  " } else { "  INDISPONÍVEL  " }
            $maintenanceStatus.BackColor = if ($maintenanceAvailable) { $script:CurrentPalette.SuccessBack } else { $script:CurrentPalette.PlannedBack }
            $maintenanceStatus.ForeColor = if ($maintenanceAvailable) { $script:CurrentPalette.Success } else { $script:CurrentPalette.Planned }
        }

        if ($null -ne $sidebarStatus -and $null -ne $sidebarStatusSub) {
            if ($generatorAvailable -and $maintenanceAvailable -and $updaterAvailable) {
                $sidebarStatus.Text = "●  Sistema pronto"
                $sidebarStatusSub.Text = "2 módulos disponíveis"
                $sidebarStatus.ForeColor = $script:CurrentPalette.Success
            }
            else {
                $sidebarStatus.Text = "●  Atenção"
                if ($moduleCount -lt 2) {
                    $sidebarStatusSub.Text = "$moduleCount de 2 módulos disponíveis"
                }
                elseif (-not $updaterAvailable) {
                    $sidebarStatusSub.Text = "Atualizador não localizado"
                }
                else {
                    $sidebarStatusSub.Text = "Verifique a instalação"
                }
                $sidebarStatus.ForeColor = $script:CurrentPalette.Planned
            }
        }
        if ($null -ne $sidebarVersion) { $sidebarVersion.Text = "Central v$($script:AppVersion)" }
        if ($null -ne $todayLabel) { $todayLabel.Text = (Get-Date).ToString("dd/MM/yyyy") }

        $signature = "$generatorAvailable|$maintenanceAvailable|$updaterAvailable|$generatorFolderAvailable|$maintenanceFolderAvailable|$(@($health.GeneratorMissing).Count)|$(@($health.MaintenanceMissing).Count)|$(@($health.UpdaterMissing).Count)|$($script:ModuleLoading)"
        if ($script:LastAvailabilitySignature -ne $signature) {
            $script:LastAvailabilitySignature = $signature
            try { $form.Invalidate($false) } catch {}
        }
    } catch {}
}

function Apply-AppTheme {
    $selectedTheme = [string]$themeCombo.SelectedItem
    if ([string]::IsNullOrWhiteSpace($selectedTheme) -or -not (@("Escuro profissional", "Técnico industrial", "Claro corporativo", "Alto contraste") -contains $selectedTheme)) {
        $selectedTheme = "Escuro profissional"
    }
    $script:CurrentPalette = Get-ThemePalette $selectedTheme
    $sidebarColor = Get-SidebarColor $selectedTheme
    $generatorAccent = Get-ModuleAccent "Generator"
    $maintenanceAccent = Get-ModuleAccent "Maintenance"

    try { Set-CentralTitleBarTheme ($selectedTheme -ne "Claro corporativo") } catch {}
    try {
        $form.BackColor = $script:CurrentPalette.Background
        $rootLayout.BackColor = $script:CurrentPalette.Background
        $sidebar.BackColor = $sidebarColor
        $mainPanel.BackColor = $script:CurrentPalette.Background
        $headerPanel.BackColor = $script:CurrentPalette.Background
        $modulesHost.BackColor = $script:CurrentPalette.Background
        $footerPanel.BackColor = $script:CurrentPalette.Footer
    } catch {}
    try {
        if ($null -ne $embeddedHost) { $embeddedHost.BackColor = $script:CurrentPalette.Background }
        if ($null -ne $embeddedToolbar) { $embeddedToolbar.BackColor = $script:CurrentPalette.Surface }
        if ($null -ne $embeddedContent) { $embeddedContent.BackColor = $script:CurrentPalette.Background }
    } catch {}
    try {
        foreach ($label in @($brandTitle, $brandSub, $sidebarSection, $sidebarThemeLabel, $sidebarVersion)) {
            if ($null -ne $label) { $label.ForeColor = [Drawing.Color]::FromArgb(225, 235, 245) }
        }
        $sidebarStatus.ForeColor = $script:CurrentPalette.Success
        $sidebarStatusSub.ForeColor = [Drawing.Color]::FromArgb(161, 179, 197)
    } catch {}
    try {
        foreach ($label in @($pageTitle, $programsTitle, $generatorTitle, $maintenanceTitle, $todayLabel, $embeddedTitle)) {
            if ($null -ne $label) { $label.ForeColor = $script:CurrentPalette.Text }
        }
        foreach ($label in @($pageSubtitle, $programsSubtitle, $generatorDescription, $generatorDetail, $maintenanceDescription, $maintenanceDetail, $embeddedSubtitle, $embeddedLoading)) {
            if ($null -ne $label) { $label.ForeColor = $script:CurrentPalette.Muted }
        }
    } catch {}
    try {
        foreach ($panel in @($generatorCard, $maintenanceCard)) {
            if ($null -ne $panel) {
                $panel.BackColor = $script:CurrentPalette.Card
                $panel.BorderStyle = [Windows.Forms.BorderStyle]::FixedSingle
            }
        }
        foreach ($layout in @($generatorLayout, $maintenanceLayout)) {
            if ($null -ne $layout) { $layout.BackColor = $script:CurrentPalette.Card }
        }
        $generatorAccentBar.BackColor = $generatorAccent
        $generatorIcon.BackColor = $generatorAccent
        $generatorIcon.ForeColor = [Drawing.Color]::White
        $maintenanceAccentBar.BackColor = $maintenanceAccent
        $maintenanceIcon.BackColor = $maintenanceAccent
        $maintenanceIcon.ForeColor = [Drawing.Color]::White
        $generatorStatus.BackColor = $script:CurrentPalette.SuccessBack
        $generatorStatus.ForeColor = $script:CurrentPalette.Success
        $maintenanceStatus.BackColor = $script:CurrentPalette.SuccessBack
        $maintenanceStatus.ForeColor = $script:CurrentPalette.Success
    } catch {}
    try {
        $themeCombo.BackColor = $script:CurrentPalette.Input
        $themeCombo.ForeColor = $script:CurrentPalette.Text
        $themeCombo.Refresh()
    } catch {}
    try { Set-ActiveNavigation $script:ActiveNavName } catch {}
    try {
        Set-PrimaryButtonStyle $openGeneratorButton
        $openGeneratorButton.BackColor = $generatorAccent
        Set-PrimaryButtonStyle $openMaintenanceButton
        $openMaintenanceButton.BackColor = $maintenanceAccent
        $openMaintenanceButton.ForeColor = [Drawing.Color]::White
        Set-SecondaryButtonStyle $openGeneratorFolderButton
        Set-SecondaryButtonStyle $openMaintenanceFolderButton
        if ($null -ne $embeddedBackButton) { Set-SecondaryButtonStyle $embeddedBackButton }
        if ($null -ne $embeddedFolderButton) { Set-SecondaryButtonStyle $embeddedFolderButton }
    } catch {}
    try {
        $headerAccent.BackColor = $script:CurrentPalette.Accent
        if ($null -ne $embeddedAccentLine) {
            $embeddedAccentLine.BackColor = if ($script:EmbeddedModule -eq "Generator") { $generatorAccent } elseif ($script:EmbeddedModule -eq "Maintenance") { $maintenanceAccent } else { $script:CurrentPalette.Accent }
        }
    } catch {}
    try { Update-CentralAvailabilityState } catch {}
    try {
        foreach ($rounded in @($generatorCard,$maintenanceCard,$brandMark,$generatorIcon,$maintenanceIcon,$openGeneratorButton,$openMaintenanceButton,$openGeneratorFolderButton,$openMaintenanceFolderButton)) {
            if ($null -ne $rounded) { Set-RoundedRegion $rounded 10 }
        }
    } catch {}
    try { $form.Invalidate($true) } catch {}
}

function Update-ResponsiveLayout {
    if ($null -eq $modulesFlow -or $modulesFlow.ClientSize.Width -le 0) { return }
    try {
        $availableWidth = [Math]::Max(360, $modulesFlow.ClientSize.Width - $modulesFlow.Padding.Horizontal - 34)
        $availableHeight = [Math]::Max(220, $modulesFlow.ClientSize.Height - $modulesFlow.Padding.Vertical - 12)
        $twoColumns = ($availableWidth -ge 860)

        if ($twoColumns) {
            $moduleWidth = [int](($availableWidth - 22) / 2)
            $moduleHeight = [Math]::Min(252, [Math]::Max(220, $availableHeight - 10))
        }
        else {
            $moduleWidth = $availableWidth
            $moduleHeight = [Math]::Min(238, [Math]::Max(205, [int](($availableHeight - 26) / 2)))
        }

        foreach ($card in @($generatorCard, $maintenanceCard)) {
            if ($null -ne $card) {
                $card.Width = $moduleWidth
                $card.Height = $moduleHeight
            }
        }

        $compactCard = ($moduleWidth -lt 560)
        foreach ($titleLabel in @($generatorTitle, $maintenanceTitle)) {
            if ($null -ne $titleLabel) {
                $titleLabel.Font = [Drawing.Font]::new("Segoe UI Semibold", $(if ($compactCard) { 12.5 } else { 14.5 }))
                $titleLabel.AutoEllipsis = $true
            }
        }
        foreach ($description in @($generatorDescription, $maintenanceDescription, $generatorDetail, $maintenanceDetail)) {
            if ($null -ne $description) { $description.AutoEllipsis = $true }
        }

        $openGeneratorButton.Text = if ($moduleWidth -lt 470) { "ABRIR" } else { "ABRIR GERENCIADOR" }
        $openMaintenanceButton.Text = if ($moduleWidth -lt 470) { "ABRIR" } else { "ABRIR MANUTENÇÃO" }

        foreach ($openButton in @($openGeneratorButton, $openMaintenanceButton)) {
            try {
                $buttonHost = $openButton.Parent
                if ($buttonHost -is [Windows.Forms.TableLayoutPanel] -and $buttonHost.ColumnStyles.Count -ge 2) {
                    if ($moduleWidth -lt 470) {
                        $buttonHost.ColumnStyles[0].Width = 66
                        $buttonHost.ColumnStyles[1].Width = 34
                    }
                    else {
                        $buttonHost.ColumnStyles[0].Width = 72
                        $buttonHost.ColumnStyles[1].Width = 28
                    }
                }
            } catch {}
        }
    } catch {}
}

function Update-CentralChromeLayout {
    try {
        # Cabeçalho principal: título, subtítulo e data nunca disputam o mesmo espaço.
        if ($null -ne $headerPanel -and $headerPanel.ClientSize.Width -gt 0) {
            $hw = [int]$headerPanel.ClientSize.Width
            $right = 26
            $todayLabel.Visible = ($hw -ge 620)
            if ($todayLabel.Visible) {
                $todayLabel.Left = [Math]::Max(330, $hw - $todayLabel.Width - $right)
                $textRight = $todayLabel.Left - 22
            }
            else {
                $textRight = $hw - $right
            }
            $pageTitle.Width = [Math]::Max(210, $textRight - $pageTitle.Left)
            $pageTitle.AutoEllipsis = $true
            $pageSubtitle.Width = [Math]::Max(210, $textRight - $pageSubtitle.Left)
            $pageSubtitle.AutoEllipsis = $true
        }

        # Cabeçalho dos programas acompanha a largura real do painel.
        if ($null -ne $programsHeader -and $programsHeader.ClientSize.Width -gt 0) {
            $programsTitle.Width = [Math]::Max(180, $programsHeader.ClientSize.Width - 20)
            $programsTitle.AutoEllipsis = $true
            $programsSubtitle.Width = [Math]::Max(180, $programsHeader.ClientSize.Width - 24)
            $programsSubtitle.AutoEllipsis = $true
        }

        # Barra lateral: controles usam a largura interna real, não tamanhos históricos fixos.
        if ($null -ne $navPanel -and $navPanel.ClientSize.Width -gt 0) {
            $navWidth = [Math]::Max(118, $navPanel.ClientSize.Width - $navPanel.Padding.Horizontal - 2)
            foreach ($b in @($navHome,$navUpdates,$navFolder,$navAbout)) {
                if ($null -ne $b) { $b.Width = $navWidth }
            }
        }
        if ($null -ne $sidebarBottom -and $sidebarBottom.ClientSize.Width -gt 0) {
            $bottomWidth = [Math]::Max(118, $sidebarBottom.ClientSize.Width - 8)
            foreach ($c in @($sidebarThemeLabel,$themeCombo,$sidebarStatus,$sidebarVersion)) {
                if ($null -ne $c) { $c.Width = $bottomWidth }
            }
            if ($null -ne $sidebarStatusSub) { $sidebarStatusSub.Width = [Math]::Max(100, $sidebarBottom.ClientSize.Width - 24) }
        }

        # Toolbar de um módulo integrado: pasta fica presa à direita e textos usam só o espaço restante.
        if ($null -ne $embeddedToolbar -and $embeddedToolbar.ClientSize.Width -gt 0) {
            $tw = [int]$embeddedToolbar.ClientSize.Width
            $embeddedFolderButton.Left = [Math]::Max(260, $tw - $embeddedFolderButton.Width - 12)
            $textWidth = [Math]::Max(120, $embeddedFolderButton.Left - $embeddedTitle.Left - 12)
            $embeddedTitle.Width = $textWidth
            $embeddedTitle.AutoEllipsis = $true
            $embeddedSubtitle.Width = [Math]::Max(120, $embeddedFolderButton.Left - $embeddedSubtitle.Left - 12)
            $embeddedSubtitle.AutoEllipsis = $true
        }

        Update-ResponsiveLayout
    } catch {}
}


$script:CentralAdaptiveBusy = $false
$script:CentralAdaptiveProfile = ""

function Get-CentralLogicalViewport {
    $dpi = 96
    try { if ($form.DeviceDpi -gt 0) { $dpi = [int]$form.DeviceDpi } } catch {}
    $w = [Math]::Max(1, [int]$form.ClientSize.Width)
    $h = [Math]::Max(1, [int]$form.ClientSize.Height)
    [pscustomobject]@{
        Dpi = $dpi
        Scale = [Math]::Round($dpi / 96.0, 2)
        Width = $w
        Height = $h
        LogicalWidth = [int][Math]::Round($w * 96.0 / $dpi)
        LogicalHeight = [int][Math]::Round($h * 96.0 / $dpi)
    }
}

function Update-CentralAdaptiveLayout {
    if ($script:CentralAdaptiveBusy -or $null -eq $form -or $null -eq $rootLayout) { return }
    $script:CentralAdaptiveBusy = $true
    try {
        $m = Get-CentralLogicalViewport
        $profile = if ($m.LogicalWidth -lt 1040 -or $m.LogicalHeight -lt 650) { "Compact" } elseif ($m.LogicalWidth -lt 1280 -or $m.LogicalHeight -lt 760) { "Balanced" } else { "Comfortable" }
        $script:CentralAdaptiveProfile = $profile

        switch ($profile) {
            "Compact" {
                $rootLayout.ColumnStyles[0].Width = 174
                $sidebar.Padding = [Windows.Forms.Padding]::new(10, 12, 10, 10)
                $brandPanel.Height = 92
                $brandMark.Size = [Drawing.Size]::new(40, 40)
                $brandMark.Location = [Drawing.Point]::new(2, 2)
                $brandTitle.Location = [Drawing.Point]::new(50, 0)
                $brandTitle.Size = [Drawing.Size]::new(106, 46)
                $brandTitle.Font = [Drawing.Font]::new("Segoe UI Semibold", 11.5)
                $brandSub.Location = [Drawing.Point]::new(2, 53)
                $brandSub.Size = [Drawing.Size]::new(150, 22)
                $brandSub.Font = [Drawing.Font]::new("Segoe UI", 7.5)
                $sidebarSection.Height = 25
                $navPanel.Height = 180
                foreach ($b in @($navHome,$navUpdates,$navFolder,$navAbout)) { $b.Width = 154; $b.Height = 35; $b.Margin = [Windows.Forms.Padding]::new(0,0,0,4); $b.Font = [Drawing.Font]::new("Segoe UI Semibold", 8.2) }
                $sidebarBottom.Height = 137
                $embeddedToolbar.Height = 44
                $embeddedBackButton.Size = [Drawing.Size]::new(92, 30)
                $embeddedBackButton.Location = [Drawing.Point]::new(9, 7)
                $embeddedTitle.Location = [Drawing.Point]::new(112, 2)
                $embeddedTitle.Font = [Drawing.Font]::new("Segoe UI Semibold", 11.5)
                $embeddedSubtitle.Location = [Drawing.Point]::new(114, 24)
                $embeddedSubtitle.Font = [Drawing.Font]::new("Segoe UI", 7.3)
                $embeddedFolderButton.Size = [Drawing.Size]::new(132, 30)
                $embeddedFolderButton.Top = 7
            }
            "Balanced" {
                $rootLayout.ColumnStyles[0].Width = 190
                $sidebar.Padding = [Windows.Forms.Padding]::new(13, 15, 13, 12)
                $brandPanel.Height = 104
                $brandMark.Size = [Drawing.Size]::new(44,44)
                $brandTitle.Location = [Drawing.Point]::new(55, 1)
                $brandTitle.Size = [Drawing.Size]::new(111,50)
                $brandTitle.Font = [Drawing.Font]::new("Segoe UI Semibold", 12.2)
                $brandSub.Location = [Drawing.Point]::new(3, 60)
                $brandSub.Size = [Drawing.Size]::new(164,24)
                $brandSub.Font = [Drawing.Font]::new("Segoe UI", 8)
                $sidebarSection.Height = 28
                $navPanel.Height = 195
                foreach ($b in @($navHome,$navUpdates,$navFolder,$navAbout)) { $b.Width = 164; $b.Height = 38; $b.Margin = [Windows.Forms.Padding]::new(0,0,0,5); $b.Font = [Drawing.Font]::new("Segoe UI Semibold", 8.6) }
                $sidebarBottom.Height = 146
                $embeddedToolbar.Height = 47
                $embeddedBackButton.Size = [Drawing.Size]::new(96,31)
                $embeddedBackButton.Location = [Drawing.Point]::new(10,8)
                $embeddedTitle.Location = [Drawing.Point]::new(120,3)
                $embeddedTitle.Font = [Drawing.Font]::new("Segoe UI Semibold", 12.2)
                $embeddedSubtitle.Location = [Drawing.Point]::new(122,25)
                $embeddedSubtitle.Font = [Drawing.Font]::new("Segoe UI",7.7)
                $embeddedFolderButton.Size = [Drawing.Size]::new(140,31)
                $embeddedFolderButton.Top = 8
            }
            default {
                $rootLayout.ColumnStyles[0].Width = 210
                $sidebar.Padding = [Windows.Forms.Padding]::new(16,18,16,16)
                $brandPanel.Height = 118
                $brandMark.Size = [Drawing.Size]::new(48,48)
                $brandTitle.Location = [Drawing.Point]::new(62,1)
                $brandTitle.Size = [Drawing.Size]::new(116,54)
                $brandTitle.Font = [Drawing.Font]::new("Segoe UI Semibold",13)
                $brandSub.Location = [Drawing.Point]::new(4,67)
                $brandSub.Size = [Drawing.Size]::new(174,26)
                $brandSub.Font = [Drawing.Font]::new("Segoe UI",8.5)
                $sidebarSection.Height = 30
                $navPanel.Height = 210
                foreach ($b in @($navHome,$navUpdates,$navFolder,$navAbout)) { $b.Width = 178; $b.Height = 42; $b.Margin = [Windows.Forms.Padding]::new(0,0,0,6); $b.Font = [Drawing.Font]::new("Segoe UI Semibold",9) }
                $sidebarBottom.Height = 156
                $embeddedToolbar.Height = 50
                $embeddedBackButton.Size = [Drawing.Size]::new(100,32)
                $embeddedBackButton.Location = [Drawing.Point]::new(12,9)
                $embeddedTitle.Location = [Drawing.Point]::new(126,4)
                $embeddedTitle.Font = [Drawing.Font]::new("Segoe UI Semibold",13)
                $embeddedSubtitle.Location = [Drawing.Point]::new(128,27)
                $embeddedSubtitle.Font = [Drawing.Font]::new("Segoe UI",8)
                $embeddedFolderButton.Size = [Drawing.Size]::new(150,32)
                $embeddedFolderButton.Top = 9
            }
        }
        # A altura visual da toolbar precisa ser a altura real da linha que a
        # hospeda; alterar somente Panel.Height não muda uma linha Absolute.
        try {
            if ($null -ne $embeddedLayout -and $embeddedLayout.RowStyles.Count -ge 2) {
                $embeddedLayout.RowStyles[0].Height = [Math]::Max(40, [int]$embeddedToolbar.Height)
            }
        } catch {}
        try { $embeddedFolderButton.Left = [Math]::Max(260, $embeddedToolbar.ClientSize.Width - $embeddedFolderButton.Width - 12) } catch {}
        Update-CentralChromeLayout
    }
    finally { $script:CentralAdaptiveBusy = $false }
}

function Open-RootFolder {
    try {
        Start-Process -FilePath "explorer.exe" -ArgumentList ('"' + $script:RootPath + '"')
        Set-StatusMessage "Pasta da Central de Trabalho aberta." "Success"
    }
    catch {
        Set-StatusMessage "Não foi possível abrir a pasta do programa." "Error"
    }
}

$form = $null
$themeCombo = $null
try {
    $settings = Get-AppSettings

    $form = New-Object Windows.Forms.Form

# A janela usa a mesma identidade visual gravada no Central de Trabalho.exe.
# Assim, Explorador, barra de tarefas, Alt+Tab e a própria janela mostram o ícone CT.
try {
    $executablePath = [Windows.Forms.Application]::ExecutablePath
    if ([IO.File]::Exists($executablePath)) {
        $applicationIcon = [Drawing.Icon]::ExtractAssociatedIcon($executablePath)
        if ($null -ne $applicationIcon) { $form.Icon = $applicationIcon }
    }
}
catch {
    # A identidade visual não pode impedir a abertura da Central.
}

$form.Text = "Central de Trabalho"
$form.StartPosition = [Windows.Forms.FormStartPosition]::CenterScreen
$form.AutoScaleMode = [Windows.Forms.AutoScaleMode]::Dpi
$form.Font = [Drawing.Font]::new("Segoe UI", 9.5)
$form.MaximizeBox = $true
$form.MinimizeBox = $true
$form.SizeGripStyle = [Windows.Forms.SizeGripStyle]::Show
$form.KeyPreview = $true

# A janela nasce sempre dentro da área útil do monitor atual. O WinForms cuida do DPI;
# o layout abaixo usa a área efetivamente disponível para escolher uma densidade visual.
$workingArea = [Windows.Forms.Screen]::PrimaryScreen.WorkingArea
$targetWidth = [Math]::Min($workingArea.Width, [Math]::Max(840, [int]($workingArea.Width * 0.94)))
$targetHeight = [Math]::Min($workingArea.Height, [Math]::Max(560, [int]($workingArea.Height * 0.94)))
$minimumWidth = [Math]::Min(900, $workingArea.Width)
$minimumHeight = [Math]::Min(620, $workingArea.Height)
$form.MinimumSize = [Drawing.Size]::new([int]$minimumWidth, [int]$minimumHeight)
$form.Size = [Drawing.Size]::new([int]$targetWidth, [int]$targetHeight)

$rootLayout = New-Object Windows.Forms.TableLayoutPanel
$rootLayout.Dock = [Windows.Forms.DockStyle]::Fill
$rootLayout.Margin = [Windows.Forms.Padding]::new(0)
$rootLayout.Padding = [Windows.Forms.Padding]::new(0)
$rootLayout.ColumnCount = 2
$rootLayout.RowCount = 1
[void]$rootLayout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Absolute, 226)))
[void]$rootLayout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 100)))
$form.Controls.Add($rootLayout)

# --- Barra lateral ---
$sidebar = New-Object Windows.Forms.Panel
$sidebar.Dock = [Windows.Forms.DockStyle]::Fill
$sidebar.Padding = [Windows.Forms.Padding]::new(16, 18, 16, 16)
$rootLayout.Controls.Add($sidebar, 0, 0)

$brandPanel = New-Object Windows.Forms.Panel
$brandPanel.Dock = [Windows.Forms.DockStyle]::Top
$brandPanel.Height = 118
$sidebar.Controls.Add($brandPanel)

$brandMark = New-Object Windows.Forms.Label
$brandMark.Text = "CT"
$brandMark.Size = [Drawing.Size]::new(48, 48)
$brandMark.Location = [Drawing.Point]::new(4, 4)
$brandMark.TextAlign = [Drawing.ContentAlignment]::MiddleCenter
$brandMark.Font = [Drawing.Font]::new("Segoe UI Black", 13)
$brandMark.BackColor = [Drawing.Color]::FromArgb(28, 145, 196)
$brandMark.ForeColor = [Drawing.Color]::White
$brandPanel.Controls.Add($brandMark)

$brandTitle = New-Object Windows.Forms.Label
$brandTitle.Text = "CENTRAL DE`r`nTRABALHO"
$brandTitle.Location = [Drawing.Point]::new(62, 1)
$brandTitle.Size = [Drawing.Size]::new(130, 54)
$brandTitle.Font = [Drawing.Font]::new("Segoe UI Semibold", 13)
$brandTitle.TextAlign = [Drawing.ContentAlignment]::MiddleLeft
$brandPanel.Controls.Add($brandTitle)

$brandSub = New-Object Windows.Forms.Label
$brandSub.Text = "Organização • Controle"
$brandSub.Location = [Drawing.Point]::new(4, 67)
$brandSub.Size = [Drawing.Size]::new(190, 26)
$brandSub.Font = [Drawing.Font]::new("Segoe UI", 8.5)
$brandPanel.Controls.Add($brandSub)

$sidebarSection = New-Object Windows.Forms.Label
$sidebarSection.Text = "NAVEGAÇÃO"
$sidebarSection.Dock = [Windows.Forms.DockStyle]::Top
$sidebarSection.Height = 30
$sidebarSection.Padding = [Windows.Forms.Padding]::new(8, 4, 0, 0)
$sidebarSection.Font = [Drawing.Font]::new("Segoe UI Semibold", 8)
$sidebar.Controls.Add($sidebarSection)
$sidebarSection.BringToFront()

$navPanel = New-Object Windows.Forms.FlowLayoutPanel
$navPanel.Dock = [Windows.Forms.DockStyle]::Top
$navPanel.Height = 210
$navPanel.FlowDirection = [Windows.Forms.FlowDirection]::TopDown
$navPanel.WrapContents = $false
$navPanel.Padding = [Windows.Forms.Padding]::new(0, 4, 0, 0)
$sidebar.Controls.Add($navPanel)
$navPanel.BringToFront()

function New-SidebarButton([string]$Text) {
    $button = New-Object Windows.Forms.Button
    $button.Text = "  " + $Text
    $button.Width = 188
    $button.Height = 42
    $button.Margin = [Windows.Forms.Padding]::new(0, 0, 0, 6)
    return $button
}

$navHome = New-SidebarButton "⌂   Início"
$navUpdates = New-SidebarButton "↻   Atualizações"
$navFolder = New-SidebarButton "▣   Pasta da Central"
$navAbout = New-SidebarButton "ⓘ   Sobre"
foreach ($button in @($navHome, $navUpdates, $navFolder, $navAbout)) { $navPanel.Controls.Add($button) }

$sidebarBottom = New-Object Windows.Forms.Panel
$sidebarBottom.Dock = [Windows.Forms.DockStyle]::Bottom
$sidebarBottom.Height = 156
$sidebar.Controls.Add($sidebarBottom)

$sidebarThemeLabel = New-Object Windows.Forms.Label
$sidebarThemeLabel.Text = "Aparência"
$sidebarThemeLabel.Location = [Drawing.Point]::new(4, 2)
$sidebarThemeLabel.Size = [Drawing.Size]::new(184, 22)
$sidebarThemeLabel.Font = [Drawing.Font]::new("Segoe UI Semibold", 8.5)
$sidebarBottom.Controls.Add($sidebarThemeLabel)

$themeCombo = New-Object Windows.Forms.ComboBox
$themeCombo.Location = [Drawing.Point]::new(4, 27)
$themeCombo.Size = [Drawing.Size]::new(184, 30)
$themeCombo.DropDownStyle = [Windows.Forms.ComboBoxStyle]::DropDownList
$themeCombo.DrawMode = [Windows.Forms.DrawMode]::Normal
$themeCombo.FlatStyle = [Windows.Forms.FlatStyle]::Popup
$themeCombo.IntegralHeight = $true
[void]$themeCombo.Items.AddRange(@("Escuro profissional", "Técnico industrial", "Claro corporativo", "Alto contraste"))
$themeCombo.SelectedItem = $settings.Theme
if ($themeCombo.SelectedIndex -lt 0) { $themeCombo.SelectedIndex = 0 }
$sidebarBottom.Controls.Add($themeCombo)

$sidebarStatus = New-Object Windows.Forms.Label
$sidebarStatus.Text = "●  Sistema pronto"
$sidebarStatus.Location = [Drawing.Point]::new(4, 75)
$sidebarStatus.Size = [Drawing.Size]::new(184, 24)
$sidebarStatus.Font = [Drawing.Font]::new("Segoe UI Semibold", 9)
$sidebarBottom.Controls.Add($sidebarStatus)

$sidebarStatusSub = New-Object Windows.Forms.Label
$sidebarStatusSub.Text = "2 módulos disponíveis"
$sidebarStatusSub.Location = [Drawing.Point]::new(20, 98)
$sidebarStatusSub.Size = [Drawing.Size]::new(170, 20)
$sidebarStatusSub.Font = [Drawing.Font]::new("Segoe UI", 8)
$sidebarBottom.Controls.Add($sidebarStatusSub)

$sidebarVersion = New-Object Windows.Forms.Label
$sidebarVersion.Text = "Central v$($script:AppVersion)"
$sidebarVersion.Location = [Drawing.Point]::new(4, 123)
$sidebarVersion.Size = [Drawing.Size]::new(184, 20)
$sidebarVersion.Font = [Drawing.Font]::new("Segoe UI", 8)
$sidebarBottom.Controls.Add($sidebarVersion)

# --- Conteúdo principal ---
$mainPanel = New-Object Windows.Forms.Panel
$mainPanel.Dock = [Windows.Forms.DockStyle]::Fill
$mainPanel.Padding = [Windows.Forms.Padding]::new(0)
$rootLayout.Controls.Add($mainPanel, 1, 0)

$mainLayout = New-Object Windows.Forms.TableLayoutPanel
$mainLayout.Dock = [Windows.Forms.DockStyle]::Fill
$mainLayout.ColumnCount = 1
$mainLayout.RowCount = 3
[void]$mainLayout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 92)))
[void]$mainLayout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 100)))
[void]$mainLayout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 44)))

$mainPanel.Controls.Add($mainLayout)

# --- Hospedagem interna dos programas ---
$embeddedHost = New-Object Windows.Forms.Panel
$embeddedHost.Dock = [Windows.Forms.DockStyle]::Fill
$embeddedHost.Visible = $false
$mainPanel.Controls.Add($embeddedHost)

# IMPORTANTE: toolbar e conteúdo não podem compartilhar o mesmo Panel com
# Dock=Top/Fill. No WinForms o controle Fill pode ocupar a área inteira e ficar
# por baixo da toolbar, escondendo a faixa superior do módulo (as abas da
# Manutenção eram justamente os primeiros pixels encobertos). Um TableLayout
# com duas linhas reserva fisicamente a altura da toolbar.
$embeddedLayout = New-Object Windows.Forms.TableLayoutPanel
$embeddedLayout.Dock = [Windows.Forms.DockStyle]::Fill
$embeddedLayout.Margin = [Windows.Forms.Padding]::new(0)
$embeddedLayout.Padding = [Windows.Forms.Padding]::new(0)
$embeddedLayout.ColumnCount = 1
$embeddedLayout.RowCount = 2
[void]$embeddedLayout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 100)))
[void]$embeddedLayout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 50)))
[void]$embeddedLayout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 100)))
$embeddedHost.Controls.Add($embeddedLayout)

$embeddedToolbar = New-Object Windows.Forms.Panel
$embeddedToolbar.Dock = [Windows.Forms.DockStyle]::Fill
$embeddedToolbar.Margin = [Windows.Forms.Padding]::new(0)
$embeddedToolbar.Padding = [Windows.Forms.Padding]::new(12, 6, 12, 6)
$embeddedLayout.Controls.Add($embeddedToolbar, 0, 0)

$embeddedAccentLine = New-Object Windows.Forms.Panel
$embeddedAccentLine.Dock = [Windows.Forms.DockStyle]::Bottom
$embeddedAccentLine.Height = 2
$embeddedToolbar.Controls.Add($embeddedAccentLine)
$embeddedAccentLine.BringToFront()

$embeddedBackButton = New-Object Windows.Forms.Button
$embeddedBackButton.Text = "←  CENTRAL"
$embeddedBackButton.Location = [Drawing.Point]::new(12, 9)
$embeddedBackButton.Size = [Drawing.Size]::new(100, 32)
$embeddedBackButton.Font = [Drawing.Font]::new("Segoe UI Semibold", 8.7)
$embeddedToolbar.Controls.Add($embeddedBackButton)

$embeddedTitle = New-Object Windows.Forms.Label
$embeddedTitle.Text = "Programa"
$embeddedTitle.Location = [Drawing.Point]::new(126, 4)
$embeddedTitle.Size = [Drawing.Size]::new(520, 22)
$embeddedTitle.Font = [Drawing.Font]::new("Segoe UI Semibold", 13)
$embeddedToolbar.Controls.Add($embeddedTitle)

$embeddedSubtitle = New-Object Windows.Forms.Label
$embeddedSubtitle.Text = "Aberto dentro da Central de Trabalho"
$embeddedSubtitle.Location = [Drawing.Point]::new(128, 27)
$embeddedSubtitle.Size = [Drawing.Size]::new(620, 18)
$embeddedSubtitle.Font = [Drawing.Font]::new("Segoe UI", 8)
$embeddedToolbar.Controls.Add($embeddedSubtitle)

$embeddedFolderButton = New-Object Windows.Forms.Button
$embeddedFolderButton.Text = "PASTA DO MÓDULO"
$embeddedFolderButton.Anchor = [Windows.Forms.AnchorStyles]::Top -bor [Windows.Forms.AnchorStyles]::Right
$embeddedFolderButton.Size = [Drawing.Size]::new(150, 32)
$embeddedFolderButton.Location = [Drawing.Point]::new([Math]::Max(690, $targetWidth - 380), 9)
$embeddedFolderButton.Font = [Drawing.Font]::new("Segoe UI Semibold", 8.2)
$embeddedToolbar.Controls.Add($embeddedFolderButton)

$embeddedContent = New-Object Windows.Forms.Panel
$embeddedContent.Dock = [Windows.Forms.DockStyle]::Fill
$embeddedContent.Margin = [Windows.Forms.Padding]::new(0)
$embeddedContent.Padding = [Windows.Forms.Padding]::new(0)
$embeddedLayout.Controls.Add($embeddedContent, 0, 1)

$embeddedLoading = New-Object Windows.Forms.Label
$embeddedLoading.Text = "Carregando módulo..."
$embeddedLoading.Dock = [Windows.Forms.DockStyle]::Fill
$embeddedLoading.TextAlign = [Drawing.ContentAlignment]::MiddleCenter
$embeddedLoading.Font = [Drawing.Font]::new("Segoe UI Semibold", 13)
$embeddedContent.Controls.Add($embeddedLoading)
$embeddedLoading.BringToFront()

$embeddedWatchTimer = New-Object Windows.Forms.Timer
$embeddedWatchTimer.Interval = 500
$embeddedWatchTimer.Add_Tick({
    try {
        if ($embeddedHost.Visible -and $null -ne $script:HostedForm) {
            if ($script:HostedForm.IsDisposed) {
                Close-EmbeddedModule -Force
                Show-Dashboard -SkipClose
                Set-StatusMessage "O módulo integrado foi fechado." "Normal"
            }
        }
    } catch {}
})
$embeddedWatchTimer.Start()

$centralHealthTimer = New-Object Windows.Forms.Timer
$centralHealthTimer.Interval = 3000
$centralHealthTimer.Add_Tick({
    try { Update-CentralAvailabilityState } catch {}
})
$centralHealthTimer.Start()

$headerPanel = New-Object Windows.Forms.Panel
$headerPanel.Dock = [Windows.Forms.DockStyle]::Fill
$headerPanel.Padding = [Windows.Forms.Padding]::new(28, 13, 26, 8)
$mainLayout.Controls.Add($headerPanel, 0, 0)

$pageTitle = New-Object Windows.Forms.Label
$pageTitle.Text = "Visão geral"
$pageTitle.Location = [Drawing.Point]::new(28, 12)
$pageTitle.AutoSize = $true
$pageTitle.Font = [Drawing.Font]::new("Segoe UI Semibold", 21)
$headerPanel.Controls.Add($pageTitle)

$pageSubtitle = New-Object Windows.Forms.Label
$pageSubtitle.Text = "Acesse seus programas e acompanhe o estado da Central em um só lugar."
$pageSubtitle.Location = [Drawing.Point]::new(31, 51)
$pageSubtitle.Size = [Drawing.Size]::new(720, 28)
$pageSubtitle.Font = [Drawing.Font]::new("Segoe UI", 10.5)
$headerPanel.Controls.Add($pageSubtitle)

$todayLabel = New-Object Windows.Forms.Label
$todayLabel.Text = (Get-Date).ToString("dd/MM/yyyy")
$todayLabel.Anchor = [Windows.Forms.AnchorStyles]::Top -bor [Windows.Forms.AnchorStyles]::Right
$todayLabel.TextAlign = [Drawing.ContentAlignment]::MiddleRight
$todayLabel.Size = [Drawing.Size]::new(125, 25)
$todayLabel.Location = [Drawing.Point]::new([Math]::Max(760, $targetWidth - 455), 15)
$todayLabel.Font = [Drawing.Font]::new("Segoe UI", 9)
$headerPanel.Controls.Add($todayLabel)

$headerAccent = New-Object Windows.Forms.Panel
$headerAccent.Dock = [Windows.Forms.DockStyle]::Bottom
$headerAccent.Height = 2
$headerPanel.Controls.Add($headerAccent)

$modulesHost = New-Object Windows.Forms.Panel
$modulesHost.Dock = [Windows.Forms.DockStyle]::Fill
$modulesHost.Padding = [Windows.Forms.Padding]::new(18, 0, 18, 4)
$mainLayout.Controls.Add($modulesHost, 0, 1)

# O cabeçalho e os cartões ficam em linhas diferentes para nunca se sobreporem.
$modulesLayout = New-Object Windows.Forms.TableLayoutPanel
$modulesLayout.Dock = [Windows.Forms.DockStyle]::Fill
$modulesLayout.Margin = [Windows.Forms.Padding]::new(0)
$modulesLayout.Padding = [Windows.Forms.Padding]::new(0)
$modulesLayout.ColumnCount = 1
$modulesLayout.RowCount = 2
[void]$modulesLayout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 50)))
[void]$modulesLayout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 100)))
$modulesHost.Controls.Add($modulesLayout)

$programsHeader = New-Object Windows.Forms.Panel
$programsHeader.Dock = [Windows.Forms.DockStyle]::Fill
$programsHeader.Margin = [Windows.Forms.Padding]::new(0)
$modulesLayout.Controls.Add($programsHeader, 0, 0)

$programsTitle = New-Object Windows.Forms.Label
$programsTitle.Text = "Programas"
$programsTitle.Location = [Drawing.Point]::new(10, 0)
$programsTitle.AutoSize = $true
$programsTitle.Font = [Drawing.Font]::new("Segoe UI Semibold", 14)
$programsHeader.Controls.Add($programsTitle)

$programsSubtitle = New-Object Windows.Forms.Label
$programsSubtitle.Text = "Seus módulos principais, com acesso rápido às pastas e ferramentas."
$programsSubtitle.Location = [Drawing.Point]::new(12, 27)
$programsSubtitle.Size = [Drawing.Size]::new(720, 20)
$programsSubtitle.Font = [Drawing.Font]::new("Segoe UI", 8.8)
$programsHeader.Controls.Add($programsSubtitle)

$modulesFlow = New-Object Windows.Forms.FlowLayoutPanel
$modulesFlow.Dock = [Windows.Forms.DockStyle]::Fill
$modulesFlow.Margin = [Windows.Forms.Padding]::new(0)
$modulesFlow.FlowDirection = [Windows.Forms.FlowDirection]::LeftToRight
$modulesFlow.WrapContents = $true
$modulesFlow.AutoScroll = $true
$modulesFlow.Padding = [Windows.Forms.Padding]::new(8, 2, 8, 4)
$modulesLayout.Controls.Add($modulesFlow, 0, 1)

function New-ModuleCard {
    param([string]$IconText, [string]$Title, [string]$Description, [string]$Detail, [string]$ButtonText)
    $card = New-Object Windows.Forms.Panel
    $card.Margin = [Windows.Forms.Padding]::new(8)
    $card.Padding = [Windows.Forms.Padding]::new(0)

    $outer = New-Object Windows.Forms.TableLayoutPanel
    $outer.Dock = [Windows.Forms.DockStyle]::Fill
    $outer.ColumnCount = 2
    $outer.RowCount = 1
    [void]$outer.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Absolute, 6)))
    [void]$outer.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 100)))
    $card.Controls.Add($outer)

    $accent = New-Object Windows.Forms.Panel
    $accent.Dock = [Windows.Forms.DockStyle]::Fill
    $outer.Controls.Add($accent, 0, 0)

    $layout = New-Object Windows.Forms.TableLayoutPanel
    $layout.Dock = [Windows.Forms.DockStyle]::Fill
    $layout.Padding = [Windows.Forms.Padding]::new(16, 10, 16, 10)
    $layout.ColumnCount = 2
    $layout.RowCount = 5
    [void]$layout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Absolute, 70)))
    [void]$layout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 100)))
    [void]$layout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 36)))
    [void]$layout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 46)))
    [void]$layout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 100)))
    [void]$layout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 27)))
    [void]$layout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 40)))
    $outer.Controls.Add($layout, 1, 0)

    $icon = New-Object Windows.Forms.Label
    $icon.Text = $IconText
    $icon.Size = [Drawing.Size]::new(48, 48)
    $icon.Margin = [Windows.Forms.Padding]::new(0, 0, 12, 0)
    $icon.TextAlign = [Drawing.ContentAlignment]::MiddleCenter
    $icon.Font = [Drawing.Font]::new("Segoe UI Black", 10)
    $layout.Controls.Add($icon, 0, 0)
    $layout.SetRowSpan($icon, 2)

    $status = New-Object Windows.Forms.Label
    $status.Text = "  DISPONÍVEL  "
    $status.AutoSize = $true
    $status.Padding = [Windows.Forms.Padding]::new(4, 3, 4, 3)
    $status.Font = [Drawing.Font]::new("Segoe UI Semibold", 8)
    $status.Anchor = [Windows.Forms.AnchorStyles]::Left
    $layout.Controls.Add($status, 1, 0)

    $titleLabel = New-Object Windows.Forms.Label
    $titleLabel.Text = $Title
    $titleLabel.Dock = [Windows.Forms.DockStyle]::Fill
    $titleLabel.TextAlign = [Drawing.ContentAlignment]::MiddleLeft
    $titleLabel.Font = [Drawing.Font]::new("Segoe UI Semibold", 14.5)
    $layout.Controls.Add($titleLabel, 1, 1)

    $desc = New-Object Windows.Forms.Label
    $desc.Text = $Description
    $desc.Dock = [Windows.Forms.DockStyle]::Fill
    $desc.Font = [Drawing.Font]::new("Segoe UI", 9.2)
    $desc.TextAlign = [Drawing.ContentAlignment]::TopLeft
    $desc.Padding = [Windows.Forms.Padding]::new(0, 2, 0, 0)
    $layout.Controls.Add($desc, 0, 2)
    $layout.SetColumnSpan($desc, 2)

    $detailLabel = New-Object Windows.Forms.Label
    $detailLabel.Text = $Detail
    $detailLabel.Dock = [Windows.Forms.DockStyle]::Fill
    $detailLabel.TextAlign = [Drawing.ContentAlignment]::MiddleLeft
    $detailLabel.Font = [Drawing.Font]::new("Segoe UI", 8.2)
    $layout.Controls.Add($detailLabel, 0, 3)
    $layout.SetColumnSpan($detailLabel, 2)

    $buttonHost = New-Object Windows.Forms.TableLayoutPanel
    $buttonHost.Dock = [Windows.Forms.DockStyle]::Fill
    $buttonHost.ColumnCount = 2
    $buttonHost.RowCount = 1
    $buttonHost.Margin = [Windows.Forms.Padding]::new(0)
    [void]$buttonHost.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 72)))
    [void]$buttonHost.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 28)))
    $layout.Controls.Add($buttonHost, 0, 4)
    $layout.SetColumnSpan($buttonHost, 2)

    $button = New-Object Windows.Forms.Button
    $button.Text = $ButtonText
    $button.Dock = [Windows.Forms.DockStyle]::Fill
    $button.Margin = [Windows.Forms.Padding]::new(0, 0, 7, 0)
    $button.Font = [Drawing.Font]::new("Segoe UI Semibold", 8.8)
    $buttonHost.Controls.Add($button, 0, 0)

    $folderButton = New-Object Windows.Forms.Button
    $folderButton.Text = "PASTA"
    $folderButton.Dock = [Windows.Forms.DockStyle]::Fill
    $folderButton.Margin = [Windows.Forms.Padding]::new(7, 0, 0, 0)
    $folderButton.Font = [Drawing.Font]::new("Segoe UI Semibold", 8.5)
    $buttonHost.Controls.Add($folderButton, 1, 0)

    return @($card,$outer,$layout,$accent,$icon,$status,$titleLabel,$desc,$detailLabel,$button,$folderButton)
}

$g = New-ModuleCard "XLS" "Gerenciador de Planilhas" "Prepara mestres CB5 e TV5, gera e junta planilhas e acompanha componentes ainda pendentes de faturamento." "Versão integrada: $($script:GeneratorVersion)   •   Requer Microsoft Excel" "ABRIR GERENCIADOR"
$generatorCard=$g[0]; $generatorOuter=$g[1]; $generatorLayout=$g[2]; $generatorAccentBar=$g[3]; $generatorIcon=$g[4]; $generatorStatus=$g[5]; $generatorTitle=$g[6]; $generatorDescription=$g[7]; $generatorDetail=$g[8]; $openGeneratorButton=$g[9]; $openGeneratorFolderButton=$g[10]
$m = New-ModuleCard "CB5" "Central de Manutenção CB5" "Cadastro de peças por código, histórico automático por série, correção auditada, relatórios e apoio ao diagnóstico." "Versão integrada: $($script:MaintenanceVersion)   •   Histórico local por série" "ABRIR MANUTENÇÃO"
$maintenanceCard=$m[0]; $maintenanceOuter=$m[1]; $maintenanceLayout=$m[2]; $maintenanceAccentBar=$m[3]; $maintenanceIcon=$m[4]; $maintenanceStatus=$m[5]; $maintenanceTitle=$m[6]; $maintenanceDescription=$m[7]; $maintenanceDetail=$m[8]; $openMaintenanceButton=$m[9]; $openMaintenanceFolderButton=$m[10]
$modulesFlow.Controls.Add($generatorCard)
$modulesFlow.Controls.Add($maintenanceCard)

$footerPanel = New-Object Windows.Forms.Panel
$footerPanel.Dock = [Windows.Forms.DockStyle]::Fill
$footerPanel.Padding = [Windows.Forms.Padding]::new(26, 7, 26, 7)
$mainLayout.Controls.Add($footerPanel, 0, 2)

$footerLayout = New-Object Windows.Forms.TableLayoutPanel
$footerLayout.Dock = [Windows.Forms.DockStyle]::Fill
$footerLayout.ColumnCount = 2
$footerLayout.RowCount = 1
[void]$footerLayout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 100)))
[void]$footerLayout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::AutoSize)))
$footerPanel.Controls.Add($footerLayout)

$footerStatus = New-Object Windows.Forms.Label
$footerStatus.Dock = [Windows.Forms.DockStyle]::Fill
$footerStatus.TextAlign = [Drawing.ContentAlignment]::MiddleLeft
$footerStatus.AutoEllipsis = $true
$footerLayout.Controls.Add($footerStatus, 0, 0)

$footerVersion = New-Object Windows.Forms.Label
$footerVersion.Text = "Central v$($script:AppVersion)  •  Integração interna responsiva"
$footerVersion.AutoSize = $true
$footerVersion.Anchor = [Windows.Forms.AnchorStyles]::Right
$footerLayout.Controls.Add($footerVersion, 1, 0)
$footerVersion.Visible = $false

# Polimento visual seguro
$toolTip = New-Object Windows.Forms.ToolTip
$toolTip.AutoPopDelay = 5000
$toolTip.InitialDelay = 350
$toolTip.ReshowDelay = 100
$toolTip.SetToolTip($openGeneratorButton, "Abrir o Gerenciador de Planilhas dentro da Central")
$toolTip.SetToolTip($openGeneratorFolderButton, "Abrir a pasta do Gerenciador")
$toolTip.SetToolTip($openMaintenanceButton, "Abrir a Central de Manutenção CB5 dentro da Central")
$toolTip.SetToolTip($openMaintenanceFolderButton, "Abrir a pasta da Manutenção CB5")
$toolTip.SetToolTip($embeddedBackButton, "Voltar para a tela inicial da Central de Trabalho (Alt+←)")
$toolTip.SetToolTip($embeddedFolderButton, "Abrir a pasta do módulo que está em uso")

foreach ($roundedPanel in @($generatorCard,$maintenanceCard)) {
    Enable-RoundedControl $roundedPanel 12
    Enable-CardHover $roundedPanel
}
foreach ($roundedSmall in @($brandMark,$generatorIcon,$maintenanceIcon,$openGeneratorButton,$openMaintenanceButton,$openGeneratorFolderButton,$openMaintenanceFolderButton)) {
    Enable-RoundedControl $roundedSmall 8
}

# Ordem de foco: navegação da Central, aparência e ações principais.
$navHome.TabIndex = 0
$navUpdates.TabIndex = 1
$navFolder.TabIndex = 2
$navAbout.TabIndex = 3
$themeCombo.TabIndex = 4
$openGeneratorButton.TabIndex = 10
$openGeneratorFolderButton.TabIndex = 11
$openMaintenanceButton.TabIndex = 12
$openMaintenanceFolderButton.TabIndex = 13
$embeddedBackButton.TabIndex = 0
$embeddedFolderButton.TabIndex = 1

# Eventos
$themeCombo.Add_SelectedIndexChanged({
    try { Apply-AppTheme } catch {}
    try { Save-AppSettings } catch {}
    try { Sync-HostedModuleTheme } catch {}
    try { Set-StatusMessage ("Aparência aplicada: " + [string]$themeCombo.SelectedItem + ".") "Success" } catch {}
})
$openGeneratorButton.Add_Click({ Start-GeneratorModule })
$openMaintenanceButton.Add_Click({ Start-MaintenanceModule })
$openGeneratorFolderButton.Add_Click({ Open-ModuleFolder $script:GeneratorDirectory "Gerenciador de Planilhas" })
$openMaintenanceFolderButton.Add_Click({ Open-ModuleFolder $script:MaintenanceDirectory "Central de Manutenção CB5" })
$navUpdates.Add_Click({ Start-UpdaterModule; Set-ActiveNavigation "Home" })
$navFolder.Add_Click({ Open-RootFolder; Set-ActiveNavigation "Home" })
$navHome.Add_Click({ Show-Dashboard })
$navAbout.Add_Click({
    Set-ActiveNavigation "About"
    [Windows.Forms.MessageBox]::Show(
        "Central de Trabalho v$($script:AppVersion)`r`n`r`nIntegra o Gerenciador de Planilhas, a Central de Manutenção CB5 e o sistema de atualização.`r`n`r`nInterface integrada e responsiva para os módulos de trabalho, manutenção e atualização.",
        "Sobre a Central de Trabalho",
        [Windows.Forms.MessageBoxButtons]::OK,
        [Windows.Forms.MessageBoxIcon]::Information
    ) | Out-Null
    Set-ActiveNavigation "Home"
})
$modulesFlow.Add_SizeChanged({ Update-CentralChromeLayout })
$form.Add_Shown({ Update-CentralAdaptiveLayout; Update-ResponsiveLayout; Apply-AppTheme; Update-CentralAvailabilityState })
$form.Add_SizeChanged({
    try { Update-CentralAdaptiveLayout } catch {}
})
$embeddedBackButton.Add_Click({ Show-Dashboard })
$embeddedFolderButton.Add_Click({
    if ($script:EmbeddedModule -eq "Generator") { Open-ModuleFolder $script:GeneratorDirectory "Gerenciador de Planilhas" }
    elseif ($script:EmbeddedModule -eq "Maintenance") { Open-ModuleFolder $script:MaintenanceDirectory "Central de Manutenção CB5" }
})
$embeddedHost.Add_SizeChanged({
    try { $embeddedFolderButton.Left = [Math]::Max(380, $embeddedToolbar.ClientSize.Width - $embeddedFolderButton.Width - 12); Update-CentralAdaptiveLayout } catch {}
})
$embeddedContent.Add_SizeChanged({
    try {
        if ($null -ne $script:HostedForm -and -not $script:HostedForm.IsDisposed) {
            $script:HostedForm.Bounds = $embeddedContent.ClientRectangle
            $script:HostedForm.PerformLayout()
            if ($null -ne $script:HostedModule) {
                & $script:HostedModule {
                    if (Get-Command Update-MaintenanceResponsiveLayout -ErrorAction SilentlyContinue) {
                        Update-MaintenanceResponsiveLayout
                    }
                    elseif (Get-Command Update-GeneratorResponsiveLayout -ErrorAction SilentlyContinue) {
                        Update-GeneratorResponsiveLayout
                        if (Get-Command Update-RootLayout -ErrorAction SilentlyContinue) { Update-RootLayout }
                    }
                }
            }
        }
    } catch {}
})
try { $form.Add_DpiChanged({ Update-CentralAdaptiveLayout }) } catch {}
$form.Add_KeyDown({
    param($sender, $eventArgs)
    try {
        if ($eventArgs.Alt -and $eventArgs.KeyCode -eq [Windows.Forms.Keys]::Left -and $embeddedHost.Visible) {
            Show-Dashboard
            $eventArgs.Handled = $true
            $eventArgs.SuppressKeyPress = $true
        }
    } catch {}
})
$form.Add_FormClosing({ Close-EmbeddedModule; Save-AppSettings })

    Apply-AppTheme
    [void]$form.ShowDialog()
}
catch {
    $details = "Falha ao iniciar a Central de Trabalho.`r`n`r`n" + $_.Exception.Message + "`r`n`r`nLinha: " + $_.InvocationInfo.ScriptLineNumber
    try {
        $logPath = [IO.Path]::Combine($script:RootPath, "ERRO-INICIALIZACAO.txt")
        [IO.File]::WriteAllText($logPath, $details, [Text.UTF8Encoding]::new($true))
    }
    catch {}
    [Windows.Forms.MessageBox]::Show(
        $details + "`r`n`r`nSe precisar, envie o arquivo ERRO-INICIALIZACAO.txt.",
        "Central de Trabalho — erro de inicialização",
        [Windows.Forms.MessageBoxButtons]::OK,
        [Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
}
finally {
    if ($null -ne $themeCombo) { Save-AppSettings }
    try { if ($null -ne $embeddedWatchTimer) { $embeddedWatchTimer.Stop(); $embeddedWatchTimer.Dispose() } } catch {}
    try { if ($null -ne $centralHealthTimer) { $centralHealthTimer.Stop(); $centralHealthTimer.Dispose() } } catch {}
    try { if ($null -ne $script:UpdaterProcess -and $script:UpdaterProcess.HasExited) { $script:UpdaterProcess.Dispose() } } catch {}
    try { Close-EmbeddedModule -Force } catch {}
    if ($null -ne $form) { $form.Dispose() }
    Close-CentralSingleInstanceMutex
}

# UI_DEDUP_CENTRAL_V0113
