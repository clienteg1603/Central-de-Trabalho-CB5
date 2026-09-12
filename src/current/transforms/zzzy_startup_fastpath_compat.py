from pathlib import Path

path = Path('src/generated/Central de Trabalho.ps1')
text = path.read_text(encoding='utf-8-sig')

# Compatibilidade transitória entre o hotfix 0.21.35 e o transform de startup.
# O transform seguinte é quem grava os valores finais 0.21.36 / NF 2.6.10.
markers = (
    ('$script:AppVersion = "0.21.35"', '$script:AppVersion = "0.21.34"', 'versão intermediária da Central'),
    ('$script:NFEntradaVersion = "2.6.10"', '$script:NFEntradaVersion = "2.6.9"', 'versão intermediária do NF na Central'),
)
for old, new, label in markers:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: esperado 1 marcador, encontrado {count}')
    text = text.replace(old, new, 1)

path.write_text(text, encoding='utf-8')
print('STARTUP COMPAT: OK - cadeia de versões preparada para o fastpath 0.21.36.')
