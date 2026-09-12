from pathlib import Path

R = Path('src/generated')
p = R / 'Central de Trabalho.ps1'
s = p.read_text(encoding='utf-8-sig')


def one(text, old, new, label):
    n = text.count(old)
    if n != 1:
        raise SystemExit(f'CURA2 SIDEBAR {label}: esperado 1, encontrado {n}')
    return text.replace(old, new, 1)


# Versão da Central.
s = one(s, '$script:AppVersion = "0.21.30"', '$script:AppVersion = "0.21.31"', 'versão')

# A barra lateral é propriedade da Central. Ao trocar o tema com um módulo aberto,
# todos os ForeColor precisam ser reaplicados explicitamente; depender da herança
# deixa labels com a cor do tema anterior (texto escuro em fundo escuro, por exemplo).
helper = r'''function Refresh-CentralSidebarTheme {
    if ($null -eq $script:CurrentPalette -or $null -eq $sidebar) { return }

    $theme = Get-CentralSelectedTheme
    $sidebarColor = Get-SidebarColor $theme

    $sidebar.SuspendLayout()
    try {
        $sidebar.BackColor = $sidebarColor
        $brandPanel.BackColor = $sidebarColor
        $navPanel.BackColor = $sidebarColor
        $sidebarBottom.BackColor = $sidebarColor

        $stack = New-Object System.Collections.Stack
        $stack.Push($sidebar)
        while ($stack.Count -gt 0) {
            $control = $stack.Pop()

            if ($control -is [Windows.Forms.Label]) {
                $control.ForeColor = $script:CurrentPalette.Text
            }
            elseif ($control -is [Windows.Forms.ComboBox]) {
                $control.BackColor = $script:CurrentPalette.Input
                $control.ForeColor = $script:CurrentPalette.Text
            }
            elseif ($control -is [Windows.Forms.Button]) {
                $control.ForeColor = $script:CurrentPalette.Text
            }

            foreach ($child in $control.Controls) {
                $stack.Push($child)
            }
        }

        # Exceções semânticas da barra lateral.
        $brandMark.ForeColor = [Drawing.Color]::White
        $brandSub.ForeColor = $script:CurrentPalette.Muted
        $sidebarStatusSub.ForeColor = $script:CurrentPalette.Muted
        $sidebarVersion.ForeColor = $script:CurrentPalette.Muted
        $themeCombo.BackColor = $script:CurrentPalette.Input
        $themeCombo.ForeColor = $script:CurrentPalette.Text

        # Reaplica o estado ativo/inativo da navegação com a paleta atual.
        Set-ActiveNavigation $script:ActiveNavName
    }
    finally {
        $sidebar.ResumeLayout($true)
    }

    $sidebar.Invalidate($true)
    $sidebar.Update()
    $sidebar.Refresh()
}'''

marker = 'function Apply-CentralTheme {'
if marker not in s:
    raise SystemExit('CURA2 SIDEBAR: Apply-CentralTheme não encontrada')
s = s.replace(marker, helper + '\n\n' + marker, 1)

# Garante uma reaplicação final da casca lateral DEPOIS de todas as atribuições de
# cor feitas pelo tema. Inserimos antes do fechamento real da função.
start = s.find(marker)
next_fn = s.find('\nfunction ', start + len(marker))
if next_fn < 0:
    raise SystemExit('CURA2 SIDEBAR: limite de Apply-CentralTheme não encontrado')
block = s[start:next_fn]
close = block.rfind('\n}')
if close < 0:
    raise SystemExit('CURA2 SIDEBAR: fechamento de Apply-CentralTheme não encontrado')
block = block[:close] + '''\n\n    # CURA 2.6 — repinta a barra lateral por último para impedir texto herdado do tema anterior.\n    Refresh-CentralSidebarTheme\n    Update-CentralAvailabilityState\n''' + block[close:]
s = s[:start] + block + s[next_fn:]

# Contratos: a correção precisa sobreviver ao empacotamento.
checks = [
    '$script:AppVersion = "0.21.31"',
    'function Refresh-CentralSidebarTheme {',
    '$stack = New-Object System.Collections.Stack',
    '$control.ForeColor = $script:CurrentPalette.Text',
    '$brandMark.ForeColor = [Drawing.Color]::White',
    'Set-ActiveNavigation $script:ActiveNavName',
    '# CURA 2.6 — repinta a barra lateral por último',
]
for c in checks:
    if c not in s:
        raise SystemExit(f'CURA2 SIDEBAR contrato ausente: {c}')

p.write_text(s, encoding='utf-8')
print('CURA 2.6: barra lateral da Central reaplicada integralmente — OK')
