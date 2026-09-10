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
    throw "Reference executable not found: $ReferenceExe"
}

$sourcePath = Join-Path $PSScriptRoot "CentralHost.cs"
if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
    throw "Native host source not found: $sourcePath"
}

[void](New-Item -ItemType Directory -Force -Path $OutputDirectory)
$outExe = Join-Path $OutputDirectory "Central de Trabalho.exe"
$iconPath = Join-Path $OutputDirectory "Central-de-Trabalho.ico"
$versionSource = Join-Path $OutputDirectory "AssemblyInfo.generated.cs"

Add-Type -AssemblyName System.Drawing
$icon = [System.Drawing.Icon]::ExtractAssociatedIcon((Resolve-Path -LiteralPath $ReferenceExe).Path)
if ($null -eq $icon) { throw "Could not extract icon from reference executable." }
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
[assembly: AssemblyDescription("Native graphical host for Central de Trabalho")]
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
    '/reference:System.Drawing.dll',
    '/reference:System.Windows.Forms.dll',
    $sourcePath,
    $versionSource
)

& $csc @arguments
if ($LASTEXITCODE -ne 0) { throw "Native host compilation failed with code $LASTEXITCODE." }
if (-not (Test-Path -LiteralPath $outExe -PathType Leaf)) { throw "Compiler did not generate Central de Trabalho.exe." }

$bytes = [IO.File]::ReadAllBytes($outExe)
if ($bytes.Length -lt 1024 -or $bytes[0] -ne 0x4D -or $bytes[1] -ne 0x5A) {
    throw "Compiled host is not a valid PE executable."
}
$peOffset = [BitConverter]::ToInt32($bytes, 0x3C)
if ($peOffset -lt 0 -or ($peOffset + 96) -ge $bytes.Length) { throw "Invalid PE header in native host." }
if ($bytes[$peOffset] -ne 0x50 -or $bytes[$peOffset + 1] -ne 0x45 -or $bytes[$peOffset + 2] -ne 0 -or $bytes[$peOffset + 3] -ne 0) {
    throw "Invalid PE signature in native host."
}
$optionalHeader = $peOffset + 24
$subsystem = [BitConverter]::ToUInt16($bytes, $optionalHeader + 68)
if ($subsystem -ne 2) { throw "Wrong executable subsystem ($subsystem). Expected Windows GUI (2)." }

$sourceText = Get-Content -LiteralPath $sourcePath -Raw
foreach ($forbidden in @('Process.Start(', 'powershell.exe', 'pwsh.exe', 'WScript.Shell')) {
    if ($sourceText.IndexOf($forbidden, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
        throw "Native host contains forbidden external process call: $forbidden"
    }
}

$info = [Diagnostics.FileVersionInfo]::GetVersionInfo($outExe)
if ($info.FileVersion -ne $fileVersion) {
    throw "EXE version mismatch: $($info.FileVersion) != $fileVersion"
}

Write-Host "NATIVE HOST: OK - Central de Trabalho.exe v$fileVersion, $($bytes.Length) bytes, Windows GUI subsystem, in-process PowerShell engine."
