param(
    [string]$GeneratedRoot = (Join-Path (Split-Path -Parent $PSScriptRoot) 'generated')
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$themes = @('Escuro profissional','Técnico industrial','Claro corporativo','Alto contraste')

$cases = @(
    [pscustomobject]@{
        Name = 'Gerenciador'
        Kind = 'Generator'
        Path = Join-Path $GeneratedRoot 'Modulos\Gerador-de-Planilhas-CB5-TV5\Gerador Planilhas.ps1'
        Setter = 'Set-HostedGeneratorTheme'
    },
    [pscustomobject]@{
        Name = 'Manutenção'
        Kind = 'Maintenance'
        Path = Join-Path $GeneratedRoot 'Modulos\Central-de-Manutencao-CB5\Central Manutencao CB5.ps1'
        Setter = 'Set-HostedMaintenanceTheme'
    },
    [pscustomobject]@{
        Name = 'NF Entrada'
        Kind = 'NFEntrada'
        Path = Join-Path $GeneratedRoot 'Modulos\Controle-NF-Entrada\Controle NF Entrada.ps1'
        Setter = 'Set-HostedNFEntradaTheme'
    }
)

function Invoke-ThemeSnapshot {
    param($ModuleInfo, [string]$Kind, [string]$Theme)
    & $ModuleInfo {
        param($kind, $theme)
        switch ($kind) {
            'Generator' {
                $mapped = Get-GeneratorThemeFromHost $theme
                $product = [string]$productCombo.SelectedItem
                if (@('CB5','TV5') -notcontains $product) { $product = 'CB5' }
                $p = Get-ThemePalette $mapped $product
                [pscustomobject]@{
                    Combo = [string]$themeCombo.SelectedItem
                    ExpectedCombo = $mapped
                    Actual = [int]$form.BackColor.ToArgb()
                    Expected = [int]$p.Background.ToArgb()
                }
            }
            'Maintenance' {
                $mapped = Get-MaintenanceThemeFromHost $theme
                $p = Get-MaintenancePalette $mapped
                [pscustomobject]@{
                    Combo = [string]$themeCombo.SelectedItem
                    ExpectedCombo = $mapped
                    Actual = [int]$form.BackColor.ToArgb()
                    Expected = [int]$p.Background.ToArgb()
                }
            }
            'NFEntrada' {
                $p = Get-NFEntradaPalette $theme
                [pscustomobject]@{
                    Combo = $theme
                    ExpectedCombo = $theme
                    Actual = [int]$form.BackColor.ToArgb()
                    Expected = [int]$p.Background.ToArgb()
                }
            }
        }
    } $Kind $Theme
}

function Invoke-CentralStyleThemeCall {
    param($ModuleInfo, [string]$Kind, [string]$Theme)
    $items = @(& $ModuleInfo {
        param($targetModule, $hostTheme)
        switch ($targetModule) {
            'Generator' {
                $resultItems = @(Set-HostedGeneratorTheme $hostTheme)
                if ($resultItems.Count -eq 0) { return $false }
                return [bool]$resultItems[$resultItems.Count - 1]
            }
            'Maintenance' {
                $resultItems = @(Set-HostedMaintenanceTheme $hostTheme)
                if ($resultItems.Count -eq 0) { return $false }
                return [bool]$resultItems[$resultItems.Count - 1]
            }
            'NFEntrada' {
                $resultItems = @(Set-HostedNFEntradaTheme $hostTheme)
                if ($resultItems.Count -eq 0) { return $false }
                return [bool]$resultItems[$resultItems.Count - 1]
            }
        }
    } $Kind $Theme)
    if ($items.Count -eq 0) { return $false }
    return [bool]$items[$items.Count - 1]
}

function Invoke-ThemeDirectDiagnostic {
    param($ModuleInfo, [string]$Kind, [string]$Theme)
    & $ModuleInfo {
        param($kind, $theme)
        try {
            switch ($kind) {
                'Generator' {
                    $script:HostedCentralTheme = $theme
                    $mapped = Get-GeneratorThemeFromHost $theme
                    $themeCombo.SelectedItem = $mapped
                    Apply-AppTheme
                    Update-GeneratorResponsiveLayout
                    Update-RootLayout
                }
                'Maintenance' {
                    $script:HostedCentralTheme = $theme
                    $mapped = Get-MaintenanceThemeFromHost $theme
                    $themeCombo.SelectedItem = $mapped
                    Apply-MaintenanceTheme
                    Update-MaintenanceResponsiveLayout
                }
                'NFEntrada' {
                    [void](Set-HostedNFEntradaTheme $theme)
                }
            }
            return 'SEM EXCEÇÃO DIRETA'
        }
        catch {
            return $_.Exception.ToString()
        }
    } $Kind $Theme
}

foreach ($case in $cases) {
    if (-not (Test-Path -LiteralPath $case.Path -PathType Leaf)) {
        throw "Arquivo ausente para $($case.Name): $($case.Path)"
    }

    Write-Host "=== $($case.Name) ==="
    $moduleName = 'ThemeRuntime_' + $case.Kind + '_' + [Guid]::NewGuid().ToString('N')
    $moduleInfo = $null
    $hostedControl = $null
    $hostForm = $null
    $hostPanel = $null
    try {
        $moduleInfo = New-Module -Name $moduleName -ArgumentList @($case.Path, 'Escuro profissional') -ScriptBlock {
            param($scriptPath, $hostTheme)
            . $scriptPath -HostedInCentral -HostTheme $hostTheme
        }
        if ($null -eq $moduleInfo) { throw "Falha ao criar módulo isolado para $($case.Name)." }

        $hostedControl = & $moduleInfo {
            $v = Get-Variable -Name HostedControlExport -Scope Script -ErrorAction SilentlyContinue
            if ($null -ne $v) { return $v.Value }
            return $null
        }
        if ($null -eq $hostedControl -or -not ($hostedControl -is [Windows.Forms.Control])) {
            throw "$($case.Name) não exportou um controle hospedável."
        }

        # Reproduz a integração da Central: Form pai + painel host + módulo visível/dock Fill.
        $hostForm = New-Object Windows.Forms.Form
        $hostForm.Size = [Drawing.Size]::new(1400, 850)
        $hostForm.StartPosition = [Windows.Forms.FormStartPosition]::Manual
        $hostForm.Location = [Drawing.Point]::new(-2000, -2000)
        $hostForm.ShowInTaskbar = $false
        $hostPanel = New-Object Windows.Forms.Panel
        $hostPanel.Dock = [Windows.Forms.DockStyle]::Fill
        $hostForm.Controls.Add($hostPanel)

        if ($hostedControl -is [Windows.Forms.Form]) {
            $hostedControl.TopLevel = $false
            $hostedControl.FormBorderStyle = [Windows.Forms.FormBorderStyle]::None
            $hostedControl.ShowInTaskbar = $false
        }
        $hostedControl.Dock = [Windows.Forms.DockStyle]::Fill
        $hostPanel.Controls.Add($hostedControl)
        $hostForm.Show()
        if ($hostedControl -is [Windows.Forms.Form]) { $hostedControl.Show() } else { $hostedControl.Visible = $true }
        $hostedControl.BringToFront()
        $hostedControl.PerformLayout()
        [Windows.Forms.Application]::DoEvents()

        foreach ($theme in $themes) {
            Write-Host "Testando $($case.Name): $theme"
            $ok = Invoke-CentralStyleThemeCall $moduleInfo $case.Kind $theme
            if (-not $ok) {
                $direct = Invoke-ThemeDirectDiagnostic $moduleInfo $case.Kind $theme
                throw "$($case.Name) recusou '$theme' quando hospedado. Diagnóstico direto: $direct"
            }

            $hostedControl.PerformLayout()
            $hostedControl.Invalidate($true)
            $hostedControl.Update()
            $hostedControl.Refresh()
            [Windows.Forms.Application]::DoEvents()
            $snap = Invoke-ThemeSnapshot $moduleInfo $case.Kind $theme
            Write-Host ("  combo={0} esperado={1} root={2} esperadoRoot={3}" -f $snap.Combo,$snap.ExpectedCombo,$snap.Actual,$snap.Expected)
            if ($snap.Combo -ne $snap.ExpectedCombo) { throw "$($case.Name): seletor interno não acompanhou '$theme'." }
            if ($snap.Actual -ne $snap.Expected) { throw "$($case.Name): cor raiz não acompanhou '$theme'." }
        }
    }
    finally {
        try { if ($null -ne $hostForm -and -not $hostForm.IsDisposed) { $hostForm.Close(); $hostForm.Dispose() } } catch {}
        try { if ($null -ne $hostedControl -and -not $hostedControl.IsDisposed) { $hostedControl.Dispose() } } catch {}
        try { if ($null -ne $moduleInfo) { Remove-Module -ModuleInfo $moduleInfo -Force -ErrorAction SilentlyContinue } } catch {}
    }
}

Write-Host 'THEME RUNTIME: OK — três módulos hospedados alternaram os quatro temas e confirmaram cores reais.'
