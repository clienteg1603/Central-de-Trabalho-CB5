from pathlib import Path
p=Path('src/generated/Modulos/Central-de-Manutencao-CB5/Central Manutencao CB5.ps1')
t=p.read_text(encoding='utf-8-sig')

def one(a,b,n):
    global t
    if t.count(a)!=1:
        raise SystemExit(n)
    t=t.replace(a,b,1)

one('if ($null -ne $script:HostedSectionNavPanel) { $script:HostedSectionNavPanel.BackColor = $script:CurrentPalette.Background }','if ($null -ne $script:HostedSectionNavPanel) { $script:HostedSectionNavPanel.BackColor = $script:CurrentPalette.Surface }\n        if ($null -ne $dashboardNavigation) { $dashboardNavigation.BackColor = $script:CurrentPalette.Surface }','nav surface')
one('[pscustomobject]@{ Name = "faixa de navegação hospedada"; Actual = [int]$script:HostedSectionNavPanel.BackColor.ToArgb(); Expected = [int]$palette.Background.ToArgb() },','[pscustomobject]@{ Name = "faixa de navegação hospedada"; Actual = [int]$script:HostedSectionNavPanel.BackColor.ToArgb(); Expected = [int]$palette.Surface.ToArgb() },\n        [pscustomobject]@{ Name = "card de resumo sem moldura"; Actual = [int]$cardSeries.BorderStyle; Expected = [int][Windows.Forms.BorderStyle]::None },','nav audit')
old='''        foreach ($pair in $pairs) {
            $button = $pair[0]
            $page = $pair[1]
            $button.Tag = if ($mainTabs.SelectedTab -eq $page) { "Primary" } else { "Secondary" }
            Set-MaintenanceButtonStyle $button
        }
        Update-MaintenanceHostedViewport'''
new='''        foreach ($pair in $pairs) {
            $button = $pair[0]
            $page = $pair[1]
            $button.Tag = if ($mainTabs.SelectedTab -eq $page) { "Primary" } else { "Secondary" }
            Set-MaintenanceButtonStyle $button
            Set-MaintenanceRoundedRegion $button 7
        }
        $pv = Get-Variable -Name passageTab -ErrorAction SilentlyContinue
        if ($null -ne $dashboardNewButton) {
            $dashboardNewButton.Tag = "Action"
            Set-MaintenanceButtonStyle $dashboardNewButton
            $active = ($null -ne $pv -and $null -ne $pv.Value -and $mainTabs.SelectedTab -eq $pv.Value)
            $dashboardNewButton.FlatAppearance.BorderSize = if ($active) { 2 } else { 0 }
            if ($active) { $dashboardNewButton.FlatAppearance.BorderColor = $script:CurrentPalette.Accent }
            Set-MaintenanceRoundedRegion $dashboardNewButton 7
        }
        Update-MaintenanceHostedViewport'''
one(old,new,'active navigation')
p.write_text(t,encoding='utf-8')
print('CURA4 nav OK')
