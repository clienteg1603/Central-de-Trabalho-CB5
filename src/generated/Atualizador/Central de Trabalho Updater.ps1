param(
    [string]$InstallRoot = "",
    [string]$CurrentVersion = "",
    [int]$ParentProcessId = 0
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[Windows.Forms.Application]::EnableVisualStyles()
[Windows.Forms.Application]::SetCompatibleTextRenderingDefault($false)

$corePath = [IO.Path]::Combine($PSScriptRoot, "Update.Core.ps1")
if (-not [IO.File]::Exists($corePath)) {
    [Windows.Forms.MessageBox]::Show(
        "O núcleo do Atualizador não foi encontrado.",
        "Central de Trabalho — Atualizações",
        [Windows.Forms.MessageBoxButtons]::OK,
        [Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
    exit 1
}
. $corePath

if ([string]::IsNullOrWhiteSpace($InstallRoot)) {
    $InstallRoot = [IO.Directory]::GetParent($PSScriptRoot).FullName
}
$InstallRoot = [IO.Path]::GetFullPath($InstallRoot)
if ([string]::IsNullOrWhiteSpace($CurrentVersion)) {
    try {
        $CurrentVersion = ConvertTo-UpdateText (Read-LocalPackageManifest -PackageRoot $InstallRoot).Version
    }
    catch { $CurrentVersion = "0.8.5" }
}

$createdNew = $false
$script:UpdaterMutex = New-Object Threading.Mutex($true, "Local\CentralDeTrabalho.Atualizador", [ref]$createdNew)
if (-not $createdNew) {
    [Windows.Forms.MessageBox]::Show(
        "O Atualizador já está aberto.",
        "Central de Trabalho — Atualizações",
        [Windows.Forms.MessageBoxButtons]::OK,
        [Windows.Forms.MessageBoxIcon]::Information
    ) | Out-Null
    $script:UpdaterMutex.Dispose()
    exit 0
}

$script:AvailableManifest = $null
$script:RestartCentral = $false
$script:UserSettings = Get-UpdateUserSettings

function Get-SelectedUpdateChannel {
    if ($channelCombo.SelectedIndex -eq 1) { return "test" }
    return "stable"
}

function Get-SelectedChannelName {
    if ((Get-SelectedUpdateChannel) -eq "test") { return "Teste" }
    return "Estável"
}

function Set-UpdaterStatus {
    param(
        [string]$Message,
        [ValidateSet("Normal", "Success", "Warning", "Error")][string]$Kind = "Normal"
    )

    $statusLabel.Text = $Message
    switch ($Kind) {
        "Success" {
            $statusPanel.BackColor = [Drawing.Color]::FromArgb(220, 252, 231)
            $statusLabel.ForeColor = [Drawing.Color]::FromArgb(21, 128, 61)
        }
        "Warning" {
            $statusPanel.BackColor = [Drawing.Color]::FromArgb(255, 247, 237)
            $statusLabel.ForeColor = [Drawing.Color]::FromArgb(194, 65, 12)
        }
        "Error" {
            $statusPanel.BackColor = [Drawing.Color]::FromArgb(254, 226, 226)
            $statusLabel.ForeColor = [Drawing.Color]::FromArgb(185, 28, 28)
        }
        default {
            $statusPanel.BackColor = [Drawing.Color]::FromArgb(239, 246, 255)
            $statusLabel.ForeColor = [Drawing.Color]::FromArgb(29, 78, 216)
        }
    }
    [Windows.Forms.Application]::DoEvents()
}

function Set-UpdaterBusy {
    param([bool]$Busy)

    $form.UseWaitCursor = $Busy
    $checkButton.Enabled = -not $Busy
    $channelCombo.Enabled = -not $Busy
    $configureButton.Enabled = -not $Busy
    $restoreButton.Enabled = -not $Busy -and @(Get-CentralUpdateBackups).Count -gt 0
    $installButton.Enabled = -not $Busy -and $null -ne $script:AvailableManifest
    [Windows.Forms.Application]::DoEvents()
}

function Refresh-UpdateEndpointState {
    $channel = Get-SelectedUpdateChannel
    $url = Get-ConfiguredUpdateUrl -InstallRoot $InstallRoot -Channel $channel -UserSettings $script:UserSettings
    $channelName = Get-SelectedChannelName
    if ([string]::IsNullOrWhiteSpace($url)) {
        $endpointLabel.Text = "Canal $channelName ainda não publicado. O endereço pode ser configurado quando o local das versões estiver definido."
        $endpointLabel.ForeColor = [Drawing.Color]::FromArgb(180, 83, 9)
        Set-UpdaterStatus "A atualização pela internet está preparada, mas este canal ainda não possui endereço." "Warning"
    }
    elseif (-not (Test-SecureUpdateUri $url)) {
        $endpointLabel.Text = "O endereço salvo para o canal $channelName não usa HTTPS."
        $endpointLabel.ForeColor = [Drawing.Color]::FromArgb(185, 28, 28)
        Set-UpdaterStatus "Corrija o endereço do canal antes de procurar atualizações." "Error"
    }
    else {
        $endpointLabel.Text = "Canal $channelName configurado com conexão segura HTTPS."
        $endpointLabel.ForeColor = [Drawing.Color]::FromArgb(21, 128, 61)
        Set-UpdaterStatus "Pronto para procurar uma nova versão no canal $channelName." "Normal"
    }
    $script:AvailableManifest = $null
    $availableVersionValue.Text = "—"
    $installButton.Enabled = $false
    $releaseNotesBox.Text = "Nenhuma atualização consultada nesta sessão."
}

function Show-UpdateUrlDialog {
    param(
        [string]$ChannelName,
        [string]$CurrentUrl
    )

    $dialog = New-Object Windows.Forms.Form
    $dialog.Text = "Configurar canal $ChannelName"
    $dialog.StartPosition = [Windows.Forms.FormStartPosition]::CenterParent
    $dialog.FormBorderStyle = [Windows.Forms.FormBorderStyle]::FixedDialog
    $dialog.MaximizeBox = $false
    $dialog.MinimizeBox = $false
    $dialog.ClientSize = [Drawing.Size]::new(610, 205)
    $dialog.Font = [Drawing.Font]::new("Segoe UI", 9.5)

    $label = New-Object Windows.Forms.Label
    $label.Text = "Cole o endereço HTTPS do manifesto deste canal. Deixe vazio para desativá-lo."
    $label.Location = [Drawing.Point]::new(20, 18)
    $label.Size = [Drawing.Size]::new(570, 42)
    $dialog.Controls.Add($label)

    $textBox = New-Object Windows.Forms.TextBox
    $textBox.Text = $CurrentUrl
    $textBox.Location = [Drawing.Point]::new(20, 68)
    $textBox.Size = [Drawing.Size]::new(570, 28)
    $dialog.Controls.Add($textBox)

    $help = New-Object Windows.Forms.Label
    $help.Text = "O programa só aceita HTTPS e sempre confere tamanho e SHA-256 antes de instalar."
    $help.Location = [Drawing.Point]::new(20, 105)
    $help.Size = [Drawing.Size]::new(570, 28)
    $help.ForeColor = [Drawing.Color]::FromArgb(71, 85, 105)
    $dialog.Controls.Add($help)

    $cancel = New-Object Windows.Forms.Button
    $cancel.Text = "CANCELAR"
    $cancel.Location = [Drawing.Point]::new(366, 151)
    $cancel.Size = [Drawing.Size]::new(105, 34)
    $cancel.DialogResult = [Windows.Forms.DialogResult]::Cancel
    $dialog.Controls.Add($cancel)

    $save = New-Object Windows.Forms.Button
    $save.Text = "SALVAR"
    $save.Location = [Drawing.Point]::new(481, 151)
    $save.Size = [Drawing.Size]::new(109, 34)
    $save.BackColor = [Drawing.Color]::FromArgb(37, 99, 235)
    $save.ForeColor = [Drawing.Color]::White
    $save.FlatStyle = [Windows.Forms.FlatStyle]::Flat
    $save.FlatAppearance.BorderSize = 0
    $save.Add_Click({
        $value = $textBox.Text.Trim()
        if (-not [string]::IsNullOrWhiteSpace($value) -and -not (Test-SecureUpdateUri $value)) {
            [Windows.Forms.MessageBox]::Show(
                "Informe um endereço completo iniciado por https:// ou deixe o campo vazio.",
                "Endereço inválido",
                [Windows.Forms.MessageBoxButtons]::OK,
                [Windows.Forms.MessageBoxIcon]::Warning
            ) | Out-Null
            return
        }
        $dialog.Tag = $value
        $dialog.DialogResult = [Windows.Forms.DialogResult]::OK
        $dialog.Close()
    })
    $dialog.Controls.Add($save)
    $dialog.AcceptButton = $save
    $dialog.CancelButton = $cancel

    try {
        $result = $dialog.ShowDialog($form)
        if ($result -eq [Windows.Forms.DialogResult]::OK) { return [string]$dialog.Tag }
        return $null
    }
    finally { $dialog.Dispose() }
}

function Invoke-UpdateCheck {
    $channel = Get-SelectedUpdateChannel
    $url = Get-ConfiguredUpdateUrl -InstallRoot $InstallRoot -Channel $channel -UserSettings $script:UserSettings
    if ([string]::IsNullOrWhiteSpace($url)) {
        Set-UpdaterStatus "Configure o endereço do canal antes de procurar atualizações." "Warning"
        return
    }

    Set-UpdaterBusy $true
    try {
        Set-UpdaterStatus "Consultando o canal $(Get-SelectedChannelName)..." "Normal"
        $manifest = Get-RemoteUpdateManifest -ManifestUrl $url -Channel $channel
        $script:UserSettings.LastCheck = [DateTime]::Now.ToString("s")
        Save-UpdateUserSettings -Settings $script:UserSettings
        $availableVersionValue.Text = ConvertTo-UpdateText $manifest.Version
        $notes = @()
        if ($manifest.PSObject.Properties.Name -contains "ReleaseNotes") {
            $notes = @($manifest.ReleaseNotes | ForEach-Object { "• " + (ConvertTo-UpdateText $_) })
        }
        if ($notes.Count -eq 0) { $notes = @("Nenhuma observação foi publicada para esta versão.") }
        $releaseNotesBox.Text = $notes -join "`r`n"

        if (Test-NewerUpdateVersion -CurrentVersion $CurrentVersion -AvailableVersion (ConvertTo-UpdateText $manifest.Version)) {
            $script:AvailableManifest = $manifest
            $installButton.Enabled = $true
            Set-UpdaterStatus "A versão $($manifest.Version) está disponível para instalação." "Success"
        }
        else {
            $script:AvailableManifest = $null
            $installButton.Enabled = $false
            Set-UpdaterStatus "A Central v$CurrentVersion já está atualizada neste canal." "Success"
        }
    }
    catch {
        $script:AvailableManifest = $null
        $installButton.Enabled = $false
        Set-UpdaterStatus "Não foi possível consultar: $($_.Exception.Message)" "Error"
    }
    finally { Set-UpdaterBusy $false }
}

function Wait-ForCentralToClose {
    if (-not (Close-UpdateParentProcess -ParentProcessId $ParentProcessId)) { return $false }
    for ($attempt = 0; $attempt -lt 24; $attempt++) {
        if (-not (Test-CentralComponentRunning -Component "Central")) { return $true }
        Start-Sleep -Milliseconds 250
    }
    return -not (Test-CentralComponentRunning -Component "Central")
}

function Test-ModulesClosedForUpdate {
    $running = @()
    if (Test-CentralComponentRunning -Component "Gerenciador") { $running += "Gerenciador de Planilhas" }
    if (Test-CentralComponentRunning -Component "Manutencao") { $running += "Central de Manutenção" }
    if ($running.Count -eq 0) { return $true }

    [Windows.Forms.MessageBox]::Show(
        "Feche antes de continuar:`r`n`r`n• " + ($running -join "`r`n• ") + "`r`n`r`nIsso evita interromper uma planilha ou um registro em andamento.",
        "Módulo em uso",
        [Windows.Forms.MessageBoxButtons]::OK,
        [Windows.Forms.MessageBoxIcon]::Warning
    ) | Out-Null
    return $false
}

function Invoke-UpdateInstallation {
    if ($null -eq $script:AvailableManifest) { return }
    if (-not (Test-ModulesClosedForUpdate)) { return }

    $targetVersion = ConvertTo-UpdateText $script:AvailableManifest.Version
    $confirmation = [Windows.Forms.MessageBox]::Show(
        "Instalar a Central de Trabalho v${targetVersion}?`r`n`r`nAntes da troca será criada uma cópia completa do programa e das bases locais. A Central será fechada somente depois que o pacote for baixado e validado.",
        "Confirmar atualização",
        [Windows.Forms.MessageBoxButtons]::YesNo,
        [Windows.Forms.MessageBoxIcon]::Question
    )
    if ($confirmation -ne [Windows.Forms.DialogResult]::Yes) { return }

    $tempRoot = [IO.Path]::Combine((Get-CentralUpdaterDataDirectory), "Temp", [Guid]::NewGuid().ToString("N"))
    $archivePath = [IO.Path]::Combine($tempRoot, "atualizacao.zip")
    $stagingPath = [IO.Path]::Combine($tempRoot, "extraido")
    $applicationLocks = @()
    Set-UpdaterBusy $true
    try {
        [void][IO.Directory]::CreateDirectory($tempRoot)
        Set-UpdaterStatus "Baixando a versão $targetVersion..." "Normal"
        [void](Receive-UpdatePackage -Manifest $script:AvailableManifest -DestinationPath $archivePath)
        Set-UpdaterStatus "Conferindo e preparando o pacote..." "Normal"
        [void](Expand-UpdatePackageSafely -ArchivePath $archivePath -DestinationDirectory $stagingPath)
        $payloadRoot = Resolve-SafeUpdateChildPath -Root $stagingPath -RelativePath (ConvertTo-UpdateText $script:AvailableManifest.PackageRoot)
        [void](Test-UpdatePackagePayload -PackageRoot $payloadRoot -ExpectedVersion $targetVersion)

        Set-UpdaterStatus "Fechando a Central e criando o backup..." "Warning"
        if (-not (Wait-ForCentralToClose)) { throw "A Central de Trabalho continua aberta." }
        if (-not (Test-ModulesClosedForUpdate)) { throw "Existe um módulo aberto." }
        $applicationLocks = @(Enter-CentralUpdateApplicationLocks)

        Set-UpdaterStatus "Instalando a versão $targetVersion..." "Warning"
        [void](Install-CentralUpdatePayload -PayloadRoot $payloadRoot -InstallRoot $InstallRoot -CurrentVersion $CurrentVersion -TargetVersion $targetVersion)
        Set-UpdaterStatus "Atualização concluída. A Central será aberta novamente." "Success"
        [Windows.Forms.MessageBox]::Show(
            "A Central de Trabalho foi atualizada para a versão $targetVersion.`r`n`r`nO backup anterior foi mantido para restauração.",
            "Atualização concluída",
            [Windows.Forms.MessageBoxButtons]::OK,
            [Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
        $script:RestartCentral = $true
        $form.Close()
    }
    catch {
        Set-UpdaterStatus "A atualização não foi instalada: $($_.Exception.Message)" "Error"
        [Windows.Forms.MessageBox]::Show(
            "A atualização não pôde ser concluída.`r`n`r`n$($_.Exception.Message)`r`n`r`nO Atualizador tentou restaurar o backup automaticamente. Se a própria mensagem indicar falha na restauração, use o backup anterior antes de tentar novamente.",
            "Falha na atualização",
            [Windows.Forms.MessageBoxButtons]::OK,
            [Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
        if (-not (Test-CentralComponentRunning -Component "Central")) { $script:RestartCentral = $true }
    }
    finally {
        Exit-CentralUpdateApplicationLocks -Locks $applicationLocks
        Set-UpdaterBusy $false
        try { if ([IO.Directory]::Exists($tempRoot)) { [IO.Directory]::Delete($tempRoot, $true) } }
        catch {}
    }
}

function Invoke-LatestBackupRestore {
    $backups = @(Get-CentralUpdateBackups)
    if ($backups.Count -eq 0) {
        Set-UpdaterStatus "Nenhum backup de atualização foi encontrado." "Warning"
        return
    }
    if (-not (Test-ModulesClosedForUpdate)) { return }

    $backup = $backups[0]
    $restoreData = $restoreDataCheck.Checked
    $dataWarning = if ($restoreData) {
        "`r`n`r`nATENÇÃO: os dados locais também voltarão ao momento do backup. Registros criados depois dele poderão ser perdidos."
    }
    else {
        "`r`n`r`nOs históricos e saldos atuais serão preservados."
    }
    $confirmation = [Windows.Forms.MessageBox]::Show(
        "Restaurar o programa para a versão $($backup.CurrentVersion)?$dataWarning",
        "Restaurar versão anterior",
        [Windows.Forms.MessageBoxButtons]::YesNo,
        [Windows.Forms.MessageBoxIcon]::Warning
    )
    if ($confirmation -ne [Windows.Forms.DialogResult]::Yes) { return }

    $applicationLocks = @()
    Set-UpdaterBusy $true
    try {
        Set-UpdaterStatus "Fechando a Central e restaurando o backup..." "Warning"
        if (-not (Wait-ForCentralToClose)) { throw "A Central de Trabalho continua aberta." }
        if (-not (Test-ModulesClosedForUpdate)) { throw "Existe um módulo aberto." }
        $applicationLocks = @(Enter-CentralUpdateApplicationLocks)
        [void](Restore-CentralUpdateBackup -Backup $backup -InstallRoot $InstallRoot -RestoreData:$restoreData)
        Set-UpdaterStatus "Versão anterior restaurada." "Success"
        [Windows.Forms.MessageBox]::Show(
            "A versão $($backup.CurrentVersion) foi restaurada com sucesso.",
            "Restauração concluída",
            [Windows.Forms.MessageBoxButtons]::OK,
            [Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
        $script:RestartCentral = $true
        $form.Close()
    }
    catch {
        Set-UpdaterStatus "Não foi possível restaurar: $($_.Exception.Message)" "Error"
    }
    finally {
        Exit-CentralUpdateApplicationLocks -Locks $applicationLocks
        Set-UpdaterBusy $false
    }
}

$form = New-Object Windows.Forms.Form
$form.Text = "Central de Trabalho — Atualizações"
$form.StartPosition = [Windows.Forms.FormStartPosition]::CenterScreen
$form.AutoScaleMode = [Windows.Forms.AutoScaleMode]::Dpi
$form.Font = [Drawing.Font]::new("Segoe UI", 9.5)
$form.MinimumSize = [Drawing.Size]::new(720, 560)
$form.Size = [Drawing.Size]::new(820, 720)
$form.BackColor = [Drawing.Color]::FromArgb(241, 245, 249)
$form.MaximizeBox = $true

# Estrutura resiliente a DPI/resoluções menores:
# cabeçalho fixo + conteúdo central rolável + status/botões sempre visíveis.
$root = New-Object Windows.Forms.TableLayoutPanel
$root.Dock = [Windows.Forms.DockStyle]::Fill
$root.Padding = [Windows.Forms.Padding]::new(22)
$root.ColumnCount = 1
$root.RowCount = 3
[void]$root.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 76)))
[void]$root.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 100)))
[void]$root.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 94)))
$form.Controls.Add($root)

$header = New-Object Windows.Forms.TableLayoutPanel
$header.Dock = [Windows.Forms.DockStyle]::Fill
$header.Margin = [Windows.Forms.Padding]::new(0)
$header.ColumnCount = 1
$header.RowCount = 2
[void]$header.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 62)))
[void]$header.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 38)))
$root.Controls.Add($header, 0, 0)

$title = New-Object Windows.Forms.Label
$title.Text = "Atualizações da Central"
$title.Font = [Drawing.Font]::new("Segoe UI Semibold", 21)
$title.Dock = [Windows.Forms.DockStyle]::Fill
$title.TextAlign = [Drawing.ContentAlignment]::BottomLeft
$title.AutoEllipsis = $true
$header.Controls.Add($title, 0, 0)

$subtitle = New-Object Windows.Forms.Label
$subtitle.Text = "Instalação protegida com conferência do pacote, backup e restauração."
$subtitle.ForeColor = [Drawing.Color]::FromArgb(71, 85, 105)
$subtitle.Dock = [Windows.Forms.DockStyle]::Fill
$subtitle.AutoEllipsis = $true
$header.Controls.Add($subtitle, 0, 1)

$bodyHost = New-Object Windows.Forms.Panel
$bodyHost.Dock = [Windows.Forms.DockStyle]::Fill
$bodyHost.Margin = [Windows.Forms.Padding]::new(0, 4, 0, 8)
$bodyHost.AutoScroll = $true
$root.Controls.Add($bodyHost, 0, 1)

$body = New-Object Windows.Forms.TableLayoutPanel
$body.Dock = [Windows.Forms.DockStyle]::Top
$body.AutoSize = $true
$body.AutoSizeMode = [Windows.Forms.AutoSizeMode]::GrowAndShrink
$body.Margin = [Windows.Forms.Padding]::new(0)
$body.ColumnCount = 1
$body.RowCount = 5
[void]$body.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 78)))
[void]$body.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 72)))
[void]$body.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 74)))
[void]$body.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 205)))
[void]$body.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 50)))
$bodyHost.Controls.Add($body)

$versionPanel = New-Object Windows.Forms.TableLayoutPanel
$versionPanel.Dock = [Windows.Forms.DockStyle]::Fill
$versionPanel.Margin = [Windows.Forms.Padding]::new(0, 0, 0, 8)
$versionPanel.BackColor = [Drawing.Color]::White
$versionPanel.Padding = [Windows.Forms.Padding]::new(14, 8, 14, 8)
$versionPanel.ColumnCount = 2
$versionPanel.RowCount = 2
[void]$versionPanel.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 50)))
[void]$versionPanel.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 50)))
[void]$versionPanel.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 24)))
[void]$versionPanel.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 100)))
$body.Controls.Add($versionPanel, 0, 0)

$currentVersionLabel = New-Object Windows.Forms.Label
$currentVersionLabel.Text = "Versão instalada"
$currentVersionLabel.Dock = [Windows.Forms.DockStyle]::Fill
$currentVersionLabel.TextAlign = [Drawing.ContentAlignment]::BottomLeft
$currentVersionLabel.ForeColor = [Drawing.Color]::FromArgb(71, 85, 105)
$versionPanel.Controls.Add($currentVersionLabel, 0, 0)
$currentVersionValue = New-Object Windows.Forms.Label
$currentVersionValue.Text = $CurrentVersion
$currentVersionValue.Font = [Drawing.Font]::new("Segoe UI Semibold", 13)
$currentVersionValue.Dock = [Windows.Forms.DockStyle]::Fill
$currentVersionValue.TextAlign = [Drawing.ContentAlignment]::TopLeft
$versionPanel.Controls.Add($currentVersionValue, 0, 1)

$availableVersionLabel = New-Object Windows.Forms.Label
$availableVersionLabel.Text = "Versão disponível"
$availableVersionLabel.Dock = [Windows.Forms.DockStyle]::Fill
$availableVersionLabel.TextAlign = [Drawing.ContentAlignment]::BottomLeft
$availableVersionLabel.ForeColor = [Drawing.Color]::FromArgb(71, 85, 105)
$versionPanel.Controls.Add($availableVersionLabel, 1, 0)
$availableVersionValue = New-Object Windows.Forms.Label
$availableVersionValue.Text = "—"
$availableVersionValue.Font = [Drawing.Font]::new("Segoe UI Semibold", 13)
$availableVersionValue.Dock = [Windows.Forms.DockStyle]::Fill
$availableVersionValue.TextAlign = [Drawing.ContentAlignment]::TopLeft
$versionPanel.Controls.Add($availableVersionValue, 1, 1)

$channelPanel = New-Object Windows.Forms.TableLayoutPanel
$channelPanel.Dock = [Windows.Forms.DockStyle]::Fill
$channelPanel.Margin = [Windows.Forms.Padding]::new(0, 0, 0, 8)
$channelPanel.Padding = [Windows.Forms.Padding]::new(0, 10, 0, 8)
$channelPanel.ColumnCount = 3
[void]$channelPanel.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Absolute, 72)))
[void]$channelPanel.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Absolute, 180)))
[void]$channelPanel.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 100)))
$body.Controls.Add($channelPanel, 0, 1)

$channelLabel = New-Object Windows.Forms.Label
$channelLabel.Text = "Canal"
$channelLabel.Dock = [Windows.Forms.DockStyle]::Fill
$channelLabel.TextAlign = [Drawing.ContentAlignment]::MiddleLeft
$channelPanel.Controls.Add($channelLabel, 0, 0)
$channelCombo = New-Object Windows.Forms.ComboBox
$channelCombo.Dock = [Windows.Forms.DockStyle]::Fill
$channelCombo.Margin = [Windows.Forms.Padding]::new(0, 7, 12, 7)
$channelCombo.DropDownStyle = [Windows.Forms.ComboBoxStyle]::DropDownList
[void]$channelCombo.Items.AddRange(@("Estável", "Teste"))
$channelCombo.SelectedIndex = if ($script:UserSettings.Channel -eq "test") { 1 } else { 0 }
$channelPanel.Controls.Add($channelCombo, 1, 0)
$configureButton = New-Object Windows.Forms.Button
$configureButton.Text = "CONFIGURAR ENDEREÇO"
$configureButton.Dock = [Windows.Forms.DockStyle]::Right
$configureButton.Width = 185
$configureButton.Margin = [Windows.Forms.Padding]::new(8, 7, 0, 7)
$channelPanel.Controls.Add($configureButton, 2, 0)

$endpointLabel = New-Object Windows.Forms.Label
$endpointLabel.Dock = [Windows.Forms.DockStyle]::Fill
$endpointLabel.Margin = [Windows.Forms.Padding]::new(0, 0, 0, 8)
$endpointLabel.Padding = [Windows.Forms.Padding]::new(12, 8, 12, 8)
$endpointLabel.BackColor = [Drawing.Color]::White
$endpointLabel.TextAlign = [Drawing.ContentAlignment]::MiddleLeft
$endpointLabel.AutoEllipsis = $false
$body.Controls.Add($endpointLabel, 0, 2)

$notesGroup = New-Object Windows.Forms.GroupBox
$notesGroup.Text = "Novidades da versão encontrada"
$notesGroup.Dock = [Windows.Forms.DockStyle]::Fill
$notesGroup.Margin = [Windows.Forms.Padding]::new(0, 0, 0, 8)
$notesGroup.Padding = [Windows.Forms.Padding]::new(12, 22, 12, 12)
$body.Controls.Add($notesGroup, 0, 3)
$releaseNotesBox = New-Object Windows.Forms.TextBox
$releaseNotesBox.Dock = [Windows.Forms.DockStyle]::Fill
$releaseNotesBox.Multiline = $true
$releaseNotesBox.ReadOnly = $true
$releaseNotesBox.ScrollBars = [Windows.Forms.ScrollBars]::Vertical
$releaseNotesBox.BackColor = [Drawing.Color]::White
$releaseNotesBox.Text = "Nenhuma atualização consultada nesta sessão."
$notesGroup.Controls.Add($releaseNotesBox)

$restorePanel = New-Object Windows.Forms.TableLayoutPanel
$restorePanel.Dock = [Windows.Forms.DockStyle]::Fill
$restorePanel.Margin = [Windows.Forms.Padding]::new(0)
$restorePanel.ColumnCount = 2
[void]$restorePanel.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 100)))
[void]$restorePanel.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::AutoSize)))
$body.Controls.Add($restorePanel, 0, 4)
$restoreDataCheck = New-Object Windows.Forms.CheckBox
$restoreDataCheck.Text = "Ao restaurar, voltar também os dados locais (normalmente deixe desmarcado)"
$restoreDataCheck.Dock = [Windows.Forms.DockStyle]::Fill
$restoreDataCheck.AutoEllipsis = $true
$restoreDataCheck.Checked = $false
$restorePanel.Controls.Add($restoreDataCheck, 0, 0)
$openBackupsButton = New-Object Windows.Forms.Button
$openBackupsButton.Text = "ABRIR BACKUPS"
$openBackupsButton.AutoSize = $true
$openBackupsButton.Dock = [Windows.Forms.DockStyle]::Right
$restorePanel.Controls.Add($openBackupsButton, 1, 0)

$footer = New-Object Windows.Forms.TableLayoutPanel
$footer.Dock = [Windows.Forms.DockStyle]::Fill
$footer.Margin = [Windows.Forms.Padding]::new(0)
$footer.ColumnCount = 1
$footer.RowCount = 2
[void]$footer.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 38)))
[void]$footer.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 100)))
$root.Controls.Add($footer, 0, 2)

$statusPanel = New-Object Windows.Forms.Panel
$statusPanel.Dock = [Windows.Forms.DockStyle]::Fill
$statusPanel.Margin = [Windows.Forms.Padding]::new(0, 0, 0, 6)
$footer.Controls.Add($statusPanel, 0, 0)
$statusLabel = New-Object Windows.Forms.Label
$statusLabel.Dock = [Windows.Forms.DockStyle]::Fill
$statusLabel.Padding = [Windows.Forms.Padding]::new(10, 0, 10, 0)
$statusLabel.TextAlign = [Drawing.ContentAlignment]::MiddleLeft
$statusLabel.AutoEllipsis = $true
$statusPanel.Controls.Add($statusLabel)

$buttonBar = New-Object Windows.Forms.TableLayoutPanel
$buttonBar.Dock = [Windows.Forms.DockStyle]::Fill
$buttonBar.Margin = [Windows.Forms.Padding]::new(0)
$buttonBar.ColumnCount = 3
[void]$buttonBar.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 33.33)))
[void]$buttonBar.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 33.34)))
[void]$buttonBar.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 33.33)))
$footer.Controls.Add($buttonBar, 0, 1)

$restoreButton = New-Object Windows.Forms.Button
$restoreButton.Text = "RESTAURAR ANTERIOR"
$restoreButton.Dock = [Windows.Forms.DockStyle]::Fill
$restoreButton.Margin = [Windows.Forms.Padding]::new(0, 0, 8, 0)
$buttonBar.Controls.Add($restoreButton, 0, 0)
$checkButton = New-Object Windows.Forms.Button
$checkButton.Text = "PROCURAR ATUALIZAÇÃO"
$checkButton.Dock = [Windows.Forms.DockStyle]::Fill
$checkButton.Margin = [Windows.Forms.Padding]::new(0, 0, 8, 0)
$buttonBar.Controls.Add($checkButton, 1, 0)
$installButton = New-Object Windows.Forms.Button
$installButton.Text = "BAIXAR E INSTALAR"
$installButton.Dock = [Windows.Forms.DockStyle]::Fill
$installButton.Margin = [Windows.Forms.Padding]::new(0)
$installButton.BackColor = [Drawing.Color]::FromArgb(37, 99, 235)
$installButton.ForeColor = [Drawing.Color]::White
$installButton.FlatStyle = [Windows.Forms.FlatStyle]::Flat
$installButton.FlatAppearance.BorderSize = 0
$installButton.Enabled = $false
$buttonBar.Controls.Add($installButton, 2, 0)

$channelCombo.Add_SelectedIndexChanged({
    $script:UserSettings.Channel = Get-SelectedUpdateChannel
    Save-UpdateUserSettings -Settings $script:UserSettings
    Refresh-UpdateEndpointState
})
$configureButton.Add_Click({
    $channel = Get-SelectedUpdateChannel
    $currentUrl = Get-ConfiguredUpdateUrl -InstallRoot $InstallRoot -Channel $channel -UserSettings $script:UserSettings
    $newUrl = Show-UpdateUrlDialog -ChannelName (Get-SelectedChannelName) -CurrentUrl $currentUrl
    if ($null -eq $newUrl) { return }
    if ($channel -eq "test") { $script:UserSettings.TestUrl = $newUrl }
    else { $script:UserSettings.StableUrl = $newUrl }
    Save-UpdateUserSettings -Settings $script:UserSettings
    Refresh-UpdateEndpointState
})
$checkButton.Add_Click({ Invoke-UpdateCheck })
$installButton.Add_Click({ Invoke-UpdateInstallation })
$restoreButton.Add_Click({ Invoke-LatestBackupRestore })
$openBackupsButton.Add_Click({
    $path = [IO.Path]::Combine((Get-CentralUpdaterDataDirectory), "Backups")
    if (-not [IO.Directory]::Exists($path)) { [void][IO.Directory]::CreateDirectory($path) }
    Start-Process -FilePath "explorer.exe" -ArgumentList ('"' + $path + '"')
})
$form.Add_Shown({
    $restoreButton.Enabled = @(Get-CentralUpdateBackups).Count -gt 0
    Refresh-UpdateEndpointState
})

try {
    [void]$form.ShowDialog()
}
finally {
    $form.Dispose()
    try { $script:UpdaterMutex.ReleaseMutex() } catch {}
    $script:UpdaterMutex.Dispose()
}

if ($script:RestartCentral) {
    $reopened = Start-CentralAfterUpdate -InstallRoot $InstallRoot
    if (-not $reopened) {
        [Windows.Forms.MessageBox]::Show(
            "A operação foi concluída, mas a Central de Trabalho não pôde ser reaberta automaticamente.`r`n`r`nAbra o programa normalmente pela pasta principal.",
            "Central não reabriu",
            [Windows.Forms.MessageBoxButtons]::OK,
            [Windows.Forms.MessageBoxIcon]::Warning
        ) | Out-Null
    }
}
