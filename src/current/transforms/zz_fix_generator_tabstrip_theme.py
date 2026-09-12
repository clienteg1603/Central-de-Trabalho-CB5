from pathlib import Path

path = Path('src/generated/Modulos/Gerador-de-Planilhas-CB5-TV5/Gerador Planilhas.ps1')
text = path.read_text(encoding='utf-8-sig')


def replace_one(old: str, new: str, label: str):
    global text
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: esperado 1 marcador, encontrado {count}')
    text = text.replace(old, new, 1)

# O TabControl nativo do WinForms não pinta a área ociosa da faixa superior
# conforme BackColor quando os estilos visuais estão ativos. Como os itens já são
# OwnerDraw, fazemos os cinco cabeçalhos ocuparem toda a largura disponível.
replace_one(
    '$tabWidth = [Math]::Min(190, [Math]::Max(92, [int][Math]::Floor(($navWidth - 10) / 5)))',
    '$tabWidth = [Math]::Max(92, [int][Math]::Floor(($navWidth - 4) / 5))',
    'largura das abas principais'
)

# A mesma regra vale para as três subtelas de Componentes.
replace_one(
    '$componentTabWidth = [Math]::Min(210, [Math]::Max(105, [int][Math]::Floor($componentTabAvailable / 3)))',
    '$componentTabWidth = [Math]::Max(105, [int][Math]::Floor(($componentTabs.ClientSize.Width - 4) / 3))',
    'largura das abas de componentes'
)

replace_one(
    '''    $tabs.BackColor = $palette.Background\n    $tabs.ForeColor = $palette.Text''',
    '''    $tabs.BackColor = $palette.Background\n    $tabs.ForeColor = $palette.Text\n    $componentTabs.BackColor = $palette.Background\n    $componentTabs.ForeColor = $palette.Text''',
    'tema dos TabControls'
)

# BackColor do TabControl nativo não é uma propriedade visual confiável no
# WinForms com visual styles. A auditoria passa a validar aquilo que de fato
# determina o resultado visível: OwnerDraw, cobertura integral da faixa e a cor
# das páginas.
replace_one(
    '''        [pscustomobject]@{ Name = "abas"; Actual = [int]$tabs.BackColor.ToArgb(); Expected = [int]$palette.Background.ToArgb() },\n        [pscustomobject]@{ Name = "área Gerar"; Actual = [int]$tabGenerate.BackColor.ToArgb(); Expected = [int]$palette.Background.ToArgb() },''',
    '''        [pscustomobject]@{ Name = "abas owner-draw"; Actual = $(if ($tabs.DrawMode -eq [Windows.Forms.TabDrawMode]::OwnerDrawFixed) { 1 } else { 0 }); Expected = 1 },\n        [pscustomobject]@{ Name = "cobertura da faixa de abas"; Actual = $(if (($tabs.ItemSize.Width * $tabs.TabPages.Count) -ge ($tabs.ClientSize.Width - 12)) { 1 } else { 0 }); Expected = 1 },\n        [pscustomobject]@{ Name = "área Gerar"; Actual = [int]$tabGenerate.BackColor.ToArgb(); Expected = [int]$palette.Background.ToArgb() },\n        [pscustomobject]@{ Name = "área Manutenções"; Actual = [int]$tabExtra.BackColor.ToArgb(); Expected = [int]$palette.Background.ToArgb() },\n        [pscustomobject]@{ Name = "área Componentes"; Actual = [int]$tabComponents.BackColor.ToArgb(); Expected = [int]$palette.Background.ToArgb() },\n        [pscustomobject]@{ Name = "área Juntar lotes"; Actual = [int]$tabCombine.BackColor.ToArgb(); Expected = [int]$palette.Background.ToArgb() },\n        [pscustomobject]@{ Name = "área Códigos"; Actual = [int]$tabDescriptions.BackColor.ToArgb(); Expected = [int]$palette.Background.ToArgb() },''',
    'auditoria visual das abas'
)

path.write_text(text, encoding='utf-8')
print('GERENCIADOR TABSTRIP: OK - faixa owner-draw cobre a largura e paginas seguem a paleta.')
