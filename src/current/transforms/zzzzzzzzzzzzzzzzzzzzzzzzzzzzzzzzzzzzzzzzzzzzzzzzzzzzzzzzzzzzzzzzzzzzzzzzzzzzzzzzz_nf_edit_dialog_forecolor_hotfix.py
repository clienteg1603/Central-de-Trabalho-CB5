from pathlib import Path

central_path = Path('src/generated/Central de Trabalho.ps1')
nf_path = Path('src/generated/Modulos/Controle-NF-Entrada/Controle NF Entrada.ps1')

central = central_path.read_text(encoding='utf-8-sig')
nf = nf_path.read_text(encoding='utf-8-sig')


def one(text, old, new, label):
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'NF EDIT HOTFIX {label}: esperado 1, encontrado {count}')
    return text.replace(old, new, 1)


# Hotfix de manutenção: nenhuma alteração na lógica de restauração validada na
# v0.22.0. A Central só avança a versão e o Controle de NF recebe a correção.
central = one(
    central,
    '$script:AppVersion = "0.22.0"',
    '$script:AppVersion = "0.22.1"',
    'versao Central'
)
central = one(
    central,
    '$script:NFEntradaVersion = "2.6.25"',
    '$script:NFEntradaVersion = "2.6.26"',
    'versao NF na Central'
)
nf = one(
    nf,
    '$script:ModuleVersion = "2.6.25"',
    '$script:ModuleVersion = "2.6.26"',
    'versao NF'
)

# Show-NFRecordDialog usa GetNewClosure para manter vivos os controles do modal.
# Em PowerShell, GetNewClosure cria um novo contexto de módulo; portanto, acessos
# $script:CurrentPalette e $script:Store dentro desse closure deixam de apontar
# para o script do Controle de NF. O resultado era Store nulo durante a validação
# e, no catch, CurrentPalette.Danger nulo, gerando SetValueInvocationException em
# ForeColor antes que a janela de EDITAR pudesse abrir.
#
# Capturamos explicitamente as duas dependências em variáveis locais antes de
# criar o closure. Variáveis locais são exatamente o que GetNewClosure preserva.
anchor = '''    $ignoreId = if ($null -ne $Existing) { [int]$Existing.Id } else { 0 }
    $validateDialog = {'''
replacement = '''    $ignoreId = if ($null -ne $Existing) { [int]$Existing.Id } else { 0 }

    # Dependências do módulo capturadas localmente para o GetNewClosure.
    $dialogStore = $script:Store
    $dialogPalette = $script:CurrentPalette
    if ($null -eq $dialogPalette) {
        $dialogPalette = Get-NFEntradaPalette (Get-NFEntradaHostedCentralTheme)
    }
    $validateDialog = {'''
nf = one(nf, anchor, replacement, 'captura de dependencias do dialogo')

nf = one(
    nf,
    '[void](Test-NFEntradaRecord -Record $candidate -Store $script:Store -Product $Product -IgnoreId $ignoreId)',
    '[void](Test-NFEntradaRecord -Record $candidate -Store $dialogStore -Product $Product -IgnoreId $ignoreId)',
    'store do closure'
)
nf = one(
    nf,
    '$validationLabel.ForeColor = $script:CurrentPalette.Success',
    '$validationLabel.ForeColor = $dialogPalette.Success',
    'cor de sucesso do closure'
)
nf = one(
    nf,
    '$validationLabel.ForeColor = $script:CurrentPalette.Danger',
    '$validationLabel.ForeColor = $dialogPalette.Danger',
    'cor de erro do closure'
)

nf += '''
# NF_EDIT_DIALOG_CLOSURE_SCOPE_HOTFIX_V02626
'''
central += '''
# CENTRAL_NF_EDIT_HOTFIX_V0221
'''

for marker in (
    '$script:AppVersion = "0.22.1"',
    '$script:NFEntradaVersion = "2.6.26"',
    'CENTRAL_RESTORE_LIVE_HOST_REDRAW_STAGE3_V02169',
    'CENTRAL_STABLE_RELEASE_V0220',
    'CENTRAL_NF_EDIT_HOTFIX_V0221',
):
    if marker not in central:
        raise SystemExit('NF EDIT HOTFIX Central marcador ausente: ' + marker)

for marker in (
    '$script:ModuleVersion = "2.6.26"',
    '$dialogStore = $script:Store',
    '$dialogPalette = $script:CurrentPalette',
    '-Store $dialogStore',
    '$validationLabel.ForeColor = $dialogPalette.Success',
    '$validationLabel.ForeColor = $dialogPalette.Danger',
    'NF_EDIT_DIALOG_CLOSURE_SCOPE_HOTFIX_V02626',
):
    if marker not in nf:
        raise SystemExit('NF EDIT HOTFIX NF marcador ausente: ' + marker)

central_path.write_text(central, encoding='utf-8')
nf_path.write_text(nf, encoding='utf-8')
print('NF EDIT HOTFIX: OK - closure do formulário captura Store e Palette locais; restauração da Central preservada.')
