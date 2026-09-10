#!/usr/bin/env python3
from pathlib import Path

central_path = Path('src/generated/Central de Trabalho.ps1')
central = central_path.read_text(encoding='utf-8-sig')

old_version = '$script:AppVersion = "0.18.2"'
new_version = '$script:AppVersion = "0.19.0"'
if old_version not in central:
    raise SystemExit('Central: versão-base 0.18.2 não encontrada.')
central = central.replace(old_version, new_version, 1)

anchor = '''$script:SettingsPath = [IO.Path]::Combine($script:SettingsDirectory, "preferencias.json")
$script:CurrentPalette = $null'''
replacement = '''$script:SettingsPath = [IO.Path]::Combine($script:SettingsDirectory, "preferencias.json")

# Desde a linha 0.17.x a Central possui um host Windows gráfico próprio. O VBS antigo
# deixou de participar da inicialização e é removido somente depois que a nova Central
# já conseguiu iniciar, evitando apagar o fallback antes de uma atualização concluída.
function Remove-LegacyLauncherArtifact {
    try {
        $legacyLauncher = [IO.Path]::Combine($script:RootPath, "ABRIR CENTRAL DE TRABALHO.vbs")
        if ([IO.File]::Exists($legacyLauncher)) {
            [IO.File]::Delete($legacyLauncher)
        }
    }
    catch {
        # A limpeza é auxiliar e nunca deve impedir a Central de abrir.
    }
}
Remove-LegacyLauncherArtifact

$script:CurrentPalette = $null'''
if anchor not in central:
    raise SystemExit('Central: ponto de inserção para limpeza do VBS não encontrado.')
central = central.replace(anchor, replacement, 1)

central_path.write_text(central, encoding='utf-8-sig')
print('0.19.0: VBS legado removido da distribuição e limpo de instalações atualizadas após inicialização bem-sucedida.')
