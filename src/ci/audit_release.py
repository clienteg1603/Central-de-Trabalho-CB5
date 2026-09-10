#!/usr/bin/env python3
import hashlib
import json
import pathlib
import re
import sys
import zipfile

EXPECTED_FILES = {
    "ABRIR CENTRAL DE TRABALHO.vbs",
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


def fail(errors):
    if not errors:
        return
    print("\nAUDITORIA DE RELEASE: FALHOU")
    for error in errors:
        print(f"  - {error}")
    raise SystemExit(1)


def read_text(path):
    return path.read_text(encoding="utf-8-sig", errors="strict")


def extract_version(text, variable):
    match = re.search(rf'\$script:{re.escape(variable)}\s*=\s*"([^"]+)"', text)
    return match.group(1) if match else None


def audit_tree(root, version):
    errors = []
    if not root.is_dir():
        fail([f"pasta do pacote não existe: {root}"])

    actual = {
        p.relative_to(root).as_posix()
        for p in root.rglob("*")
        if p.is_file() and p.name != "PACOTE-MANIFESTO.json"
    }
    missing = sorted(EXPECTED_FILES - actual)
    extras = sorted(actual - EXPECTED_FILES)
    if missing:
        errors.append("arquivos obrigatórios ausentes: " + ", ".join(missing))
    if extras:
        errors.append("arquivos inesperados no pacote limpo: " + ", ".join(extras))

    for rel in sorted(EXPECTED_FILES & actual):
        path = root / rel
        if path.stat().st_size <= 0:
            errors.append(f"arquivo vazio: {rel}")

    central_path = root / "Central de Trabalho.ps1"
    generator_path = root / "Modulos/Gerador-de-Planilhas-CB5-TV5/Gerador Planilhas.ps1"
    generator_core_path = root / "Modulos/Gerador-de-Planilhas-CB5-TV5/Componentes.Core.ps1"
    maintenance_path = root / "Modulos/Central-de-Manutencao-CB5/Central Manutencao CB5.ps1"
    maintenance_core_path = root / "Modulos/Central-de-Manutencao-CB5/Manutencao.Core.ps1"
    updater_path = root / "Atualizador/Central de Trabalho Updater.ps1"
    updater_core_path = root / "Atualizador/Update.Core.ps1"
    channels_path = root / "Atualizador/CANAIS.json"

    if all(p.exists() for p in (central_path, generator_path, generator_core_path, maintenance_path, maintenance_core_path, updater_path, updater_core_path, channels_path)):
        central = read_text(central_path)
        generator = read_text(generator_path)
        generator_core = read_text(generator_core_path)
        maintenance = read_text(maintenance_path)
        maintenance_core = read_text(maintenance_core_path)
        updater = read_text(updater_path)
        updater_core = read_text(updater_core_path)

        central_version = extract_version(central, "AppVersion")
        generator_declared = extract_version(central, "GeneratorVersion")
        maintenance_declared = extract_version(central, "MaintenanceVersion")
        generator_version = extract_version(generator, "AppVersion")
        maintenance_version = extract_version(maintenance, "AppVersion")

        if central_version != version:
            errors.append(f"versão da Central divergente: script={central_version!r}, release={version!r}")
        if not generator_declared or generator_declared != generator_version:
            errors.append(f"versão do Gerenciador divergente: Central={generator_declared!r}, módulo={generator_version!r}")
        if not maintenance_declared or maintenance_declared != maintenance_version:
            errors.append(f"versão da Manutenção divergente: Central={maintenance_declared!r}, módulo={maintenance_version!r}")

        # Integração: ambos os módulos precisam continuar exportando um Control hospedável.
        for name, text in (("Gerenciador", generator), ("Manutenção", maintenance)):
            if "$script:HostedControlExport" not in text:
                errors.append(f"{name}: exportação HostedControlExport foi perdida")
            if "[switch]$HostedInCentral" not in text:
                errors.append(f"{name}: suporte HostedInCentral foi perdido")

        # Regra crítica do Juntar lotes: REPARO livre somente quando consumo de saldo está desmarcado.
        required_generator_rules = (
            "Read-TV5MasterWorkbook $excel $masterPath -AllowUnknownRepair:(-not $consumeBalance)",
            "Read-MasterWorkbook $excel $masterPath -RequireInvoices -AllowUnknownRepair:(-not $consumeBalance)",
            "Get-BillingDeductionPlan -Store $script:BillingComponentStore",
            "Get-BillingNoDeductionPlan -Store $script:BillingComponentStore",
            "$combineConsumeBalanceCheck.Add_CheckedChanged",
        )
        for marker in required_generator_rules:
            if marker not in generator:
                errors.append(f"Gerenciador: regra crítica ausente: {marker}")

        # A camada Core que controla componentes precisa continuar disponível.
        for marker in ("Get-BillingDeductionPlan", "Get-BillingNoDeductionPlan", "Apply-BillingDeductionPlan"):
            if marker not in generator_core:
                errors.append(f"Componentes.Core: função crítica ausente: {marker}")

        # Regra crítica da Manutenção: toda série é numérica e possui exatamente 8 dígitos.
        if not re.search(r'\$serialBox\.MaxLength\s*=\s*8\b', maintenance):
            errors.append("Manutenção: limite visual de série em 8 dígitos foi perdido")
        if "if (-not (Test-CB5Serial $serial))" not in maintenance:
            errors.append("Manutenção: validação Test-CB5Serial não está sendo usada na consulta por série")
        core_serial = re.search(r'function\s+Test-CB5Serial\b(.{0,1400})', maintenance_core, re.S | re.I)
        if not core_serial:
            errors.append("Manutencao.Core: função Test-CB5Serial ausente")
        else:
            serial_body = core_serial.group(1)
            if not any(token in serial_body for token in ("{8}", "-eq 8", "-ne 8", "Length -eq 8", "Length -ne 8")):
                errors.append("Manutencao.Core: não foi encontrada evidência da regra de exatamente 8 dígitos em Test-CB5Serial")

        # Núcleos e configuração do Atualizador não podem desaparecer silenciosamente.
        if "Update.Core.ps1" not in updater:
            errors.append("Atualizador: referência a Update.Core.ps1 ausente")
        if len(updater_core.strip()) < 200:
            errors.append("Atualizador: Update.Core.ps1 parece incompleto")
        try:
            channels = json.loads(read_text(channels_path))
            if not channels:
                errors.append("Atualizador: CANAIS.json está vazio")
        except Exception as exc:
            errors.append(f"Atualizador: CANAIS.json inválido: {exc}")

    # Pacote de instalação nunca deve carregar dados do usuário, caches ou logs de desenvolvimento.
    forbidden_parts = ("__pycache__", ".pyc", ".log", "erro-inicializacao", "componentes-a-faturar", "preferencias.json")
    for rel in sorted(actual):
        low = rel.lower()
        if any(part in low for part in forbidden_parts):
            errors.append(f"arquivo de dados/cache indevido no pacote: {rel}")

    fail(errors)
    print(f"AUDITORIA DE ÁRVORE: OK — {len(actual)} arquivos obrigatórios, versões e regras críticas preservadas.")


def audit_package(root, version, package_path, channel_path):
    errors = []
    manifest_path = root / "PACOTE-MANIFESTO.json"
    if not manifest_path.exists():
        errors.append("PACOTE-MANIFESTO.json não foi criado")
    if not package_path.exists() or package_path.stat().st_size <= 0:
        errors.append("ZIP final não foi criado ou está vazio")
    if not channel_path.exists():
        errors.append("updates/test.json não foi criado")
    fail(errors)

    manifest = json.loads(read_text(manifest_path))
    channel = json.loads(read_text(channel_path))
    package_bytes = package_path.read_bytes()
    package_sha = hashlib.sha256(package_bytes).hexdigest().upper()

    if manifest.get("Version") != version:
        errors.append(f"manifesto com versão divergente: {manifest.get('Version')!r}")
    if channel.get("Version") != version:
        errors.append(f"canal Teste com versão divergente: {channel.get('Version')!r}")
    if channel.get("PackageRoot") != root.name:
        errors.append(f"PackageRoot divergente: {channel.get('PackageRoot')!r} != {root.name!r}")
    if channel.get("PackageSha256") != package_sha:
        errors.append("SHA-256 do canal Teste não corresponde ao ZIP gerado")
    if int(channel.get("PackageSize", -1)) != len(package_bytes):
        errors.append("PackageSize do canal Teste não corresponde ao ZIP gerado")

    manifest_paths = {str(item.get("Path", "")).replace("\\", "/") for item in manifest.get("Files", [])}
    if manifest_paths != EXPECTED_FILES:
        missing = sorted(EXPECTED_FILES - manifest_paths)
        extras = sorted(manifest_paths - EXPECTED_FILES)
        if missing:
            errors.append("manifesto não contém: " + ", ".join(missing))
        if extras:
            errors.append("manifesto contém arquivos inesperados: " + ", ".join(extras))

    expected_zip = {f"{root.name}/{rel}" for rel in EXPECTED_FILES | {"PACOTE-MANIFESTO.json"}}
    try:
        with zipfile.ZipFile(package_path, "r") as zf:
            names = {name.rstrip("/") for name in zf.namelist() if not name.endswith("/")}
            if zf.testzip() is not None:
                errors.append("ZIP final falhou na verificação CRC")
            if names != expected_zip:
                missing = sorted(expected_zip - names)
                extras = sorted(names - expected_zip)
                if missing:
                    errors.append("ZIP não contém: " + ", ".join(missing))
                if extras:
                    errors.append("ZIP contém arquivos inesperados: " + ", ".join(extras))
    except zipfile.BadZipFile:
        errors.append("arquivo final não é um ZIP válido")

    fail(errors)
    print(f"AUDITORIA DE PACOTE: OK — ZIP, manifesto, SHA-256 e canal Teste consistentes ({len(package_bytes)} bytes).")


def main():
    if len(sys.argv) < 2:
        raise SystemExit("uso: audit_release.py tree ROOT VERSION | package ROOT VERSION ZIP TEST_JSON")
    mode = sys.argv[1]
    if mode == "tree" and len(sys.argv) == 4:
        audit_tree(pathlib.Path(sys.argv[2]), sys.argv[3])
        return
    if mode == "package" and len(sys.argv) == 6:
        audit_package(pathlib.Path(sys.argv[2]), sys.argv[3], pathlib.Path(sys.argv[4]), pathlib.Path(sys.argv[5]))
        return
    raise SystemExit("argumentos inválidos")


if __name__ == "__main__":
    main()
