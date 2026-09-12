from pathlib import Path
p=Path('src/generated/Modulos/Gerador-de-Planilhas-CB5-TV5/Gerador Planilhas.ps1')
g=p.read_text(encoding='utf-8-sig')

def one(a,b,label):
    global g
    n=g.count(a)
    if n!=1: raise SystemExit(f'E2C {label}: {n}')
    g=g.replace(a,b,1)

marker='function Update-RootLayout {'
helper=r'''function Update-GeneratorStage2Density {
    if (-not $script:IsInProcessHosted) { return }
    try {
        $rh = if ($script:GeneratorResponsiveProfile -eq 'Tight') { 23 } elseif ($script:GeneratorResponsiveProfile -eq 'Compact') { 25 } else { 27 }
        $hh = if ($script:GeneratorResponsiveProfile -eq 'Tight') { 27 } elseif ($script:GeneratorResponsiveProfile -eq 'Compact') { 29 } else { 30 }
        foreach ($grid in @($extraGrid,$componentGrid,$componentMovementGrid,$componentUnionGrid,$combineGrid,$descriptionsGrid)) {
            if ($null -ne $grid -and $grid -is [Windows.Forms.DataGridView]) {
                $grid.RowTemplate.Height = $rh
                $grid.ColumnHeadersHeight = $hh
            }
        }
    } catch {}
}

'''
if g.count(marker)!=1: raise SystemExit('E2C root ausente')
g=g.replace(marker,helper+marker,1)
one('    Update-GeneratorRemainingLayouts\n\n    $clientWidth','    Update-GeneratorRemainingLayouts\n    Update-GeneratorStage2Density\n\n    $clientWidth','densidade')
g+='\n# GERAL2_ETAPA2_GENERATOR_DENSITY_V03715\n'
p.write_text(g,encoding='utf-8')
print('GERAL 2 ETAPA 2C: OK')
