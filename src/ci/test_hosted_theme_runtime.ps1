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
    param($ModuleInfo, [string]$Kind)
    $items = @(& $ModuleInfo {
        param($kind)
        switch ($kind) {
            'Generator' { Get-HostedGeneratorThemeAudit }
            'Maintenance' { Get-HostedMaintenanceThemeAudit }
            'NFEntrada' { Get-HostedNFEntradaThemeAudit }
        }
    } $Kind)
    if ($items.Count -eq 0) { throw "$Kind não retornou auditoria de aparência." }
    return $items[$items.Count - 1]
}

function Invoke-CentralStyleThemeCall {
    param($ModuleInfo, [string]$Kind, [string]$Theme, $HostContext)
    $HostContext.Theme = $Theme
    $HostContext.Revision = [int]$HostContext.Revision + 1
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
        $hostContext = [pscustomobject]@{ Theme = 'Escuro profissional'; Revision = 0 }
        $moduleInfo = New-Module -Name $moduleName -ArgumentList @($case.Path, $hostContext) -ScriptBlock {
            param($scriptPath, $context)
            . $scriptPath -HostedInCentral -HostTheme ([string]$context.Theme) -HostThemeContext $context
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
            $ok = Invoke-CentralStyleThemeCall $moduleInfo $case.Kind $theme $hostContext
            if (-not $ok) {
                $direct = Invoke-ThemeDirectDiagnostic $moduleInfo $case.Kind $theme
                throw "$($case.Name) recusou '$theme' quando hospedado. Diagnóstico direto: $direct"
            }

            $hostedControl.PerformLayout()
            $hostedControl.Invalidate($true)
            [Windows.Forms.Application]::DoEvents()
            $snap = Invoke-ThemeSnapshot $moduleInfo $case.Kind
            $invalid = @($snap.InvalidChecks | ForEach-Object { [string]$_.Name }) -join ', '
            Write-Host ("  autoridade={0} interno={1} revisão={2} controles={3}" -f $snap.AuthorityTheme,$snap.InternalTheme,$snap.Revision,@($snap.Checks).Count)
            if (-not [bool]$snap.Valid) { throw "$($case.Name): controles fora da paleta em '$theme': $invalid" }
            if ([string]$snap.AuthorityTheme -ne $theme) { throw "$($case.Name): autoridade hospedada não acompanhou '$theme'." }
            if ([int]$snap.Revision -ne [int]$hostContext.Revision) { throw "$($case.Name): revisão de aparência divergente em '$theme'." }
        }
    }
    finally {
        try { if ($null -ne $hostForm -and -not $hostForm.IsDisposed) { $hostForm.Close(); $hostForm.Dispose() } } catch {}
        try { if ($null -ne $hostedControl -and -not $hostedControl.IsDisposed) { $hostedControl.Dispose() } } catch {}
        try { if ($null -ne $moduleInfo) { Remove-Module -ModuleInfo $moduleInfo -Force -ErrorAction SilentlyContinue } } catch {}
    }
}

Write-Host 'THEME RUNTIME: OK — três módulos hospedados alternaram os quatro temas e confirmaram cores reais.'
