from pathlib import Path

p = Path('src/generated/Central de Trabalho.ps1')
s = p.read_text(encoding='utf-8-sig')


def one(a, b):
    global s
    if s.count(a) != 1:
        raise SystemExit('marcador inesperado: ' + a[:50])
    s = s.replace(a, b, 1)


one('$script:AppVersion = "0.21.33"', '$script:AppVersion = "0.21.35"')
one('$script:NFEntradaVersion = "2.6.9"', '$script:NFEntradaVersion = "2.6.10"')
one('    catch {}\n    return $settings\n}\n\nfunction Save-AppSettings', '    catch {}\n    if (-not $ThemeRuntimeSelfTest) { $settings.Theme = "Técnico industrial" }\n    return $settings\n}\n\nfunction Save-AppSettings')
one('$sidebarStatus.Location = [Drawing.Point]::new(4, 75)', '$sidebarStatus.Location = [Drawing.Point]::new(4, 12)')
one('$sidebarStatusSub.Location = [Drawing.Point]::new(20, 98)', '$sidebarStatusSub.Location = [Drawing.Point]::new(20, 36)')
one('$sidebarVersion.Location = [Drawing.Point]::new(4, 123)', '$sidebarVersion.Location = [Drawing.Point]::new(4, 61)')
one('$sidebarBottom.Controls.Add($sidebarVersion)\n\n# --- Conteúdo principal ---', '$sidebarBottom.Controls.Add($sidebarVersion)\n\nif (-not $ThemeRuntimeSelfTest) {\n    $sidebarThemeLabel.Visible = $false\n    $themeCombo.Visible = $false\n}\n\n# --- Conteúdo principal ---')
p.write_text(s, encoding='utf-8')

nf = Path('src/generated/Modulos/Controle-NF-Entrada/Controle NF Entrada.ps1')
n = nf.read_text(encoding='utf-8-sig')
marker = '$script:ModuleVersion = "2.6.9"'
if n.count(marker) != 1:
    raise SystemExit('versão do Controle de NF inesperada')
n = n.replace(marker, '$script:ModuleVersion = "2.6.10"', 1)
nf.write_text(n, encoding='utf-8')

print('Tema fixo Técnico industrial aplicado; NF Entrada v2.6.10 sem tabstrip experimental.')
