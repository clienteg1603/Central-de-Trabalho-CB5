from pathlib import Path

p = Path('src/generated/Modulos/Gerador-de-Planilhas-CB5-TV5/Gerador Planilhas.ps1')
s = p.read_text(encoding='utf-8-sig')
anchor = '$script:BillingComponentStore = Read-BillingComponentStore -Path $script:BillingComponentStorePath'
count = s.count(anchor)
if count != 2:
    raise SystemExit(f'PRE COMPONENT RECOVERY: esperado 2 ocorrencias da leitura da base, encontrado {count}')
# A primeira é a carga inicial e será usada pela transformação de recuperação.
# A segunda ocorre no fluxo de restauração; torna-se sintaticamente distinta sem mudar o comportamento.
pos = s.rfind(anchor)
s = s[:pos] + '$script:BillingComponentStore = Read-BillingComponentStore -Path ([string]$script:BillingComponentStorePath)' + s[pos + len(anchor):]
p.write_text(s, encoding='utf-8')
print('PRE COMPONENT RECOVERY: OK - carga inicial ficou como ancora unica; restauração preservada.')
