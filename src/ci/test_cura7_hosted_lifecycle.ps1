param(
    [Parameter(Mandatory = $true)][string]$InstallRoot
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$InstallRoot = [IO.Path]::GetFullPath($InstallRoot)
if (-not [IO.Directory]::Exists($InstallRoot)) { throw "Raiz do pacote não encontrada: $InstallRoot" }

$theme = 'Técnico industrial'
$script:CycleDataRoot = Join-Path $env:RUNNER_TEMP 'central-cura7-lifecycle-data'
if (Test-Path -LiteralPath $script:CycleDataRoot) { Remove-Item -LiteralPath $script:CycleDataRoot -Recurse -Force }
New-Item -ItemType Directory -Force -Path $script:CycleDataRoot | Out-Null
$env:CENTRAL_THEME_RUNTIME_TEST = '1'
$env:CENTRAL_THEME_TEST_DATA_ROOT = $script:CycleDataRoot

$cases = @(
    [pscustomobject]@{
        Name = 'Gerenciador de Planilhas'
        Kind = 'Generator'
        Path = Join-Path $InstallRoot 'Modulos\Gerador-de-Planilhas-CB5-TV5\Gerador Planilhas.ps1'
    },
    [pscustomobject]@{
        Name = 'Central de Manutenção'
        Kind = 'Maintenance'
        Path = Join-Path $InstallRoot 'Modulos\Central-de-Manutencao-CB5\Central Manutencao CB5.ps1'
    },
    [pscustomobject]@{
        Name = 'Controle de NF de Entrada'
        Kind = 'NFEntrada'
        Path = Join-Path $InstallRoot 'Modulos\Controle-NF-Entrada\Controle NF Entrada.ps1'
    }
)

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Invoke-HostedThemeRefresh {
    param($ModuleInfo, [string]$Kind, $Context)
    $Context.Theme = $theme
    $Context.Revision = [int]$Context.Revision + 1
    $items = @(& $ModuleInfo {
        param($kind, $hostTheme)
        switch ($kind) {
            'Generator'   { return @(Set-HostedGeneratorTheme $hostTheme)[-1] }
            'Maintenance' { return @(Set-HostedMaintenanceTheme $hostTheme)[-1] }
            'NFEntrada'   { return @(Set-HostedNFEntradaTheme $hostTheme)[-1] }
        }
    } $Kind $theme)
    if ($items.Count -eq 0 -or -not [bool]$items[-1]) {
        throw "$Kind recusou a reaplicação da aparência oficial."
    }
}

function Test-GeneratorRuntime {
    param($ModuleInfo)
    $result = & $ModuleInfo {
        $tabsVar = Get-Variable -Name tabs -Scope Script -ErrorAction SilentlyContinue
        $productVar = Get-Variable -Name productCombo -Scope Script -ErrorAction SilentlyContinue
        if ($null -eq $tabsVar -or $null -eq $productVar) { throw 'Controles principais do Gerenciador ausentes.' }
        $tabsLocal = $tabsVar.Value
        $productLocal = $productVar.Value

        $productLocal.SelectedItem = 'CB5'
        Update-ProductInterface
        Apply-AppTheme
        [Windows.Forms.Application]::DoEvents()
        $cb5 = [int]$script:CurrentPalette.Accent.ToArgb()

        $productLocal.SelectedItem = 'TV5'
        Update-ProductInterface
        Apply-AppTheme
        [Windows.Forms.Application]::DoEvents()
        $tv5 = [int]$script:CurrentPalette.Accent.ToArgb()

        $productLocal.SelectedItem = 'CB5'
        Update-ProductInterface
        Apply-AppTheme
        [Windows.Forms.Application]::DoEvents()

        [pscustomobject]@{
            Pages = [int]$tabsLocal.TabPages.Count
            HeaderHeight = [int]$tabsLocal.ItemSize.Height
            Cb5Accent = $cb5
            Tv5Accent = $tv5
            ExpectedCb5 = [int]([Drawing.Color]::FromArgb(44,189,197).ToArgb())
            ExpectedTv5 = [int]([Drawing.Color]::FromArgb(72,202,143).ToArgb())
        }
    }
    Assert-True ($result.Pages -eq 5) "Gerenciador: esperado 5 itens de navegação, obtido $($result.Pages)."
    Assert-True ($result.HeaderHeight -ge 34) "Gerenciador: cabeçalho de navegação ficou baixo demais ($($result.HeaderHeight) px)."
    Assert-True ($result.Cb5Accent -eq $result.ExpectedCb5) 'Gerenciador: CB5 não terminou com o ciano oficial.'
    Assert-True ($result.Tv5Accent -eq $result.ExpectedTv5) 'Gerenciador: TV5 não terminou com o verde técnico oficial.'
    Assert-True ($result.Cb5Accent -ne $result.Tv5Accent) 'Gerenciador: CB5 e TV5 terminaram com a mesma cor de produto.'
}

function Test-MaintenanceRuntime {
    param($ModuleInfo)
    $result = & $ModuleInfo {
        $tabsVar = Get-Variable -Name mainTabs -Scope Script -ErrorAction SilentlyContinue
        $newVar = Get-Variable -Name dashboardNewButton -Scope Script -ErrorAction SilentlyContinue
        $historyVar = Get-Variable -Name dashboardHistoryButton -Scope Script -ErrorAction SilentlyContinue
        if ($null -eq $tabsVar -or $null -eq $newVar -or $null -eq $historyVar) { throw 'Navegação principal da Manutenção ausente.' }
        [pscustomobject]@{
            Pages = [int]$tabsVar.Value.TabPages.Count
            NewRole = [string]$newVar.Value.Tag
            NewHeight = [int]$newVar.Value.Height
            HistoryHeight = [int]$historyVar.Value.Height
        }
    }
    Assert-True ($result.Pages -ge 6) "Manutenção: quantidade inesperada de páginas ($($result.Pages))."
    Assert-True ($result.NewRole -eq 'Action') "Manutenção: + NOVA PASSAGEM perdeu o papel visual Action."
    Assert-True ($result.NewHeight -ge 30 -and $result.HistoryHeight -ge 30) 'Manutenção: botões de navegação ficaram baixos demais.'
}

function Test-NFEntradaRuntime {
    param($ModuleInfo)
    $result = & $ModuleInfo {
        $tabsVar = Get-Variable -Name mainTabs -Scope Script -ErrorAction SilentlyContinue
        $newVar = Get-Variable -Name newButton -Scope Script -ErrorAction SilentlyContinue
        $importVar = Get-Variable -Name importButton -Scope Script -ErrorAction SilentlyContinue
        $computerGridVar = Get-Variable -Name computerGrid -Scope Script -ErrorAction SilentlyContinue
        $keyboardGridVar = Get-Variable -Name keyboardGrid -Scope Script -ErrorAction SilentlyContinue
        if ($null -eq $tabsVar -or $null -eq $newVar -or $null -eq $importVar -or $null -eq $computerGridVar -or $null -eq $keyboardGridVar) {
            throw 'Controles principais do Controle de NF ausentes.'
        }
        $tabsLocal = $tabsVar.Value
        $tabTexts = @($tabsLocal.TabPages | ForEach-Object { [string]$_.Text })
        foreach ($page in @($tabsLocal.TabPages)) {
            $tabsLocal.SelectedTab = $page
            $tabsLocal.PerformLayout()
            [Windows.Forms.Application]::DoEvents()
            if ($tabsLocal.SelectedTab -ne $page) { throw "Falha ao selecionar a aba $($page.Text)." }
        }
        [pscustomobject]@{
            Pages = [int]$tabsLocal.TabPages.Count
            TabTexts = $tabTexts
            DrawMode = [string]$tabsLocal.DrawMode
            NewRole = [string]$newVar.Value.Tag
            ImportRole = [string]$importVar.Value.Tag
            ComputerBorder = [string]$computerGridVar.Value.BorderStyle
            KeyboardBorder = [string]$keyboardGridVar.Value.BorderStyle
        }
    }

    Write-Host ('  NF abas: ' + ($result.TabTexts -join ' | '))
    Assert-True ($result.Pages -eq 6) "NF: esperado 6 abas nativas, obtido $($result.Pages)."
    Assert-True ($result.TabTexts.Count -eq 6) 'NF: lista de abas inconsistente.'
    Assert-True ([string]$result.TabTexts[0] -like 'COMPUTADOR DE BORDO*') 'NF: primeira aba deixou de representar Computador de Bordo.'
    Assert-True ([string]$result.TabTexts[1] -like 'TECLADO V5*') 'NF: segunda aba deixou de representar Teclado V5.'
    foreach ($expected in @('MOVIMENTAÇÕES','HISTÓRICO','SEGURANÇA','RESUMO')) {
        Assert-True ($result.TabTexts -contains $expected) "NF: aba ausente: $expected"
    }
    Assert-True ($result.DrawMode -ne 'OwnerDrawFixed') 'NF: OwnerDrawFixed reapareceu nas abas nativas.'
    Assert-True ($result.NewRole -eq 'Theme.Button.Action') 'NF: NOVA NF perdeu o destaque Action.'
    Assert-True ($result.ImportRole -eq 'Theme.Button.Action') 'NF: IMPORTAR EXCEL perdeu o destaque Action.'
    Assert-True ($result.ComputerBorder -eq 'None' -and $result.KeyboardBorder -eq 'None') 'NF: moldura pesada reapareceu nas grades principais.'
}

function Invoke-OneCycle {
    param($Case, [int]$Cycle)

    Write-Host "CURA 7 — $($Case.Name), ciclo $Cycle"
    if (-not [IO.File]::Exists($Case.Path)) { throw "Arquivo ausente: $($Case.Path)" }

    $context = [pscustomobject]@{ Theme = $theme; Revision = 0 }
    $moduleInfo = $null
    $hostedControl = $null
    $hostForm = $null
    $panel = $null
    try {
        $moduleName = 'Cura7_' + $Case.Kind + '_' + $Cycle + '_' + [Guid]::NewGuid().ToString('N')
        $moduleInfo = New-Module -Name $moduleName -ArgumentList @($Case.Path, $context) -ScriptBlock {
            param($scriptPath, $hostContext)
            . $scriptPath -HostedInCentral -HostTheme ([string]$hostContext.Theme) -HostThemeContext $hostContext
        }
        Assert-True ($null -ne $moduleInfo) "$($Case.Name): falha ao criar módulo isolado."

        $hostedControl = & $moduleInfo {
            $v = Get-Variable -Name HostedControlExport -Scope Script -ErrorAction SilentlyContinue
            if ($null -ne $v) { return $v.Value }
            return $null
        }
        Assert-True ($null -ne $hostedControl -and $hostedControl -is [Windows.Forms.Control]) "$($Case.Name): não exportou controle hospedável."

        $hostForm = New-Object Windows.Forms.Form
        $hostForm.StartPosition = [Windows.Forms.FormStartPosition]::Manual
        $hostForm.Location = [Drawing.Point]::new(-30000, -30000)
        $hostForm.ShowInTaskbar = $false
        $hostForm.ClientSize = [Drawing.Size]::new(1280, 760)
        $panel = New-Object Windows.Forms.Panel
        $panel.Dock = [Windows.Forms.DockStyle]::Fill
        $hostForm.Controls.Add($panel)

        if ($hostedControl -is [Windows.Forms.Form]) {
            $hostedControl.TopLevel = $false
            $hostedControl.FormBorderStyle = [Windows.Forms.FormBorderStyle]::None
            $hostedControl.ShowInTaskbar = $false
        }
        $hostedControl.Dock = [Windows.Forms.DockStyle]::Fill
        $hostedControl.Margin = [Windows.Forms.Padding]::new(0)
        $panel.Controls.Add($hostedControl)
        $hostForm.Show()
        if ($hostedControl -is [Windows.Forms.Form]) { $hostedControl.Show() } else { $hostedControl.Visible = $true }
        $hostedControl.BringToFront()
        [Windows.Forms.Application]::DoEvents()

        Invoke-HostedThemeRefresh $moduleInfo $Case.Kind $context

        foreach ($size in @(
            [Drawing.Size]::new(1024, 650),
            [Drawing.Size]::new(1280, 760),
            [Drawing.Size]::new(1600, 900),
            [Drawing.Size]::new(1180, 700)
        )) {
            $hostForm.ClientSize = $size
            $hostForm.PerformLayout()
            $panel.PerformLayout()
            $hostedControl.PerformLayout()
            [Windows.Forms.Application]::DoEvents()
            Assert-True (-not $hostedControl.IsDisposed) "$($Case.Name): controle foi descartado durante redimensionamento."
            Assert-True ($hostedControl.Width -gt 700 -and $hostedControl.Height -gt 450) "$($Case.Name): área útil inválida após redimensionamento ($($hostedControl.Width)x$($hostedControl.Height))."
        }

        switch ($Case.Kind) {
            'Generator' { Test-GeneratorRuntime $moduleInfo }
            'Maintenance' { Test-MaintenanceRuntime $moduleInfo }
            'NFEntrada' { Test-NFEntradaRuntime $moduleInfo }
        }

        Write-Host "  OK: abertura, tema, redimensionamento e controles críticos."
    }
    finally {
        try {
            if ($null -ne $hostedControl -and -not $hostedControl.IsDisposed) {
                if ($hostedControl -is [Windows.Forms.Form]) { $hostedControl.Close() }
                else { $hostedControl.Dispose() }
            }
        } catch {}
        try { if ($null -ne $hostForm -and -not $hostForm.IsDisposed) { $hostForm.Close(); $hostForm.Dispose() } } catch {}
        try { if ($null -ne $moduleInfo) { Remove-Module -ModuleInfo $moduleInfo -Force -ErrorAction SilentlyContinue } } catch {}
        [Windows.Forms.Application]::DoEvents()
        [GC]::Collect()
        [GC]::WaitForPendingFinalizers()
    }
}

foreach ($case in $cases) {
    # Dois ciclos capturam problemas de fechamento/reabertura e liberação de mutex.
    Invoke-OneCycle $case 1
    Invoke-OneCycle $case 2
}

Write-Host 'CURA 7 HOSTED LIFECYCLE: OK — Gerenciador, Manutenção e Controle de NF abriram, redimensionaram, fecharam e reabriram corretamente no pacote publicado.'
