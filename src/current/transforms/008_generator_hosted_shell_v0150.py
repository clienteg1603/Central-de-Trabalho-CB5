from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CENTRAL = ROOT / "generated" / "Central de Trabalho.ps1"
GENERATOR = ROOT / "generated" / "Modulos" / "Gerador-de-Planilhas-CB5-TV5" / "Gerador Planilhas.ps1"


def read(path):
    return path.read_text(encoding="utf-8-sig")


def write(path, text):
    path.write_text(text, encoding="utf-8-sig")


def replace_once(text, old, new, label):
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: esperado 1 trecho, encontrado {count}")
    return text.replace(old, new, 1)


# ---------------------------------------------------------------------------
# CENTRAL DE TRABALHO
# ---------------------------------------------------------------------------
central = read(CENTRAL)
central = replace_once(central, '$script:AppVersion = "0.14.5"', '$script:AppVersion = "0.15.0"', "versao Central")
central = replace_once(central, '$script:GeneratorVersion = "3.6.2"', '$script:GeneratorVersion = "3.7.0"', "versao Gerenciador na Central")
write(CENTRAL, central)


# ---------------------------------------------------------------------------
# GERENCIADOR DE PLANILHAS
# ---------------------------------------------------------------------------
gen = read(GENERATOR)
gen = replace_once(gen, '$script:AppVersion = "3.6.2"', '$script:AppVersion = "3.7.0"', "versao Gerenciador")
gen = replace_once(
    gen,
    '$script:EmbeddedResizeTimer = $null\n',
    '$script:EmbeddedResizeTimer = $null\n$script:GeneratorHostedShell = $null\n',
    "estado do shell hospedado"
)

# No modo integrado, header, abas e rodape passam a ocupar linhas reais de um
# TableLayoutPanel. Isso elimina a dependencia de coordenadas Top/Height entre
# controles ancorados e evita sobreposicao ao mudar resolucao, DPI ou tamanho.
marker = '''$footerPanel.Controls.Add($combineGenerateButton)\n\n# Layout compacto quando o Gerenciador está hospedado dentro da Central de Trabalho.'''
shell = '''$footerPanel.Controls.Add($combineGenerateButton)

if ($script:IsInProcessHosted) {
    $script:GeneratorHostedShell = New-Object Windows.Forms.TableLayoutPanel
    $script:GeneratorHostedShell.Dock = [Windows.Forms.DockStyle]::Fill
    $script:GeneratorHostedShell.Margin = New-Object Windows.Forms.Padding(0)
    $script:GeneratorHostedShell.Padding = New-Object Windows.Forms.Padding(0)
    $script:GeneratorHostedShell.ColumnCount = 1
    $script:GeneratorHostedShell.RowCount = 3
    [void]$script:GeneratorHostedShell.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 100)))
    [void]$script:GeneratorHostedShell.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 42)))
    [void]$script:GeneratorHostedShell.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 100)))
    [void]$script:GeneratorHostedShell.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 56)))

    try { $form.Controls.Remove($headerPanel) } catch {}
    try { $form.Controls.Remove($tabs) } catch {}
    try { $form.Controls.Remove($footerPanel) } catch {}

    $headerPanel.Dock = [Windows.Forms.DockStyle]::Fill
    $headerPanel.Margin = New-Object Windows.Forms.Padding(0)
    $tabs.Dock = [Windows.Forms.DockStyle]::Fill
    $tabs.Margin = New-Object Windows.Forms.Padding(6, 4, 6, 3)
    $footerPanel.Dock = [Windows.Forms.DockStyle]::Fill
    $footerPanel.Margin = New-Object Windows.Forms.Padding(0)

    $script:GeneratorHostedShell.Controls.Add($headerPanel, 0, 0)
    $script:GeneratorHostedShell.Controls.Add($tabs, 0, 1)
    $script:GeneratorHostedShell.Controls.Add($footerPanel, 0, 2)
    $form.Controls.Add($script:GeneratorHostedShell)
    $script:GeneratorHostedShell.BringToFront()
}

# Layout compacto quando o Gerenciador está hospedado dentro da Central de Trabalho.'''
gen = replace_once(gen, marker, shell, "shell real do Gerenciador integrado")

# Mantem as cinco secoes proporcionais no topo. O texto completo cabe na maior
# parte das larguras; nos perfis menores o proprio OwnerDraw usa ellipsis.
old_profile_start = '''        switch ($profile) {
            "Tight" {
                $form.Font = [Drawing.Font]::new("Segoe UI",8.2)
                $headerPanel.Height = 34; $accentStrip.Height = 34
                $productLabel.Location = [Drawing.Point]::new(10,9)
                $productCombo.Location = [Drawing.Point]::new(62,3); $productCombo.Size = [Drawing.Size]::new(145,26)
                $tabs.Location = [Drawing.Point]::new(5,37); $tabs.ItemSize = [Drawing.Size]::new(0,27); $tabs.Padding = [Drawing.Point]::new(8,3)
                $footerPanel.Height = 46
                $progressStatusLabel.Top = 3; $progressBar.Top = 23
                $generateButton.Height = 31; $combineGenerateButton.Height = 31; $updateMasterButton.Height = 31
                $generateButton.Width = 222; $combineGenerateButton.Width = 222; $updateMasterButton.Width = 180
            }
            "Compact" {
                $form.Font = [Drawing.Font]::new("Segoe UI",8.7)
                $headerPanel.Height = 38; $accentStrip.Height = 38
                $productLabel.Location = [Drawing.Point]::new(12,10)
                $productCombo.Location = [Drawing.Point]::new(69,5); $productCombo.Size = [Drawing.Size]::new(158,27)
                $tabs.Location = [Drawing.Point]::new(6,41); $tabs.ItemSize = [Drawing.Size]::new(0,29); $tabs.Padding = [Drawing.Point]::new(10,4)
                $footerPanel.Height = 50
                $progressStatusLabel.Top = 4; $progressBar.Top = 25
                $generateButton.Height = 33; $combineGenerateButton.Height = 33; $updateMasterButton.Height = 33
                $generateButton.Width = 238; $combineGenerateButton.Width = 238; $updateMasterButton.Width = 190
            }
            default {
                $form.Font = [Drawing.Font]::new("Segoe UI",9.25)
                $headerPanel.Height = 42; $accentStrip.Height = 42
                $productLabel.Location = [Drawing.Point]::new(16,12)
                $productCombo.Location = [Drawing.Point]::new(78,6); $productCombo.Size = [Drawing.Size]::new(172,28)
                $tabs.Location = [Drawing.Point]::new(8,46); $tabs.ItemSize = [Drawing.Size]::new(0,31); $tabs.Padding = [Drawing.Point]::new(14,5)
                $footerPanel.Height = 56
                $progressStatusLabel.Top = 5; $progressBar.Top = 27
                $generateButton.Height = 36; $combineGenerateButton.Height = 36; $updateMasterButton.Height = 36
                $generateButton.Width = 254; $combineGenerateButton.Width = 254; $updateMasterButton.Width = 205
            }
        }
        foreach ($page in @($tabGenerate,$tabExtra,$tabComponents,$tabCombine,$tabDescriptions)) { $page.AutoScroll = $true; $page.AutoScrollMinSize = [Drawing.Size]::new(0,0) }'''
new_profile_start = '''        switch ($profile) {
            "Tight" {
                $form.Font = [Drawing.Font]::new("Segoe UI",8.2)
                $headerPanel.Height = 34; $accentStrip.Height = 34
                $productLabel.Location = [Drawing.Point]::new(10,9)
                $productCombo.Location = [Drawing.Point]::new(62,3); $productCombo.Size = [Drawing.Size]::new(145,26)
                $tabs.Padding = [Drawing.Point]::new(6,3)
                $footerPanel.Height = 46
                $progressStatusLabel.Top = 3; $progressBar.Top = 23
                $generateButton.Height = 31; $combineGenerateButton.Height = 31; $updateMasterButton.Height = 31
                $generateButton.Width = 222; $combineGenerateButton.Width = 222; $updateMasterButton.Width = 180
                if ($null -ne $script:GeneratorHostedShell) {
                    $script:GeneratorHostedShell.RowStyles[0].Height = 34
                    $script:GeneratorHostedShell.RowStyles[2].Height = 46
                }
                $tabHeaderHeight = 27
            }
            "Compact" {
                $form.Font = [Drawing.Font]::new("Segoe UI",8.7)
                $headerPanel.Height = 38; $accentStrip.Height = 38
                $productLabel.Location = [Drawing.Point]::new(12,10)
                $productCombo.Location = [Drawing.Point]::new(69,5); $productCombo.Size = [Drawing.Size]::new(158,27)
                $tabs.Padding = [Drawing.Point]::new(8,4)
                $footerPanel.Height = 50
                $progressStatusLabel.Top = 4; $progressBar.Top = 25
                $generateButton.Height = 33; $combineGenerateButton.Height = 33; $updateMasterButton.Height = 33
                $generateButton.Width = 238; $combineGenerateButton.Width = 238; $updateMasterButton.Width = 190
                if ($null -ne $script:GeneratorHostedShell) {
                    $script:GeneratorHostedShell.RowStyles[0].Height = 38
                    $script:GeneratorHostedShell.RowStyles[2].Height = 50
                }
                $tabHeaderHeight = 29
            }
            default {
                $form.Font = [Drawing.Font]::new("Segoe UI",9.25)
                $headerPanel.Height = 42; $accentStrip.Height = 42
                $productLabel.Location = [Drawing.Point]::new(16,12)
                $productCombo.Location = [Drawing.Point]::new(78,6); $productCombo.Size = [Drawing.Size]::new(172,28)
                $tabs.Padding = [Drawing.Point]::new(10,5)
                $footerPanel.Height = 56
                $progressStatusLabel.Top = 5; $progressBar.Top = 27
                $generateButton.Height = 36; $combineGenerateButton.Height = 36; $updateMasterButton.Height = 36
                $generateButton.Width = 254; $combineGenerateButton.Width = 254; $updateMasterButton.Width = 205
                if ($null -ne $script:GeneratorHostedShell) {
                    $script:GeneratorHostedShell.RowStyles[0].Height = 42
                    $script:GeneratorHostedShell.RowStyles[2].Height = 56
                }
                $tabHeaderHeight = 31
            }
        }

        $tabs.SizeMode = [Windows.Forms.TabSizeMode]::Fixed
        $navWidth = if ($tabs.ClientSize.Width -gt 200) { $tabs.ClientSize.Width } else { [Math]::Max(480, $form.ClientSize.Width - 16) }
        $tabWidth = [Math]::Min(190, [Math]::Max(92, [int][Math]::Floor(($navWidth - 10) / 5)))
        $tabs.ItemSize = [Drawing.Size]::new($tabWidth, $tabHeaderHeight)
        foreach ($page in @($tabGenerate,$tabExtra,$tabComponents,$tabCombine,$tabDescriptions)) { $page.AutoScroll = $true; $page.AutoScrollMinSize = [Drawing.Size]::new(0,0) }'''
gen = replace_once(gen, old_profile_start, new_profile_start, "perfis responsivos do Gerenciador")

old_root = '''    $clientWidth = [Math]::Max(1, $form.ClientSize.Width)
    $headerPanel.Width = $clientWidth
    $tabs.Width = [Math]::Max(320, $clientWidth - (2 * $tabs.Left))
    $bottomGap = if ($script:IsInProcessHosted) { 4 } else { 10 }
    $tabs.Height = [Math]::Max(220, $footerPanel.Top - $tabs.Top - $bottomGap)

    $rightMargin = if ($script:IsInProcessHosted -and $script:GeneratorResponsiveProfile -eq "Tight") { 8 } elseif ($script:IsInProcessHosted) { 12 } else { 20 }'''
new_root = '''    $clientWidth = [Math]::Max(1, $form.ClientSize.Width)
    if ($script:IsInProcessHosted -and $null -ne $script:GeneratorHostedShell) {
        $headerPanel.Dock = [Windows.Forms.DockStyle]::Fill
        $tabs.Dock = [Windows.Forms.DockStyle]::Fill
        $footerPanel.Dock = [Windows.Forms.DockStyle]::Fill
        $script:GeneratorHostedShell.PerformLayout()
    }
    else {
        $headerPanel.Width = $clientWidth
        $tabs.Width = [Math]::Max(320, $clientWidth - (2 * $tabs.Left))
        $bottomGap = 10
        $tabs.Height = [Math]::Max(220, $footerPanel.Top - $tabs.Top - $bottomGap)
    }

    $rightMargin = if ($script:IsInProcessHosted -and $script:GeneratorResponsiveProfile -eq "Tight") { 8 } elseif ($script:IsInProcessHosted) { 12 } else { 20 }'''
gen = replace_once(gen, old_root, new_root, "root responsivo sem coordenadas cruzadas")

# Quando o controle hospedado for redimensionado, recalcula a largura das abas
# depois de o TableLayout concluir a distribuicao das linhas.
old_host_end = '''    $form.Add_HandleCreated({ try { Update-GeneratorResponsiveLayout; Update-RootLayout } catch {} })
    $form.Add_Disposed({'''
new_host_end = '''    $form.Add_HandleCreated({ try { Update-GeneratorResponsiveLayout; Update-RootLayout } catch {} })
    if ($null -ne $script:GeneratorHostedShell) {
        $script:GeneratorHostedShell.Add_SizeChanged({ try { Update-GeneratorResponsiveLayout; Update-RootLayout } catch {} })
    }
    $form.Add_Disposed({'''
gen = replace_once(gen, old_host_end, new_host_end, "resize do shell hospedado")

write(GENERATOR, gen)
