#!/usr/bin/env python3
import pathlib
import sys


def read(path: pathlib.Path) -> str:
    return path.read_text(encoding="utf-8-sig", errors="strict")


def require(errors, text: str, marker: str, label: str) -> None:
    if marker not in text:
        errors.append(f"{label}: marcador ausente: {marker}")


def forbid(errors, text: str, marker: str, label: str) -> None:
    if marker in text:
        errors.append(f"{label}: mecanismo proibido reapareceu: {marker}")


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("uso: geral2_responsive_contracts.py ROOT")

    root = pathlib.Path(sys.argv[1])
    central_path = root / "Central de Trabalho.ps1"
    generator_path = root / "Modulos/Gerador-de-Planilhas-CB5-TV5/Gerador Planilhas.ps1"
    maintenance_path = root / "Modulos/Central-de-Manutencao-CB5/Central Manutencao CB5.ps1"
    nf_path = root / "Modulos/Controle-NF-Entrada/Controle NF Entrada.ps1"
    updater_path = root / "Atualizador/Central de Trabalho Updater.ps1"

    errors = []
    for path in (central_path, generator_path, maintenance_path, nf_path, updater_path):
        if not path.is_file():
            errors.append(f"arquivo ausente: {path.relative_to(root)}")
    if errors:
        raise SystemExit("\n".join(errors))

    central = read(central_path)
    generator = read(generator_path)
    maintenance = read(maintenance_path)
    nf = read(nf_path)
    updater = read(updater_path)

    # Etapa 1 — casca da Central.
    for marker in (
        "function Invoke-CentralResponsivePass",
        "function Schedule-CentralResponsivePass",
        "$form.Add_SizeChanged({ Schedule-CentralResponsivePass })",
        "$form.Add_DpiChanged({ Schedule-CentralResponsivePass })",
        "GERAL2_ETAPA1_CENTRAL_RESPONSIVA_V02149",
    ):
        require(errors, central, marker, "GERAL 2 / Central")

    # Etapa 2 — Gerenciador.
    for marker in (
        "function Update-GeneratorResponsiveLayout",
        "GERAL2_ETAPA2_GENERATOR_NAV_V03715",
        "GERAL2_ETAPA2_GENERATOR_V02150",
    ):
        require(errors, generator if "V03715" in marker or "function" in marker else central, marker, "GERAL 2 / Gerenciador")

    # Etapa 3 — Manutenção, incluindo a janela independente.
    for marker in (
        "function Update-MaintenanceResponsiveLayout",
        "$form.MinimumSize = [Drawing.Size]::new(880, 600)",
        "$form.Add_SizeChanged({ Update-MaintenanceResponsiveLayout })",
        "GERAL2_ETAPA3_MANUTENCAO_BASE_V00612",
        "GERAL2_ETAPA3_MANUTENCAO_TECNICA_V00612",
    ):
        require(errors, maintenance, marker, "GERAL 2 / Manutenção")

    # Etapa 4 — Controle de NF. A responsividade não pode reabrir o caminho
    # instável do TabControl que já causou reentrada de layout.
    for marker in (
        "function Update-NFResponsiveLayout",
        "$form.MinimumSize = [Drawing.Size]::new(860, 600)",
        "GERAL2_ETAPA4_NF_RESPONSIVE_V02618",
    ):
        require(errors, nf, marker, "GERAL 2 / Controle de NF")
    for marker in (
        "$mainTabs.Add_SizeChanged",
        "$mainTabs.Add_HandleCreated",
        "$mainTabs.DrawMode = [Windows.Forms.TabDrawMode]::OwnerDrawFixed",
        "$mainTabs.ItemSize",
        "Update-NFMainTabStripLayout",
    ):
        forbid(errors, nf, marker, "GERAL 2 / Controle de NF")

    # O Atualizador já possuía uma casca própria resiliente: DPI, maximização,
    # conteúdo rolável e rodapé fora da rolagem. A GERAL 2 não precisa alterar
    # suas regras de instalação; apenas garante que essas proteções permaneçam.
    for marker in (
        "$form.AutoScaleMode = [Windows.Forms.AutoScaleMode]::Dpi",
        "$form.MaximizeBox = $true",
        "$bodyHost.AutoScroll = $true",
        "$root.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 100)))",
        "$footer.Dock = [Windows.Forms.DockStyle]::Fill",
    ):
        require(errors, updater, marker, "GERAL 2 / Atualizador")

    # Fechamento: a versão final da etapa precisa estar presente na Central.
    require(errors, central, '$script:AppVersion = "0.21.53"', "GERAL 2 / fechamento")
    require(errors, central, "GERAL2_ETAPA5_FECHAMENTO_V02153", "GERAL 2 / fechamento")

    if errors:
        print("GERAL 2 — AUDITORIA RESPONSIVA: FALHOU")
        for error in errors:
            print(" - " + error)
        raise SystemExit(1)

    print("GERAL 2 — AUDITORIA RESPONSIVA: OK — Central, Gerenciador, Manutenção, NF e casca do Atualizador preservados.")


if __name__ == "__main__":
    main()
