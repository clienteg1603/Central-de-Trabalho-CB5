from pathlib import Path
p = Path('src/generated/Modulos/Controle-NF-Entrada/Controle NF Entrada.ps1')
s = p.read_text(encoding='utf-8-sig')
start = s.find('function Set-HostedNFEntradaTheme {')
if start < 0:
    raise SystemExit('CURA2 boundary: Set-HostedNFEntradaTheme ausente')
marker = '\nif ($script:IsInProcessHosted)'
pos = s.find(marker, start)
if pos < 0:
    raise SystemExit('CURA2 boundary: bloco hospedado final ausente')
insert = '\nfunction Invoke-NFThemeBoundaryMarker { return }\n'
if 'function Invoke-NFThemeBoundaryMarker' not in s:
    s = s[:pos] + insert + s[pos:]
p.write_text(s, encoding='utf-8')
print('CURA2 boundary NF OK')
