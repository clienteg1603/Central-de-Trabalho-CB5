from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CENTRAL = ROOT / "generated" / "Central de Trabalho.ps1"
GEN = ROOT / "generated" / "Modulos" / "Gerador-de-Planilhas-CB5-TV5" / "Gerador Planilhas.ps1"


def read(path):
    return path.read_text(encoding="utf-8-sig")


def write(path, text):
    path.write_text(text, encoding="utf-8-sig")


def replace_once(text, old, new, label):
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: esperado 1 trecho, encontrado {count}")
    return text.replace(old, new, 1)


central = read(CENTRAL)
central = replace_once(central, '$script:AppVersion = "0.13.1"', '$script:AppVersion = "0.14.0"', "versao Central")
central = replace_once(central, '$script:GeneratorVersion = "3.6.1"', '$script:GeneratorVersion = "3.6.2"', "versao Gerenciador na Central")

old_nav = '''$navHome = New-SidebarButton "⌂   Início"
$navPrograms = New-SidebarButton "▦   Programas"
$navPrograms.Visible = $false
$navUpdates = New-SidebarButton "↻   Atualizações"
$navBackup = New-SidebarButton "⟲   Backup / restauração"
$navBackup.Visible = $false
$navFolder = New-SidebarButton "▣   Pasta da Central"
$navAbout = New-SidebarButton "ⓘ   Sobre"
foreach ($button in @($navHome, $navPrograms, $navUpdates, $navBackup, $navFolder, $navAbout)) { $navPanel.Controls.Add($button) }'''
new_nav = '''$navHome = New-SidebarButton "⌂   Início"
# Programas e Backup deixaram de ser botões próprios: eram rotas duplicadas.
# Mantemos as variáveis nulas para compatibilidade com o estado interno de navegação.
$navPrograms = $null
$navUpdates = New-SidebarButton "↻   Atualizações"
$navBackup = $null
$navFolder = New-SidebarButton "▣   Pasta da Central"
$navAbout = New-SidebarButton "ⓘ   Sobre"
foreach ($button in @($navHome, $navUpdates, $navFolder, $navAbout)) { $navPanel.Controls.Add($button) }'''
central = replace_once(central, old_nav, new_nav, "navegacao lateral sem duplicatas")

central = replace_once(
    central,
    '$embeddedBackButton.Text = "←  VOLTAR"',
    '$embeddedBackButton.Text = "←  CENTRAL"',
    "rotulo voltar para Central"
)
central = replace_once(
    central,
    '$pageSubtitle.Text = "Painel principal para acessar módulos, acompanhar o sistema e chegar rápido ao que precisa."',
    '$pageSubtitle.Text = "Acesse seus programas e acompanhe o estado da Central em um só lugar."',
    "subtitulo da visao geral"
)
central = replace_once(
    central,
    '$g = New-ModuleCard "XLS" "Gerenciador de Planilhas" "Prepara mestres CB5 e TV5, gera e junta planilhas e acompanha componentes ainda pendentes de faturamento." "Versão integrada: $($script:GeneratorVersion)   •   Requer Microsoft Excel" "ABRIR NA CENTRAL"',
    '$g = New-ModuleCard "XLS" "Gerenciador de Planilhas" "Prepara mestres CB5 e TV5, gera e junta planilhas e acompanha componentes ainda pendentes de faturamento." "Versão integrada: $($script:GeneratorVersion)   •   Requer Microsoft Excel" "ABRIR GERENCIADOR"',
    "botao Gerenciador"
)
central = replace_once(
    central,
    '$m = New-ModuleCard "CB5" "Central de Manutenção CB5" "Cadastro de peças por código, histórico automático por série, correção auditada, relatórios e apoio ao diagnóstico." "Versão integrada: $($script:MaintenanceVersion)   •   Histórico local por série" "ABRIR NA CENTRAL"',
    '$m = New-ModuleCard "CB5" "Central de Manutenção CB5" "Cadastro de peças por código, histórico automático por série, correção auditada, relatórios e apoio ao diagnóstico." "Versão integrada: $($script:MaintenanceVersion)   •   Histórico local por série" "ABRIR MANUTENÇÃO"',
    "botao Manutencao"
)

central = replace_once(
    central,
    '$navBackup.Add_Click({ Set-ActiveNavigation "Backup"; Start-UpdaterModule })\n',
    '',
    "evento antigo de Backup"
)
old_program_event = '''$navPrograms.Add_Click({
    Show-Dashboard
    Set-ActiveNavigation "Programs"
    try { $modulesFlow.ScrollControlIntoView($generatorCard) } catch {}
    Set-StatusMessage "Escolha um programa para abri-lo dentro da Central." "Normal"
})
'''
central = replace_once(central, old_program_event, '', "evento antigo de Programas")

central = replace_once(
    central,
    '$toolTip.SetToolTip($quickUpdatesButton, "Abrir atualização, backup e restauração")',
    '$toolTip.SetToolTip($quickUpdatesButton, "Abrir atualização, backup e restauração")\n$toolTip.SetToolTip($embeddedBackButton, "Voltar para a tela inicial da Central de Trabalho")\n$toolTip.SetToolTip($embeddedFolderButton, "Abrir a pasta do módulo que está em uso")',
    "tooltips da barra integrada"
)
central = replace_once(
    central,
    'Etapa 3: integração visual e evolução da Central de Manutenção CB5.',
    'Interface integrada e responsiva para os módulos de trabalho, manutenção e atualização.',
    "texto Sobre atualizado"
)
write(CENTRAL, central)


gen = read(GEN)
gen = replace_once(gen, '$script:AppVersion = "3.6.1"', '$script:AppVersion = "3.6.2"', "versao Gerenciador")
old_summary = '''    $invalidText = if ($invalidFields -gt 0) { "  •  $invalidFields quantidade(s) inválida(s)" } else { "" }
    $balanceText = if ($combineConsumeBalanceCheck.Checked) { "consumir saldo" } else { "não consumir saldo" }
    $combineSelectionLabel.Text = "$($combineGrid.Rows.Count) lote(s) selecionado(s)  •  $withMaintenance mestre(s) serão atualizadas  •  $balanceText$invalidText"'''
new_summary = '''    $invalidText = if ($invalidFields -gt 0) { "  •  $invalidFields quantidade(s) inválida(s)" } else { "" }
    # O estado de consumo já possui um cartão próprio logo abaixo; não repetimos a mesma informação no resumo.
    $combineSelectionLabel.Text = "$($combineGrid.Rows.Count) lote(s) selecionado(s)  •  $withMaintenance mestre(s) serão atualizadas$invalidText"'''
gen = replace_once(gen, old_summary, new_summary, "remove duplicacao do estado de saldo")
gen = replace_once(
    gen,
    '$combineConsumeBalanceCheck.BackColor = $palette.Background',
    '$combineConsumeBalanceCheck.BackColor = $palette.Surface',
    "fundo do checkbox de saldo"
)
gen = replace_once(
    gen,
    '$componentsIntro.Text = "Saldo a faturar: quantidades já usadas nas manutenções e ainda não enviadas ao faturamento. A baixa automática acontece somente após Juntar lotes terminar com sucesso."',
    '$componentsIntro.Text = "Saldo a faturar reúne componentes já usados e ainda não enviados ao faturamento. A baixa automática ocorre somente após Juntar lotes concluir com sucesso."',
    "texto de contexto de Componentes"
)

marker = '$componentBalancesPage.Controls.Add($componentLaunchButton)\n'
insert = marker + '$toolTip.SetToolTip($componentLaunchButton, "Registrar no saldo uma quantidade de componente que já foi usada e ainda será faturada.")\n'
gen = replace_once(gen, marker, insert, "tooltip lancar uso")
marker = '$componentBalancesPage.Controls.Add($componentAdjustButton)\n'
insert = marker + '$toolTip.SetToolTip($componentAdjustButton, "Corrigir manualmente o saldo atual do componente selecionado.")\n'
gen = replace_once(gen, marker, insert, "tooltip ajustar saldo")
marker = '$componentBalancesPage.Controls.Add($componentNewButton)\n'
insert = marker + '$toolTip.SetToolTip($componentNewButton, "Cadastrar um novo componente para reconhecimento e controle de faturamento.")\n'
gen = replace_once(gen, marker, insert, "tooltip novo componente")
marker = '$componentBalancesPage.Controls.Add($componentEditButton)\n'
insert = marker + '$toolTip.SetToolTip($componentEditButton, "Editar nome, códigos, texto de reparo, apelidos ou estado do componente selecionado.")\n'
gen = replace_once(gen, marker, insert, "tooltip editar componente")
write(GEN, gen)

print("Transformação v0.14.0 aplicada com sucesso.")
