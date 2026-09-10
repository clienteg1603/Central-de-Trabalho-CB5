#!/usr/bin/env python3
from pathlib import Path

path = Path('src/generated/Central de Trabalho.ps1')
text = path.read_text(encoding='utf-8-sig')

old_version = '$script:AppVersion = "0.17.1"'
new_version = '$script:AppVersion = "0.18.0"'
if old_version not in text:
    raise SystemExit('Versão-base 0.17.1 não encontrada no script da Central.')
text = text.replace(old_version, new_version, 1)

old_updater_paths = '''$script:UpdaterDirectory = [IO.Path]::Combine($script:RootPath, "Atualizador")
$script:UpdaterScript = [IO.Path]::Combine($script:UpdaterDirectory, "Central de Trabalho Updater.ps1")
$script:UpdaterCore = [IO.Path]::Combine($script:UpdaterDirectory, "Update.Core.ps1")
$script:UpdaterChannels = [IO.Path]::Combine($script:UpdaterDirectory, "CANAIS.json")'''
new_updater_paths = '''$script:UpdaterDirectory = [IO.Path]::Combine($script:RootPath, "Atualizador")
$script:UpdaterExecutable = [IO.Path]::Combine($script:UpdaterDirectory, "Central de Trabalho Updater.exe")
$script:UpdaterScript = [IO.Path]::Combine($script:UpdaterDirectory, "Central de Trabalho Updater.ps1")
$script:UpdaterCore = [IO.Path]::Combine($script:UpdaterDirectory, "Update.Core.ps1")
$script:UpdaterChannels = [IO.Path]::Combine($script:UpdaterDirectory, "CANAIS.json")'''
if old_updater_paths not in text:
    raise SystemExit('Bloco de caminhos do Atualizador não encontrado.')
text = text.replace(old_updater_paths, new_updater_paths, 1)

old_required = '$updaterRequired = @($script:UpdaterScript, $script:UpdaterCore, $script:UpdaterChannels)'
new_required = '$updaterRequired = @($script:UpdaterExecutable, $script:UpdaterScript, $script:UpdaterCore, $script:UpdaterChannels)'
if old_required not in text:
    raise SystemExit('Contrato de arquivos obrigatórios do Atualizador não encontrado.')
text = text.replace(old_required, new_required, 1)

old_launch = '''    try {
        $powershellPath = [IO.Path]::Combine(
            [Environment]::GetFolderPath([Environment+SpecialFolder]::Windows),
            "System32",
            "WindowsPowerShell",
            "v1.0",
            "powershell.exe"
        )
        if (-not [IO.File]::Exists($powershellPath)) { $powershellPath = "powershell.exe" }

        $startInfo = New-Object Diagnostics.ProcessStartInfo
        $startInfo.FileName = $powershellPath
        $startInfo.WorkingDirectory = $script:UpdaterDirectory
        $startInfo.Arguments = '-NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File \\"' + $script:UpdaterScript + '\\" -InstallRoot \\"' + $script:RootPath + '\\" -CurrentVersion \\"' + $script:AppVersion + '\\" -ParentProcessId ' + $PID
        $startInfo.UseShellExecute = $true
        $script:UpdaterProcess = [Diagnostics.Process]::Start($startInfo)
        Set-StatusMessage "Tela de atualizações aberta em uma nova janela." "Success"
    }
'''

# O arquivo PowerShell usa aspas normais na string. A variante abaixo cobre exatamente
# o texto gerado após leitura Python, sem depender do escape visual do GitHub.
old_launch_plain = '''    try {
        $powershellPath = [IO.Path]::Combine(
            [Environment]::GetFolderPath([Environment+SpecialFolder]::Windows),
            "System32",
            "WindowsPowerShell",
            "v1.0",
            "powershell.exe"
        )
        if (-not [IO.File]::Exists($powershellPath)) { $powershellPath = "powershell.exe" }

        $startInfo = New-Object Diagnostics.ProcessStartInfo
        $startInfo.FileName = $powershellPath
        $startInfo.WorkingDirectory = $script:UpdaterDirectory
        $startInfo.Arguments = '-NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File "' + $script:UpdaterScript + '" -InstallRoot "' + $script:RootPath + '" -CurrentVersion "' + $script:AppVersion + '" -ParentProcessId ' + $PID
        $startInfo.UseShellExecute = $true
        $script:UpdaterProcess = [Diagnostics.Process]::Start($startInfo)
        Set-StatusMessage "Tela de atualizações aberta em uma nova janela." "Success"
    }
'''

new_launch = '''    try {
        $startInfo = New-Object Diagnostics.ProcessStartInfo
        $startInfo.FileName = $script:UpdaterExecutable
        $startInfo.WorkingDirectory = $script:UpdaterDirectory
        $startInfo.Arguments = '-InstallRoot "' + $script:RootPath + '" -CurrentVersion "' + $script:AppVersion + '" -ParentProcessId ' + $PID
        $startInfo.UseShellExecute = $true
        $script:UpdaterProcess = [Diagnostics.Process]::Start($startInfo)
        Set-StatusMessage "Tela de atualizações aberta pelo Atualizador nativo." "Success"
    }
'''

if old_launch_plain in text:
    text = text.replace(old_launch_plain, new_launch, 1)
elif old_launch in text:
    text = text.replace(old_launch, new_launch, 1)
else:
    raise SystemExit('Bloco antigo de inicialização externa do Atualizador não encontrado.')

if 'powershell.exe' in text.lower():
    raise SystemExit('A Central ainda contém referência direta a powershell.exe após a transformação.')
if '$script:UpdaterExecutable' not in text:
    raise SystemExit('Contrato do executável nativo do Atualizador não foi aplicado.')

path.write_text(text, encoding='utf-8-sig')
print('0.18.0: Central preparada para abrir o Atualizador nativo sem powershell.exe externo.')
