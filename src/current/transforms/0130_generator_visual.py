from pathlib import Path

ROOT = Path('src/generated')
GEN = ROOT / 'Modulos' / 'Gerador-de-Planilhas-CB5-TV5' / 'Gerador Planilhas.ps1'
CENTRAL = ROOT / 'Central de Trabalho.ps1'


def read(path):
    return path.read_text(encoding='utf-8-sig')


def write(path, text):
    path.write_text(text, encoding='utf-8-sig')


def replace_once(text, old, new, label):
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: esperado 1 trecho, encontrado {count}')
    return text.replace(old, new, 1)


g = read(GEN)
c = read(CENTRAL)

# Versões.
g = replace_once(g, '$script:AppVersion = "3.5.2"', '$script:AppVersion = "3.6.0"', 'versao gerenciador')
c = replace_once(c, '$script:AppVersion = "0.12.4"', '$script:AppVersion = "0.13.0"', 'versao central')
c = replace_once(c, '$script:GeneratorVersion = "3.5.2"', '$script:GeneratorVersion = "3.6.0"', 'versao gerenciador na central')

# Helper de cartões arredondados, seguindo a identidade já usada na Manutenção.
needle = '''    return $bitmap
}

function Set-ButtonTheme {'''
insert = '''    return $bitmap
}

function Set-GeneratorRoundedRegion {
    param([Windows.Forms.Control]$Control, [int]$Radius = 10)
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

function Set-ButtonTheme {'''
g = replace_once(g, needle, insert, 'helper arredondado')

# Hierarquia visual da tela principal de geração.
g = replace_once(g, '$masterLabel.Text = "PLANILHA MESTRE"', '$masterLabel.Text = "1  PLANILHA MESTRE"', 'etapa mestre')
g = replace_once(g, '$outputLabel.Text = "Destino automático: Área de Trabalho"', '$outputLabel.Text = "2  DESTINO AUTOMÁTICO — ÁREA DE TRABALHO"', 'etapa destino')
g = replace_once(g, '$summaryTitle.Text = "RESUMO DA SELEÇÃO"', '$summaryTitle.Text = "3  RESUMO ANTES DE GERAR"', 'etapa resumo')
g = replace_once(g, '$statusLabel.Text = "Resultado da última execução"', '$statusLabel.Text = "CONFERÊNCIA E RESULTADO"', 'titulo resultado')
g = replace_once(
    g,
    '$infoBox.Text = "Sem manutenção adicional, a mestre não é alterada. Com alguma quantidade, somente REPARO é atualizado. Cabeçalhos, lote, séries, operadoras e ICCIDs são validados antes da gravação."',
    '$infoBox.Text = "Sem manutenção adicional, a mestre permanece intacta. Se houver quantidades em Manutenções, somente REPARO será atualizado. A estrutura da mestre é validada antes de qualquer gravação."',
    'texto informativo'
)

# Abas mais compactas no modo integrado, sem perder a descrição completa nos tooltips.
hosted_anchor = '''if ($script:IsInProcessHosted) {
    $headerPanel.Height = 42'''
hosted_new = '''if ($script:IsInProcessHosted) {
    $tabGenerate.Text = "Gerar"
    $tabGenerate.ToolTipText = "Gerar planilhas a partir de uma mestre CB5 ou TV5."
    $tabExtra.Text = "Manutenções"
    $tabExtra.ToolTipText = "Manutenções adicionais que podem atualizar a coluna REPARO da mestre."
    $tabComponents.Text = "Componentes"
    $tabComponents.ToolTipText = "Componentes a faturar, saldos, movimentos e uniões processadas."
    $tabCombine.Text = "Juntar lotes"
    $tabCombine.ToolTipText = "Unir duas ou mais mestres da mesma nota fiscal."
    $tabDescriptions.Text = "Códigos"
    $tabDescriptions.ToolTipText = "Legenda dos códigos utilizados nos arquivos gerados."

    $headerPanel.Height = 42'''
g = replace_once(g, hosted_anchor, hosted_new, 'abas compactas')

# Cartões passam a usar a mesma linguagem visual suave da Central de Manutenção.
footer_anchor = '''$footerPanel = New-Object Windows.Forms.Panel
$footerPanel.Location = New-Object Drawing.Point(0, 662)'''
rounded_block = '''foreach ($roundedPanel in @($masterCard, $destinationCard, $summaryCard, $componentActiveCard, $componentPendingCard, $componentOperationsCard)) {
    $roundedPanel.BorderStyle = [Windows.Forms.BorderStyle]::None
    $roundedPanel.Add_SizeChanged({ Set-GeneratorRoundedRegion $this 10 })
    Set-GeneratorRoundedRegion $roundedPanel 10
}

$footerPanel = New-Object Windows.Forms.Panel
$footerPanel.Location = New-Object Drawing.Point(0, 662)'''
g = replace_once(g, footer_anchor, rounded_block, 'cartoes arredondados')

# Reaplica a região quando o tema/layout muda.
theme_anchor = '''    foreach ($panel in @($masterCard, $summaryCard, $destinationCard, $componentActiveCard, $componentPendingCard, $componentOperationsCard)) {
        $panel.BackColor = $palette.Surface
        $panel.ForeColor = $palette.Text
    }'''
theme_new = '''    foreach ($panel in @($masterCard, $summaryCard, $destinationCard, $componentActiveCard, $componentPendingCard, $componentOperationsCard)) {
        $panel.BackColor = $palette.Surface
        $panel.ForeColor = $palette.Text
        $panel.BorderStyle = [Windows.Forms.BorderStyle]::None
        Set-GeneratorRoundedRegion $panel 10
    }'''
g = replace_once(g, theme_anchor, theme_new, 'tema dos cartoes')

# Ações do rodapé realmente contextuais: a aba Códigos é apenas consulta.
handler_old = '''$tabs.Add_SelectedIndexChanged({
    $isCombineTab = ($tabs.SelectedTab -eq $tabCombine)
    $isComponentsTab = ($tabs.SelectedTab -eq $tabComponents)
    $canUpdateMaster = ($tabs.SelectedTab -eq $tabGenerate -or $tabs.SelectedTab -eq $tabExtra)
    $generateButton.Visible = (-not $isCombineTab -and -not $isComponentsTab)
    $updateMasterButton.Visible = $canUpdateMaster
    $combineGenerateButton.Visible = $isCombineTab
    $openFolderButton.Visible = (-not $isComponentsTab)'''
handler_new = '''$tabs.Add_SelectedIndexChanged({
    $isCombineTab = ($tabs.SelectedTab -eq $tabCombine)
    $isComponentsTab = ($tabs.SelectedTab -eq $tabComponents)
    $isDescriptionsTab = ($tabs.SelectedTab -eq $tabDescriptions)
    $canUpdateMaster = ($tabs.SelectedTab -eq $tabGenerate -or $tabs.SelectedTab -eq $tabExtra)
    $canGenerate = (-not $isCombineTab -and -not $isComponentsTab -and -not $isDescriptionsTab)
    $generateButton.Visible = $canGenerate
    $updateMasterButton.Visible = $canUpdateMaster
    $combineGenerateButton.Visible = $isCombineTab
    $openFolderButton.Visible = (-not $isComponentsTab -and -not $isDescriptionsTab)'''
g = replace_once(g, handler_old, handler_new, 'acoes contextuais')

# Pequenas melhorias de texto dos botões de conferência.
g = replace_once(g, '$previewMasterButton.Text = "Conferir sem gravar"', '$previewMasterButton.Text = "Conferir primeiro"', 'botao conferir mestre')
g = replace_once(g, '$previewCombineButton.Text = "Conferir sem gravar"', '$previewCombineButton.Text = "Conferir primeiro"', 'botao conferir uniao')

write(GEN, g)
write(CENTRAL, c)
print('Transformação v0.13.0 aplicada com sucesso.')
