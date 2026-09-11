from pathlib import Path

UI = Path('src/generated/Modulos/Controle-NF-Entrada/Controle NF Entrada.ps1')
CENTRAL = Path('src/generated/Central de Trabalho.ps1')


def read(path):
    return path.read_text(encoding='utf-8-sig')


def write(path, text):
    path.write_text(text, encoding='utf-8')


def rep(text, old, new, label):
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'Etapa 17: marcador inesperado em {label}: {count}')
    return text.replace(old, new, 1)


ui = read(UI)
central = read(CENTRAL)

ui = rep(ui, '$script:ModuleVersion = "2.6.0"', '$script:ModuleVersion = "2.6.1"', 'versão módulo')
central = rep(central, '$script:AppVersion = "0.21.20"', '$script:AppVersion = "0.21.21"', 'versão central')
central = rep(central, '$script:NFEntradaVersion = "2.6.0"', '$script:NFEntradaVersion = "2.6.1"', 'versão NF na central')

# Fechamento: nenhuma função nova. Confirma os contratos operacionais consolidados
# depois da auditoria da Etapa 16 antes de gerar o pacote final de Teste.
required_ui = (
    '$script:ModuleVersion = "2.6.1"',
    '$importButton.Text = "IMPORTAR EXCEL"',
    '$exportButton.Text = "EXCEL OFICIAL"',
    '$clearFiltersButton.Text = "LIMPAR"',
    '$reviewIssuesButton.Text = "PENDÊNCIAS"',
    '$outBox.ReadOnly = $true',
    'NF de Saída / movimentações (automático)',
    'function Get-NFHistoryActionLabel',
    '$historyPeriodFilter',
    'function Set-HostedNFEntradaTheme',
    '$movementReverseButton',
    '$integrityButton.Add_Click',
    '$restoreBackupButton.Add_Click',
    '$exportButton.Enabled = $true',
)
for marker in required_ui:
    if marker not in ui:
        raise SystemExit('Etapa 17: contrato final ausente na interface: ' + marker)

if '$exportCheckButton = New-Object Windows.Forms.Button' in ui:
    raise SystemExit('Etapa 17: botão redundante VALIDAR EXCEL voltou à interface.')

if '$script:AppVersion = "0.21.21"' not in central:
    raise SystemExit('Etapa 17: versão final da Central não aplicada.')
if '$script:NFEntradaVersion = "2.6.1"' not in central:
    raise SystemExit('Etapa 17: versão final do Controle NF na Central não aplicada.')

write(UI, ui)
write(CENTRAL, central)
print('ETAPA 17: OK - contratos finais consolidados; Central 0.21.21 / NF Entrada 2.6.1.')
