from pathlib import Path

cp = Path('src/generated/Central de Trabalho.ps1')
mp = Path('src/generated/Modulos/Central-de-Manutencao-CB5/Central Manutencao CB5.ps1')
c = cp.read_text(encoding='utf-8-sig')
m = mp.read_text(encoding='utf-8-sig')

def one(text, old, new, label):
    n = text.count(old)
    if n != 1:
        raise SystemExit(f'GERAL2/E3D {label}: esperado 1, encontrado {n}')
    return text.replace(old, new, 1)

# Versões desta etapa.
c = one(c, '$script:AppVersion = "0.21.50"', '$script:AppVersion = "0.21.51"', 'versao Central')
c = one(c, '$script:MaintenanceVersion = "0.6.11"', '$script:MaintenanceVersion = "0.6.12"', 'versao Manutencao Central')
m = one(m, '$script:AppVersion = "0.6.11"', '$script:AppVersion = "0.6.12"', 'versao Manutencao')

# A rotina responsiva passa a servir também a janela independente. Antes ela
# retornava imediatamente fora da Central, então maximizar/restaurar a janela
# standalone não recalculava a densidade nem as telas técnicas.
m = one(
    m,
    'if (-not $script:IsInProcessHosted -or $script:MaintenanceResponsiveBusy -or $null -eq $form) { return }',
    'if ($script:MaintenanceResponsiveBusy -or $null -eq $form) { return }',
    'responsividade standalone'
)

# A janela independente ganha um mínimo mais realista para notebook, mantendo
# scroll como fallback onde o conteúdo realmente não puder ser comprimido.
m = one(
    m,
    '$form.MinimumSize = [Drawing.Size]::new(1000, 650)',
    '$form.MinimumSize = [Drawing.Size]::new(880, 600)',
    'minimum standalone'
)

# No standalone, resize e DPI passam a disparar a mesma rotina usada no modo
# integrado. O modo hospedado já tem seu SizeChanged próprio mais abaixo.
old_standalone = '''else {
    $form.Add_FormClosing({ Save-MaintenanceSettings })
    $form.Add_Shown({
        Apply-MaintenanceTheme
        Update-MaintenanceResponsiveLayout
        Reset-PassageForm
        Refresh-AllViews
    })
}'''
new_standalone = '''else {
    $form.Add_FormClosing({ Save-MaintenanceSettings })
    $form.Add_SizeChanged({ Update-MaintenanceResponsiveLayout })
    try { $form.Add_DpiChanged({ Update-MaintenanceResponsiveLayout }) } catch {}
    $form.Add_Shown({
        Apply-MaintenanceTheme
        Update-MaintenanceResponsiveLayout
        Reset-PassageForm
        Refresh-AllViews
    })
}'''
m = one(m, old_standalone, new_standalone, 'eventos standalone')

c += '\n# GERAL2_ETAPA3_MANUTENCAO_V02151\n'
m += '\n# GERAL2_ETAPA3_MANUTENCAO_BASE_V00612\n'

for marker in ('$script:AppVersion = "0.21.51"', '$script:MaintenanceVersion = "0.6.12"', 'GERAL2_ETAPA3_MANUTENCAO_V02151'):
    if marker not in c:
        raise SystemExit('GERAL2/E3D Central marcador ausente: ' + marker)
for marker in ('$script:AppVersion = "0.6.12"', '$form.MinimumSize = [Drawing.Size]::new(880, 600)', 'GERAL2_ETAPA3_MANUTENCAO_BASE_V00612'):
    if marker not in m:
        raise SystemExit('GERAL2/E3D Manutencao marcador ausente: ' + marker)

cp.write_text(c, encoding='utf-8')
mp.write_text(m, encoding='utf-8')
print('GERAL 2 ETAPA 3D: OK - Manutencao v0.6.12 responde a resize/DPI também fora da Central.')
