#!/usr/bin/env python3
from pathlib import Path

central_path = Path('src/generated/Central de Trabalho.ps1')
generator_path = Path('src/generated/Modulos/Gerador-de-Planilhas-CB5-TV5/Gerador Planilhas.ps1')

central = central_path.read_text(encoding='utf-8-sig')
generator = generator_path.read_text(encoding='utf-8-sig')

replacements_central = [
    ('$script:AppVersion = "0.18.1"', '$script:AppVersion = "0.18.2"'),
    ('$script:GeneratorVersion = "3.7.2"', '$script:GeneratorVersion = "3.7.3"'),
]
for old, new in replacements_central:
    if old not in central:
        raise SystemExit(f'Central: marcador não encontrado: {old}')
    central = central.replace(old, new, 1)

replacements_generator = [
    ('$script:AppVersion = "3.7.2"', '$script:AppVersion = "3.7.3"'),
    (
        '$combineIntro.Text = "Selecione duas ou mais mestres $Product da mesma NF. Cada linha representa um lote; informe as manutenções adicionais diretamente na linha correspondente. A ordem abaixo será mantida no arquivo final."',
        '$combineIntro.Text = "Selecione uma ou mais mestres $Product. Quando houver mais de uma, elas devem pertencer à mesma NF. Cada linha representa um lote; informe as manutenções adicionais diretamente na linha correspondente. A ordem abaixo será mantida no arquivo final."'
    ),
    (
        '$combineStatusText.Text = "Adicione pelo menos duas planilhas mestre $Product para conferir ou juntar os lotes."',
        '$combineStatusText.Text = "Adicione uma ou mais planilhas mestre $Product para conferir ou juntar os lotes."'
    ),
    (
        'if ($combineGrid.Rows.Count -lt 2) {\n            throw "Adicione pelo menos duas planilhas mestres $product para conferir a união."\n        }',
        'if ($combineGrid.Rows.Count -lt 1) {\n            throw "Adicione pelo menos uma planilha mestre $product para conferir."\n        }'
    ),
    (
        'if ($combineGrid.Rows.Count -lt 2) {\n            throw "Adicione pelo menos duas planilhas mestres $product para juntar os lotes."\n        }',
        'if ($combineGrid.Rows.Count -lt 1) {\n            throw "Adicione pelo menos uma planilha mestre $product para processar os lotes."\n        }'
    ),
]

for old, new in replacements_generator:
    if old not in generator:
        raise SystemExit(f'Gerenciador: marcador não encontrado: {old[:120]}')
    generator = generator.replace(old, new, 1)

# A antiga trava de duas planilhas não pode permanecer em nenhum caminho do Juntar lotes.
for forbidden in (
    'combineGrid.Rows.Count -lt 2',
    'Adicione pelo menos duas planilhas mestres',
    'Selecione duas ou mais mestres',
):
    if forbidden in generator:
        raise SystemExit(f'Gerenciador: regra antiga ainda presente: {forbidden}')

central_path.write_text(central, encoding='utf-8-sig')
generator_path.write_text(generator, encoding='utf-8-sig')
print('0.18.2 / Gerenciador 3.7.3: Juntar lotes agora aceita uma única planilha mestre.')
