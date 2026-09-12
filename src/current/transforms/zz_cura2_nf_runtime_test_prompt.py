from pathlib import Path

p = Path('src/generated/Modulos/Controle-NF-Entrada/Controle NF Entrada.ps1')
s = p.read_text(encoding='utf-8-sig')
old = '''$localTemplatePath = Get-NFEntradaTemplatePath -DataDirectory $script:DataDirectory
if (-not [IO.File]::Exists($localTemplatePath)) {'''
new = '''$localTemplatePath = Get-NFEntradaTemplatePath -DataDirectory $script:DataDirectory
# O prompt continua normal em produção. Apenas o autoteste não interativo do runner
# o ignora para poder validar a aparência de uma instalação limpa.
if (-not [IO.File]::Exists($localTemplatePath) -and $env:CENTRAL_THEME_RUNTIME_TEST -ne "1") {'''
if s.count(old) != 1:
    raise SystemExit(f'CURA2 NF prompt: esperado 1, encontrado {s.count(old)}')
s = s.replace(old, new, 1)
p.write_text(s, encoding='utf-8')
print('CURA 2 NF runtime prompt guard — OK')
