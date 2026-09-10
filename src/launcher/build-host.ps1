param(
    [Parameter(Mandatory = $true)]
    [string]$Version,

    [Parameter(Mandatory = $true)]
    [string]$OutputDirectory
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$sourcePath = Join-Path $PSScriptRoot "CentralHost.cs"
if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
    throw "Native host source not found: $sourcePath"
}

$srcRoot = Split-Path -Parent $PSScriptRoot
$iconAssetPath = Join-Path $srcRoot "assets\Central-de-Trabalho.png.b64"
if (-not (Test-Path -LiteralPath $iconAssetPath -PathType Leaf)) {
    throw "Central icon asset not found: $iconAssetPath"
}

[void](New-Item -ItemType Directory -Force -Path $OutputDirectory)
$outExe = Join-Path $OutputDirectory "Central de Trabalho.exe"
$iconPath = Join-Path $OutputDirectory "Central-de-Trabalho.ico"
$versionSource = Join-Path $OutputDirectory "AssemblyInfo.generated.cs"

$encodedIcon = (Get-Content -LiteralPath $iconAssetPath -Raw).Trim()
try { $imageBytes = [Convert]::FromBase64String($encodedIcon) }
catch { throw "Central icon image asset is not valid Base64." }
if ($imageBytes.Length -lt 1024) { throw "Central icon image asset is unexpectedly small." }
$imageSha = [BitConverter]::ToString(([Security.Cryptography.SHA256]::Create()).ComputeHash($imageBytes)).Replace('-', '')
if ($imageSha -ne 'A4F954FAD5A3226B726214010B9C8B1C14D254ADE638A53FF23D6EEF6546E715') {
    throw "Central icon image asset failed SHA-256 validation."
}

Add-Type -AssemblyName System.Drawing
$memory = [IO.MemoryStream]::new(,$imageBytes)
$bitmap = $null
$icon = $null
$fileStream = $null
try {
    $bitmap = [Drawing.Bitmap]::FromStream($memory)
    if ($bitmap.Width -ne 64 -or $bitmap.Height -ne 64) {
        throw "Central icon image must be 64x64 pixels."
    }
    $icon = [Drawing.Icon]::FromHandle($bitmap.GetHicon())
    $fileStream = [IO.File]::Create($iconPath)
    $icon.Save($fileStream)
}
finally {
    if ($null -ne $fileStream) { $fileStream.Dispose() }
    if ($null -ne $icon) { $icon.Dispose() }
    if ($null -ne $bitmap) { $bitmap.Dispose() }
    $memory.Dispose()
}
if (-not (Test-Path -LiteralPath $iconPath -PathType Leaf) -or (Get-Item -LiteralPath $iconPath).Length -lt 512) {
    throw "Central ICO was not generated correctly from the CT image."
}

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
$forbiddenPatterns = @(
    '(?i)\bProcess\.Start\s*\(',
    '(?i)(?<![A-Za-z0-9_.-])powershell\.exe(?![A-Za-z0-9_.-])',
    '(?i)(?<![A-Za-z0-9_.-])pwsh\.exe(?![A-Za-z0-9_.-])',
    '(?i)WScript\.Shell'
)
foreach ($pattern in $forbiddenPatterns) {
    if ([regex]::IsMatch($sourceText, $pattern)) {
        throw "Native host contains a forbidden external process launcher pattern: $pattern"
    }
}

$info = [Diagnostics.FileVersionInfo]::GetVersionInfo($outExe)
if ($info.FileVersion -ne $fileVersion) {
    throw "EXE version mismatch: $($info.FileVersion) != $fileVersion"
}

Write-Host "NATIVE HOST: OK - Central de Trabalho.exe v$fileVersion, $($bytes.Length) bytes, Windows GUI subsystem, custom CT icon, in-process PowerShell engine."
