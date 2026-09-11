from pathlib import Path
import json

ROOT = Path('.')
central_path = ROOT / 'src/generated/Central de Trabalho.ps1'
reg_path = ROOT / 'src/ci/regression_contracts.py'
version_path = ROOT / 'src/current/version.json'


def read(path):
    return path.read_text(encoding='utf-8-sig')


def write(path, text):
    path.write_text(text, encoding='utf-8')


def replace_once(text, old, new, label):
    if old not in text:
        raise SystemExit(f'Etapa 3 NF Entrada: trecho não encontrado ({label})')
    return text.replace(old, new, 1)

central = read(central_path)
central = replace_once(central, '$script:AppVersion = "0.21.3"', '$script:AppVersion = "0.21.4"', 'versão Central')
central = replace_once(central, '$script:NFEntradaVersion = "1.2.0"', '$script:NFEntradaVersion = "1.3.0"', 'versão NF Central')
write(central_path, central)

reg = read(reg_path)
reg = replace_once(reg,
'''    for fn in ("Initialize-NFEntradaDataStore", "Import-NFEntradaSourceWorkbook", "Read-NFEntradaStore", "Write-NFEntradaStore", "Ensure-NFEntradaStoreShape", "Add-NFEntradaHistoryEvent", "Get-NFEntradaHistory", "New-NFEntradaSafetyBackup", "Restore-NFEntradaSafetyBackup", "Get-NFEntradaRecordStatus", "Add-NFEntradaRecord", "Update-NFEntradaRecord", "Remove-NFEntradaRecord", "Get-NFEntradaSummary", "Export-NFEntradaWorkbook"):
''',
'''    for fn in ("Initialize-NFEntradaDataStore", "Import-NFEntradaSourceWorkbook", "Read-NFEntradaStore", "Write-NFEntradaStore", "Ensure-NFEntradaStoreShape", "Add-NFEntradaHistoryEvent", "Get-NFEntradaHistory", "New-NFEntradaSafetyBackup", "Restore-NFEntradaSafetyBackup", "Get-NFEntradaSafetyBackups", "Restore-NFEntradaBackupSet", "Get-NFEntradaRecordStatus", "Add-NFEntradaRecord", "Update-NFEntradaRecord", "Remove-NFEntradaRecord", "Get-NFEntradaSummary", "Export-NFEntradaWorkbook"):
''', 'funções core no contrato')

anchor = '''    for marker in ('"Todos", "Em estoque", "Encerrada", "Revisar"', '"Todos", "800", "100", "850", "Garantia"', 'Add-NFGridColumn $grid "Status" "STATUS"', '$CountLabel.Text = "$shown de $($records.Count)"', 'EDITAR SELEÇÃO'):
        require(errors, nf, marker, "NF Entrada / clareza visual e filtros")
'''
addition = '''    for marker in ('"Todos", "Em estoque", "Encerrada", "Revisar"', '"Todos", "800", "100", "850", "Garantia"', 'Add-NFGridColumn $grid "Status" "STATUS"', '$CountLabel.Text = "$shown de $($records.Count)"', 'EDITAR SELEÇÃO'):
        require(errors, nf, marker, "NF Entrada / clareza visual e filtros")
    for marker in ('HISTÓRICO', 'SEGURANÇA', 'VER DETALHES', 'CRIAR BACKUP AGORA', 'RESTAURAR SELECIONADO', 'Confirmar restauração de backup', 'Refresh-NFHistory', 'Refresh-NFBackups'):
        require(errors, nf, marker, "NF Entrada / histórico e segurança visíveis")
    for marker in ('backup-info.json', 'Antes de restaurar backup', '-Tipo "RestauracaoBackup"', 'O backup selecionado não pertence ao Controle de NF de Entrada.'):
        require(errors, nf_core, marker, "NFEntrada.Core / restauração protegida")
'''
reg = replace_once(reg, anchor, addition, 'contratos etapa 3')
write(reg_path, reg)

meta = {
    'version': '0.21.4',
    'buildRevision': 1,
    'releaseNotes': [
        'Etapa 3 do Controle de NF de Entrada: torna o histórico auditável e os backups acessíveis diretamente pela interface.',
        'Nova aba HISTÓRICO lista adições, edições, exclusões, importações e restaurações, com pesquisa, filtro por tipo e visualização detalhada do estado anterior e posterior.',
        'Nova aba SEGURANÇA lista os backups internos com data, motivo, quantidade de registros, conteúdo e situação.',
        'Passa a ser possível criar um backup manual pelo programa sem manipular pastas ou arquivos.',
        'A restauração de um backup exige confirmação, valida a base escolhida e cria automaticamente um backup do estado atual antes de aplicar a restauração.',
        'Se a restauração falhar, o estado anterior é restaurado automaticamente; restaurações concluídas também entram no histórico do módulo.',
        'Novos backups recebem metadados internos para diferenciar cópias manuais, automáticas e cópias criadas antes de restaurações.',
        'Filtros, status, importação protegida e exportação fiel ao XLSX original permanecem preservados.',
        'Controle de NF de Entrada passa para v1.3.0; Gerenciador de Planilhas permanece v3.7.3 e Central de Manutenção permanece v0.6.1.',
        'A versão Estável permanece v0.20.2; a v0.21.4 é publicada somente no canal Teste.'
    ]
}
version_path.write_text(json.dumps(meta, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print('Etapa 3 metadados/contratos aplicada.')
