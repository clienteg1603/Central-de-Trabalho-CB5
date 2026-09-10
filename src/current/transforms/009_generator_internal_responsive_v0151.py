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
central = replace_once(central, '$script:AppVersion = "0.15.0"', '$script:AppVersion = "0.15.1"', 'versao Central')
central = replace_once(central, '$script:GeneratorVersion = "3.7.0"', '$script:GeneratorVersion = "3.7.1"', 'versao Gerenciador na Central')
write(CENTRAL, central)

gen = read(GEN)
gen = replace_once(gen, '$script:AppVersion = "3.7.0"', '$script:AppVersion = "3.7.1"', 'versao Gerenciador')

# Remove tooltips duplicados que foram acumulados durante o polimento anterior.
gen = gen.replace('$toolTip.SetToolTip($componentLaunchButton, "Registrar no saldo uma quantidade de componente que já foi usada e ainda será faturada.")\n', '')
gen = gen.replace('$toolTip.SetToolTip($componentAdjustButton, "Corrigir manualmente o saldo atual do componente selecionado.")\n', '')

marker = 'function Update-RootLayout {\n'
if gen.count(marker) != 1:
    raise RuntimeError('Update-RootLayout nao localizado de forma unica')

helper = r'''function Update-GeneratorInternalLayouts {
    if (-not $script:IsInProcessHosted) { return }
    try {
        # Componentes: a barra de pesquisa e as ações da direita passam a usar
        # o espaço real da página, evitando colisões em DPI e larguras menores.
        $cw = [Math]::Max(520, [int]$tabComponents.ClientSize.Width)
        $ch = [Math]::Max(320, [int]$tabComponents.ClientSize.Height)
        $innerW = [Math]::Max(460, $cw - 36)

        foreach ($control in @($componentsIntro, $componentMetricsLayout, $componentTabs)) {
            if ($null -ne $control) { $control.Width = $innerW }
        }

        $actionW = if ($cw -lt 850) { 92 } else { 118 }
        $gap = 8
        $right = $cw - 18
        $componentRestoreButton.Width = $actionW
        $componentBackupButton.Width = $actionW
        $componentRestoreButton.Left = [Math]::Max(18, $right - $actionW)
        $componentBackupButton.Left = [Math]::Max(18, $componentRestoreButton.Left - $gap - $actionW)

        $componentSearchText.Width = if ($cw -lt 760) { 170 } elseif ($cw -lt 980) { 220 } else { 260 }
        $componentSearchClearButton.Left = $componentSearchText.Right + 8
        $componentSearchClearButton.Width = if ($cw -lt 760) { 64 } else { 76 }
        $summaryLeft = $componentSearchClearButton.Right + 12
        $summaryRight = $componentBackupButton.Left - 10
        if (($summaryRight - $summaryLeft) -ge 120) {
            $componentsSummaryLabel.Visible = $true
            $componentsSummaryLabel.Left = $summaryLeft
            $componentsSummaryLabel.Width = $summaryRight - $summaryLeft
        }
        else {
            $componentsSummaryLabel.Visible = $false
        }

        # As três subtelas de Componentes dividem a largura disponível.
        $componentTabAvailable = [Math]::Max(330, $componentTabs.ClientSize.Width - 8)
        $componentTabWidth = [Math]::Min(210, [Math]::Max(105, [int][Math]::Floor($componentTabAvailable / 3)))
        $componentTabs.SizeMode = [Windows.Forms.TabSizeMode]::Fixed
        $componentTabs.ItemSize = [Drawing.Size]::new($componentTabWidth, $(if ($script:GeneratorResponsiveProfile -eq 'Tight') { 26 } else { 30 }))

        # Juntar lotes: cartão de saldo, grade e resultado acompanham a página real.
        $jw = [Math]::Max(520, [int]$tabCombine.ClientSize.Width)
        $jInnerW = [Math]::Max(460, $jw - 36)
        foreach ($control in @($combineBalanceCard, $combineGrid, $combineStatusText)) {
            if ($null -ne $control) { $control.Width = $jInnerW }
        }
        $combineConsumeBalanceCheck.Width = [Math]::Max(210, [int]($jInnerW * 0.58))
        $combineBalanceStatus.Width = [Math]::Max(130, $jInnerW - $combineConsumeBalanceCheck.Width - 24)
        $combineBalanceStatus.Left = [Math]::Max(12, $jInnerW - $combineBalanceStatus.Width - 12)
        $combineBalanceStatus.AutoEllipsis = $true

        $copyW = if ($jw -lt 760) { 118 } else { 157 }
        $previewW = if ($jw -lt 760) { 126 } else { 158 }
        $copyCombineStatusButton.Width = $copyW
        $previewCombineButton.Width = $previewW
        $copyCombineStatusButton.Left = [Math]::Max(18, $jw - 18 - $copyW)
        $previewCombineButton.Left = [Math]::Max(18, $copyCombineStatusButton.Left - 10 - $previewW)

        # Gerar: os dois botões de conferência também evitam se encostar no título.
        $gw = [Math]::Max(520, [int]$tabGenerate.ClientSize.Width)
        $copyStatusButton.Width = if ($gw -lt 760) { 118 } else { 157 }
        $previewMasterButton.Width = if ($gw -lt 760) { 126 } else { 158 }
        $copyStatusButton.Left = [Math]::Max(18, $gw - 18 - $copyStatusButton.Width)
        $previewMasterButton.Left = [Math]::Max(18, $copyStatusButton.Left - 10 - $previewMasterButton.Width)

        if ($gw -lt 700) {
            $previewMasterButton.Text = 'Conferir'
            $copyStatusButton.Text = 'Copiar'
            $previewCombineButton.Text = 'Conferir'
            $copyCombineStatusButton.Text = 'Copiar'
        }
        else {
            $previewMasterButton.Text = 'Conferir primeiro'
            $copyStatusButton.Text = 'Copiar resultado'
            $previewCombineButton.Text = 'Conferir primeiro'
            $copyCombineStatusButton.Text = 'Copiar resultado'
        }
    }
    catch {}
}

'''
gen = gen.replace(marker, helper + marker, 1)

gen = replace_once(
    gen,
    '    Update-GeneratorResponsiveLayout\n\n    $clientWidth = [Math]::Max(1, $form.ClientSize.Width)',
    '    Update-GeneratorResponsiveLayout\n    Update-GeneratorInternalLayouts\n\n    $clientWidth = [Math]::Max(1, $form.ClientSize.Width)',
    'chamada do layout interno'
)

# Recalcula também ao trocar de página principal e de subpágina de Componentes.
old_tabs_event = '''    Update-RootLayout
    $tabs.Invalidate()
})'''
new_tabs_event = '''    Update-RootLayout
    Update-GeneratorInternalLayouts
    $tabs.Invalidate()
})'''
if old_tabs_event not in gen:
    raise RuntimeError('evento principal de tabs nao localizado')
gen = gen.replace(old_tabs_event, new_tabs_event, 1)

# Subtabs de Componentes ganham recálculo próprio sem alterar a lógica funcional.
insert_before = '$form.Add_KeyDown({\n'
if insert_before not in gen:
    raise RuntimeError('marcador Add_KeyDown nao localizado')
gen = gen.replace(insert_before, '$componentTabs.Add_SelectedIndexChanged({ Update-GeneratorInternalLayouts; $componentTabs.Invalidate() })\n\n' + insert_before, 1)

write(GEN, gen)
