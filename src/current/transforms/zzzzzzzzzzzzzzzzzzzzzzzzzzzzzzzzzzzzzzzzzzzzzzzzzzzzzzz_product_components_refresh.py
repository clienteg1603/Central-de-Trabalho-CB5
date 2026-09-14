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

old = '''    Apply-AppTheme
    Update-LiveSummary
    if ($script:UiReady) { Save-AppSettings }
}

$productCombo.Add_SelectedIndexChanged({ Update-ProductInterface })'''
new = '''    # O contexto de Componentes depende do produto atual. Ao alternar CB5/TV5,
    # recarregar imediatamente Saldos, Histórico e Uniões processadas para que
    # nenhuma grade permaneça exibindo dados do produto anterior.
    Update-BillingComponentsView
    Apply-AppTheme
    Update-LiveSummary
    if ($script:UiReady) { Save-AppSettings }
}

$productCombo.Add_SelectedIndexChanged({ Update-ProductInterface })'''
g = one(g, old, new, 'refresh ao trocar produto')

# Auditoria local da transformação: a atualização deve estar dentro de
# Update-ProductInterface e antes do evento SelectedIndexChanged.
fn_start = g.find('function Update-ProductInterface {')
fn_end = g.find('$productCombo.Add_SelectedIndexChanged({ Update-ProductInterface })', fn_start)
if fn_start < 0 or fn_end < 0:
    raise SystemExit('PRODUCT COMPONENT REFRESH: bloco Update-ProductInterface não localizado')
block = g[fn_start:fn_end]
if 'Update-BillingComponentsView' not in block:
    raise SystemExit('PRODUCT COMPONENT REFRESH: refresh de Componentes não ficou no bloco do produto')
if block.find('$script:CurrentProduct = $selectedProduct') > block.find('Update-BillingComponentsView'):
    raise SystemExit('PRODUCT COMPONENT REFRESH: refresh ocorre antes da troca do produto')

c += '\n# PRODUCT_COMPONENT_REFRESH_V02163\n'
g += '\n# PRODUCT_COMPONENT_REFRESH_V03720\n'

for marker in ('$script:AppVersion = "0.21.63"', '$script:GeneratorVersion = "3.7.20"', 'PRODUCT_COMPONENT_REFRESH_V02163'):
    if marker not in c:
        raise SystemExit('PRODUCT COMPONENT REFRESH Central marcador ausente: ' + marker)
for marker in ('$script:AppVersion = "3.7.20"', 'Update-BillingComponentsView', 'PRODUCT_COMPONENT_REFRESH_V03720'):
    if marker not in g:
        raise SystemExit('PRODUCT COMPONENT REFRESH Gerenciador marcador ausente: ' + marker)

cp.write_text(c, encoding='utf-8')
gp.write_text(g, encoding='utf-8')
print('PRODUCT COMPONENT REFRESH: OK - Saldos, Histórico e Uniões acompanham CB5/TV5 imediatamente.')
