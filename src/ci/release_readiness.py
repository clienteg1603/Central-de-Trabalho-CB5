#!/usr/bin/env python3
import hashlib
import json
import pathlib
import sys
import zipfile

APP_ID = "central-de-trabalho"
EXPECTED_RUNTIME_FILES = {
    "Central de Trabalho.exe",
    "Central de Trabalho.ps1",
    "Atualizador/CANAIS.json",
    "Atualizador/Central de Trabalho Updater.exe",
    "Atualizador/Central de Trabalho Updater.ps1",
    "Atualizador/Update.Core.ps1",
    "Modulos/Central-de-Manutencao-CB5/Central Manutencao CB5.ps1",
    "Modulos/Central-de-Manutencao-CB5/Manutencao.Core.ps1",
    "Modulos/Gerador-de-Planilhas-CB5-TV5/Gerador Planilhas.ps1",
    "Modulos/Gerador-de-Planilhas-CB5-TV5/Componentes.Core.ps1",
}
FORBIDDEN_SUFFIXES = (".vbs", ".bat", ".cmd", ".pyc", ".log")
FORBIDDEN_PARTS = ("__pycache__", "erro-inicializacao", "componentes-a-faturar", "preferencias.json")


def load_json(path):
    return json.loads(path.read_text(encoding="utf-8-sig"))


def version_tuple(text):
    parts = str(text).strip().split(".")
    if not parts or any(not p.isdigit() for p in parts):
        raise ValueError(f"versão inválida: {text!r}")
    return tuple(int(p) for p in parts)


def package_path_from_channel(channel, root):
    version = channel["Version"]
    expected_name = f"Central-de-Trabalho-v{version}.zip"
    url = str(channel.get("PackageUrl", ""))
    if not url.endswith("/" + expected_name):
        raise ValueError(f"PackageUrl não termina em {expected_name}")
    return root / "updates" / "packages" / expected_name


def validate_channel(channel, expected_channel):
    errors = []
    if channel.get("SchemaVersion") != 1:
        errors.append(f"{expected_channel}: SchemaVersion deve ser 1")
    if channel.get("AppId") != APP_ID:
        errors.append(f"{expected_channel}: AppId divergente")
    if channel.get("Channel") != expected_channel:
        errors.append(f"{expected_channel}: campo Channel divergente")
    if not channel.get("Version"):
        errors.append(f"{expected_channel}: Version ausente")
    if not channel.get("PackageSha256"):
        errors.append(f"{expected_channel}: PackageSha256 ausente")
    if not isinstance(channel.get("PackageSize"), int) or channel.get("PackageSize", 0) <= 0:
        errors.append(f"{expected_channel}: PackageSize inválido")
    return errors


def validate_package(root, channel, label, strict_layout):
    errors = []
    version = channel.get("Version")
    try:
        package_path = package_path_from_channel(channel, root)
    except Exception as exc:
        return [f"{label}: {exc}"]

    if not package_path.is_file():
        return [f"{label}: pacote não encontrado no repositório: {package_path}"]

    data = package_path.read_bytes()
    actual_sha = hashlib.sha256(data).hexdigest().upper()
    if actual_sha != str(channel.get("PackageSha256", "")).upper():
        errors.append(f"{label}: SHA-256 do pacote não confere")
    if len(data) != int(channel.get("PackageSize", -1)):
        errors.append(f"{label}: tamanho do pacote não confere")

    expected_root = f"Central-de-Trabalho-v{version}"
    if channel.get("PackageRoot") != expected_root:
        errors.append(f"{label}: PackageRoot divergente")

    try:
        with zipfile.ZipFile(package_path, "r") as zf:
            bad = zf.testzip()
            if bad is not None:
                errors.append(f"{label}: CRC inválido em {bad}")

            file_names = [n.rstrip("/") for n in zf.namelist() if not n.endswith("/")]
            prefix = expected_root + "/"
            if any(not n.startswith(prefix) for n in file_names):
                errors.append(f"{label}: ZIP contém arquivo fora da raiz esperada")

            if not strict_layout:
                return errors

            rel_files = {n[len(prefix):].replace("\\", "/") for n in file_names if n.startswith(prefix)}
            expected_all = EXPECTED_RUNTIME_FILES | {"PACOTE-MANIFESTO.json"}
            missing = sorted(expected_all - rel_files)
            extras = sorted(rel_files - expected_all)
            if missing:
                errors.append(f"{label}: arquivos ausentes no ZIP: {', '.join(missing)}")
            if extras:
                errors.append(f"{label}: arquivos inesperados no ZIP: {', '.join(extras)}")

            for rel in sorted(rel_files):
                low = rel.lower()
                if low.endswith(FORBIDDEN_SUFFIXES) or any(part in low for part in FORBIDDEN_PARTS):
                    errors.append(f"{label}: arquivo proibido na distribuição: {rel}")

            manifest_name = prefix + "PACOTE-MANIFESTO.json"
            if manifest_name in file_names:
                manifest = json.loads(zf.read(manifest_name).decode("utf-8-sig"))
                if manifest.get("SchemaVersion") != 1:
                    errors.append(f"{label}: manifesto com SchemaVersion inválido")
                if manifest.get("AppId") != APP_ID:
                    errors.append(f"{label}: manifesto com AppId divergente")
                if manifest.get("Version") != version:
                    errors.append(f"{label}: manifesto com versão divergente")

                manifest_files = {str(item.get("Path", "")).replace("\\", "/") for item in manifest.get("Files", [])}
                if manifest_files != EXPECTED_RUNTIME_FILES:
                    errors.append(f"{label}: lista de arquivos do manifesto diverge do runtime esperado")

                for item in manifest.get("Files", []):
                    rel = str(item.get("Path", "")).replace("\\", "/")
                    zip_name = prefix + rel
                    if zip_name not in file_names:
                        continue
                    payload = zf.read(zip_name)
                    if len(payload) != int(item.get("Size", -1)):
                        errors.append(f"{label}: tamanho divergente no manifesto: {rel}")
                    item_sha = hashlib.sha256(payload).hexdigest().upper()
                    if item_sha != str(item.get("Sha256", "")).upper():
                        errors.append(f"{label}: SHA divergente no manifesto: {rel}")
    except zipfile.BadZipFile:
        errors.append(f"{label}: pacote não é ZIP válido")
    except Exception as exc:
        errors.append(f"{label}: falha ao validar ZIP: {exc}")

    return errors


def main():
    root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
    test_path = root / "updates" / "test.json"
    stable_path = root / "updates" / "stable.json"
    version_path = root / "src" / "current" / "version.json"

    errors = []
    for path in (test_path, stable_path, version_path):
        if not path.is_file():
            errors.append(f"arquivo obrigatório ausente: {path.relative_to(root)}")
    if errors:
        raise SystemExit("\n".join(errors))

    test = load_json(test_path)
    stable = load_json(stable_path)
    current = load_json(version_path)

    errors.extend(validate_channel(test, "test"))
    errors.extend(validate_channel(stable, "stable"))

    same_release = False
    try:
        test_version = version_tuple(test["Version"])
        stable_version = version_tuple(stable["Version"])
        if test_version < stable_version:
            errors.append(f"o canal Teste ({test['Version']}) não pode ficar atrás da Estável ({stable['Version']})")
        same_release = test_version == stable_version
    except Exception as exc:
        errors.append(str(exc))

    if current.get("version") != test.get("Version"):
        errors.append(f"src/current/version.json ({current.get('version')}) diverge do canal Teste ({test.get('Version')})")

    # A candidata sempre obedece ao layout atual completo. Uma Estável antiga pode ter
    # arquitetura legada; quando Teste e Estável apontam para a mesma release promovida,
    # a Estável passa a ser validada também com o layout atual completo.
    errors.extend(validate_package(root, test, "Teste", strict_layout=True))
    errors.extend(validate_package(root, stable, "Estável atual", strict_layout=same_release))

    if errors:
        print("RELEASE READINESS: FALHOU")
        for error in errors:
            print("  - " + error)
        raise SystemExit(1)

    print("RELEASE READINESS: OK")
    print(f"  Teste: v{test['Version']}")
    print(f"  Estável: v{stable['Version']}")
    if same_release:
        print("  Estado pós-promoção confirmado: Teste e Estável apontam para a mesma release validada.")
        print("  Pacote, hashes, manifesto e lista de arquivos da Estável atual estão consistentes com o layout moderno.")
    else:
        print("  Candidata, pacote, hashes, manifesto e lista de arquivos estão consistentes.")
        print("  A Estável atual foi preservada e conferida sem exigir o layout novo.")
        print("  Nenhuma promoção foi executada; a mudança do canal Estável continua dependendo de aprovação explícita.")


if __name__ == "__main__":
    main()
