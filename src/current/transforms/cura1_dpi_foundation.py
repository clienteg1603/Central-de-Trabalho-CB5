from pathlib import Path

R = Path('src/generated')

def load(p):
    return p.read_text(encoding='utf-8-sig')

def save(p, s):
    p.write_text(s, encoding='utf-8')

def one(s, old, new, name):
    n = s.count(old)
    if n != 1:
        raise SystemExit(f'CURA1 {name}: esperado 1, encontrado {n}')
    return s.replace(old, new, 1)

# Central
p = R / 'Central de Trabalho.ps1'
s = load(p)
s = one(s, '$script:AppVersion = "0.21.21"', '$script:AppVersion = "0.21.22"', 'versao central')
s = one(s, '$script:GeneratorVersion = "3.7.3"', '$script:GeneratorVersion = "3.7.4"', 'versao gerador')
s = one(s, '$script:MaintenanceVersion = "0.6.2"', '$script:MaintenanceVersion = "0.6.3"', 'versao manutencao')
s = one(s, '$script:NFEntradaVersion = "2.6.1"', '$script:NFEntradaVersion = "2.6.2"', 'versao nf')
s = one(s,
    '$form.AutoScaleMode = [Windows.Forms.AutoScaleMode]::Dpi\n$form.Font = [Drawing.Font]::new("Segoe UI", 9.5)',
    '$form.AutoScaleDimensions = [Drawing.SizeF]::new(96.0, 96.0)\n$form.AutoScaleMode = [Windows.Forms.AutoScaleMode]::Dpi\n$form.Font = [Drawing.Font]::new("Segoe UI", 9.5)',
    'dpi central')
save(p, s)

# Manutencao
p = R / 'Modulos/Central-de-Manutencao-CB5/Central Manutencao CB5.ps1'
s = load(p)
s = one(s, '$script:AppVersion = "0.6.2"', '$script:AppVersion = "0.6.3"', 'versao manutencao modulo')
s = one(s,
    '    $form.Name = "MaintenanceHostedControl"\n    $form.AutoScaleMode = [Windows.Forms.AutoScaleMode]::None\n    $form.Font = [Drawing.Font]::new("Segoe UI", 9.0)',
    '    $form.Name = "MaintenanceHostedControl"\n    $form.AutoScaleDimensions = [Drawing.SizeF]::new(96.0, 96.0)\n    $form.AutoScaleMode = [Windows.Forms.AutoScaleMode]::Dpi\n    $form.Font = [Drawing.Font]::new("Segoe UI", 9.0)',
    'dpi manutencao hospedada')
old = '''    # Em modo hospedado as coordenadas já são as coordenadas finais do controle
    # dentro da Central; dividir novamente pelo DPI fazia o módulo acreditar que
    # tinha menos espaço e, pior, mascarava o fato de o Form antigo estar maior
    # do que seu painel pai.
    $logicalW = if ($script:IsInProcessHosted) { $w } else { [int][Math]::Round($w * 96.0 / $dpi) }
    $logicalH = if ($script:IsInProcessHosted) { $h } else { [int][Math]::Round($h * 96.0 / $dpi) }
'''
new = '''    # CURA 1: perfis responsivos usam sempre a mesma base lógica de 96 DPI.
    $logicalW = [int][Math]::Round($w * 96.0 / $dpi)
    $logicalH = [int][Math]::Round($h * 96.0 / $dpi)
'''
s = one(s, old, new, 'viewport manutencao')
save(p, s)

# Gerenciador
p = R / 'Modulos/Gerador-de-Planilhas-CB5-TV5/Gerador Planilhas.ps1'
s = load(p)
s = one(s, '$script:AppVersion = "3.7.3"', '$script:AppVersion = "3.7.4"', 'versao gerenciador modulo')
s = one(s,
    '    $form.Name = "GeneratorHostedControl"\n    $form.AutoScaleMode = [Windows.Forms.AutoScaleMode]::None\n    $form.AutoScaleDimensions = New-Object Drawing.SizeF(96, 96)',
    '    $form.Name = "GeneratorHostedControl"\n    $form.AutoScaleDimensions = New-Object Drawing.SizeF(96, 96)\n    $form.AutoScaleMode = [Windows.Forms.AutoScaleMode]::Dpi',
    'dpi gerenciador hospedado')
s = s.replace('$logicalW = if ($script:IsInProcessHosted) { $w } else { [int][Math]::Round($w * 96.0 / $dpi) }', '$logicalW = [int][Math]::Round($w * 96.0 / $dpi)')
s = s.replace('$logicalH = if ($script:IsInProcessHosted) { $h } else { [int][Math]::Round($h * 96.0 / $dpi) }', '$logicalH = [int][Math]::Round($h * 96.0 / $dpi)')
save(p, s)

# NF Entrada
p = R / 'Modulos/Controle-NF-Entrada/Controle NF Entrada.ps1'
s = load(p)
s = one(s, '$script:ModuleVersion = "2.6.1"', '$script:ModuleVersion = "2.6.2"', 'versao nf modulo')
s = one(s,
    '    $form = New-Object Windows.Forms.UserControl\n    $form.Name = "NFEntradaHostedControl"\n    $form.Dock = [Windows.Forms.DockStyle]::Fill',
    '    $form = New-Object Windows.Forms.UserControl\n    $form.Name = "NFEntradaHostedControl"\n    $form.AutoScaleDimensions = [Drawing.SizeF]::new(96.0, 96.0)\n    $form.AutoScaleMode = [Windows.Forms.AutoScaleMode]::Dpi\n    $form.Dock = [Windows.Forms.DockStyle]::Fill',
    'dpi nf hospedado')
s = one(s,
    '    $form.Text = "Controle de NF de Entrada"\n    $form.StartPosition = [Windows.Forms.FormStartPosition]::CenterScreen\n    $form.MinimumSize = [Drawing.Size]::new(980, 680)',
    '    $form.Text = "Controle de NF de Entrada"\n    $form.StartPosition = [Windows.Forms.FormStartPosition]::CenterScreen\n    $form.AutoScaleDimensions = [Drawing.SizeF]::new(96.0, 96.0)\n    $form.AutoScaleMode = [Windows.Forms.AutoScaleMode]::Dpi\n    $form.MinimumSize = [Drawing.Size]::new(980, 680)',
    'dpi nf janela')
save(p, s)

# Atualizador WinForms
p = R / 'Atualizador/Central de Trabalho Updater.ps1'
s = load(p)
s = one(s,
    '$form.AutoScaleMode = [Windows.Forms.AutoScaleMode]::Dpi\n$form.Font = [Drawing.Font]::new("Segoe UI", 9.5)',
    '$form.AutoScaleDimensions = [Drawing.SizeF]::new(96.0, 96.0)\n$form.AutoScaleMode = [Windows.Forms.AutoScaleMode]::Dpi\n$form.Font = [Drawing.Font]::new("Segoe UI", 9.5)',
    'dpi atualizador')
save(p, s)

# Falha o build se a fundacao desaparecer.
required = {
    R / 'Central de Trabalho.ps1': ['0.21.22', 'AutoScaleDimensions = [Drawing.SizeF]::new(96.0, 96.0)'],
    R / 'Modulos/Central-de-Manutencao-CB5/Central Manutencao CB5.ps1': ['0.6.3', 'MaintenanceHostedControl', '$logicalW = [int][Math]::Round($w * 96.0 / $dpi)'],
    R / 'Modulos/Gerador-de-Planilhas-CB5-TV5/Gerador Planilhas.ps1': ['3.7.4', 'GeneratorHostedControl', 'AutoScaleMode = [Windows.Forms.AutoScaleMode]::Dpi'],
    R / 'Modulos/Controle-NF-Entrada/Controle NF Entrada.ps1': ['2.6.2', 'NFEntradaHostedControl', 'AutoScaleMode = [Windows.Forms.AutoScaleMode]::Dpi'],
}
for path, marks in required.items():
    text = load(path)
    for mark in marks:
        if mark not in text:
            raise SystemExit(f'CURA1 contrato ausente: {path} :: {mark}')

print('CURA 1 OK: baseline 96 DPI unificado; Central 0.21.22 / Manutencao 0.6.3 / Gerenciador 3.7.4 / NF 2.6.2')
