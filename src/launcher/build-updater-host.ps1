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
    throw "Reference updater executable not found: $ReferenceExe"
}

$sourcePath = Join-Path $PSScriptRoot "UpdaterHost.cs"
if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
    throw "Native updater host source not found: $sourcePath"
}

[void](New-Item -ItemType Directory -Force -Path $OutputDirectory)
$outExe = Join-Path $OutputDirectory "Central de Trabalho Updater.exe"
$iconPath = Join-Path $OutputDirectory "Central-de-Trabalho-Updater.ico"
$versionSource = Join-Path $OutputDirectory "UpdaterAssemblyInfo.generated.cs"

Add-Type -AssemblyName System.Drawing
$icon = [System.Drawing.Icon]::ExtractAssociatedIcon((Resolve-Path -LiteralPath $ReferenceExe).Path)
if ($null -eq $icon) { throw "Could not extract icon from reference updater executable." }
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
[assembly: AssemblyTitle("Central de Trabalho - Atualizador")]
[assembly: AssemblyProduct("Central de Trabalho CB5")]
[assembly: AssemblyCompany("Central de Trabalho CB5")]
[assembly: AssemblyDescription("Native graphical updater host for Central de Trabalho")]
[assembly: AssemblyVersion("$fileVersion")]
[assembly: AssemblyFileVersion("$fileVersion")]
"@ | Set-Content -LiteralPath $versionSource -Encoding UTF8

$cscCandidates = @(
    (Join-Path $env:WINDIR "Microsoft.NET\Framework64\v4.0.30319\csc.exe"),
    (Join-Path $env:WINDIR "Microsoft.NET\Framework\v4.0.30319\csc.exe")
)
$csc = $cscCandidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
if ([string]::IsNullOrWhiteSpace($csc)) { throw "C# compiler from .NET Framework not found." }

$sma = [System.Management.Automation.PowerShell].Assembly.Location
if ([string]::IsNullOrWhiteSpace($sma) -or -not (Test-Path -LiteralPath $sma -PathType Leaf)) {
    throw "System.Management.Automation.dll from Windows PowerShell not found."
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
    '/reference:System.Windows.Forms.dll',
    $sourcePath,
    $versionSource
)

& $csc @arguments
if ($LASTEXITCODE -ne 0) { throw "Native updater host compilation failed with code $LASTEXITCODE." }
if (-not (Test-Path -LiteralPath $outExe -PathType Leaf)) { throw "Compiler did not generate Central de Trabalho Updater.exe." }

$bytes = [IO.File]::ReadAllBytes($outExe)
if ($bytes.Length -lt 1024 -or $bytes[0] -ne 0x4D -or $bytes[1] -ne 0x5A) {
    throw "Compiled updater host is not a valid PE executable."
}
$peOffset = [BitConverter]::ToInt32($bytes, 0x3C)
if ($peOffset -lt 0 -or ($peOffset + 96) -ge $bytes.Length) { throw "Invalid PE header in native updater host." }
if ($bytes[$peOffset] -ne 0x50 -or $bytes[$peOffset + 1] -ne 0x45 -or $bytes[$peOffset + 2] -ne 0 -or $bytes[$peOffset + 3] -ne 0) {
    throw "Invalid PE signature in native updater host."
}
$optionalHeader = $peOffset + 24
$subsystem = [BitConverter]::ToUInt16($bytes, $optionalHeader + 68)
if ($subsystem -ne 2) { throw "Wrong updater executable subsystem ($subsystem). Expected Windows GUI (2)." }

$sourceText = Get-Content -LiteralPath $sourcePath -Raw
$forbiddenPatterns = @(
    '(?i)(?<![A-Za-z0-9_.-])powershell\.exe(?![A-Za-z0-9_.-])',
    '(?i)(?<![A-Za-z0-9_.-])pwsh\.exe(?![A-Za-z0-9_.-])',
    '(?i)(?<![A-Za-z0-9_.-])cmd\.exe(?![A-Za-z0-9_.-])',
    '(?i)(?<![A-Za-z0-9_.-])cscript\.exe(?![A-Za-z0-9_.-])',
    '(?i)(?<![A-Za-z0-9_.-])wscript\.exe(?![A-Za-z0-9_.-])',
    '(?i)WScript\.Shell'
)
foreach ($pattern in $forbiddenPatterns) {
    if ([regex]::IsMatch($sourceText, $pattern)) {
        throw "Native updater host contains a forbidden legacy launcher pattern: $pattern"
    }
}

foreach ($required in @(
    'RunspaceFactory.CreateRunspace',
    'UpdaterRuntime',
    'CentralDeTrabalho_Atualizador',
    'Central de Trabalho Updater.ps1'
)) {
    if ($sourceText -notmatch [regex]::Escape($required)) {
        throw "Native updater host is missing required contract: $required"
    }
}

$info = [Diagnostics.FileVersionInfo]::GetVersionInfo($outExe)
if ($info.FileVersion -ne $fileVersion) {
    throw "Updater EXE version mismatch: $($info.FileVersion) != $fileVersion"
}

Write-Host "NATIVE UPDATER HOST: OK - Central de Trabalho Updater.exe v$fileVersion, $($bytes.Length) bytes, Windows GUI subsystem, temporary self-hosted runtime, in-process PowerShell engine."
