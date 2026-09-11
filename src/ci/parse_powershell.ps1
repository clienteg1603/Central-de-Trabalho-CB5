param(
    [Parameter(Mandatory = $true)]
    [string]$Root
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $Root -PathType Container)) {
    throw "Pasta do pacote nao encontrada: $Root"
}

$files = @(Get-ChildItem -LiteralPath $Root -Recurse -File -Filter *.ps1 | Sort-Object FullName)
if ($files.Count -eq 0) {
    throw "Nenhum script PowerShell encontrado para validar."
}

$allErrors = [System.Collections.Generic.List[string]]::new()
foreach ($file in $files) {
    $tokens = $null
    $parseErrors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile(
        $file.FullName,
        [ref]$tokens,
        [ref]$parseErrors
    )
    foreach ($parseError in @($parseErrors)) {
        $allErrors.Add("$($file.FullName): linha $($parseError.Extent.StartLineNumber), coluna $($parseError.Extent.StartColumnNumber): $($parseError.Message)")
    }
}

if ($allErrors.Count -gt 0) {
    Write-Host "SINTAXE POWERSHELL: FALHOU"
    foreach ($item in $allErrors) { Write-Host "  - $item" }
    exit 1
}

Write-Host "SINTAXE POWERSHELL: OK - $($files.Count) scripts analisados sem erro de parser."

# O Controle de NF de Entrada possui uma auditoria final permanente que valida
# o fluxo operacional e os contratos atuais da interface em todo novo pacote.
$nfFinalTest = Join-Path $PSScriptRoot "test_nfentrada_final.ps1"
if (Test-Path -LiteralPath $nfFinalTest -PathType Leaf) {
    $corePath = Join-Path $Root "Modulos/Controle-NF-Entrada/NFEntrada.Core.ps1"
    $uiPath = Join-Path $Root "Modulos/Controle-NF-Entrada/Controle NF Entrada.ps1"
    $centralPath = Join-Path $Root "Central de Trabalho.ps1"
    & $nfFinalTest -CorePath $corePath -UiPath $uiPath -CentralPath $centralPath
}
