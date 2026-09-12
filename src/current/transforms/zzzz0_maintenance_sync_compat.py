from pathlib import Path

path = Path('src/generated/Modulos/Central-de-Manutencao-CB5/Central Manutencao CB5.ps1')
text = path.read_text(encoding='utf-8-sig')

old = '''    finally {
        $script:HostedThemeSyncInProgress = $false
    }'''
new = '''    finally {
        $script:HostedThemeSyncInProgress = [bool]$false
    }'''
count = text.count(old)
if count != 1:
    raise SystemExit(f'finally da sincronização de tema: esperado 1 marcador, encontrado {count}')
text = text.replace(old, new, 1)
path.write_text(text, encoding='utf-8')
print('MAINT STARTUP COMPAT: OK - marcador de estado inicial ficou inequívoco.')
