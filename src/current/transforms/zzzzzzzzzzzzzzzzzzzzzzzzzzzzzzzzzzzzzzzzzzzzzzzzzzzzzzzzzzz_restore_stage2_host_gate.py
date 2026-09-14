from pathlib import Path

cp=Path('src/generated/Central de Trabalho.ps1')
gp=Path('src/generated/Modulos/Gerador-de-Planilhas-CB5-TV5/Gerador Planilhas.ps1')
mp=Path('src/generated/Modulos/Central-de-Manutencao-CB5/Central Manutencao CB5.ps1')
np=Path('src/generated/Modulos/Controle-NF-Entrada/Controle NF Entrada.ps1')
c=cp.read_text(encoding='utf-8-sig'); g=gp.read_text(encoding='utf-8-sig'); m=mp.read_text(encoding='utf-8-sig'); n=np.read_text(encoding='utf-8-sig')

def one(t,a,b,l):
 k=t.count(a)
 if k!=1: raise SystemExit(f'S2 {l}: {k}')
 return t.replace(a,b,1)

c=one(c,'$script:AppVersion = "0.21.67"','$script:AppVersion = "0.21.68"','central version')
c=one(c,'$script:GeneratorVersion = "3.7.20"','$script:GeneratorVersion = "3.7.21"','central generator version')
c=one(c,'$script:MaintenanceVersion = "0.6.17"','$script:MaintenanceVersion = "0.6.18"','central maintenance version')
c=one(c,'$script:NFEntradaVersion = "2.6.24"','$script:NFEntradaVersion = "2.6.25"','central NF version')
g=one(g,'$script:AppVersion = "3.7.20"','$script:AppVersion = "3.7.21"','generator version')
m=one(m,'$script:AppVersion = "0.6.17"','$script:AppVersion = "0.6.18"','maintenance version')
n=one(n,'$script:ModuleVersion = "2.6.24"','$script:ModuleVersion = "2.6.25"','NF version')

# O contexto ja compartilhado entre Central e modulos passa a carregar o estado
# da restauracao. Assim os tres programas podem ignorar seus proprios callbacks
# de layout sem criar uma segunda comunicacao entre processos/modulos.
c=one(c,'    Revision = 0\n}','    Revision = 0\n    LayoutRestoreActive = $false\n}','contexto inicial')
c=one(c,'[pscustomobject]@{ Theme = $resolved; Revision = 0 }','[pscustomobject]@{ Theme = $resolved; Revision = 0; LayoutRestoreActive = $false }','contexto fallback')

# Gerenciador
helper='''function Test-GeneratorHostedLayoutRestoreGate {\n    if (-not $script:IsInProcessHosted -or $null -eq $script:HostedThemeContext) { return $false }\n    try { return [bool]$script:HostedThemeContext.LayoutRestoreActive } catch { return $false }\n}\n'''
g=one(g,'$script:HostedThemeContext = $(if ($script:IsInProcessHosted) { $HostThemeContext } else { $null })', '$script:HostedThemeContext = $(if ($script:IsInProcessHosted) { $HostThemeContext } else { $null })\n'+helper,'generator helper')
for a,b,l in [
('function Update-GeneratorResponsiveLayout {\n    if (-not $script:IsInProcessHosted -or $script:GeneratorResponsiveBusy) { return }','function Update-GeneratorResponsiveLayout {\n    if (Test-GeneratorHostedLayoutRestoreGate) { return }\n    if (-not $script:IsInProcessHosted -or $script:GeneratorResponsiveBusy) { return }','gen responsive'),
('function Update-GeneratorInternalLayouts {\n    if (-not $script:IsInProcessHosted) { return }','function Update-GeneratorInternalLayouts {\n    if (Test-GeneratorHostedLayoutRestoreGate) { return }\n    if (-not $script:IsInProcessHosted) { return }','gen internal'),
('function Update-GeneratorRemainingLayouts {\n    if (-not $script:IsInProcessHosted) { return }','function Update-GeneratorRemainingLayouts {\n    if (Test-GeneratorHostedLayoutRestoreGate) { return }\n    if (-not $script:IsInProcessHosted) { return }','gen remaining'),
('function Update-RootLayout {\n    if ($null -eq $form -or $null -eq $headerPanel -or $null -eq $tabs -or $null -eq $footerPanel) { return }','function Update-RootLayout {\n    if (Test-GeneratorHostedLayoutRestoreGate) { return }\n    if ($null -eq $form -or $null -eq $headerPanel -or $null -eq $tabs -or $null -eq $footerPanel) { return }','gen root'),
('function Invoke-GeneratorLayoutPass {\n    try {','function Invoke-GeneratorLayoutPass {\n    if (Test-GeneratorHostedLayoutRestoreGate) { return }\n    try {','gen invoke'),
('function Schedule-GeneratorLayoutPass {\n    try {\n        if ($null -eq $script:GeneratorLayoutTimer) { return }','function Schedule-GeneratorLayoutPass {\n    try {\n        if (Test-GeneratorHostedLayoutRestoreGate) { return }\n        if ($null -eq $script:GeneratorLayoutTimer) { return }','gen schedule')]: g=one(g,a,b,l)

# Manutencao
helper='''function Test-MaintenanceHostedLayoutRestoreGate {\n    if (-not $script:IsInProcessHosted -or $null -eq $script:HostedThemeContext) { return $false }\n    try { return [bool]$script:HostedThemeContext.LayoutRestoreActive } catch { return $false }\n}\n'''
m=one(m,'$script:HostedThemeContext = $(if ($script:IsInProcessHosted) { $HostThemeContext } else { $null })', '$script:HostedThemeContext = $(if ($script:IsInProcessHosted) { $HostThemeContext } else { $null })\n'+helper,'maintenance helper')
for a,b,l in [
('function Update-MaintenanceResponsiveLayout {\n    if (-not $script:IsInProcessHosted -or $script:MaintenanceResponsiveBusy -or $null -eq $form) { return }','function Update-MaintenanceResponsiveLayout {\n    if (Test-MaintenanceHostedLayoutRestoreGate) { return }\n    if (-not $script:IsInProcessHosted -or $script:MaintenanceResponsiveBusy -or $null -eq $form) { return }','maint responsive'),
('function Update-MaintenanceHostedViewport {\n        if (-not $script:IsInProcessHosted) { return }','function Update-MaintenanceHostedViewport {\n        if (Test-MaintenanceHostedLayoutRestoreGate) { return }\n        if (-not $script:IsInProcessHosted) { return }','maint viewport'),
('function Invoke-MaintenanceLayoutPass {\n    try { Update-MaintenanceResponsiveLayout } catch {}','function Invoke-MaintenanceLayoutPass {\n    if (Test-MaintenanceHostedLayoutRestoreGate) { return }\n    try { Update-MaintenanceResponsiveLayout } catch {}','maint invoke'),
('function Schedule-MaintenanceLayoutPass {\n    try {\n        if ($null -eq $script:MaintenanceLayoutTimer) { return }','function Schedule-MaintenanceLayoutPass {\n    try {\n        if (Test-MaintenanceHostedLayoutRestoreGate) { return }\n        if ($null -eq $script:MaintenanceLayoutTimer) { return }','maint schedule')]: m=one(m,a,b,l)

# NF
helper='''function Test-NFHostedLayoutRestoreGate {\n    if (-not $script:IsInProcessHosted -or $null -eq $script:HostedThemeContext) { return $false }\n    try { return [bool]$script:HostedThemeContext.LayoutRestoreActive } catch { return $false }\n}\n'''
n=one(n,'$script:HostedThemeContext = $(if ($script:IsInProcessHosted) { $HostThemeContext } else { $null })', '$script:HostedThemeContext = $(if ($script:IsInProcessHosted) { $HostThemeContext } else { $null })\n'+helper,'NF helper')
n=one(n,'function Update-NFResponsiveLayout {\n    if ($script:NFResponsiveBusy -or $null -eq $form) { return }','function Update-NFResponsiveLayout {\n    if (Test-NFHostedLayoutRestoreGate) { return }\n    if ($script:NFResponsiveBusy -or $null -eq $form) { return }','NF responsive')
n=one(n,'function Schedule-NFResponsiveLayout {\n    try {\n        if ($null -eq $script:NFLayoutTimer) { return }','function Schedule-NFResponsiveLayout {\n    try {\n        if (Test-NFHostedLayoutRestoreGate) { return }\n        if ($null -eq $script:NFLayoutTimer) { return }','NF schedule')

# A Central ativa o gate ao minimizar/restaurar. Na conclusao, o modulo ainda
# esta oculto: o gate abre para uma unica passagem final, fecha durante o
# Visible=true e so depois e liberado definitivamente.
c=one(c,'            try { $script:CentralRestoreTimer.Stop() } catch {}\n\n            # Somente a área do programa integrado','            try { $script:CentralRestoreTimer.Stop() } catch {}\n            try { $script:HostedThemeContext.LayoutRestoreActive = $true } catch {}\n\n            # Somente a área do programa integrado','gate minimizar')
c=one(c,'        $script:CentralRestoreInProgress = $true\n        $script:CentralRestoreStableTicks = 0','        $script:CentralRestoreInProgress = $true\n        try { $script:HostedThemeContext.LayoutRestoreActive = $true } catch {}\n        $script:CentralRestoreStableTicks = 0','gate restaurar')
old='''        if ($script:CentralRestoreEmbeddedContentWasVisible) {\n            try { $embeddedContent.Visible = $true } catch {}\n        }\n        $script:CentralRestoreEmbeddedContentWasVisible = $false\n\n        Invoke-CentralResponsivePass\n        Invoke-CentralHostedLayoutPass\n        try { $form.Invalidate($true) } catch {}'''
new='''        Invoke-CentralResponsivePass\n        try { $script:HostedThemeContext.LayoutRestoreActive = $false } catch {}\n        Invoke-CentralHostedLayoutPass\n        try { $script:HostedThemeContext.LayoutRestoreActive = $true } catch {}\n\n        if ($script:CentralRestoreEmbeddedContentWasVisible) {\n            try {\n                $embeddedContent.Visible = $true\n                $embeddedContent.PerformLayout()\n                if ($null -ne $script:HostedForm -and -not $script:HostedForm.IsDisposed) { $script:HostedForm.PerformLayout() }\n            } catch {}\n        }\n        $script:CentralRestoreEmbeddedContentWasVisible = $false\n        try { $script:HostedThemeContext.LayoutRestoreActive = $false } catch {}\n        try {\n            if ($null -ne $script:HostedForm -and -not $script:HostedForm.IsDisposed) { $script:HostedForm.Invalidate($true) }\n            $form.Invalidate($true)\n        } catch {}'''
c=one(c,old,new,'complete order')
c=one(c,'        try { $embeddedContent.Visible = $true } catch {}\n        try { Invoke-CentralResponsivePass } catch {}','        try { $embeddedContent.Visible = $true } catch {}\n        try { $script:HostedThemeContext.LayoutRestoreActive = $false } catch {}\n        try { Invoke-CentralResponsivePass } catch {}','complete fallback')
c=one(c,'        try { $embeddedContent.Visible = $true } catch {}\n    }\n}','        try { $embeddedContent.Visible = $true } catch {}\n        try { $script:HostedThemeContext.LayoutRestoreActive = $false } catch {}\n    }\n}','repair fallback')

c+='\n# CENTRAL_RESTORE_TARGETED_STAGE2_V02168\n'; g+='\n# HOSTED_RESTORE_GATE_STAGE2_V03721\n'; m+='\n# HOSTED_RESTORE_GATE_STAGE2_V00618\n'; n+='\n# HOSTED_RESTORE_GATE_STAGE2_V02625\n'
cp.write_text(c,encoding='utf-8'); gp.write_text(g,encoding='utf-8'); mp.write_text(m,encoding='utf-8'); np.write_text(n,encoding='utf-8')
print('RESTORE STAGE2 OK')
