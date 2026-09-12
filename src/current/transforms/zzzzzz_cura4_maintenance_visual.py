from pathlib import Path

cp=Path('src/generated/Central de Trabalho.ps1')
mp=Path('src/generated/Modulos/Central-de-Manutencao-CB5/Central Manutencao CB5.ps1')
c=cp.read_text(encoding='utf-8-sig')
m=mp.read_text(encoding='utf-8-sig')

def one(t,a,b,n):
    if t.count(a)!=1:
        raise SystemExit(n)
    return t.replace(a,b,1)

c=one(c,'$script:AppVersion = "0.21.37"','$script:AppVersion = "0.21.38"','central version')
c=one(c,'$script:MaintenanceVersion = "0.6.9"','$script:MaintenanceVersion = "0.6.10"','maintenance declared')
m=one(m,'$script:AppVersion = "0.6.9"','$script:AppVersion = "0.6.10"','maintenance version')
m=one(m,'$script:HostedSectionNavPanel.Padding = [Windows.Forms.Padding]::new(8, 2, 8, 2)','$script:HostedSectionNavPanel.Padding = [Windows.Forms.Padding]::new(10, 4, 10, 4)','nav padding')
m=one(m,'$navHeight = if ($shellH -lt 600) { 38 } else { 42 }','$navHeight = if ($shellH -lt 600) { 44 } else { 48 }','nav height')
m=one(m,'$script:HostedOverviewPanel.Padding = [Windows.Forms.Padding]::new(8, 4, 8, 2)','$script:HostedOverviewPanel.Padding = [Windows.Forms.Padding]::new(10, 6, 10, 4)','overview padding')
m=one(m,'Set-MaintenanceRoundedRegion $card 10','Set-MaintenanceRoundedRegion $card 12','card radius')

cp.write_text(c,encoding='utf-8')
mp.write_text(m,encoding='utf-8')
print('CURA4 base OK')
