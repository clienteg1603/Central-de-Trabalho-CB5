from pathlib import Path

cp = Path('src/generated/Central de Trabalho.ps1')
np = Path('src/generated/Modulos/Controle-NF-Entrada/Controle NF Entrada.ps1')
c = cp.read_text(encoding='utf-8-sig')
n = np.read_text(encoding='utf-8-sig')

def r(t, a, b, label):
    if t.count(a) != 1:
        raise SystemExit(f'{label}: marcador inesperado ({t.count(a)})')
    return t.replace(a, b, 1)

c = r(c, '$script:AppVersion = "0.21.43"', '$script:AppVersion = "0.21.44"', 'Central')
c = r(c, '$script:NFEntradaVersion = "2.6.12"', '$script:NFEntradaVersion = "2.6.13"', 'NF Central')
n = r(n, '$script:ModuleVersion = "2.6.12"', '$script:ModuleVersion = "2.6.13"', 'NF modulo')

n = r(n, '    Set-NFRoundedRegion $Button 7', '    Set-NFRoundedRegion $Button 10', 'raio botoes')

n = r(n,
    '$importButton.Margin = if ($script:IsInProcessHosted) { [Windows.Forms.Padding]::new(8, 11, 0, 9) } else { [Windows.Forms.Padding]::new(10, 16, 0, 14) }',
    '$importButton.Margin = if ($script:IsInProcessHosted) { [Windows.Forms.Padding]::new(3, 7, 3, 7) } else { [Windows.Forms.Padding]::new(3, 17, 3, 17) }\n$importButton.Padding = [Windows.Forms.Padding]::new(8, 0, 8, 0)\n$importButton.Font = [Drawing.Font]::new("Segoe UI Semibold", 8.5)',
    'Importar Excel')

n = r(n,
    '$exportButton.Margin = if ($script:IsInProcessHosted) { [Windows.Forms.Padding]::new(8, 11, 0, 9) } else { [Windows.Forms.Padding]::new(10, 16, 0, 14) }',
    '$exportButton.Margin = if ($script:IsInProcessHosted) { [Windows.Forms.Padding]::new(3, 7, 3, 7) } else { [Windows.Forms.Padding]::new(3, 17, 3, 17) }\n$exportButton.Padding = [Windows.Forms.Padding]::new(8, 0, 8, 0)\n$exportButton.Font = [Drawing.Font]::new("Segoe UI Semibold", 8.5)',
    'Excel Oficial')

n = r(n,
    '$nfHeaderActionWidth = if ($script:IsInProcessHosted) { 150 } else { 175 }',
    '$nfHeaderActionWidth = if ($script:IsInProcessHosted) { 158 } else { 175 }',
    'largura cabecalho')

n += '\n# NF_BUTTON_GEOMETRY_MAINTENANCE_STYLE_V02613\n'

if '$mainTabs.Add_SizeChanged' in n or '$mainTabs.Add_HandleCreated' in n or 'OwnerDrawFixed' in n:
    raise SystemExit('abas NF alteradas indevidamente')

cp.write_text(c, encoding='utf-8')
np.write_text(n, encoding='utf-8')
print('NF BUTTON GEOMETRY: OK')
