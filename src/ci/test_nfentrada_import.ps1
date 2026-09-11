param(
    [string]$CorePath = ".\src\generated\Modulos\Controle-NF-Entrada\NFEntrada.Core.ps1"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

if (-not (Test-Path -LiteralPath $CorePath -PathType Leaf)) {
    throw "NFEntrada.Core.ps1 não encontrado: $CorePath"
}

. $CorePath
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$root = Join-Path $env:RUNNER_TEMP ("nfentrada-import-" + [guid]::NewGuid().ToString("N"))
$dataDir = Join-Path $root "dados"
$xlsx = Join-Path $root "NF DE ENTRADA.xlsx"
New-Item -ItemType Directory -Force -Path $root | Out-Null

function Add-ZipTextEntry {
    param(
        [Parameter(Mandatory = $true)][IO.Compression.ZipArchive]$Archive,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Text
    )
    $entry = $Archive.CreateEntry($Name, [IO.Compression.CompressionLevel]::Optimal)
    $stream = $entry.Open()
    $writer = $null
    try {
        $writer = [IO.StreamWriter]::new($stream, [Text.UTF8Encoding]::new($false))
        $writer.Write($Text)
    }
    finally {
        if ($null -ne $writer) { $writer.Dispose() }
        else { $stream.Dispose() }
    }
}

try {
    $file = [IO.File]::Open($xlsx, [IO.FileMode]::CreateNew, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
    $zip = $null
    try {
        $zip = [IO.Compression.ZipArchive]::new($file, [IO.Compression.ZipArchiveMode]::Create, $false)
        $sheet1 = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData><row r="3"><c r="A3"><v>45544</v></c><c r="B3"><v>10</v></c><c r="C3"><v>12345</v></c><c r="D3"><v>4</v></c><c r="E3"><v>800</v></c><c r="F3" t="inlineStr"><is><t>54321</t></is></c></row></sheetData></worksheet>'
        $sheet2 = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?><worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData><row r="3"><c r="A3"><v>45545</v></c><c r="B3"><v>8</v></c><c r="C3"><v>67890</v></c><c r="D3"><v>3</v></c><c r="E3"><v>850</v></c><c r="F3" t="inlineStr"><is><t>98765</t></is></c></row></sheetData></worksheet>'
        Add-ZipTextEntry -Archive $zip -Name "xl/worksheets/sheet1.xml" -Text $sheet1
        Add-ZipTextEntry -Archive $zip -Name "xl/worksheets/sheet2.xml" -Text $sheet2
    }
    finally {
        if ($null -ne $zip) { $zip.Dispose() }
        else { $file.Dispose() }
    }

    $beforeHash = (Get-FileHash -LiteralPath $xlsx -Algorithm SHA256).Hash
    $result = Import-NFEntradaSourceWorkbook -SourcePath $xlsx -DataDirectory $dataDir

    if (-not (Test-Path -LiteralPath $xlsx -PathType Leaf)) { throw "A importação removeu a planilha original." }
    $afterHash = (Get-FileHash -LiteralPath $xlsx -Algorithm SHA256).Hash
    if ($beforeHash -ne $afterHash) { throw "A importação alterou a planilha original." }
    if (-not (Test-Path -LiteralPath $result.TemplatePath -PathType Leaf)) { throw "A cópia protegida do modelo não foi criada." }
    if (-not (Test-Path -LiteralPath $result.StorePath -PathType Leaf)) { throw "A base local não foi criada." }

    $templateHash = (Get-FileHash -LiteralPath $result.TemplatePath -Algorithm SHA256).Hash
    if ($templateHash -ne $beforeHash) { throw "A cópia protegida não é idêntica à planilha original." }

    $store = Read-NFEntradaStore -Path $result.StorePath
    $cb = @(Get-NFEntradaProductRecords -Store $store -Product "COMPUTADOR DE BORDO V5")
    $tk = @(Get-NFEntradaProductRecords -Store $store -Product "TECLADO V5")
    if ($cb.Count -ne 1 -or $tk.Count -ne 1) { throw "Quantidade de registros importados incorreta: CB=$($cb.Count), TK=$($tk.Count)." }
    if ([string]$cb[0].NFEntrada -ne "12345" -or [int]$cb[0].QuantidadeSaldo -ne 4 -or [string]$cb[0].Codigo -ne "800") {
        throw "Registro de Computador de Bordo importado incorretamente."
    }
    if ([string]$tk[0].NFEntrada -ne "67890" -or [int]$tk[0].QuantidadeSaldo -ne 3 -or [string]$tk[0].Codigo -ne "850") {
        throw "Registro de Teclado importado incorretamente."
    }

    Write-Host "IMPORTAÇÃO NF ENTRADA: OK — original preservado, modelo copiado e registros importados."
}
finally {
    if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
}
