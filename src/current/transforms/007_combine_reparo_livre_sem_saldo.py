from pathlib import Path

ROOT = Path('src/generated')
central_path = ROOT / 'Central de Trabalho.ps1'
generator_path = ROOT / 'Modulos/Gerador-de-Planilhas-CB5-TV5/Gerador Planilhas.ps1'
central = central_path.read_text(encoding='utf-8-sig')
gen = generator_path.read_text(encoding='utf-8-sig')


def rep(text, old, new, label, count=1):
    n = text.count(old)
    if n != count:
        raise RuntimeError(f'{label}: esperado {count} trecho(s), encontrado {n}')
    return text.replace(old, new, count)


# Versões.
central = rep(central, '$script:AppVersion = "0.12.2"', '$script:AppVersion = "0.12.3"', 'versão da Central')
central = rep(central, '$script:GeneratorVersion = "3.5.1"', '$script:GeneratorVersion = "3.5.2"', 'versão do Gerenciador na Central')
gen = rep(gen, '$script:AppVersion = "3.5.1"', '$script:AppVersion = "3.5.2"', 'versão do Gerenciador')

# Os parsers continuam rigorosos por padrão. O modo permissivo só é ativado
# pelo Juntar lotes quando o consumo de saldo estiver desmarcado.
gen = rep(
    gen,
    'function Get-CB5RepairInfo {\n    param([string]$Text)',
    'function Get-CB5RepairInfo {\n    param(\n        [string]$Text,\n        [switch]$AllowUnknownRepair\n    )',
    'parâmetro permissivo CB5'
)
gen = rep(
    gen,
    'function Get-TV5RepairInfo {\n    param([string]$Text)',
    'function Get-TV5RepairInfo {\n    param(\n        [string]$Text,\n        [switch]$AllowUnknownRepair\n    )',
    'parâmetro permissivo TV5'
)

# Se o REPARO inteiro não seguir o formato oficial, no modo sem saldo ele é
# preservado como texto opaco. Nenhum componente é inferido dele.
gen = rep(
    gen,
    '''    if (-not $match.Success) {
        throw "REPARO '$Text' não reconhecido para CB5. Comece com ASTEC, ASTEC 1, ASTEC 2 ou ASTEC 3 e separe as manutenções por vírgulas."
    }''',
    '''    if (-not $match.Success) {
        if ($AllowUnknownRepair) {
            return [pscustomobject]@{
                Level = 0
                Codes = [Collections.Generic.List[string]]::new()
                LastAction = ""
            }
        }
        throw "REPARO '$Text' não reconhecido para CB5. Comece com ASTEC, ASTEC 1, ASTEC 2 ou ASTEC 3 e separe as manutenções por vírgulas."
    }''',
    'fallback de REPARO livre CB5'
)
gen = rep(
    gen,
    '''    if (-not $match.Success) {
        throw "REPARO '$Text' não reconhecido para TV5. Comece com ASTEC TV5 e separe as manutenções por vírgulas."
    }''',
    '''    if (-not $match.Success) {
        if ($AllowUnknownRepair) {
            return [pscustomobject]@{
                Codes = [Collections.Generic.List[string]]::new()
                LastAction = ""
            }
        }
        throw "REPARO '$Text' não reconhecido para TV5. Comece com ASTEC TV5 e separe as manutenções por vírgulas."
    }''',
    'fallback de REPARO livre TV5'
)

# Quando só uma manutenção/componente dentro do REPARO é desconhecida, o modo
# sem saldo ignora apenas essa interpretação. O texto original continua no item
# e será copiado para a planilha unida. Com saldo marcado, o erro continua.
old_unknown = '''                if ([string]::IsNullOrWhiteSpace($code)) {
                    throw "Manutenção '$componentText' não reconhecida no REPARO '$Text'. Confira o texto e, se for um componente novo, cadastre-o em Componentes a faturar com o código da planilha."
                }'''
new_unknown = '''                if ([string]::IsNullOrWhiteSpace($code)) {
                    if ($AllowUnknownRepair) { continue }
                    throw "Manutenção '$componentText' não reconhecida no REPARO '$Text'. Confira o texto e, se for um componente novo, cadastre-o em Componentes a faturar com o código da planilha."
                }'''
if gen.count(old_unknown) != 2:
    raise RuntimeError(f'manutenções desconhecidas: esperado 2 trechos, encontrado {gen.count(old_unknown)}')
gen = gen.replace(old_unknown, new_unknown)

# Leitores de mestre recebem a opção, mas continuam estritos em todos os demais
# fluxos do Gerenciador porque o switch fica falso por padrão.
gen = rep(
    gen,
    '''function Read-MasterWorkbook {
    param(
        $Excel,
        [string]$Path,
        [switch]$RequireInvoices
    )''',
    '''function Read-MasterWorkbook {
    param(
        $Excel,
        [string]$Path,
        [switch]$RequireInvoices,
        [switch]$AllowUnknownRepair
    )''',
    'leitor CB5'
)
gen = rep(
    gen,
    '$repairInfo = Get-CB5RepairInfo $repair',
    '$repairInfo = Get-CB5RepairInfo $repair -AllowUnknownRepair:$AllowUnknownRepair',
    'uso parser CB5'
)
gen = rep(
    gen,
    '''function Read-TV5MasterWorkbook {
    param(
        $Excel,
        [string]$Path,
        [switch]$AllowBlankInvoices
    )''',
    '''function Read-TV5MasterWorkbook {
    param(
        $Excel,
        [string]$Path,
        [switch]$AllowBlankInvoices,
        [switch]$AllowUnknownRepair
    )''',
    'leitor TV5'
)
gen = rep(
    gen,
    '$repairInfo = Get-TV5RepairInfo $repair',
    '$repairInfo = Get-TV5RepairInfo $repair -AllowUnknownRepair:$AllowUnknownRepair',
    'uso parser TV5'
)

# Existem dois caminhos de união: conferência e execução. Nos dois, a leitura
# permissiva depende diretamente do checkbox Consumir saldo.
old_combine_read = '''            if ($product -eq "TV5") {
                $masterData = Read-TV5MasterWorkbook $excel $masterPath
            }
            else {
                $masterData = Read-MasterWorkbook $excel $masterPath -RequireInvoices
            }'''
new_combine_read = '''            if ($product -eq "TV5") {
                $masterData = Read-TV5MasterWorkbook $excel $masterPath -AllowUnknownRepair:(-not $consumeBalance)
            }
            else {
                $masterData = Read-MasterWorkbook $excel $masterPath -RequireInvoices -AllowUnknownRepair:(-not $consumeBalance)
            }'''
if gen.count(old_combine_read) != 2:
    raise RuntimeError(f'leitura da união: esperado 2 trechos, encontrado {gen.count(old_combine_read)}')
gen = gen.replace(old_combine_read, new_combine_read)

# Explica a regra na própria interface.
gen = rep(
    gen,
    '$toolTip.SetToolTip($combineConsumeBalanceCheck, "Marcado: consulta, valida e baixa o saldo somente após a união concluir. Desmarcado: junta os lotes sem consultar nem alterar o saldo e registra essa escolha.")',
    '$toolTip.SetToolTip($combineConsumeBalanceCheck, "Marcado: valida os reparos, consulta e baixa o saldo após a união. Desmarcado: não consulta o saldo e permite textos de REPARO não cadastrados, preservando-os na planilha unida.")',
    'tooltip do consumo'
)

gen = gen.replace(
    'Opção desmarcada: o saldo não seria consultado nem alterado. A união seria registrada como sem consumo.',
    'Opção desmarcada: o saldo não seria consultado nem alterado. Textos de REPARO não cadastrados seriam preservados sem bloquear a união.'
)
gen = gen.replace(
    'Consumo desmarcado: o saldo não foi consultado nem alterado. A união foi registrada como sem consumo.',
    'Consumo desmarcado: o saldo não foi consultado nem alterado. Textos de REPARO não cadastrados foram preservados na união.'
)

checks = [
    ('$script:AppVersion = "0.12.3"' in central, 'Central não ficou em 0.12.3'),
    ('$script:GeneratorVersion = "3.5.2"' in central, 'Central não referencia Gerenciador 3.5.2'),
    ('$script:AppVersion = "3.5.2"' in gen, 'Gerenciador não ficou em 3.5.2'),
    (gen.count('[switch]$AllowUnknownRepair') >= 4, 'switch permissivo não foi propagado'),
    (gen.count('if ($AllowUnknownRepair) { continue }') == 2, 'componentes desconhecidos não estão liberados nos dois produtos'),
    (gen.count('-AllowUnknownRepair:(-not $consumeBalance)') == 4, 'conferência/união não usam o checkbox nas quatro leituras'),
    ('if ($AllowUnknownRepair)' in gen and 'throw "REPARO' in gen, 'modo estrito foi removido por engano'),
    ('$row = @($item.Series, $item.Lot, $item.FullVersion, $item.Repair' in gen, 'texto REPARO deixou de ser preservado na saída')
]
for ok, msg in checks:
    if not ok:
        raise RuntimeError(msg)

central_path.write_text(central, encoding='utf-8-sig')
generator_path.write_text(gen, encoding='utf-8-sig')
print('OK: Juntar lotes permite REPARO livre somente quando o consumo de saldo está desmarcado.')
