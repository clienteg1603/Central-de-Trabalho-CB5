#!/usr/bin/env python3
from pathlib import Path

central_path = Path("src/generated/Central de Trabalho.ps1")
core_path = Path("src/generated/Atualizador/Update.Core.ps1")

central = central_path.read_text(encoding="utf-8-sig")
core = core_path.read_text(encoding="utf-8-sig")

if '$script:AppVersion = "0.19.4"' not in central:
    raise SystemExit("Central: versão-base 0.19.4 não encontrada")
central = central.replace('$script:AppVersion = "0.19.4"', '$script:AppVersion = "0.19.5"', 1)

old_assert_prefix = '''function Assert-CentralUpdateInstallRoot {
    param([Parameter(Mandatory = $true)][string]$InstallRoot)

    $fullPath = [IO.Path]::GetFullPath($InstallRoot).TrimEnd(
        [IO.Path]::DirectorySeparatorChar,
        [IO.Path]::AltDirectorySeparatorChar
    )
    $driveRoot = [IO.Path]::GetPathRoot($fullPath).TrimEnd(
        [IO.Path]::DirectorySeparatorChar,
        [IO.Path]::AltDirectorySeparatorChar
    )
    if ([string]::IsNullOrWhiteSpace($fullPath) -or $fullPath -eq $driveRoot) {
        throw "A pasta informada não pode ser a raiz de uma unidade."
    }

'''
new_assert_prefix = '''function Resolve-CentralUpdateInstallRootPath {
    param([Parameter(Mandatory = $true)][string]$InstallRoot)

    $fullPath = [IO.Path]::GetFullPath($InstallRoot).TrimEnd(
        [IO.Path]::DirectorySeparatorChar,
        [IO.Path]::AltDirectorySeparatorChar
    )
    $driveRoot = [IO.Path]::GetPathRoot($fullPath).TrimEnd(
        [IO.Path]::DirectorySeparatorChar,
        [IO.Path]::AltDirectorySeparatorChar
    )
    if ([string]::IsNullOrWhiteSpace($fullPath) -or $fullPath -eq $driveRoot) {
        throw "A pasta informada não pode ser a raiz de uma unidade."
    }
    return $fullPath
}

function Assert-CentralUpdateInstallRoot {
    param([Parameter(Mandatory = $true)][string]$InstallRoot)

    $fullPath = Resolve-CentralUpdateInstallRootPath -InstallRoot $InstallRoot

'''
if old_assert_prefix not in core:
    raise SystemExit("Atualizador: início de Assert-CentralUpdateInstallRoot não encontrado")
core = core.replace(old_assert_prefix, new_assert_prefix, 1)

assert_end = '''    return $fullPath
}

function Write-UpdateJsonAtomic {'''
helper_block = '''    return $fullPath
}

function Clear-CentralUpdateBlockingAttributes {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not [IO.File]::Exists($Path) -and -not [IO.Directory]::Exists($Path)) { return }
    $attributes = [IO.File]::GetAttributes($Path)
    $blocking = [IO.FileAttributes]::Hidden -bor [IO.FileAttributes]::ReadOnly -bor [IO.FileAttributes]::System
    $updated = $attributes -band (-bnot $blocking)
    if ($updated -ne $attributes) {
        [IO.File]::SetAttributes($Path, [IO.FileAttributes]$updated)
    }
}

function Write-UpdateJsonAtomic {'''
if assert_end not in core:
    raise SystemExit("Atualizador: fim de Assert-CentralUpdateInstallRoot não encontrado")
core = core.replace(assert_end, helper_block, 1)

old_copy = '''        if (-not [IO.Directory]::Exists($parent)) { [void][IO.Directory]::CreateDirectory($parent) }
        [IO.File]::Copy($file, $target, $true)'''
new_copy = '''        if (-not [IO.Directory]::Exists($parent)) { [void][IO.Directory]::CreateDirectory($parent) }
        if ([IO.File]::Exists($target)) { Clear-CentralUpdateBlockingAttributes -Path $target }
        [IO.File]::Copy($file, $target, $true)'''
if old_copy not in core:
    raise SystemExit("Atualizador: cópia de diretório não encontrada")
core = core.replace(old_copy, new_copy, 1)

old_remove_file = '''            $path = Resolve-SafeUpdateChildPath -Root $InstallRoot -RelativePath $relative
            if ([IO.File]::Exists($path)) { [IO.File]::Delete($path) }'''
new_remove_file = '''            $path = Resolve-SafeUpdateChildPath -Root $InstallRoot -RelativePath $relative
            if ([IO.File]::Exists($path)) {
                Clear-CentralUpdateBlockingAttributes -Path $path
                [IO.File]::Delete($path)
            }'''
if old_remove_file not in core:
    raise SystemExit("Atualizador: remoção de arquivo gerenciado não encontrada")
core = core.replace(old_remove_file, new_remove_file, 1)

old_remove_manifest = '''    if ([IO.File]::Exists($manifestPath)) { [IO.File]::Delete($manifestPath) }
}

function Restore-CentralUpdateBackup'''
new_remove_manifest = '''    if ([IO.File]::Exists($manifestPath)) {
        Clear-CentralUpdateBlockingAttributes -Path $manifestPath
        [IO.File]::Delete($manifestPath)
    }
}

function Restore-CentralUpdateBackup'''
if old_remove_manifest not in core:
    raise SystemExit("Atualizador: remoção do manifesto não encontrada")
core = core.replace(old_remove_manifest, new_remove_manifest, 1)

restore_marker = '''function Restore-CentralUpdateBackup {
    param(
        [Parameter(Mandatory = $true)][object]$Backup,
        [Parameter(Mandatory = $true)][string]$InstallRoot,
        [switch]$RestoreData
    )

    $InstallRoot = Assert-CentralUpdateInstallRoot -InstallRoot $InstallRoot'''
restore_fixed = restore_marker.replace(
    '$InstallRoot = Assert-CentralUpdateInstallRoot -InstallRoot $InstallRoot',
    '$InstallRoot = Resolve-CentralUpdateInstallRootPath -InstallRoot $InstallRoot'
)
if restore_marker not in core:
    raise SystemExit("Atualizador: validação do Restore não encontrada")
core = core.replace(restore_marker, restore_fixed, 1)

old_install_copy = '''            $parent = [IO.Path]::GetDirectoryName($destination)
            if (-not [IO.Directory]::Exists($parent)) { [void][IO.Directory]::CreateDirectory($parent) }
            [IO.File]::Copy($source, $destination, $true)
        }
        [IO.File]::Copy(
            ([IO.Path]::Combine($PayloadRoot, "PACOTE-MANIFESTO.json")),
            ([IO.Path]::Combine($InstallRoot, "PACOTE-MANIFESTO.json")),
            $true
        )'''
new_install_copy = '''            $parent = [IO.Path]::GetDirectoryName($destination)
            if (-not [IO.Directory]::Exists($parent)) { [void][IO.Directory]::CreateDirectory($parent) }
            if ([IO.File]::Exists($destination)) { Clear-CentralUpdateBlockingAttributes -Path $destination }
            [IO.File]::Copy($source, $destination, $true)
        }
        $packageManifestDestination = [IO.Path]::Combine($InstallRoot, "PACOTE-MANIFESTO.json")
        if ([IO.File]::Exists($packageManifestDestination)) {
            Clear-CentralUpdateBlockingAttributes -Path $packageManifestDestination
        }
        [IO.File]::Copy(
            ([IO.Path]::Combine($PayloadRoot, "PACOTE-MANIFESTO.json")),
            $packageManifestDestination,
            $true
        )'''
if old_install_copy not in core:
    raise SystemExit("Atualizador: bloco de instalação não encontrado")
core = core.replace(old_install_copy, new_install_copy, 1)

old_oldpath_delete = '''                $oldPath = Resolve-SafeUpdateChildPath -Root $InstallRoot -RelativePath $relative
                if ([IO.File]::Exists($oldPath)) { [IO.File]::Delete($oldPath) }'''
new_oldpath_delete = '''                $oldPath = Resolve-SafeUpdateChildPath -Root $InstallRoot -RelativePath $relative
                if ([IO.File]::Exists($oldPath)) {
                    Clear-CentralUpdateBlockingAttributes -Path $oldPath
                    [IO.File]::Delete($oldPath)
                }'''
if old_oldpath_delete not in core:
    raise SystemExit("Atualizador: limpeza de arquivos antigos não encontrada")
core = core.replace(old_oldpath_delete, new_oldpath_delete, 1)

old_catch = '''    catch {
        foreach ($file in @($newManifest.Files)) {
            try {
                $newPath = Resolve-SafeUpdateChildPath -Root $InstallRoot -RelativePath (ConvertTo-UpdateText $file.Path)
                if ([IO.File]::Exists($newPath)) { [IO.File]::Delete($newPath) }
            }
            catch {}
        }
        try { [void](Restore-CentralUpdateBackup -Backup $backup -InstallRoot $InstallRoot -RestoreData) }
        catch {}
        throw
    }
}'''
new_catch = '''    catch {
        $originalError = $_
        foreach ($file in @($newManifest.Files)) {
            try {
                $newPath = Resolve-SafeUpdateChildPath -Root $InstallRoot -RelativePath (ConvertTo-UpdateText $file.Path)
                if ([IO.File]::Exists($newPath)) {
                    Clear-CentralUpdateBlockingAttributes -Path $newPath
                    [IO.File]::Delete($newPath)
                }
            }
            catch {}
        }

        $rollbackError = $null
        try { [void](Restore-CentralUpdateBackup -Backup $backup -InstallRoot $InstallRoot -RestoreData) }
        catch { $rollbackError = $_ }

        if ($null -ne $rollbackError) {
            throw "A atualização falhou: $($originalError.Exception.Message) Falha adicional ao restaurar o backup: $($rollbackError.Exception.Message)"
        }
        throw $originalError
    }
}'''
if old_catch not in core:
    raise SystemExit("Atualizador: bloco de rollback não encontrado")
core = core.replace(old_catch, new_catch, 1)

required_markers = [
    'function Resolve-CentralUpdateInstallRootPath',
    'function Clear-CentralUpdateBlockingAttributes',
    'Clear-CentralUpdateBlockingAttributes -Path $destination',
    '$InstallRoot = Resolve-CentralUpdateInstallRootPath -InstallRoot $InstallRoot',
    '$originalError = $_',
    '$rollbackError = $null',
]
for marker in required_markers:
    if marker not in core:
        raise SystemExit(f"Atualizador: marcador final ausente: {marker}")

central_path.write_text(central, encoding="utf-8-sig")
core_path.write_text(core, encoding="utf-8-sig")
print("0.19.5: corrige atualização sobre arquivos ocultos e torna rollback recuperável.")
