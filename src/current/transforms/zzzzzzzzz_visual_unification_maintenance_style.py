from pathlib import Path

central_path = Path('src/generated/Central de Trabalho.ps1')
generator_path = Path('src/generated/Modulos/Gerador-de-Planilhas-CB5-TV5/Gerador Planilhas.ps1')
nf_path = Path('src/generated/Modulos/Controle-NF-Entrada/Controle NF Entrada.ps1')

central = central_path.read_text(encoding='utf-8-sig')
generator = generator_path.read_text(encoding='utf-8-sig')
nf = nf_path.read_text(encoding='utf-8-sig')


def one(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: esperado 1 marcador, encontrado {count}')
    return text.replace(old, new, 1)


def many(text: str, old: str, new: str, minimum: int, label: str) -> str:
    count = text.count(old)
    if count < minimum:
        raise SystemExit(f'{label}: esperado pelo menos {minimum} marcador(es), encontrado {count}')
    return text.replace(old, new)


# ---------------------------------------------------------------------------
# VERSÕES — continuação da CURA 6, somente canal Teste.
# ---------------------------------------------------------------------------
central = one(central, '$script:AppVersion = "0.21.40"', '$script:AppVersion = "0.21.41"', 'versao Central')
central = one(central, '$script:GeneratorVersion = "3.7.12"', '$script:GeneratorVersion = "3.7.13"', 'versao Gerenciador na Central')
central = one(central, '$script:NFEntradaVersion = "2.6.11"', '$script:NFEntradaVersion = "2.6.12"', 'versao NF na Central')
generator = one(generator, '$script:AppVersion = "3.7.12"', '$script:AppVersion = "3.7.13"', 'versao Gerenciador')
nf = one(nf, '$script:ModuleVersion = "2.6.11"', '$script:ModuleVersion = "2.6.12"', 'versao NF')


# ---------------------------------------------------------------------------
# GERENCIADOR — mesma linguagem dos botões da Central de Manutenção:
# ciano = principal/seleção, laranja = ação final, escuro contornado = secundário.
# Mantemos todos os eventos e fluxos existentes.
# ---------------------------------------------------------------------------
old_generator_button = '''function Set-ButtonTheme {
    param($Button, $Palette)
    $Button.FlatStyle = [Windows.Forms.FlatStyle]::Flat
    $Button.FlatAppearance.BorderSize = 1
    $role = [string]$Button.Tag
    if ($role -eq "Primary") {
        $Button.BackColor = $Palette.Accent
        $Button.ForeColor = $Palette.AccentText
        $Button.FlatAppearance.BorderColor = $Palette.Accent
    }
    else {
        $Button.BackColor = $Palette.Surface
        $Button.ForeColor = $Palette.Text
        $Button.FlatAppearance.BorderColor = $Palette.Border
    }
}'''
new_generator_button = '''function Set-ButtonTheme {
    param($Button, $Palette)
    $Button.FlatStyle = [Windows.Forms.FlatStyle]::Flat
    $Button.Cursor = [Windows.Forms.Cursors]::Hand
    $Button.Font = New-Object Drawing.Font("Segoe UI Semibold", 9)
    $role = [string]$Button.Tag
    if ($role -eq "Primary") {
        $Button.BackColor = $Palette.Accent
        $Button.ForeColor = $Palette.AccentText
        $Button.FlatAppearance.BorderSize = 0
    }
    elseif ($role -eq "Action") {
        # Mesma ação laranja que dá destaque ao + NOVA PASSAGEM da Manutenção.
        $Button.BackColor = [Drawing.Color]::FromArgb(244, 142, 40)
        $Button.ForeColor = [Drawing.Color]::FromArgb(27, 24, 17)
        $Button.FlatAppearance.BorderSize = 0
    }
    else {
        $Button.BackColor = $Palette.Surface
        $Button.ForeColor = $Palette.Text
        $Button.FlatAppearance.BorderColor = $Palette.Border
        $Button.FlatAppearance.BorderSize = 1
    }
    Set-GeneratorRoundedRegion $Button 7
}'''
generator = one(generator, old_generator_button, new_generator_button, 'estilo dos botoes do Gerenciador')

# No tema único Técnico industrial, o acento do Gerenciador passa a ser o mesmo
# ciano da Manutenção inclusive quando o produto selecionado é TV5.
generator = one(
    generator,
    '$accent = if ($Product -eq "TV5") { [Drawing.Color]::FromArgb(72, 202, 143) } else { [Drawing.Color]::FromArgb(44, 189, 197) }\n            return [pscustomobject]@{',
    '$accent = [Drawing.Color]::FromArgb(44, 189, 197)\n            return [pscustomobject]@{',
    'acento tecnico do Gerenciador'
)

# As duas ações finais ficam laranja; seleção de mestre e demais ações principais
# permanecem ciano, reproduzindo a hierarquia da Central de Manutenção.
generator = one(generator, '$generateButton.Tag = "Primary"', '$generateButton.Tag = "Action"', 'acao gerar planilhas')
# O botão de união aparece no mesmo rodapé e é a ação final equivalente.
combine_marker = '$combineGenerateButton.Tag = "Primary"'
if combine_marker in generator:
    generator = one(generator, combine_marker, '$combineGenerateButton.Tag = "Action"', 'acao juntar lotes')
else:
    # Algumas bases antigas herdam o papel do botão ao serem alternadas. Nesse
    # caso definimos o papel logo após a criação, sem tocar no evento Click.
    anchor = '$combineGenerateButton = New-Object Windows.Forms.Button\n'
    generator = one(generator, anchor, anchor + '$combineGenerateButton.Tag = "Action"\n', 'papel do botao juntar lotes')

# Arredondamento também é reaplicado quando o layout responsivo recalcula tamanhos.
generator = one(
    generator,
    '''    foreach ($button in @($masterButton, $openDestinationCardButton, $previewMasterButton, $copyStatusButton, $componentSearchClearButton, $componentLaunchButton, $componentAdjustButton, $componentNewButton, $componentEditButton, $componentBackupButton, $componentRestoreButton, $combineAddButton, $combineRemoveButton, $combineUpButton, $combineDownButton, $combineClearButton, $combineCopyQuantitiesButton, $combinePasteQuantitiesButton, $previewCombineButton, $copyCombineStatusButton, $openFolderButton, $updateMasterButton, $generateButton, $combineGenerateButton)) {
        Set-ButtonTheme $button $palette
    }''',
    '''    foreach ($button in @($masterButton, $openDestinationCardButton, $previewMasterButton, $copyStatusButton, $componentSearchClearButton, $componentLaunchButton, $componentAdjustButton, $componentNewButton, $componentEditButton, $componentBackupButton, $componentRestoreButton, $combineAddButton, $combineRemoveButton, $combineUpButton, $combineDownButton, $combineClearButton, $combineCopyQuantitiesButton, $combinePasteQuantitiesButton, $previewCombineButton, $copyCombineStatusButton, $openFolderButton, $updateMasterButton, $generateButton, $combineGenerateButton)) {
        Set-ButtonTheme $button $palette
        Set-GeneratorRoundedRegion $button 7
    }''',
    'reaplicacao visual dos botoes do Gerenciador'
)

# Auditoria hospedada: o botão final agora é Action (laranja), não Accent.
generator = one(
    generator,
    '[pscustomobject]@{ Name = "botão principal"; Actual = [int]$generateButton.BackColor.ToArgb(); Expected = [int]$palette.Accent.ToArgb() },',
    '[pscustomobject]@{ Name = "botão principal"; Actual = [int]$generateButton.BackColor.ToArgb(); Expected = [int][Drawing.Color]::FromArgb(244, 142, 40).ToArgb() },',
    'auditoria do botao principal do Gerenciador'
)


# ---------------------------------------------------------------------------
# CONTROLE DE NF — aproxima a paleta e os botões do padrão da Manutenção.
# NÃO toca em DrawMode, ItemSize, SizeChanged ou HandleCreated das abas.
# ---------------------------------------------------------------------------
old_nf_technical = '''        "Técnico industrial" {
            return [pscustomobject]@{
                Background = [Drawing.Color]::FromArgb(16, 20, 22)
                Surface = [Drawing.Color]::FromArgb(22, 28, 31)
                Card = [Drawing.Color]::FromArgb(29, 36, 39)
                Input = [Drawing.Color]::FromArgb(18, 24, 27)
                Text = [Drawing.Color]::FromArgb(244, 247, 248)
                Muted = [Drawing.Color]::FromArgb(170, 181, 184)
                Border = [Drawing.Color]::FromArgb(60, 72, 76)
                Accent = [Drawing.Color]::FromArgb(35, 179, 158)
                AccentStrong = [Drawing.Color]::FromArgb(27, 151, 134)
                AccentText = [Drawing.Color]::White
                Success = [Drawing.Color]::FromArgb(48, 207, 145)
                SuccessBack = [Drawing.Color]::FromArgb(17, 70, 55)
                Warning = [Drawing.Color]::FromArgb(244, 190, 74)
                WarningBack = [Drawing.Color]::FromArgb(77, 58, 15)
                Danger = [Drawing.Color]::FromArgb(239, 108, 102)
                DangerBack = [Drawing.Color]::FromArgb(78, 28, 26)
            }
        }'''
new_nf_technical = '''        "Técnico industrial" {
            return [pscustomobject]@{
                Background = [Drawing.Color]::FromArgb(18, 23, 25)
                Surface = [Drawing.Color]::FromArgb(27, 35, 38)
                Card = [Drawing.Color]::FromArgb(34, 43, 46)
                Input = [Drawing.Color]::FromArgb(18, 23, 25)
                Text = [Drawing.Color]::FromArgb(242, 246, 245)
                Muted = [Drawing.Color]::FromArgb(174, 188, 186)
                Border = [Drawing.Color]::FromArgb(62, 77, 80)
                Accent = [Drawing.Color]::FromArgb(44, 189, 197)
                AccentStrong = [Drawing.Color]::FromArgb(44, 189, 197)
                AccentText = [Drawing.Color]::FromArgb(9, 24, 28)
                Action = [Drawing.Color]::FromArgb(244, 142, 40)
                ActionText = [Drawing.Color]::FromArgb(27, 24, 17)
                Success = [Drawing.Color]::FromArgb(72, 202, 143)
                SuccessBack = [Drawing.Color]::FromArgb(22, 72, 57)
                Warning = [Drawing.Color]::FromArgb(246, 186, 68)
                WarningBack = [Drawing.Color]::FromArgb(86, 59, 13)
                Danger = [Drawing.Color]::FromArgb(239, 108, 102)
                DangerBack = [Drawing.Color]::FromArgb(78, 28, 26)
            }
        }'''
nf = one(nf, old_nf_technical, new_nf_technical, 'paleta Tecnico industrial do NF')

old_nf_button = '''function Set-NFButtonStyle {
    param([Windows.Forms.Button]$Button, [ValidateSet("Primary", "Secondary", "Danger")][string]$Kind = "Secondary")
    $Button.Tag = "Theme.Button.$Kind"
    $Button.FlatStyle = [Windows.Forms.FlatStyle]::Flat
    $Button.Cursor = [Windows.Forms.Cursors]::Hand
    $Button.Font = [Drawing.Font]::new("Segoe UI Semibold", 9)
    switch ($Kind) {
        "Primary" {
            $Button.BackColor = $script:CurrentPalette.AccentStrong
            $Button.ForeColor = $script:CurrentPalette.AccentText
            $Button.FlatAppearance.BorderSize = 0
        }
        "Danger" {
            $Button.BackColor = $script:CurrentPalette.DangerBack
            $Button.ForeColor = $script:CurrentPalette.Danger
            $Button.FlatAppearance.BorderColor = $script:CurrentPalette.Danger
            $Button.FlatAppearance.BorderSize = 1
        }
        default {
            $Button.BackColor = $script:CurrentPalette.Card
            $Button.ForeColor = $script:CurrentPalette.Text
            $Button.FlatAppearance.BorderColor = $script:CurrentPalette.Border
            $Button.FlatAppearance.BorderSize = 1
        }
    }
}'''
new_nf_button = '''function Set-NFRoundedRegion {
    param([Windows.Forms.Control]$Control, [int]$Radius = 7)
    if ($null -eq $Control -or $Control.Width -le 2 -or $Control.Height -le 2) { return }
    try {
        $diameter = [Math]::Max(2, $Radius * 2)
        $rect = [Drawing.Rectangle]::new(0, 0, $Control.Width - 1, $Control.Height - 1)
        $path = New-Object Drawing.Drawing2D.GraphicsPath
        $path.AddArc($rect.Left, $rect.Top, $diameter, $diameter, 180, 90)
        $path.AddArc($rect.Right - $diameter, $rect.Top, $diameter, $diameter, 270, 90)
        $path.AddArc($rect.Right - $diameter, $rect.Bottom - $diameter, $diameter, $diameter, 0, 90)
        $path.AddArc($rect.Left, $rect.Bottom - $diameter, $diameter, $diameter, 90, 90)
        $path.CloseFigure()
        $oldRegion = $Control.Region
        $Control.Region = New-Object Drawing.Region($path)
        $path.Dispose()
        if ($null -ne $oldRegion) { $oldRegion.Dispose() }
    } catch {}
}

function Set-NFButtonStyle {
    param([Windows.Forms.Button]$Button, [ValidateSet("Primary", "Action", "Secondary", "Danger")][string]$Kind = "Secondary")
    $Button.Tag = "Theme.Button.$Kind"
    $Button.FlatStyle = [Windows.Forms.FlatStyle]::Flat
    $Button.Cursor = [Windows.Forms.Cursors]::Hand
    $Button.Font = [Drawing.Font]::new("Segoe UI Semibold", 9)
    switch ($Kind) {
        "Primary" {
            $Button.BackColor = $script:CurrentPalette.AccentStrong
            $Button.ForeColor = $script:CurrentPalette.AccentText
            $Button.FlatAppearance.BorderSize = 0
        }
        "Action" {
            $actionBack = if ($script:CurrentPalette.PSObject.Properties.Name -contains "Action") { $script:CurrentPalette.Action } else { [Drawing.Color]::FromArgb(244, 142, 40) }
            $actionText = if ($script:CurrentPalette.PSObject.Properties.Name -contains "ActionText") { $script:CurrentPalette.ActionText } else { [Drawing.Color]::FromArgb(27, 24, 17) }
            $Button.BackColor = $actionBack
            $Button.ForeColor = $actionText
            $Button.FlatAppearance.BorderSize = 0
        }
        "Danger" {
            $Button.BackColor = $script:CurrentPalette.DangerBack
            $Button.ForeColor = $script:CurrentPalette.Danger
            $Button.FlatAppearance.BorderColor = $script:CurrentPalette.Danger
            $Button.FlatAppearance.BorderSize = 1
        }
        default {
            $Button.BackColor = $script:CurrentPalette.Card
            $Button.ForeColor = $script:CurrentPalette.Text
            $Button.FlatAppearance.BorderColor = $script:CurrentPalette.Border
            $Button.FlatAppearance.BorderSize = 1
        }
    }
    Set-NFRoundedRegion $Button 7
}'''
nf = one(nf, old_nf_button, new_nf_button, 'estilo dos botoes do NF')

# Ações de criação/importação em laranja, como a ação principal da Manutenção.
nf = many(nf, 'Set-NFButtonStyle $importButton "Secondary"', 'Set-NFButtonStyle $importButton "Action"', 2, 'papel do Importar Excel')
nf = many(nf, 'Set-NFButtonStyle $newButton "Primary"', 'Set-NFButtonStyle $newButton "Action"', 2, 'papel da Nova NF')

# Reaplicação semântica passa a reconhecer Action.
nf = one(
    nf,
    '''        if ($role -eq "Theme.Button.Primary") { Set-NFButtonStyle $Control "Primary" }
        elseif ($role -eq "Theme.Button.Danger") { Set-NFButtonStyle $Control "Danger" }
        else { Set-NFButtonStyle $Control "Secondary" }''',
    '''        if ($role -eq "Theme.Button.Primary") { Set-NFButtonStyle $Control "Primary" }
        elseif ($role -eq "Theme.Button.Action") { Set-NFButtonStyle $Control "Action" }
        elseif ($role -eq "Theme.Button.Danger") { Set-NFButtonStyle $Control "Danger" }
        else { Set-NFButtonStyle $Control "Secondary" }''',
    'papel Action na arvore do NF'
)

# Na reaplicação final da CURA 2, Importar e Nova NF não podem ser rebaixados
# novamente para Secondary/Primary.
nf = one(
    nf,
    'foreach ($button in @($importButton,$editButton,$outputButton,$clearFiltersButton,$exportListButton,$movementExportButton,$movementOpenButton,$historyDetailsButton,$historyExportButton,$integrityButton,$manualBackupButton,$restoreBackupButton,$reviewIssuesButton)) {',
    'foreach ($button in @($editButton,$outputButton,$clearFiltersButton,$exportListButton,$movementExportButton,$movementOpenButton,$historyDetailsButton,$historyExportButton,$integrityButton,$manualBackupButton,$restoreBackupButton,$reviewIssuesButton)) {',
    'lista secundaria final do NF'
)
nf = one(
    nf,
    'foreach ($button in @($exportButton,$newButton)) {',
    'foreach ($button in @($exportButton)) {',
    'lista primaria final do NF'
)
nf = one(
    nf,
    '''    foreach ($button in @($exportButton)) {
        if ($null -ne $button) { Set-NFButtonStyle $button "Primary" }
    }
    foreach ($button in @($deleteButton,$movementReverseButton)) {''',
    '''    foreach ($button in @($exportButton)) {
        if ($null -ne $button) { Set-NFButtonStyle $button "Primary" }
    }
    foreach ($button in @($importButton,$newButton)) {
        if ($null -ne $button) { Set-NFButtonStyle $button "Action" }
    }
    foreach ($button in @($deleteButton,$movementReverseButton)) {''',
    'lista Action final do NF'
)

# Marcadores para auditoria/regressão desta padronização.
generator += '\n# VISUAL_UNIFICADO_MANUTENCAO_GENERATOR_V03713\n'
nf += '\n# VISUAL_UNIFICADO_MANUTENCAO_NF_V02612\n'

for marker in (
    '$script:AppVersion = "0.21.41"',
    '$script:GeneratorVersion = "3.7.13"',
    '$script:NFEntradaVersion = "2.6.12"',
):
    if marker not in central:
        raise SystemExit('marcador ausente na Central: ' + marker)

for marker in (
    '$script:AppVersion = "3.7.13"',
    'VISUAL_UNIFICADO_MANUTENCAO_GENERATOR_V03713',
    '$Button.Cursor = [Windows.Forms.Cursors]::Hand',
    '$generateButton.Tag = "Action"',
):
    if marker not in generator:
        raise SystemExit('marcador ausente no Gerenciador: ' + marker)

for marker in (
    '$script:ModuleVersion = "2.6.12"',
    'VISUAL_UNIFICADO_MANUTENCAO_NF_V02612',
    'function Set-NFRoundedRegion',
    'Theme.Button.Action',
    'Set-NFButtonStyle $importButton "Action"',
):
    if marker not in nf:
        raise SystemExit('marcador ausente no NF: ' + marker)

# Proteção permanente do caminho estável das abas do Controle de NF.
for forbidden in (
    '$mainTabs.Add_SizeChanged',
    '$mainTabs.Add_HandleCreated',
    '$mainTabs.DrawMode = [Windows.Forms.TabDrawMode]::OwnerDrawFixed',
):
    if forbidden in nf:
        raise SystemExit('padronizacao visual reintroduziu mecanismo proibido de abas: ' + forbidden)

central_path.write_text(central, encoding='utf-8')
generator_path.write_text(generator, encoding='utf-8')
nf_path.write_text(nf, encoding='utf-8')
print('PADRONIZACAO VISUAL: OK - Gerenciador e NF alinhados ao estilo da Central de Manutencao, sem alterar fluxos operacionais ou abas estaveis do NF.')
