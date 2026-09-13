from pathlib import Path

cp = Path('src/generated/Central de Trabalho.ps1')
np = Path('src/generated/Modulos/Controle-NF-Entrada/Controle NF Entrada.ps1')

c = cp.read_text(encoding='utf-8-sig')
n = np.read_text(encoding='utf-8-sig')


def one(text, old, new, label):
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'UI FIT NF SINGLE ROW {label}: esperado 1, encontrado {count}')
    return text.replace(old, new, 1)

c = one(c, '$script:NFEntradaVersion = "2.6.20"', '$script:NFEntradaVersion = "2.6.21"', 'versao Central')
n = one(n, '$script:ModuleVersion = "2.6.20"', '$script:ModuleVersion = "2.6.21"', 'versao modulo')

# A auditoria visual completa encontrou o mesmo padrão em vários layouts de uma única linha:
# ColumnStyles existiam, mas RowCount/RowStyle não. Em WinForms isso pode manter a altura
# preferida antiga (ex.: 100 px) dentro de um container responsivo de 48/66 px.
# Tornamos essas linhas explícitas para que os filhos sempre recebam exatamente a altura real.

n = one(
    n,
    '''$header = New-Object Windows.Forms.TableLayoutPanel
$header.Dock = [Windows.Forms.DockStyle]::Fill
$header.ColumnCount = 3''',
    '''$header = New-Object Windows.Forms.TableLayoutPanel
$header.Dock = [Windows.Forms.DockStyle]::Fill
$header.ColumnCount = 3
$header.RowCount = 1
[void]$header.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 100)))''',
    'header'
)

n = one(
    n,
    '''$movementFilters = New-Object Windows.Forms.TableLayoutPanel
$movementFilters.Dock = [Windows.Forms.DockStyle]::Fill
$movementFilters.ColumnCount = 6''',
    '''$movementFilters = New-Object Windows.Forms.TableLayoutPanel
$movementFilters.Dock = [Windows.Forms.DockStyle]::Fill
$movementFilters.ColumnCount = 6
$movementFilters.RowCount = 1
[void]$movementFilters.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 100)))''',
    'movementFilters'
)

n = one(
    n,
    '''$movementFooter=New-Object Windows.Forms.TableLayoutPanel
$movementFooter.Dock=[Windows.Forms.DockStyle]::Fill; $movementFooter.ColumnCount=4''',
    '''$movementFooter=New-Object Windows.Forms.TableLayoutPanel
$movementFooter.Dock=[Windows.Forms.DockStyle]::Fill; $movementFooter.ColumnCount=4; $movementFooter.RowCount=1
[void]$movementFooter.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent,100)))''',
    'movementFooter'
)

n = one(
    n,
    '''$historyFilters = New-Object Windows.Forms.TableLayoutPanel
$historyFilters.Dock = [Windows.Forms.DockStyle]::Fill
$historyFilters.ColumnCount = 7''',
    '''$historyFilters = New-Object Windows.Forms.TableLayoutPanel
$historyFilters.Dock = [Windows.Forms.DockStyle]::Fill
$historyFilters.ColumnCount = 7
$historyFilters.RowCount = 1
[void]$historyFilters.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 100)))''',
    'historyFilters'
)

n = one(
    n,
    '''$securityActions = New-Object Windows.Forms.TableLayoutPanel
$securityActions.Dock = [Windows.Forms.DockStyle]::Fill; $securityActions.ColumnCount = 2''',
    '''$securityActions = New-Object Windows.Forms.TableLayoutPanel
$securityActions.Dock = [Windows.Forms.DockStyle]::Fill; $securityActions.ColumnCount = 2; $securityActions.RowCount = 1
[void]$securityActions.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 100)))''',
    'securityActions'
)

n = one(
    n,
    '''$footerHost = New-Object Windows.Forms.TableLayoutPanel
$footerHost.Dock = [Windows.Forms.DockStyle]::Fill
$footerHost.BackColor = $script:CurrentPalette.Surface''',
    '''$footerHost = New-Object Windows.Forms.TableLayoutPanel
$footerHost.Dock = [Windows.Forms.DockStyle]::Fill
$footerHost.RowCount = 1
[void]$footerHost.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 100)))
$footerHost.BackColor = $script:CurrentPalette.Surface''',
    'footerHost'
)

c += '\n# POS_GERAL2_NF_SINGLE_ROW_FIT_V02157\n'
n += '\n# POS_GERAL2_NF_SINGLE_ROW_FIT_V02621\n'

for marker in ('$script:NFEntradaVersion = "2.6.21"', 'POS_GERAL2_NF_SINGLE_ROW_FIT_V02157'):
    if marker not in c:
        raise SystemExit('UI FIT NF SINGLE ROW Central marcador ausente: ' + marker)
for marker in ('$script:ModuleVersion = "2.6.21"', '$header.RowCount = 1', '$movementFilters.RowCount = 1', '$historyFilters.RowCount = 1', '$footerHost.RowCount = 1', 'POS_GERAL2_NF_SINGLE_ROW_FIT_V02621'):
    if marker not in n:
        raise SystemExit('UI FIT NF SINGLE ROW marcador ausente: ' + marker)

cp.write_text(c, encoding='utf-8')
np.write_text(n, encoding='utf-8')
print('POS-GERAL 2 NF SINGLE ROW FIT: OK - layouts de uma linha seguem a altura real do container em resize/maximizado/DPI.')
