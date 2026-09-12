from pathlib import Path

central_path = Path('src/generated/Central de Trabalho.ps1')
nf_path = Path('src/generated/Modulos/Controle-NF-Entrada/Controle NF Entrada.ps1')

central = central_path.read_text(encoding='utf-8-sig')
nf = nf_path.read_text(encoding='utf-8-sig')


def one(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: esperado 1 marcador, encontrado {count}')
    return text.replace(old, new, 1)


# CURA 8: fechamento final da cura visual/preventiva no canal Teste.
central = one(central, '$script:AppVersion = "0.21.45"', '$script:AppVersion = "0.21.46"', 'versao Central')
central = one(central, '$script:NFEntradaVersion = "2.6.14"', '$script:NFEntradaVersion = "2.6.15"', 'versao NF na Central')
nf = one(nf, '$script:ModuleVersion = "2.6.14"', '$script:ModuleVersion = "2.6.15"', 'versao NF')

# Botões secundários ativos usam texto branco. Isso mantém a leitura uniforme
# com LIMPAR/CSV e com a navegação escura introduzida na etapa anterior.
old_secondary = '''        default {
            $Button.BackColor = $script:CurrentPalette.Card
            $Button.ForeColor = $script:CurrentPalette.Text
            $Button.FlatAppearance.BorderColor = $script:CurrentPalette.Border
            $Button.FlatAppearance.BorderSize = 1
        }'''
new_secondary = '''        default {
            $Button.BackColor = $script:CurrentPalette.Card
            $Button.ForeColor = [Drawing.Color]::White
            $Button.FlatAppearance.BorderColor = $script:CurrentPalette.Border
            $Button.FlatAppearance.BorderSize = 1
        }'''
nf = one(nf, old_secondary, new_secondary, 'contraste dos botoes secundarios')

# WinForms substitui ForeColor pelo texto de sistema quando Button.Enabled=False.
# EDITAR e SAÍDA ficam desabilitados sem seleção, que é exatamente o estado da
# captura enviada pelo usuário. Pintamos apenas o texto desabilitado por cima do
# desenho nativo, mantendo Enabled=False e toda a segurança operacional.
style_anchor = '''    Set-NFRoundedRegion $Button 10
}'''
readable_disabled = '''    Set-NFRoundedRegion $Button 10
}

function Add-NFReadableDisabledText {
    param([Windows.Forms.Button]$Button)
    if ($null -eq $Button) { return }
    $Button.Add_Paint({
        param($sender, $eventArgs)
        if ($sender.Enabled) { return }
        $flags = [Windows.Forms.TextFormatFlags]::HorizontalCenter -bor
                 [Windows.Forms.TextFormatFlags]::VerticalCenter -bor
                 [Windows.Forms.TextFormatFlags]::SingleLine -bor
                 [Windows.Forms.TextFormatFlags]::NoPrefix
        [Windows.Forms.TextRenderer]::DrawText(
            $eventArgs.Graphics,
            [string]$sender.Text,
            $sender.Font,
            $sender.ClientRectangle,
            [Drawing.Color]::White,
            $flags
        )
    })
}'''
nf = one(nf, style_anchor, readable_disabled, 'helper de texto desabilitado')

nf = one(
    nf,
    '$editButton.Text = "EDITAR"; $editButton.Width = 78; $editButton.Height = 34; Set-NFButtonStyle $editButton "Secondary"',
    '$editButton.Text = "EDITAR"; $editButton.Width = 78; $editButton.Height = 34; Set-NFButtonStyle $editButton "Secondary"; Add-NFReadableDisabledText $editButton',
    'contraste do EDITAR'
)
nf = one(
    nf,
    '$outputButton.Text = "SAÍDA"; $outputButton.Width = 78; $outputButton.Height = 34; Set-NFButtonStyle $outputButton "Secondary"',
    '$outputButton.Text = "SAÍDA"; $outputButton.Width = 78; $outputButton.Height = 34; Set-NFButtonStyle $outputButton "Secondary"; Add-NFReadableDisabledText $outputButton',
    'contraste da SAIDA'
)

# Contratos finais da cura: tema único, navegação nova e proteção do mecanismo
# nativo de abas permanecem obrigatórios.
for marker in (
    'NF_SECTION_NAV_MAINTENANCE_STYLE_V02614',
    'function Update-NFSectionNavigation',
    'function Add-NFReadableDisabledText',
    'Add-NFReadableDisabledText $editButton',
    'Add-NFReadableDisabledText $outputButton',
):
    if marker not in nf:
        raise SystemExit('CURA 8: marcador ausente no NF: ' + marker)

for forbidden in (
    '$mainTabs.Add_SizeChanged',
    '$mainTabs.Add_HandleCreated',
    '$mainTabs.DrawMode = [Windows.Forms.TabDrawMode]::OwnerDrawFixed',
    '$mainTabs.ItemSize',
):
    if forbidden in nf:
        raise SystemExit('CURA 8: mecanismo proibido de abas reapareceu: ' + forbidden)

central += '\n# CURA8_FINALIZADA_V02146\n'
nf += '\n# CURA8_NF_CONTRASTE_V02615\n'

central_path.write_text(central, encoding='utf-8')
nf_path.write_text(nf, encoding='utf-8')
print('CURA 8: OK - contraste de EDITAR/SAIDA corrigido mantendo botoes desabilitados e navegacao/abas estaveis.')
