from pathlib import Path

cp = Path('src/generated/Central de Trabalho.ps1')
mp = Path('src/generated/Modulos/Central-de-Manutencao-CB5/Central Manutencao CB5.ps1')

c = cp.read_text(encoding='utf-8-sig')
m = mp.read_text(encoding='utf-8-sig')


def one(text, old, new, label):
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'UI FIT MAINT VALUE {label}: esperado 1, encontrado {count}')
    return text.replace(old, new, 1)

c = one(c, '$script:MaintenanceVersion = "0.6.14"', '$script:MaintenanceVersion = "0.6.15"', 'versao Central')
m = one(m, '$script:AppVersion = "0.6.14"', '$script:AppVersion = "0.6.15"', 'versao modulo')

# O teste visual real em 1366x768 mostrou que o valor dos quatro cartões ainda
# pedia cerca de 40 px dentro de uma célula de 31 px. O valor precisa reduzir
# tipografia antes de sacrificar o restante do viewport.
m = one(
    m,
    '''$decoration.Value.Font = [Drawing.Font]::new("Segoe UI Semibold", $(if ($profile -eq "Tight") { 16.5 } elseif ($profile -eq "Compact") { 18.0 } else { 20.0 }))''',
    '''$decoration.Value.Font = [Drawing.Font]::new("Segoe UI Semibold", $(if ($profile -eq "Tight") { 12.5 } elseif ($profile -eq "Compact") { 13.5 } else { 15.0 }))''',
    'fonte do valor hospedado'
)

# Dá prioridade vertical ao número sem aumentar a altura total do resumo.
m = one(
    m,
    '''                    if ($null -ne $contentTable -and $contentTable -is [Windows.Forms.TableLayoutPanel]) {
                        $contentTable.Padding = if ($profile -eq "Tight") { [Windows.Forms.Padding]::new(9,5,7,4) } elseif ($profile -eq "Compact") { [Windows.Forms.Padding]::new(10,6,8,5) } else { [Windows.Forms.Padding]::new(12,7,9,6) }
                    }''',
    '''                    if ($null -ne $contentTable -and $contentTable -is [Windows.Forms.TableLayoutPanel]) {
                        $contentTable.Padding = if ($profile -eq "Tight") { [Windows.Forms.Padding]::new(9,4,7,3) } elseif ($profile -eq "Compact") { [Windows.Forms.Padding]::new(10,4,8,4) } else { [Windows.Forms.Padding]::new(12,5,9,5) }
                        if ($contentTable.RowStyles.Count -ge 2) {
                            $contentTable.RowStyles[0].SizeType = [Windows.Forms.SizeType]::Percent
                            $contentTable.RowStyles[0].Height = 64
                            $contentTable.RowStyles[1].SizeType = [Windows.Forms.SizeType]::Percent
                            $contentTable.RowStyles[1].Height = 36
                        }
                    }''',
    'proporcao vertical do cartão'
)

c += '\n# POS_GERAL2_MAINTENANCE_VALUE_FIT_V02157\n'
m += '\n# POS_GERAL2_MAINTENANCE_VALUE_FIT_V00615\n'

for marker in ('$script:MaintenanceVersion = "0.6.15"', 'POS_GERAL2_MAINTENANCE_VALUE_FIT_V02157'):
    if marker not in c:
        raise SystemExit('UI FIT MAINT VALUE Central marcador ausente: ' + marker)
for marker in ('$script:AppVersion = "0.6.15"', '$contentTable.RowStyles[0].Height = 64', 'POS_GERAL2_MAINTENANCE_VALUE_FIT_V00615'):
    if marker not in m:
        raise SystemExit('UI FIT MAINT VALUE marcador ausente: ' + marker)

cp.write_text(c, encoding='utf-8')
mp.write_text(m, encoding='utf-8')
print('POS-GERAL 2 MAINT VALUE FIT: OK - valores dos cartões cabem na altura real de notebook sem aumentar a faixa de resumo.')
