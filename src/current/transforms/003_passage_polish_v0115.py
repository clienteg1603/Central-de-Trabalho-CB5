from pathlib import Path

repo = Path('.')
central_path = repo / 'src/generated/Central de Trabalho.ps1'
maint_path = repo / 'src/generated/Modulos/Central-de-Manutencao-CB5/Central Manutencao CB5.ps1'

central = central_path.read_text(encoding='utf-8-sig')
text = maint_path.read_text(encoding='utf-8-sig')
marker = '# PASSAGE_POLISH_V0115'

if marker in text:
    print('Polimento da Passagem v0.11.5 já aplicado.')
    raise SystemExit(0)

def rep(source, old, new, label):
    count = source.count(old)
    if count != 1:
        raise RuntimeError(f'{label}: esperado 1 trecho, encontrado {count}')
    return source.replace(old, new, 1)

# Versões.
central = rep(central, '$script:AppVersion = "0.11.4"', '$script:AppVersion = "0.11.5"', 'versão Central')
central = rep(central, '$script:MaintenanceVersion = "0.5.4"', '$script:MaintenanceVersion = "0.5.5"', 'versão Manutenção na Central')
text = rep(text, '$script:AppVersion = "0.5.4"', '$script:AppVersion = "0.5.5"', 'versão interna Manutenção')

# Nomes dos blocos: mais curtos e orientados ao fluxo real.
text = rep(text, '$identityGroup.Text = "1. Identificação da peça"', '$identityGroup.Text = "1. Identificação"', 'título Identificação')
text = rep(text, '$defectsGroup.Text = "2. Defeitos"', '$defectsGroup.Text = "2. Defeitos e diagnóstico"', 'título Defeitos')
text = rep(text, '$maintenanceGroup.Text = "3. Manutenção"', '$maintenanceGroup.Text = "3. Manutenção realizada"', 'título Manutenção')
text = rep(text, '$finalResultGroup.Text = "4. Resultado final"', '$finalResultGroup.Text = "4. Conclusão"', 'título Conclusão')
text = rep(text, '$updateGroup.Text = "Atualização de versão"', '$updateGroup.Text = "Atualização / próxima etapa"', 'título Atualização')
text = rep(text, '$seriesHistoryGroup.Text = "Histórico automático da série"', '$seriesHistoryGroup.Text = "Histórico da série"', 'título Histórico lateral')

# Faixa de modo atual: vira um cartão discreto em vez de texto solto.
old_mode = '''$modePanel = New-Object Windows.Forms.Panel
$modePanel.Dock = [Windows.Forms.DockStyle]::Top
$modePanel.Height = 48
$formModeLabel = New-Object Windows.Forms.Label
$formModeLabel.Text = "NOVA PASSAGEM"
$formModeLabel.Dock = [Windows.Forms.DockStyle]::Fill
$formModeLabel.TextAlign = [Drawing.ContentAlignment]::MiddleLeft'''
new_mode = '''$modePanel = New-Object Windows.Forms.Panel
$modePanel.Dock = [Windows.Forms.DockStyle]::Top
$modePanel.Height = 48
$modePanel.Margin = [Windows.Forms.Padding]::new(0, 0, 0, 6)
$modePanel.Padding = [Windows.Forms.Padding]::new(10, 0, 10, 0)
$modePanel.Add_SizeChanged({ Set-MaintenanceRoundedRegion $this 9 })
$formModeLabel = New-Object Windows.Forms.Label
$formModeLabel.Text = "NOVA PASSAGEM"
$formModeLabel.Dock = [Windows.Forms.DockStyle]::Fill
$formModeLabel.Padding = [Windows.Forms.Padding]::new(4, 0, 4, 0)
$formModeLabel.TextAlign = [Drawing.ContentAlignment]::MiddleLeft'''
text = rep(text, old_mode, new_mode, 'cartão de modo')

# Informação de fluxo na identificação.
old_flow = '''$automaticFlowLabel.Text = "A passagem permanece aberta até você concluir como Aprovado ou PT."
$automaticFlowLabel.Dock = [Windows.Forms.DockStyle]::Fill
$automaticFlowLabel.Padding = [Windows.Forms.Padding]::new(12, 3, 3, 3)
$automaticFlowLabel.TextAlign = [Drawing.ContentAlignment]::MiddleLeft'''
new_flow = '''$automaticFlowLabel.Text = "A passagem fica aberta até a conclusão como Aprovado ou PT."
$automaticFlowLabel.Dock = [Windows.Forms.DockStyle]::Fill
$automaticFlowLabel.Margin = [Windows.Forms.Padding]::new(8, 2, 0, 2)
$automaticFlowLabel.Padding = [Windows.Forms.Padding]::new(10, 3, 8, 3)
$automaticFlowLabel.TextAlign = [Drawing.ContentAlignment]::MiddleLeft
$automaticFlowLabel.Add_SizeChanged({ Set-MaintenanceRoundedRegion $this 8 })'''
text = rep(text, old_flow, new_flow, 'cartão de fluxo')

# Ajuda de conclusão também fica visualmente separada do ComboBox.
old_final_help = '''$finalResultHelp.Dock = [Windows.Forms.DockStyle]::Fill
$finalResultHelp.Padding = [Windows.Forms.Padding]::new(14, 6, 4, 4)
$finalResultHelp.TextAlign = [Drawing.ContentAlignment]::MiddleLeft
$finalResultHelp.Text = "Escolha o resultado somente ao finalizar."'''
new_final_help = '''$finalResultHelp.Dock = [Windows.Forms.DockStyle]::Fill
$finalResultHelp.Margin = [Windows.Forms.Padding]::new(10, 2, 0, 2)
$finalResultHelp.Padding = [Windows.Forms.Padding]::new(10, 4, 8, 4)
$finalResultHelp.TextAlign = [Drawing.ContentAlignment]::MiddleLeft
$finalResultHelp.Text = "Escolha o resultado somente ao finalizar."
$finalResultHelp.Add_SizeChanged({ Set-MaintenanceRoundedRegion $this 8 })'''
text = rep(text, old_final_help, new_final_help, 'ajuda Conclusão')

# Cartões laterais: margens e cantos para separar informação automática de ações.
text = rep(text,
'''$recordBanner.Dock = [Windows.Forms.DockStyle]::Fill
$recordBanner.Padding = [Windows.Forms.Padding]::new(12)
$recordBanner.TextAlign = [Drawing.ContentAlignment]::MiddleLeft''',
'''$recordBanner.Dock = [Windows.Forms.DockStyle]::Fill
$recordBanner.Margin = [Windows.Forms.Padding]::new(0, 0, 0, 6)
$recordBanner.Padding = [Windows.Forms.Padding]::new(11, 7, 11, 7)
$recordBanner.TextAlign = [Drawing.ContentAlignment]::MiddleLeft
$recordBanner.Add_SizeChanged({ Set-MaintenanceRoundedRegion $this 9 })''',
'record banner')

text = rep(text,
'''$updateInfo.Dock = [Windows.Forms.DockStyle]::Fill
$updateInfo.Padding = [Windows.Forms.Padding]::new(10)
$updateInfo.TextAlign = [Drawing.ContentAlignment]::MiddleLeft
$updateInfo.AutoEllipsis = $false''',
'''$updateInfo.Dock = [Windows.Forms.DockStyle]::Fill
$updateInfo.Margin = [Windows.Forms.Padding]::new(0, 0, 0, 2)
$updateInfo.Padding = [Windows.Forms.Padding]::new(9, 6, 9, 6)
$updateInfo.TextAlign = [Drawing.ContentAlignment]::MiddleLeft
$updateInfo.AutoEllipsis = $false
$updateInfo.Add_SizeChanged({ Set-MaintenanceRoundedRegion $this 8 })''',
'aviso atualização')

text = rep(text,
'''$codeRuleLabel.Dock = [Windows.Forms.DockStyle]::Fill
$codeRuleLabel.Padding = [Windows.Forms.Padding]::new(10)
$codeRuleLabel.TextAlign = [Drawing.ContentAlignment]::MiddleLeft''',
'''$codeRuleLabel.Dock = [Windows.Forms.DockStyle]::Fill
$codeRuleLabel.Margin = [Windows.Forms.Padding]::new(0, 4, 0, 4)
$codeRuleLabel.Padding = [Windows.Forms.Padding]::new(9, 4, 9, 4)
$codeRuleLabel.TextAlign = [Drawing.ContentAlignment]::MiddleLeft
$codeRuleLabel.Add_SizeChanged({ Set-MaintenanceRoundedRegion $this 8 })''',
'regra de código')

# Texto do botão secundário: curto sem esconder que ele limpa a tela.
text = rep(text, '$newPassageButton.Text = "LIMPAR / NOVA PASSAGEM"', '$newPassageButton.Text = "NOVA / LIMPAR"', 'texto Nova/Limpar')

# Tooltips operacionais: ajudam sem criar novos botões ou textos na tela.
anchor_actions = '''$actionsLayout.Controls.Add($completePassageButton, 0, 2)

$historyTab = New-Object Windows.Forms.TabPage'''
insert_actions = '''$actionsLayout.Controls.Add($completePassageButton, 0, 2)

$passageToolTip = New-Object Windows.Forms.ToolTip
$passageToolTip.AutoPopDelay = 5000
$passageToolTip.InitialDelay = 350
$passageToolTip.ReshowDelay = 100
$passageToolTip.SetToolTip($serialBox, "Série obrigatória com exatamente 8 dígitos")
$passageToolTip.SetToolTip($inputVersionCombo, "Versão recebida nesta passagem")
$passageToolTip.SetToolTip($outputVersionCombo, "Versão que ficará registrada ao final da passagem")
$passageToolTip.SetToolTip($newPassageButton, "Limpa os campos e inicia uma nova passagem")
$passageToolTip.SetToolTip($savePassageButton, "Salva o andamento sem concluir a passagem")
$passageToolTip.SetToolTip($completePassageButton, "Conclui a passagem com o resultado selecionado")
$passageToolTip.SetToolTip($seriesHistoryDetailsButton, "Mostra os detalhes da passagem selecionada")
$passageToolTip.SetToolTip($seriesHistoryFullButton, "Abre o histórico completo desta série")

$historyTab = New-Object Windows.Forms.TabPage'''
text = rep(text, anchor_actions, insert_actions, 'tooltips Passagem')

# Correção estrutural: os perfis antigos davam menos altura ao bloco Identificação
# do que a soma das quatro linhas internas fixas. Ajustamos altura externa e linhas.
text = rep(text,
'$modeH = 29; $identityH = 110; $defectsH = 120; $maintH = 88; $finalH = 70; $notesH = 70; $gap = 4',
'$modeH = 30; $identityH = 124; $defectsH = 122; $maintH = 90; $finalH = 82; $notesH = 74; $gap = 4',
'perfil Tight Passagem')
text = rep(text,
'$modeH = 31; $identityH = 118; $defectsH = 130; $maintH = 96; $finalH = 76; $notesH = 76; $gap = 5',
'$modeH = 32; $identityH = 132; $defectsH = 132; $maintH = 98; $finalH = 88; $notesH = 78; $gap = 5',
'perfil Compact Passagem')
text = rep(text,
'$modeH = 34; $identityH = 132; $defectsH = 150; $maintH = 112; $finalH = 86; $notesH = 86; $gap = 6',
'$modeH = 35; $identityH = 142; $defectsH = 150; $maintH = 112; $finalH = 96; $notesH = 86; $gap = 6',
'perfil Comfortable Passagem')

# Linhas internas acompanham o perfil real em vez de manter 130 px fixos em qualquer tela.
responsive_anchor = '''        # Telas técnicas também acompanham o perfil da área real hospedada.'''
responsive_insert = '''        # Passagem: as linhas internas também precisam caber dentro das alturas externas.
        if ($profile -eq "Tight") {
            $identityLayout.RowStyles[0].Height = 18
            $identityLayout.RowStyles[1].Height = 28
            $identityLayout.RowStyles[2].Height = 18
            $identityLayout.RowStyles[3].Height = 28
            $finalResultLayout.RowStyles[0].Height = 18
        }
        elseif ($profile -eq "Compact") {
            $identityLayout.RowStyles[0].Height = 20
            $identityLayout.RowStyles[1].Height = 30
            $identityLayout.RowStyles[2].Height = 20
            $identityLayout.RowStyles[3].Height = 30
            $finalResultLayout.RowStyles[0].Height = 20
        }
        else {
            $identityLayout.RowStyles[0].Height = 22
            $identityLayout.RowStyles[1].Height = 32
            $identityLayout.RowStyles[2].Height = 22
            $identityLayout.RowStyles[3].Height = 32
            $finalResultLayout.RowStyles[0].Height = 22
        }
        $identityGroup.Padding = [Windows.Forms.Padding]::new([Math]::Max(7,$passagePadding + 3), [Math]::Max(17,$groupPadTop), [Math]::Max(7,$passagePadding + 3), [Math]::Max(5,$passagePadding))
        $finalResultGroup.Padding = [Windows.Forms.Padding]::new([Math]::Max(7,$passagePadding + 3), [Math]::Max(17,$groupPadTop), [Math]::Max(7,$passagePadding + 3), [Math]::Max(5,$passagePadding))
        $automaticFlowLabel.Font = [Drawing.Font]::new("Segoe UI", [Math]::Max(7.2, $baseFont - 0.1))
        $finalResultHelp.Font = [Drawing.Font]::new("Segoe UI", [Math]::Max(7.2, $baseFont - 0.05))

        # Telas técnicas também acompanham o perfil da área real hospedada.'''
text = rep(text, responsive_anchor, responsive_insert, 'responsividade interna Passagem')

# Tema dos novos cartões da Passagem.
old_theme = '''    $recordBanner.BackColor = $script:CurrentPalette.SuccessBack
    $recordBanner.ForeColor = $script:CurrentPalette.Success
    $updateInfo.BackColor = $script:CurrentPalette.WarningBack
    $updateInfo.ForeColor = $script:CurrentPalette.Warning
    $seriesHistoryStateLabel.ForeColor = $script:CurrentPalette.Muted'''
new_theme = '''    $modePanel.BackColor = $script:CurrentPalette.Surface
    $formModeLabel.ForeColor = $script:CurrentPalette.Accent
    Set-MaintenanceRoundedRegion $modePanel 9
    $automaticFlowLabel.BackColor = $script:CurrentPalette.Surface
    $automaticFlowLabel.ForeColor = $script:CurrentPalette.Muted
    Set-MaintenanceRoundedRegion $automaticFlowLabel 8
    $finalResultHelp.BackColor = $script:CurrentPalette.Surface
    Set-MaintenanceRoundedRegion $finalResultHelp 8
    $recordBanner.BackColor = $script:CurrentPalette.SuccessBack
    $recordBanner.ForeColor = $script:CurrentPalette.Success
    Set-MaintenanceRoundedRegion $recordBanner 9
    $updateInfo.BackColor = $script:CurrentPalette.WarningBack
    $updateInfo.ForeColor = $script:CurrentPalette.Warning
    Set-MaintenanceRoundedRegion $updateInfo 8
    $codeRuleLabel.BackColor = $script:CurrentPalette.Surface
    $codeRuleLabel.ForeColor = $script:CurrentPalette.Muted
    Set-MaintenanceRoundedRegion $codeRuleLabel 8
    $seriesHistoryStateLabel.ForeColor = $script:CurrentPalette.Muted'''
text = rep(text, old_theme, new_theme, 'tema Passagem')

# A função de regra de código não deve sobrescrever a cor definida pelo tema.
text = rep(text, '    $codeRuleLabel.ForeColor = $script:CurrentPalette.Muted\n    Update-FinalResultUI', '    Update-FinalResultUI', 'cor regra código')

# Marca final para idempotência e auditoria do fonte gerado.
end_anchor = '''        # Scroll é fallback, nunca o mecanismo principal de encaixe.'''
text = rep(text, end_anchor, marker + '\n        # Scroll é fallback, nunca o mecanismo principal de encaixe.', 'marca v0.11.5')

central_path.write_text(central, encoding='utf-8', newline='')
maint_path.write_text(text, encoding='utf-8', newline='')
print('Polimento da Passagem v0.11.5 aplicado com sucesso.')
