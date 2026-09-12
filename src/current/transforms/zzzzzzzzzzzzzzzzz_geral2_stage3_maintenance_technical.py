from pathlib import Path

p = Path('src/generated/Modulos/Central-de-Manutencao-CB5/Central Manutencao CB5.ps1')
m = p.read_text(encoding='utf-8-sig')

def one(old, new, label):
    global m
    n = m.count(old)
    if n != 1:
        raise SystemExit(f'GERAL2/E3E {label}: esperado 1, encontrado {n}')
    m = m.replace(old, new, 1)

helper = r'''function Update-MaintenanceStage3TechnicalLayouts {
    if ($null -eq $form -or $null -eq $script:MaintenanceResponsiveProfile) { return }
    try {
        $metrics = Get-MaintenanceLogicalViewport
        $w = [int]$metrics.LogicalWidth
        $h = [int]$metrics.LogicalHeight
        $profile = [string]$script:MaintenanceResponsiveProfile
        $narrow = ($w -lt 760)
        $veryNarrow = ($w -lt 620)

        # HISTORICO: filtros continuam em uma linha, mas as ações deixam de reservar
        # quatro blocos de 170 px quando a janela é restaurada.
        $historyRoot.RowStyles[0].Height = if ($veryNarrow) { 68 } elseif ($profile -eq 'Tight') { 76 } elseif ($profile -eq 'Compact') { 82 } else { 88 }
        $historyRoot.RowStyles[2].Height = if ($veryNarrow) { 46 } elseif ($profile -eq 'Tight') { 50 } elseif ($profile -eq 'Compact') { 54 } else { 58 }
        $historyFilterGroup.Padding = [Windows.Forms.Padding]::new($(if ($narrow) { 7 } else { 10 }), $(if ($narrow) { 17 } else { 20 }), $(if ($narrow) { 7 } else { 10 }), $(if ($narrow) { 6 } else { 8 }))
        $historyActionWidth = if ($veryNarrow) { 96 } elseif ($w -lt 900) { 124 } else { 160 }
        for ($i = 1; $i -lt 5; $i++) {
            $historyActions.ColumnStyles[$i].SizeType = [Windows.Forms.SizeType]::Absolute
            $historyActions.ColumnStyles[$i].Width = $historyActionWidth
        }
        if ($narrow) {
            $viewHistoryButton.Text = 'VISUALIZAR'
            $editHistoryButton.Text = 'EDITAR'
            $returnHistoryButton.Text = 'RETORNO'
            $exportHistoryButton.Text = 'CSV'
            $historyClearButton.Text = 'LIMPAR'
        }
        else {
            $viewHistoryButton.Text = 'VISUALIZAR'
            $editHistoryButton.Text = 'EDITAR / CORRIGIR'
            $returnHistoryButton.Text = 'REGISTRAR RETORNO'
            $exportHistoryButton.Text = 'EXPORTAR CSV'
            $historyClearButton.Text = 'LIMPAR FILTROS'
        }

        # DIAGNOSTICO: os dois botões recebem largura útil real em vez de 8% cada.
        if ($narrow) {
            $diagSpecs = @(
                @([Windows.Forms.SizeType]::Absolute, 88),
                @([Windows.Forms.SizeType]::Absolute, 82),
                @([Windows.Forms.SizeType]::Percent, 50),
                @([Windows.Forms.SizeType]::Percent, 50),
                @([Windows.Forms.SizeType]::Absolute, 72),
                @([Windows.Forms.SizeType]::Absolute, 80)
            )
            $diagnosisLoadButton.Text = 'CARREGAR'
        }
        elseif ($w -lt 1040) {
            $diagSpecs = @(
                @([Windows.Forms.SizeType]::Absolute, 108),
                @([Windows.Forms.SizeType]::Absolute, 94),
                @([Windows.Forms.SizeType]::Percent, 50),
                @([Windows.Forms.SizeType]::Percent, 50),
                @([Windows.Forms.SizeType]::Absolute, 84),
                @([Windows.Forms.SizeType]::Absolute, 90)
            )
            $diagnosisLoadButton.Text = "CARREGAR`nSÉRIE"
        }
        else {
            $diagSpecs = @(
                @([Windows.Forms.SizeType]::Percent, 16),
                @([Windows.Forms.SizeType]::Percent, 12),
                @([Windows.Forms.SizeType]::Percent, 28),
                @([Windows.Forms.SizeType]::Percent, 28),
                @([Windows.Forms.SizeType]::Percent, 8),
                @([Windows.Forms.SizeType]::Percent, 8)
            )
            $diagnosisLoadButton.Text = "CARREGAR`nSÉRIE"
        }
        for ($i = 0; $i -lt 6; $i++) {
            $diagnosisInputLayout.ColumnStyles[$i].SizeType = $diagSpecs[$i][0]
            $diagnosisInputLayout.ColumnStyles[$i].Width = [single]$diagSpecs[$i][1]
        }

        # ESQUEMATICOS: busca e cadastro passam a comprimir primeiro os blocos
        # auxiliares; o campo de arquivo/pesquisa fica com o espaço elástico.
        if ($narrow) {
            $searchSpecs = @(118, 0, 128, 108)
            $entrySpecs = @(88, 102, 0, 58, 92, 112)
            $schemaOpenButton.Text = 'ABRIR'
            $schemaRemoveButton.Text = 'REMOVER'
            $schemaBrowseButton.Text = 'ARQUIVO...'
            $schemaAddButton.Text = 'CADASTRAR'
        }
        elseif ($w -lt 1040) {
            $searchSpecs = @(145, 0, 160, 130)
            $entrySpecs = @(104, 125, 0, 72, 115, 140)
            $schemaOpenButton.Text = 'ABRIR SELECIONADO'
            $schemaRemoveButton.Text = 'REMOVER ÍNDICE'
            $schemaBrowseButton.Text = 'SELECIONAR ARQUIVO'
            $schemaAddButton.Text = 'CADASTRAR REFERÊNCIA'
        }
        else {
            $searchSpecs = @(180, 0, 190, 150)
            $entrySpecs = @(120, 150, 0, 90, 150, 170)
            $schemaOpenButton.Text = 'ABRIR SELECIONADO'
            $schemaRemoveButton.Text = 'REMOVER ÍNDICE'
            $schemaBrowseButton.Text = 'SELECIONAR ARQUIVO'
            $schemaAddButton.Text = 'CADASTRAR REFERÊNCIA'
        }
        for ($i=0; $i -lt 4; $i++) {
            if ($i -eq 1) {
                $schemaSearchLayout.ColumnStyles[$i].SizeType = [Windows.Forms.SizeType]::Percent
                $schemaSearchLayout.ColumnStyles[$i].Width = 100
            } else {
                $schemaSearchLayout.ColumnStyles[$i].SizeType = [Windows.Forms.SizeType]::Absolute
                $schemaSearchLayout.ColumnStyles[$i].Width = $searchSpecs[$i]
            }
        }
        for ($i=0; $i -lt 6; $i++) {
            if ($i -eq 2) {
                $schemaEntryLayout.ColumnStyles[$i].SizeType = [Windows.Forms.SizeType]::Percent
                $schemaEntryLayout.ColumnStyles[$i].Width = 100
            } else {
                $schemaEntryLayout.ColumnStyles[$i].SizeType = [Windows.Forms.SizeType]::Absolute
                $schemaEntryLayout.ColumnStyles[$i].Width = $entrySpecs[$i]
            }
        }

        # REGRAS/DADOS: mantém o caminho da base legível sem deixar o botão da
        # direita dominar a linha inteira em largura reduzida.
        $dataPanel.ColumnStyles[0].Width = if ($narrow) { 118 } elseif ($w -lt 1040) { 145 } else { 170 }
        $dataPanel.ColumnStyles[2].Width = if ($narrow) { 138 } elseif ($w -lt 1040) { 158 } else { 180 }
        $openDataFolderButton.Text = if ($narrow) { 'ABRIR PASTA' } else { 'ABRIR PASTA DOS DADOS' }

        # NOVA PASSAGEM: em largura menor a lateral cede mais espaço aos campos
        # principais. Acima disso preserva a geometria já aprovada.
        if ($w -lt 760) {
            $passageRoot.ColumnStyles[1].Width = [Math]::Min(228, [Math]::Max(202, [int]($w * 0.34)))
            $seriesHistoryDetailsButton.Text = 'DETALHES'
            $seriesHistoryFullButton.Text = 'HISTÓRICO'
        }
        else {
            $seriesHistoryDetailsButton.Text = 'VER DETALHES'
            $seriesHistoryFullButton.Text = 'ABRIR HISTÓRICO'
        }

        # Densidade consistente em todas as grades, não apenas nas quatro que já
        # participavam da rotina antiga.
        $rowH = if ($profile -eq 'Tight') { 21 } elseif ($profile -eq 'Compact') { 22 } else { 23 }
        $headH = if ($profile -eq 'Tight') { 23 } elseif ($profile -eq 'Compact') { 24 } else { 26 }
        foreach ($grid in @($diagnosisGrid,$statsVersionGrid,$statsCodeGrid,$statsResultGrid,$statsStatusGrid,$statsDefectGrid,$statsRepairGrid,$versionRulesGrid)) {
            if ($null -ne $grid) {
                try { $grid.RowTemplate.Height = $rowH; $grid.ColumnHeadersHeight = $headH } catch {}
            }
        }

        # Colunas fixas mais contidas no perfil estreito; colunas de texto longo
        # continuam em Fill e recebem o espaço restante.
        if ($narrow) {
            try {
                $historyGrid.Columns['Data'].Width = 82
                $historyGrid.Columns['Serie'].Width = 70
                $historyGrid.Columns['Passagem'].Width = 60
                $historyGrid.Columns['Retorno'].Width = 56
                $historyGrid.Columns['Codigo'].Width = 58
                $historyGrid.Columns['Versao'].Width = 66
                $historyGrid.Columns['Status'].Width = 76
            } catch {}
            try {
                $diagnosisGrid.Columns['Tipo'].Width = 58
                $diagnosisGrid.Columns['Defeito'].Width = 108
                $diagnosisGrid.Columns['Casos'].Width = 48
                $diagnosisGrid.Columns['Nivel'].Width = 92
            } catch {}
            try {
                $schemaGrid.Columns['Versao'].Width = 72
                $schemaGrid.Columns['Designador'].Width = 84
                $schemaGrid.Columns['Arquivo'].Width = 132
                $schemaGrid.Columns['Pagina'].Width = 56
                $schemaGrid.Columns['Area'].Width = 82
            } catch {}
        }

        # Scroll somente quando a tela realmente passou do limite de compressão.
        $historyTab.AutoScroll = ($w -lt 560 -or $h -lt 430)
        $statisticsTab.AutoScroll = ($w -lt 540 -or $h -lt 410)
        $diagnosisTab.AutoScroll = ($w -lt 560 -or $h -lt 450)
        $schematicsTab.AutoScroll = ($w -lt 580 -or $h -lt 470)
        $rulesTab.AutoScroll = ($w -lt 560 -or $h -lt 430)
    }
    catch {}
}

'''

marker = '$statsTabs.Add_DrawItem({' 
if m.count(marker) != 1:
    raise SystemExit(f'GERAL2/E3E marcador helper: {m.count(marker)}')
m = m.replace(marker, helper + marker, 1)

one(
    '''        # Scroll é fallback, nunca o mecanismo principal de encaixe.
        $passageScroll.AutoScroll = $true
        $passageTab.AutoScroll = $false
        $form.PerformLayout()''',
    '''        # Scroll é fallback, nunca o mecanismo principal de encaixe.
        $passageScroll.AutoScroll = $true
        $passageTab.AutoScroll = $false
        Update-MaintenanceStage3TechnicalLayouts
        $form.PerformLayout()''',
    'chamada stage3'
)

m += '\n# GERAL2_ETAPA3_MANUTENCAO_TECNICA_V00612\n'
for marker in ('function Update-MaintenanceStage3TechnicalLayouts', 'Update-MaintenanceStage3TechnicalLayouts\n        $form.PerformLayout()', 'GERAL2_ETAPA3_MANUTENCAO_TECNICA_V00612'):
    if marker not in m:
        raise SystemExit('GERAL2/E3E marcador final ausente: ' + marker)

p.write_text(m, encoding='utf-8')
print('GERAL 2 ETAPA 3E: OK - Historico, Diagnostico, Esquematicos, Regras e grades agora se adaptam a janela real.')
