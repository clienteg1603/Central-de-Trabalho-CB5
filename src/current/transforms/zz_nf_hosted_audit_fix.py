from pathlib import Path

path = Path('src/generated/Modulos/Controle-NF-Entrada/Controle NF Entrada.ps1')
text = path.read_text(encoding='utf-8-sig')

old = '''        [pscustomobject]@{ Name = "abas"; Actual = [int]$mainTabs.BackColor.ToArgb(); Expected = [int]$palette.Background.ToArgb() },\n        [pscustomobject]@{ Name = "aba computador"; Actual = [int]$computerTab.BackColor.ToArgb(); Expected = [int]$palette.Background.ToArgb() },'''
new = '''        [pscustomobject]@{ Name = "abas nativas estáveis"; Actual = $(if ($mainTabs.DrawMode -eq [Windows.Forms.TabDrawMode]::Normal -and $mainTabs.TabPages.Count -eq 6) { 1 } else { 0 }); Expected = 1 },\n        [pscustomobject]@{ Name = "aba computador"; Actual = [int]$computerTab.BackColor.ToArgb(); Expected = [int]$palette.Background.ToArgb() },\n        [pscustomobject]@{ Name = "aba teclado"; Actual = [int]$keyboardTab.BackColor.ToArgb(); Expected = [int]$palette.Background.ToArgb() },\n        [pscustomobject]@{ Name = "aba movimentações"; Actual = [int]$movementTab.BackColor.ToArgb(); Expected = [int]$palette.Background.ToArgb() },\n        [pscustomobject]@{ Name = "aba histórico"; Actual = [int]$historyTab.BackColor.ToArgb(); Expected = [int]$palette.Background.ToArgb() },\n        [pscustomobject]@{ Name = "aba segurança"; Actual = [int]$securityTab.BackColor.ToArgb(); Expected = [int]$palette.Background.ToArgb() },\n        [pscustomobject]@{ Name = "aba resumo"; Actual = [int]$summaryTab.BackColor.ToArgb(); Expected = [int]$palette.Background.ToArgb() },'''

count = text.count(old)
if count != 1:
    raise SystemExit(f'auditoria de abas NF: esperado 1 marcador, encontrado {count}')
text = text.replace(old, new, 1)
path.write_text(text, encoding='utf-8')
print('NF AUDIT: OK - valida abas nativas sem depender de TabControl.BackColor.')
