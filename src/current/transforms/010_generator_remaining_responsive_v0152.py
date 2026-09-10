from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CENTRAL = ROOT / "generated" / "Central de Trabalho.ps1"
GEN = ROOT / "generated" / "Modulos" / "Gerador-de-Planilhas-CB5-TV5" / "Gerador Planilhas.ps1"


def read(path):
    return path.read_text(encoding="utf-8-sig")


def write(path, text):
    path.write_text(text, encoding="utf-8-sig")


def replace_once(text, old, new, label):
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: esperado 1 trecho, encontrado {count}")
    return text.replace(old, new, 1)


central = read(CENTRAL)
central = replace_once(central, '$script:AppVersion = "0.15.1"', '$script:AppVersion = "0.15.2"', 'versao Central')
central = replace_once(central, '$script:GeneratorVersion = "3.7.1"', '$script:GeneratorVersion = "3.7.2"', 'versao Gerenciador na Central')
write(CENTRAL, central)


gen = read(GEN)
gen = replace_once(gen, '$script:AppVersion = "3.7.1"', '$script:AppVersion = "3.7.2"', 'versao Gerenciador')

# Códigos passa a usar o mesmo bloco informativo visual das outras áreas.
old_desc = '''$descriptionsIntro = New-Object Windows.Forms.Label
$descriptionsIntro.Text = "Legenda completa usada nos arquivos gerados. Esta área é somente para consulta."
$descriptionsIntro.Location = New-Object Drawing.Point(18, 16)
$descriptionsIntro.Size = New-Object Drawing.Size(982, 30)
$descriptionsIntro.Anchor = "Top,Left,Right"
$tabDescriptions.Controls.Add($descriptionsIntro)'''
new_desc = '''$descriptionsIntro = New-Object Windows.Forms.Label
$descriptionsIntro.Text = "Legenda completa usada nos arquivos gerados. Esta área é somente para consulta."
$descriptionsIntro.Location = New-Object Drawing.Point(18, 12)
$descriptionsIntro.Size = New-Object Drawing.Size(982, 38)
$descriptionsIntro.Anchor = "Top,Left,Right"
$descriptionsIntro.Font = New-Object Drawing.Font("Segoe UI Semibold", 9.1)
$descriptionsIntro.Padding = New-Object Windows.Forms.Padding(12, 7, 12, 6)
$descriptionsIntro.BorderStyle = [Windows.Forms.BorderStyle]::None
$descriptionsIntro.Add_SizeChanged({ Set-GeneratorRoundedRegion $this 9 })
$tabDescriptions.Controls.Add($descriptionsIntro)'''
gen = replace_once(gen, old_desc, new_desc, 'bloco informativo de codigos')
gen = replace_once(gen, '$descriptionsGrid.Location = New-Object Drawing.Point(18, 52)', '$descriptionsGrid.Location = New-Object Drawing.Point(18, 58)', 'posicao grade de codigos')

# O tema também colore o novo bloco de Códigos.
gen = replace_once(
    gen,
    '''    $componentsIntro.BackColor = $palette.Info
    $componentsIntro.ForeColor = $palette.Text
    $combineBalanceCard.BackColor = $palette.Surface''',
    '''    $componentsIntro.BackColor = $palette.Info
    $componentsIntro.ForeColor = $palette.Text
    $descriptionsIntro.BackColor = $palette.Info
    $descriptionsIntro.ForeColor = $palette.Text
    Set-GeneratorRoundedRegion $descriptionsIntro 9
    $combineBalanceCard.BackColor = $palette.Surface''',
    'tema do bloco de codigos'
)

marker = 'function Update-RootLayout {\n'
if gen.count(marker) != 1:
    raise RuntimeError('Update-RootLayout nao localizado de forma unica')

helper = r'''function Update-GeneratorRemainingLayouts {
    if (-not $script:IsInProcessHosted) { return }
    try {
        # GERAR: cartões e controles internos respeitam a largura real da página.
        $gw = [Math]::Max(520, [int]$tabGenerate.ClientSize.Width)
        $gh = [Math]::Max(330, [int]$tabGenerate.ClientSize.Height)
        $gInnerW = [Math]::Max(460, $gw - 36)
        foreach ($control in @($masterCard, $destinationCard, $summaryCard, $infoBox, $statusText)) {
            if ($null -ne $control) { $control.Width = $gInnerW }
        }
        $summaryLayout.Width = [Math]::Max(420, $summaryCard.ClientSize.Width - 20)
        $openDestinationCardButton.Left = [Math]::Max(220, $destinationCard.ClientSize.Width - $openDestinationCardButton.Width - 14)
        $outputInfo.Width = [Math]::Max(150, $openDestinationCardButton.Left - $outputInfo.Left - 12)
        $statusText.Height = [Math]::Max(82, $gh - $statusText.Top - 14)
        Update-MasterCardLayout

        # MANUTENÇÕES: instrução, resumo e grade permanecem alinhados em qualquer largura.
        $ew = [Math]::Max(520, [int]$tabExtra.ClientSize.Width)
        $eh = [Math]::Max(300, [int]$tabExtra.ClientSize.Height)
        $eInnerW = [Math]::Max(460, $ew - 36)
        $extraIntro.Width = $eInnerW
        $extraSelectionLabel.Width = $eInnerW
        $extraGrid.Width = $eInnerW
        $extraGrid.Height = [Math]::Max(150, $eh - $extraGrid.Top - 14)
        if ($ew -lt 720) {
            $extraGrid.Columns[0].Width = 88
            $extraGrid.Columns[1].Width = 126
            $extraGrid.Columns[3].Width = 138
        }
        else {
            $extraGrid.Columns[0].Width = 105
            $extraGrid.Columns[1].Width = 145
            $extraGrid.Columns[3].Width = 190
        }

        # CÓDIGOS: a grade usa todo o espaço restante e a coluna de observação encolhe primeiro.
        $dw = [Math]::Max(520, [int]$tabDescriptions.ClientSize.Width)
        $dh = [Math]::Max(300, [int]$tabDescriptions.ClientSize.Height)
        $dInnerW = [Math]::Max(460, $dw - 36)
        $descriptionsIntro.Width = $dInnerW
        $descriptionsGrid.Width = $dInnerW
        $descriptionsGrid.Height = [Math]::Max(170, $dh - $descriptionsGrid.Top - 14)
        $descriptionsGrid.Columns[0].Width = if ($dw -lt 720) { 86 } else { 100 }
        $descriptionsGrid.Columns[2].Width = if ($dw -lt 720) { 132 } elseif ($dw -lt 900) { 160 } else { 200 }

        # JUNTAR LOTES: a barra de ações de topo deixa de depender de 982 px fixos.
        $jw = [Math]::Max(520, [int]$tabCombine.ClientSize.Width)
        $jh = [Math]::Max(340, [int]$tabCombine.ClientSize.Height)
        $jInnerW = [Math]::Max(460, $jw - 36)
        $gap = if ($jw -lt 650) { 6 } else { 8 }

        if ($jw -ge 930) {
            $specs = @(
                @($combineAddButton, 172), @($combineRemoveButton, 100), @($combineUpButton, 86),
                @($combineDownButton, 86), @($combineClearButton, 112), @($combineCopyQuantitiesButton, 145), @($combinePasteQuantitiesButton, 145)
            )
            $x = 18
            foreach ($spec in $specs) {
                $b = $spec[0]; $w = [int]$spec[1]
                $b.Top = 78; $b.Left = $x; $b.Width = $w; $b.Height = 34
                $x += $w + $gap
            }
            $combineAddButton.Text = "+  Adicionar planilhas..."
            $combineRemoveButton.Text = "−  Remover"
            $combineUpButton.Text = "↑  Subir"
            $combineDownButton.Text = "↓  Descer"
            $combineClearButton.Text = "×  Limpar lista"
            $balanceTop = 118
        }
        else {
            $small = ($jw -lt 650)
            $addW = if ($small) { 120 } else { 150 }
            $removeW = if ($small) { 76 } else { 90 }
            $upW = if ($small) { 60 } else { 72 }
            $downW = if ($small) { 68 } else { 78 }
            $clearW = if ($small) { 82 } else { 100 }
            $x = 18
            foreach ($pair in @(
                @($combineAddButton,$addW), @($combineRemoveButton,$removeW), @($combineUpButton,$upW),
                @($combineDownButton,$downW), @($combineClearButton,$clearW)
            )) {
                $b=$pair[0]; $w=[int]$pair[1]
                $b.Top=78; $b.Left=$x; $b.Width=$w; $b.Height=32
                $x += $w + $gap
            }
            $combineAddButton.Text = if ($small) { "+ Adicionar" } else { "+  Adicionar planilhas" }
            $combineRemoveButton.Text = "Remover"
            $combineUpButton.Text = "Subir"
            $combineDownButton.Text = "Descer"
            $combineClearButton.Text = "Limpar"

            $copyW = if ($small) { 104 } else { 120 }
            $pasteW = $copyW
            $combineCopyQuantitiesButton.Top = 116; $combineCopyQuantitiesButton.Left = 18; $combineCopyQuantitiesButton.Width = $copyW; $combineCopyQuantitiesButton.Height = 32
            $combinePasteQuantitiesButton.Top = 116; $combinePasteQuantitiesButton.Left = 18 + $copyW + $gap; $combinePasteQuantitiesButton.Width = $pasteW; $combinePasteQuantitiesButton.Height = 32
            $balanceTop = 154
        }

        $combineBalanceCard.Top = $balanceTop
        $combineBalanceCard.Width = $jInnerW
        $gridTop = $balanceTop + 48
        $combineGrid.Top = $gridTop
        $combineGrid.Width = $jInnerW

        $resultTop = [Math]::Max($gridTop + 105, $jh - 118)
        $combineStatusLabel.Top = $resultTop
        $previewCombineButton.Top = [Math]::Max($gridTop + 72, $resultTop - 9)
        $copyCombineStatusButton.Top = $previewCombineButton.Top
        $combineGrid.Height = [Math]::Max(90, $resultTop - $gridTop - 10)
        $combineStatusText.Top = $resultTop + 24
        $combineStatusText.Width = $jInnerW
        $combineStatusText.Height = [Math]::Max(58, $jh - $combineStatusText.Top - 12)
    }
    catch {}
}

'''
gen = gen.replace(marker, helper + marker, 1)

# O cálculo geral chama os dois passes internos.
gen = replace_once(
    gen,
    '''    Update-GeneratorResponsiveLayout
    Update-GeneratorInternalLayouts

    $clientWidth = [Math]::Max(1, $form.ClientSize.Width)''',
    '''    Update-GeneratorResponsiveLayout
    Update-GeneratorInternalLayouts
    Update-GeneratorRemainingLayouts

    $clientWidth = [Math]::Max(1, $form.ClientSize.Width)''',
    'chamada do acabamento restante'
)

# Ao trocar de página, recalcule tudo no mesmo ciclo de layout.
gen = replace_once(
    gen,
    '''    Update-RootLayout
    Update-GeneratorInternalLayouts
    $tabs.Invalidate()
})''',
    '''    Update-RootLayout
    Update-GeneratorInternalLayouts
    Update-GeneratorRemainingLayouts
    $tabs.Invalidate()
})''',
    'evento principal das abas'
)

# Recalcula diretamente quando páginas críticas mudam de tamanho.
insert_before = '$componentTabs.Add_SelectedIndexChanged({ Update-GeneratorInternalLayouts; $componentTabs.Invalidate() })\n'
if insert_before not in gen:
    raise RuntimeError('evento de subtabs nao localizado')
resize_events = '''$tabGenerate.Add_SizeChanged({ Update-GeneratorRemainingLayouts })
$tabExtra.Add_SizeChanged({ Update-GeneratorRemainingLayouts })
$tabDescriptions.Add_SizeChanged({ Update-GeneratorRemainingLayouts })
$tabCombine.Add_SizeChanged({ Update-GeneratorRemainingLayouts })

'''
gen = gen.replace(insert_before, resize_events + insert_before, 1)

write(GEN, gen)
