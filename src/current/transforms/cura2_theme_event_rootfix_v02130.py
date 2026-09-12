from pathlib import Path

p = Path('src/generated/Central de Trabalho.ps1')
s = p.read_text(encoding='utf-8-sig')


def one(old, new, label):
    global s
    n = s.count(old)
    if n != 1:
        raise SystemExit(f'CURA2 EVENT {label}: esperado 1, encontrado {n}')
    s = s.replace(old, new, 1)


one('$script:AppVersion = "0.21.29"', '$script:AppVersion = "0.21.30"', 'versão Central')

# A causa raiz observada em uso real: SelectionChangeCommitted não cobre todas
# as maneiras pelas quais o ComboBox altera a seleção. O texto podia mudar sem
# disparar a reaplicação de Central + módulo. SelectedIndexChanged cobre todas.
one('$themeCombo.Add_SelectionChangeCommitted({', '$themeCombo.Add_SelectedIndexChanged({', 'evento do seletor')

# PowerShell pode devolver vários objetos de uma função. O código anterior só
# rejeitava um resultado que fosse exatamente [bool]$false; um array contendo
# saídas auxiliares e $false acabava aceito como sucesso. Sempre usamos o último
# resultado explícito do setter e exigimos que ele seja verdadeiro.
for module, setter, message in [
    ('Manutenção', 'Set-HostedMaintenanceTheme', 'A Manutenção recusou a aparência selecionada.'),
    ('Gerenciador', 'Set-HostedGeneratorTheme', 'O Gerenciador recusou a aparência selecionada.'),
    ('Controle de NF', 'Set-HostedNFEntradaTheme', 'O Controle de NF não conseguiu aplicar a aparência selecionada.'),
]:
    old = f'''                    $result = {setter} $hostTheme\n                    if ($result -is [bool] -and -not $result) {{ throw "{message}" }}\n                    return $true'''
    new = f'''                    $resultItems = @({setter} $hostTheme)\n                    if ($resultItems.Count -eq 0) {{ throw "{module} não retornou confirmação de aparência." }}\n                    $resultOk = [bool]$resultItems[$resultItems.Count - 1]\n                    if (-not $resultOk) {{ throw "{message}" }}\n                    return $true'''
    one(old, new, f'retorno escalar {module}')

# Contratos do hotfix.
checks = [
    '$script:AppVersion = "0.21.30"',
    '$themeCombo.Add_SelectedIndexChanged({',
    '$resultItems = @(Set-HostedGeneratorTheme $hostTheme)',
    '$resultItems = @(Set-HostedMaintenanceTheme $hostTheme)',
    '$resultItems = @(Set-HostedNFEntradaTheme $hostTheme)',
]
for marker in checks:
    if marker not in s:
        raise SystemExit(f'CURA2 EVENT contrato ausente: {marker}')
if '$themeCombo.Add_SelectionChangeCommitted({' in s:
    raise SystemExit('CURA2 EVENT: evento incompleto ainda presente')

p.write_text(s, encoding='utf-8')
print('CURA 2 evento: SelectedIndexChanged + retorno real dos módulos — OK')
