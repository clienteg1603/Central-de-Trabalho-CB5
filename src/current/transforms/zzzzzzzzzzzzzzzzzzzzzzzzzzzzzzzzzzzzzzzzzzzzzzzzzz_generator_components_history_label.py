from pathlib import Path

cp = Path('src/generated/Central de Trabalho.ps1')
gp = Path('src/generated/Modulos/Gerador-de-Planilhas-CB5-TV5/Gerador Planilhas.ps1')

c = cp.read_text(encoding='utf-8-sig')
g = gp.read_text(encoding='utf-8-sig')


def one(text, old, new, label):
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'COMPONENT HISTORY {label}: esperado 1, encontrado {count}')
    return text.replace(old, new, 1)


# Versões — somente canal Teste.
c = one(c, '$script:AppVersion = "0.21.60"', '$script:AppVersion = "0.21.61"', 'versao Central')
c = one(c, '$script:GeneratorVersion = "3.7.17"', '$script:GeneratorVersion = "3.7.18"', 'versao Gerenciador na Central')
g = one(g, '$script:AppVersion = "3.7.17"', '$script:AppVersion = "3.7.18"', 'versao Gerenciador')

# A página já é o histórico real de movimentos dos componentes (data,
# componente, movimento, variação etc.). O rótulo "Movimentações" ficou
# ambíguo depois da repaginação e fez o histórico parecer ter desaparecido.
# Mantemos exatamente a mesma grade/dados e restauramos o nome explícito.
g = one(
    g,
    '$componentMovementsPage.Text = "Movimentações"',
    '$componentMovementsPage.Text = "Histórico"',
    'rotulo da aba de historico'
)

c += '\n# COMPONENTES_HISTORICO_VISIVEL_V02161\n'
g += '\n# COMPONENTES_HISTORICO_VISIVEL_V03718\n'

for marker in (
    '$script:AppVersion = "0.21.61"',
    '$script:GeneratorVersion = "3.7.18"',
    'COMPONENTES_HISTORICO_VISIVEL_V02161',
):
    if marker not in c:
        raise SystemExit('COMPONENT HISTORY Central marcador ausente: ' + marker)

for marker in (
    '$script:AppVersion = "3.7.18"',
    '$componentMovementsPage.Text = "Histórico"',
    '$componentHistoryGrid.Columns.Add("Date", "Data")',
    '$componentHistoryGrid.Columns.Add("Component", "Componente")',
    '$componentHistoryGrid.Columns.Add("Type", "Movimento")',
    'Get-BillingMovementRows',
    'COMPONENTES_HISTORICO_VISIVEL_V03718',
):
    if marker not in g:
        raise SystemExit('COMPONENT HISTORY Gerenciador marcador ausente: ' + marker)

cp.write_text(c, encoding='utf-8')
gp.write_text(g, encoding='utf-8')
print('COMPONENTES: OK - histórico real novamente identificado como Histórico; dados e lógica preservados.')
