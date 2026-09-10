param(
    [Parameter(Mandatory = $true)]
    [string]$Version,

    [Parameter(Mandatory = $true)]
    [string]$OutputDirectory,

    [Parameter(Mandatory = $true)]
    [string]$ReferenceExe
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

if (-not (Test-Path -LiteralPath $ReferenceExe -PathType Leaf)) {
    throw "Executável de referência não encontrado: $ReferenceExe"
}

$sourcePath = Join-Path $PSScriptRoot "CentralHost.cs"
if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
    throw "Fonte do host nativo não encontrado: $sourcePath"
}

[void](New-Item -ItemType Directory -Force -Path $OutputDirectory)
$outExe = Join-Path $OutputDirectory "Central de Trabalho.exe"
$iconPath = Join-Path $OutputDirectory "Central-de-Trabalho.ico"
$versionSource = Join-Path $OutputDirectory "AssemblyInfo.generated.cs"

Add-Type -AssemblyName System.Drawing
$icon = [System.Drawing.Icon]::ExtractAssociatedIcon((Resolve-Path -LiteralPath $ReferenceExe).Path)
if ($null -eq $icon) { throw "Não foi possível extrair o ícone do executável de referência." }
try {
    $stream = [IO.File]::Create($iconPath)
    try { $icon.Save($stream) }
    finally { $stream.Dispose() }
}
finally { $icon.Dispose() }

$parts = @($Version.Split('.'))
while ($parts.Count -lt 4) { $parts += '0' }
$fileVersion = (($parts | Select-Object -First 4) -join '.')
@"
using System.Reflection;
[assembly: AssemblyTitle("Central de Trabalho")]
[assembly: AssemblyProduct("Central de Trabalho CB5")]
[assembly: AssemblyCompany("Central de Trabalho CB5")]
[assembly: AssemblyDescription("Host gráfico nativo da Central de Trabalho")]
[assembly: AssemblyVersion("$fileVersion")]
[assembly: AssemblyFileVersion("$fileVersion")]
"@ | Set-Content -LiteralPath $versionSource -Encoding UTF8

$cscCandidates = @(
    (Join-Path $env:WINDIR "Microsoft.NET\Framework64\v4.0.30319\csc.exe"),
    (Join-Path $env:WINDIR "Microsoft.NET\Framework\v4.0.30319\csc.exe")
)
$csc = $cscCandidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
if ([string]::IsNullOrWhiteSpace($csc)) { throw "Compilador C# do .NET Framework não encontrado." }

$sma = [System.Management.Automation.PowerShell].Assembly.Location
if ([string]::IsNullOrWhiteSpace($sma) -or -not (Test-Path -LiteralPath $sma -PathType Leaf)) {
    throw "System.Management.Automation.dll do Windows PowerShell não foi localizada."
}

$arguments = @(
    '/nologo',
    '/target:winexe',
    '/platform:anycpu',
    '/optimize+',
    '/debug-',
    "/out:$outExe",
    "/win32icon:$iconPath",
    "/reference:$sma",
    '/reference:System.dll',
    '/reference:System.Core.dll',
    '/reference:System.Drawing.dll',
    '/reference:System.Windows.Forms.dll',
    $sourcePath,
    $versionSource
)

& $csc @arguments
if ($LASTEXITCODE -ne 0) { throw "Falha ao compilar o host nativo da Central (código $LASTEXITCODE)." }
if (-not (Test-Path -LiteralPath $outExe -PathType Leaf)) { throw "O compilador não gerou Central de Trabalho.exe." }

$bytes = [IO.File]::ReadAllBytes($outExe)
if ($bytes.Length -lt 1024 -or $bytes[0] -ne 0x4D -or $bytes[1] -ne 0x5A) {
    throw "O host compilado não é um executável PE válido."
}

$sourceText = Get-Content -LiteralPath $sourcePath -Raw
foreach ($forbidden in @('Process.Start(', 'powershell.exe', 'pwsh.exe', 'WScript.Shell')) {
    if ($sourceText.IndexOf($forbidden, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
        throw "O host nativo contém chamada proibida a processo externo: $forbidden"
    }
}

$info = [Diagnostics.FileVersionInfo]::GetVersionInfo($outExe)
if ($info.FileVersion -ne $fileVersion) {
    throw "Versão do EXE divergente: $($info.FileVersion) != $fileVersion"
}

Write-Host "HOST NATIVO: OK — Central de Trabalho.exe v$fileVersion, $($bytes.Length) bytes, PowerShell hospedado no próprio processo."
