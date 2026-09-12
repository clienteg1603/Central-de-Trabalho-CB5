param(
    [string]$GeneratedRoot = (Join-Path (Split-Path -Parent $PSScriptRoot) 'generated')
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$theme = 'Técnico industrial'
$cases = @(
    [pscustomobject]@{
        Name = 'Gerenciador'
        Kind = 'Generator'
        Path = Join-Path $GeneratedRoot 'Modulos\Gerador-de-Planilhas-CB5-TV5\Gerador Planilhas.ps1'
    },
    [pscustomobject]@{
        Name = 'Manutenção'
        Kind = 'Maintenance'
        Path = Join-Path $GeneratedRoot 'Modulos\Central-de-Manutencao-CB5\Central Manutencao CB5.ps1'
    },
    [pscustomobject]@{
        Name = 'Controle de NF'
        Kind = 'NFEntrada'
        Path = Join-Path $GeneratedRoot 'Modulos\Controle-NF-Entrada\Controle NF Entrada.ps1'
    }
)

# Matriz final da GERAL 2: pequena, intermediária, notebook 1366x768,
# ampla e Full HD. O segundo ciclo reabre cada módulo após o fechamento.
$matrix = @(
    [pscustomobject]@{ Name='Compacta'; Width=900; Height=600 },
    [pscustomobject]@{ Name='Intermediária'; Width=1180; Height=700 },
    [pscustomobject]@{ Name='Notebook-1366x768'; Width=1366; Height=768 },
    [pscustomobject]@{ Name='Ampla'; Width=1600; Height=900 },
    [pscustomobject]@{ Name='FullHD'; Width=1920; Height=1080 }
)

function Invoke-ModuleResponsiveSnapshot {
    param($ModuleInfo, [string]$Kind)
    $items = @(& $ModuleInfo {
        param($kind)
        switch ($kind) {
            'Generator' {
                if (Get-Command Invoke-GeneratorLayoutPass -ErrorAction SilentlyContinue) { Invoke-GeneratorLayoutPass }
                else {
                    if (Get-Command Update-GeneratorResponsiveLayout -ErrorAction SilentlyContinue) { Update-GeneratorResponsiveLayout }
                    if (Get-Command Update-RootLayout -ErrorAction SilentlyContinue) { Update-RootLayout }
                }
                $profile = [string]$script:GeneratorResponsiveProfile
            }
            'Maintenance' {
                if (Get-Command Invoke-MaintenanceLayoutPass -ErrorAction SilentlyContinue) { Invoke-MaintenanceLayoutPass }
                elseif (Get-Command Update-MaintenanceResponsiveLayout -ErrorAction SilentlyContinue) { Update-MaintenanceResponsiveLayout }
                $profile = [string]$script:MaintenanceResponsiveProfile
            }
            'NFEntrada' {
                if (Get-Command Update-NFResponsiveLayout -ErrorAction SilentlyContinue) { Update-NFResponsiveLayout }
                $profile = [string]$script:NFResponsiveProfile
            }
            default { throw "Tipo de módulo desconhecido: $kind" }
        }

        $export = $script:HostedControlExport
        if ($null -eq $export) { throw "$kind não possui HostedControlExport." }
        return [pscustomobject]@{
            Profile = $profile
            Width = [int]$export.ClientSize.Width
            Height = [int]$export.ClientSize.Height
            Visible = [bool]$export.Visible
            Disposed = [bool]$export.IsDisposed
        }
    } $Kind)
    if ($items.Count -eq 0) { throw "$Kind não retornou snapshot responsivo." }
    return $items[$items.Count - 1]
}

function Invoke-ThemeAuthority {
    param($ModuleInfo, [string]$Kind, $HostContext)
    $HostContext.Theme = $theme
    $HostContext.Revision = [int]$HostContext.Revision + 1
    $items = @(& $ModuleInfo {
        param($kind, $hostTheme)
        switch ($kind) {
            'Generator' { return [bool](Set-HostedGeneratorTheme $hostTheme) }
            'Maintenance' { return [bool](Set-HostedMaintenanceTheme $hostTheme) }
            'NFEntrada' { return [bool](Set-HostedNFEntradaTheme $hostTheme) }
        }
        return $false
    } $Kind $theme)
    if ($items.Count -eq 0 -or -not [bool]$items[$items.Count - 1]) {
        throw "$Kind recusou a aparência oficial durante a matriz de tamanhos."
    }
}

foreach ($case in $cases) {
    if (-not (Test-Path -LiteralPath $case.Path -PathType Leaf)) {
        throw "Arquivo ausente para $($case.Name): $($case.Path)"
    }

    $profilesFirstCycle = New-Object 'Collections.Generic.List[string]'

    foreach ($cycle in 1..2) {
        $moduleName = 'Geral2Layout_' + $case.Kind + '_' + $cycle + '_' + [Guid]::NewGuid().ToString('N')
        $moduleInfo = $null
        $hostedControl = $null
        $hostForm = $null
        $hostPanel = $null
        try {
            $hostContext = [pscustomobject]@{ Theme = $theme; Revision = 0 }
            $moduleInfo = New-Module -Name $moduleName -ArgumentList @($case.Path, $hostContext) -ScriptBlock {
                param($scriptPath, $context)
                . $scriptPath -HostedInCentral -HostTheme ([string]$context.Theme) -HostThemeContext $context
            }
            if ($null -eq $moduleInfo) { throw "Falha ao abrir $($case.Name), ciclo $cycle." }

            $hostedControl = & $moduleInfo {
                $v = Get-Variable -Name HostedControlExport -Scope Script -ErrorAction SilentlyContinue
                if ($null -ne $v) { return $v.Value }
                return $null
            }
            if ($null -eq $hostedControl -or -not ($hostedControl -is [Windows.Forms.Control])) {
                throw "$($case.Name) não exportou um controle hospedável no ciclo $cycle."
            }

            $hostForm = New-Object Windows.Forms.Form
            $hostForm.StartPosition = [Windows.Forms.FormStartPosition]::Manual
            $hostForm.Location = [Drawing.Point]::new(-2400, -1800)
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

            $hostForm.Size = [Drawing.Size]::new(1366, 768)
            $hostForm.Show()
            if ($hostedControl -is [Windows.Forms.Form]) { $hostedControl.Show() } else { $hostedControl.Visible = $true }
            $hostedControl.BringToFront()
            [Windows.Forms.Application]::DoEvents()
            Invoke-ThemeAuthority $moduleInfo $case.Kind $hostContext

            $sizesToRun = if ($cycle -eq 1) { $matrix } else { @($matrix[2]) }
            foreach ($sizeCase in $sizesToRun) {
                $hostForm.Size = [Drawing.Size]::new([int]$sizeCase.Width, [int]$sizeCase.Height)
                $hostForm.PerformLayout()
                $hostPanel.PerformLayout()
                $hostedControl.PerformLayout()
                [Windows.Forms.Application]::DoEvents()
                Start-Sleep -Milliseconds 110
                [Windows.Forms.Application]::DoEvents()

                $snap = Invoke-ModuleResponsiveSnapshot $moduleInfo $case.Kind
                if ($snap.Disposed) { throw "$($case.Name)/$($sizeCase.Name): controle foi descartado durante resize." }
                if (-not $snap.Visible) { throw "$($case.Name)/$($sizeCase.Name): controle deixou de ficar visível." }
                if ($snap.Width -lt 500 -or $snap.Height -lt 320) {
                    throw "$($case.Name)/$($sizeCase.Name): área útil colapsou para $($snap.Width)x$($snap.Height)."
                }
                if (@('Tight','Compact','Comfortable') -notcontains [string]$snap.Profile) {
                    throw "$($case.Name)/$($sizeCase.Name): perfil responsivo inválido '$($snap.Profile)'."
                }

                $dw = [Math]::Abs([int]$snap.Width - [int]$hostPanel.ClientSize.Width)
                $dh = [Math]::Abs([int]$snap.Height - [int]$hostPanel.ClientSize.Height)
                if ($dw -gt 8 -or $dh -gt 8) {
                    throw "$($case.Name)/$($sizeCase.Name): módulo não acompanhou o host (diferença ${dw}x${dh})."
                }

                if ($cycle -eq 1) { $profilesFirstCycle.Add([string]$snap.Profile) }
                Write-Host ("  {0,-16} {1,4}x{2,-4} perfil={3,-11} área={4}x{5}" -f $sizeCase.Name,$sizeCase.Width,$sizeCase.Height,$snap.Profile,$snap.Width,$snap.Height)
            }
        }
        finally {
            try { if ($null -ne $hostForm -and -not $hostForm.IsDisposed) { $hostForm.Close(); $hostForm.Dispose() } } catch {}
            try { if ($null -ne $hostedControl -and -not $hostedControl.IsDisposed) { $hostedControl.Dispose() } } catch {}
            try { if ($null -ne $moduleInfo) { Remove-Module -ModuleInfo $moduleInfo -Force -ErrorAction SilentlyContinue } } catch {}
        }
    }

    $uniqueProfiles = @($profilesFirstCycle | Select-Object -Unique)
    if ($uniqueProfiles.Count -lt 2) {
        throw "$($case.Name): matriz não provocou mudança real de densidade responsiva. Perfis: $($uniqueProfiles -join ', ')."
    }
    Write-Host ("MATRIZ {0}: OK — perfis exercitados: {1}; fechamento e reabertura OK." -f $case.Name,($uniqueProfiles -join ', '))
}

Write-Host 'GERAL 2 / ETAPA 8: MATRIZ FINAL OK — 900x600, 1180x700, 1366x768, 1600x900 e 1920x1080; três módulos fecharam e reabriram sem colapso.'
