from pathlib import Path

cp = Path('src/generated/Central de Trabalho.ps1')
gp = Path('src/generated/Modulos/Gerador-de-Planilhas-CB5-TV5/Gerador Planilhas.ps1')

c = cp.read_text(encoding='utf-8-sig')
g = gp.read_text(encoding='utf-8-sig')


def one(text, old, new, label):
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'PRODUCT COMPONENT REFRESH {label}: esperado 1, encontrado {count}')
    return text.replace(old, new, 1)

c = one(c, '$script:AppVersion = "0.21.62"', '$script:AppVersion = "0.21.63"', 'versao Central')
c = one(c, '$script:GeneratorVersion = "3.7.19"', '$script:GeneratorVersion = "3.7.20"', 'versao Gerenciador Central')
g = one(g, '$script:AppVersion = "3.7.19"', '$script:AppVersion = "3.7.20"', 'versao Gerenciador')

# O evento de troca do seletor de produto já chama Update-ProductInterface, que
# atualiza $script:CurrentProduct. Logo depois, atualizar explicitamente toda a
# área Componentes para o novo contexto. Isso evita que Histórico/Saldos/Uniões
# conservem as linhas do produto anterior até outra ação forçar um refresh.
event_old = '$productCombo.Add_SelectedIndexChanged({ Update-ProductInterface })'
event_new = '$productCombo.Add_SelectedIndexChanged({ Update-ProductInterface; Update-BillingComponentsView })'
g = one(g, event_old, event_new, 'evento de troca de produto')

# Auditoria local: CurrentProduct precisa ser alterado por Update-ProductInterface
# e o evento precisa atualizar Componentes somente depois dessa chamada.
fn_start = g.find('function Update-ProductInterface {')
fn_end = g.find('$productCombo.Add_SelectedIndexChanged(', fn_start)
if fn_start < 0 or fn_end < 0:
    raise SystemExit('PRODUCT COMPONENT REFRESH: Update-ProductInterface/evento não localizado')
block = g[fn_start:fn_end]
if '$script:CurrentProduct = $selectedProduct' not in block:
    raise SystemExit('PRODUCT COMPONENT REFRESH: troca de CurrentProduct ausente')
if event_new not in g:
    raise SystemExit('PRODUCT COMPONENT REFRESH: evento final não aplicado')

c += '\n# PRODUCT_COMPONENT_REFRESH_V02163\n'
g += '\n# PRODUCT_COMPONENT_REFRESH_V03720\n'

for marker in ('$script:AppVersion = "0.21.63"', '$script:GeneratorVersion = "3.7.20"', 'PRODUCT_COMPONENT_REFRESH_V02163'):
    if marker not in c:
        raise SystemExit('PRODUCT COMPONENT REFRESH Central marcador ausente: ' + marker)
for marker in ('$script:AppVersion = "3.7.20"', event_new, 'PRODUCT_COMPONENT_REFRESH_V03720'):
    if marker not in g:
        raise SystemExit('PRODUCT COMPONENT REFRESH Gerenciador marcador ausente: ' + marker)

cp.write_text(c, encoding='utf-8')
gp.write_text(g, encoding='utf-8')
print('PRODUCT COMPONENT REFRESH: OK - Saldos, Histórico e Uniões acompanham CB5/TV5 imediatamente.')
