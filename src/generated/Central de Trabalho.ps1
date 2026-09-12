param(
    [switch]$ThemeRuntimeSelfTest,
    [string]$ThemeRuntimeReportPath = "",
    [string]$ThemeRuntimeArtifactsPath = ""
)

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

$script:AppVersion = "0.21.33"
$script:RootPath = $PSScriptRoot
$script:GeneratorVersion = "3.7.10"
$script:MaintenanceVersion = "0.6.8"
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
$script:NFEntradaVersion = "2.6.9"
$script:NFEntradaDirectory = [IO.Path]::Combine(
    $script:RootPath,
    "Modulos",
    "Controle-NF-Entrada"
)
$script:NFEntradaScript = [IO.Path]::Combine($script:NFEntradaDirectory, "Controle NF Entrada.ps1")
$script:NFEntradaCore = [IO.Path]::Combine($script:NFEntradaDirectory, "NFEntrada.Core.ps1")
$script:UpdaterDirectory = [IO.Path]::Combine($script:RootPath, "Atualizador")
$script:UpdaterExecutable = [IO.Path]::Combine($script:UpdaterDirectory, "Central de Trabalho Updater.exe")
$script:UpdaterScript = [IO.Path]::Combine($script:UpdaterDirectory, "Central de Trabalho Updater.ps1")
$script:UpdaterCore = [IO.Path]::Combine($script:UpdaterDirectory, "Update.Core.ps1")
$script:UpdaterChannels = [IO.Path]::Combine($script:UpdaterDirectory, "CANAIS.json")
$centralLocalDataRoot = [Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData)
if ($ThemeRuntimeSelfTest -and $env:CENTRAL_THEME_RUNTIME_TEST -eq "1" -and -not [string]::IsNullOrWhiteSpace($env:CENTRAL_THEME_TEST_DATA_ROOT)) {
    $centralLocalDataRoot = [IO.Path]::GetFullPath($env:CENTRAL_THEME_TEST_DATA_ROOT)
}
$script:SettingsDirectory = [IO.Path]::Combine($centralLocalDataRoot, "CentralDeTrabalho")
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
$script:LastThemeSyncError = ""
$script:CentralThemeCombo = $null
$script:CentralThemeChanging = $false
$script:CentralTheme = "Escuro profissional"
$script:AppliedCentralTheme = "Escuro profissional"
$script:PendingCentralTheme = ""
$script:CentralThemeDispatchScheduled = $false
$script:ThemeTransactionFailureCount = 0
$script:HostedThemeContext = [pscustomobject]@{
    Theme = "Escuro profissional"
    Revision = 0
}

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
            Theme = (Get-CentralSelectedTheme)
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
    $nfEntradaRequired = @($script:NFEntradaScript, $script:NFEntradaCore)
    $updaterRequired = @($script:UpdaterExecutable, $script:UpdaterScript, $script:UpdaterCore, $script:UpdaterChannels)

    $generatorMissing = @($generatorRequired | Where-Object { -not [IO.File]::Exists($_) })
    $maintenanceMissing = @($maintenanceRequired | Where-Object { -not [IO.File]::Exists($_) })
    $nfEntradaMissing = @($nfEntradaRequired | Where-Object { -not [IO.File]::Exists($_) })
    $updaterMissing = @($updaterRequired | Where-Object { -not [IO.File]::Exists($_) })

    [pscustomobject]@{
        GeneratorAvailable = ($generatorMissing.Count -eq 0)
        MaintenanceAvailable = ($maintenanceMissing.Count -eq 0)
        NFEntradaAvailable = ($nfEntradaMissing.Count -eq 0)
        UpdaterAvailable = ($updaterMissing.Count -eq 0)
        GeneratorMissing = $generatorMissing
        MaintenanceMissing = $maintenanceMissing
        NFEntradaMissing = $nfEntradaMissing
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
    $script:LastThemeSyncError = ""
    if ($null -eq $script:HostedModule -or [string]::IsNullOrWhiteSpace($script:EmbeddedModule)) { return $true }
    if ($null -eq $script:HostedForm -or $script:HostedForm.IsDisposed) { return $true }

    $theme = (Get-CentralSelectedTheme)
    if ([string]::IsNullOrWhiteSpace($theme)) { $theme = "Escuro profissional" }
    if ($null -eq $script:HostedThemeContext -or [string]$script:HostedThemeContext.Theme -ne $theme) {
        [void](Set-CentralThemeAuthority $theme)
    }
    $moduleName = [string]$script:EmbeddedModule

    try {
        $handled = & $script:HostedModule {
            param($targetModule, $hostTheme, $hostRevision)

            $audit = $null
            switch ($targetModule) {
                "Maintenance" {
                    if ($null -eq (Get-Command -Name Set-HostedMaintenanceTheme -CommandType Function -ErrorAction SilentlyContinue)) {
                        throw "A função de aparência da Manutenção não foi encontrada."
                    }
                    $resultItems = @(Set-HostedMaintenanceTheme $hostTheme)
                    if ($resultItems.Count -eq 0 -or -not [bool]$resultItems[$resultItems.Count - 1]) {
                        throw "A Manutenção recusou a aparência selecionada."
                    }
                    $audit = Get-HostedMaintenanceThemeAudit
                }
                "Generator" {
                    if ($null -eq (Get-Command -Name Set-HostedGeneratorTheme -CommandType Function -ErrorAction SilentlyContinue)) {
                        throw "A função de aparência do Gerenciador não foi encontrada."
                    }
                    $resultItems = @(Set-HostedGeneratorTheme $hostTheme)
                    if ($resultItems.Count -eq 0 -or -not [bool]$resultItems[$resultItems.Count - 1]) {
                        throw "O Gerenciador recusou a aparência selecionada."
                    }
                    $audit = Get-HostedGeneratorThemeAudit
                }
                "NFEntrada" {
                    if ($null -eq (Get-Command -Name Set-HostedNFEntradaTheme -CommandType Function -ErrorAction SilentlyContinue)) {
                        throw "A função de aparência do Controle de NF não foi encontrada."
                    }
                    $resultItems = @(Set-HostedNFEntradaTheme $hostTheme)
                    if ($resultItems.Count -eq 0 -or -not [bool]$resultItems[$resultItems.Count - 1]) {
                        throw "O Controle de NF não conseguiu aplicar a aparência selecionada."
                    }
                    $audit = Get-HostedNFEntradaThemeAudit
                }
                default { throw "Módulo integrado desconhecido: $targetModule" }
            }

            if ($null -eq $audit) { throw "$targetModule não retornou auditoria visual." }
            if (-not [bool]$audit.Valid) {
                $invalidNames = @($audit.InvalidChecks | ForEach-Object { [string]$_.Name }) -join ", "
                throw "$targetModule terminou com controles fora da paleta: $invalidNames"
            }
            if ([string]$audit.AuthorityTheme -ne $hostTheme) {
                throw "$targetModule não reconheceu a autoridade da Central: '$($audit.AuthorityTheme)' != '$hostTheme'."
            }
            if ([int]$audit.Revision -ne [int]$hostRevision) {
                throw "$targetModule está na revisão de aparência $($audit.Revision), mas a Central está na revisão $hostRevision."
            }
            return $true
        } $moduleName $theme ([int]$script:HostedThemeContext.Revision)

        if (-not [bool]$handled) {
            $script:LastThemeSyncError = "O módulo não confirmou a aplicação da aparência."
            return $false
        }

        try {
            $script:HostedForm.PerformLayout()
            $script:HostedForm.Invalidate($true)
        } catch {}
        return $true
    }
    catch {
        $script:LastThemeSyncError = $_.Exception.Message
        return $false
    }
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
    param([ValidateSet("Generator", "Maintenance", "NFEntrada")][string]$Module)

    switch ($Module) {
        "Generator" {
            $moduleScript = $script:GeneratorScript
            $moduleName = "Gerenciador de Planilhas"
            $moduleVersion = $script:GeneratorVersion
        }
        "Maintenance" {
            $moduleScript = $script:MaintenanceScript
            $moduleName = "Central de Manutenção CB5"
            $moduleVersion = $script:MaintenanceVersion
        }
        default {
            $moduleScript = $script:NFEntradaScript
            $moduleName = "Controle de NF de Entrada"
            $moduleVersion = $script:NFEntradaVersion
        }
    }

    $health = Get-CentralHealthSnapshot
    switch ($Module) {
        "Generator" { $moduleAvailable = $health.GeneratorAvailable; $moduleMissing = @($health.GeneratorMissing) }
        "Maintenance" { $moduleAvailable = $health.MaintenanceAvailable; $moduleMissing = @($health.MaintenanceMissing) }
        default { $moduleAvailable = $health.NFEntradaAvailable; $moduleMissing = @($health.NFEntradaMissing) }
    }
    if (-not $moduleAvailable) {
        $missingText = Format-MissingCentralFiles $moduleMissing
        Set-StatusMessage "Não foi possível abrir: instalação do módulo incompleta." "Error"
        if ($ThemeRuntimeSelfTest) {
            throw "A instalação de $moduleName está incompleta no pacote: $missingText"
        }
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
        $hostTheme = (Get-CentralSelectedTheme)
        $moduleInfo = New-Module -Name $dynamicName -ArgumentList @($moduleScript, $hostTheme, $script:HostedThemeContext) -ScriptBlock {
            param($scriptPath, $hostTheme, $hostThemeContext)
            . $scriptPath -HostedInCentral -HostTheme $hostTheme -HostThemeContext $hostThemeContext
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
                $embeddedAccentLine.BackColor = if ($Module -eq "Generator") { Get-ModuleAccent "Generator" } elseif ($Module -eq "Maintenance") { Get-ModuleAccent "Maintenance" } else { Get-ModuleAccent "NFEntrada" }
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

        # O módulo só é considerado aberto depois de confirmar o mesmo contexto
        # de aparência usado pela Central. O objeto de contexto é compartilhado:
        # módulos hospedados não mantêm uma preferência concorrente.
        if (-not [bool](Sync-HostedModuleTheme)) {
            $detail = if ([string]::IsNullOrWhiteSpace($script:LastThemeSyncError)) { "falha desconhecida" } else { $script:LastThemeSyncError }
            throw "O módulo abriu, mas não confirmou a aparência da Central: $detail"
        }

        Set-StatusMessage "$moduleName integrado à Central." "Success"
    }
    catch {
        $moduleFailure = $_.Exception.Message
        try { Close-EmbeddedModule -Force } catch {}
        Show-Dashboard -SkipClose
        Set-StatusMessage "Falha ao integrar $moduleName à Central." "Error"
        if ($ThemeRuntimeSelfTest) { throw "Não foi possível integrar $moduleName à Central: $moduleFailure" }
        [Windows.Forms.MessageBox]::Show(
            "Não foi possível integrar $moduleName à Central.`r`n`r`n$moduleFailure",
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

function Start-NFEntradaModule {
    Start-EmbeddedModule "NFEntrada"
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
        "Claro corporativo" { return [Drawing.Color]::FromArgb(234, 240, 247) }
        "Alto contraste" { return [Drawing.Color]::Black }
        "Técnico industrial" { return [Drawing.Color]::FromArgb(18, 23, 25) }
        default { return [Drawing.Color]::FromArgb(9, 24, 41) }
    }
}

function Resolve-CentralThemeName {
    param([string]$Theme)
    if (@("Escuro profissional", "Técnico industrial", "Claro corporativo", "Alto contraste") -contains $Theme) {
        return $Theme
    }
    return "Escuro profissional"
}

function Set-CentralThemeAuthority {
    param([string]$Theme)

    $resolved = Resolve-CentralThemeName $Theme
    $changed = -not [string]::Equals($script:CentralTheme, $resolved, [StringComparison]::Ordinal)
    $script:CentralTheme = $resolved
    if ($null -eq $script:HostedThemeContext) {
        $script:HostedThemeContext = [pscustomobject]@{ Theme = $resolved; Revision = 0 }
    }
    if ($changed -or -not [string]::Equals([string]$script:HostedThemeContext.Theme, $resolved, [StringComparison]::Ordinal)) {
        $script:HostedThemeContext.Theme = $resolved
        $script:HostedThemeContext.Revision = [int]$script:HostedThemeContext.Revision + 1
    }
    return $resolved
}

function Get-CentralSelectedTheme {
    return (Resolve-CentralThemeName ([string]$script:CentralTheme))
}

function Set-CentralThemeComboSelection {
    param([string]$Theme)
    $resolved = Resolve-CentralThemeName $Theme
    if ($null -eq $script:CentralThemeCombo -or $script:CentralThemeCombo.IsDisposed) { return }
    if ([string]$script:CentralThemeCombo.SelectedItem -eq $resolved) { return }
    $oldChanging = $script:CentralThemeChanging
    $script:CentralThemeChanging = $true
    try { $script:CentralThemeCombo.SelectedItem = $resolved }
    finally { $script:CentralThemeChanging = $oldChanging }
}

function Get-ModuleAccent {
    param([ValidateSet("Generator", "Maintenance", "NFEntrada")][string]$Module)
    $theme = (Get-CentralSelectedTheme)
    if ($Module -eq "Generator") {
        if ($theme -eq "Claro corporativo") { return [Drawing.Color]::FromArgb(13, 142, 158) }
        if ($theme -eq "Técnico industrial") { return [Drawing.Color]::FromArgb(44, 189, 197) }
        if ($theme -eq "Alto contraste") { return [Drawing.Color]::Cyan }
        return [Drawing.Color]::FromArgb(33, 156, 211)
    }
    if ($Module -eq "NFEntrada") {
        if ($theme -eq "Claro corporativo") { return [Drawing.Color]::FromArgb(47, 112, 230) }
        if ($theme -eq "Técnico industrial") { return [Drawing.Color]::FromArgb(35, 179, 158) }
        if ($theme -eq "Alto contraste") { return [Drawing.Color]::Yellow }
        return [Drawing.Color]::FromArgb(39, 196, 125)
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
        try { $target.BackColor = Get-CardHoverColor ((Get-CentralSelectedTheme)) } catch {}
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
    if ($null -eq $Button -or $Button.IsDisposed) { return }
    $Button.FlatStyle = [Windows.Forms.FlatStyle]::Flat
    $Button.FlatAppearance.BorderSize = 0
    $Button.TextAlign = [Drawing.ContentAlignment]::MiddleLeft
    $Button.Cursor = [Windows.Forms.Cursors]::Hand
    $Button.Font = [Drawing.Font]::new("Segoe UI Semibold", 9.5)
    if ($Active) {
        $Button.BackColor = $script:CurrentPalette.AccentStrong
        $Button.ForeColor = $script:CurrentPalette.AccentText
    }
    else {
        $Button.BackColor = Get-SidebarColor (Get-CentralSelectedTheme)
        $Button.ForeColor = $script:CurrentPalette.Text
    }
}

function Update-CentralAvailabilityState {
    try {
        $health = Get-CentralHealthSnapshot
        $generatorAvailable = [bool]$health.GeneratorAvailable
        $maintenanceAvailable = [bool]$health.MaintenanceAvailable
        $nfEntradaAvailable = [bool]$health.NFEntradaAvailable
        $updaterAvailable = [bool]$health.UpdaterAvailable
        $generatorFolderAvailable = [IO.Directory]::Exists($script:GeneratorDirectory)
        $maintenanceFolderAvailable = [IO.Directory]::Exists($script:MaintenanceDirectory)
        $nfEntradaFolderAvailable = [IO.Directory]::Exists($script:NFEntradaDirectory)
        $moduleCount = ([int]$generatorAvailable + [int]$maintenanceAvailable + [int]$nfEntradaAvailable)

        if ($null -ne $script:UpdaterProcess) {
            try {
                if ($script:UpdaterProcess.HasExited) {
                    try { $script:UpdaterProcess.Dispose() } catch {}
                    $script:UpdaterProcess = $null
                }
            } catch { $script:UpdaterProcess = $null }
        }

        foreach ($pair in @(
            @($openGeneratorButton, $generatorAvailable),
            @($openMaintenanceButton, $maintenanceAvailable),
            @($openNFEntradaButton, $nfEntradaAvailable),
            @($openGeneratorFolderButton, $generatorFolderAvailable),
            @($openMaintenanceFolderButton, $maintenanceFolderAvailable),
            @($openNFEntradaFolderButton, $nfEntradaFolderAvailable)
        )) {
            $button = $pair[0]
            if ($null -ne $button) {
                $button.Enabled = ([bool]$pair[1] -and -not $script:ModuleLoading)
                $button.Cursor = if ($button.Enabled) { [Windows.Forms.Cursors]::Hand } else { [Windows.Forms.Cursors]::Default }
            }
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

        foreach ($entry in @(
            @($generatorStatus, $generatorAvailable, $generatorFolderAvailable),
            @($maintenanceStatus, $maintenanceAvailable, $maintenanceFolderAvailable),
            @($nfEntradaStatus, $nfEntradaAvailable, $nfEntradaFolderAvailable)
        )) {
            $status = $entry[0]
            if ($null -ne $status) {
                $available = [bool]$entry[1]
                $folderAvailable = [bool]$entry[2]
                $status.Text = if ($available) { "  DISPONÍVEL  " } elseif ($folderAvailable) { "  INCOMPLETO  " } else { "  INDISPONÍVEL  " }
                $status.BackColor = if ($available) { $script:CurrentPalette.SuccessBack } else { $script:CurrentPalette.PlannedBack }
                $status.ForeColor = if ($available) { $script:CurrentPalette.Success } else { $script:CurrentPalette.Planned }
            }
        }

        if ($null -ne $sidebarStatus -and $null -ne $sidebarStatusSub) {
            if ($generatorAvailable -and $maintenanceAvailable -and $nfEntradaAvailable -and $updaterAvailable) {
                $sidebarStatus.Text = "●  Sistema pronto"
                $sidebarStatusSub.Text = "3 módulos disponíveis"
                $sidebarStatus.ForeColor = $script:CurrentPalette.Success
            }
            else {
                $sidebarStatus.Text = "●  Atenção"
                if ($moduleCount -lt 3) {
                    $sidebarStatusSub.Text = "$moduleCount de 3 módulos disponíveis"
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

        $signature = "$generatorAvailable|$maintenanceAvailable|$nfEntradaAvailable|$updaterAvailable|$generatorFolderAvailable|$maintenanceFolderAvailable|$nfEntradaFolderAvailable|$(@($health.GeneratorMissing).Count)|$(@($health.MaintenanceMissing).Count)|$(@($health.NFEntradaMissing).Count)|$(@($health.UpdaterMissing).Count)|$($script:ModuleLoading)"
        if ($script:LastAvailabilitySignature -ne $signature) {
            $script:LastAvailabilitySignature = $signature
            try { $form.Invalidate($false) } catch {}
        }
    } catch {}
}

function Refresh-CentralSidebarTheme {
    if ($null -eq $script:CurrentPalette -or $null -eq $sidebar) { return }

    $theme = Get-CentralSelectedTheme
    $sidebarColor = Get-SidebarColor $theme

    $sidebar.SuspendLayout()
    try {
        $sidebar.BackColor = $sidebarColor
        $brandPanel.BackColor = $sidebarColor
        $navPanel.BackColor = $sidebarColor
        $sidebarBottom.BackColor = $sidebarColor

        $stack = New-Object System.Collections.Stack
        $stack.Push($sidebar)
        while ($stack.Count -gt 0) {
            $control = $stack.Pop()

            if ($control -is [Windows.Forms.Label]) {
                $control.ForeColor = $script:CurrentPalette.Text
            }
            elseif ($control -is [Windows.Forms.ComboBox]) {
                $control.BackColor = $script:CurrentPalette.Input
                $control.ForeColor = $script:CurrentPalette.Text
            }
            elseif ($control -is [Windows.Forms.Button]) {
                $control.ForeColor = $script:CurrentPalette.Text
            }

            foreach ($child in $control.Controls) {
                $stack.Push($child)
            }
        }

        # Exceções semânticas da barra lateral.
        $brandMark.ForeColor = [Drawing.Color]::White
        $brandSub.ForeColor = $script:CurrentPalette.Muted
        $sidebarStatusSub.ForeColor = $script:CurrentPalette.Muted
        $sidebarVersion.ForeColor = $script:CurrentPalette.Muted
        $themeCombo.BackColor = $script:CurrentPalette.Input
        $themeCombo.ForeColor = $script:CurrentPalette.Text

        # Reaplica o estado ativo/inativo da navegação com a paleta atual.
        Set-ActiveNavigation $script:ActiveNavName
    }
    finally {
        $sidebar.ResumeLayout($true)
    }

    $sidebar.Invalidate($true)
    $sidebar.Update()
    $sidebar.Refresh()
}

function Apply-CentralTheme {
    $selectedTheme = (Get-CentralSelectedTheme)
    if ([string]::IsNullOrWhiteSpace($selectedTheme) -or -not (@("Escuro profissional", "Técnico industrial", "Claro corporativo", "Alto contraste") -contains $selectedTheme)) {
        $selectedTheme = "Escuro profissional"
    }
    $script:CurrentPalette = Get-ThemePalette $selectedTheme
    $sidebarColor = Get-SidebarColor $selectedTheme
    $generatorAccent = Get-ModuleAccent "Generator"
    $maintenanceAccent = Get-ModuleAccent "Maintenance"
    $nfEntradaAccent = Get-ModuleAccent "NFEntrada"

    try { Set-CentralTitleBarTheme ($selectedTheme -ne "Claro corporativo") } catch {}
    try {
        $form.BackColor = $script:CurrentPalette.Background
        $rootLayout.BackColor = $script:CurrentPalette.Background
        $sidebar.BackColor = $sidebarColor
        $brandPanel.BackColor = $sidebarColor
        $navPanel.BackColor = $sidebarColor
        $sidebarBottom.BackColor = $sidebarColor
        $mainPanel.BackColor = $script:CurrentPalette.Background
        $mainLayout.BackColor = $script:CurrentPalette.Background
        $headerPanel.BackColor = $script:CurrentPalette.Background
        $modulesHost.BackColor = $script:CurrentPalette.Background
        $modulesLayout.BackColor = $script:CurrentPalette.Background
        $programsHeader.BackColor = $script:CurrentPalette.Background
        $modulesFlow.BackColor = $script:CurrentPalette.Background
        $footerPanel.BackColor = $script:CurrentPalette.Footer
        $footerLayout.BackColor = $script:CurrentPalette.Footer
    } catch {}
    try {
        if ($null -ne $embeddedHost) { $embeddedHost.BackColor = $script:CurrentPalette.Background }
        if ($null -ne $embeddedToolbar) { $embeddedToolbar.BackColor = $script:CurrentPalette.Surface }
        if ($null -ne $embeddedContent) { $embeddedContent.BackColor = $script:CurrentPalette.Background }
    } catch {}
    try {
        foreach ($label in @($brandTitle, $sidebarSection, $sidebarThemeLabel, $sidebarVersion)) {
            if ($null -ne $label) { $label.ForeColor = $script:CurrentPalette.Text }
        }
        foreach ($label in @($brandSub, $sidebarStatusSub)) {
            if ($null -ne $label) { $label.ForeColor = $script:CurrentPalette.Muted }
        }
        $sidebarStatus.ForeColor = $script:CurrentPalette.Success
    } catch {}
    try {
        foreach ($label in @($pageTitle, $programsTitle, $generatorTitle, $maintenanceTitle, $nfEntradaTitle, $todayLabel, $embeddedTitle)) {
            if ($null -ne $label) { $label.ForeColor = $script:CurrentPalette.Text }
        }
        foreach ($label in @($pageSubtitle, $programsSubtitle, $generatorDescription, $generatorDetail, $maintenanceDescription, $maintenanceDetail, $nfEntradaDescription, $nfEntradaDetail, $embeddedSubtitle, $embeddedLoading)) {
            if ($null -ne $label) { $label.ForeColor = $script:CurrentPalette.Muted }
        }
    } catch {}
    try {
        foreach ($panel in @($generatorCard, $maintenanceCard, $nfEntradaCard)) {
            if ($null -ne $panel) {
                $panel.BackColor = $script:CurrentPalette.Card
                $panel.BorderStyle = [Windows.Forms.BorderStyle]::FixedSingle
            }
        }
        foreach ($layout in @($generatorLayout, $maintenanceLayout, $nfEntradaLayout)) {
            if ($null -ne $layout) { $layout.BackColor = $script:CurrentPalette.Card }
        }
        $generatorAccentBar.BackColor = $generatorAccent
        $generatorIcon.BackColor = $generatorAccent
        $generatorIcon.ForeColor = [Drawing.Color]::White
        $maintenanceAccentBar.BackColor = $maintenanceAccent
        $maintenanceIcon.BackColor = $maintenanceAccent
        $maintenanceIcon.ForeColor = [Drawing.Color]::White
        $nfEntradaAccentBar.BackColor = $nfEntradaAccent
        $nfEntradaIcon.BackColor = $nfEntradaAccent
        $nfEntradaIcon.ForeColor = [Drawing.Color]::White
        $generatorStatus.BackColor = $script:CurrentPalette.SuccessBack
        $generatorStatus.ForeColor = $script:CurrentPalette.Success
        $maintenanceStatus.BackColor = $script:CurrentPalette.SuccessBack
        $maintenanceStatus.ForeColor = $script:CurrentPalette.Success
        $nfEntradaStatus.BackColor = $script:CurrentPalette.SuccessBack
        $nfEntradaStatus.ForeColor = $script:CurrentPalette.Success
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
        Set-PrimaryButtonStyle $openNFEntradaButton
        $openNFEntradaButton.BackColor = $nfEntradaAccent
        $openNFEntradaButton.ForeColor = [Drawing.Color]::White
        Set-SecondaryButtonStyle $openGeneratorFolderButton
        Set-SecondaryButtonStyle $openMaintenanceFolderButton
        Set-SecondaryButtonStyle $openNFEntradaFolderButton
        if ($null -ne $embeddedBackButton) { Set-SecondaryButtonStyle $embeddedBackButton }
        if ($null -ne $embeddedFolderButton) { Set-SecondaryButtonStyle $embeddedFolderButton }
    } catch {}
    try {
        $headerAccent.BackColor = $script:CurrentPalette.Accent
        if ($null -ne $embeddedAccentLine) {
            $embeddedAccentLine.BackColor = if ($script:EmbeddedModule -eq "Generator") { $generatorAccent } elseif ($script:EmbeddedModule -eq "Maintenance") { $maintenanceAccent } elseif ($script:EmbeddedModule -eq "NFEntrada") { $nfEntradaAccent } else { $script:CurrentPalette.Accent }
        }
    } catch {}
    try { Update-CentralAvailabilityState } catch {}
    try {
        foreach ($rounded in @($generatorCard,$maintenanceCard,$nfEntradaCard,$brandMark,$generatorIcon,$maintenanceIcon,$nfEntradaIcon,$openGeneratorButton,$openMaintenanceButton,$openNFEntradaButton,$openGeneratorFolderButton,$openMaintenanceFolderButton,$openNFEntradaFolderButton)) {
            if ($null -ne $rounded) { Set-RoundedRegion $rounded 10 }
        }
    } catch {}
    try { $form.Invalidate($true) } catch {}
    # CURA 2 — núcleo visual obrigatório da Central.
    # Este bloco não usa catch silencioso: se a casca não receber a cor escolhida,
    # o evento saberá que houve falha e não informará sucesso falso.
    $centralTheme = Get-CentralSelectedTheme
    $script:CurrentPalette = Get-ThemePalette $centralTheme
    if ($null -eq $script:CurrentPalette) { throw "A paleta da Central não foi encontrada." }
    $centralSidebarColor = Get-SidebarColor $centralTheme

    $form.BackColor = $script:CurrentPalette.Background
    $rootLayout.BackColor = $script:CurrentPalette.Background
    $sidebar.BackColor = $centralSidebarColor
    $brandPanel.BackColor = $centralSidebarColor
    $navPanel.BackColor = $centralSidebarColor
    $sidebarBottom.BackColor = $centralSidebarColor
    $mainPanel.BackColor = $script:CurrentPalette.Background
    $mainLayout.BackColor = $script:CurrentPalette.Background
    $embeddedHost.BackColor = $script:CurrentPalette.Background
    $embeddedLayout.BackColor = $script:CurrentPalette.Background
    $embeddedToolbar.BackColor = $script:CurrentPalette.Surface
    $embeddedContent.BackColor = $script:CurrentPalette.Background
    $headerPanel.BackColor = $script:CurrentPalette.Background
    $modulesHost.BackColor = $script:CurrentPalette.Background
    $modulesLayout.BackColor = $script:CurrentPalette.Background
    $programsHeader.BackColor = $script:CurrentPalette.Background
    $modulesFlow.BackColor = $script:CurrentPalette.Background
    $footerPanel.BackColor = $script:CurrentPalette.Footer
    $footerLayout.BackColor = $script:CurrentPalette.Footer

    foreach ($label in @($brandTitle,$sidebarSection,$sidebarThemeLabel,$sidebarVersion,$embeddedTitle,$pageTitle,$programsTitle,$todayLabel)) {
        if ($null -ne $label -and -not $label.IsDisposed) { $label.ForeColor = $script:CurrentPalette.Text }
    }
    foreach ($label in @($brandSub,$sidebarStatusSub,$embeddedSubtitle,$embeddedLoading,$pageSubtitle,$programsSubtitle)) {
        if ($null -ne $label -and -not $label.IsDisposed) { $label.ForeColor = $script:CurrentPalette.Muted }
    }
    $themeCombo.BackColor = $script:CurrentPalette.Input
    $themeCombo.ForeColor = $script:CurrentPalette.Text

    Set-ActiveNavigation $script:ActiveNavName
    if ($null -ne $embeddedBackButton) { Set-SecondaryButtonStyle $embeddedBackButton }
    if ($null -ne $embeddedFolderButton) { Set-SecondaryButtonStyle $embeddedFolderButton }

    # Validação real. O screenshot do usuário mostrou módulo correto + Central
    # antiga; esta checagem impede essa combinação de ser aceita como sucesso.
    if ([int]$sidebar.BackColor.ToArgb() -ne [int]$centralSidebarColor.ToArgb()) {
        throw "A barra lateral não recebeu a aparência $centralTheme."
    }
    if ([int]$embeddedToolbar.BackColor.ToArgb() -ne [int]$script:CurrentPalette.Surface.ToArgb()) {
        throw "A barra superior integrada não recebeu a aparência $centralTheme."
    }
    if ([int]$form.BackColor.ToArgb() -ne [int]$script:CurrentPalette.Background.ToArgb()) {
        throw "A janela principal não recebeu a aparência $centralTheme."
    }

    foreach ($control in @($sidebar,$brandPanel,$navPanel,$sidebarBottom,$embeddedToolbar,$embeddedHost,$mainPanel,$form)) {
        if ($null -ne $control -and -not $control.IsDisposed) {
            $control.Invalidate($true)
            $control.Update()
            $control.Refresh()
        }
    }
    # CURA 2.6 — repinta a barra lateral por último para impedir texto herdado do tema anterior.
    Refresh-CentralSidebarTheme
    Update-CentralAvailabilityState

}

function Update-ResponsiveLayout {
    if ($null -eq $modulesFlow -or $modulesFlow.ClientSize.Width -le 0) { return }
    try {
        $availableWidth = [Math]::Max(360, $modulesFlow.ClientSize.Width - $modulesFlow.Padding.Horizontal - 34)
        $availableHeight = [Math]::Max(220, $modulesFlow.ClientSize.Height - $modulesFlow.Padding.Vertical - 12)
        $twoColumns = ($availableWidth -ge 860)

        if ($twoColumns) {
            $moduleWidth = [int](($availableWidth - 22) / 2)
            $moduleHeight = [Math]::Min(230, [Math]::Max(205, [int](($availableHeight - 22) / 2)))
        }
        else {
            $moduleWidth = $availableWidth
            $moduleHeight = [Math]::Min(215, [Math]::Max(195, [int](($availableHeight - 40) / 3)))
        }

        foreach ($card in @($generatorCard, $maintenanceCard, $nfEntradaCard)) {
            if ($null -ne $card) {
                $card.Width = $moduleWidth
                $card.Height = $moduleHeight
            }
        }

        $compactCard = ($moduleWidth -lt 560)
        foreach ($titleLabel in @($generatorTitle, $maintenanceTitle, $nfEntradaTitle)) {
            if ($null -ne $titleLabel) {
                $titleLabel.Font = [Drawing.Font]::new("Segoe UI Semibold", $(if ($compactCard) { 12.5 } else { 14.5 }))
                $titleLabel.AutoEllipsis = $true
            }
        }
        foreach ($description in @($generatorDescription, $maintenanceDescription, $generatorDetail, $maintenanceDetail, $nfEntradaDescription, $nfEntradaDetail)) {
            if ($null -ne $description) { $description.AutoEllipsis = $true }
        }

        $openGeneratorButton.Text = if ($moduleWidth -lt 470) { "ABRIR" } else { "ABRIR GERENCIADOR" }
        $openMaintenanceButton.Text = if ($moduleWidth -lt 470) { "ABRIR" } else { "ABRIR MANUTENÇÃO" }
        $openNFEntradaButton.Text = if ($moduleWidth -lt 470) { "ABRIR" } else { "ABRIR CONTROLE" }

        foreach ($openButton in @($openGeneratorButton, $openMaintenanceButton, $openNFEntradaButton)) {
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
$script:CentralThemeCombo = $themeCombo
[void](Set-CentralThemeAuthority ([string]$themeCombo.SelectedItem))
$script:AppliedCentralTheme = Get-CentralSelectedTheme
$sidebarBottom.Controls.Add($themeCombo)

$sidebarStatus = New-Object Windows.Forms.Label
$sidebarStatus.Text = "●  Sistema pronto"
$sidebarStatus.Location = [Drawing.Point]::new(4, 75)
$sidebarStatus.Size = [Drawing.Size]::new(184, 24)
$sidebarStatus.Font = [Drawing.Font]::new("Segoe UI Semibold", 9)
$sidebarBottom.Controls.Add($sidebarStatus)

$sidebarStatusSub = New-Object Windows.Forms.Label
$sidebarStatusSub.Text = "3 módulos disponíveis"
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
$n = New-ModuleCard "NF" "Controle de NF de Entrada" "Controla entradas, saldos e movimentações de Computador de Bordo V5 e Teclado V5 e exporta no modelo original." "Versão integrada: $($script:NFEntradaVersion)   •   Modelo original .xlsx" "ABRIR CONTROLE"
$nfEntradaCard=$n[0]; $nfEntradaOuter=$n[1]; $nfEntradaLayout=$n[2]; $nfEntradaAccentBar=$n[3]; $nfEntradaIcon=$n[4]; $nfEntradaStatus=$n[5]; $nfEntradaTitle=$n[6]; $nfEntradaDescription=$n[7]; $nfEntradaDetail=$n[8]; $openNFEntradaButton=$n[9]; $openNFEntradaFolderButton=$n[10]
$modulesFlow.Controls.Add($generatorCard)
$modulesFlow.Controls.Add($maintenanceCard)
$modulesFlow.Controls.Add($nfEntradaCard)

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
$toolTip.SetToolTip($openNFEntradaButton, "Abrir o Controle de NF de Entrada dentro da Central")
$toolTip.SetToolTip($openNFEntradaFolderButton, "Abrir a pasta do Controle de NF de Entrada")
$toolTip.SetToolTip($embeddedBackButton, "Voltar para a tela inicial da Central de Trabalho (Alt+←)")
$toolTip.SetToolTip($embeddedFolderButton, "Abrir a pasta do módulo que está em uso")

foreach ($roundedPanel in @($generatorCard,$maintenanceCard,$nfEntradaCard)) {
    Enable-RoundedControl $roundedPanel 12
    Enable-CardHover $roundedPanel
}
foreach ($roundedSmall in @($brandMark,$generatorIcon,$maintenanceIcon,$nfEntradaIcon,$openGeneratorButton,$openMaintenanceButton,$openNFEntradaButton,$openGeneratorFolderButton,$openMaintenanceFolderButton,$openNFEntradaFolderButton)) {
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
$openNFEntradaButton.TabIndex = 14
$openNFEntradaFolderButton.TabIndex = 15
$embeddedBackButton.TabIndex = 0
$embeddedFolderButton.TabIndex = 1

function Invoke-CentralThemeRuntimeSelfTestLegacy {
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

function Wait-CentralThemeRuntimeUi {
    param([int]$Milliseconds = 350)
    $watch = [Diagnostics.Stopwatch]::StartNew()
    while ($watch.ElapsedMilliseconds -lt $Milliseconds) {
        [Windows.Forms.Application]::DoEvents()
        Start-Sleep -Milliseconds 25
    }
    [Windows.Forms.Application]::DoEvents()
}

function Get-CentralThemeRuntimeAudit {
    if ($null -eq $script:HostedModule -or [string]::IsNullOrWhiteSpace($script:EmbeddedModule)) {
        throw "Não há módulo hospedado para auditar."
    }
    $auditItems = @(& $script:HostedModule {
        param($targetModule)
        switch ($targetModule) {
            "Generator" { Get-HostedGeneratorThemeAudit }
            "Maintenance" { Get-HostedMaintenanceThemeAudit }
            "NFEntrada" { Get-HostedNFEntradaThemeAudit }
            default { throw "Módulo desconhecido no teste: $targetModule" }
        }
    } ([string]$script:EmbeddedModule))
    if ($auditItems.Count -eq 0) { throw "$($script:EmbeddedModule) não retornou auditoria visual." }
    return $auditItems[$auditItems.Count - 1]
}

function Assert-CentralThemeRuntimeState {
    param(
        [string]$ExpectedTheme,
        [string]$Scenario
    )

    $expected = Resolve-CentralThemeName $ExpectedTheme
    if ((Get-CentralSelectedTheme) -ne $expected -or [string]$script:AppliedCentralTheme -ne $expected) {
        throw "${Scenario}: a autoridade da Central não permaneceu em '$expected'."
    }
    if ([string]$themeCombo.SelectedItem -ne $expected) {
        throw "${Scenario}: o seletor visual da Central não permaneceu em '$expected'."
    }
    if ([string]$script:HostedThemeContext.Theme -ne $expected) {
        throw "${Scenario}: o contexto compartilhado não permaneceu em '$expected'."
    }

    $centralPalette = Get-ThemePalette $expected
    if ([int]$form.BackColor.ToArgb() -ne [int]$centralPalette.Background.ToArgb()) {
        throw "${Scenario}: o fundo da Central não recebeu '$expected'."
    }
    $sidebarColor = Get-SidebarColor $expected
    if ([int]$sidebar.BackColor.ToArgb() -ne [int]$sidebarColor.ToArgb()) {
        throw "${Scenario}: a barra lateral da Central não recebeu '$expected'."
    }

    $audit = Get-CentralThemeRuntimeAudit
    if (-not [bool]$audit.Valid) {
        $invalid = @($audit.InvalidChecks | ForEach-Object { [string]$_.Name }) -join ", "
        throw "${Scenario}: $($script:EmbeddedModule) terminou com controles fora da paleta: $invalid"
    }
    if ([string]$audit.AuthorityTheme -ne $expected) {
        throw "${Scenario}: $($script:EmbeddedModule) reconheceu '$($audit.AuthorityTheme)' em vez de '$expected'."
    }
    if ([int]$audit.Revision -ne [int]$script:HostedThemeContext.Revision) {
        throw "${Scenario}: $($script:EmbeddedModule) não confirmou a revisão compartilhada $($script:HostedThemeContext.Revision)."
    }
    return $audit
}

function Set-CentralThemeForRuntimeTest {
    param(
        [string]$Theme,
        [string]$Scenario,
        [int]$LateWaitMilliseconds = 700
    )

    $resolved = Resolve-CentralThemeName $Theme
    if ([string]$themeCombo.SelectedItem -ne $resolved) {
        # A alteração programática dispara o mesmo SelectedIndexChanged usado pelo
        # ComboBox real; o processamento continua via BeginInvoke no host nativo.
        $themeCombo.SelectedItem = $resolved
    }
    elseif ([string]$script:AppliedCentralTheme -ne $resolved) {
        Request-CentralThemeChange $resolved
    }

    $watch = [Diagnostics.Stopwatch]::StartNew()
    while ($watch.ElapsedMilliseconds -lt 5000) {
        [Windows.Forms.Application]::DoEvents()
        if ([string]$script:AppliedCentralTheme -eq $resolved -and
            [string]$script:HostedThemeContext.Theme -eq $resolved -and
            [string]::IsNullOrWhiteSpace($script:PendingCentralTheme) -and
            -not $script:CentralThemeChanging -and
            -not $script:CentralThemeDispatchScheduled) {
            break
        }
        Start-Sleep -Milliseconds 25
    }
    if ([string]$script:AppliedCentralTheme -ne $resolved) {
        $detail = if ([string]::IsNullOrWhiteSpace($script:LastThemeSyncError)) { "sem diagnóstico adicional" } else { $script:LastThemeSyncError }
        throw "${Scenario}: a transação de '$resolved' não concluiu em cinco segundos. $detail"
    }

    Wait-CentralThemeRuntimeUi $LateWaitMilliseconds
    return (Assert-CentralThemeRuntimeState $resolved $Scenario)
}

function Invoke-CentralThemeRuntimeLateEvents {
    param([string]$ModuleName)

    # Exercita exatamente as famílias de eventos que historicamente podiam
    # reconstruir controles ou reaplicar a preferência autônoma do módulo.
    $originalSize = $form.Size
    $form.Size = [Drawing.Size]::new([Math]::Max(1180, $originalSize.Width - 37), [Math]::Max(720, $originalSize.Height - 23))
    $form.PerformLayout()
    if ($null -ne $script:HostedForm -and -not $script:HostedForm.IsDisposed) {
        $script:HostedForm.Bounds = $embeddedContent.ClientRectangle
        $script:HostedForm.PerformLayout()
        $script:HostedForm.Refresh()
    }

    & $script:HostedModule {
        param($targetModule)
        switch ($targetModule) {
            "Generator" {
                Update-ProductInterface
                Update-GeneratorResponsiveLayout
                Update-RootLayout
            }
            "Maintenance" {
                Refresh-AllViews
                Update-MaintenanceResponsiveLayout
            }
            "NFEntrada" {
                Refresh-NFAll
                Update-NFActions
            }
        }
    } $ModuleName

    $form.Size = $originalSize
    $form.PerformLayout()
    Wait-CentralThemeRuntimeUi 275
}

function Get-CentralThemeRuntimeFileSnapshot {
    param([string]$Directory)

    $snapshot = [ordered]@{}
    if ([string]::IsNullOrWhiteSpace($Directory) -or -not [IO.Directory]::Exists($Directory)) { return $snapshot }
    $root = [IO.Path]::GetFullPath($Directory).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
    foreach ($path in [IO.Directory]::GetFiles($root, "*", [IO.SearchOption]::AllDirectories)) {
        if ([string]::Equals([IO.Path]::GetFileName($path), "preferencias.json", [StringComparison]::OrdinalIgnoreCase)) { continue }
        $relative = $path.Substring($root.Length).TrimStart([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
        $snapshot[$relative] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
    }
    return $snapshot
}

function Assert-CentralThemeRuntimeFileSnapshot {
    param(
        [Collections.IDictionary]$Before,
        [Collections.IDictionary]$After,
        [string]$Scenario
    )
    if ($Before.Count -ne $After.Count) {
        throw "${Scenario}: a troca de aparência alterou a quantidade de arquivos operacionais ($($Before.Count) -> $($After.Count))."
    }
    foreach ($key in $Before.Keys) {
        if (-not $After.Contains($key) -or [string]$After[$key] -ne [string]$Before[$key]) {
            throw "${Scenario}: a troca de aparência modificou o arquivo operacional '$key'."
        }
    }
}

function Save-CentralThemeRuntimeScreenshot {
    param([string]$Name)
    if ([string]::IsNullOrWhiteSpace($ThemeRuntimeArtifactsPath)) { return "" }

    if (-not [IO.Directory]::Exists($ThemeRuntimeArtifactsPath)) {
        [void][IO.Directory]::CreateDirectory($ThemeRuntimeArtifactsPath)
    }
    $safeName = $Name -replace '[^A-Za-z0-9._-]', '-'
    $path = [IO.Path]::Combine($ThemeRuntimeArtifactsPath, ($safeName + ".png"))
    $bitmap = New-Object Drawing.Bitmap([Math]::Max(1, $form.ClientSize.Width), [Math]::Max(1, $form.ClientSize.Height))
    try {
        $form.DrawToBitmap($bitmap, [Drawing.Rectangle]::new(0, 0, $bitmap.Width, $bitmap.Height))
        $bitmap.Save($path, [Drawing.Imaging.ImageFormat]::Png)
    }
    finally { $bitmap.Dispose() }
    if (-not [IO.File]::Exists($path) -or ([IO.FileInfo]$path).Length -le 0) {
        throw "A captura visual '$Name' não foi gerada."
    }
    return $path
}

function Get-CentralThemeRuntimePreference {
    param([string]$Path)
    try {
        if ([IO.File]::Exists($Path)) {
            return [string]((Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json).Theme)
        }
    } catch {}
    return ""
}

function Invoke-CentralThemeRuntimeSelfTest {
    $normalSequence = @("Escuro profissional", "Claro corporativo", "Técnico industrial", "Alto contraste", "Claro corporativo")
    $rapidSequence = @("Alto contraste", "Escuro profissional", "Técnico industrial", "Claro corporativo", "Escuro profissional", "Alto contraste", "Claro corporativo")
    $startupTheme = Get-CentralSelectedTheme
    $startedAt = [DateTime]::UtcNow
    $caseResults = New-Object 'Collections.Generic.List[object]'
    $screenshots = New-Object 'Collections.Generic.List[string]'
    $dataChecks = New-Object 'Collections.Generic.List[object]'
    $success = $false
    $failure = ""

    if ([string]::IsNullOrWhiteSpace($ThemeRuntimeReportPath)) {
        $ThemeRuntimeReportPath = [IO.Path]::Combine($script:RootPath, "theme-runtime-report.json")
    }

    $testDataRoot = [IO.Path]::GetFullPath($env:CENTRAL_THEME_TEST_DATA_ROOT)
    $generatorSettingsPath = [IO.Path]::Combine($testDataRoot, "GeradorPlanilhasCB5TV5", "preferencias.json")
    $maintenanceSettingsPath = [IO.Path]::Combine($testDataRoot, "CentralDeTrabalho", "ManutencaoCB5", "preferencias.json")
    $generatorPreferenceBefore = Get-CentralThemeRuntimePreference $generatorSettingsPath
    $maintenancePreferenceBefore = Get-CentralThemeRuntimePreference $maintenanceSettingsPath

    $form.StartPosition = [Windows.Forms.FormStartPosition]::Manual
    $form.Location = [Drawing.Point]::new(24, 24)
    $form.Size = [Drawing.Size]::new(1440, 900)
    $form.ShowInTaskbar = $false
    $form.Show()
    Wait-CentralThemeRuntimeUi 450

    try {
        foreach ($product in @("TV5", "CB5")) {
            Start-EmbeddedModule "Generator"
            if ($script:EmbeddedModule -ne "Generator") { throw "O Gerenciador não abriu no host nativo." }
            $openAudit = Assert-CentralThemeRuntimeState (Get-CentralSelectedTheme) "Gerenciador/$product/abertura-hospedada"
            $caseResults.Add([pscustomobject]@{
                Module = "Generator"; Product = $product; Theme = (Get-CentralSelectedTheme); Scenario = "hosted-open";
                Revision = [int]$openAudit.Revision; Checks = @($openAudit.Checks); Valid = [bool]$openAudit.Valid
            })
            & $script:HostedModule {
                param($targetProduct)
                $productCombo.SelectedItem = $targetProduct
                Update-ProductInterface
            } $product
            Wait-CentralThemeRuntimeUi 300

            $generatorDataDirectory = & $script:HostedModule { return [string]$script:SettingsDirectory }
            $dataBefore = Get-CentralThemeRuntimeFileSnapshot $generatorDataDirectory
            foreach ($themeName in $normalSequence) {
                $scenario = "Gerenciador/$product/$themeName"
                $audit = Set-CentralThemeForRuntimeTest $themeName $scenario
                Invoke-CentralThemeRuntimeLateEvents "Generator"
                $audit = Assert-CentralThemeRuntimeState $themeName ($scenario + "/eventos-tardios")
                $shot = Save-CentralThemeRuntimeScreenshot ("Generator-{0}-{1}" -f $product, (@{
                    "Escuro profissional" = "dark"; "Claro corporativo" = "light"; "Técnico industrial" = "industrial"; "Alto contraste" = "contrast"
                }[$themeName]))
                if (-not [string]::IsNullOrWhiteSpace($shot)) { $screenshots.Add($shot) }
                $caseResults.Add([pscustomobject]@{
                    Module = "Generator"; Product = $product; Theme = $themeName; Scenario = "normal";
                    Revision = [int]$audit.Revision; Checks = @($audit.Checks); Valid = [bool]$audit.Valid
                })
            }

            foreach ($themeName in $rapidSequence) {
                $themeCombo.SelectedItem = $themeName
                [Windows.Forms.Application]::DoEvents()
                Start-Sleep -Milliseconds 35
            }
            Wait-CentralThemeRuntimeUi 3400
            $rapidAudit = Assert-CentralThemeRuntimeState "Claro corporativo" "Gerenciador/$product/alternância-rápida"
            $caseResults.Add([pscustomobject]@{
                Module = "Generator"; Product = $product; Theme = "Claro corporativo"; Scenario = "rapid-and-late";
                Revision = [int]$rapidAudit.Revision; Checks = @($rapidAudit.Checks); Valid = [bool]$rapidAudit.Valid
            })

            $dataAfter = Get-CentralThemeRuntimeFileSnapshot $generatorDataDirectory
            Assert-CentralThemeRuntimeFileSnapshot $dataBefore $dataAfter "Gerenciador/$product"
            $dataChecks.Add([pscustomobject]@{ Module = "Generator"; Product = $product; Unchanged = $true; Files = $dataAfter.Count })
            Close-EmbeddedModule -Force
            Wait-CentralThemeRuntimeUi 250
        }

        # Mudar primeiro e abrir depois garante que o Gerenciador já nasça no
        # tema atual, sem restaurar a preferência autônoma salva anteriormente.
        $themeCombo.SelectedItem = "Técnico industrial"
        Wait-CentralThemeRuntimeUi 600
        Start-EmbeddedModule "Generator"
        $bornAudit = Assert-CentralThemeRuntimeState "Técnico industrial" "Gerenciador/abertura-após-troca"
        $caseResults.Add([pscustomobject]@{ Module = "Generator"; Product = [string]$bornAudit.Product; Theme = "Técnico industrial"; Scenario = "born-current"; Revision = [int]$bornAudit.Revision; Checks = @($bornAudit.Checks); Valid = [bool]$bornAudit.Valid })
        Close-EmbeddedModule -Force

        foreach ($moduleName in @("Maintenance", "NFEntrada")) {
            Start-EmbeddedModule $moduleName
            if ($script:EmbeddedModule -ne $moduleName) { throw "$moduleName não abriu no host nativo." }
            $openAudit = Assert-CentralThemeRuntimeState (Get-CentralSelectedTheme) "$moduleName/abertura-hospedada"
            $caseResults.Add([pscustomobject]@{
                Module = $moduleName; Product = ""; Theme = (Get-CentralSelectedTheme); Scenario = "hosted-open";
                Revision = [int]$openAudit.Revision; Checks = @($openAudit.Checks); Valid = [bool]$openAudit.Valid
            })
            Wait-CentralThemeRuntimeUi 300
            $moduleDataDirectory = & $script:HostedModule { return [string]$script:DataDirectory }
            $dataBefore = Get-CentralThemeRuntimeFileSnapshot $moduleDataDirectory

            foreach ($themeName in $normalSequence) {
                $scenario = "$moduleName/$themeName"
                $audit = Set-CentralThemeForRuntimeTest $themeName $scenario
                Invoke-CentralThemeRuntimeLateEvents $moduleName
                $audit = Assert-CentralThemeRuntimeState $themeName ($scenario + "/eventos-tardios")
                $shot = Save-CentralThemeRuntimeScreenshot ("{0}-{1}" -f $moduleName, (@{
                    "Escuro profissional" = "dark"; "Claro corporativo" = "light"; "Técnico industrial" = "industrial"; "Alto contraste" = "contrast"
                }[$themeName]))
                if (-not [string]::IsNullOrWhiteSpace($shot)) { $screenshots.Add($shot) }
                $caseResults.Add([pscustomobject]@{
                    Module = $moduleName; Product = ""; Theme = $themeName; Scenario = "normal";
                    Revision = [int]$audit.Revision; Checks = @($audit.Checks); Valid = [bool]$audit.Valid
                })
            }

            foreach ($themeName in $rapidSequence) {
                $themeCombo.SelectedItem = $themeName
                [Windows.Forms.Application]::DoEvents()
                Start-Sleep -Milliseconds 35
            }
            Wait-CentralThemeRuntimeUi 3400
            $rapidAudit = Assert-CentralThemeRuntimeState "Claro corporativo" "$moduleName/alternância-rápida"
            $caseResults.Add([pscustomobject]@{
                Module = $moduleName; Product = ""; Theme = "Claro corporativo"; Scenario = "rapid-and-late";
                Revision = [int]$rapidAudit.Revision; Checks = @($rapidAudit.Checks); Valid = [bool]$rapidAudit.Valid
            })

            $dataAfter = Get-CentralThemeRuntimeFileSnapshot $moduleDataDirectory
            Assert-CentralThemeRuntimeFileSnapshot $dataBefore $dataAfter $moduleName
            $dataChecks.Add([pscustomobject]@{ Module = $moduleName; Product = ""; Unchanged = $true; Files = $dataAfter.Count })
            Close-EmbeddedModule -Force
            Wait-CentralThemeRuntimeUi 250

            $themeCombo.SelectedItem = "Alto contraste"
            Wait-CentralThemeRuntimeUi 600
            Start-EmbeddedModule $moduleName
            $bornAudit = Assert-CentralThemeRuntimeState "Alto contraste" "$moduleName/abertura-após-troca"
            $caseResults.Add([pscustomobject]@{ Module = $moduleName; Product = ""; Theme = "Alto contraste"; Scenario = "born-current"; Revision = [int]$bornAudit.Revision; Checks = @($bornAudit.Checks); Valid = [bool]$bornAudit.Valid })
            Close-EmbeddedModule -Force
        }

        # Estado final deliberado: o segundo processo do workflow deve iniciar em
        # Claro corporativo e repetir todos os testes, cobrindo reinício completo.
        $themeCombo.SelectedItem = "Claro corporativo"
        Wait-CentralThemeRuntimeUi 750
        if ([string]$script:AppliedCentralTheme -ne "Claro corporativo") { throw "A Central não persistiu o tema final do teste." }
        Save-AppSettings

        $generatorPreferenceAfter = Get-CentralThemeRuntimePreference $generatorSettingsPath
        $maintenancePreferenceAfter = Get-CentralThemeRuntimePreference $maintenanceSettingsPath
        if (-not [string]::IsNullOrWhiteSpace($generatorPreferenceBefore) -and $generatorPreferenceAfter -ne $generatorPreferenceBefore) {
            throw "O modo hospedado sobrescreveu a preferência standalone do Gerenciador."
        }
        if (-not [string]::IsNullOrWhiteSpace($maintenancePreferenceBefore) -and $maintenancePreferenceAfter -ne $maintenancePreferenceBefore) {
            throw "O modo hospedado sobrescreveu a preferência standalone da Manutenção."
        }
        if ([int]$script:ThemeTransactionFailureCount -ne 0) {
            throw "Ocorreram $($script:ThemeTransactionFailureCount) falhas intermediárias de sincronização durante o teste."
        }

        $success = $true
        Write-Host "CENTRAL THEME RUNTIME PACKAGE: OK — host nativo, 3 módulos, TV5/CB5, 4 temas, alternância rápida, reabertura e integridade de dados."
    }
    catch {
        $failure = $_.Exception.ToString()
        throw
    }
    finally {
        try { Close-EmbeddedModule -Force } catch {}
        try { $form.Hide() } catch {}
        try { $form.Close() } catch {}

        $reportDirectory = [IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($ThemeRuntimeReportPath))
        if (-not [IO.Directory]::Exists($reportDirectory)) { [void][IO.Directory]::CreateDirectory($reportDirectory) }
        $report = [ordered]@{
            Success = $success
            Failure = $failure
            StartedUtc = $startedAt.ToString("o")
            FinishedUtc = [DateTime]::UtcNow.ToString("o")
            StartupTheme = $startupTheme
            FinalTheme = Get-CentralSelectedTheme
            CentralVersion = $script:AppVersion
            GeneratorVersion = $script:GeneratorVersion
            MaintenanceVersion = $script:MaintenanceVersion
            NFEntradaVersion = $script:NFEntradaVersion
            SharedRevision = [int]$script:HostedThemeContext.Revision
            ThemeTransactionFailures = [int]$script:ThemeTransactionFailureCount
            NativeHostProcess = [IO.Path]::GetFileName([Diagnostics.Process]::GetCurrentProcess().MainModule.FileName)
            Cases = @($caseResults)
            DataIntegrity = @($dataChecks)
            StandalonePreferences = [ordered]@{
                GeneratorBefore = $generatorPreferenceBefore
                GeneratorAfter = (Get-CentralThemeRuntimePreference $generatorSettingsPath)
                MaintenanceBefore = $maintenancePreferenceBefore
                MaintenanceAfter = (Get-CentralThemeRuntimePreference $maintenanceSettingsPath)
            }
            Screenshots = @($screenshots)
        }
        $json = $report | ConvertTo-Json -Depth 12
        [IO.File]::WriteAllText([IO.Path]::GetFullPath($ThemeRuntimeReportPath), $json, [Text.UTF8Encoding]::new($false))
    }
}

# A escolha do ComboBox apenas agenda uma transação curta para o próximo ciclo
# da interface. Isso evita executar Apply/Refresh/DoEvents enquanto o controle
# ainda está finalizando SelectedIndexChanged, que era uma fonte de reentrada no
# executável real. Mudanças rápidas são consolidadas no último tema escolhido.
function Invoke-PendingCentralThemeChange {
    if ($script:CentralThemeChanging) { return }
    $script:CentralThemeDispatchScheduled = $false

    $targetTheme = Resolve-CentralThemeName $script:PendingCentralTheme
    $previousTheme = Resolve-CentralThemeName $script:AppliedCentralTheme
    $script:PendingCentralTheme = ""
    if ($targetTheme -eq $previousTheme) {
        Set-CentralThemeComboSelection $previousTheme
        return
    }

    $script:CentralThemeChanging = $true
    try {
        [void](Set-CentralThemeAuthority $targetTheme)
        Apply-CentralTheme
        if (-not [bool](Sync-HostedModuleTheme)) {
            $detail = if ([string]::IsNullOrWhiteSpace($script:LastThemeSyncError)) { "falha desconhecida" } else { $script:LastThemeSyncError }
            throw "O módulo aberto não atualizou: $detail"
        }

        $script:AppliedCentralTheme = $targetTheme
        Save-AppSettings
        Set-StatusMessage ("Aparência aplicada: " + $targetTheme + ".") "Success"
    }
    catch {
        $failure = $_.Exception.Message
        $script:ThemeTransactionFailureCount = [int]$script:ThemeTransactionFailureCount + 1

        # Uma falha não pode deixar Central e módulo em temas distintos. A troca
        # é transacional: ambos retornam ao último tema confirmado.
        try {
            [void](Set-CentralThemeAuthority $previousTheme)
            Set-CentralThemeComboSelection $previousTheme
            Apply-CentralTheme
            [void](Sync-HostedModuleTheme)
            $script:AppliedCentralTheme = $previousTheme
        } catch {}

        Set-StatusMessage ("Falha na aparência; tema anterior restaurado: " + $failure) "Error"
        try {
            $diagPath = [IO.Path]::Combine($script:SettingsDirectory, "tema-diagnostico.log")
            if (-not [IO.Directory]::Exists($script:SettingsDirectory)) { [void][IO.Directory]::CreateDirectory($script:SettingsDirectory) }
            $line = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss") + " | " + $targetTheme + " | " + $failure
            [IO.File]::AppendAllText($diagPath, $line + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
        } catch {}
    }
    finally {
        $script:CentralThemeChanging = $false
    }

    # Se outra escolha chegou enquanto a transação estava ocupada, processa a
    # mais recente sem permitir estados intermediários concorrentes.
    if (-not [string]::IsNullOrWhiteSpace($script:PendingCentralTheme)) {
        Request-CentralThemeChange $script:PendingCentralTheme
    }
}

function Request-CentralThemeChange {
    param([string]$Theme)
    $script:PendingCentralTheme = Resolve-CentralThemeName $Theme
    if ($script:CentralThemeDispatchScheduled -or $script:CentralThemeChanging) { return }
    $script:CentralThemeDispatchScheduled = $true

    $processor = ${function:Invoke-PendingCentralThemeChange}
    $dispatch = [Action]{ & $processor }.GetNewClosure()
    try { [void]$form.BeginInvoke($dispatch) }
    catch {
        $script:CentralThemeDispatchScheduled = $false
        & $processor
    }
}

# Eventos
$themeSelectionChanged = {
    if ($script:CentralThemeChanging) { return }
    Request-CentralThemeChange ([string]$themeCombo.SelectedItem)
}
$themeCombo.Add_SelectedIndexChanged($themeSelectionChanged)
$themeCombo.Add_SelectionChangeCommitted($themeSelectionChanged)
$openGeneratorButton.Add_Click({ Start-GeneratorModule })
$openMaintenanceButton.Add_Click({ Start-MaintenanceModule })
$openNFEntradaButton.Add_Click({ Start-NFEntradaModule })
$openGeneratorFolderButton.Add_Click({ Open-ModuleFolder $script:GeneratorDirectory "Gerenciador de Planilhas" })
$openMaintenanceFolderButton.Add_Click({ Open-ModuleFolder $script:MaintenanceDirectory "Central de Manutenção CB5" })
$openNFEntradaFolderButton.Add_Click({ Open-ModuleFolder $script:NFEntradaDirectory "Controle de NF de Entrada" })
$navUpdates.Add_Click({ Start-UpdaterModule; Set-ActiveNavigation "Home" })
$navFolder.Add_Click({ Open-RootFolder; Set-ActiveNavigation "Home" })
$navHome.Add_Click({ Show-Dashboard })
$navAbout.Add_Click({
    Set-ActiveNavigation "About"
    [Windows.Forms.MessageBox]::Show(
        "Central de Trabalho v$($script:AppVersion)`r`n`r`nIntegra o Gerenciador de Planilhas, a Central de Manutenção CB5, o Controle de NF de Entrada e o sistema de atualização.`r`n`r`nInterface integrada e responsiva para os módulos de trabalho, manutenção e atualização.",
        "Sobre a Central de Trabalho",
        [Windows.Forms.MessageBoxButtons]::OK,
        [Windows.Forms.MessageBoxIcon]::Information
    ) | Out-Null
    Set-ActiveNavigation "Home"
})
$modulesFlow.Add_SizeChanged({ Update-CentralChromeLayout })
$form.Add_Shown({ Update-CentralAdaptiveLayout; Update-ResponsiveLayout; Apply-CentralTheme; Update-CentralAvailabilityState })
$form.Add_SizeChanged({
    try { Update-CentralAdaptiveLayout } catch {}
})
$embeddedBackButton.Add_Click({ Show-Dashboard })
$embeddedFolderButton.Add_Click({
    if ($script:EmbeddedModule -eq "Generator") { Open-ModuleFolder $script:GeneratorDirectory "Gerenciador de Planilhas" }
    elseif ($script:EmbeddedModule -eq "Maintenance") { Open-ModuleFolder $script:MaintenanceDirectory "Central de Manutenção CB5" }
    elseif ($script:EmbeddedModule -eq "NFEntrada") { Open-ModuleFolder $script:NFEntradaDirectory "Controle de NF de Entrada" }
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

    Apply-CentralTheme
    if ($ThemeRuntimeSelfTest) {
        Invoke-CentralThemeRuntimeSelfTest
        return
    }
    [void]$form.ShowDialog()
}
catch {
    $details = "Falha ao iniciar a Central de Trabalho.`r`n`r`n" + $_.Exception.Message + "`r`n`r`nLinha: " + $_.InvocationInfo.ScriptLineNumber
    try {
        $logPath = [IO.Path]::Combine($script:RootPath, "ERRO-INICIALIZACAO.txt")
        [IO.File]::WriteAllText($logPath, $details, [Text.UTF8Encoding]::new($true))
    }
    catch {}
    if ($ThemeRuntimeSelfTest) { throw }
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
