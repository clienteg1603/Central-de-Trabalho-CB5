#!/usr/bin/env python3
from pathlib import Path

path = Path('src/generated/Central de Trabalho.ps1')
text = path.read_text(encoding='utf-8-sig')

old_version = '$script:AppVersion = "0.19.2"'
new_version = '$script:AppVersion = "0.19.3"'
if old_version not in text:
    raise SystemExit('Versão-base 0.19.2 não encontrada na Central.')
text = text.replace(old_version, new_version, 1)

anchor = '''Remove-LegacyLauncherArtifact

$script:CurrentPalette = $null'''
insert = '''Remove-LegacyLauncherArtifact

# Mantém a pasta de instalação limpa para o usuário sem remover nenhum arquivo
# necessário ao funcionamento. Os itens internos continuam no mesmo lugar para
# preservar compatibilidade com o host, módulos e Atualizador; apenas recebem o
# atributo Hidden do Windows depois que a Central já iniciou com sucesso.
function Set-InternalRuntimeArtifactsHidden {
    try {
        $internalPaths = @(
            [IO.Path]::Combine($script:RootPath, "Central de Trabalho.ps1"),
            [IO.Path]::Combine($script:RootPath, "PACOTE-MANIFESTO.json"),
            [IO.Path]::Combine($script:RootPath, "Atualizador"),
            [IO.Path]::Combine($script:RootPath, "Modulos")
        )

        foreach ($internalPath in $internalPaths) {
            if ([IO.File]::Exists($internalPath) -or [IO.Directory]::Exists($internalPath)) {
                $attributes = [IO.File]::GetAttributes($internalPath)
                if (($attributes -band [IO.FileAttributes]::Hidden) -eq 0) {
                    [IO.File]::SetAttributes($internalPath, ($attributes -bor [IO.FileAttributes]::Hidden))
                }
            }
        }
    }
    catch {
        # A limpeza visual é auxiliar e nunca deve impedir a Central de abrir.
    }
}
Set-InternalRuntimeArtifactsHidden

$script:CurrentPalette = $null'''

if anchor not in text:
    raise SystemExit('Ponto de inserção da limpeza visual não encontrado.')
text = text.replace(anchor, insert, 1)

required = [
    'function Set-InternalRuntimeArtifactsHidden',
    '[IO.FileAttributes]::Hidden',
    '[IO.Path]::Combine($script:RootPath, "PACOTE-MANIFESTO.json")',
    '[IO.Path]::Combine($script:RootPath, "Atualizador")',
    '[IO.Path]::Combine($script:RootPath, "Modulos")',
]
for marker in required:
    if marker not in text:
        raise SystemExit(f'Contrato de limpeza visual ausente após transformação: {marker}')

path.write_text(text, encoding='utf-8-sig')
print('0.19.3: instalação preparada para mostrar somente o EXE por padrão no Explorador.')
