from pathlib import Path

path = Path('src/generated/Modulos/Central-de-Manutencao-CB5/Central Manutencao CB5.ps1')
text = path.read_text(encoding='utf-8-sig')


def replace_one(old: str, new: str, label: str):
    global text
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: esperado 1 marcador, encontrado {count}')
    text = text.replace(old, new, 1)

# No modo hospedado a faixa nativa do TabControl fica deliberadamente fora da área
# visível (Y=-31). A navegação que o usuário realmente vê é HostedSectionNavPanel +
# dashboardNavigation. BackColor do TabControl nativo não é uma propriedade visual
# confiável com visual styles, portanto a auditoria precisa medir a navegação real.
replace_one(
    '''    $saveExpected = if ([string]$savePassageButton.Tag -eq "Primary") { $palette.Accent } else { $palette.Surface }\n    $checks = @(''',
    '''    $saveExpected = if ([string]$savePassageButton.Tag -eq "Primary") { $palette.Accent } else { $palette.Surface }\n    $historyNavExpected = if ([string]$dashboardHistoryButton.Tag -eq "Primary") { $palette.Accent } else { $palette.Surface }\n    $checks = @(''',
    'cor esperada da navegação'
)

replace_one(
    '''        [pscustomobject]@{ Name = "abas"; Actual = [int]$mainTabs.BackColor.ToArgb(); Expected = [int]$palette.Background.ToArgb() },\n        [pscustomobject]@{ Name = "painel inicial"; Actual = [int]$dashboardTab.BackColor.ToArgb(); Expected = [int]$palette.Background.ToArgb() },\n        [pscustomobject]@{ Name = "painel passagem"; Actual = [int]$passageTab.BackColor.ToArgb(); Expected = [int]$palette.Background.ToArgb() },''',
    '''        [pscustomobject]@{ Name = "abas owner-draw"; Actual = $(if ($mainTabs.DrawMode -eq [Windows.Forms.TabDrawMode]::OwnerDrawFixed) { 1 } else { 0 }); Expected = 1 },\n        [pscustomobject]@{ Name = "faixa de navegação hospedada"; Actual = [int]$script:HostedSectionNavPanel.BackColor.ToArgb(); Expected = [int]$palette.Background.ToArgb() },\n        [pscustomobject]@{ Name = "botão da navegação hospedada"; Actual = [int]$dashboardHistoryButton.BackColor.ToArgb(); Expected = [int]$historyNavExpected.ToArgb() },\n        [pscustomobject]@{ Name = "painel inicial"; Actual = [int]$dashboardTab.BackColor.ToArgb(); Expected = [int]$palette.Background.ToArgb() },\n        [pscustomobject]@{ Name = "painel passagem"; Actual = [int]$passageTab.BackColor.ToArgb(); Expected = [int]$palette.Background.ToArgb() },\n        [pscustomobject]@{ Name = "painel histórico"; Actual = [int]$historyTab.BackColor.ToArgb(); Expected = [int]$palette.Background.ToArgb() },\n        [pscustomobject]@{ Name = "painel estatísticas"; Actual = [int]$statisticsTab.BackColor.ToArgb(); Expected = [int]$palette.Background.ToArgb() },\n        [pscustomobject]@{ Name = "painel diagnóstico"; Actual = [int]$diagnosisTab.BackColor.ToArgb(); Expected = [int]$palette.Background.ToArgb() },\n        [pscustomobject]@{ Name = "painel esquemáticos"; Actual = [int]$schematicsTab.BackColor.ToArgb(); Expected = [int]$palette.Background.ToArgb() },\n        [pscustomobject]@{ Name = "painel regras"; Actual = [int]$rulesTab.BackColor.ToArgb(); Expected = [int]$palette.Background.ToArgb() },''',
    'auditoria da navegação visível'
)

path.write_text(text, encoding='utf-8')
print('MANUTENCAO THEME AUDIT: OK - auditoria mede a navegacao realmente visivel no modo hospedado.')
