from pathlib import Path

path = Path('src/generated/Modulos/Controle-NF-Entrada/Controle NF Entrada.ps1')
text = path.read_text(encoding='utf-8-sig')


def replace_one(old: str, new: str, label: str):
    global text
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: esperado 1 marcador, encontrado {count}')
    text = text.replace(old, new, 1)

replace_one(
    '''$mainTabs = New-Object Windows.Forms.TabControl\n$mainTabs.Dock = [Windows.Forms.DockStyle]::Fill\n$mainTabs.Font = [Drawing.Font]::new("Segoe UI Semibold", 9)\n$root.Controls.Add($mainTabs, 0, 2)''',
    '''$mainTabs = New-Object Windows.Forms.TabControl\n$mainTabs.Dock = [Windows.Forms.DockStyle]::Fill\n$mainTabs.Font = [Drawing.Font]::new("Segoe UI Semibold", 9)\n$mainTabs.Appearance = [Windows.Forms.TabAppearance]::Normal\n$mainTabs.DrawMode = [Windows.Forms.TabDrawMode]::OwnerDrawFixed\n$mainTabs.SizeMode = [Windows.Forms.TabSizeMode]::Fixed\n$mainTabs.Multiline = $false\n$mainTabs.HotTrack = $true\n$mainTabs.Padding = [Drawing.Point]::new(3, 2)\n$mainTabs.ItemSize = [Drawing.Size]::new(150, 28)\n$root.Controls.Add($mainTabs, 0, 2)''',
    'configuração owner-draw das abas NF'
)

replace_one(
    '''$mainTabs.TabPages.Add($summaryTab)\n$mainTabs.SelectedTab = $computerTab''',
    '''$mainTabs.TabPages.Add($summaryTab)\n\nfunction Update-NFMainTabStripLayout {\n    if ($null -eq $mainTabs -or $mainTabs.IsDisposed -or $mainTabs.TabPages.Count -le 0) { return }\n    try {\n        $available = [Math]::Max(1, $mainTabs.ClientSize.Width - 6)\n        $count = [Math]::Max(1, $mainTabs.TabPages.Count)\n        $single = [int][Math]::Floor($available / $count)\n        if ($single -ge 112) {\n            $mainTabs.Multiline = $false\n            $width = [Math]::Max(112, $single)\n        }\n        else {\n            # Em áreas estreitas usamos duas linhas de três abas. Assim a faixa\n            # continua totalmente coberta e nenhum cabeçalho é cortado.\n            $mainTabs.Multiline = $true\n            $width = [Math]::Max(112, [int][Math]::Floor($available / 3))\n        }\n        $mainTabs.ItemSize = [Drawing.Size]::new($width, 28)\n        $mainTabs.Invalidate()\n    } catch {}\n}\n\n$mainTabs.Add_DrawItem({\n    param($sender, $eventArgs)\n    if ($null -eq $script:CurrentPalette -or $eventArgs.Index -lt 0 -or $eventArgs.Index -ge $sender.TabPages.Count) { return }\n    $selected = ($eventArgs.Index -eq $sender.SelectedIndex)\n    $background = if ($selected) { $script:CurrentPalette.AccentStrong } else { $script:CurrentPalette.Card }\n    $foreground = if ($selected) { $script:CurrentPalette.AccentText } else { $script:CurrentPalette.Text }\n    $border = $script:CurrentPalette.Border\n    $backBrush = New-Object Drawing.SolidBrush($background)\n    $borderPen = New-Object Drawing.Pen($border)\n    try {\n        $eventArgs.Graphics.FillRectangle($backBrush, $eventArgs.Bounds)\n        $rect = [Drawing.Rectangle]::new($eventArgs.Bounds.X, $eventArgs.Bounds.Y, [Math]::Max(1, $eventArgs.Bounds.Width - 1), [Math]::Max(1, $eventArgs.Bounds.Height - 1))\n        $eventArgs.Graphics.DrawRectangle($borderPen, $rect)\n        [Windows.Forms.TextRenderer]::DrawText(\n            $eventArgs.Graphics,\n            $sender.TabPages[$eventArgs.Index].Text,\n            $sender.Font,\n            $eventArgs.Bounds,\n            $foreground,\n            ([Windows.Forms.TextFormatFlags]::HorizontalCenter -bor [Windows.Forms.TextFormatFlags]::VerticalCenter -bor [Windows.Forms.TextFormatFlags]::EndEllipsis)\n        )\n    }\n    finally { $backBrush.Dispose(); $borderPen.Dispose() }\n})\n$mainTabs.Add_SizeChanged({ Update-NFMainTabStripLayout })\n$mainTabs.Add_HandleCreated({ Update-NFMainTabStripLayout })\n$mainTabs.SelectedTab = $computerTab\nUpdate-NFMainTabStripLayout''',
    'desenho e dimensionamento das abas NF'
)

replace_one(
    '''    Set-NFEntradaStatusRowTheme $movementGrid "MovementStatus"\n    $form.PerformLayout()\n    $form.Invalidate($true)''',
    '''    Set-NFEntradaStatusRowTheme $movementGrid "MovementStatus"\n    Update-NFMainTabStripLayout\n    $mainTabs.Invalidate()\n    $form.PerformLayout()\n    $form.Invalidate($true)''',
    'repaint das abas na troca de tema'
)

replace_one(
    '''        [pscustomobject]@{ Name = "abas"; Actual = [int]$mainTabs.BackColor.ToArgb(); Expected = [int]$palette.Background.ToArgb() },\n        [pscustomobject]@{ Name = "aba computador"; Actual = [int]$computerTab.BackColor.ToArgb(); Expected = [int]$palette.Background.ToArgb() },''',
    '''        [pscustomobject]@{ Name = "abas owner-draw"; Actual = $(if ($mainTabs.DrawMode -eq [Windows.Forms.TabDrawMode]::OwnerDrawFixed) { 1 } else { 0 }); Expected = 1 },\n        [pscustomobject]@{ Name = "cobertura da faixa de abas"; Actual = $(\n            $tabsPerRow = if ($mainTabs.Multiline) { [Math]::Min(3, $mainTabs.TabPages.Count) } else { $mainTabs.TabPages.Count }\n            if (($mainTabs.ItemSize.Width * $tabsPerRow) -ge ($mainTabs.ClientSize.Width - 14)) { 1 } else { 0 }\n        ); Expected = 1 },\n        [pscustomobject]@{ Name = "aba computador"; Actual = [int]$computerTab.BackColor.ToArgb(); Expected = [int]$palette.Background.ToArgb() },\n        [pscustomobject]@{ Name = "aba teclado"; Actual = [int]$keyboardTab.BackColor.ToArgb(); Expected = [int]$palette.Background.ToArgb() },\n        [pscustomobject]@{ Name = "aba movimentações"; Actual = [int]$movementTab.BackColor.ToArgb(); Expected = [int]$palette.Background.ToArgb() },\n        [pscustomobject]@{ Name = "aba histórico"; Actual = [int]$historyTab.BackColor.ToArgb(); Expected = [int]$palette.Background.ToArgb() },\n        [pscustomobject]@{ Name = "aba segurança"; Actual = [int]$securityTab.BackColor.ToArgb(); Expected = [int]$palette.Background.ToArgb() },\n        [pscustomobject]@{ Name = "aba resumo"; Actual = [int]$summaryTab.BackColor.ToArgb(); Expected = [int]$palette.Background.ToArgb() },''',
    'auditoria visual das abas NF'
)

path.write_text(text, encoding='utf-8')
print('NF TABSTRIP: OK - abas owner-draw seguem a paleta e cobrem toda a faixa visível.')
