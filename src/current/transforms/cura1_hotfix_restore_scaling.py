from pathlib import Path

R = Path('src/generated')

def load(p):
    return p.read_text(encoding='utf-8-sig')

def save(p, s):
    p.write_text(s, encoding='utf-8')

def one(s, old, new, name):
    n = s.count(old)
    if n != 1:
        raise SystemExit(f'HOTFIX CURA1 {name}: esperado 1, encontrado {n}')
    return s.replace(old, new, 1)

# Central: restaura o comportamento de escala conhecido como estável antes da CURA 1.
p = R / 'Central de Trabalho.ps1'
s = load(p)
s = one(s, '$script:AppVersion = "0.21.22"', '$script:AppVersion = "0.21.23"', 'versao central')
s = one(s, '$script:GeneratorVersion = "3.7.4"', '$script:GeneratorVersion = "3.7.5"', 'versao gerador')
s = one(s, '$script:MaintenanceVersion = "0.6.3"', '$script:MaintenanceVersion = "0.6.4"', 'versao manutencao')
s = one(s, '$script:NFEntradaVersion = "2.6.2"', '$script:NFEntradaVersion = "2.6.3"', 'versao nf')
s = one(s,
    '$form.AutoScaleDimensions = [Drawing.SizeF]::new(96.0, 96.0)\n$form.AutoScaleMode = [Windows.Forms.AutoScaleMode]::Dpi\n$form.Font = [Drawing.Font]::new("Segoe UI", 9.5)',
    '$form.AutoScaleMode = [Windows.Forms.AutoScaleMode]::Dpi\n$form.Font = [Drawing.Font]::new("Segoe UI", 9.5)',
    'escala central')
save(p, s)

# Manutencao: no modo hospedado volta a usar as coordenadas finais entregues pela Central.
p = R / 'Modulos/Central-de-Manutencao-CB5/Central Manutencao CB5.ps1'
s = load(p)
s = one(s, '$script:AppVersion = "0.6.3"', '$script:AppVersion = "0.6.4"', 'versao manutencao modulo')
s = one(s,
    '    $form.Name = "MaintenanceHostedControl"\n    $form.AutoScaleDimensions = [Drawing.SizeF]::new(96.0, 96.0)\n    $form.AutoScaleMode = [Windows.Forms.AutoScaleMode]::Dpi\n    $form.Font = [Drawing.Font]::new("Segoe UI", 9.0)',
    '    $form.Name = "MaintenanceHostedControl"\n    $form.AutoScaleMode = [Windows.Forms.AutoScaleMode]::None\n    $form.Font = [Drawing.Font]::new("Segoe UI", 9.0)',
    'escala manutencao hospedada')
s = one(s,
    '    # CURA 1: perfis responsivos usam sempre a mesma base lógica de 96 DPI.\n    $logicalW = [int][Math]::Round($w * 96.0 / $dpi)\n    $logicalH = [int][Math]::Round($h * 96.0 / $dpi)\n',
    '    # Em modo hospedado as coordenadas já são as coordenadas finais do controle\n    # dentro da Central; dividir novamente pelo DPI fazia o módulo acreditar que\n    # tinha menos espaço e, pior, mascarava o fato de o Form antigo estar maior\n    # do que seu painel pai.\n    $logicalW = if ($script:IsInProcessHosted) { $w } else { [int][Math]::Round($w * 96.0 / $dpi) }\n    $logicalH = if ($script:IsInProcessHosted) { $h } else { [int][Math]::Round($h * 96.0 / $dpi) }\n',
    'viewport manutencao')
save(p, s)

# Gerenciador: o viewport hospedado já preservava as coordenadas finais; restaura apenas o AutoScale.
p = R / 'Modulos/Gerador-de-Planilhas-CB5-TV5/Gerador Planilhas.ps1'
s = load(p)
s = one(s, '$script:AppVersion = "3.7.4"', '$script:AppVersion = "3.7.5"', 'versao gerenciador modulo')
s = one(s,
    '    $form.Name = "GeneratorHostedControl"\n    $form.AutoScaleDimensions = New-Object Drawing.SizeF(96, 96)\n    $form.AutoScaleMode = [Windows.Forms.AutoScaleMode]::Dpi',
    '    $form.Name = "GeneratorHostedControl"\n    $form.AutoScaleMode = [Windows.Forms.AutoScaleMode]::None\n    $form.AutoScaleDimensions = New-Object Drawing.SizeF(96, 96)',
    'escala gerenciador hospedado')
if 'LogicalWidth=if ($script:IsInProcessHosted) { $w } else { [int][Math]::Round($w*96.0/$dpi) }' not in s:
    raise SystemExit('HOTFIX CURA1: viewport hospedado do Gerenciador não está no contrato esperado')
save(p, s)

# NF Entrada: UserControl hospedado volta a deixar a escala sob responsabilidade da Central.
p = R / 'Modulos/Controle-NF-Entrada/Controle NF Entrada.ps1'
s = load(p)
s = one(s, '$script:ModuleVersion = "2.6.2"', '$script:ModuleVersion = "2.6.3"', 'versao nf modulo')
s = one(s,
    '    $form = New-Object Windows.Forms.UserControl\n    $form.Name = "NFEntradaHostedControl"\n    $form.AutoScaleDimensions = [Drawing.SizeF]::new(96.0, 96.0)\n    $form.AutoScaleMode = [Windows.Forms.AutoScaleMode]::Dpi\n    $form.Dock = [Windows.Forms.DockStyle]::Fill',
    '    $form = New-Object Windows.Forms.UserControl\n    $form.Name = "NFEntradaHostedControl"\n    $form.Dock = [Windows.Forms.DockStyle]::Fill',
    'escala nf hospedado')
s = one(s,
    '    $form.Text = "Controle de NF de Entrada"\n    $form.StartPosition = [Windows.Forms.FormStartPosition]::CenterScreen\n    $form.AutoScaleDimensions = [Drawing.SizeF]::new(96.0, 96.0)\n    $form.AutoScaleMode = [Windows.Forms.AutoScaleMode]::Dpi\n    $form.MinimumSize = [Drawing.Size]::new(980, 680)',
    '    $form.Text = "Controle de NF de Entrada"\n    $form.StartPosition = [Windows.Forms.FormStartPosition]::CenterScreen\n    $form.MinimumSize = [Drawing.Size]::new(980, 680)',
    'escala nf janela')
save(p, s)

# Atualizador: restaura o baseline anterior desta fase.
p = R / 'Atualizador/Central de Trabalho Updater.ps1'
s = load(p)
s = one(s,
    '$form.AutoScaleDimensions = [Drawing.SizeF]::new(96.0, 96.0)\n$form.AutoScaleMode = [Windows.Forms.AutoScaleMode]::Dpi\n$form.Font = [Drawing.Font]::new("Segoe UI", 9.5)',
    '$form.AutoScaleMode = [Windows.Forms.AutoScaleMode]::Dpi\n$form.Font = [Drawing.Font]::new("Segoe UI", 9.5)',
    'escala atualizador')
save(p, s)

# Contratos da correção: nenhum módulo hospedado deve voltar a fazer dupla escala nesta revisão.
checks = {
    R / 'Central de Trabalho.ps1': ['0.21.23'],
    R / 'Modulos/Central-de-Manutencao-CB5/Central Manutencao CB5.ps1': ['0.6.4', 'MaintenanceHostedControl', 'AutoScaleMode = [Windows.Forms.AutoScaleMode]::None'],
    R / 'Modulos/Gerador-de-Planilhas-CB5-TV5/Gerador Planilhas.ps1': ['3.7.5', 'GeneratorHostedControl', 'AutoScaleMode = [Windows.Forms.AutoScaleMode]::None'],
    R / 'Modulos/Controle-NF-Entrada/Controle NF Entrada.ps1': ['2.6.3', 'NFEntradaHostedControl'],
}
for path, marks in checks.items():
    text = load(path)
    for mark in marks:
        if mark not in text:
            raise SystemExit(f'HOTFIX CURA1 contrato ausente: {path} :: {mark}')

print('HOTFIX CURA 1 OK: escala anterior restaurada sem alterar regras; Central 0.21.23 / Manutencao 0.6.4 / Gerenciador 3.7.5 / NF 2.6.3')
