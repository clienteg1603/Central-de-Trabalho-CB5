from pathlib import Path

p = Path('src/current/transforms/cura2_theme_coordinator_v028.py')
s = p.read_text(encoding='utf-8-sig')
old = '''s = one(
    s,
    '$script:LastThemeSyncError = ""',
    '$script:LastThemeSyncError = ""\\n$script:CentralThemeCombo = $null\\n$script:CentralThemeChanging = $false',
    'estado do coordenador de tema'
)'''
new = '''s = one(
    s,
    '$script:LastAvailabilitySignature = ""\\n$script:LastThemeSyncError = ""',
    '$script:LastAvailabilitySignature = ""\\n$script:LastThemeSyncError = ""\\n$script:CentralThemeCombo = $null\\n$script:CentralThemeChanging = $false',
    'estado do coordenador de tema'
)'''
if s.count(old) != 1:
    raise SystemExit(f'FIX CURA2: bloco alvo esperado 1, encontrado {s.count(old)}')
p.write_text(s.replace(old, new, 1), encoding='utf-8')
print('FIX CURA2 marcador do coordenador: OK')
