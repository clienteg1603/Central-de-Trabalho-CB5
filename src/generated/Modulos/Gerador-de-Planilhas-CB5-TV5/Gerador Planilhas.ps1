param(
    [Int64]$EmbeddedParentHandle = 0,
    [switch]$HostedInCentral,
    [string]$HostTheme = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$script:IsInProcessHosted = [bool]$HostedInCentral
$script:IsEmbedded = (($EmbeddedParentHandle -gt 0) -and -not $script:IsInProcessHosted)
$script:HostedFormExport = $null
$script:HostedControlExport = $null
$script:EmbeddedParentHandle = [IntPtr]::new($EmbeddedParentHandle)
$script:EmbeddedResizeTimer = $null

if ($script:IsEmbedded -and -not ("CentralModuleEmbed.Native" -as [type])) {
    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
namespace CentralModuleEmbed {
    public static class Native {
        public const int GWL_STYLE = -16;
        public const int WS_CHILD = 0x40000000;
        public const int WS_POPUP = unchecked((int)0x80000000);
        [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
        [DllImport("user32.dll", SetLastError=true)] public static extern IntPtr SetParent(IntPtr child, IntPtr newParent);
        [DllImport("user32.dll", SetLastError=true)] public static extern int GetWindowLong(IntPtr hWnd, int nIndex);
        [DllImport("user32.dll", SetLastError=true)] public static extern int SetWindowLong(IntPtr hWnd, int nIndex, int value);
        [DllImport("user32.dll", SetLastError=true)] [return: MarshalAs(UnmanagedType.Bool)] public static extern bool GetClientRect(IntPtr hWnd, out RECT rect);
        [DllImport("user32.dll", SetLastError=true)] [return: MarshalAs(UnmanagedType.Bool)] public static extern bool MoveWindow(IntPtr hWnd, int x, int y, int width, int height, bool repaint);
        public static void Attach(IntPtr child, IntPtr parent) {
            SetParent(child, parent);
            int style = GetWindowLong(child, GWL_STYLE);
            style = (style & ~WS_POPUP) | WS_CHILD;
            SetWindowLong(child, GWL_STYLE, style);
            Fit(child, parent);
        }
        public static void Fit(IntPtr child, IntPtr parent) {
            RECT r;
            if (GetClientRect(parent, out r)) MoveWindow(child, 0, 0, Math.Max(1, r.Right-r.Left), Math.Max(1, r.Bottom-r.Top), true);
        }
    }
}
"@
}

function Initialize-EmbeddedModuleWindow {
    param([Windows.Forms.Form]$TargetForm)
    if (-not $script:IsEmbedded) { return }
    try {
        $TargetForm.FormBorderStyle = [Windows.Forms.FormBorderStyle]::None
        $TargetForm.ShowInTaskbar = $false
        $TargetForm.ControlBox = $false
        $TargetForm.MinimizeBox = $false
        $TargetForm.MaximizeBox = $false
        $TargetForm.StartPosition = [Windows.Forms.FormStartPosition]::Manual
        $TargetForm.MinimumSize = [Drawing.Size]::new(1, 1)
        $TargetForm.Add_Shown({
            try {
                [CentralModuleEmbed.Native]::Attach($TargetForm.Handle, $script:EmbeddedParentHandle)
                $script:EmbeddedResizeTimer = New-Object Windows.Forms.Timer
                $script:EmbeddedResizeTimer.Interval = 180
                $script:EmbeddedResizeTimer.Add_Tick({
                    try { [CentralModuleEmbed.Native]::Fit($TargetForm.Handle, $script:EmbeddedParentHandle) } catch {}
                })
                $script:EmbeddedResizeTimer.Start()
            } catch {}
        }.GetNewClosure())
        $TargetForm.Add_FormClosed({
            try { if ($null -ne $script:EmbeddedResizeTimer) { $script:EmbeddedResizeTimer.Stop(); $script:EmbeddedResizeTimer.Dispose(); $script:EmbeddedResizeTimer = $null } } catch {}
        })
    } catch {}
}


$script:AppVersion = "3.6.1"
. ([IO.Path]::Combine($PSScriptRoot, "Componentes.Core.ps1"))

$script:SingleInstanceMutex = $null
$script:OwnsSingleInstanceMutex = $false
$createdNewMutex = $false
try {
    $script:SingleInstanceMutex = [Threading.Mutex]::new($true, "CentralDeTrabalho_GeradorPlanilhas", ([ref]$createdNewMutex))
    $script:OwnsSingleInstanceMutex = $createdNewMutex
}
catch {}

if ($null -ne $script:SingleInstanceMutex -and -not $script:OwnsSingleInstanceMutex) {
    [Windows.Forms.MessageBox]::Show(
        "O Gerenciador de Planilhas já está aberto.`r`n`r`nUse a janela que já está em execução para evitar duas operações simultâneas no Excel ou no saldo.",
        "Gerenciador de Planilhas",
        [Windows.Forms.MessageBoxButtons]::OK,
        [Windows.Forms.MessageBoxIcon]::Information
    ) | Out-Null
    $script:SingleInstanceMutex.Dispose()
    return
}

function Close-GeneratorSingleInstanceMutex {
    if ($null -eq $script:SingleInstanceMutex) { return }
    try {
        if ($script:OwnsSingleInstanceMutex) { $script:SingleInstanceMutex.ReleaseMutex() }
    }
    catch {}
    try { $script:SingleInstanceMutex.Dispose() }
    catch {}
    $script:SingleInstanceMutex = $null
    $script:OwnsSingleInstanceMutex = $false
}

$script:CurrentProduct = "CB5"
$script:CB5MaintenanceDefinitions = @(
    [pscustomobject]@{ Code = "TC";      Description = "TROCA DE CHIP(S)";                    Note = "";    Level = 0 },
    [pscustomobject]@{ Code = "ATFWCP";  Description = "ATUALIZAÇÃO FIRMWARE CAIXA PRETA";    Note = "";    Level = 0 },
    [pscustomobject]@{ Code = "AT";      Description = "AUTO TESTE ";                         Note = "";    Level = 0 },
    [pscustomobject]@{ Code = "EM";      Description = "EMBARCADO MACRO";                     Note = "";    Level = 0 },
    [pscustomobject]@{ Code = "TGBE";    Description = "TROCA DE GABINETE COM ETIQUETA";      Note = "";    Level = 0 },
    [pscustomobject]@{ Code = "TRB";     Description = "TROCA DE BATERIA";                    Note = "";    Level = 0 },
    [pscustomobject]@{ Code = "TM4G";    Description = "TROCADO MODEM 4G";                    Note = 1;     Level = 1 },
    [pscustomobject]@{ Code = "ADCBTT";  Description = "ADICIONADO BLUETOOTH";                Note = 2;     Level = 2 },
    [pscustomobject]@{ Code = "ADCLR";   Description = "ADICIONADO LORA";                     Note = 3;     Level = 3 },
    [pscustomobject]@{ Code = "TRS232";  Description = "TROCADO RS232";                       Note = "";    Level = $null },
    [pscustomobject]@{ Code = "TSCM";    Description = "TROCADO SICMA";                       Note = "";    Level = $null },
    [pscustomobject]@{ Code = "TMF";     Description = "TROCADO MEMORIA FLASH";               Note = "U4";  Level = $null },
    [pscustomobject]@{ Code = "TCP";     Description = "TROCADO CAPACITOR";                   Note = "U57"; Level = $null },
    [pscustomobject]@{ Code = "TRS485";  Description = "TROCADO RS485";                       Note = "";    Level = $null },
    [pscustomobject]@{ Code = "TRU20";   Description = "TROCADO U20";                         Note = "";    Level = $null },
    [pscustomobject]@{ Code = "TPCSS";   Description = "TROCADO PROCESSADOR";                 Note = "";    Level = $null },
    [pscustomobject]@{ Code = "TRCUS";   Description = "TROCADO CONECTOR USB";                Note = "";    Level = $null }
)
$script:MaintenanceDefinitions = $script:CB5MaintenanceDefinitions

# A ordem abaixo reproduz exatamente as linhas 2 a 21 da aba TABELA do modelo TV5.
# As linhas 2 a 7 são automáticas. A linha 8 (TLCD) vem da mestre e não é selecionável.
# As linhas 9 a 11 usam a descrição da coluna B no ORÇAMENTO; da linha 12 em diante,
# as opções adicionais usam a indicação da coluna C.
$script:TV5MaintenanceDefinitions = @(
    [pscustomobject]@{ Code = "ATFW";   Description = "ATUALIZAÇÃO DE FIRMWARE";          Note = "";        Additional = $false; BudgetAction = "";           BudgetComponent = "" },
    [pscustomobject]@{ Code = "TGBE";   Description = "TROCA DE GABINETE COM ETIQUETA";  Note = "";        Additional = $false; BudgetAction = "";           BudgetComponent = "" },
    [pscustomobject]@{ Code = "AT";     Description = "AUTO TESTE";                       Note = "";        Additional = $false; BudgetAction = "";           BudgetComponent = "" },
    [pscustomobject]@{ Code = "TCB";    Description = "TROCA DE CABO";                    Note = "";        Additional = $false; BudgetAction = "";           BudgetComponent = "" },
    [pscustomobject]@{ Code = "TM";     Description = "TROCA DE MANTA";                   Note = "";        Additional = $false; BudgetAction = "";           BudgetComponent = "" },
    [pscustomobject]@{ Code = "CXPP";   Description = "CAIXA DE PAPELÃO";                 Note = "";        Additional = $false; BudgetAction = "";           BudgetComponent = "" },
    [pscustomobject]@{ Code = "TLCD";   Description = "TROCA LCD";                        Note = "";        Additional = $false; BudgetAction = "";           BudgetComponent = "" },
    [pscustomobject]@{ Code = "TBZ";    Description = "TROCA DE BUZZER";                  Note = "";        Additional = $true;  BudgetAction = "TROCADO";    BudgetComponent = "BUZZER" },
    [pscustomobject]@{ Code = "TRS485"; Description = "TROCADO RS485";                    Note = "";        Additional = $true;  BudgetAction = "TROCADO";    BudgetComponent = "RS485" },
    [pscustomobject]@{ Code = "TPRC";   Description = "TROCADO PROCESSADOR";              Note = "";        Additional = $true;  BudgetAction = "TROCADO";    BudgetComponent = "PROCESSADOR" },
    [pscustomobject]@{ Code = "TRCNL";  Description = "TROCADO CONECTOR DO LCD";          Note = "CN1";     Additional = $true;  BudgetAction = "TROCADO";    BudgetComponent = "CN1" },
    [pscustomobject]@{ Code = "TRCUS";  Description = "TROCADO CONECTOR USB";             Note = "CN2";     Additional = $true;  BudgetAction = "TROCADO";    BudgetComponent = "CN2" },
    [pscustomobject]@{ Code = "ADCS";   Description = "ADICIONADO CONECTOR DO SPEAKER";   Note = "CN5 CN6"; Additional = $true;  BudgetAction = "TROCADO";    BudgetComponent = "CN5 CN6" },
    [pscustomobject]@{ Code = "TRCNC";  Description = "TROCADO CONECTOR DO CABO";         Note = "CN8";     Additional = $true;  BudgetAction = "TROCADO";    BudgetComponent = "CN8" },
    [pscustomobject]@{ Code = "TRD";    Description = "TROCA DIODO";                      Note = "D";       Additional = $true;  BudgetAction = "TROCADO";    BudgetComponent = "D" },
    [pscustomobject]@{ Code = "TCI";    Description = "TROCADO CIRCUITO INTEGRADO";       Note = "U";       Additional = $true;  BudgetAction = "TROCADO";    BudgetComponent = "U" },
    [pscustomobject]@{ Code = "TR";     Description = "TROCADO RESISTOR ";                 Note = "R";       Additional = $true;  BudgetAction = "TROCADO";    BudgetComponent = "R" },
    [pscustomobject]@{ Code = "TRBB";   Description = "TROCADO BOBINA";                   Note = "L";       Additional = $true;  BudgetAction = "TROCADO";    BudgetComponent = "L" },
    [pscustomobject]@{ Code = "TRCTL";  Description = "TROCADO CRISTAL";                  Note = "X";       Additional = $true;  BudgetAction = "TROCADO";    BudgetComponent = "X" },
    [pscustomobject]@{ Code = "TRCP";   Description = "TROCA CAPACITOR";                  Note = "C";       Additional = $true;  BudgetAction = "TROCADO";    BudgetComponent = "C" }
)

function Get-OleRgb {
    param([int]$Red, [int]$Green, [int]$Blue)
    return $Red + (256 * $Green) + (65536 * $Blue)
}

function Release-ComObject {
    param($Object)
    if ($null -ne $Object -and [System.Runtime.InteropServices.Marshal]::IsComObject($Object)) {
        [void][System.Runtime.InteropServices.Marshal]::FinalReleaseComObject($Object)
    }
}

function Normalize-Text {
    param([AllowNull()][object]$Value)
    if ($null -eq $Value) { return "" }
    return ([string]$Value).Trim()
}

function Normalize-Header {
    param([string]$Text)
    $decomposed = $Text.Normalize([Text.NormalizationForm]::FormD)
    $builder = New-Object Text.StringBuilder
    foreach ($character in $decomposed.ToCharArray()) {
        $category = [Globalization.CharUnicodeInfo]::GetUnicodeCategory($character)
        if ($category -ne [Globalization.UnicodeCategory]::NonSpacingMark) {
            [void]$builder.Append($character)
        }
    }
    return ($builder.ToString().ToUpperInvariant() -replace "\s+", "")
}

function Set-WorkbookWorksheetCount {
    param($Workbook, [int]$DesiredCount)
    $worksheets = $null
    $temporarySheet = $null
    try {
        $worksheets = $Workbook.Worksheets
        while ($worksheets.Count -lt $DesiredCount) {
            $temporarySheet = $worksheets.Add()
            Release-ComObject $temporarySheet
            $temporarySheet = $null
        }
        while ($worksheets.Count -gt $DesiredCount) {
            $temporarySheet = $worksheets.Item($worksheets.Count)
            $temporarySheet.Delete()
            Release-ComObject $temporarySheet
            $temporarySheet = $null
        }
    }
    finally {
        Release-ComObject $temporarySheet
        Release-ComObject $worksheets
    }
}

function Get-LastRequiredRow {
    param($Sheet, [int]$FirstColumn, [int]$LastColumn)
    $cells = $null
    $rows = $null
    $bottomCell = $null
    $lastCell = $null
    try {
        $cells = $Sheet.Cells
        $rows = $Sheet.Rows
        $maximumRow = [int]$rows.Count
        $lastRequiredRow = 1
        for ($column = $FirstColumn; $column -le $LastColumn; $column++) {
            $bottomCell = $cells.Item($maximumRow, $column)
            $lastCell = $bottomCell.End(-4162)
            $candidateRow = [int]$lastCell.Row
            if ($candidateRow -gt $lastRequiredRow) { $lastRequiredRow = $candidateRow }
            Release-ComObject $lastCell
            Release-ComObject $bottomCell
            $lastCell = $null
            $bottomCell = $null
        }
        return $lastRequiredRow
    }
    finally {
        Release-ComObject $lastCell
        Release-ComObject $bottomCell
        Release-ComObject $rows
        Release-ComObject $cells
    }
}

function Set-OptionalPageSetup {
    param($Sheet)
    $pageSetup = $null
    try {
        $pageSetup = $Sheet.PageSetup
        try { $pageSetup.Orientation = 1 } catch {}
        try { $pageSetup.PaperSize = 9 } catch {}
    }
    catch {}
    finally {
        Release-ComObject $pageSetup
    }
}

function Assert-FileAvailableForReplace {
    param([string]$Path)
    if (-not [IO.File]::Exists($Path)) { return }
    $attributes = [IO.File]::GetAttributes($Path)
    if (($attributes -band [IO.FileAttributes]::ReadOnly) -ne 0) {
        throw "Retire a opção 'Somente leitura' do arquivo '$([IO.Path]::GetFileName($Path))' antes de gerar novamente."
    }
    $stream = $null
    try {
        $stream = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
    }
    catch {
        throw "Feche o arquivo '$([IO.Path]::GetFileName($Path))' no Excel antes de gerar novamente."
    }
    finally {
        if ($null -ne $stream) { $stream.Dispose() }
    }
}

function Assert-GeneratedFile {
    param([string]$Path, [string]$Description)
    if (-not [IO.File]::Exists($Path)) { throw "O arquivo $Description não foi criado." }
    $fileInfo = [IO.FileInfo]::new($Path)
    if ($fileInfo.Length -le 0) { throw "O arquivo $Description foi criado vazio." }
}

function Get-OperatorDisplayName {
    param([string]$Value)
    $text = (Normalize-Text $Value)
    $lower = $text.ToLowerInvariant()
    $exactOperators = [ordered]@{
        "onixsat.vivo.com.br"  = "Vivo"
        "onixsat.claro.com.br" = "Claro"
        "onixsat.tim.br"       = "Tim"
        "trucks.v.quectel.br"  = "Quectel"
        "onixsat.vodafone.br"  = "Arquia"
    }
    if ($exactOperators.Contains($lower)) {
        return $exactOperators[$lower]
    }

    $operatorAliases = [ordered]@{
        "vodafone" = "Arquia"
        "arquia"   = "Arquia"
        "quectel"  = "Quectel"
        "vivo"     = "Vivo"
        "claro"    = "Claro"
        "tim"      = "Tim"
    }
    foreach ($key in $operatorAliases.Keys) {
        $escaped = [Text.RegularExpressions.Regex]::Escape($key)
        if ($lower -match "(^|[^a-z0-9])$escaped([^a-z0-9]|$)") {
            return $operatorAliases[$key]
        }
    }
    if ($lower -match "^[a-z0-9]+$") {
        return $lower.Substring(0, 1).ToUpperInvariant() + $lower.Substring(1)
    }
    throw "Não foi possível identificar a operadora pelo valor '$Value'. Operadoras reconhecidas: Vivo, Claro, Tim, Quectel e Arquia."
}

function Get-MaintenanceCodes {
    param([int]$Level)
    $codes = [Collections.Generic.List[string]]::new()
    foreach ($definition in $script:MaintenanceDefinitions) {
        if ($null -ne $definition.Level -and [int]$definition.Level -eq 0) {
            $codes.Add($definition.Code)
        }
    }
    if ($Level -ge 1) { $codes.Add("TM4G") }
    if ($Level -ge 2) { $codes.Add("ADCBTT") }
    if ($Level -ge 3) { $codes.Add("ADCLR") }
    return ,$codes
}

function Get-RepairComponentKey {
    param([string]$Text)
    $key = (Normalize-Header $Text) -replace "[^A-Z0-9]", ""
    foreach ($prefix in @("TROCADE", "TROCADO", "TROCADA", "TROCA", "ADICIONADO", "ADICIONADA")) {
        if ($key.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
            $key = $key.Substring($prefix.Length)
            break
        }
    }
    return $key
}

function Get-CB5RepairInfo {
    param(
        [string]$Text,
        [switch]$AllowUnknownRepair
    )

    $match = [Text.RegularExpressions.Regex]::Match(
        (Normalize-Text $Text),
        "^\s*ASTEC\s*([123])?\s*(?:,\s*(.+))?$",
        [Text.RegularExpressions.RegexOptions]::IgnoreCase
    )
    if (-not $match.Success) {
        if ($AllowUnknownRepair) {
            return [pscustomobject]@{
                Level = 0
                Codes = [Collections.Generic.List[string]]::new()
                LastAction = ""
            }
        }
        throw "REPARO '$Text' não reconhecido para CB5. Comece com ASTEC, ASTEC 1, ASTEC 2 ou ASTEC 3 e separe as manutenções por vírgulas."
    }

    $level = if ($match.Groups[1].Success) { [int]$match.Groups[1].Value } else { 0 }
    $codes = Get-MaintenanceCodes $level
    $componentCodes = [ordered]@{
        "RS232"        = "TRS232"
        "SICMA"        = "TSCM"
        "MEMORIAFLASH" = "TMF"
        "CAPACITOR"    = "TCP"
        "RS485"        = "TRS485"
        "U20"          = "TRU20"
        "PROCESSADOR"  = "TPCSS"
        "CONECTORUSB"  = "TRCUS"
    }

    $hasAdditionalRepair = $false
    if ($match.Groups[2].Success) {
        foreach ($component in $match.Groups[2].Value.Split(",")) {
            $componentText = (Normalize-Text $component)
            if ([string]::IsNullOrWhiteSpace($componentText)) {
                throw "REPARO '$Text' possui uma manutenção vazia entre vírgulas."
            }
            $componentKey = Get-RepairComponentKey $componentText
            if ($componentCodes.Contains($componentKey)) {
                $code = $componentCodes[$componentKey]
            }
            else {
                $catalogComponent = Get-BillingComponentForRepairPart $script:BillingComponentStore "CB5" $componentText
                $code = if ($null -ne $catalogComponent) { [string]$catalogComponent.CodigoPlanilha } else { "" }
                if ([string]::IsNullOrWhiteSpace($code)) {
                    if ($AllowUnknownRepair) { continue }
                    throw "Manutenção '$componentText' não reconhecida no REPARO '$Text'. Confira o texto e, se for um componente novo, cadastre-o em Componentes a faturar com o código da planilha."
                }
            }
            if (-not $codes.Contains($code)) { $codes.Add($code) }
            $hasAdditionalRepair = $true
        }
    }

    return [pscustomobject]@{
        Level = $level
        Codes = $codes
        LastAction = if ($hasAdditionalRepair) { "TROCADO" } else { "" }
    }
}

function Get-VivoVersion {
    param([string]$FullVersion)
    $parts = $FullVersion.Trim().Split(".")
    if ($parts.Count -lt 2 -or [string]::IsNullOrWhiteSpace($parts[0]) -or [string]::IsNullOrWhiteSpace($parts[1])) {
        throw "VERSÃO '$FullVersion' inválida. O Chip1 precisa dos dois primeiros blocos, como 5.54."
    }
    return "$($parts[0]).$($parts[1])"
}

function Assert-TextIdentifier {
    param(
        [AllowNull()][object]$RawValue,
        [string]$ColumnName,
        [int]$RowNumber
    )
    if ($null -eq $RawValue -or [string]::IsNullOrWhiteSpace([string]$RawValue)) {
        throw "A coluna $ColumnName está vazia na linha $RowNumber."
    }
    if ($RawValue -isnot [string]) {
        throw "A célula $ColumnName$RowNumber precisa estar como TEXTO para não perder zeros ou dígitos."
    }
    return ([string]$RawValue).Trim()
}

function Read-MasterWorkbook {
    param(
        $Excel,
        [string]$Path,
        [switch]$RequireInvoices,
        [switch]$AllowUnknownRepair
    )

    $workbooks = $null
    $workbook = $null
    $worksheets = $null
    $sheet = $null
    $range = $null
    try {
        $workbooks = $Excel.Workbooks
        $workbook = $workbooks.Open($Path, 0, $true)
        Release-ComObject $workbooks
        $workbooks = $null
        $worksheets = $workbook.Worksheets
        $sheet = $worksheets.Item(1)
        Release-ComObject $worksheets
        $worksheets = $null
        $lastColumn = if ($RequireInvoices) { 10 } else { 8 }
        $lastColumnLetter = if ($RequireInvoices) { "J" } else { "H" }
        $lastRow = Get-LastRequiredRow $sheet 1 $lastColumn
        if ($lastRow -lt 2) {
            throw "A planilha mestre não possui peças abaixo do cabeçalho."
        }

        $range = $sheet.Range("A1", "$lastColumnLetter$lastRow")
        $matrix = $range.Value2
        $expectedHeaders = @("SERIE", "LOTE", "VERSAO", "REPARO", "OPERADORA1", "ICCID1", "OPERADORA2", "ICCID2")
        if ($RequireInvoices) { $expectedHeaders += @("NFDEENTRADA", "NFDESAIDA") }
        for ($column = 1; $column -le $lastColumn; $column++) {
            $actual = Normalize-Header ([string]$matrix[1, $column])
            if ($actual -ne $expectedHeaders[$column - 1]) {
                throw "Cabeçalho inválido na coluna $column. Esperado '$($expectedHeaders[$column - 1])' e encontrado '$($matrix[1, $column])'."
            }
        }

        $items = [Collections.Generic.List[object]]::new()
        $seriesSeen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        $chip1Seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        $chip2Seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        $lotValue = $null
        $operator1Name = $null
        $operator2Name = $null

        for ($row = 2; $row -le $lastRow; $row++) {
            $series = Assert-TextIdentifier $matrix[$row, 1] "A" $row
            $lot = Assert-TextIdentifier $matrix[$row, 2] "B" $row
            $version = Normalize-Text $matrix[$row, 3]
            $repair = Normalize-Text $matrix[$row, 4]
            $operator1 = Normalize-Text $matrix[$row, 5]
            $iccid1 = Assert-TextIdentifier $matrix[$row, 6] "F" $row
            $operator2 = Normalize-Text $matrix[$row, 7]
            $iccid2 = Assert-TextIdentifier $matrix[$row, 8] "H" $row
            $entryInvoice = if ($RequireInvoices) { Normalize-Text $matrix[$row, 9] } else { "" }
            $exitInvoice = if ($RequireInvoices) { Normalize-Text $matrix[$row, 10] } else { "" }

            if ([string]::IsNullOrWhiteSpace($version)) { throw "A coluna VERSÃO está vazia na linha $row." }
            if ([string]::IsNullOrWhiteSpace($repair)) { throw "A coluna REPARO está vazia na linha $row." }
            if ([string]::IsNullOrWhiteSpace($operator1)) { throw "A coluna OPERADORA1 está vazia na linha $row." }
            if ([string]::IsNullOrWhiteSpace($operator2)) { throw "A coluna OPERADORA2 está vazia na linha $row." }
            if ($RequireInvoices -and [string]::IsNullOrWhiteSpace($entryInvoice)) { throw "A coluna NF DE ENTRADA está vazia na linha $row." }
            if ($RequireInvoices -and [string]::IsNullOrWhiteSpace($exitInvoice)) { throw "A coluna NF DE SAÍDA está vazia na linha $row." }
            $currentOperator1Name = Get-OperatorDisplayName $operator1
            $currentOperator2Name = Get-OperatorDisplayName $operator2
            if (-not $seriesSeen.Add($series)) { throw "SÉRIE duplicada na planilha mestre: $series." }
            if (-not $chip1Seen.Add($iccid1)) { throw "ICCID1 duplicado na planilha mestre: $iccid1." }
            if (-not $chip2Seen.Add($iccid2)) { throw "ICCID2 duplicado na planilha mestre: $iccid2." }
            if ($null -eq $lotValue) { $lotValue = $lot }
            elseif ($lotValue -ne $lot) { throw "Foram encontrados lotes diferentes: '$lotValue' e '$lot'." }
            if ($null -eq $operator1Name) { $operator1Name = $currentOperator1Name }
            elseif ($operator1Name -ne $currentOperator1Name) { throw "A coluna OPERADORA1 mistura operadoras diferentes: '$operator1Name' e '$currentOperator1Name'." }
            if ($null -eq $operator2Name) { $operator2Name = $currentOperator2Name }
            elseif ($operator2Name -ne $currentOperator2Name) { throw "A coluna OPERADORA2 mistura operadoras diferentes: '$operator2Name' e '$currentOperator2Name'." }

            $repairInfo = Get-CB5RepairInfo $repair -AllowUnknownRepair:$AllowUnknownRepair
            $items.Add([pscustomobject]@{
                Series = $series
                Lot = $lot
                FullVersion = $version
                VivoVersion = (Get-VivoVersion $version)
                Repair = $repair
                RepairLevel = $repairInfo.Level
                Operator1 = $operator1
                Iccid1 = $iccid1
                Operator2 = $operator2
                Iccid2 = $iccid2
                EntryInvoice = $entryInvoice
                ExitInvoice = $exitInvoice
                MaintenanceCodes = $repairInfo.Codes
                LastBudgetAction = $repairInfo.LastAction
            })
        }

        return [pscustomobject]@{
            Lot = $lotValue
            Operator1Name = $operator1Name
            Operator2Name = $operator2Name
            Items = $items
        }
    }
    finally {
        if ($null -ne $workbook) { try { $workbook.Close($false) } catch {} }
        Release-ComObject $range
        Release-ComObject $sheet
        Release-ComObject $worksheets
        Release-ComObject $workbook
        Release-ComObject $workbooks
    }
}

function Get-TV5RepairInfo {
    param(
        [string]$Text,
        [switch]$AllowUnknownRepair
    )

    $match = [Text.RegularExpressions.Regex]::Match(
        (Normalize-Text $Text),
        "^\s*ASTEC\s+TV5\s*(?:,\s*(.+))?$",
        [Text.RegularExpressions.RegexOptions]::IgnoreCase
    )
    if (-not $match.Success) {
        if ($AllowUnknownRepair) {
            return [pscustomobject]@{
                Codes = [Collections.Generic.List[string]]::new()
                LastAction = ""
            }
        }
        throw "REPARO '$Text' não reconhecido para TV5. Comece com ASTEC TV5 e separe as manutenções por vírgulas."
    }

    $codes = [Collections.Generic.List[string]]::new()
    foreach ($code in @("ATFW", "TGBE", "AT", "TCB", "TM", "CXPP")) { $codes.Add($code) }
    $componentCodes = [ordered]@{
        "LCD"                         = "TLCD"
        "BUZZER"                      = "TBZ"
        "RS485"                       = "TRS485"
        "PROCESSADOR"                 = "TPRC"
        "CN1"                         = "TRCNL"
        "CONECTORDOLCD"               = "TRCNL"
        "CN2"                         = "TRCUS"
        "CONECTORUSB"                 = "TRCUS"
        "CN5CN6"                      = "ADCS"
        "CONECTORDOSPEAKER"           = "ADCS"
        "CN8"                         = "TRCNC"
        "CONECTORDOCABO"              = "TRCNC"
        "D"                           = "TRD"
        "DIODO"                       = "TRD"
        "U"                           = "TCI"
        "CIRCUITOINTEGRADO"           = "TCI"
        "R"                           = "TR"
        "RESISTOR"                    = "TR"
        "L"                           = "TRBB"
        "BOBINA"                      = "TRBB"
        "X"                           = "TRCTL"
        "CRISTAL"                     = "TRCTL"
        "C"                           = "TRCP"
        "CAPACITOR"                   = "TRCP"
    }

    $hasRepair = $false
    if ($match.Groups[1].Success) {
        foreach ($component in $match.Groups[1].Value.Split(",")) {
            $componentText = (Normalize-Text $component)
            if ([string]::IsNullOrWhiteSpace($componentText)) {
                throw "REPARO '$Text' possui uma manutenção vazia entre vírgulas."
            }
            $componentKey = Get-RepairComponentKey $componentText
            if ($componentCodes.Contains($componentKey)) {
                $code = $componentCodes[$componentKey]
            }
            else {
                $catalogComponent = Get-BillingComponentForRepairPart $script:BillingComponentStore "TV5" $componentText
                $code = if ($null -ne $catalogComponent) { [string]$catalogComponent.CodigoPlanilha } else { "" }
                if ([string]::IsNullOrWhiteSpace($code)) {
                    if ($AllowUnknownRepair) { continue }
                    throw "Manutenção '$componentText' não reconhecida no REPARO '$Text'. Confira o texto e, se for um componente novo, cadastre-o em Componentes a faturar com o código da planilha."
                }
            }
            if (-not $codes.Contains($code)) { $codes.Add($code) }
            $hasRepair = $true
        }
    }

    return [pscustomobject]@{
        HasLcd = $codes.Contains("TLCD")
        Codes = $codes
        LastAction = if ($hasRepair) { "TROCADO" } else { "" }
    }
}

function Read-TV5MasterWorkbook {
    param(
        $Excel,
        [string]$Path,
        [switch]$AllowBlankInvoices,
        [switch]$AllowUnknownRepair
    )

    $workbooks = $null
    $workbook = $null
    $worksheets = $null
    $sheet = $null
    $range = $null
    try {
        $workbooks = $Excel.Workbooks
        $workbook = $workbooks.Open($Path, 0, $true)
        Release-ComObject $workbooks
        $workbooks = $null
        $worksheets = $workbook.Worksheets
        $sheet = $worksheets.Item(1)
        Release-ComObject $worksheets
        $worksheets = $null
        $lastRow = Get-LastRequiredRow $sheet 1 6
        if ($lastRow -lt 2) {
            throw "A planilha mestre TV5 não possui peças abaixo do cabeçalho."
        }

        $range = $sheet.Range("A1", "F$lastRow")
        $matrix = $range.Value2
        $expectedHeaders = @("SERIE", "LOTE", "VERSAO", "REPARO", "NFDEENTRADA", "NFDESAIDA")
        for ($column = 1; $column -le 6; $column++) {
            $actual = Normalize-Header ([string]$matrix[1, $column])
            if ($actual -ne $expectedHeaders[$column - 1]) {
                throw "Cabeçalho TV5 inválido na coluna $column. Esperado '$($expectedHeaders[$column - 1])' e encontrado '$($matrix[1, $column])'."
            }
        }

        $items = [Collections.Generic.List[object]]::new()
        $seriesSeen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        $lotValue = $null

        for ($row = 2; $row -le $lastRow; $row++) {
            $series = Assert-TextIdentifier $matrix[$row, 1] "A" $row
            $lot = Assert-TextIdentifier $matrix[$row, 2] "B" $row
            $version = Normalize-Text $matrix[$row, 3]
            $repair = Normalize-Text $matrix[$row, 4]
            $entryInvoice = Normalize-Text $matrix[$row, 5]
            $exitInvoice = Normalize-Text $matrix[$row, 6]

            if ([string]::IsNullOrWhiteSpace($version)) { throw "A coluna VERSÃO está vazia na linha $row." }
            if ([string]::IsNullOrWhiteSpace($repair)) { throw "A coluna REPARO está vazia na linha $row." }
            if (-not $AllowBlankInvoices -and [string]::IsNullOrWhiteSpace($entryInvoice)) { throw "A coluna NF DE ENTRADA está vazia na linha $row." }
            if (-not $AllowBlankInvoices -and [string]::IsNullOrWhiteSpace($exitInvoice)) { throw "A coluna NF DE SAÍDA está vazia na linha $row." }
            if (-not $seriesSeen.Add($series)) { throw "SÉRIE duplicada na planilha mestre TV5: $series." }
            if ($null -eq $lotValue) { $lotValue = $lot }
            elseif ($lotValue -ne $lot) { throw "Foram encontrados lotes diferentes na mestre TV5: '$lotValue' e '$lot'." }

            $repairInfo = Get-TV5RepairInfo $repair -AllowUnknownRepair:$AllowUnknownRepair
            $codes = [Collections.Generic.List[string]]::new()
            foreach ($code in $repairInfo.Codes) { $codes.Add($code) }
            $items.Add([pscustomobject]@{
                Series = $series
                Lot = $lot
                FullVersion = $version
                Repair = $repair
                EntryInvoice = $entryInvoice
                ExitInvoice = $exitInvoice
                MaintenanceCodes = $codes
                LastBudgetAction = $repairInfo.LastAction
            })
        }

        return [pscustomobject]@{
            Lot = $lotValue
            Items = $items
        }
    }
    finally {
        if ($null -ne $workbook) { try { $workbook.Close($false) } catch {} }
        Release-ComObject $range
        Release-ComObject $sheet
        Release-ComObject $worksheets
        Release-ComObject $workbook
        Release-ComObject $workbooks
    }
}

function Save-UpdatedMasterCopy {
    param(
        $Excel,
        [string]$SourcePath,
        [Collections.Generic.List[object]]$Items,
        [string]$DestinationPath
    )

    if ($Items.Count -lt 1) { throw "A mestre não possui peças para atualizar." }
    Copy-Item -LiteralPath $SourcePath -Destination $DestinationPath -Force

    $workbooks = $null
    $workbook = $null
    $worksheets = $null
    $sheet = $null
    $range = $null
    try {
        $workbooks = $Excel.Workbooks
        $workbook = $workbooks.Open($DestinationPath, 0, $false)
        Release-ComObject $workbooks
        $workbooks = $null
        $worksheets = $workbook.Worksheets
        $sheet = $worksheets.Item(1)
        Release-ComObject $worksheets
        $worksheets = $null

        $matrix = New-ObjectMatrix $Items.Count 1
        for ($index = 0; $index -lt $Items.Count; $index++) {
            $matrix[$index, 0] = $Items[$index].Repair
        }
        $lastRow = $Items.Count + 1
        $range = $sheet.Range("D2", "D$lastRow")
        $range.NumberFormat = "@"
        $range.Value2 = $matrix
        $workbook.Save()
    }
    finally {
        if ($null -ne $workbook) { try { $workbook.Close($false) } catch {} }
        Release-ComObject $range
        Release-ComObject $sheet
        Release-ComObject $worksheets
        Release-ComObject $workbook
        Release-ComObject $workbooks
    }

    Assert-GeneratedFile $DestinationPath "da mestre atualizada"
}

function New-ObjectMatrix {
    param([int]$Rows, [int]$Columns)
    return ,([Array]::CreateInstance([object], @($Rows, $Columns)))
}

function Set-AllBorders {
    param($Range, [int]$Weight = 2)
    $borders = $null
    try {
        $borders = $Range.Borders
        $borders.LineStyle = 1
        $borders.Weight = $Weight
        $borders.Color = Get-OleRgb 0 0 0
    }
    finally {
        Release-ComObject $borders
    }
}

function Save-MaintenanceWorkbook {
    param(
        $Excel,
        [Collections.Generic.List[object]]$Items,
        [string]$Path
    )
    $workbooks = $null
    $workbook = $null
    $worksheets = $null
    $sheet1 = $null
    $sheet2 = $null
    $range1 = $null
    $range2 = $null
    try {
        $workbooks = $Excel.Workbooks
        $workbook = $workbooks.Add()
        Release-ComObject $workbooks
        $workbooks = $null
        Set-WorkbookWorksheetCount $workbook 2
        $worksheets = $workbook.Worksheets
        $sheet1 = $worksheets.Item(1)
        $sheet2 = $worksheets.Item(2)
        Release-ComObject $worksheets
        $worksheets = $null
        $temporarySheetSuffix = [Guid]::NewGuid().ToString("N").Substring(0, 8)
        $sheet1.Name = "CB5_1_$temporarySheetSuffix"
        $sheet2.Name = "CB5_2_$temporarySheetSuffix"
        $sheet1.Name = "Planilha1"
        $sheet2.Name = "Planilha2"

        $rowCount = $Items.Count + 1
        $values1 = New-ObjectMatrix $rowCount 2
        $values1.SetValue("SERIE", 0, 0)
        $values1.SetValue("REPARO", 0, 1)
        for ($index = 0; $index -lt $Items.Count; $index++) {
            $values1.SetValue($Items[$index].Series, $index + 1, 0)
            $values1.SetValue(($Items[$index].MaintenanceCodes -join ", "), $index + 1, 1)
        }
        $range1 = $sheet1.Range("A1", "B$rowCount")
        $range1.NumberFormat = "@"
        $range1.Value2 = $values1
        $range1.Font.Name = "Calibri"
        $range1.Font.Size = 11
        Set-AllBorders $range1 2
        $sheet1.Range("A1:B1").Interior.Color = Get-OleRgb 191 191 191
        $sheet1.Range("A1").HorizontalAlignment = -4108
        $sheet1.Range("B1").HorizontalAlignment = -4131
        $sheet1.Range("A2:A$rowCount").HorizontalAlignment = -4108
        $sheet1.Range("B2:B$rowCount").HorizontalAlignment = -4131
        $sheet1.Columns.Item("A").ColumnWidth = 9
        $sheet1.Columns.Item("B").ColumnWidth = 43.29

        $definitionRows = $script:MaintenanceDefinitions.Count + 1
        $values2 = New-ObjectMatrix $definitionRows 3
        $values2.SetValue("CÓDIGO", 0, 0)
        $values2.SetValue("DESCRIÇÃO", 0, 1)
        $values2.SetValue("", 0, 2)
        for ($index = 0; $index -lt $script:MaintenanceDefinitions.Count; $index++) {
            $definition = $script:MaintenanceDefinitions[$index]
            $values2.SetValue($definition.Code, $index + 1, 0)
            $values2.SetValue($definition.Description, $index + 1, 1)
            $values2.SetValue($definition.Note, $index + 1, 2)
        }
        $range2 = $sheet2.Range("A1", "C$definitionRows")
        $range2.Value2 = $values2
        $range2.Font.Name = "Calibri"
        $range2.Font.Size = 11
        $sheet2.Range("A1:B$definitionRows").NumberFormat = "@"
        Set-AllBorders ($sheet2.Range("A1:B$definitionRows")) 2
        $sheet2.Range("A1:B1").Interior.Color = Get-OleRgb 191 191 191
        $sheet2.Range("A1:B1").Font.Bold = $true
        $sheet2.Range("A8:B10").Interior.Color = Get-OleRgb 221 235 247
        $sheet2.Range("A11:B16").Interior.Color = Get-OleRgb 189 215 238
        $sheet2.Range("A17:B18").Interior.Color = Get-OleRgb 91 155 213
        $sheet2.Columns.Item("A").ColumnWidth = 8.86
        $sheet2.Columns.Item("B").ColumnWidth = 34.86
        $sheet2.Columns.Item("C").ColumnWidth = 4.29
        $sheet2.Range("A2:A$definitionRows").WrapText = $true

        $workbook.SaveAs($Path, 51)
        $workbook.Close($false)
    }
    finally {
        if ($null -ne $workbook) {
            try { if (-not $workbook.Saved) { $workbook.Close($false) } } catch {}
        }
        Release-ComObject $range2
        Release-ComObject $range1
        Release-ComObject $sheet2
        Release-ComObject $sheet1
        Release-ComObject $worksheets
        Release-ComObject $workbook
        Release-ComObject $workbooks
    }
}

function Save-TV5Workbook {
    param(
        $Excel,
        [Collections.Generic.List[object]]$Items,
        [string]$Path
    )
    $workbooks = $null
    $workbook = $null
    $worksheets = $null
    $budgetSheet = $null
    $maintenanceSheet = $null
    $tableSheet = $null
    $budgetRange = $null
    $maintenanceRange = $null
    $tableRange = $null
    try {
        $workbooks = $Excel.Workbooks
        $workbook = $workbooks.Add()
        Release-ComObject $workbooks
        $workbooks = $null
        Set-WorkbookWorksheetCount $workbook 3
        $worksheets = $workbook.Worksheets
        $budgetSheet = $worksheets.Item(1)
        $maintenanceSheet = $worksheets.Item(2)
        $tableSheet = $worksheets.Item(3)
        Release-ComObject $worksheets
        $worksheets = $null

        $temporarySheetSuffix = [Guid]::NewGuid().ToString("N").Substring(0, 8)
        $budgetSheet.Name = "TV5_1_$temporarySheetSuffix"
        $maintenanceSheet.Name = "TV5_2_$temporarySheetSuffix"
        $tableSheet.Name = "TV5_3_$temporarySheetSuffix"
        $budgetSheet.Name = "ORÇAMENTO"
        $maintenanceSheet.Name = "MANUTENÇÃO"
        $tableSheet.Name = "TABELA"

        $rowCount = $Items.Count + 1
        $budgetValues = New-ObjectMatrix $rowCount 6
        $budgetHeaders = @("SÉRIE", "LOTE", "VERSÃO", "REPARO", "NF DE ENTRADA", "NF DE SAÍDA")
        for ($column = 0; $column -lt 6; $column++) { $budgetValues.SetValue($budgetHeaders[$column], 0, $column) }
        for ($index = 0; $index -lt $Items.Count; $index++) {
            $item = $Items[$index]
            $row = @($item.Series, $item.Lot, $item.FullVersion, $item.Repair, $item.EntryInvoice, $item.ExitInvoice)
            for ($column = 0; $column -lt 6; $column++) { $budgetValues.SetValue($row[$column], $index + 1, $column) }
        }
        $budgetRange = $budgetSheet.Range("A1", "F$rowCount")
        $budgetRange.NumberFormat = "@"
        $budgetRange.Value2 = $budgetValues
        $budgetRange.Font.Name = "Calibri"
        $budgetRange.Font.Size = 11
        Set-AllBorders $budgetRange 2
        $budgetSheet.Range("A1:F1").Interior.Color = Get-OleRgb 191 191 191
        $budgetSheet.Range("A1:F1").Font.Bold = $true
        $budgetSheet.Range("A1:F1").HorizontalAlignment = -4108
        $budgetSheet.Range("A2:C$rowCount").HorizontalAlignment = -4108
        $budgetSheet.Range("D2:D$rowCount").HorizontalAlignment = -4131
        $budgetSheet.Range("E2:F$rowCount").HorizontalAlignment = -4108
        $budgetSheet.Columns.Item("A").ColumnWidth = 10
        $budgetSheet.Columns.Item("B").ColumnWidth = 10
        $budgetSheet.Columns.Item("C").ColumnWidth = 11
        $budgetSheet.Columns.Item("D").ColumnWidth = 65
        $budgetSheet.Columns.Item("E").ColumnWidth = 16
        $budgetSheet.Columns.Item("F").ColumnWidth = 15

        $maintenanceValues = New-ObjectMatrix $rowCount 2
        $maintenanceValues.SetValue("SÉRIE", 0, 0)
        $maintenanceValues.SetValue("REPARO", 0, 1)
        for ($index = 0; $index -lt $Items.Count; $index++) {
            $maintenanceValues.SetValue($Items[$index].Series, $index + 1, 0)
            $maintenanceValues.SetValue(($Items[$index].MaintenanceCodes -join ", "), $index + 1, 1)
        }
        $maintenanceRange = $maintenanceSheet.Range("A1", "B$rowCount")
        $maintenanceRange.NumberFormat = "@"
        $maintenanceRange.Value2 = $maintenanceValues
        $maintenanceRange.Font.Name = "Calibri"
        $maintenanceRange.Font.Size = 11
        Set-AllBorders $maintenanceRange 2
        $maintenanceSheet.Range("A1:B1").Interior.Color = Get-OleRgb 191 191 191
        $maintenanceSheet.Range("A1:B1").Font.Bold = $true
        $maintenanceSheet.Range("A1:B1").HorizontalAlignment = -4131
        $maintenanceSheet.Range("A2:A$rowCount").HorizontalAlignment = -4108
        $maintenanceSheet.Range("B2:B$rowCount").HorizontalAlignment = -4131
        $maintenanceSheet.Columns.Item("A").ColumnWidth = 10
        $maintenanceSheet.Columns.Item("B").ColumnWidth = 52

        $definitionRows = $script:TV5MaintenanceDefinitions.Count + 1
        $tableValues = New-ObjectMatrix $definitionRows 3
        $tableValues.SetValue("CÓDIGO", 0, 0)
        $tableValues.SetValue("DESCRIÇÃO", 0, 1)
        $tableValues.SetValue("", 0, 2)
        for ($index = 0; $index -lt $script:TV5MaintenanceDefinitions.Count; $index++) {
            $definition = $script:TV5MaintenanceDefinitions[$index]
            $tableValues.SetValue($definition.Code, $index + 1, 0)
            $tableValues.SetValue($definition.Description, $index + 1, 1)
            $tableValues.SetValue($definition.Note, $index + 1, 2)
        }
        $tableRange = $tableSheet.Range("A1", "C$definitionRows")
        $tableRange.Value2 = $tableValues
        $tableRange.Font.Name = "Calibri"
        $tableRange.Font.Size = 11
        $tableSheet.Range("A1:C$definitionRows").NumberFormat = "@"
        Set-AllBorders ($tableSheet.Range("A1:B$definitionRows")) 2
        $tableSheet.Range("A1:B1").Interior.Color = Get-OleRgb 191 191 191
        $tableSheet.Range("A1:B1").Font.Bold = $true
        $tableSheet.Range("A2:B7").Interior.Color = Get-OleRgb 221 235 247
        $tableSheet.Range("A8:B$definitionRows").Interior.Color = Get-OleRgb 189 215 238
        $tableSheet.Columns.Item("A").ColumnWidth = 10
        $tableSheet.Columns.Item("B").ColumnWidth = 39
        $tableSheet.Columns.Item("C").ColumnWidth = 10
        $tableSheet.Range("A2:C$definitionRows").WrapText = $true

        Set-OptionalPageSetup $budgetSheet
        Set-OptionalPageSetup $maintenanceSheet
        Set-OptionalPageSetup $tableSheet
        $workbook.SaveAs($Path, 51)
        $workbook.Close($false)
    }
    finally {
        if ($null -ne $workbook) {
            try { if (-not $workbook.Saved) { $workbook.Close($false) } } catch {}
        }
        Release-ComObject $tableRange
        Release-ComObject $maintenanceRange
        Release-ComObject $budgetRange
        Release-ComObject $tableSheet
        Release-ComObject $maintenanceSheet
        Release-ComObject $budgetSheet
        Release-ComObject $worksheets
        Release-ComObject $workbook
        Release-ComObject $workbooks
    }
}

function Save-CB5CombinedWorkbook {
    param(
        $Excel,
        [Collections.Generic.List[object]]$Items,
        [string]$Path
    )
    $workbooks = $null
    $workbook = $null
    $worksheets = $null
    $budgetSheet = $null
    $maintenanceSheet = $null
    $tableSheet = $null
    $budgetRange = $null
    $maintenanceRange = $null
    $tableRange = $null
    try {
        $workbooks = $Excel.Workbooks
        $workbook = $workbooks.Add()
        Release-ComObject $workbooks
        $workbooks = $null
        Set-WorkbookWorksheetCount $workbook 3
        $worksheets = $workbook.Worksheets
        $budgetSheet = $worksheets.Item(1)
        $maintenanceSheet = $worksheets.Item(2)
        $tableSheet = $worksheets.Item(3)
        Release-ComObject $worksheets
        $worksheets = $null

        $temporarySheetSuffix = [Guid]::NewGuid().ToString("N").Substring(0, 8)
        $budgetSheet.Name = "CB5_1_$temporarySheetSuffix"
        $maintenanceSheet.Name = "CB5_2_$temporarySheetSuffix"
        $tableSheet.Name = "CB5_3_$temporarySheetSuffix"
        $budgetSheet.Name = "ORÇAMENTO"
        $maintenanceSheet.Name = "MANUTENÇÃO"
        $tableSheet.Name = "TABELA"

        $rowCount = $Items.Count + 1
        $budgetValues = New-ObjectMatrix $rowCount 10
        $budgetHeaders = @("SÉRIE", "LOTE", "VERSÃO", "REPARO", "OPERADORA1", "ICCID1", "OPERADORA2", "ICCID2", "NF DE ENTRADA", "NF DE SAÍDA")
        for ($column = 0; $column -lt 10; $column++) { $budgetValues.SetValue($budgetHeaders[$column], 0, $column) }
        for ($index = 0; $index -lt $Items.Count; $index++) {
            $item = $Items[$index]
            $row = @(
                $item.Series, $item.Lot, $item.FullVersion, $item.Repair,
                $item.Operator1, $item.Iccid1, $item.Operator2, $item.Iccid2,
                $item.EntryInvoice, $item.ExitInvoice
            )
            for ($column = 0; $column -lt 10; $column++) { $budgetValues.SetValue($row[$column], $index + 1, $column) }
        }
        $budgetRange = $budgetSheet.Range("A1", "J$rowCount")
        $budgetRange.NumberFormat = "@"
        $budgetRange.Value2 = $budgetValues
        $budgetRange.Font.Name = "Calibri"
        $budgetRange.Font.Size = 11
        Set-AllBorders $budgetRange 2
        $budgetSheet.Range("A1:J1").Interior.Color = Get-OleRgb 31 111 139
        $budgetSheet.Range("A1:J1").Font.Bold = $true
        $budgetSheet.Range("A1:J1").HorizontalAlignment = -4108
        $budgetSheet.Range("A2:D$rowCount").HorizontalAlignment = -4108
        $budgetSheet.Range("E2:H$rowCount").HorizontalAlignment = -4108
        $budgetSheet.Range("I2:J$rowCount").HorizontalAlignment = -4108
        $budgetSheet.Columns.Item("A").ColumnWidth = 10
        $budgetSheet.Columns.Item("B").ColumnWidth = 10
        $budgetSheet.Columns.Item("C").ColumnWidth = 11
        $budgetSheet.Columns.Item("D").ColumnWidth = 12
        $budgetSheet.Columns.Item("E").ColumnWidth = 26
        $budgetSheet.Columns.Item("F").ColumnWidth = 22
        $budgetSheet.Columns.Item("G").ColumnWidth = 26
        $budgetSheet.Columns.Item("H").ColumnWidth = 22
        $budgetSheet.Columns.Item("I").ColumnWidth = 16
        $budgetSheet.Columns.Item("J").ColumnWidth = 15

        $maintenanceValues = New-ObjectMatrix $rowCount 2
        $maintenanceValues.SetValue("SERIE", 0, 0)
        $maintenanceValues.SetValue("REPARO", 0, 1)
        for ($index = 0; $index -lt $Items.Count; $index++) {
            $maintenanceValues.SetValue($Items[$index].Series, $index + 1, 0)
            $maintenanceValues.SetValue(($Items[$index].MaintenanceCodes -join ", "), $index + 1, 1)
        }
        $maintenanceRange = $maintenanceSheet.Range("A1", "B$rowCount")
        $maintenanceRange.NumberFormat = "@"
        $maintenanceRange.Value2 = $maintenanceValues
        $maintenanceRange.Font.Name = "Calibri"
        $maintenanceRange.Font.Size = 11
        Set-AllBorders $maintenanceRange 2
        $maintenanceSheet.Range("A1:B1").Interior.Color = Get-OleRgb 31 111 139
        $maintenanceSheet.Range("A1:B1").Font.Bold = $true
        $maintenanceSheet.Range("A1:B1").HorizontalAlignment = -4131
        $maintenanceSheet.Range("A2:A$rowCount").HorizontalAlignment = -4108
        $maintenanceSheet.Range("B2:B$rowCount").HorizontalAlignment = -4131
        $maintenanceSheet.Columns.Item("A").ColumnWidth = 10
        $maintenanceSheet.Columns.Item("B").ColumnWidth = 52

        $definitionRows = $script:CB5MaintenanceDefinitions.Count + 1
        $tableValues = New-ObjectMatrix $definitionRows 3
        $tableValues.SetValue("CÓDIGO", 0, 0)
        $tableValues.SetValue("DESCRIÇÃO", 0, 1)
        $tableValues.SetValue("", 0, 2)
        for ($index = 0; $index -lt $script:CB5MaintenanceDefinitions.Count; $index++) {
            $definition = $script:CB5MaintenanceDefinitions[$index]
            $tableValues.SetValue($definition.Code, $index + 1, 0)
            $tableValues.SetValue($definition.Description, $index + 1, 1)
            $tableValues.SetValue($definition.Note, $index + 1, 2)
        }
        $tableRange = $tableSheet.Range("A1", "C$definitionRows")
        $tableRange.Value2 = $tableValues
        $tableRange.Font.Name = "Calibri"
        $tableRange.Font.Size = 11
        $tableSheet.Range("A1:C$definitionRows").NumberFormat = "@"
        Set-AllBorders ($tableSheet.Range("A1:B$definitionRows")) 2
        $tableSheet.Range("A1:B1").Interior.Color = Get-OleRgb 191 191 191
        $tableSheet.Range("A1:B1").Font.Bold = $true
        $tableSheet.Range("A8:B10").Interior.Color = Get-OleRgb 221 235 247
        $tableSheet.Range("A11:B16").Interior.Color = Get-OleRgb 189 215 238
        $tableSheet.Range("A17:B18").Interior.Color = Get-OleRgb 91 155 213
        $tableSheet.Columns.Item("A").ColumnWidth = 10
        $tableSheet.Columns.Item("B").ColumnWidth = 39
        $tableSheet.Columns.Item("C").ColumnWidth = 10
        $tableSheet.Range("A2:C$definitionRows").WrapText = $true

        Set-OptionalPageSetup $budgetSheet
        Set-OptionalPageSetup $maintenanceSheet
        Set-OptionalPageSetup $tableSheet
        $workbook.SaveAs($Path, 51)
        $workbook.Close($false)
    }
    finally {
        if ($null -ne $workbook) {
            try { if (-not $workbook.Saved) { $workbook.Close($false) } } catch {}
        }
        Release-ComObject $tableRange
        Release-ComObject $maintenanceRange
        Release-ComObject $budgetRange
        Release-ComObject $tableSheet
        Release-ComObject $maintenanceSheet
        Release-ComObject $budgetSheet
        Release-ComObject $worksheets
        Release-ComObject $workbook
        Release-ComObject $workbooks
    }
}

function Save-Chip1Workbook {
    param($Excel, [Collections.Generic.List[object]]$Items, [string]$Path)
    $workbooks = $null
    $workbook = $null
    $worksheets = $null
    $sheet = $null
    $range = $null
    try {
        $workbooks = $Excel.Workbooks
        $workbook = $workbooks.Add()
        Release-ComObject $workbooks
        $workbooks = $null
        Set-WorkbookWorksheetCount $workbook 1
        $worksheets = $workbook.Worksheets
        $sheet = $worksheets.Item(1)
        Release-ComObject $worksheets
        $worksheets = $null
        if ($sheet.Name -ne "Lote de manutenção") { $sheet.Name = "Lote de manutenção" }
        $values = New-ObjectMatrix $Items.Count 8
        for ($index = 0; $index -lt $Items.Count; $index++) {
            $item = $Items[$index]
            $row = @($item.Series, $item.Lot, $item.VivoVersion, "5", $item.Operator1, "S", $item.Iccid1, "0")
            for ($column = 0; $column -lt 8; $column++) { $values.SetValue($row[$column], $index, $column) }
        }
        $range = $sheet.Range("A1", "H$($Items.Count)")
        $range.NumberFormat = "@"
        $range.Value2 = $values
        $range.Font.Name = "Calibri"
        $range.Font.Size = 11
        $range.HorizontalAlignment = -4108
        $sheet.Columns.Item("A").ColumnWidth = 8.99
        $sheet.Columns.Item("B").ColumnWidth = 7.99
        $sheet.Columns.Item("C").ColumnWidth = 4.56
        $sheet.Columns.Item("D").ColumnWidth = 2.13
        $sheet.Columns.Item("E").ColumnWidth = 18.70
        $sheet.Columns.Item("F").ColumnWidth = 1.99
        $sheet.Columns.Item("G").ColumnWidth = 21.42
        $sheet.Columns.Item("H").ColumnWidth = 2.13
        $sheet.Columns.Item("I").ColumnWidth = 9.14
        Set-OptionalPageSetup $sheet
        $workbook.SaveAs($Path, 56)
        $workbook.Close($false)
    }
    finally {
        if ($null -ne $workbook) {
            try { if (-not $workbook.Saved) { $workbook.Close($false) } } catch {}
        }
        Release-ComObject $range
        Release-ComObject $sheet
        Release-ComObject $worksheets
        Release-ComObject $workbook
        Release-ComObject $workbooks
    }
}

function Save-Chip2Workbook {
    param($Excel, [Collections.Generic.List[object]]$Items, [string]$Path)
    $workbooks = $null
    $workbook = $null
    $worksheets = $null
    $sheet = $null
    $range = $null
    try {
        $workbooks = $Excel.Workbooks
        $workbook = $workbooks.Add()
        Release-ComObject $workbooks
        $workbooks = $null
        Set-WorkbookWorksheetCount $workbook 1
        $worksheets = $workbook.Worksheets
        $sheet = $worksheets.Item(1)
        Release-ComObject $worksheets
        $worksheets = $null
        if ($sheet.Name -ne "Lote de manutenção") { $sheet.Name = "Lote de manutenção" }
        $values = New-ObjectMatrix $Items.Count 3
        for ($index = 0; $index -lt $Items.Count; $index++) {
            $item = $Items[$index]
            $values.SetValue($item.Series, $index, 0)
            $values.SetValue($item.Operator2, $index, 1)
            $values.SetValue($item.Iccid2, $index, 2)
        }
        $range = $sheet.Range("A1", "C$($Items.Count)")
        $range.NumberFormat = "@"
        $range.Value2 = $values
        $range.Font.Name = "Calibri"
        $range.Font.Size = 11
        $range.HorizontalAlignment = -4108
        $sheet.Columns.Item("A").ColumnWidth = 8.99
        $sheet.Columns.Item("B").ColumnWidth = 13.56
        $sheet.Columns.Item("C").ColumnWidth = 21.42
        $sheet.Columns.Item("D").ColumnWidth = 8.85
        Set-OptionalPageSetup $sheet
        $workbook.SaveAs($Path, 56)
        $workbook.Close($false)
    }
    finally {
        if ($null -ne $workbook) {
            try { if (-not $workbook.Saved) { $workbook.Close($false) } } catch {}
        }
        Release-ComObject $range
        Release-ComObject $sheet
        Release-ComObject $worksheets
        Release-ComObject $workbook
        Release-ComObject $workbooks
    }
}

function Get-AdditionalMaintenance {
    param([System.Windows.Forms.DataGridView]$Grid)
    $result = [Collections.Generic.List[object]]::new()
    $rowOrder = 0
    foreach ($row in $Grid.Rows) {
        if ($row.IsNewRow) { continue }
        $code = [string]$row.Cells[0].Value
        $text = ([string]$row.Cells[1].Value).Trim()
        if ([string]::IsNullOrWhiteSpace($text)) {
            $rowOrder++
            continue
        }
        $quantity = 0
        if (-not [int]::TryParse($text, [ref]$quantity) -or $quantity -lt 0) {
            throw "A quantidade de $code deve ser um número inteiro igual ou maior que zero."
        }
        if ($quantity -gt 0) {
            $result.Add([pscustomobject]@{ Code = $code; Quantity = $quantity; Order = $rowOrder })
        }
        $rowOrder++
    }

    $ordered = [Collections.Generic.List[object]]::new()
    $sorted = @($result | Sort-Object -Property @{ Expression = { $_.Quantity }; Descending = $true }, @{ Expression = { $_.Order }; Ascending = $true })
    foreach ($item in $sorted) {
        $ordered.Add([pscustomobject]@{ Code = $item.Code; Quantity = $item.Quantity })
    }
    return ,$ordered
}

function Get-LotSuffix {
    param([string]$Lot)
    $lotText = Normalize-Text $Lot
    if ($lotText.Length -le 3) { return $lotText }
    return $lotText.Substring($lotText.Length - 3)
}

function Get-CB5BillingVersionFamily {
    param($MasterData)

    $families = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($item in @($MasterData.Items)) {
        $fullVersion = Normalize-Text $item.FullVersion
        $match = [regex]::Match($fullVersion, "^5\.(?<minor>[0-9]{2})(?:\.|$)")
        if (-not $match.Success) {
            throw "A versão CB5 '$fullVersion' não permite identificar a família de faturamento. Use o formato completo, como 5.22 ou 5.54.0."
        }

        $minor = [int]$match.Groups["minor"].Value
        if ($minor -le 22) {
            [void]$families.Add("5.30")
        }
        elseif ($minor -ge 52) {
            [void]$families.Add("5.40")
        }
        else {
            throw "A versão CB5 '$fullVersion' está entre 5.23 e 5.51 e ainda não possui família de faturamento definida. Confira a coluna VERSÃO."
        }
    }

    if ($families.Count -eq 0) {
        throw "Não há peças no lote CB5 para identificar a família de faturamento."
    }
    if ($families.Count -gt 1) {
        throw "O lote CB5 mistura as famílias de faturamento 5.30 e 5.40. Confira a coluna VERSÃO antes de gerar as planilhas."
    }
    return @($families)[0]
}

function Get-BillingSummary {
    param(
        [string]$Product,
        $MasterData,
        [Collections.Generic.List[object]]$Additional
    )

    $lotSuffix = Get-LotSuffix $MasterData.Lot
    $billingText = "$Product - Lote $lotSuffix - $($MasterData.Items.Count) pçs"

    if ($Product -eq "CB5") {
        $billingVersionFamily = Get-CB5BillingVersionFamily -MasterData $MasterData
        $billingText += " ($billingVersionFamily)"
        $automaticMaintenance = [Collections.Generic.List[string]]::new()
        $totalCount = $MasterData.Items.Count
        $modemCount = @($MasterData.Items | Where-Object { $_.RepairLevel -ge 1 }).Count
        $bluetoothCount = @($MasterData.Items | Where-Object { $_.RepairLevel -ge 2 }).Count
        $loraCount = @($MasterData.Items | Where-Object { $_.RepairLevel -ge 3 }).Count
        if ($modemCount -gt 0) {
            $modemText = if ($modemCount -eq $totalCount) { "MODEM 4G" } else { "$modemCount MODEM 4G" }
            $automaticMaintenance.Add($modemText)
        }
        if ($bluetoothCount -gt 0) {
            $bluetoothText = if ($bluetoothCount -eq $totalCount) { "BLUETOOTH" } else { "$bluetoothCount BLUETOOTH" }
            $automaticMaintenance.Add($bluetoothText)
        }
        if ($loraCount -gt 0) {
            $loraText = if ($loraCount -eq $totalCount) { "LORA" } else { "$loraCount LORA" }
            $automaticMaintenance.Add($loraText)
        }
        if ($automaticMaintenance.Count -gt 0) {
            $billingText += " ($($automaticMaintenance -join ' + '))"
        }
    }

    if ($Additional.Count -gt 0) { $billingText += " + MANUTENÇÃO" }
    return $billingText
}

function Apply-AdditionalMaintenance {
    param(
        [Collections.Generic.List[object]]$Items,
        [Collections.Generic.List[object]]$Additional
    )
    foreach ($extra in $Additional) {
        if ($extra.Quantity -gt $Items.Count) {
            throw "A quantidade de $($extra.Code) é $($extra.Quantity), mas o lote possui somente $($Items.Count) peças."
        }
        $definition = $script:CB5MaintenanceDefinitions | Where-Object { $_.Code -eq $extra.Code -and $null -eq $_.Level } | Select-Object -First 1
        if ($null -eq $definition) {
            throw "O código adicional CB5 '$($extra.Code)' não pertence às manutenções adicionais permitidas."
        }
        $component = (Normalize-Text ($definition.Description -replace "(?i)^TROCADO\s+", ""))
        for ($index = 0; $index -lt $extra.Quantity; $index++) {
            $item = $Items[$index]
            if ($item.MaintenanceCodes.Contains($extra.Code)) { continue }
            $item.MaintenanceCodes.Add($extra.Code)
            if ($item.LastBudgetAction -eq "TROCADO") {
                $item.Repair = "$($item.Repair), $component"
            }
            else {
                $item.Repair = "$($item.Repair), TROCADO $component"
                $item.LastBudgetAction = "TROCADO"
            }
        }
    }
}

function Apply-TV5AdditionalMaintenance {
    param(
        [Collections.Generic.List[object]]$Items,
        [Collections.Generic.List[object]]$Additional
    )
    foreach ($extra in $Additional) {
        if ($extra.Quantity -gt $Items.Count) {
            throw "A quantidade de $($extra.Code) é $($extra.Quantity), mas o lote possui somente $($Items.Count) peças."
        }
        $definition = $script:TV5MaintenanceDefinitions | Where-Object { $_.Code -eq $extra.Code } | Select-Object -First 1
        if ($null -eq $definition -or -not $definition.Additional) {
            throw "O código adicional TV5 '$($extra.Code)' não pertence às linhas adicionais permitidas da TABELA."
        }
        for ($index = 0; $index -lt $extra.Quantity; $index++) {
            $item = $Items[$index]
            if ($item.MaintenanceCodes.Contains($extra.Code)) { continue }
            $item.MaintenanceCodes.Add($extra.Code)
            if ($item.LastBudgetAction -eq $definition.BudgetAction) {
                $item.Repair = "$($item.Repair), $($definition.BudgetComponent)"
            }
            else {
                $item.Repair = "$($item.Repair), $($definition.BudgetAction) $($definition.BudgetComponent)"
                $item.LastBudgetAction = $definition.BudgetAction
            }
        }
    }
}

function Assert-ValidFilePart {
    param([string]$Text, [string]$FieldName = "valor")
    if ($Text.IndexOfAny([IO.Path]::GetInvalidFileNameChars()) -ge 0) {
        throw "O $FieldName '$Text' contém caractere inválido para nome de arquivo."
    }
}

function Get-InvoiceNumberFromFileName {
    param(
        [string]$Path,
        [ValidateSet("CB5", "TV5")][string]$Product
    )
    $baseName = [IO.Path]::GetFileNameWithoutExtension($Path)
    if ($baseName -match "\(\s*NF\s+([^\)]+?)\s*\)") {
        $invoiceNumber = $Matches[1].Trim()
    }
    else {
        throw "O nome da mestre $Product precisa conter a NF entre parênteses, por exemplo: $Product - Lote 0826982 (NF 5.225).xlsx"
    }
    if ([string]::IsNullOrWhiteSpace($invoiceNumber)) {
        throw "O número da NF não foi encontrado no nome da mestre $Product."
    }
    Assert-ValidFilePart $invoiceNumber "número da NF"
    return $invoiceNumber
}

function Get-TV5InvoiceNumberFromFileName {
    param([string]$Path)
    return Get-InvoiceNumberFromFileName $Path "TV5"
}

function Get-InvoiceComparisonKey {
    param([string]$InvoiceNumber)
    $key = (Normalize-Text $InvoiceNumber).ToUpperInvariant() -replace "[\s\.\-]", ""
    if ([string]::IsNullOrWhiteSpace($key)) {
        throw "O número da NF está vazio."
    }
    return $key
}

function Get-MasterProductFromFileName {
    param([string]$Path)
    $baseName = [IO.Path]::GetFileNameWithoutExtension($Path).Trim()
    if ($baseName -match "^(?i:TV5)(?:\s|-)" ) { return "TV5" }
    if ($baseName -match "^(?i:CB5)(?:\s|-)" ) { return "CB5" }
    return ""
}

function Assert-MasterMatchesProduct {
    param(
        [string]$Path,
        [ValidateSet("CB5", "TV5")][string]$ExpectedProduct
    )

    $extension = [IO.Path]::GetExtension($Path).ToLowerInvariant()
    if ($extension -notin @(".xlsx", ".xlsm")) {
        throw "O arquivo '$([IO.Path]::GetFileName($Path))' não é uma mestre Excel válida. Use .xlsx ou .xlsm."
    }

    $actualProduct = Get-MasterProductFromFileName $Path
    if ([string]::IsNullOrWhiteSpace($actualProduct)) {
        throw "Não foi possível identificar o produto de '$([IO.Path]::GetFileName($Path))'. O nome deve começar por CB5 ou TV5."
    }
    if ($actualProduct -ne $ExpectedProduct) {
        throw "A planilha '$([IO.Path]::GetFileName($Path))' é do $actualProduct, mas esta opção aceita somente mestres $ExpectedProduct."
    }
    [void](Get-InvoiceNumberFromFileName $Path $ExpectedProduct)
}

function Get-CombinedMaintenanceDefinitions {
    param([ValidateSet("CB5", "TV5")][string]$Product)
    if ($Product -eq "TV5") {
        return @($script:TV5MaintenanceDefinitions | Where-Object { $_.Additional })
    }
    return @($script:CB5MaintenanceDefinitions | Where-Object { $null -eq $_.Level })
}

function Get-CombinedAdditionalMaintenance {
    param(
        [System.Windows.Forms.DataGridViewRow]$Row,
        [ValidateSet("CB5", "TV5")][string]$Product
    )

    $result = [Collections.Generic.List[object]]::new()
    $definitions = @(Get-CombinedMaintenanceDefinitions $Product)
    for ($index = 0; $index -lt $definitions.Count; $index++) {
        $definition = $definitions[$index]
        $cellIndex = $index + 2
        $text = ([string]$Row.Cells[$cellIndex].Value).Trim()
        if ([string]::IsNullOrWhiteSpace($text)) { continue }
        $quantity = 0
        if (-not [int]::TryParse($text, [ref]$quantity) -or $quantity -lt 0) {
            throw "A quantidade de $($definition.Code) na planilha '$($Row.Cells[1].Value)' deve ser um número inteiro igual ou maior que zero."
        }
        if ($quantity -gt 0) {
            $result.Add([pscustomobject]@{ Code = $definition.Code; Quantity = $quantity; Order = $index })
        }
    }

    $ordered = [Collections.Generic.List[object]]::new()
    $sorted = @($result | Sort-Object -Property @{ Expression = { $_.Quantity }; Descending = $true }, @{ Expression = { $_.Order }; Ascending = $true })
    foreach ($item in $sorted) {
        $ordered.Add([pscustomobject]@{ Code = $item.Code; Quantity = $item.Quantity })
    }
    return ,$ordered
}

function Get-RepairSnapshot {
    param([Parameter(Mandatory = $true)][object[]]$Items)
    $snapshot = @{}
    foreach ($item in @($Items)) {
        $snapshot[[string]$item.Series] = [string]$item.Repair
    }
    return $snapshot
}

function Get-RepairPreviewRows {
    param(
        [Parameter(Mandatory = $true)][object[]]$Items,
        [Parameter(Mandatory = $true)][hashtable]$OriginalRepairs
    )
    $rows = [Collections.Generic.List[object]]::new()
    foreach ($item in @($Items)) {
        $series = [string]$item.Series
        $before = if ($OriginalRepairs.ContainsKey($series)) { [string]$OriginalRepairs[$series] } else { "" }
        $after = [string]$item.Repair
        if (-not [string]::Equals($before, $after, [StringComparison]::Ordinal)) {
            $rows.Add([pscustomobject]@{ Serie = $series; Antes = $before; Depois = $after })
        }
    }
    return $rows.ToArray()
}

$script:SettingsDirectory = [IO.Path]::Combine([Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData), "GeradorPlanilhasCB5TV5")
$script:SettingsPath = [IO.Path]::Combine($script:SettingsDirectory, "preferencias.json")
$script:BillingComponentStorePath = Initialize-BillingComponentStore -DataDirectory $script:SettingsDirectory
$script:BillingComponentStore = Read-BillingComponentStore -Path $script:BillingComponentStorePath
$script:LastOutputDirectory = ""
$script:LastInputDirectory = ""
$script:CopiedCombinedQuantities = $null
$script:UiReady = $false
$script:CurrentPalette = $null

function Get-AppSettings {
    $settings = [pscustomobject]@{ Theme = "Claro moderno"; Product = "CB5"; LastInputDirectory = "" }
    try {
        if ([IO.File]::Exists($script:SettingsPath)) {
            $saved = Get-Content -LiteralPath $script:SettingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
            if (@("Claro moderno", "Escuro grafite", "Técnico industrial", "Alto contraste") -contains [string]$saved.Theme) {
                $settings.Theme = [string]$saved.Theme
            }
            if (@("CB5", "TV5") -contains [string]$saved.Product) {
                $settings.Product = [string]$saved.Product
            }
            if ($saved.PSObject.Properties.Name -contains "LastInputDirectory" -and [IO.Directory]::Exists([string]$saved.LastInputDirectory)) {
                $settings.LastInputDirectory = [string]$saved.LastInputDirectory
            }
        }
    }
    catch {}
    return $settings
}

function Save-AppSettings {
    try {
        if (-not [IO.Directory]::Exists($script:SettingsDirectory)) {
            [void][IO.Directory]::CreateDirectory($script:SettingsDirectory)
        }
        [pscustomobject]@{
            Theme = [string]$themeCombo.SelectedItem
            Product = [string]$productCombo.SelectedItem
            LastInputDirectory = [string]$script:LastInputDirectory
        } | ConvertTo-Json | Set-Content -LiteralPath $script:SettingsPath -Encoding UTF8
    }
    catch {}
}

function Get-DialogInitialDirectory {
    if (-not [string]::IsNullOrWhiteSpace($script:LastInputDirectory) -and [IO.Directory]::Exists($script:LastInputDirectory)) {
        return $script:LastInputDirectory
    }
    return [Environment]::GetFolderPath([Environment+SpecialFolder]::DesktopDirectory)
}

function Remember-InputPath {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return }
    $directory = if ([IO.Directory]::Exists($Path)) { $Path } else { [IO.Path]::GetDirectoryName($Path) }
    if (-not [string]::IsNullOrWhiteSpace($directory) -and [IO.Directory]::Exists($directory)) {
        $script:LastInputDirectory = $directory
        if ($script:UiReady) { Save-AppSettings }
    }
}

function Copy-ResultText {
    param([string]$Text, [string]$Title = "Copiar resultado")
    if ([string]::IsNullOrWhiteSpace($Text)) {
        [Windows.Forms.MessageBox]::Show("Ainda não há resultado para copiar.", $Title, "OK", "Information") | Out-Null
        return
    }
    try {
        [Windows.Forms.Clipboard]::SetText($Text)
        Set-UiProgress $progressBar.Value "Resultado copiado" "Success"
    }
    catch {
        [Windows.Forms.MessageBox]::Show("Não foi possível copiar o resultado.`r`n$($_.Exception.Message)", $Title, "OK", "Error") | Out-Null
    }
}

function Get-ThemePalette {
    param(
        [string]$Theme,
        [ValidateSet("CB5", "TV5")][string]$Product
    )

    $accent = if ($Product -eq "TV5") { [Drawing.Color]::FromArgb(5, 150, 105) } else { [Drawing.Color]::FromArgb(37, 99, 235) }
    switch ($Theme) {
        "Escuro grafite" {
            $accent = if ($Product -eq "TV5") { [Drawing.Color]::FromArgb(52, 211, 153) } else { [Drawing.Color]::FromArgb(96, 165, 250) }
            return [pscustomobject]@{
                Background = [Drawing.Color]::FromArgb(15, 23, 42)
                Surface = [Drawing.Color]::FromArgb(30, 41, 59)
                Panel = [Drawing.Color]::FromArgb(22, 32, 50)
                Input = [Drawing.Color]::FromArgb(15, 23, 42)
                Text = [Drawing.Color]::FromArgb(248, 250, 252)
                Muted = [Drawing.Color]::FromArgb(203, 213, 225)
                Border = [Drawing.Color]::FromArgb(71, 85, 105)
                Accent = $accent
                AccentText = [Drawing.Color]::FromArgb(15, 23, 42)
                Info = [Drawing.Color]::FromArgb(30, 58, 88)
                Quantity = [Drawing.Color]::FromArgb(78, 65, 23)
                SelectedRow = [Drawing.Color]::FromArgb(55, 65, 81)
                SelectedQuantity = [Drawing.Color]::FromArgb(113, 83, 20)
                Invalid = [Drawing.Color]::FromArgb(127, 29, 29)
                Success = [Drawing.Color]::FromArgb(74, 222, 128)
                Error = [Drawing.Color]::FromArgb(248, 113, 113)
                Warning = [Drawing.Color]::FromArgb(251, 191, 36)
            }
        }
        "Técnico industrial" {
            $accent = if ($Product -eq "TV5") { [Drawing.Color]::FromArgb(72, 202, 143) } else { [Drawing.Color]::FromArgb(44, 189, 197) }
            return [pscustomobject]@{
                Background = [Drawing.Color]::FromArgb(18, 23, 25)
                Surface = [Drawing.Color]::FromArgb(27, 35, 38)
                Panel = [Drawing.Color]::FromArgb(34, 43, 46)
                Input = [Drawing.Color]::FromArgb(18, 23, 25)
                Text = [Drawing.Color]::FromArgb(242, 246, 245)
                Muted = [Drawing.Color]::FromArgb(174, 188, 186)
                Border = [Drawing.Color]::FromArgb(62, 77, 80)
                Accent = $accent
                AccentText = [Drawing.Color]::FromArgb(9, 24, 28)
                Info = [Drawing.Color]::FromArgb(27, 55, 59)
                Quantity = [Drawing.Color]::FromArgb(86, 59, 13)
                SelectedRow = [Drawing.Color]::FromArgb(39, 55, 57)
                SelectedQuantity = [Drawing.Color]::FromArgb(112, 75, 18)
                Invalid = [Drawing.Color]::FromArgb(78, 28, 26)
                Success = [Drawing.Color]::FromArgb(72, 202, 143)
                Error = [Drawing.Color]::FromArgb(239, 108, 102)
                Warning = [Drawing.Color]::FromArgb(246, 186, 68)
            }
        }
        "Alto contraste" {
            return [pscustomobject]@{
                Background = [Drawing.Color]::Black
                Surface = [Drawing.Color]::Black
                Panel = [Drawing.Color]::FromArgb(18, 18, 18)
                Input = [Drawing.Color]::Black
                Text = [Drawing.Color]::White
                Muted = [Drawing.Color]::FromArgb(255, 235, 59)
                Border = [Drawing.Color]::White
                Accent = [Drawing.Color]::FromArgb(255, 214, 0)
                AccentText = [Drawing.Color]::Black
                Info = [Drawing.Color]::FromArgb(28, 28, 28)
                Quantity = [Drawing.Color]::FromArgb(75, 65, 0)
                SelectedRow = [Drawing.Color]::FromArgb(45, 45, 45)
                SelectedQuantity = [Drawing.Color]::FromArgb(122, 100, 0)
                Invalid = [Drawing.Color]::FromArgb(92, 0, 0)
                Success = [Drawing.Color]::Lime
                Error = [Drawing.Color]::FromArgb(255, 82, 82)
                Warning = [Drawing.Color]::Yellow
            }
        }
        default {
            return [pscustomobject]@{
                Background = [Drawing.Color]::FromArgb(241, 245, 249)
                Surface = [Drawing.Color]::White
                Panel = [Drawing.Color]::FromArgb(248, 250, 252)
                Input = [Drawing.Color]::White
                Text = [Drawing.Color]::FromArgb(15, 23, 42)
                Muted = [Drawing.Color]::FromArgb(71, 85, 105)
                Border = [Drawing.Color]::FromArgb(203, 213, 225)
                Accent = $accent
                AccentText = [Drawing.Color]::White
                Info = [Drawing.Color]::FromArgb(239, 246, 255)
                Quantity = [Drawing.Color]::FromArgb(254, 249, 195)
                SelectedRow = [Drawing.Color]::FromArgb(240, 253, 250)
                SelectedQuantity = [Drawing.Color]::FromArgb(253, 230, 138)
                Invalid = [Drawing.Color]::FromArgb(254, 226, 226)
                Success = [Drawing.Color]::FromArgb(21, 128, 61)
                Error = [Drawing.Color]::FromArgb(185, 28, 28)
                Warning = [Drawing.Color]::FromArgb(180, 83, 9)
            }
        }
    }
}

function Get-GeneratorThemeFromHost {
    param([string]$Theme)
    switch ($Theme) {
        "Escuro profissional" { return "Escuro grafite" }
        "Técnico industrial" { return "Técnico industrial" }
        "Claro corporativo" { return "Claro moderno" }
        "Alto contraste" { return "Alto contraste" }
        default { return "Escuro grafite" }
    }
}

function Set-HostedGeneratorTheme {
    param([string]$CentralTheme)
    if (-not $script:IsInProcessHosted) { return }
    $mapped = Get-GeneratorThemeFromHost $CentralTheme
    try {
        if ($themeCombo.Items.Contains($mapped)) { $themeCombo.SelectedItem = $mapped }
        else { $themeCombo.SelectedItem = "Escuro grafite" }
        Apply-AppTheme
        Update-GeneratorResponsiveLayout
        Update-RootLayout
    } catch {}
}

function New-AppLogoBitmap {
    param([Drawing.Color]$Accent, [int]$Size = 48)
    $bitmap = New-Object Drawing.Bitmap($Size, $Size)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.Clear([Drawing.Color]::Transparent)
    $accentBrush = New-Object Drawing.SolidBrush($Accent)
    $whiteBrush = New-Object Drawing.SolidBrush([Drawing.Color]::White)
    $gridPen = New-Object Drawing.Pen([Drawing.Color]::FromArgb(210, 255, 255, 255), 1)
    try {
        $graphics.FillRectangle($accentBrush, 4, 4, ($Size - 8), ($Size - 8))
        $graphics.FillRectangle($whiteBrush, 12, 11, ($Size - 24), 6)
        for ($line = 0; $line -lt 3; $line++) {
            $position = 12 + ($line * 8)
            $graphics.DrawLine($gridPen, 12, $position + 10, ($Size - 12), $position + 10)
            $graphics.DrawLine($gridPen, $position, 19, $position, ($Size - 12))
        }
    }
    finally {
        $gridPen.Dispose()
        $whiteBrush.Dispose()
        $accentBrush.Dispose()
        $graphics.Dispose()
    }
    return $bitmap
}

function Set-GeneratorRoundedRegion {
    param([Windows.Forms.Control]$Control, [int]$Radius = 10)
    if ($null -eq $Control -or $Control.Width -le 2 -or $Control.Height -le 2) { return }
    try {
        $diameter = [Math]::Max(2, $Radius * 2)
        $rect = [Drawing.Rectangle]::new(0, 0, $Control.Width - 1, $Control.Height - 1)
        $path = New-Object Drawing.Drawing2D.GraphicsPath
        $path.AddArc($rect.Left, $rect.Top, $diameter, $diameter, 180, 90)
        $path.AddArc($rect.Right - $diameter, $rect.Top, $diameter, $diameter, 270, 90)
        $path.AddArc($rect.Right - $diameter, $rect.Bottom - $diameter, $diameter, $diameter, 0, 90)
        $path.AddArc($rect.Left, $rect.Bottom - $diameter, $diameter, $diameter, 90, 90)
        $path.CloseFigure()
        $oldRegion = $Control.Region
        $Control.Region = New-Object Drawing.Region($path)
        $path.Dispose()
        if ($null -ne $oldRegion) { $oldRegion.Dispose() }
    } catch {}
}

function Set-ButtonTheme {
    param($Button, $Palette)
    $Button.FlatStyle = [Windows.Forms.FlatStyle]::Flat
    $Button.FlatAppearance.BorderSize = 1
    $role = [string]$Button.Tag
    if ($role -eq "Primary") {
        $Button.BackColor = $Palette.Accent
        $Button.ForeColor = $Palette.AccentText
        $Button.FlatAppearance.BorderColor = $Palette.Accent
    }
    else {
        $Button.BackColor = $Palette.Surface
        $Button.ForeColor = $Palette.Text
        $Button.FlatAppearance.BorderColor = $Palette.Border
    }
}

function Set-GridTheme {
    param($Grid, $Palette)
    if ($null -eq $Grid -or $null -eq $Palette) { return }
    try { if ($Grid.IsDisposed -or $Grid.Disposing) { return } } catch { return }
    $Grid.EnableHeadersVisualStyles = $false
    $Grid.BackgroundColor = $Palette.Surface
    try { $Grid.GridColor = $Palette.Border } catch {}
    $Grid.BorderStyle = [Windows.Forms.BorderStyle]::FixedSingle
    $Grid.ColumnHeadersBorderStyle = [Windows.Forms.DataGridViewHeaderBorderStyle]::Single
    $Grid.ColumnHeadersDefaultCellStyle.BackColor = $Palette.Panel
    $Grid.ColumnHeadersDefaultCellStyle.ForeColor = $Palette.Text
    $Grid.ColumnHeadersDefaultCellStyle.SelectionBackColor = $Palette.Panel
    $Grid.ColumnHeadersDefaultCellStyle.SelectionForeColor = $Palette.Text
    $Grid.ColumnHeadersDefaultCellStyle.Font = New-Object Drawing.Font("Segoe UI Semibold", 9.5)
    $Grid.DefaultCellStyle.BackColor = $Palette.Surface
    $Grid.DefaultCellStyle.ForeColor = $Palette.Text
    $Grid.DefaultCellStyle.SelectionBackColor = $Palette.Accent
    $Grid.DefaultCellStyle.SelectionForeColor = $Palette.AccentText
    $Grid.AlternatingRowsDefaultCellStyle.BackColor = $Palette.Panel
    $Grid.RowTemplate.Height = 28
    $Grid.AllowUserToResizeColumns = $true
    $Grid.ScrollBars = [Windows.Forms.ScrollBars]::Both
}

function Set-GridColumnWidth {
    param(
        [Windows.Forms.DataGridView]$Grid,
        [string]$Name,
        [int]$Width = 100,
        [ValidateSet("Fixed", "Fill")][string]$Sizing = "Fixed",
        [int]$MinimumWidth = 45
    )

    $column = $Grid.Columns[$Name]
    if ($null -eq $column) { throw "Coluna não encontrada: $Name" }

    $column.MinimumWidth = [Math]::Max(20, $MinimumWidth)
    if ($Sizing -eq "Fill") {
        $column.FillWeight = [Math]::Max(1, $Width)
        $column.AutoSizeMode = [Windows.Forms.DataGridViewAutoSizeColumnMode]::Fill
    }
    else {
        $column.AutoSizeMode = [Windows.Forms.DataGridViewAutoSizeColumnMode]::None
        $column.Width = [Math]::Max($column.MinimumWidth, $Width)
    }
}

function Set-UiProgress {
    param(
        [int]$Percent,
        [string]$Message,
        [ValidateSet("Normal", "Success", "Error", "Warning")][string]$State = "Normal"
    )
    $safePercent = [Math]::Max(0, [Math]::Min(100, $Percent))
    $progressBar.Value = $safePercent
    $progressStatusLabel.Text = $Message
    switch ($State) {
        "Success" { $progressStatusLabel.ForeColor = $script:CurrentPalette.Success }
        "Error" { $progressStatusLabel.ForeColor = $script:CurrentPalette.Error }
        "Warning" { $progressStatusLabel.ForeColor = $script:CurrentPalette.Warning }
        default { $progressStatusLabel.ForeColor = $script:CurrentPalette.Muted }
    }
}

function Get-LiveAdditionalItems {
    $items = [Collections.Generic.List[string]]::new()
    foreach ($row in $extraGrid.Rows) {
        $quantity = 0
        $text = ([string]$row.Cells[1].Value).Trim()
        if ([int]::TryParse($text, [ref]$quantity) -and $quantity -gt 0) {
            $items.Add("$quantity $($row.Cells[0].Value)")
        }
    }
    return $items.ToArray()
}

function Update-ExtraGridHighlights {
    if ($null -eq $script:CurrentPalette) { return }
    foreach ($row in $extraGrid.Rows) {
        $quantity = 0
        $text = ([string]$row.Cells[1].Value).Trim()
        $parsed = [int]::TryParse($text, [ref]$quantity)
        $invalid = -not [string]::IsNullOrWhiteSpace($text) -and (-not $parsed -or $quantity -lt 0)
        $active = $parsed -and $quantity -gt 0
        for ($column = 0; $column -lt $row.Cells.Count; $column++) {
            $row.Cells[$column].Style.BackColor = if ($active) { $script:CurrentPalette.SelectedRow } else { $script:CurrentPalette.Surface }
            $row.Cells[$column].Style.ForeColor = $script:CurrentPalette.Text
        }
        $row.Cells[1].Style.BackColor = if ($invalid) { $script:CurrentPalette.Invalid } elseif ($active) { $script:CurrentPalette.SelectedQuantity } else { $script:CurrentPalette.Quantity }
        if ($invalid) { $row.Cells[1].Style.ForeColor = $script:CurrentPalette.Error }
    }
}

function Update-CombineGridHighlights {
    if ($null -eq $script:CurrentPalette) { return }
    foreach ($row in $combineGrid.Rows) {
        $activeCount = 0
        for ($column = 2; $column -lt $row.Cells.Count; $column++) {
            $quantity = 0
            if ([int]::TryParse(([string]$row.Cells[$column].Value).Trim(), [ref]$quantity) -and $quantity -gt 0) { $activeCount++ }
        }
        for ($column = 0; $column -lt $row.Cells.Count; $column++) {
            $row.Cells[$column].Style.BackColor = if ($activeCount -gt 0) { $script:CurrentPalette.SelectedRow } else { $script:CurrentPalette.Surface }
            $row.Cells[$column].Style.ForeColor = $script:CurrentPalette.Text
        }
        for ($column = 2; $column -lt $row.Cells.Count; $column++) {
            $quantity = 0
            $text = ([string]$row.Cells[$column].Value).Trim()
            $parsed = [int]::TryParse($text, [ref]$quantity)
            $invalid = -not [string]::IsNullOrWhiteSpace($text) -and (-not $parsed -or $quantity -lt 0)
            $active = $parsed -and $quantity -gt 0
            $row.Cells[$column].Style.BackColor = if ($invalid) { $script:CurrentPalette.Invalid } elseif ($active) { $script:CurrentPalette.SelectedQuantity } else { $script:CurrentPalette.Quantity }
            if ($invalid) { $row.Cells[$column].Style.ForeColor = $script:CurrentPalette.Error }
        }
    }
}

function Update-LiveSummary {
    if ($null -eq $masterSummaryLabel) { return }
    $fileName = if ([string]::IsNullOrWhiteSpace($masterText.Text)) { "Nenhuma mestre selecionada" } else { [IO.Path]::GetFileName($masterText.Text) }
    $items = @(Get-LiveAdditionalItems)
    $hasInvalid = $false
    foreach ($row in $extraGrid.Rows) {
        $quantity = 0
        $text = ([string]$row.Cells[1].Value).Trim()
        if (-not [string]::IsNullOrWhiteSpace($text) -and (-not [int]::TryParse($text, [ref]$quantity) -or $quantity -lt 0)) { $hasInvalid = $true }
    }
    $extrasText = if ($items.Count -gt 0) { $items -join "  •  " } else { "Nenhuma manutenção adicional" }
    $masterSummaryLabel.Text = $fileName
    $extrasSummaryLabel.Text = $extrasText
    $masterEffectLabel.Text = if ($hasInvalid) { "Corrija a quantidade em vermelho" } elseif ($items.Count -gt 0) { "A mestre será atualizada" } else { "A mestre permanecerá intacta" }
    if ($null -ne $script:CurrentPalette) {
        $masterEffectLabel.ForeColor = if ($hasInvalid) { $script:CurrentPalette.Error } elseif ($items.Count -gt 0) { $script:CurrentPalette.Warning } else { $script:CurrentPalette.Success }
    }
    $extraSelectionLabel.Text = $extrasText
    Update-ExtraGridHighlights
}

function Update-CombineSummary {
    $withMaintenance = 0
    $invalidFields = 0
    foreach ($row in $combineGrid.Rows) {
        $rowHasMaintenance = $false
        for ($column = 2; $column -lt $row.Cells.Count; $column++) {
            $quantity = 0
            $text = ([string]$row.Cells[$column].Value).Trim()
            $parsed = [int]::TryParse($text, [ref]$quantity)
            if (-not [string]::IsNullOrWhiteSpace($text) -and (-not $parsed -or $quantity -lt 0)) { $invalidFields++ }
            if ($parsed -and $quantity -gt 0) {
                $rowHasMaintenance = $true
            }
        }
        if ($rowHasMaintenance) { $withMaintenance++ }
    }
    $invalidText = if ($invalidFields -gt 0) { "  •  $invalidFields quantidade(s) inválida(s)" } else { "" }
    $balanceText = if ($combineConsumeBalanceCheck.Checked) { "consumir saldo" } else { "não consumir saldo" }
    $combineSelectionLabel.Text = "$($combineGrid.Rows.Count) lote(s) selecionado(s)  •  $withMaintenance mestre(s) serão atualizadas  •  $balanceText$invalidText"
    $combineBalanceStatus.Text = if ($combineConsumeBalanceCheck.Checked) { "SALDO: SERÁ CONSUMIDO" } else { "SALDO: NÃO SERÁ CONSUMIDO" }
    if ($null -ne $script:CurrentPalette) {
        $combineSelectionLabel.ForeColor = if ($invalidFields -gt 0) { $script:CurrentPalette.Error } else { $script:CurrentPalette.Text }
        $combineBalanceStatus.ForeColor = if ($combineConsumeBalanceCheck.Checked) { $script:CurrentPalette.Warning } else { $script:CurrentPalette.Success }
        $combineBalanceCard.BackColor = $script:CurrentPalette.Surface
        Update-CombineGridHighlights
    }
}

function Get-SelectedBillingComponent {
    if ($null -eq $componentGrid.CurrentRow) { return $null }
    $id = [string]$componentGrid.CurrentRow.Tag
    if ([string]::IsNullOrWhiteSpace($id)) { return $null }
    return Get-BillingComponentById $script:BillingComponentStore $id
}

function Update-BillingComponentsView {
    $selectedId = ""
    if ($null -ne $componentGrid.CurrentRow) { $selectedId = [string]$componentGrid.CurrentRow.Tag }
    $componentGrid.Rows.Clear()
    $componentHistoryGrid.Rows.Clear()
    $componentOperationsGrid.Rows.Clear()
    $product = $script:CurrentProduct
    $allComponents = @(Get-BillingComponents $script:BillingComponentStore $product -IncludeInactive)
    $searchText = if ($null -ne $componentSearchText) { [string]$componentSearchText.Text } else { "" }
    $components = @($allComponents | Where-Object { Test-BillingComponentMatchesSearch $_ $searchText })
    foreach ($component in $components) {
        $balance = ConvertTo-BillingInteger $component.Saldo
        $active = ConvertTo-BillingBoolean $component.Ativo
        $rowIndex = $componentGrid.Rows.Add(
            [string]$component.Componente,
            [string]$component.Nome,
            $balance,
            [string]$component.CodigoPlanilha,
            [string]$component.TextoReparo,
            $(if ($active) { "Ativo" } else { "Inativo" })
        )
        $row = $componentGrid.Rows[$rowIndex]
        $row.Tag = [string]$component.Id
        $row.Cells[0].ToolTipText = "Apelidos: " + (@($component.Apelidos) -join ", ")
        if (-not $active -and $null -ne $script:CurrentPalette) {
            $row.DefaultCellStyle.ForeColor = $script:CurrentPalette.Muted
        }
        if ([string]$component.Id -eq $selectedId) { $componentGrid.CurrentCell = $row.Cells[0] }
    }
    if ($componentGrid.Rows.Count -gt 0 -and $null -eq $componentGrid.CurrentCell) {
        $componentGrid.CurrentCell = $componentGrid.Rows[0].Cells[0]
    }
    $dashboard = Get-BillingDashboardSummary $script:BillingComponentStore $product
    $componentActiveValue.Text = [string]$dashboard.Ativos
    $componentPendingValue.Text = [string]$dashboard.UnidadesPendentes
    $componentOperationsValue.Text = [string]$dashboard.UnioesProcessadas
    $componentsSummaryLabel.Text = if ([string]::IsNullOrWhiteSpace($searchText) -and $components.Count -eq 0) {
        "Nenhum componente a faturar cadastrado."
    }
    elseif ([string]::IsNullOrWhiteSpace($searchText)) {
        "$($components.Count) componente(s) exibido(s)"
    }
    elseif ($components.Count -eq 0) {
        "Nenhum componente encontrado."
    }
    else {
        "$($components.Count) de $($dashboard.Componentes) componente(s) encontrado(s)"
    }

    foreach ($movement in @(Get-BillingMovementRows $script:BillingComponentStore $product 250)) {
        $when = [string]$movement.Em
        $parsedDate = [DateTime]::MinValue
        if ([DateTime]::TryParse($when, [ref]$parsedDate)) { $when = $parsedDate.ToString("dd/MM/yyyy HH:mm") }
        $change = ConvertTo-BillingInteger $movement.Variacao
        $changeText = if ($change -gt 0) { "+$change" } else { [string]$change }
        $lotsText = @($movement.Lotes) -join ", "
        [void]$componentHistoryGrid.Rows.Add(
            $when,
            [string]$movement.Componente,
            [string]$movement.Tipo,
            $changeText,
            "$($movement.SaldoAnterior) → $($movement.SaldoPosterior)",
            [string]$movement.NF,
            $lotsText,
            [string]$movement.Observacao
        )
    }

    foreach ($operation in @(Get-BillingOperationRows $script:BillingComponentStore $product 250)) {
        $when = [string]$operation.Em
        $parsedDate = [DateTime]::MinValue
        if ([DateTime]::TryParse($when, [ref]$parsedDate)) { $when = $parsedDate.ToString("dd/MM/yyyy HH:mm") }
        [void]$componentOperationsGrid.Rows.Add(
            $when,
            [string]$operation.NF,
            (@($operation.Lotes) -join ", "),
            (ConvertTo-BillingInteger $operation.QuantidadeTotal),
            (Get-BillingOperationDetailText $operation)
        )
    }
}

function Show-BillingQuantityDialog {
    param(
        [Parameter(Mandatory = $true)][object]$Component,
        [switch]$SetExactBalance
    )
    $dialog = New-Object Windows.Forms.Form
    $dialog.Text = if ($SetExactBalance) { "Ajustar saldo a faturar" } else { "Lançar quantidade usada" }
    $dialog.StartPosition = "CenterParent"
    $dialog.FormBorderStyle = "FixedDialog"
    $dialog.MaximizeBox = $false
    $dialog.MinimizeBox = $false
    $dialog.ShowInTaskbar = $false
    $dialog.ClientSize = New-Object Drawing.Size(470, 270)
    $dialog.BackColor = $script:CurrentPalette.Surface
    $dialog.ForeColor = $script:CurrentPalette.Text

    $componentLabel = New-Object Windows.Forms.Label
    $componentLabel.Text = "$($Component.Produto) $($Component.Componente) — $($Component.Nome)"
    $componentLabel.Font = New-Object Drawing.Font("Segoe UI Semibold", 11)
    $componentLabel.Location = New-Object Drawing.Point(20, 18)
    $componentLabel.Size = New-Object Drawing.Size(430, 25)
    $dialog.Controls.Add($componentLabel)

    $currentLabel = New-Object Windows.Forms.Label
    $currentLabel.Text = "Saldo atual a faturar: $($Component.Saldo)"
    $currentLabel.Location = New-Object Drawing.Point(20, 50)
    $currentLabel.Size = New-Object Drawing.Size(430, 22)
    $currentLabel.ForeColor = $script:CurrentPalette.Muted
    $dialog.Controls.Add($currentLabel)

    $quantityLabel = New-Object Windows.Forms.Label
    $quantityLabel.Text = if ($SetExactBalance) { "Novo saldo exato" } else { "Quantidade usada para acrescentar" }
    $quantityLabel.Location = New-Object Drawing.Point(20, 82)
    $quantityLabel.AutoSize = $true
    $dialog.Controls.Add($quantityLabel)

    $quantityControl = New-Object Windows.Forms.NumericUpDown
    $quantityControl.Location = New-Object Drawing.Point(20, 105)
    $quantityControl.Size = New-Object Drawing.Size(150, 28)
    $quantityControl.Minimum = if ($SetExactBalance) { 0 } else { 1 }
    $quantityControl.Maximum = 1000000
    $quantityControl.Value = if ($SetExactBalance) { [decimal](ConvertTo-BillingInteger $Component.Saldo) } else { 1 }
    $quantityControl.BackColor = $script:CurrentPalette.Input
    $quantityControl.ForeColor = $script:CurrentPalette.Text
    $dialog.Controls.Add($quantityControl)

    $observationLabel = New-Object Windows.Forms.Label
    $observationLabel.Text = "Observação (opcional)"
    $observationLabel.Location = New-Object Drawing.Point(20, 145)
    $observationLabel.AutoSize = $true
    $dialog.Controls.Add($observationLabel)

    $observationText = New-Object Windows.Forms.TextBox
    $observationText.Location = New-Object Drawing.Point(20, 168)
    $observationText.Size = New-Object Drawing.Size(430, 27)
    $observationText.BackColor = $script:CurrentPalette.Input
    $observationText.ForeColor = $script:CurrentPalette.Text
    $dialog.Controls.Add($observationText)

    $cancelButton = New-Object Windows.Forms.Button
    $cancelButton.Text = "Cancelar"
    $cancelButton.Location = New-Object Drawing.Point(250, 218)
    $cancelButton.Size = New-Object Drawing.Size(95, 34)
    $cancelButton.DialogResult = [Windows.Forms.DialogResult]::Cancel
    $cancelButton.Tag = "Secondary"
    Set-ButtonTheme $cancelButton $script:CurrentPalette
    $dialog.Controls.Add($cancelButton)

    $okButton = New-Object Windows.Forms.Button
    $okButton.Text = if ($SetExactBalance) { "Salvar ajuste" } else { "Lançar"
    }
    $okButton.Location = New-Object Drawing.Point(355, 218)
    $okButton.Size = New-Object Drawing.Size(95, 34)
    $okButton.Tag = "Primary"
    Set-ButtonTheme $okButton $script:CurrentPalette
    $dialog.Controls.Add($okButton)
    $dialog.AcceptButton = $okButton
    $dialog.CancelButton = $cancelButton

    $okButton.Add_Click({
        $dialog.Tag = [pscustomobject]@{
            Quantity = [int]$quantityControl.Value
            Observation = $observationText.Text.Trim()
        }
        $dialog.DialogResult = [Windows.Forms.DialogResult]::OK
        $dialog.Close()
    })
    if ($dialog.ShowDialog($form) -eq [Windows.Forms.DialogResult]::OK) { return $dialog.Tag }
    return $null
}

function Show-BillingComponentDialog {
    param(
        [ValidateSet("CB5", "TV5")][string]$DefaultProduct,
        [AllowNull()][object]$ExistingComponent
    )
    $editing = $null -ne $ExistingComponent
    $dialog = New-Object Windows.Forms.Form
    $dialog.Text = if ($editing) { "Editar componente" } else { "Novo componente a faturar" }
    $dialog.StartPosition = "CenterParent"
    $dialog.FormBorderStyle = "FixedDialog"
    $dialog.MaximizeBox = $false
    $dialog.MinimizeBox = $false
    $dialog.ShowInTaskbar = $false
    $dialog.ClientSize = New-Object Drawing.Size(610, 500)
    $dialog.BackColor = $script:CurrentPalette.Surface
    $dialog.ForeColor = $script:CurrentPalette.Text

    $productDialogLabel = New-Object Windows.Forms.Label
    $productDialogLabel.Text = "Produto"
    $productDialogLabel.Location = New-Object Drawing.Point(20, 17)
    $productDialogLabel.AutoSize = $true
    $dialog.Controls.Add($productDialogLabel)
    $productDialogCombo = New-Object Windows.Forms.ComboBox
    $productDialogCombo.Location = New-Object Drawing.Point(20, 40)
    $productDialogCombo.Size = New-Object Drawing.Size(160, 28)
    $productDialogCombo.DropDownStyle = "DropDownList"
    [void]$productDialogCombo.Items.Add("CB5")
    [void]$productDialogCombo.Items.Add("TV5")
    $productDialogCombo.SelectedItem = if ($editing) { [string]$ExistingComponent.Produto } else { $DefaultProduct }
    $productDialogCombo.Enabled = -not $editing
    $dialog.Controls.Add($productDialogCombo)

    $componentDialogLabel = New-Object Windows.Forms.Label
    $componentDialogLabel.Text = "Componente / designador"
    $componentDialogLabel.Location = New-Object Drawing.Point(200, 17)
    $componentDialogLabel.AutoSize = $true
    $dialog.Controls.Add($componentDialogLabel)
    $componentDialogText = New-Object Windows.Forms.TextBox
    $componentDialogText.Location = New-Object Drawing.Point(200, 40)
    $componentDialogText.Size = New-Object Drawing.Size(175, 27)
    $componentDialogText.Text = if ($editing) { [string]$ExistingComponent.Componente } else { "" }
    $componentDialogText.Enabled = -not $editing
    $dialog.Controls.Add($componentDialogText)

    $initialBalanceLabel = New-Object Windows.Forms.Label
    $initialBalanceLabel.Text = "Saldo inicial"
    $initialBalanceLabel.Location = New-Object Drawing.Point(395, 17)
    $initialBalanceLabel.AutoSize = $true
    $dialog.Controls.Add($initialBalanceLabel)
    $initialBalanceControl = New-Object Windows.Forms.NumericUpDown
    $initialBalanceControl.Location = New-Object Drawing.Point(395, 40)
    $initialBalanceControl.Size = New-Object Drawing.Size(195, 28)
    $initialBalanceControl.Minimum = 0
    $initialBalanceControl.Maximum = 1000000
    $initialBalanceControl.Value = if ($editing) { [decimal](ConvertTo-BillingInteger $ExistingComponent.Saldo) } else { 0 }
    $initialBalanceControl.Enabled = -not $editing
    $dialog.Controls.Add($initialBalanceControl)

    $nameDialogLabel = New-Object Windows.Forms.Label
    $nameDialogLabel.Text = "Nome do componente"
    $nameDialogLabel.Location = New-Object Drawing.Point(20, 84)
    $nameDialogLabel.AutoSize = $true
    $dialog.Controls.Add($nameDialogLabel)
    $nameDialogText = New-Object Windows.Forms.TextBox
    $nameDialogText.Location = New-Object Drawing.Point(20, 107)
    $nameDialogText.Size = New-Object Drawing.Size(570, 27)
    $nameDialogText.Text = if ($editing) { [string]$ExistingComponent.Nome } else { "" }
    $dialog.Controls.Add($nameDialogText)

    $outputCodeLabel = New-Object Windows.Forms.Label
    $outputCodeLabel.Text = "Código na TABELA (opcional)"
    $outputCodeLabel.Location = New-Object Drawing.Point(20, 151)
    $outputCodeLabel.AutoSize = $true
    $dialog.Controls.Add($outputCodeLabel)
    $outputCodeText = New-Object Windows.Forms.TextBox
    $outputCodeText.Location = New-Object Drawing.Point(20, 174)
    $outputCodeText.Size = New-Object Drawing.Size(180, 27)
    $outputCodeText.CharacterCasing = "Upper"
    $outputCodeText.Text = if ($editing) { [string]$ExistingComponent.CodigoPlanilha } else { "" }
    $dialog.Controls.Add($outputCodeText)

    $repairTextLabel = New-Object Windows.Forms.Label
    $repairTextLabel.Text = "Texto principal usado no REPARO"
    $repairTextLabel.Location = New-Object Drawing.Point(220, 151)
    $repairTextLabel.AutoSize = $true
    $dialog.Controls.Add($repairTextLabel)
    $repairDialogText = New-Object Windows.Forms.TextBox
    $repairDialogText.Location = New-Object Drawing.Point(220, 174)
    $repairDialogText.Size = New-Object Drawing.Size(370, 27)
    $repairDialogText.Text = if ($editing) { [string]$ExistingComponent.TextoReparo } else { "" }
    $dialog.Controls.Add($repairDialogText)

    $aliasesLabel = New-Object Windows.Forms.Label
    $aliasesLabel.Text = "Outros nomes ou indicações, separados por vírgula"
    $aliasesLabel.Location = New-Object Drawing.Point(20, 218)
    $aliasesLabel.AutoSize = $true
    $dialog.Controls.Add($aliasesLabel)
    $aliasesText = New-Object Windows.Forms.TextBox
    $aliasesText.Location = New-Object Drawing.Point(20, 241)
    $aliasesText.Size = New-Object Drawing.Size(570, 27)
    $aliasesText.Text = if ($editing) { @($ExistingComponent.Apelidos) -join ", " } else { "" }
    $dialog.Controls.Add($aliasesText)

    $activeCheck = New-Object Windows.Forms.CheckBox
    $activeCheck.Text = "Componente ativo para reconhecimento e baixa automática"
    $activeCheck.Location = New-Object Drawing.Point(20, 285)
    $activeCheck.Size = New-Object Drawing.Size(500, 24)
    $activeCheck.Checked = if ($editing) { ConvertTo-BillingBoolean $ExistingComponent.Ativo } else { $true }
    $dialog.Controls.Add($activeCheck)

    $componentHelp = New-Object Windows.Forms.Label
    $componentHelp.Text = "O saldo representa peças já usadas e ainda não faturadas. O texto e os apelidos ajudam o programa a localizar o componente na coluna REPARO. Sem código da TABELA, o cadastro serve para controle, mas uma mestre que use esse componente não poderá ser gerada até o código ser informado."
    $componentHelp.Location = New-Object Drawing.Point(20, 321)
    $componentHelp.Size = New-Object Drawing.Size(570, 72)
    $componentHelp.Padding = New-Object Windows.Forms.Padding(10, 8, 10, 8)
    $componentHelp.BackColor = $script:CurrentPalette.Info
    $componentHelp.ForeColor = $script:CurrentPalette.Text
    $dialog.Controls.Add($componentHelp)

    foreach ($inputControl in @($productDialogCombo, $componentDialogText, $initialBalanceControl, $nameDialogText, $outputCodeText, $repairDialogText, $aliasesText)) {
        $inputControl.BackColor = $script:CurrentPalette.Input
        $inputControl.ForeColor = $script:CurrentPalette.Text
    }

    $cancelDialogButton = New-Object Windows.Forms.Button
    $cancelDialogButton.Text = "Cancelar"
    $cancelDialogButton.Location = New-Object Drawing.Point(374, 439)
    $cancelDialogButton.Size = New-Object Drawing.Size(100, 36)
    $cancelDialogButton.DialogResult = [Windows.Forms.DialogResult]::Cancel
    $cancelDialogButton.Tag = "Secondary"
    Set-ButtonTheme $cancelDialogButton $script:CurrentPalette
    $dialog.Controls.Add($cancelDialogButton)

    $saveDialogButton = New-Object Windows.Forms.Button
    $saveDialogButton.Text = "Salvar"
    $saveDialogButton.Location = New-Object Drawing.Point(484, 439)
    $saveDialogButton.Size = New-Object Drawing.Size(106, 36)
    $saveDialogButton.Tag = "Primary"
    Set-ButtonTheme $saveDialogButton $script:CurrentPalette
    $dialog.Controls.Add($saveDialogButton)
    $dialog.AcceptButton = $saveDialogButton
    $dialog.CancelButton = $cancelDialogButton

    $saveDialogButton.Add_Click({
        if ([string]::IsNullOrWhiteSpace($componentDialogText.Text)) {
            [Windows.Forms.MessageBox]::Show("Informe o componente ou designador.", "Cadastro de componente", "OK", "Warning") | Out-Null
            return
        }
        if ([string]::IsNullOrWhiteSpace($nameDialogText.Text)) {
            [Windows.Forms.MessageBox]::Show("Informe o nome do componente.", "Cadastro de componente", "OK", "Warning") | Out-Null
            return
        }
        $dialog.Tag = [pscustomobject]@{
            Product = [string]$productDialogCombo.SelectedItem
            Component = $componentDialogText.Text.Trim()
            Name = $nameDialogText.Text.Trim()
            InitialBalance = [int]$initialBalanceControl.Value
            OutputCode = $outputCodeText.Text.Trim()
            RepairText = $repairDialogText.Text.Trim()
            Aliases = @($aliasesText.Text -split '[,;]' | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
            Active = [bool]$activeCheck.Checked
        }
        $dialog.DialogResult = [Windows.Forms.DialogResult]::OK
        $dialog.Close()
    })
    if ($dialog.ShowDialog($form) -eq [Windows.Forms.DialogResult]::OK) { return $dialog.Tag }
    return $null
}

function Apply-AppTheme {
    $theme = [string]$themeCombo.SelectedItem
    if ([string]::IsNullOrWhiteSpace($theme)) { $theme = "Claro moderno" }
    $product = [string]$productCombo.SelectedItem
    if (@("CB5", "TV5") -notcontains $product) { $product = "CB5" }
    $palette = Get-ThemePalette $theme $product
    $script:CurrentPalette = $palette
    $baseFontSize = if ($theme -eq "Alto contraste") { if ($script:IsInProcessHosted) { 10.0 } else { 10.75 } } else { if ($script:IsInProcessHosted) { 9.25 } else { 10 } }
    $form.Font = New-Object Drawing.Font("Segoe UI", $baseFontSize)
    $form.BackColor = $palette.Background
    $headerPanel.BackColor = $palette.Surface
    $footerPanel.BackColor = $palette.Surface
    $accentStrip.BackColor = $palette.Accent
    $title.ForeColor = $palette.Text
    $subtitle.ForeColor = $palette.Muted
    $productLabel.ForeColor = $palette.Muted
    $themeLabel.ForeColor = $palette.Muted
    $versionLabel.ForeColor = $palette.Muted
    $progressStatusLabel.ForeColor = $palette.Muted
    foreach ($combo in @($productCombo, $themeCombo)) {
        $combo.BackColor = $palette.Input
        $combo.ForeColor = $palette.Text
    }
    foreach ($page in @($tabGenerate, $tabExtra, $tabComponents, $tabDescriptions, $tabCombine, $componentBalancesPage, $componentMovementsPage, $componentOperationsPage)) {
        $page.BackColor = $palette.Background
        $page.ForeColor = $palette.Text
    }
    foreach ($panel in @($masterCard, $summaryCard, $destinationCard, $componentActiveCard, $componentPendingCard, $componentOperationsCard, $combineBalanceCard)) {
        $panel.BackColor = $palette.Surface
        $panel.ForeColor = $palette.Text
        $panel.BorderStyle = [Windows.Forms.BorderStyle]::None
        Set-GeneratorRoundedRegion $panel 10
    }
    foreach ($label in @($masterLabel, $masterFileNameLabel, $masterPathLabel, $outputLabel, $outputInfo, $summaryTitle, $summaryProductCaption, $summaryProductValue, $summaryMasterCaption, $masterSummaryLabel, $summaryExtrasCaption, $extrasSummaryLabel, $summaryEffectCaption, $statusLabel, $combineIntro, $combineSelectionLabel, $combineStatusLabel, $extraIntro, $extraSelectionLabel, $componentsIntro, $componentsSummaryLabel, $componentSearchLabel, $componentActiveCaption, $componentActiveValue, $componentPendingCaption, $componentPendingValue, $componentOperationsCaption, $componentOperationsValue, $descriptionsIntro)) {
        $label.ForeColor = $palette.Text
    }
    foreach ($label in @($masterPathLabel, $outputInfo, $summaryProductCaption, $summaryMasterCaption, $summaryExtrasCaption, $summaryEffectCaption, $combineIntro, $extraIntro, $componentsIntro, $componentSearchLabel, $componentActiveCaption, $componentPendingCaption, $componentOperationsCaption, $descriptionsIntro)) {
        $label.ForeColor = $palette.Muted
    }
    $summaryProductValue.ForeColor = $palette.Accent
    foreach ($label in @($componentActiveValue, $componentPendingValue, $componentOperationsValue)) { $label.ForeColor = $palette.Accent }
    $infoBox.BackColor = $palette.Info
    $infoBox.ForeColor = $palette.Text
    $extraIntro.BackColor = $palette.Info
    $extraIntro.ForeColor = $palette.Text
    $extraSelectionLabel.BackColor = $palette.Surface
    $extraSelectionLabel.ForeColor = $palette.Text
    $componentsIntro.BackColor = $palette.Info
    $componentsIntro.ForeColor = $palette.Text
    $combineBalanceCard.BackColor = $palette.Surface
    foreach ($textBox in @($masterText, $statusText, $combineStatusText, $componentSearchText)) {
        $textBox.BackColor = $palette.Input
        $textBox.ForeColor = $palette.Text
    }
    $combineConsumeBalanceCheck.BackColor = $palette.Background
    $combineConsumeBalanceCheck.ForeColor = $palette.Text
    foreach ($button in @($masterButton, $openDestinationCardButton, $previewMasterButton, $copyStatusButton, $componentSearchClearButton, $componentLaunchButton, $componentAdjustButton, $componentNewButton, $componentEditButton, $componentBackupButton, $componentRestoreButton, $combineAddButton, $combineRemoveButton, $combineUpButton, $combineDownButton, $combineClearButton, $combineCopyQuantitiesButton, $combinePasteQuantitiesButton, $previewCombineButton, $copyCombineStatusButton, $openFolderButton, $updateMasterButton, $generateButton, $combineGenerateButton)) {
        Set-ButtonTheme $button $palette
    }
    foreach ($grid in @($extraGrid, $componentGrid, $componentHistoryGrid, $componentOperationsGrid, $descriptionsGrid, $combineGrid)) { Set-GridTheme $grid $palette }
    if ($null -ne $logoPicture.Image) { $logoPicture.Image.Dispose() }
    $logoPicture.Image = New-AppLogoBitmap $palette.Accent 48
    Update-RootLayout
    $tabs.Invalidate()
    $componentTabs.Invalidate()
    Update-LiveSummary
    Update-CombineSummary
    Update-BillingComponentsView
}

function Get-AdditionalDisplayText {
    param([Collections.Generic.List[object]]$Additional)
    if ($Additional.Count -eq 0) { return "Nenhuma" }
    return (@($Additional | ForEach-Object { "$($_.Quantity) $($_.Code)" }) -join "  •  ")
}

function Show-GenerationConfirmation {
    param(
        [string]$Product,
        [string]$MasterPath,
        $MasterData,
        [Collections.Generic.List[object]]$Additional,
        [string[]]$OutputNames,
        [int]$ExistingCount
    )
    $masterAction = if ($Additional.Count -gt 0) { "ATUALIZADA" } else { "NÃO será alterada" }
    $outputLines = @($OutputNames | ForEach-Object { "  • $_" }) -join "`r`n"
    $message = "Confira antes de gerar:`r`n`r`nProduto: $Product`r`nLote: $($MasterData.Lot)`r`nPeças: $($MasterData.Items.Count)`r`nManutenções: $(Get-AdditionalDisplayText $Additional)`r`nMestre: $([IO.Path]::GetFileName($MasterPath)) — $masterAction`r`n`r`nArquivos:`r`n$outputLines"
    if ($ExistingCount -gt 0) { $message += "`r`n`r`n$ExistingCount arquivo(s) existente(s) serão substituídos." }
    $answer = [Windows.Forms.MessageBox]::Show($message, "Confirmar geração", [Windows.Forms.MessageBoxButtons]::YesNo, [Windows.Forms.MessageBoxIcon]::Question)
    return ($answer -eq [Windows.Forms.DialogResult]::Yes)
}

function Show-CombinedConfirmation {
    param(
        [string]$Product,
        [Collections.Generic.List[object]]$Records,
        [Collections.Generic.List[object]]$CombinedItems,
        [string]$OutputName,
        [bool]$FileExists,
        [AllowNull()][object]$DeductionPlan
    )
    $lines = [Collections.Generic.List[string]]::new()
    foreach ($record in $Records) {
        $action = if ($record.UpdateMaster) { "mestre será atualizada" } else { "mestre intacta" }
        $lines.Add("  • $([IO.Path]::GetFileName($record.Path)) | lote $($record.MasterData.Lot) | $($record.MasterData.Items.Count) peças | $(Get-AdditionalDisplayText $record.Additional) | $action")
    }
    $deductionText = "Nenhum componente cadastrado foi encontrado nos reparos. A união será registrada para impedir uma baixa futura duplicada."
    if ($null -ne $DeductionPlan) {
        if ([bool]$DeductionPlan.JaAplicada) {
            $deductionText = "Este mesmo conjunto de lotes já foi processado. O saldo NÃO será descontado novamente, mesmo que a NF tenha sido renomeada."
        }
        elseif (-not [bool]$DeductionPlan.ConsumirSaldo) {
            $deductionText = "A opção de consumo está DESMARCADA. O saldo não será consultado nem baixado. Esta escolha será registrada e estes mesmos lotes não poderão gerar uma baixa posterior acidental."
        }
        elseif (@($DeductionPlan.Linhas).Count -gt 0) {
            $deductionLines = @($DeductionPlan.Linhas | ForEach-Object {
                "  • $($_.Componente) — $($_.Nome): -$($_.Quantidade)  |  $($_.SaldoAnterior) → $($_.SaldoPosterior)"
            })
            $deductionText = "Baixa automática após a união concluir:`r`n$($deductionLines -join "`r`n")"
        }
    }
    $message = "Confira antes de juntar:`r`n`r`nProduto: $Product`r`nLotes: $($Records.Count)`r`nPeças totais: $($CombinedItems.Count)`r`n`r`n$($lines -join "`r`n")`r`n`r`nArquivo final:`r`n  • $OutputName`r`n`r`nComponentes a faturar:`r`n$deductionText"
    if ($FileExists) { $message += "`r`n`r`nO arquivo final existente será substituído." }
    $answer = [Windows.Forms.MessageBox]::Show($message, "Confirmar união", [Windows.Forms.MessageBoxButtons]::YesNo, [Windows.Forms.MessageBoxIcon]::Question)
    return ($answer -eq [Windows.Forms.DialogResult]::Yes)
}

function Show-AppSplash {
    $splash = New-Object Windows.Forms.Form
    $splash.FormBorderStyle = [Windows.Forms.FormBorderStyle]::None
    $splash.StartPosition = [Windows.Forms.FormStartPosition]::CenterScreen
    $splash.Size = New-Object Drawing.Size(430, 205)
    $splash.BackColor = $script:CurrentPalette.Surface
    $splash.ShowInTaskbar = $false
    $splash.TopMost = $true
    $picture = New-Object Windows.Forms.PictureBox
    $picture.Location = New-Object Drawing.Point(28, 35)
    $picture.Size = New-Object Drawing.Size(72, 72)
    $picture.SizeMode = [Windows.Forms.PictureBoxSizeMode]::CenterImage
    $picture.Image = New-AppLogoBitmap $script:CurrentPalette.Accent 64
    $splash.Controls.Add($picture)
    $splashTitle = New-Object Windows.Forms.Label
    $splashTitle.Text = "Gerenciador de Planilhas"
    $splashTitle.Font = New-Object Drawing.Font("Segoe UI Semibold", 18)
    $splashTitle.ForeColor = $script:CurrentPalette.Text
    $splashTitle.Location = New-Object Drawing.Point(118, 45)
    $splashTitle.AutoSize = $true
    $splash.Controls.Add($splashTitle)
    $splashText = New-Object Windows.Forms.Label
    $splashText.Text = "CB5 e TV5  •  Versão $($script:AppVersion)"
    $splashText.ForeColor = $script:CurrentPalette.Muted
    $splashText.Location = New-Object Drawing.Point(120, 84)
    $splashText.AutoSize = $true
    $splash.Controls.Add($splashText)
    $splashProgress = New-Object Windows.Forms.ProgressBar
    $splashProgress.Location = New-Object Drawing.Point(28, 150)
    $splashProgress.Size = New-Object Drawing.Size(374, 8)
    $splashProgress.Style = [Windows.Forms.ProgressBarStyle]::Marquee
    $splashProgress.MarqueeAnimationSpeed = 22
    $splash.Controls.Add($splashProgress)
    $timer = New-Object Windows.Forms.Timer
    $timer.Interval = 750
    $timer.Add_Tick({ $timer.Stop(); $splash.Close() })
    $splash.Add_Shown({ $timer.Start() })
    [void]$splash.ShowDialog()
    $timer.Dispose()
    $picture.Image.Dispose()
    $splash.Dispose()
}

$script:AppSettings = Get-AppSettings
if ($script:IsInProcessHosted -and -not [string]::IsNullOrWhiteSpace($HostTheme)) {
    $script:AppSettings.Theme = Get-GeneratorThemeFromHost $HostTheme
}
$script:LastInputDirectory = [string]$script:AppSettings.LastInputDirectory
$initialPalette = Get-ThemePalette $script:AppSettings.Theme $script:AppSettings.Product
$script:CurrentPalette = $initialPalette

$workingArea = [Windows.Forms.Screen]::PrimaryScreen.WorkingArea
$targetWidth = [Math]::Min($workingArea.Width, [Math]::Max(760, [int]($workingArea.Width * 0.94)))
$targetHeight = [Math]::Min($workingArea.Height, [Math]::Max(520, [int]($workingArea.Height * 0.94)))
$targetWidth = [Math]::Min($targetWidth, $workingArea.Width)
$targetHeight = [Math]::Min($targetHeight, $workingArea.Height)
$minimumWidth = [Math]::Min(820, $workingArea.Width)
$minimumHeight = [Math]::Min(560, $workingArea.Height)

if ($script:IsInProcessHosted) {
    $form = New-Object Windows.Forms.UserControl
    $form.Name = "GeneratorHostedControl"
    $form.AutoScaleMode = [Windows.Forms.AutoScaleMode]::None
    $form.AutoScaleDimensions = New-Object Drawing.SizeF(96, 96)
    $form.MinimumSize = New-Object Drawing.Size(1, 1)
    $form.Margin = New-Object Windows.Forms.Padding(0)
    $form.Dock = [Windows.Forms.DockStyle]::Fill
    $form.Font = New-Object Drawing.Font("Segoe UI", 9.25)
    $form.BackColor = $initialPalette.Background
    $script:AppIconBitmap = $null
    $script:AppIcon = $null
}
else {
    $form = New-Object Windows.Forms.Form
    $form.Text = "Gerenciador de Planilhas CB5 e TV5"
    $form.StartPosition = [Windows.Forms.FormStartPosition]::CenterScreen
    $form.AutoScaleMode = [Windows.Forms.AutoScaleMode]::Dpi
    $form.AutoScaleDimensions = New-Object Drawing.SizeF(96, 96)
    $form.FormBorderStyle = [Windows.Forms.FormBorderStyle]::Sizable
    $form.MaximizeBox = $true
    $form.MinimizeBox = $true
    $form.Size = New-Object Drawing.Size(1080, 780)
    $form.MinimumSize = New-Object Drawing.Size(820, 560)
    $form.Font = New-Object Drawing.Font("Segoe UI", 10)
    $form.BackColor = $initialPalette.Background
    $form.KeyPreview = $true
    $script:AppIconBitmap = New-AppLogoBitmap $initialPalette.Accent 32
    $script:AppIcon = [Drawing.Icon]::FromHandle($script:AppIconBitmap.GetHicon())
    $form.Icon = $script:AppIcon
}

$toolTip = New-Object Windows.Forms.ToolTip
$toolTip.AutoPopDelay = 8000
$toolTip.InitialDelay = 450
$toolTip.ReshowDelay = 120

$headerPanel = New-Object Windows.Forms.Panel
$headerPanel.Location = New-Object Drawing.Point(0, 0)
$headerPanel.Size = New-Object Drawing.Size(1064, 88)
$headerPanel.Anchor = "Top,Left,Right"
$headerPanel.BackColor = $initialPalette.Surface
$form.Controls.Add($headerPanel)

$accentStrip = New-Object Windows.Forms.Panel
$accentStrip.Location = New-Object Drawing.Point(0, 0)
$accentStrip.Size = New-Object Drawing.Size(7, 88)
$accentStrip.BackColor = $initialPalette.Accent
$headerPanel.Controls.Add($accentStrip)

$logoPicture = New-Object Windows.Forms.PictureBox
$logoPicture.Location = New-Object Drawing.Point(22, 18)
$logoPicture.Size = New-Object Drawing.Size(48, 48)
$logoPicture.SizeMode = [Windows.Forms.PictureBoxSizeMode]::StretchImage
$logoPicture.Image = New-AppLogoBitmap $initialPalette.Accent 48
$headerPanel.Controls.Add($logoPicture)

$title = New-Object Windows.Forms.Label
$title.Text = "Gerenciador de Planilhas"
$title.Font = New-Object Drawing.Font("Segoe UI Semibold", 18)
$title.Location = New-Object Drawing.Point(82, 14)
$title.AutoSize = $true
$headerPanel.Controls.Add($title)

$subtitle = New-Object Windows.Forms.Label
$subtitle.Text = "Escolha o produto, selecione a mestre e confira o resumo antes de gerar."
$subtitle.Location = New-Object Drawing.Point(84, 52)
$subtitle.AutoSize = $true
$headerPanel.Controls.Add($subtitle)

$themeLabel = New-Object Windows.Forms.Label
$themeLabel.Text = "Aparência"
$themeLabel.Location = New-Object Drawing.Point(684, 12)
$themeLabel.AutoSize = $true
$themeLabel.Anchor = "Top,Right"
$headerPanel.Controls.Add($themeLabel)

$themeCombo = New-Object Windows.Forms.ComboBox
$themeCombo.Location = New-Object Drawing.Point(684, 34)
$themeCombo.Size = New-Object Drawing.Size(166, 30)
$themeCombo.Anchor = "Top,Right"
$themeCombo.DropDownStyle = [Windows.Forms.ComboBoxStyle]::DropDownList
[void]$themeCombo.Items.Add("Claro moderno")
[void]$themeCombo.Items.Add("Escuro grafite")
[void]$themeCombo.Items.Add("Técnico industrial")
[void]$themeCombo.Items.Add("Alto contraste")
$themeCombo.SelectedItem = $script:AppSettings.Theme
$headerPanel.Controls.Add($themeCombo)

$productLabel = New-Object Windows.Forms.Label
$productLabel.Text = "Produto"
$productLabel.Location = New-Object Drawing.Point(870, 12)
$productLabel.AutoSize = $true
$productLabel.Anchor = "Top,Right"
$headerPanel.Controls.Add($productLabel)

$productCombo = New-Object Windows.Forms.ComboBox
$productCombo.Location = New-Object Drawing.Point(870, 34)
$productCombo.Size = New-Object Drawing.Size(166, 30)
$productCombo.Anchor = "Top,Right"
$productCombo.DropDownStyle = [Windows.Forms.ComboBoxStyle]::DropDownList
[void]$productCombo.Items.Add("CB5")
[void]$productCombo.Items.Add("TV5")
$productCombo.SelectedItem = $script:AppSettings.Product
$headerPanel.Controls.Add($productCombo)

$tabs = New-Object Windows.Forms.TabControl
$tabs.Location = New-Object Drawing.Point(20, 98)
$tabs.Size = New-Object Drawing.Size(1024, 554)
$tabs.Anchor = "Top,Bottom,Left,Right"
$tabs.DrawMode = [Windows.Forms.TabDrawMode]::OwnerDrawFixed
$tabs.SizeMode = [Windows.Forms.TabSizeMode]::Normal
if ($script:IsInProcessHosted) {
    $tabs.ItemSize = New-Object Drawing.Size(0, 31)
}
else {
    $tabs.ItemSize = New-Object Drawing.Size(0, 34)
}
if ($script:IsInProcessHosted) {
    $tabs.Padding = New-Object Drawing.Point(14, 5)
}
else {
    $tabs.Padding = New-Object Drawing.Point(18, 6)
}
$tabs.ShowToolTips = $true
$form.Controls.Add($tabs)

$tabGenerate = New-Object Windows.Forms.TabPage
$tabGenerate.Text = "Gerar planilhas"
$tabGenerate.AutoScroll = $true
$tabGenerate.AutoScrollMinSize = New-Object Drawing.Size(1000, 500)
$tabs.TabPages.Add($tabGenerate)

$tabExtra = New-Object Windows.Forms.TabPage
$tabExtra.Text = "Manutenções adicionais"
$tabExtra.ToolTipText = "Quantidades adicionais que serão escritas na planilha mestre."
$tabExtra.AutoScroll = $true
$tabExtra.AutoScrollMinSize = New-Object Drawing.Size(1000, 500)
$tabs.TabPages.Add($tabExtra)

$tabComponents = New-Object Windows.Forms.TabPage
$tabComponents.Text = "Componentes a faturar"
$tabComponents.ToolTipText = "Saldo dos componentes e serviços usados que ainda aguardam faturamento."
$tabComponents.AutoScroll = $true
$tabComponents.AutoScrollMinSize = New-Object Drawing.Size(1000, 500)
$tabs.TabPages.Add($tabComponents)

$tabCombine = New-Object Windows.Forms.TabPage
$tabCombine.Text = "Juntar lotes"
$tabCombine.AutoScroll = $true
$tabCombine.AutoScrollMinSize = New-Object Drawing.Size(1000, 500)
$tabs.TabPages.Add($tabCombine)

$tabDescriptions = New-Object Windows.Forms.TabPage
$tabDescriptions.Text = "Legenda de códigos"
$tabDescriptions.ToolTipText = "Consulta dos códigos e textos usados nos arquivos gerados."
$tabDescriptions.AutoScroll = $true
$tabDescriptions.AutoScrollMinSize = New-Object Drawing.Size(1000, 500)
$tabs.TabPages.Add($tabDescriptions)

$masterCard = New-Object Windows.Forms.Panel
$masterCard.Location = New-Object Drawing.Point(18, 16)
$masterCard.Size = New-Object Drawing.Size(982, 100)
$masterCard.Anchor = "Top,Left,Right"
$masterCard.BorderStyle = [Windows.Forms.BorderStyle]::FixedSingle
$tabGenerate.Controls.Add($masterCard)

$masterLabel = New-Object Windows.Forms.Label
$masterLabel.Text = "1  PLANILHA MESTRE"
$masterLabel.Font = New-Object Drawing.Font("Segoe UI Semibold", 9)
$masterLabel.Location = New-Object Drawing.Point(14, 10)
$masterLabel.AutoSize = $true
$masterCard.Controls.Add($masterLabel)

$masterFileNameLabel = New-Object Windows.Forms.Label
$masterFileNameLabel.Text = "Nenhuma mestre selecionada"
$masterFileNameLabel.Font = New-Object Drawing.Font("Segoe UI Semibold", 11.5)
$masterFileNameLabel.Location = New-Object Drawing.Point(14, 31)
$masterFileNameLabel.Size = New-Object Drawing.Size(750, 24)
$masterFileNameLabel.Anchor = "Top,Left"
$masterFileNameLabel.AutoEllipsis = $true
$masterCard.Controls.Add($masterFileNameLabel)

$masterPathLabel = New-Object Windows.Forms.Label
$masterPathLabel.Text = "Caminho:"
$masterPathLabel.Location = New-Object Drawing.Point(14, 66)
$masterPathLabel.AutoSize = $true
$masterCard.Controls.Add($masterPathLabel)

$masterText = New-Object Windows.Forms.TextBox
$masterText.Location = New-Object Drawing.Point(78, 62)
$masterText.Size = New-Object Drawing.Size(710, 27)
$masterText.Anchor = "Top,Left"
$masterText.ReadOnly = $true
$masterText.TabStop = $false
$masterCard.Controls.Add($masterText)

$masterButton = New-Object Windows.Forms.Button
$masterButton.Text = "▣  Selecionar mestre..."
$masterButton.Location = New-Object Drawing.Point(790, 13)
$masterButton.Size = New-Object Drawing.Size(174, 34)
$masterButton.Anchor = "Top,Right"
$masterButton.Tag = "Primary"
$masterCard.Controls.Add($masterButton)
$toolTip.SetToolTip($masterButton, "Escolha a planilha mestre do produto selecionado. A NF só é obrigatória ao gerar os arquivos finais.")

function Update-MasterCardLayout {
    if ($null -eq $masterCard -or $null -eq $masterButton -or $null -eq $masterText) { return }
    $rightMargin = 14
    $controlGap = 12
    $buttonWidth = 174
    $buttonLeft = [Math]::Max(270, $masterCard.ClientSize.Width - $buttonWidth - $rightMargin)
    $masterButton.Left = [int]$buttonLeft
    $masterButton.Top = 13
    $masterButton.Width = $buttonWidth
    $masterText.Width = [int][Math]::Max(160, $masterCard.ClientSize.Width - $masterText.Left - $rightMargin)
    $masterFileNameLabel.Width = [int][Math]::Max(160, $buttonLeft - $masterFileNameLabel.Left - $controlGap)
    $masterButton.Visible = $true
    $masterButton.Enabled = $true
    $masterButton.BringToFront()
}

$masterCard.Add_Resize({ Update-MasterCardLayout })
Update-MasterCardLayout

$destinationCard = New-Object Windows.Forms.Panel
$destinationCard.Location = New-Object Drawing.Point(18, 126)
$destinationCard.Size = New-Object Drawing.Size(982, 56)
$destinationCard.Anchor = "Top,Left,Right"
$destinationCard.BorderStyle = [Windows.Forms.BorderStyle]::FixedSingle
$tabGenerate.Controls.Add($destinationCard)

$outputLabel = New-Object Windows.Forms.Label
$outputLabel.Text = "2  DESTINO AUTOMÁTICO — ÁREA DE TRABALHO"
$outputLabel.Font = New-Object Drawing.Font("Segoe UI Semibold", 10)
$outputLabel.Location = New-Object Drawing.Point(14, 8)
$outputLabel.AutoSize = $true
$destinationCard.Controls.Add($outputLabel)

$outputInfo = New-Object Windows.Forms.Label
$outputInfo.Text = "Manutenção, Chip1 e Chip2 serão salvos na Área de Trabalho."
$outputInfo.Location = New-Object Drawing.Point(14, 30)
$outputInfo.Size = New-Object Drawing.Size(750, 21)
$outputInfo.Anchor = "Top,Left,Right"
$destinationCard.Controls.Add($outputInfo)

$openDestinationCardButton = New-Object Windows.Forms.Button
$openDestinationCardButton.Text = "↗  Abrir destino"
$openDestinationCardButton.Location = New-Object Drawing.Point(834, 10)
$openDestinationCardButton.Size = New-Object Drawing.Size(130, 34)
$openDestinationCardButton.Anchor = "Top,Right"
$openDestinationCardButton.Tag = "Secondary"
$destinationCard.Controls.Add($openDestinationCardButton)

$summaryCard = New-Object Windows.Forms.Panel
$summaryCard.Location = New-Object Drawing.Point(18, 192)
$summaryCard.Size = New-Object Drawing.Size(982, 88)
$summaryCard.Anchor = "Top,Left,Right"
$summaryCard.BorderStyle = [Windows.Forms.BorderStyle]::FixedSingle
$tabGenerate.Controls.Add($summaryCard)

$summaryTitle = New-Object Windows.Forms.Label
$summaryTitle.Text = "3  RESUMO ANTES DE GERAR"
$summaryTitle.Font = New-Object Drawing.Font("Segoe UI Semibold", 9)
$summaryTitle.Location = New-Object Drawing.Point(14, 7)
$summaryTitle.AutoSize = $true
$summaryCard.Controls.Add($summaryTitle)

$summaryLayout = New-Object Windows.Forms.TableLayoutPanel
$summaryLayout.Location = New-Object Drawing.Point(10, 27)
$summaryLayout.Size = New-Object Drawing.Size(958, 52)
$summaryLayout.Anchor = "Top,Left,Right"
$summaryLayout.ColumnCount = 4
$summaryLayout.RowCount = 2
[void]$summaryLayout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 14)))
[void]$summaryLayout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 25)))
[void]$summaryLayout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 34)))
[void]$summaryLayout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 27)))
[void]$summaryLayout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 42)))
[void]$summaryLayout.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Percent, 58)))
$summaryCard.Controls.Add($summaryLayout)

$summaryProductCaption = New-Object Windows.Forms.Label
$summaryProductCaption.Text = "Produto"
$summaryProductCaption.Dock = "Fill"
$summaryProductValue = New-Object Windows.Forms.Label
$summaryProductValue.Text = "CB5"
$summaryProductValue.Font = New-Object Drawing.Font("Segoe UI Semibold", 10)
$summaryProductValue.Dock = "Fill"
$summaryMasterCaption = New-Object Windows.Forms.Label
$summaryMasterCaption.Text = "Mestre"
$summaryMasterCaption.Dock = "Fill"
$masterSummaryLabel = New-Object Windows.Forms.Label
$masterSummaryLabel.Text = "Nenhuma mestre selecionada"
$masterSummaryLabel.Font = New-Object Drawing.Font("Segoe UI Semibold", 10)
$masterSummaryLabel.Dock = "Fill"
$masterSummaryLabel.AutoEllipsis = $true
$summaryExtrasCaption = New-Object Windows.Forms.Label
$summaryExtrasCaption.Text = "Manutenções"
$summaryExtrasCaption.Dock = "Fill"
$extrasSummaryLabel = New-Object Windows.Forms.Label
$extrasSummaryLabel.Text = "Nenhuma manutenção adicional"
$extrasSummaryLabel.Font = New-Object Drawing.Font("Segoe UI Semibold", 10)
$extrasSummaryLabel.Dock = "Fill"
$extrasSummaryLabel.AutoEllipsis = $true
$summaryEffectCaption = New-Object Windows.Forms.Label
$summaryEffectCaption.Text = "Efeito na mestre"
$summaryEffectCaption.Dock = "Fill"
$masterEffectLabel = New-Object Windows.Forms.Label
$masterEffectLabel.Text = "A mestre permanecerá intacta"
$masterEffectLabel.Font = New-Object Drawing.Font("Segoe UI Semibold", 10)
$masterEffectLabel.Dock = "Fill"
$masterEffectLabel.AutoEllipsis = $true
$summaryLayout.Controls.Add($summaryProductCaption, 0, 0)
$summaryLayout.Controls.Add($summaryProductValue, 0, 1)
$summaryLayout.Controls.Add($summaryMasterCaption, 1, 0)
$summaryLayout.Controls.Add($masterSummaryLabel, 1, 1)
$summaryLayout.Controls.Add($summaryExtrasCaption, 2, 0)
$summaryLayout.Controls.Add($extrasSummaryLabel, 2, 1)
$summaryLayout.Controls.Add($summaryEffectCaption, 3, 0)
$summaryLayout.Controls.Add($masterEffectLabel, 3, 1)

$infoBox = New-Object Windows.Forms.Label
$infoBox.Text = "Sem manutenção adicional, a mestre permanece intacta. Se houver quantidades em Manutenções, somente REPARO será atualizado. A estrutura da mestre é validada antes de qualquer gravação."
$infoBox.Location = New-Object Drawing.Point(18, 290)
$infoBox.Size = New-Object Drawing.Size(982, 56)
$infoBox.Anchor = "Top,Left,Right"
$infoBox.Padding = New-Object Windows.Forms.Padding(12, 9, 12, 8)
$tabGenerate.Controls.Add($infoBox)

$statusLabel = New-Object Windows.Forms.Label
$statusLabel.Text = "CONFERÊNCIA E RESULTADO"
$statusLabel.Font = New-Object Drawing.Font("Segoe UI Semibold", 10)
$statusLabel.Location = New-Object Drawing.Point(18, 358)
$statusLabel.AutoSize = $true
$tabGenerate.Controls.Add($statusLabel)

$previewMasterButton = New-Object Windows.Forms.Button
$previewMasterButton.Text = "Conferir primeiro"
$previewMasterButton.Location = New-Object Drawing.Point(675, 349)
$previewMasterButton.Size = New-Object Drawing.Size(158, 30)
$previewMasterButton.Anchor = "Top,Right"
$previewMasterButton.Tag = "Secondary"
$tabGenerate.Controls.Add($previewMasterButton)
$toolTip.SetToolTip($previewMasterButton, "Valida a mestre e mostra exatamente quais séries mudariam, sem salvar nenhum arquivo.")

$copyStatusButton = New-Object Windows.Forms.Button
$copyStatusButton.Text = "Copiar resultado"
$copyStatusButton.Location = New-Object Drawing.Point(843, 349)
$copyStatusButton.Size = New-Object Drawing.Size(157, 30)
$copyStatusButton.Anchor = "Top,Right"
$copyStatusButton.Tag = "Secondary"
$tabGenerate.Controls.Add($copyStatusButton)

$statusText = New-Object Windows.Forms.TextBox
$statusText.Location = New-Object Drawing.Point(18, 382)
$statusText.Size = New-Object Drawing.Size(982, 105)
$statusText.Anchor = "Top,Bottom,Left,Right"
$statusText.Multiline = $true
$statusText.ReadOnly = $true
$statusText.ScrollBars = "Vertical"
$statusText.BorderStyle = [Windows.Forms.BorderStyle]::FixedSingle
$tabGenerate.Controls.Add($statusText)

$extraIntro = New-Object Windows.Forms.Label
$extraIntro.Text = "Digite na coluna amarela quantas peças receberão cada manutenção. A maior quantidade é aplicada primeiro."
$extraIntro.Location = New-Object Drawing.Point(18, 12)
$extraIntro.Size = New-Object Drawing.Size(982, 38)
$extraIntro.Anchor = "Top,Left,Right"
$tabExtra.Controls.Add($extraIntro)

$extraSelectionLabel = New-Object Windows.Forms.Label
$extraSelectionLabel.Text = "Nenhuma manutenção adicional"
$extraSelectionLabel.Font = New-Object Drawing.Font("Segoe UI Semibold", 10)
$extraSelectionLabel.Location = New-Object Drawing.Point(18, 56)
$extraSelectionLabel.Size = New-Object Drawing.Size(982, 34)
$extraSelectionLabel.Anchor = "Top,Left,Right"
$tabExtra.Controls.Add($extraSelectionLabel)
$extraIntro.Font = New-Object Drawing.Font("Segoe UI Semibold", 9.2)
$extraIntro.Padding = New-Object Windows.Forms.Padding(12, 7, 12, 6)
$extraIntro.BorderStyle = [Windows.Forms.BorderStyle]::None
$extraSelectionLabel.Padding = New-Object Windows.Forms.Padding(12, 7, 12, 6)
$extraSelectionLabel.BorderStyle = [Windows.Forms.BorderStyle]::None
$extraIntro.Add_SizeChanged({ Set-GeneratorRoundedRegion $this 9 })
$extraSelectionLabel.Add_SizeChanged({ Set-GeneratorRoundedRegion $this 9 })
Set-GeneratorRoundedRegion $extraIntro 9
Set-GeneratorRoundedRegion $extraSelectionLabel 9

$extraGrid = New-Object Windows.Forms.DataGridView
$extraGrid.Location = New-Object Drawing.Point(18, 98)
$extraGrid.Size = New-Object Drawing.Size(982, 389)
$extraGrid.Anchor = "Top,Bottom,Left,Right"
$extraGrid.AllowUserToAddRows = $false
$extraGrid.AllowUserToDeleteRows = $false
$extraGrid.AllowUserToResizeRows = $false
$extraGrid.RowHeadersVisible = $false
$extraGrid.AutoSizeColumnsMode = "None"
$extraGrid.SelectionMode = "CellSelect"
$extraGrid.EditMode = [Windows.Forms.DataGridViewEditMode]::EditOnEnter
[void]$extraGrid.Columns.Add("Code", "Código")
[void]$extraGrid.Columns.Add("Quantity", "Quantidade (digite)")
[void]$extraGrid.Columns.Add("Description", "Descrição")
[void]$extraGrid.Columns.Add("Note", "Observação")
$extraGrid.Columns[0].ReadOnly = $true
$extraGrid.Columns[1].ReadOnly = $false
$extraGrid.Columns[2].ReadOnly = $true
$extraGrid.Columns[3].ReadOnly = $true
Set-GridColumnWidth $extraGrid "Code" 105 "Fixed" 85
Set-GridColumnWidth $extraGrid "Quantity" 145 "Fixed" 125
Set-GridColumnWidth $extraGrid "Description" 100 "Fill" 260
Set-GridColumnWidth $extraGrid "Note" 190 "Fixed" 150
$extraGrid.Columns[1].DefaultCellStyle.Alignment = [Windows.Forms.DataGridViewContentAlignment]::MiddleCenter
$extraGrid.Columns[1].ToolTipText = "Digite a quantidade de peças; zero ou vazio não altera a mestre."
$tabExtra.Controls.Add($extraGrid)

$componentsIntro = New-Object Windows.Forms.Label
$componentsIntro.Text = "Saldo a faturar: quantidades já usadas nas manutenções e ainda não enviadas ao faturamento. A baixa automática acontece somente após Juntar lotes terminar com sucesso."
$componentsIntro.Location = New-Object Drawing.Point(18, 10)
$componentsIntro.Size = New-Object Drawing.Size(982, 38)
$componentsIntro.Anchor = "Top,Left,Right"
$tabComponents.Controls.Add($componentsIntro)
$componentsIntro.Font = New-Object Drawing.Font("Segoe UI Semibold", 9.1)
$componentsIntro.Padding = New-Object Windows.Forms.Padding(12, 7, 12, 6)
$componentsIntro.BorderStyle = [Windows.Forms.BorderStyle]::None
$componentsIntro.Add_SizeChanged({ Set-GeneratorRoundedRegion $this 9 })
Set-GeneratorRoundedRegion $componentsIntro 9

$componentMetricsLayout = New-Object Windows.Forms.TableLayoutPanel
$componentMetricsLayout.Location = New-Object Drawing.Point(18, 56)
$componentMetricsLayout.Size = New-Object Drawing.Size(982, 58)
$componentMetricsLayout.Anchor = "Top,Left,Right"
$componentMetricsLayout.ColumnCount = 3
$componentMetricsLayout.RowCount = 1
$componentMetricsLayout.Padding = New-Object Windows.Forms.Padding(0)
[void]$componentMetricsLayout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 33.33)))
[void]$componentMetricsLayout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 33.34)))
[void]$componentMetricsLayout.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent, 33.33)))
$tabComponents.Controls.Add($componentMetricsLayout)

$componentActiveCard = New-Object Windows.Forms.Panel
$componentActiveCard.Dock = "Fill"
$componentActiveCard.Margin = New-Object Windows.Forms.Padding(0, 0, 6, 0)
$componentActiveCard.BorderStyle = [Windows.Forms.BorderStyle]::FixedSingle
$componentMetricsLayout.Controls.Add($componentActiveCard, 0, 0)
$componentActiveCaption = New-Object Windows.Forms.Label
$componentActiveCaption.Text = "COMPONENTES ATIVOS"
$componentActiveCaption.Location = New-Object Drawing.Point(10, 6)
$componentActiveCaption.AutoSize = $true
$componentActiveCard.Controls.Add($componentActiveCaption)
$componentActiveValue = New-Object Windows.Forms.Label
$componentActiveValue.Text = "0"
$componentActiveValue.Font = New-Object Drawing.Font("Segoe UI Semibold", 15)
$componentActiveValue.Location = New-Object Drawing.Point(9, 24)
$componentActiveValue.AutoSize = $true
$componentActiveCard.Controls.Add($componentActiveValue)

$componentPendingCard = New-Object Windows.Forms.Panel
$componentPendingCard.Dock = "Fill"
$componentPendingCard.Margin = New-Object Windows.Forms.Padding(3, 0, 3, 0)
$componentPendingCard.BorderStyle = [Windows.Forms.BorderStyle]::FixedSingle
$componentMetricsLayout.Controls.Add($componentPendingCard, 1, 0)
$componentPendingCaption = New-Object Windows.Forms.Label
$componentPendingCaption.Text = "UNIDADES PENDENTES"
$componentPendingCaption.Location = New-Object Drawing.Point(10, 6)
$componentPendingCaption.AutoSize = $true
$componentPendingCard.Controls.Add($componentPendingCaption)
$componentPendingValue = New-Object Windows.Forms.Label
$componentPendingValue.Text = "0"
$componentPendingValue.Font = New-Object Drawing.Font("Segoe UI Semibold", 15)
$componentPendingValue.Location = New-Object Drawing.Point(9, 24)
$componentPendingValue.AutoSize = $true
$componentPendingCard.Controls.Add($componentPendingValue)

$componentOperationsCard = New-Object Windows.Forms.Panel
$componentOperationsCard.Dock = "Fill"
$componentOperationsCard.Margin = New-Object Windows.Forms.Padding(6, 0, 0, 0)
$componentOperationsCard.BorderStyle = [Windows.Forms.BorderStyle]::FixedSingle
$componentMetricsLayout.Controls.Add($componentOperationsCard, 2, 0)
$componentOperationsCaption = New-Object Windows.Forms.Label
$componentOperationsCaption.Text = "UNIÕES PROCESSADAS"
$componentOperationsCaption.Location = New-Object Drawing.Point(10, 6)
$componentOperationsCaption.AutoSize = $true
$componentOperationsCard.Controls.Add($componentOperationsCaption)
$componentOperationsValue = New-Object Windows.Forms.Label
$componentOperationsValue.Text = "0"
$componentOperationsValue.Font = New-Object Drawing.Font("Segoe UI Semibold", 15)
$componentOperationsValue.Location = New-Object Drawing.Point(9, 24)
$componentOperationsValue.AutoSize = $true
$componentOperationsCard.Controls.Add($componentOperationsValue)

$componentSearchLabel = New-Object Windows.Forms.Label
$componentSearchLabel.Text = "Pesquisar"
$componentSearchLabel.Location = New-Object Drawing.Point(18, 125)
$componentSearchLabel.AutoSize = $true
$tabComponents.Controls.Add($componentSearchLabel)

$componentSearchText = New-Object Windows.Forms.TextBox
$componentSearchText.Location = New-Object Drawing.Point(88, 120)
$componentSearchText.Size = New-Object Drawing.Size(225, 27)
$componentSearchText.Anchor = "Top,Left"
$tabComponents.Controls.Add($componentSearchText)
$toolTip.SetToolTip($componentSearchText, "Pesquise pelo componente, nome, código, texto de reparo ou apelido.")

$componentSearchClearButton = New-Object Windows.Forms.Button
$componentSearchClearButton.Text = "Limpar"
$componentSearchClearButton.Location = New-Object Drawing.Point(321, 118)
$componentSearchClearButton.Size = New-Object Drawing.Size(76, 31)
$componentSearchClearButton.Tag = "Secondary"
$tabComponents.Controls.Add($componentSearchClearButton)

$componentsSummaryLabel = New-Object Windows.Forms.Label
$componentsSummaryLabel.Text = "Carregando componentes..."
$componentsSummaryLabel.Location = New-Object Drawing.Point(409, 125)
$componentsSummaryLabel.Size = New-Object Drawing.Size(260, 21)
$componentsSummaryLabel.Anchor = "Top,Left,Right"
$tabComponents.Controls.Add($componentsSummaryLabel)

$componentBackupButton = New-Object Windows.Forms.Button
$componentBackupButton.Text = "Backup"
$componentBackupButton.Location = New-Object Drawing.Point(690, 118)
$componentBackupButton.Size = New-Object Drawing.Size(142, 31)
$componentBackupButton.Anchor = "Top,Right"
$componentBackupButton.Tag = "Secondary"
$tabComponents.Controls.Add($componentBackupButton)

$componentRestoreButton = New-Object Windows.Forms.Button
$componentRestoreButton.Text = "Restaurar"
$componentRestoreButton.Location = New-Object Drawing.Point(842, 118)
$componentRestoreButton.Size = New-Object Drawing.Size(142, 31)
$componentRestoreButton.Anchor = "Top,Right"
$componentRestoreButton.Tag = "Secondary"
$tabComponents.Controls.Add($componentRestoreButton)

$componentTabs = New-Object Windows.Forms.TabControl
$componentTabs.Location = New-Object Drawing.Point(18, 160)
$componentTabs.Size = New-Object Drawing.Size(982, 327)
$componentTabs.Anchor = "Top,Bottom,Left,Right"
$componentTabs.DrawMode = [Windows.Forms.TabDrawMode]::OwnerDrawFixed
$componentTabs.SizeMode = [Windows.Forms.TabSizeMode]::Fixed
$componentTabs.ItemSize = New-Object Drawing.Size(174, 30)
$tabComponents.Controls.Add($componentTabs)

$componentBalancesPage = New-Object Windows.Forms.TabPage
$componentBalancesPage.Text = "Saldos"
$componentTabs.TabPages.Add($componentBalancesPage)

$componentMovementsPage = New-Object Windows.Forms.TabPage
$componentMovementsPage.Text = "Movimentações"
$componentTabs.TabPages.Add($componentMovementsPage)

$componentOperationsPage = New-Object Windows.Forms.TabPage
$componentOperationsPage.Text = "Uniões processadas"
$componentTabs.TabPages.Add($componentOperationsPage)

$componentLaunchButton = New-Object Windows.Forms.Button
$componentLaunchButton.Text = "+  Lançar uso"
$componentLaunchButton.Location = New-Object Drawing.Point(10, 9)
$componentLaunchButton.Size = New-Object Drawing.Size(174, 34)
$componentLaunchButton.Tag = "Primary"
$componentBalancesPage.Controls.Add($componentLaunchButton)
$toolTip.SetToolTip($componentLaunchButton, "Acrescenta ao saldo a faturar a quantidade usada do componente selecionado.")

$componentAdjustButton = New-Object Windows.Forms.Button
$componentAdjustButton.Text = "Ajustar saldo"
$componentAdjustButton.Location = New-Object Drawing.Point(194, 9)
$componentAdjustButton.Size = New-Object Drawing.Size(145, 34)
$componentAdjustButton.Tag = "Secondary"
$componentBalancesPage.Controls.Add($componentAdjustButton)
$toolTip.SetToolTip($componentAdjustButton, "Define manualmente o saldo exato do componente selecionado.")

$componentNewButton = New-Object Windows.Forms.Button
$componentNewButton.Text = "+  Novo"
$componentNewButton.Location = New-Object Drawing.Point(349, 9)
$componentNewButton.Size = New-Object Drawing.Size(165, 34)
$componentNewButton.Tag = "Secondary"
$componentBalancesPage.Controls.Add($componentNewButton)

$componentEditButton = New-Object Windows.Forms.Button
$componentEditButton.Text = "Editar"
$componentEditButton.Location = New-Object Drawing.Point(524, 9)
$componentEditButton.Size = New-Object Drawing.Size(160, 34)
$componentEditButton.Tag = "Secondary"
$componentBalancesPage.Controls.Add($componentEditButton)

$componentGrid = New-Object Windows.Forms.DataGridView
$componentGrid.Location = New-Object Drawing.Point(10, 51)
$componentGrid.Size = New-Object Drawing.Size(954, 250)
$componentGrid.Anchor = "Top,Bottom,Left,Right"
$componentGrid.AllowUserToAddRows = $false
$componentGrid.AllowUserToDeleteRows = $false
$componentGrid.AllowUserToResizeRows = $false
$componentGrid.RowHeadersVisible = $false
$componentGrid.ReadOnly = $true
$componentGrid.MultiSelect = $false
$componentGrid.SelectionMode = "FullRowSelect"
$componentGrid.AutoSizeColumnsMode = "None"
[void]$componentGrid.Columns.Add("Component", "Componente")
[void]$componentGrid.Columns.Add("Name", "Nome")
[void]$componentGrid.Columns.Add("Balance", "Saldo a faturar")
[void]$componentGrid.Columns.Add("OutputCode", "Código planilha")
[void]$componentGrid.Columns.Add("RepairText", "Texto no REPARO")
[void]$componentGrid.Columns.Add("Active", "Situação")
Set-GridColumnWidth $componentGrid "Component" 105 "Fixed" 85
Set-GridColumnWidth $componentGrid "Name" 175 "Fixed" 130
Set-GridColumnWidth $componentGrid "Balance" 130 "Fixed" 110
Set-GridColumnWidth $componentGrid "OutputCode" 130 "Fixed" 110
Set-GridColumnWidth $componentGrid "RepairText" 100 "Fill" 180
Set-GridColumnWidth $componentGrid "Active" 95 "Fixed" 80
$componentGrid.Columns[2].DefaultCellStyle.Alignment = [Windows.Forms.DataGridViewContentAlignment]::MiddleCenter
$componentGrid.Columns[3].DefaultCellStyle.Alignment = [Windows.Forms.DataGridViewContentAlignment]::MiddleCenter
$componentGrid.Columns[5].DefaultCellStyle.Alignment = [Windows.Forms.DataGridViewContentAlignment]::MiddleCenter
$componentBalancesPage.Controls.Add($componentGrid)

$componentHistoryGrid = New-Object Windows.Forms.DataGridView
$componentHistoryGrid.Location = New-Object Drawing.Point(10, 9)
$componentHistoryGrid.Size = New-Object Drawing.Size(954, 292)
$componentHistoryGrid.Anchor = "Top,Bottom,Left,Right"
$componentHistoryGrid.AllowUserToAddRows = $false
$componentHistoryGrid.AllowUserToDeleteRows = $false
$componentHistoryGrid.AllowUserToResizeRows = $false
$componentHistoryGrid.RowHeadersVisible = $false
$componentHistoryGrid.ReadOnly = $true
$componentHistoryGrid.SelectionMode = "FullRowSelect"
$componentHistoryGrid.AutoSizeColumnsMode = "None"
[void]$componentHistoryGrid.Columns.Add("Date", "Data")
[void]$componentHistoryGrid.Columns.Add("Component", "Componente")
[void]$componentHistoryGrid.Columns.Add("Type", "Movimento")
[void]$componentHistoryGrid.Columns.Add("Change", "Variação")
[void]$componentHistoryGrid.Columns.Add("Balance", "Saldo anterior → posterior")
[void]$componentHistoryGrid.Columns.Add("Invoice", "NF")
[void]$componentHistoryGrid.Columns.Add("Lots", "Lotes")
[void]$componentHistoryGrid.Columns.Add("Observation", "Observação")
Set-GridColumnWidth $componentHistoryGrid "Date" 120 "Fixed" 110
Set-GridColumnWidth $componentHistoryGrid "Component" 90 "Fixed" 80
Set-GridColumnWidth $componentHistoryGrid "Type" 105 "Fixed" 90
Set-GridColumnWidth $componentHistoryGrid "Change" 75 "Fixed" 65
Set-GridColumnWidth $componentHistoryGrid "Balance" 160 "Fixed" 140
Set-GridColumnWidth $componentHistoryGrid "Invoice" 80 "Fixed" 70
Set-GridColumnWidth $componentHistoryGrid "Lots" 105 "Fixed" 90
Set-GridColumnWidth $componentHistoryGrid "Observation" 100 "Fill" 200
$componentHistoryGrid.Columns[3].DefaultCellStyle.Alignment = [Windows.Forms.DataGridViewContentAlignment]::MiddleCenter
$componentHistoryGrid.Columns[4].DefaultCellStyle.Alignment = [Windows.Forms.DataGridViewContentAlignment]::MiddleCenter
$componentMovementsPage.Controls.Add($componentHistoryGrid)

$componentOperationsGrid = New-Object Windows.Forms.DataGridView
$componentOperationsGrid.Location = New-Object Drawing.Point(10, 9)
$componentOperationsGrid.Size = New-Object Drawing.Size(954, 292)
$componentOperationsGrid.Anchor = "Top,Bottom,Left,Right"
$componentOperationsGrid.AllowUserToAddRows = $false
$componentOperationsGrid.AllowUserToDeleteRows = $false
$componentOperationsGrid.AllowUserToResizeRows = $false
$componentOperationsGrid.RowHeadersVisible = $false
$componentOperationsGrid.ReadOnly = $true
$componentOperationsGrid.SelectionMode = "FullRowSelect"
$componentOperationsGrid.AutoSizeColumnsMode = "None"
[void]$componentOperationsGrid.Columns.Add("Date", "Data")
[void]$componentOperationsGrid.Columns.Add("Invoice", "NF")
[void]$componentOperationsGrid.Columns.Add("Lots", "Lotes")
[void]$componentOperationsGrid.Columns.Add("Quantity", "Unidades baixadas")
[void]$componentOperationsGrid.Columns.Add("Details", "Detalhes")
Set-GridColumnWidth $componentOperationsGrid "Date" 120 "Fixed" 110
Set-GridColumnWidth $componentOperationsGrid "Invoice" 85 "Fixed" 70
Set-GridColumnWidth $componentOperationsGrid "Lots" 170 "Fixed" 120
Set-GridColumnWidth $componentOperationsGrid "Quantity" 145 "Fixed" 125
Set-GridColumnWidth $componentOperationsGrid "Details" 100 "Fill" 280
$componentOperationsGrid.Columns[3].DefaultCellStyle.Alignment = [Windows.Forms.DataGridViewContentAlignment]::MiddleCenter
$componentOperationsPage.Controls.Add($componentOperationsGrid)

$descriptionsIntro = New-Object Windows.Forms.Label
$descriptionsIntro.Text = "Legenda completa usada nos arquivos gerados. Esta área é somente para consulta."
$descriptionsIntro.Location = New-Object Drawing.Point(18, 16)
$descriptionsIntro.Size = New-Object Drawing.Size(982, 30)
$descriptionsIntro.Anchor = "Top,Left,Right"
$tabDescriptions.Controls.Add($descriptionsIntro)

$descriptionsGrid = New-Object Windows.Forms.DataGridView
$descriptionsGrid.Location = New-Object Drawing.Point(18, 52)
$descriptionsGrid.Size = New-Object Drawing.Size(982, 435)
$descriptionsGrid.Anchor = "Top,Bottom,Left,Right"
$descriptionsGrid.AllowUserToAddRows = $false
$descriptionsGrid.AllowUserToDeleteRows = $false
$descriptionsGrid.AllowUserToResizeRows = $false
$descriptionsGrid.RowHeadersVisible = $false
$descriptionsGrid.ReadOnly = $true
$descriptionsGrid.AutoSizeColumnsMode = "None"
[void]$descriptionsGrid.Columns.Add("Code", "Código")
[void]$descriptionsGrid.Columns.Add("Description", "Descrição")
[void]$descriptionsGrid.Columns.Add("Note", "Observação")
Set-GridColumnWidth $descriptionsGrid "Code" 100 "Fixed" 85
Set-GridColumnWidth $descriptionsGrid "Description" 100 "Fill" 360
Set-GridColumnWidth $descriptionsGrid "Note" 200 "Fixed" 160
$tabDescriptions.Controls.Add($descriptionsGrid)

$combineIntro = New-Object Windows.Forms.Label
$combineIntro.Text = "Selecione duas ou mais mestres da mesma NF. Cada linha representa um lote e mantém sua própria manutenção."
$combineIntro.Location = New-Object Drawing.Point(18, 14)
$combineIntro.Size = New-Object Drawing.Size(982, 35)
$combineIntro.Anchor = "Top,Left,Right"
$tabCombine.Controls.Add($combineIntro)

$combineSelectionLabel = New-Object Windows.Forms.Label
$combineSelectionLabel.Text = "0 lote(s) selecionado(s)  •  0 mestre(s) serão atualizadas"
$combineSelectionLabel.Font = New-Object Drawing.Font("Segoe UI Semibold", 10)
$combineSelectionLabel.Location = New-Object Drawing.Point(18, 50)
$combineSelectionLabel.Size = New-Object Drawing.Size(982, 23)
$combineSelectionLabel.Anchor = "Top,Left,Right"
$tabCombine.Controls.Add($combineSelectionLabel)

$combineAddButton = New-Object Windows.Forms.Button
$combineAddButton.Text = "+  Adicionar planilhas..."
$combineAddButton.Location = New-Object Drawing.Point(18, 78)
$combineAddButton.Size = New-Object Drawing.Size(172, 34)
$combineAddButton.Tag = "Primary"
$tabCombine.Controls.Add($combineAddButton)

$combineRemoveButton = New-Object Windows.Forms.Button
$combineRemoveButton.Text = "−  Remover"
$combineRemoveButton.Location = New-Object Drawing.Point(200, 78)
$combineRemoveButton.Size = New-Object Drawing.Size(100, 34)
$combineRemoveButton.Tag = "Secondary"
$tabCombine.Controls.Add($combineRemoveButton)

$combineUpButton = New-Object Windows.Forms.Button
$combineUpButton.Text = "↑  Subir"
$combineUpButton.Location = New-Object Drawing.Point(310, 78)
$combineUpButton.Size = New-Object Drawing.Size(86, 34)
$combineUpButton.Tag = "Secondary"
$tabCombine.Controls.Add($combineUpButton)

$combineDownButton = New-Object Windows.Forms.Button
$combineDownButton.Text = "↓  Descer"
$combineDownButton.Location = New-Object Drawing.Point(406, 78)
$combineDownButton.Size = New-Object Drawing.Size(86, 34)
$combineDownButton.Tag = "Secondary"
$tabCombine.Controls.Add($combineDownButton)

$combineClearButton = New-Object Windows.Forms.Button
$combineClearButton.Text = "×  Limpar lista"
$combineClearButton.Location = New-Object Drawing.Point(502, 78)
$combineClearButton.Size = New-Object Drawing.Size(112, 34)
$combineClearButton.Tag = "Secondary"
$tabCombine.Controls.Add($combineClearButton)

$combineCopyQuantitiesButton = New-Object Windows.Forms.Button
$combineCopyQuantitiesButton.Text = "Copiar linha"
$combineCopyQuantitiesButton.Location = New-Object Drawing.Point(624, 78)
$combineCopyQuantitiesButton.Size = New-Object Drawing.Size(145, 34)
$combineCopyQuantitiesButton.Tag = "Secondary"
$tabCombine.Controls.Add($combineCopyQuantitiesButton)
$toolTip.SetToolTip($combineCopyQuantitiesButton, "Copia todas as quantidades da linha selecionada.")

$combinePasteQuantitiesButton = New-Object Windows.Forms.Button
$combinePasteQuantitiesButton.Text = "Colar linha"
$combinePasteQuantitiesButton.Location = New-Object Drawing.Point(779, 78)
$combinePasteQuantitiesButton.Size = New-Object Drawing.Size(145, 34)
$combinePasteQuantitiesButton.Tag = "Secondary"
$tabCombine.Controls.Add($combinePasteQuantitiesButton)
$toolTip.SetToolTip($combinePasteQuantitiesButton, "Cola as quantidades copiadas na linha selecionada.")

$combineBalanceCard = New-Object Windows.Forms.Panel
$combineBalanceCard.Location = New-Object Drawing.Point(18, 118)
$combineBalanceCard.Size = New-Object Drawing.Size(982, 40)
$combineBalanceCard.Anchor = "Top,Left,Right"
$combineBalanceCard.BorderStyle = [Windows.Forms.BorderStyle]::None
$tabCombine.Controls.Add($combineBalanceCard)

$combineConsumeBalanceCheck = New-Object Windows.Forms.CheckBox
$combineConsumeBalanceCheck.Text = "Consumir saldo ao concluir a união"
$combineConsumeBalanceCheck.Checked = $true
$combineConsumeBalanceCheck.Location = New-Object Drawing.Point(12, 8)
$combineConsumeBalanceCheck.Size = New-Object Drawing.Size(420, 24)
$combineConsumeBalanceCheck.Font = New-Object Drawing.Font("Segoe UI Semibold", 9.5)
$combineConsumeBalanceCheck.Anchor = "Top,Left"
$combineBalanceCard.Controls.Add($combineConsumeBalanceCheck)
$toolTip.SetToolTip($combineConsumeBalanceCheck, "Marcado: valida os reparos, consulta e baixa o saldo após a união. Desmarcado: não consulta o saldo e permite textos de REPARO não cadastrados, preservando-os na planilha unida.")

$combineBalanceStatus = New-Object Windows.Forms.Label
$combineBalanceStatus.Text = "SALDO: SERÁ CONSUMIDO"
$combineBalanceStatus.Font = New-Object Drawing.Font("Segoe UI Semibold", 9.2)
$combineBalanceStatus.Location = New-Object Drawing.Point(650, 8)
$combineBalanceStatus.Size = New-Object Drawing.Size(316, 24)
$combineBalanceStatus.Anchor = "Top,Right"
$combineBalanceStatus.TextAlign = [Drawing.ContentAlignment]::MiddleRight
$combineBalanceCard.Controls.Add($combineBalanceStatus)
$combineBalanceCard.Add_SizeChanged({ Set-GeneratorRoundedRegion $this 9 })
Set-GeneratorRoundedRegion $combineBalanceCard 9

$combineGrid = New-Object Windows.Forms.DataGridView
$combineGrid.Location = New-Object Drawing.Point(18, 166)
$combineGrid.Size = New-Object Drawing.Size(982, 193)
$combineGrid.Anchor = "Top,Bottom,Left,Right"
$combineGrid.AllowUserToAddRows = $false
$combineGrid.AllowUserToDeleteRows = $false
$combineGrid.AllowUserToResizeRows = $false
$combineGrid.AllowUserToOrderColumns = $false
$combineGrid.RowHeadersVisible = $false
$combineGrid.MultiSelect = $false
$combineGrid.SelectionMode = "CellSelect"
$combineGrid.EditMode = [Windows.Forms.DataGridViewEditMode]::EditOnEnter
$combineGrid.AutoSizeColumnsMode = "None"
$combineGrid.AutoGenerateColumns = $false
[void]$combineGrid.Columns.Add("Order", "Ordem")
[void]$combineGrid.Columns.Add("File", "Planilha mestre / lote")
$combineGrid.Columns[0].ReadOnly = $true
$combineGrid.Columns[0].MinimumWidth = 55
$combineGrid.Columns[0].Width = 60
$combineGrid.Columns[0].DefaultCellStyle.Alignment = [Windows.Forms.DataGridViewContentAlignment]::MiddleCenter
$combineGrid.Columns[1].ReadOnly = $true
$combineGrid.Columns[1].MinimumWidth = 220
$combineGrid.Columns[1].Width = 280
$tabCombine.Controls.Add($combineGrid)

$combineStatusLabel = New-Object Windows.Forms.Label
$combineStatusLabel.Text = "Resultado da última união"
$combineStatusLabel.Font = New-Object Drawing.Font("Segoe UI Semibold", 10)
$combineStatusLabel.Location = New-Object Drawing.Point(18, 370)
$combineStatusLabel.AutoSize = $true
$combineStatusLabel.Anchor = "Bottom,Left"
$tabCombine.Controls.Add($combineStatusLabel)

$previewCombineButton = New-Object Windows.Forms.Button
$previewCombineButton.Text = "Conferir primeiro"
$previewCombineButton.Location = New-Object Drawing.Point(675, 361)
$previewCombineButton.Size = New-Object Drawing.Size(158, 30)
$previewCombineButton.Anchor = "Bottom,Right"
$previewCombineButton.Tag = "Secondary"
$tabCombine.Controls.Add($previewCombineButton)
$toolTip.SetToolTip($previewCombineButton, "Valida lotes, NFs, séries, manutenções e a baixa prevista sem gravar arquivos ou saldos.")

$copyCombineStatusButton = New-Object Windows.Forms.Button
$copyCombineStatusButton.Text = "Copiar resultado"
$copyCombineStatusButton.Location = New-Object Drawing.Point(843, 361)
$copyCombineStatusButton.Size = New-Object Drawing.Size(157, 30)
$copyCombineStatusButton.Anchor = "Bottom,Right"
$copyCombineStatusButton.Tag = "Secondary"
$tabCombine.Controls.Add($copyCombineStatusButton)

$combineStatusText = New-Object Windows.Forms.TextBox
$combineStatusText.Location = New-Object Drawing.Point(18, 394)
$combineStatusText.Size = New-Object Drawing.Size(982, 93)
$combineStatusText.Anchor = "Bottom,Left,Right"
$combineStatusText.Multiline = $true
$combineStatusText.ReadOnly = $true
$combineStatusText.ScrollBars = "Vertical"
$combineStatusText.BorderStyle = [Windows.Forms.BorderStyle]::FixedSingle
$tabCombine.Controls.Add($combineStatusText)

foreach ($roundedPanel in @($masterCard, $destinationCard, $summaryCard, $componentActiveCard, $componentPendingCard, $componentOperationsCard, $combineBalanceCard)) {
    $roundedPanel.BorderStyle = [Windows.Forms.BorderStyle]::None
    $roundedPanel.Add_SizeChanged({ Set-GeneratorRoundedRegion $this 10 })
    Set-GeneratorRoundedRegion $roundedPanel 10
}

$footerPanel = New-Object Windows.Forms.Panel
$footerPanel.Location = New-Object Drawing.Point(0, 662)
$footerPanel.Size = New-Object Drawing.Size(1064, 79)
$footerPanel.Anchor = "None"
$footerPanel.Dock = [Windows.Forms.DockStyle]::Bottom
$form.Controls.Add($footerPanel)

$progressStatusLabel = New-Object Windows.Forms.Label
$progressStatusLabel.Text = "Pronto para gerar"
$progressStatusLabel.Location = New-Object Drawing.Point(20, 12)
$progressStatusLabel.Size = New-Object Drawing.Size(330, 20)
$footerPanel.Controls.Add($progressStatusLabel)

$progressBar = New-Object Windows.Forms.ProgressBar
$progressBar.Location = New-Object Drawing.Point(20, 38)
$progressBar.Size = New-Object Drawing.Size(330, 8)
$progressBar.Style = [Windows.Forms.ProgressBarStyle]::Continuous
$footerPanel.Controls.Add($progressBar)

$versionLabel = New-Object Windows.Forms.Label
$versionLabel.Text = "Versão $($script:AppVersion)"
$versionLabel.Location = New-Object Drawing.Point(20, 54)
$versionLabel.AutoSize = $true
$footerPanel.Controls.Add($versionLabel)

$openFolderButton = New-Object Windows.Forms.Button
$openFolderButton.Text = "↗  Abrir pasta"
$openFolderButton.Location = New-Object Drawing.Point(650, 20)
$openFolderButton.Size = New-Object Drawing.Size(126, 40)
$openFolderButton.Anchor = "Top,Right"
$openFolderButton.Tag = "Secondary"
$openFolderButton.Enabled = $false
$footerPanel.Controls.Add($openFolderButton)

$updateMasterButton = New-Object Windows.Forms.Button
$updateMasterButton.Text = "Atualizar somente a mestre"
$updateMasterButton.Location = New-Object Drawing.Point(575, 18)
$updateMasterButton.Size = New-Object Drawing.Size(205, 44)
$updateMasterButton.Anchor = "Top,Right"
$updateMasterButton.Tag = "Secondary"
$footerPanel.Controls.Add($updateMasterButton)

$generateButton = New-Object Windows.Forms.Button
$generateButton.Text = "✓  Validar e gerar 3 planilhas"
$generateButton.Location = New-Object Drawing.Point(790, 18)
$generateButton.Size = New-Object Drawing.Size(254, 44)
$generateButton.Anchor = "Top,Right"
$generateButton.Tag = "Primary"
$footerPanel.Controls.Add($generateButton)

$combineGenerateButton = New-Object Windows.Forms.Button
$combineGenerateButton.Text = "✓  Validar e juntar lotes"
$combineGenerateButton.Location = New-Object Drawing.Point(790, 18)
$combineGenerateButton.Size = New-Object Drawing.Size(254, 44)
$combineGenerateButton.Anchor = "Top,Right"
$combineGenerateButton.Tag = "Primary"
$combineGenerateButton.Visible = $false
$footerPanel.Controls.Add($combineGenerateButton)

# Layout compacto quando o Gerenciador está hospedado dentro da Central de Trabalho.
# Mantém Produto acessível, remove cabeçalho duplicado e deixa o conteúdo usar a área disponível.
if ($script:IsInProcessHosted) {
    $tabGenerate.Text = "Gerar"
    $tabGenerate.ToolTipText = "Gerar planilhas a partir de uma mestre CB5 ou TV5."
    $tabExtra.Text = "Manutenções"
    $tabExtra.ToolTipText = "Manutenções adicionais que podem atualizar a coluna REPARO da mestre."
    $tabComponents.Text = "Componentes"
    $tabComponents.ToolTipText = "Componentes a faturar, saldos, movimentos e uniões processadas."
    $tabCombine.Text = "Juntar lotes"
    $tabCombine.ToolTipText = "Unir duas ou mais mestres da mesma nota fiscal."
    $tabDescriptions.Text = "Códigos"
    $tabDescriptions.ToolTipText = "Legenda dos códigos utilizados nos arquivos gerados."

    $headerPanel.Height = 42
    $headerPanel.Size = New-Object Drawing.Size($headerPanel.Width, 42)
    $accentStrip.Height = 42
    $logoPicture.Visible = $false
    $title.Visible = $false
    $subtitle.Visible = $false
    $themeLabel.Visible = $false
    $themeCombo.Visible = $false

    $productLabel.Anchor = "Top,Left"
    $productLabel.Location = New-Object Drawing.Point(16, 12)
    $productCombo.Anchor = "Top,Left"
    $productCombo.Location = New-Object Drawing.Point(78, 6)
    $productCombo.Size = New-Object Drawing.Size(172, 28)

    $tabs.Location = New-Object Drawing.Point(8, 46)
    foreach ($page in @($tabGenerate, $tabExtra, $tabComponents, $tabCombine, $tabDescriptions)) {
        $page.AutoScroll = $true
        $page.AutoScrollMinSize = New-Object Drawing.Size(0, 0)
    }

    $footerPanel.Height = 56
    $footerPanel.Size = New-Object Drawing.Size($footerPanel.Width, 56)
    $versionLabel.Visible = $false
    $openFolderButton.Visible = $false
    $openFolderButton.Width = 0
    $progressStatusLabel.Top = 5
    $progressBar.Top = 27
    $generateButton.Height = 36
    $combineGenerateButton.Height = 36
    $updateMasterButton.Height = 36
}


$script:GeneratorResponsiveBusy = $false
$script:GeneratorResponsiveProfile = ""

function Get-GeneratorLogicalViewport {
    $dpi = 96
    try { if ($form.DeviceDpi -gt 0) { $dpi = [int]$form.DeviceDpi } } catch {}
    $w = [Math]::Max(1,[int]$form.ClientSize.Width)
    $h = [Math]::Max(1,[int]$form.ClientSize.Height)
    [pscustomobject]@{
        Dpi=$dpi
        Scale=[Math]::Round($dpi/96.0, 2)
        Width=$w
        Height=$h
        LogicalWidth=if ($script:IsInProcessHosted) { $w } else { [int][Math]::Round($w*96.0/$dpi) }
        LogicalHeight=if ($script:IsInProcessHosted) { $h } else { [int][Math]::Round($h*96.0/$dpi) }
    }
}

function Update-GeneratorResponsiveLayout {
    if (-not $script:IsInProcessHosted -or $script:GeneratorResponsiveBusy) { return }
    $script:GeneratorResponsiveBusy = $true
    try {
        $m = Get-GeneratorLogicalViewport
        $profile = if ($m.LogicalWidth -lt 900 -or $m.LogicalHeight -lt 560) { "Tight" } elseif ($m.LogicalWidth -lt 1120 -or $m.LogicalHeight -lt 700) { "Compact" } else { "Comfortable" }
        $script:GeneratorResponsiveProfile = $profile
        switch ($profile) {
            "Tight" {
                $form.Font = [Drawing.Font]::new("Segoe UI",8.2)
                $headerPanel.Height = 34; $accentStrip.Height = 34
                $productLabel.Location = [Drawing.Point]::new(10,9)
                $productCombo.Location = [Drawing.Point]::new(62,3); $productCombo.Size = [Drawing.Size]::new(145,26)
                $tabs.Location = [Drawing.Point]::new(5,37); $tabs.ItemSize = [Drawing.Size]::new(0,27); $tabs.Padding = [Drawing.Point]::new(8,3)
                $footerPanel.Height = 46
                $progressStatusLabel.Top = 3; $progressBar.Top = 23
                $generateButton.Height = 31; $combineGenerateButton.Height = 31; $updateMasterButton.Height = 31
                $generateButton.Width = 222; $combineGenerateButton.Width = 222; $updateMasterButton.Width = 180
            }
            "Compact" {
                $form.Font = [Drawing.Font]::new("Segoe UI",8.7)
                $headerPanel.Height = 38; $accentStrip.Height = 38
                $productLabel.Location = [Drawing.Point]::new(12,10)
                $productCombo.Location = [Drawing.Point]::new(69,5); $productCombo.Size = [Drawing.Size]::new(158,27)
                $tabs.Location = [Drawing.Point]::new(6,41); $tabs.ItemSize = [Drawing.Size]::new(0,29); $tabs.Padding = [Drawing.Point]::new(10,4)
                $footerPanel.Height = 50
                $progressStatusLabel.Top = 4; $progressBar.Top = 25
                $generateButton.Height = 33; $combineGenerateButton.Height = 33; $updateMasterButton.Height = 33
                $generateButton.Width = 238; $combineGenerateButton.Width = 238; $updateMasterButton.Width = 190
            }
            default {
                $form.Font = [Drawing.Font]::new("Segoe UI",9.25)
                $headerPanel.Height = 42; $accentStrip.Height = 42
                $productLabel.Location = [Drawing.Point]::new(16,12)
                $productCombo.Location = [Drawing.Point]::new(78,6); $productCombo.Size = [Drawing.Size]::new(172,28)
                $tabs.Location = [Drawing.Point]::new(8,46); $tabs.ItemSize = [Drawing.Size]::new(0,31); $tabs.Padding = [Drawing.Point]::new(14,5)
                $footerPanel.Height = 56
                $progressStatusLabel.Top = 5; $progressBar.Top = 27
                $generateButton.Height = 36; $combineGenerateButton.Height = 36; $updateMasterButton.Height = 36
                $generateButton.Width = 254; $combineGenerateButton.Width = 254; $updateMasterButton.Width = 205
            }
        }
        foreach ($page in @($tabGenerate,$tabExtra,$tabComponents,$tabCombine,$tabDescriptions)) { $page.AutoScroll = $true; $page.AutoScrollMinSize = [Drawing.Size]::new(0,0) }
    }
    catch {}
    finally { $script:GeneratorResponsiveBusy = $false }
}

function Update-RootLayout {
    if ($null -eq $form -or $null -eq $headerPanel -or $null -eq $tabs -or $null -eq $footerPanel) { return }
    Update-GeneratorResponsiveLayout

    $clientWidth = [Math]::Max(1, $form.ClientSize.Width)
    $headerPanel.Width = $clientWidth
    $tabs.Width = [Math]::Max(320, $clientWidth - (2 * $tabs.Left))
    $bottomGap = if ($script:IsInProcessHosted) { 4 } else { 10 }
    $tabs.Height = [Math]::Max(220, $footerPanel.Top - $tabs.Top - $bottomGap)

    $rightMargin = if ($script:IsInProcessHosted -and $script:GeneratorResponsiveProfile -eq "Tight") { 8 } elseif ($script:IsInProcessHosted) { 12 } else { 20 }
    $buttonGap = if ($script:IsInProcessHosted) { 7 } else { 10 }
    $mainButtonLeft = [Math]::Max($rightMargin, $footerPanel.ClientSize.Width - $generateButton.Width - $rightMargin)
    $mainButtonTop = [Math]::Max(4, [int](($footerPanel.ClientSize.Height - $generateButton.Height) / 2))
    foreach ($button in @($generateButton, $combineGenerateButton)) {
        $button.Left = $mainButtonLeft
        $button.Top = $mainButtonTop
    }
    $updateMasterButton.Left = [Math]::Max($rightMargin, $mainButtonLeft - $updateMasterButton.Width - $buttonGap)
    $updateMasterButton.Top = $mainButtonTop
    $openFolderButton.Left = [Math]::Max($rightMargin, $updateMasterButton.Left - $openFolderButton.Width - $buttonGap)
    $openFolderButton.Top = [Math]::Max(4, [int](($footerPanel.ClientSize.Height - $openFolderButton.Height) / 2))
    $progressWidth = [Math]::Max(80, $openFolderButton.Left - $progressBar.Left - 18)
    $progressBar.Width = $progressWidth
    $progressStatusLabel.Width = $progressWidth

    $footerPanel.BringToFront()
    if ($combineGenerateButton.Visible) { $combineGenerateButton.BringToFront() }
    elseif ($generateButton.Visible) { $generateButton.BringToFront() }
    Update-MasterCardLayout
}

$form.Add_Resize({ Update-RootLayout })
try { $form.Add_DpiChanged({ Update-RootLayout }) } catch {}
$footerPanel.Add_Resize({ Update-RootLayout })
Update-RootLayout

$tabs.Add_DrawItem({
    param($sender, $eventArgs)
    $page = $sender.TabPages[$eventArgs.Index]
    $selected = ($eventArgs.Index -eq $sender.SelectedIndex)
    $background = if ($selected) { $script:CurrentPalette.Accent } else { $script:CurrentPalette.Panel }
    $foreground = if ($selected) { $script:CurrentPalette.AccentText } else { $script:CurrentPalette.Text }
    $brush = New-Object Drawing.SolidBrush($background)
    try {
        $eventArgs.Graphics.FillRectangle($brush, $eventArgs.Bounds)
        [Windows.Forms.TextRenderer]::DrawText(
            $eventArgs.Graphics,
            $page.Text,
            $form.Font,
            $eventArgs.Bounds,
            $foreground,
            ([Windows.Forms.TextFormatFlags]::HorizontalCenter -bor [Windows.Forms.TextFormatFlags]::VerticalCenter -bor [Windows.Forms.TextFormatFlags]::EndEllipsis)
        )
    }
    finally { $brush.Dispose() }
})

$componentTabs.Add_DrawItem({
    param($sender, $eventArgs)
    $page = $sender.TabPages[$eventArgs.Index]
    $selected = ($eventArgs.Index -eq $sender.SelectedIndex)
    $background = if ($selected) { $script:CurrentPalette.Accent } else { $script:CurrentPalette.Panel }
    $foreground = if ($selected) { $script:CurrentPalette.AccentText } else { $script:CurrentPalette.Text }
    $brush = New-Object Drawing.SolidBrush($background)
    try {
        $eventArgs.Graphics.FillRectangle($brush, $eventArgs.Bounds)
        [Windows.Forms.TextRenderer]::DrawText(
            $eventArgs.Graphics,
            $page.Text,
            $form.Font,
            $eventArgs.Bounds,
            $foreground,
            ([Windows.Forms.TextFormatFlags]::HorizontalCenter -bor [Windows.Forms.TextFormatFlags]::VerticalCenter -bor [Windows.Forms.TextFormatFlags]::EndEllipsis)
        )
    }
    finally { $brush.Dispose() }
})

function Update-CombinedRowNumbers {
    for ($index = 0; $index -lt $combineGrid.Rows.Count; $index++) {
        $combineGrid.Rows[$index].Cells[0].Value = $index + 1
    }
}

function Move-CombinedGridRow {
    param([int]$Direction)
    if ($null -eq $combineGrid.CurrentRow) { return }
    [void]$combineGrid.EndEdit()
    $sourceIndex = $combineGrid.CurrentRow.Index
    $targetIndex = $sourceIndex + $Direction
    if ($targetIndex -lt 0 -or $targetIndex -ge $combineGrid.Rows.Count) { return }

    $sourceRow = $combineGrid.Rows[$sourceIndex]
    $values = [object[]]::new($combineGrid.Columns.Count)
    for ($column = 0; $column -lt $combineGrid.Columns.Count; $column++) {
        $values[$column] = $sourceRow.Cells[$column].Value
    }
    $path = [string]$sourceRow.Tag
    $combineGrid.Rows.RemoveAt($sourceIndex)
    $combineGrid.Rows.Insert($targetIndex, $values)
    $combineGrid.Rows[$targetIndex].Tag = $path
    $combineGrid.Rows[$targetIndex].Cells[1].ToolTipText = $path
    $combineGrid.CurrentCell = $combineGrid.Rows[$targetIndex].Cells[1]
    Update-CombinedRowNumbers
    Update-CombineSummary
}

function Update-CombinedProductInterface {
    param([ValidateSet("CB5", "TV5")][string]$Product)

    [void]$combineGrid.EndEdit()
    $script:CopiedCombinedQuantities = $null
    $combineGrid.Rows.Clear()
    while ($combineGrid.Columns.Count -gt 2) {
        $combineGrid.Columns.RemoveAt($combineGrid.Columns.Count - 1)
    }
    foreach ($definition in (Get-CombinedMaintenanceDefinitions $Product)) {
        $columnIndex = $combineGrid.Columns.Add("Extra_$($definition.Code)", $definition.Code)
        $combineGrid.Columns[$columnIndex].ReadOnly = $false
        $combineGrid.Columns[$columnIndex].MinimumWidth = 62
        $combineGrid.Columns[$columnIndex].Width = 70
        $combineGrid.Columns[$columnIndex].DefaultCellStyle.Alignment = [Windows.Forms.DataGridViewContentAlignment]::MiddleCenter
        $combineGrid.Columns[$columnIndex].ToolTipText = $definition.Description
        $combineGrid.Columns[$columnIndex].SortMode = [Windows.Forms.DataGridViewColumnSortMode]::NotSortable
    }
    $tabCombine.Text = "Juntar lotes"
    $combineIntro.Text = "Selecione duas ou mais mestres $Product da mesma NF. Cada linha representa um lote; informe as manutenções adicionais diretamente na linha correspondente. A ordem abaixo será mantida no arquivo final."
    $combineGenerateButton.Text = "✓  Validar e juntar lotes $Product"
    $combineStatusText.Text = "Adicione pelo menos duas planilhas mestre $Product para conferir ou juntar os lotes."
    Update-CombineSummary
}

function Update-ProductInterface {
    $selectedProduct = [string]$productCombo.SelectedItem
    if ([string]::IsNullOrWhiteSpace($selectedProduct)) { $selectedProduct = "CB5" }
    $script:CurrentProduct = $selectedProduct
    [void]$extraGrid.EndEdit()
    $extraGrid.Rows.Clear()
    $descriptionsGrid.Rows.Clear()
    if ($null -ne $componentSearchText) { $componentSearchText.Clear() }
    $masterText.Text = ""
    $masterFileNameLabel.Text = "Nenhuma mestre selecionada"
    $statusText.Text = "Selecione uma planilha mestre $selectedProduct para conferir, atualizar ou gerar os arquivos."
    Update-CombinedProductInterface $selectedProduct
    $summaryProductValue.Text = $selectedProduct

    if ($selectedProduct -eq "TV5") {
        $script:MaintenanceDefinitions = $script:TV5MaintenanceDefinitions
        $subtitle.Text = "A mestre TV5 gera um arquivo com as abas ORÇAMENTO, MANUTENÇÃO e TABELA."
        $outputInfo.Text = "A planilha TV5 será salva na Área de Trabalho com a NF lida do nome da mestre."
        $infoBox.Text = "Gerar TV5 continua exigindo NF no nome e nas colunas. Para acrescentar manutenções antes de enviar ao faturamento, use Atualizar somente a mestre: esse caminho aceita a NF ainda vazia e altera apenas REPARO."
        $extraIntro.Text = "Informe as quantidades: linhas 9 a 11 usam a coluna B; da linha 12 em diante usa-se a coluna C. A maior quantidade será aplicada primeiro; a linha 8 vem da mestre."
        $descriptionsIntro.Text = "Esta é a TABELA completa que será mantida como a terceira aba do arquivo TV5."
        $generateButton.Text = "✓  Validar e gerar TV5"
        $updateMasterButton.Text = "Atualizar só a mestre TV5"
        foreach ($definition in $script:TV5MaintenanceDefinitions | Where-Object { $_.Additional }) {
            [void]$extraGrid.Rows.Add($definition.Code, "", $definition.Description, $definition.Note)
        }
        foreach ($definition in $script:TV5MaintenanceDefinitions) {
            [void]$descriptionsGrid.Rows.Add($definition.Code, $definition.Description, $definition.Note)
        }
    }
    else {
        $script:MaintenanceDefinitions = $script:CB5MaintenanceDefinitions
        $subtitle.Text = "A mestre CB5 gera Manutenção, Chip1 e Chip2 conforme as operadoras informadas."
        $outputInfo.Text = "As planilhas de Manutenção, Chip1 e Chip2 serão salvas na Área de Trabalho deste computador."
        $infoBox.Text = "Gerar CB5 mantém todas as validações atuais. Para apenas acrescentar as manutenções na coluna REPARO, sem criar arquivos finais, use Atualizar somente a mestre."
        $extraIntro.Text = "Digite na coluna amarela QUANTIDADE quantas peças receberão cada manutenção extra. Cada código começa na primeira peça; a maior quantidade será aplicada primeiro."
        $descriptionsIntro.Text = "Esta é a legenda completa que será mantida como Planilha2 no arquivo de Manutenção."
        $generateButton.Text = "✓  Validar e gerar 3 planilhas"
        $updateMasterButton.Text = "Atualizar só a mestre CB5"
        foreach ($definition in $script:CB5MaintenanceDefinitions | Where-Object { $null -eq $_.Level }) {
            [void]$extraGrid.Rows.Add($definition.Code, "", $definition.Description, $definition.Note)
        }
        foreach ($definition in $script:CB5MaintenanceDefinitions) {
            [void]$descriptionsGrid.Rows.Add($definition.Code, $definition.Description, $definition.Note)
        }
    }
    Apply-AppTheme
    Update-LiveSummary
    if ($script:UiReady) { Save-AppSettings }
}

$productCombo.Add_SelectedIndexChanged({ Update-ProductInterface })
$themeCombo.Add_SelectedIndexChanged({
    if ($script:UiReady) {
        Apply-AppTheme
        Save-AppSettings
    }
})
Update-ProductInterface
$script:UiReady = $true
Apply-AppTheme
Save-AppSettings

$masterButton.Add_Click({
    $dialog = New-Object Windows.Forms.OpenFileDialog
    $dialog.Title = "Selecione a planilha mestre do $($script:CurrentProduct)"
    $dialog.Filter = "Planilhas Excel (*.xlsx;*.xlsm)|*.xlsx;*.xlsm|Todos os arquivos (*.*)|*.*"
    $dialog.InitialDirectory = Get-DialogInitialDirectory
    if ($dialog.ShowDialog() -eq [Windows.Forms.DialogResult]::OK) {
        Remember-InputPath $dialog.FileName
        $masterText.Text = $dialog.FileName
        $masterFileNameLabel.Text = [IO.Path]::GetFileName($dialog.FileName)
        $toolTip.SetToolTip($masterFileNameLabel, $dialog.FileName)
        Update-LiveSummary
        Set-UiProgress 0 "Mestre selecionada; confira as manutenções" "Normal"
    }
})

$openDestinationAction = {
    $destination = if (-not [string]::IsNullOrWhiteSpace($script:LastOutputDirectory)) { $script:LastOutputDirectory } else { [Environment]::GetFolderPath([Environment+SpecialFolder]::DesktopDirectory) }
    if ([IO.Directory]::Exists($destination)) {
        try { Start-Process -FilePath "explorer.exe" -ArgumentList ('"' + $destination + '"') } catch {
            [Windows.Forms.MessageBox]::Show("Não foi possível abrir a pasta de destino.`r`n$($_.Exception.Message)", "Abrir destino", [Windows.Forms.MessageBoxButtons]::OK, [Windows.Forms.MessageBoxIcon]::Error) | Out-Null
        }
    }
}
$openDestinationCardButton.Add_Click($openDestinationAction)
$openFolderButton.Add_Click($openDestinationAction)

$extraGrid.Add_CellEndEdit({ Update-LiveSummary })
$extraGrid.Add_CellValueChanged({ if ($script:UiReady) { Update-LiveSummary } })
$combineGrid.Add_CellEndEdit({ Update-CombineSummary })
$combineGrid.Add_CellValueChanged({ if ($script:UiReady) { Update-CombineSummary } })
$combineConsumeBalanceCheck.Add_CheckedChanged({ if ($script:UiReady) { Update-CombineSummary } })

$componentLaunchButton.Add_Click({
    $component = Get-SelectedBillingComponent
    if ($null -eq $component) {
        [Windows.Forms.MessageBox]::Show("Selecione um componente para lançar a quantidade.", "Componentes a faturar", "OK", "Information") | Out-Null
        return
    }
    $values = Show-BillingQuantityDialog -Component $component
    if ($null -eq $values) { return }
    try {
        $workingStore = Copy-BillingComponentStore $script:BillingComponentStore
        [void](Add-BillingManualQuantity -Store $workingStore -Id ([string]$component.Id) -Quantity ([int]$values.Quantity) -Observation ([string]$values.Observation))
        Write-BillingComponentStore -Store $workingStore -Path $script:BillingComponentStorePath
        $script:BillingComponentStore = $workingStore
        Update-BillingComponentsView
        [Windows.Forms.MessageBox]::Show("Quantidade lançada. O saldo ficará aguardando a baixa no Juntar lotes.", "Componentes a faturar", "OK", "Information") | Out-Null
    }
    catch {
        [Windows.Forms.MessageBox]::Show($_.Exception.Message, "Componentes a faturar", "OK", "Error") | Out-Null
    }
})

$componentAdjustButton.Add_Click({
    $component = Get-SelectedBillingComponent
    if ($null -eq $component) {
        [Windows.Forms.MessageBox]::Show("Selecione um componente para ajustar o saldo.", "Componentes a faturar", "OK", "Information") | Out-Null
        return
    }
    $values = Show-BillingQuantityDialog -Component $component -SetExactBalance
    if ($null -eq $values) { return }
    try {
        $workingStore = Copy-BillingComponentStore $script:BillingComponentStore
        [void](Set-BillingManualBalance -Store $workingStore -Id ([string]$component.Id) -NewBalance ([int]$values.Quantity) -Observation ([string]$values.Observation))
        Write-BillingComponentStore -Store $workingStore -Path $script:BillingComponentStorePath
        $script:BillingComponentStore = $workingStore
        Update-BillingComponentsView
        [Windows.Forms.MessageBox]::Show("Saldo ajustado e registrado no histórico.", "Componentes a faturar", "OK", "Information") | Out-Null
    }
    catch {
        [Windows.Forms.MessageBox]::Show($_.Exception.Message, "Componentes a faturar", "OK", "Error") | Out-Null
    }
})

$componentNewButton.Add_Click({
    $values = Show-BillingComponentDialog -DefaultProduct $script:CurrentProduct -ExistingComponent $null
    if ($null -eq $values) { return }
    try {
        $workingStore = Copy-BillingComponentStore $script:BillingComponentStore
        [void](Add-BillingComponent -Store $workingStore -Product ([string]$values.Product) -Component ([string]$values.Component) -Name ([string]$values.Name) -InitialBalance ([int]$values.InitialBalance) -OutputCode ([string]$values.OutputCode) -RepairText ([string]$values.RepairText) -Aliases @($values.Aliases))
        Write-BillingComponentStore -Store $workingStore -Path $script:BillingComponentStorePath
        $script:BillingComponentStore = $workingStore
        if ([string]$productCombo.SelectedItem -ne [string]$values.Product) { $productCombo.SelectedItem = [string]$values.Product }
        else { Update-BillingComponentsView }
        [Windows.Forms.MessageBox]::Show("Componente cadastrado. Ele já pode ser reconhecido pelo texto do REPARO.", "Componentes a faturar", "OK", "Information") | Out-Null
    }
    catch {
        [Windows.Forms.MessageBox]::Show($_.Exception.Message, "Componentes a faturar", "OK", "Error") | Out-Null
    }
})

$componentEditButton.Add_Click({
    $component = Get-SelectedBillingComponent
    if ($null -eq $component) {
        [Windows.Forms.MessageBox]::Show("Selecione um componente para editar.", "Componentes a faturar", "OK", "Information") | Out-Null
        return
    }
    $values = Show-BillingComponentDialog -DefaultProduct ([string]$component.Produto) -ExistingComponent $component
    if ($null -eq $values) { return }
    try {
        $workingStore = Copy-BillingComponentStore $script:BillingComponentStore
        [void](Update-BillingComponent -Store $workingStore -Id ([string]$component.Id) -Name ([string]$values.Name) -OutputCode ([string]$values.OutputCode) -RepairText ([string]$values.RepairText) -Aliases @($values.Aliases) -Active ([bool]$values.Active))
        Write-BillingComponentStore -Store $workingStore -Path $script:BillingComponentStorePath
        $script:BillingComponentStore = $workingStore
        Update-BillingComponentsView
        [Windows.Forms.MessageBox]::Show("Cadastro atualizado.", "Componentes a faturar", "OK", "Information") | Out-Null
    }
    catch {
        [Windows.Forms.MessageBox]::Show($_.Exception.Message, "Componentes a faturar", "OK", "Error") | Out-Null
    }
})

$componentGrid.Add_CellDoubleClick({
    param($sender, $eventArgs)
    if ($eventArgs.RowIndex -ge 0) { $componentEditButton.PerformClick() }
})

$componentSearchText.Add_TextChanged({
    if ($script:UiReady) { Update-BillingComponentsView }
})

$componentSearchClearButton.Add_Click({
    $componentSearchText.Clear()
    $componentSearchText.Focus()
})

$componentBackupButton.Add_Click({
    $dialog = New-Object Windows.Forms.SaveFileDialog
    $dialog.Title = "Exportar backup dos componentes a faturar"
    $dialog.Filter = "Backup JSON (*.json)|*.json"
    $dialog.DefaultExt = "json"
    $dialog.AddExtension = $true
    $dialog.FileName = "componentes-a-faturar-backup-$([DateTime]::Now.ToString('yyyyMMdd-HHmmss')).json"
    $dialog.InitialDirectory = Get-DialogInitialDirectory
    if ($dialog.ShowDialog() -ne [Windows.Forms.DialogResult]::OK) { return }
    try {
        Write-BillingComponentStore -Store (Copy-BillingComponentStore $script:BillingComponentStore) -Path $dialog.FileName
        Remember-InputPath $dialog.FileName
        [Windows.Forms.MessageBox]::Show("Backup exportado com sucesso.`r`n`r`n$($dialog.FileName)", "Componentes a faturar", "OK", "Information") | Out-Null
    }
    catch {
        [Windows.Forms.MessageBox]::Show($_.Exception.Message, "Exportar backup", "OK", "Error") | Out-Null
    }
})

$componentRestoreButton.Add_Click({
    $dialog = New-Object Windows.Forms.OpenFileDialog
    $dialog.Title = "Restaurar backup dos componentes a faturar"
    $dialog.Filter = "Backup JSON (*.json)|*.json|Todos os arquivos (*.*)|*.*"
    $dialog.InitialDirectory = Get-DialogInitialDirectory
    if ($dialog.ShowDialog() -ne [Windows.Forms.DialogResult]::OK) { return }
    try {
        $importedStore = Read-BillingComponentStore -Path $dialog.FileName
        $currentSummary = Get-BillingDashboardSummary $script:BillingComponentStore
        $importedSummary = Get-BillingDashboardSummary $importedStore
        $message = "O backup selecionado substituirá toda a base atual de componentes, saldos, movimentações e uniões processadas.`r`n`r`nBase atual: $($currentSummary.Componentes) componentes e $($currentSummary.UnioesProcessadas) uniões.`r`nBackup: $($importedSummary.Componentes) componentes e $($importedSummary.UnioesProcessadas) uniões.`r`n`r`nDeseja continuar?"
        $answer = [Windows.Forms.MessageBox]::Show($message, "Restaurar backup", [Windows.Forms.MessageBoxButtons]::YesNo, [Windows.Forms.MessageBoxIcon]::Warning)
        if ($answer -ne [Windows.Forms.DialogResult]::Yes) { return }
        Write-BillingComponentStore -Store $importedStore -Path $script:BillingComponentStorePath
        $script:BillingComponentStore = Read-BillingComponentStore -Path $script:BillingComponentStorePath
        Remember-InputPath $dialog.FileName
        Update-BillingComponentsView
        [Windows.Forms.MessageBox]::Show("Backup restaurado com sucesso.", "Componentes a faturar", "OK", "Information") | Out-Null
    }
    catch {
        [Windows.Forms.MessageBox]::Show($_.Exception.Message, "Restaurar backup", "OK", "Error") | Out-Null
    }
})

$combineAddButton.Add_Click({
    $dialog = New-Object Windows.Forms.OpenFileDialog
    $product = $script:CurrentProduct
    $dialog.Title = "Selecione duas ou mais planilhas mestres $product da mesma NF"
    $dialog.Filter = "Planilhas Excel (*.xlsx;*.xlsm)|*.xlsx;*.xlsm|Todos os arquivos (*.*)|*.*"
    $dialog.Multiselect = $true
    $dialog.InitialDirectory = Get-DialogInitialDirectory
    if ($dialog.ShowDialog() -eq [Windows.Forms.DialogResult]::OK) {
        try {
            if ($dialog.FileNames.Count -gt 0) { Remember-InputPath $dialog.FileNames[0] }
            foreach ($path in $dialog.FileNames) {
                Assert-MasterMatchesProduct $path $product
            }
            foreach ($path in $dialog.FileNames) {
                $alreadyAdded = $false
                foreach ($row in $combineGrid.Rows) {
                    if ([string]::Equals([string]$row.Tag, $path, [StringComparison]::OrdinalIgnoreCase)) {
                        $alreadyAdded = $true
                        break
                    }
                }
                if ($alreadyAdded) { continue }

                $rowIndex = $combineGrid.Rows.Add()
                $row = $combineGrid.Rows[$rowIndex]
                $row.Tag = $path
                $row.Cells[0].Value = $rowIndex + 1
                $row.Cells[1].Value = [IO.Path]::GetFileName($path)
                $row.Cells[1].ToolTipText = $path
            }
            Update-CombinedRowNumbers
            if ($combineGrid.Rows.Count -gt 0 -and $null -eq $combineGrid.CurrentCell) {
                $combineGrid.CurrentCell = $combineGrid.Rows[0].Cells[1]
            }
            Update-CombineSummary
        }
        catch {
            [Windows.Forms.MessageBox]::Show(
                $_.Exception.Message,
                "Seleção de planilhas",
                [Windows.Forms.MessageBoxButtons]::OK,
                [Windows.Forms.MessageBoxIcon]::Error
            ) | Out-Null
        }
    }
})

$combineRemoveButton.Add_Click({
    if ($null -ne $combineGrid.CurrentRow) {
        $combineGrid.Rows.RemoveAt($combineGrid.CurrentRow.Index)
        Update-CombinedRowNumbers
        Update-CombineSummary
    }
})

$combineUpButton.Add_Click({ Move-CombinedGridRow -Direction -1 })
$combineDownButton.Add_Click({ Move-CombinedGridRow -Direction 1 })
$combineCopyQuantitiesButton.Add_Click({
    [void]$combineGrid.EndEdit()
    if ($null -eq $combineGrid.CurrentRow) {
        [Windows.Forms.MessageBox]::Show("Selecione a linha que possui as quantidades a copiar.", "Copiar quantidades", "OK", "Information") | Out-Null
        return
    }
    $values = [object[]]::new([Math]::Max(0, $combineGrid.Columns.Count - 2))
    for ($column = 2; $column -lt $combineGrid.Columns.Count; $column++) {
        $values[$column - 2] = $combineGrid.CurrentRow.Cells[$column].Value
    }
    $script:CopiedCombinedQuantities = [pscustomobject]@{
        Product = $script:CurrentProduct
        Source = [string]$combineGrid.CurrentRow.Cells[1].Value
        Values = $values
    }
    Set-UiProgress $progressBar.Value "Quantidades copiadas da linha selecionada" "Success"
})

$combinePasteQuantitiesButton.Add_Click({
    [void]$combineGrid.EndEdit()
    if ($null -eq $script:CopiedCombinedQuantities) {
        [Windows.Forms.MessageBox]::Show("Copie primeiro as quantidades de outra linha.", "Colar quantidades", "OK", "Information") | Out-Null
        return
    }
    if ($null -eq $combineGrid.CurrentRow) {
        [Windows.Forms.MessageBox]::Show("Selecione a linha que receberá as quantidades.", "Colar quantidades", "OK", "Information") | Out-Null
        return
    }
    if ([string]$script:CopiedCombinedQuantities.Product -ne $script:CurrentProduct -or @($script:CopiedCombinedQuantities.Values).Count -ne ($combineGrid.Columns.Count - 2)) {
        [Windows.Forms.MessageBox]::Show("As quantidades copiadas pertencem a outro produto. Copie novamente a partir de uma linha $($script:CurrentProduct).", "Colar quantidades", "OK", "Warning") | Out-Null
        return
    }
    for ($column = 2; $column -lt $combineGrid.Columns.Count; $column++) {
        $combineGrid.CurrentRow.Cells[$column].Value = $script:CopiedCombinedQuantities.Values[$column - 2]
    }
    Update-CombineSummary
    Set-UiProgress $progressBar.Value "Quantidades coladas na linha selecionada" "Success"
})

$combineClearButton.Add_Click({
    [void]$combineGrid.EndEdit()
    $combineGrid.Rows.Clear()
    $combineStatusText.Text = ""
    Update-CombineSummary
})

$copyStatusButton.Add_Click({ Copy-ResultText $statusText.Text })
$copyCombineStatusButton.Add_Click({ Copy-ResultText $combineStatusText.Text })

$tabs.Add_SelectedIndexChanged({
    $isCombineTab = ($tabs.SelectedTab -eq $tabCombine)
    $isComponentsTab = ($tabs.SelectedTab -eq $tabComponents)
    $isDescriptionsTab = ($tabs.SelectedTab -eq $tabDescriptions)
    $canUpdateMaster = ($tabs.SelectedTab -eq $tabGenerate -or $tabs.SelectedTab -eq $tabExtra)
    $canGenerate = (-not $isCombineTab -and -not $isComponentsTab -and -not $isDescriptionsTab)
    $generateButton.Visible = $canGenerate
    $updateMasterButton.Visible = $canUpdateMaster
    $combineGenerateButton.Visible = $isCombineTab
    $openFolderButton.Visible = (-not $isComponentsTab -and -not $isDescriptionsTab)
    if ($isCombineTab) { $combineGenerateButton.BringToFront() }
    elseif ($generateButton.Visible) { $generateButton.BringToFront() }
    if ($updateMasterButton.Visible) { $updateMasterButton.BringToFront() }
    Update-RootLayout
    $tabs.Invalidate()
})

$form.Add_KeyDown({
    param($sender, $eventArgs)
    if ($eventArgs.Control -and $eventArgs.KeyCode -eq [Windows.Forms.Keys]::O) {
        $masterButton.PerformClick()
        $eventArgs.SuppressKeyPress = $true
    }
})

$previewMasterButton.Add_Click({
    $excel = $null
    $currentStage = "Preparação da conferência"
    $previewMasterButton.Enabled = $false
    $updateMasterButton.Enabled = $false
    $generateButton.Enabled = $false
    $productCombo.Enabled = $false
    $themeCombo.Enabled = $false
    $tabs.Enabled = $false
    $form.UseWaitCursor = $true
    $statusText.Text = "Conferindo a mestre sem gravar..."
    Set-UiProgress 5 "Preparando a conferência sem gravação..." "Normal"
    [Windows.Forms.Application]::DoEvents()
    try {
        $product = $script:CurrentProduct
        $masterPath = $masterText.Text.Trim()
        if (-not [IO.File]::Exists($masterPath)) { throw "Selecione uma planilha mestre válida." }
        if ([IO.Path]::GetExtension($masterPath).ToLowerInvariant() -notin @(".xlsx", ".xlsm")) {
            throw "Selecione uma planilha mestre .xlsx ou .xlsm."
        }

        [void]$extraGrid.EndEdit()
        $additional = Get-AdditionalMaintenance $extraGrid
        $currentStage = "Abertura do Microsoft Excel"
        try { $excel = New-Object -ComObject Excel.Application }
        catch { throw "Não foi possível abrir o Microsoft Excel. Esta conferência precisa do Excel instalado no Windows." }
        $excel.Visible = $false
        $excel.DisplayAlerts = $false
        $excel.ScreenUpdating = $false
        try { $excel.EnableEvents = $false } catch {}
        try { $excel.AskToUpdateLinks = $false } catch {}

        $currentStage = "Leitura da mestre $product"
        Set-UiProgress 35 "Validando estrutura, peças e manutenções..." "Normal"
        if ($product -eq "TV5") {
            $masterData = Read-TV5MasterWorkbook $excel $masterPath -AllowBlankInvoices
        }
        else {
            $masterData = Read-MasterWorkbook $excel $masterPath
        }
        $originalRepairs = Get-RepairSnapshot -Items @($masterData.Items)
        if ($product -eq "TV5") {
            Apply-TV5AdditionalMaintenance $masterData.Items $additional
        }
        else {
            Apply-AdditionalMaintenance $masterData.Items $additional
        }
        $changes = @(Get-RepairPreviewRows -Items @($masterData.Items) -OriginalRepairs $originalRepairs)

        $summary = [Collections.Generic.List[string]]::new()
        $summary.Add("CONFERÊNCIA — NENHUM ARQUIVO FOI ALTERADO")
        $summary.Add("Produto: $product")
        $summary.Add("Mestre: $([IO.Path]::GetFileName($masterPath))")
        $summary.Add("Lote: $($masterData.Lot)")
        $summary.Add("Peças validadas: $($masterData.Items.Count)")
        $summary.Add("Manutenções informadas: $(Get-AdditionalDisplayText $additional)")
        if ($product -eq "TV5") { $summary.Add("NF: não é exigida nesta conferência; continuará obrigatória na geração final") }
        $summary.Add("")
        if ($changes.Count -eq 0) {
            $summary.Add("Nenhuma série teria o REPARO alterado.")
        }
        else {
            $summary.Add("$($changes.Count) série(s) teriam o REPARO alterado:")
            foreach ($change in $changes) {
                $summary.Add("$($change.Serie): $($change.Antes)  →  $($change.Depois)")
            }
        }
        $summary.Add("")
        $summary.Add("A regra atual foi preservada: cada quantidade começa na primeira peça da mestre.")
        $statusText.Text = $summary -join "`r`n"
        Set-UiProgress 100 "Conferência concluída; nada foi gravado" "Success"
    }
    catch {
        $statusText.Text = "ERRO EM: $currentStage`r`n$($_.Exception.Message)"
        Set-UiProgress 0 "Erro em: $currentStage" "Error"
        [Windows.Forms.MessageBox]::Show("Etapa: $currentStage`r`n`r`n$($_.Exception.Message)", "Conferir sem gravar", "OK", "Error") | Out-Null
    }
    finally {
        if ($null -ne $excel) {
            try { $excel.Quit() } catch {}
            Release-ComObject $excel
        }
        [GC]::Collect()
        [GC]::WaitForPendingFinalizers()
        $form.UseWaitCursor = $false
        $previewMasterButton.Enabled = $true
        $updateMasterButton.Enabled = $true
        $generateButton.Enabled = $true
        $productCombo.Enabled = $true
        $themeCombo.Enabled = $true
        $tabs.Enabled = $true
    }
})

$updateMasterButton.Add_Click({
    $excel = $null
    $temporaryDirectory = $null
    $rollbackPath = $null
    $masterPath = ""
    $commitStarted = $false
    $currentStage = "Preparação da atualização da mestre"
    $updateMasterButton.Enabled = $false
    $generateButton.Enabled = $false
    $productCombo.Enabled = $false
    $themeCombo.Enabled = $false
    $tabs.Enabled = $false
    $form.UseWaitCursor = $true
    $statusText.Text = "Validando a mestre para atualizar somente REPARO..."
    Set-UiProgress 5 "Preparando a atualização da mestre..." "Normal"
    [Windows.Forms.Application]::DoEvents()
    try {
        $product = $script:CurrentProduct
        $masterPath = $masterText.Text.Trim()
        if (-not [IO.File]::Exists($masterPath)) { throw "Selecione uma planilha mestre válida." }
        if ([IO.Path]::GetExtension($masterPath).ToLowerInvariant() -notin @(".xlsx", ".xlsm")) {
            throw "Para atualizar a mestre, selecione um arquivo .xlsx ou .xlsm."
        }

        [void]$extraGrid.EndEdit()
        $additional = Get-AdditionalMaintenance $extraGrid
        if ($additional.Count -eq 0) {
            throw "Informe pelo menos uma quantidade na aba Manutenções. Sem manutenção, não há nada para atualizar na mestre."
        }

        $currentStage = "Abertura do Microsoft Excel"
        try { $excel = New-Object -ComObject Excel.Application }
        catch { throw "Não foi possível abrir o Microsoft Excel. Esta função precisa do Excel instalado no Windows." }
        $excel.Visible = $false
        $excel.DisplayAlerts = $false
        $excel.ScreenUpdating = $false
        try { $excel.EnableEvents = $false } catch {}
        try { $excel.AskToUpdateLinks = $false } catch {}

        $currentStage = "Leitura da mestre $product"
        Set-UiProgress 25 "Conferindo estrutura e manutenções..." "Normal"
        if ($product -eq "TV5") {
            $masterData = Read-TV5MasterWorkbook $excel $masterPath -AllowBlankInvoices
            Apply-TV5AdditionalMaintenance $masterData.Items $additional
        }
        else {
            $masterData = Read-MasterWorkbook $excel $masterPath
            Apply-AdditionalMaintenance $masterData.Items $additional
        }

        $message = "Confira antes de atualizar:`r`n`r`nProduto: $product`r`nLote: $($masterData.Lot)`r`nPeças: $($masterData.Items.Count)`r`nManutenções: $(Get-AdditionalDisplayText $additional)`r`nMestre: $([IO.Path]::GetFileName($masterPath))`r`n`r`nSomente a coluna REPARO será gravada. Nenhuma planilha final será gerada e nenhuma baixa de componentes será feita agora."
        $answer = [Windows.Forms.MessageBox]::Show($message, "Atualizar somente a mestre", [Windows.Forms.MessageBoxButtons]::YesNo, [Windows.Forms.MessageBoxIcon]::Question)
        if ($answer -ne [Windows.Forms.DialogResult]::Yes) {
            $statusText.Text = "Operação cancelada. A mestre não foi alterada."
            Set-UiProgress 0 "Atualização cancelada; nenhum arquivo foi alterado" "Warning"
            return
        }

        $currentStage = "Preparação da substituição segura"
        Set-UiProgress 48 "Preparando cópia e reversão temporária..." "Normal"
        Assert-FileAvailableForReplace $masterPath
        $temporaryDirectory = [IO.Path]::Combine([IO.Path]::GetTempPath(), "GeradorMestre_" + [Guid]::NewGuid().ToString("N"))
        [void][IO.Directory]::CreateDirectory($temporaryDirectory)
        $rollbackPath = [IO.Path]::Combine($temporaryDirectory, "Mestre original" + [IO.Path]::GetExtension($masterPath))
        $temporaryMasterPath = [IO.Path]::Combine($temporaryDirectory, "Mestre atualizada" + [IO.Path]::GetExtension($masterPath))
        Copy-Item -LiteralPath $masterPath -Destination $rollbackPath
        Save-UpdatedMasterCopy $excel $masterPath $masterData.Items $temporaryMasterPath

        $currentStage = "Gravação da mestre"
        Set-UiProgress 85 "Gravando somente a coluna REPARO..." "Normal"
        Assert-FileAvailableForReplace $masterPath
        $commitStarted = $true
        Move-Item -LiteralPath $temporaryMasterPath -Destination $masterPath -Force
        Assert-GeneratedFile $masterPath "da mestre atualizada"
        $commitStarted = $false

        $summary = [Collections.Generic.List[string]]::new()
        $summary.Add("MESTRE ATUALIZADA")
        $summary.Add("Produto: $product")
        $summary.Add("Lote: $($masterData.Lot)")
        $summary.Add("Peças: $($masterData.Items.Count)")
        $summary.Add("Arquivo: $([IO.Path]::GetFileName($masterPath))")
        $summary.Add("Alteração: somente a coluna REPARO")
        $summary.Add("")
        foreach ($extra in $additional) { $summary.Add("$($extra.Code): $($extra.Quantity) primeira(s) peça(s)") }
        $summary.Add("")
        $summary.Add("NF e arquivos finais continuam pendentes. A baixa dos componentes ocorrerá somente ao Juntar lotes.")
        $statusText.Text = $summary -join "`r`n"
        Set-UiProgress 100 "Mestre atualizada com sucesso" "Success"
        [Windows.Forms.MessageBox]::Show("A mestre $product foi atualizada com segurança. Somente a coluna REPARO foi alterada.", "Atualizar somente a mestre", [Windows.Forms.MessageBoxButtons]::OK, [Windows.Forms.MessageBoxIcon]::Information) | Out-Null
    }
    catch {
        if ($commitStarted -and -not [string]::IsNullOrWhiteSpace($rollbackPath) -and [IO.File]::Exists($rollbackPath) -and -not [string]::IsNullOrWhiteSpace($masterPath)) {
            try { Copy-Item -LiteralPath $rollbackPath -Destination $masterPath -Force } catch {}
        }
        $errorMessage = $_.Exception.Message
        $statusText.Text = "ERRO EM: $currentStage`r`n$errorMessage"
        Set-UiProgress 0 "Erro em: $currentStage" "Error"
        [Windows.Forms.MessageBox]::Show("Etapa: $currentStage`r`n`r`n$errorMessage", "Atualizar somente a mestre", [Windows.Forms.MessageBoxButtons]::OK, [Windows.Forms.MessageBoxIcon]::Error) | Out-Null
    }
    finally {
        if ($null -ne $excel) {
            try { $excel.Quit() } catch {}
            Release-ComObject $excel
        }
        if ($null -ne $temporaryDirectory -and [IO.Directory]::Exists($temporaryDirectory)) {
            try { Remove-Item -LiteralPath $temporaryDirectory -Recurse -Force } catch {}
        }
        [GC]::Collect()
        [GC]::WaitForPendingFinalizers()
        $form.UseWaitCursor = $false
        $updateMasterButton.Enabled = $true
        $generateButton.Enabled = $true
        $productCombo.Enabled = $true
        $themeCombo.Enabled = $true
        $tabs.Enabled = $true
    }
})

$generateButton.Add_Click({
    $excel = $null
    $temporaryDirectory = $null
    $rollbackPaths = @{}
    $updateMaster = $false
    $temporaryMasterPath = $null
    $currentStage = "Preparação"
    $generateButton.Enabled = $false
    $productCombo.Enabled = $false
    $themeCombo.Enabled = $false
    $tabs.Enabled = $false
    $form.UseWaitCursor = $true
    $statusText.Text = "Validando a planilha mestre..."
    Set-UiProgress 5 "Preparando a validação..." "Normal"
    [Windows.Forms.Application]::DoEvents()
    try {
        $product = $script:CurrentProduct
        $masterPath = $masterText.Text.Trim()
        $outputDirectory = [Environment]::GetFolderPath([Environment+SpecialFolder]::DesktopDirectory)
        if (-not [IO.File]::Exists($masterPath)) { throw "Selecione uma planilha mestre válida." }
        if ([string]::IsNullOrWhiteSpace($outputDirectory)) { throw "O Windows não informou o caminho da Área de Trabalho." }
        if (-not [IO.Directory]::Exists($outputDirectory)) { [void][IO.Directory]::CreateDirectory($outputDirectory) }

        $currentStage = "Leitura das manutenções adicionais"
        [void]$extraGrid.EndEdit()
        $additional = Get-AdditionalMaintenance $extraGrid
        $updateMaster = ($additional.Count -gt 0)
        Set-UiProgress 12 "Manutenções adicionais conferidas" "Normal"
        $currentStage = "Abertura do Microsoft Excel"
        try {
            $excel = New-Object -ComObject Excel.Application
        }
        catch {
            throw "Não foi possível abrir o Microsoft Excel. Esta versão precisa do Excel instalado no Windows."
        }
        $excel.Visible = $false
        $excel.DisplayAlerts = $false
        $excel.ScreenUpdating = $false
        try { $excel.EnableEvents = $false } catch {}
        try { $excel.AskToUpdateLinks = $false } catch {}
        Set-UiProgress 20 "Microsoft Excel aberto em segundo plano" "Normal"

        $currentStage = "Validação da planilha mestre"
        $invoiceNumber = $null
        if ($product -eq "TV5") {
            $invoiceNumber = Get-TV5InvoiceNumberFromFileName $masterPath
            $masterData = Read-TV5MasterWorkbook $excel $masterPath
            Assert-ValidFilePart $masterData.Lot "lote"
            Apply-TV5AdditionalMaintenance $masterData.Items $additional
            $outputNames = @("TV5 - NF $invoiceNumber.xlsx")
        }
        else {
            $masterData = Read-MasterWorkbook $excel $masterPath
            Assert-ValidFilePart $masterData.Lot "lote"
            Assert-ValidFilePart $masterData.Operator1Name "nome da OPERADORA1"
            Assert-ValidFilePart $masterData.Operator2Name "nome da OPERADORA2"
            Apply-AdditionalMaintenance $masterData.Items $additional
            $outputNames = @(
                "CB5 - Lote $($masterData.Lot) - Manutençao.xlsx",
                "Chip1 CB5 Lotes $($masterData.Lot) - $($masterData.Operator1Name).xls",
                "Chip2 CB5 Lotes $($masterData.Lot) - $($masterData.Operator2Name).xls"
            )
        }
        $outputPaths = @($outputNames | ForEach-Object { [IO.Path]::Combine($outputDirectory, $_) })
        Set-UiProgress 35 "$($masterData.Items.Count) peças validadas no lote $($masterData.Lot)" "Normal"

        $currentStage = "Verificação dos arquivos existentes"
        $existing = @($outputPaths | Where-Object { [IO.File]::Exists($_) })
        foreach ($path in $existing) { Assert-FileAvailableForReplace $path }
        if ($updateMaster) { Assert-FileAvailableForReplace $masterPath }
        Set-UiProgress 40 "Aguardando sua confirmação" "Warning"
        if (-not (Show-GenerationConfirmation $product $masterPath $masterData $additional $outputNames $existing.Count)) {
            $statusText.Text = "Operação cancelada. Nenhum arquivo foi alterado."
            Set-UiProgress 0 "Operação cancelada; nenhum arquivo foi alterado" "Warning"
            return
        }
        $temporaryDirectory = [IO.Path]::Combine([IO.Path]::GetTempPath(), "GeradorPlanilhas_" + [Guid]::NewGuid().ToString("N"))
        [void][IO.Directory]::CreateDirectory($temporaryDirectory)
        if ($existing.Count -gt 0 -or $updateMaster) {
            $currentStage = "Preparação da substituição"
            Set-UiProgress 48 "Preparando a substituição segura..." "Normal"
            $rollbackDirectory = [IO.Path]::Combine($temporaryDirectory, "ReversaoTemporaria")
            [void][IO.Directory]::CreateDirectory($rollbackDirectory)
            for ($rollbackIndex = 0; $rollbackIndex -lt $existing.Count; $rollbackIndex++) {
                $path = $existing[$rollbackIndex]
                $rollbackPath = [IO.Path]::Combine($rollbackDirectory, ("Saida {0:D2} original - {1}" -f ($rollbackIndex + 1), [IO.Path]::GetFileName($path)))
                Copy-Item -LiteralPath $path -Destination $rollbackPath
                $rollbackPaths[$path] = $rollbackPath
            }
            if ($updateMaster) {
                $masterRollbackPath = [IO.Path]::Combine($rollbackDirectory, "Mestre original - $([IO.Path]::GetFileName($masterPath))")
                Copy-Item -LiteralPath $masterPath -Destination $masterRollbackPath
                $rollbackPaths[$masterPath] = $masterRollbackPath
            }
        }
        $temporaryPaths = @($outputNames | ForEach-Object { [IO.Path]::Combine($temporaryDirectory, $_) })
        if ($updateMaster) {
            $currentStage = "Preparação da mestre atualizada"
            Set-UiProgress 55 "Preparando a mestre atualizada..." "Normal"
            $temporaryMasterPath = [IO.Path]::Combine($temporaryDirectory, "Mestre atualizada$([IO.Path]::GetExtension($masterPath))")
            Save-UpdatedMasterCopy $excel $masterPath $masterData.Items $temporaryMasterPath
        }

        if ($product -eq "TV5") {
            $currentStage = "Geração da planilha TV5"
            $statusText.Text = "Gerando ORÇAMENTO, MANUTENÇÃO e TABELA..."
            Set-UiProgress 72 "Gerando ORÇAMENTO, MANUTENÇÃO e TABELA..." "Normal"
            [Windows.Forms.Application]::DoEvents()
            Save-TV5Workbook $excel $masterData.Items $temporaryPaths[0]
            Assert-GeneratedFile $temporaryPaths[0] "TV5"
        }
        else {
            $currentStage = "Geração da planilha de Manutenção"
            $statusText.Text = "Gerando Manutenção..."
            Set-UiProgress 60 "Gerando Manutenção..." "Normal"
            [Windows.Forms.Application]::DoEvents()
            Save-MaintenanceWorkbook $excel $masterData.Items $temporaryPaths[0]
            Assert-GeneratedFile $temporaryPaths[0] "de Manutenção"
            $currentStage = "Geração da planilha Chip1 $($masterData.Operator1Name)"
            $statusText.AppendText("`r`nGerando Chip1 $($masterData.Operator1Name)...")
            Set-UiProgress 72 "Gerando Chip1 $($masterData.Operator1Name)..." "Normal"
            [Windows.Forms.Application]::DoEvents()
            Save-Chip1Workbook $excel $masterData.Items $temporaryPaths[1]
            Assert-GeneratedFile $temporaryPaths[1] "Chip1 $($masterData.Operator1Name)"
            $currentStage = "Geração da planilha Chip2 $($masterData.Operator2Name)"
            $statusText.AppendText("`r`nGerando Chip2 $($masterData.Operator2Name)...")
            Set-UiProgress 82 "Gerando Chip2 $($masterData.Operator2Name)..." "Normal"
            [Windows.Forms.Application]::DoEvents()
            Save-Chip2Workbook $excel $masterData.Items $temporaryPaths[2]
            Assert-GeneratedFile $temporaryPaths[2] "Chip2 $($masterData.Operator2Name)"
        }

        $currentStage = "Gravação dos arquivos"
        Set-UiProgress 92 "Gravando os arquivos com segurança..." "Normal"
        foreach ($path in $existing) { Assert-FileAvailableForReplace $path }
        if ($updateMaster) { Assert-FileAvailableForReplace $masterPath }
        $transactions = [Collections.Generic.List[object]]::new()
        for ($fileIndex = 0; $fileIndex -lt $outputPaths.Count; $fileIndex++) {
            $transactions.Add([pscustomobject]@{
                TemporaryPath = $temporaryPaths[$fileIndex]
                TargetPath = $outputPaths[$fileIndex]
                Existed = [IO.File]::Exists($outputPaths[$fileIndex])
                RollbackPath = if ($rollbackPaths.ContainsKey($outputPaths[$fileIndex])) { $rollbackPaths[$outputPaths[$fileIndex]] } else { $null }
            })
        }
        if ($updateMaster) {
            $transactions.Add([pscustomobject]@{
                TemporaryPath = $temporaryMasterPath
                TargetPath = $masterPath
                Existed = $true
                RollbackPath = $rollbackPaths[$masterPath]
            })
        }
        $committedTransactions = [Collections.Generic.List[object]]::new()
        try {
            foreach ($transaction in $transactions) {
                Move-Item -LiteralPath $transaction.TemporaryPath -Destination $transaction.TargetPath -Force
                $committedTransactions.Add($transaction)
            }
        }
        catch {
            foreach ($transaction in $committedTransactions) {
                try {
                    if ($transaction.Existed -and $null -ne $transaction.RollbackPath -and [IO.File]::Exists($transaction.RollbackPath)) {
                        Copy-Item -LiteralPath $transaction.RollbackPath -Destination $transaction.TargetPath -Force
                    }
                    elseif (-not $transaction.Existed -and [IO.File]::Exists($transaction.TargetPath)) {
                        Remove-Item -LiteralPath $transaction.TargetPath -Force
                    }
                }
                catch {}
            }
            throw
        }
        for ($fileIndex = 0; $fileIndex -lt $outputPaths.Count; $fileIndex++) {
            Assert-GeneratedFile $outputPaths[$fileIndex] "na Área de Trabalho"
        }
        if ($updateMaster) { Assert-GeneratedFile $masterPath "da mestre atualizada" }

        $currentStage = "Conclusão"
        $counts = $masterData.Items | Group-Object Repair | Sort-Object Name
        $summary = [Collections.Generic.List[string]]::new()
        $summary.Add("CONCLUÍDO")
        $summary.Add((Get-BillingSummary $product $masterData $additional))
        $summary.Add("")
        $summary.Add("Lote: $($masterData.Lot)")
        if ($product -eq "TV5") { $summary.Add("NF do nome: $invoiceNumber") }
        $summary.Add("Peças: $($masterData.Items.Count)")
        $summary.Add("Destino: $outputDirectory")
        foreach ($count in $counts) { $summary.Add("$($count.Name): $($count.Count)") }
        foreach ($extra in $additional) { $summary.Add("Extra $($extra.Code): $($extra.Quantity) primeiras peças") }
        if ($updateMaster) { $summary.Add("Mestre atualizada: $([IO.Path]::GetFileName($masterPath))") }
        $summary.Add("")
        foreach ($outputName in $outputNames) { $summary.Add($outputName) }
        $statusText.Text = $summary -join "`r`n"
        $script:LastOutputDirectory = $outputDirectory
        $openFolderButton.Enabled = $true
        Set-UiProgress 100 "Geração concluída com sucesso" "Success"
        $successMessage = if ($product -eq "TV5") { "A planilha TV5 foi gerada com sucesso." } else { "As três planilhas CB5 foram geradas com sucesso." }
        if ($updateMaster) { $successMessage += " A mestre também foi atualizada." }
        [Windows.Forms.MessageBox]::Show(
            $successMessage,
            "Gerenciador de Planilhas",
            [Windows.Forms.MessageBoxButtons]::OK,
            [Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
    }
    catch {
        $errorMessage = $_.Exception.Message
        $statusText.Text = "ERRO EM: $currentStage`r`n$errorMessage"
        Set-UiProgress 0 "Erro em: $currentStage" "Error"
        [Windows.Forms.MessageBox]::Show(
            "Etapa: $currentStage`r`n`r`n$errorMessage",
            "Gerenciador de Planilhas",
            [Windows.Forms.MessageBoxButtons]::OK,
            [Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
    }
    finally {
        if ($null -ne $excel) {
            try { $excel.Quit() } catch {}
            Release-ComObject $excel
        }
        if ($null -ne $temporaryDirectory -and [IO.Directory]::Exists($temporaryDirectory)) {
            try { Remove-Item -LiteralPath $temporaryDirectory -Recurse -Force } catch {}
        }
        [GC]::Collect()
        [GC]::WaitForPendingFinalizers()
        [GC]::Collect()
        [GC]::WaitForPendingFinalizers()
        $form.UseWaitCursor = $false
        $generateButton.Enabled = $true
        $productCombo.Enabled = $true
        $themeCombo.Enabled = $true
        $tabs.Enabled = $true
    }
})

$previewCombineButton.Add_Click({
    $excel = $null
    $currentStage = "Preparação da conferência da união"
    $previewCombineButton.Enabled = $false
    $combineGenerateButton.Enabled = $false
    $productCombo.Enabled = $false
    $themeCombo.Enabled = $false
    $tabs.Enabled = $false
    $form.UseWaitCursor = $true
    $combineStatusText.Text = "Conferindo os lotes sem gravar..."
    Set-UiProgress 5 "Preparando a conferência da união..." "Normal"
    [Windows.Forms.Application]::DoEvents()
    try {
        $product = $script:CurrentProduct
        $consumeBalance = [bool]$combineConsumeBalanceCheck.Checked
        [void]$combineGrid.EndEdit()
        if ($combineGrid.Rows.Count -lt 2) {
            throw "Adicione pelo menos duas planilhas mestres $product para conferir a união."
        }

        $pathSeen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        foreach ($row in $combineGrid.Rows) {
            $masterPath = [string]$row.Tag
            if (-not [IO.File]::Exists($masterPath)) {
                throw "A planilha '$($row.Cells[1].Value)' não foi encontrada. Remova-a da lista e selecione novamente."
            }
            Assert-MasterMatchesProduct $masterPath $product
            if (-not $pathSeen.Add($masterPath)) {
                throw "A mesma planilha foi adicionada mais de uma vez: $([IO.Path]::GetFileName($masterPath))."
            }
        }

        $currentStage = "Abertura do Microsoft Excel"
        try { $excel = New-Object -ComObject Excel.Application }
        catch { throw "Não foi possível abrir o Microsoft Excel. Esta conferência precisa do Excel instalado no Windows." }
        $excel.Visible = $false
        $excel.DisplayAlerts = $false
        $excel.ScreenUpdating = $false
        try { $excel.EnableEvents = $false } catch {}
        try { $excel.AskToUpdateLinks = $false } catch {}

        $records = [Collections.Generic.List[object]]::new()
        $combinedItems = [Collections.Generic.List[object]]::new()
        $lotSeen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        $seriesSeen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        $chip1Seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        $chip2Seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        $expectedInvoiceKey = $null
        $displayInvoiceNumber = $null
        $validatedRecordNumber = 0

        foreach ($row in $combineGrid.Rows) {
            $validatedRecordNumber++
            $masterPath = [string]$row.Tag
            $currentStage = "Validação de $([IO.Path]::GetFileName($masterPath))"
            $combineStatusText.Text = "Conferindo $([IO.Path]::GetFileName($masterPath))..."
            $validationPercent = 20 + [int](50 * ($validatedRecordNumber / [double]$combineGrid.Rows.Count))
            Set-UiProgress $validationPercent "Conferindo lote $validatedRecordNumber de $($combineGrid.Rows.Count)..." "Normal"
            [Windows.Forms.Application]::DoEvents()

            $invoiceNumber = Get-InvoiceNumberFromFileName $masterPath $product
            $invoiceKey = Get-InvoiceComparisonKey $invoiceNumber
            if ($null -eq $expectedInvoiceKey) {
                $expectedInvoiceKey = $invoiceKey
                $displayInvoiceNumber = $invoiceNumber
            }
            elseif ($invoiceKey -ne $expectedInvoiceKey) {
                throw "As planilhas selecionadas não possuem a mesma NF. Encontradas NF $displayInvoiceNumber e NF $invoiceNumber."
            }

            if ($product -eq "TV5") {
                $masterData = Read-TV5MasterWorkbook $excel $masterPath -AllowUnknownRepair:(-not $consumeBalance)
            }
            else {
                $masterData = Read-MasterWorkbook $excel $masterPath -RequireInvoices -AllowUnknownRepair:(-not $consumeBalance)
            }
            Assert-ValidFilePart $masterData.Lot "lote"
            if (-not $lotSeen.Add($masterData.Lot)) {
                throw "O lote $($masterData.Lot) aparece em mais de uma planilha selecionada."
            }
            $exitInvoiceKeys = @($masterData.Items | ForEach-Object { Get-InvoiceComparisonKey $_.ExitInvoice } | Sort-Object -Unique)
            if ($exitInvoiceKeys.Count -ne 1) {
                throw "O lote $($masterData.Lot) possui mais de um valor na coluna NF DE SAÍDA."
            }
            if ($exitInvoiceKeys[0] -ne $expectedInvoiceKey) {
                throw "No lote $($masterData.Lot), a NF DE SAÍDA da planilha não corresponde à NF $displayInvoiceNumber informada no nome do arquivo."
            }

            $additional = Get-CombinedAdditionalMaintenance $row $product
            if ($product -eq "TV5") {
                Apply-TV5AdditionalMaintenance $masterData.Items $additional
            }
            else {
                Apply-AdditionalMaintenance $masterData.Items $additional
            }
            foreach ($item in $masterData.Items) {
                if (-not $seriesSeen.Add($item.Series)) { throw "A SÉRIE $($item.Series) aparece em mais de um lote selecionado." }
                if ($product -eq "CB5") {
                    if (-not $chip1Seen.Add($item.Iccid1)) { throw "O ICCID1 $($item.Iccid1) aparece em mais de um lote selecionado." }
                    if (-not $chip2Seen.Add($item.Iccid2)) { throw "O ICCID2 $($item.Iccid2) aparece em mais de um lote selecionado." }
                }
                $combinedItems.Add($item)
            }
            $records.Add([pscustomobject]@{
                Path = $masterPath
                MasterData = $masterData
                Additional = $additional
                UpdateMaster = ($additional.Count -gt 0)
            })
        }

        $currentStage = if ($consumeBalance) { "Conferência dos componentes a faturar" } else { "Registro da união sem consumo de saldo" }
        $operationLots = @($records | ForEach-Object { [string]$_.MasterData.Lot })
        $billingOperationKey = Get-BillingOperationKey -Product $product -Invoice $displayInvoiceNumber -Lots $operationLots
        $deductionPlan = if ($consumeBalance) {
            Get-BillingDeductionPlan -Store $script:BillingComponentStore -Product $product -Items $combinedItems -OperationKey $billingOperationKey
        }
        else {
            Get-BillingNoDeductionPlan -Store $script:BillingComponentStore -Product $product -OperationKey $billingOperationKey
        }
        if (-not [bool]$deductionPlan.Valido) {
            $details = @($deductionPlan.Erros | ForEach-Object { "  • $_" }) -join "`r`n"
            throw "O saldo a faturar não é suficiente para concluir a união. Ajuste ou lance as quantidades na aba Componentes:`r`n$details"
        }

        $summary = [Collections.Generic.List[string]]::new()
        $summary.Add("CONFERÊNCIA DA UNIÃO — NADA FOI GRAVADO")
        $summary.Add("Produto: $product")
        $summary.Add("NF: $displayInvoiceNumber")
        $summary.Add("Lotes: $($records.Count)")
        $summary.Add("Peças totais: $($combinedItems.Count)")
        $summary.Add("Arquivo previsto: $product - NF $displayInvoiceNumber.xlsx")
        $summary.Add("")
        foreach ($record in $records) {
            $masterAction = if ($record.UpdateMaster) { "mestre seria atualizada" } else { "mestre permaneceria intacta" }
            $summary.Add("Lote $($record.MasterData.Lot): $($record.MasterData.Items.Count) peças | $(Get-AdditionalDisplayText $record.Additional) | $masterAction")
        }
        $summary.Add("")
        $summary.Add("Componentes a faturar:")
        if ([bool]$deductionPlan.JaAplicada) {
            $summary.Add("Esta união já foi processada; nenhum saldo seria descontado novamente.")
        }
        elseif (-not [bool]$deductionPlan.ConsumirSaldo) {
            $summary.Add("Opção desmarcada: o saldo não seria consultado nem alterado. Textos de REPARO não cadastrados seriam preservados sem bloquear a união.")
        }
        elseif (@($deductionPlan.Linhas).Count -eq 0) {
            $summary.Add("Nenhum componente controlado foi encontrado; a união seria apenas registrada contra repetição.")
        }
        else {
            foreach ($deduction in @($deductionPlan.Linhas)) {
                $summary.Add("$($deduction.Componente) — $($deduction.Nome): -$($deduction.Quantidade) | $($deduction.SaldoAnterior) → $($deduction.SaldoPosterior)")
            }
        }
        $summary.Add("")
        $summary.Add("Nenhuma mestre, planilha final ou quantidade foi alterada nesta conferência.")
        $combineStatusText.Text = $summary -join "`r`n"
        Set-UiProgress 100 "Conferência da união concluída; nada foi gravado" "Success"
    }
    catch {
        $combineStatusText.Text = "ERRO EM: $currentStage`r`n$($_.Exception.Message)"
        Set-UiProgress 0 "Erro em: $currentStage" "Error"
        [Windows.Forms.MessageBox]::Show("Etapa: $currentStage`r`n`r`n$($_.Exception.Message)", "Conferir união sem gravar", "OK", "Error") | Out-Null
    }
    finally {
        if ($null -ne $excel) {
            try { $excel.Quit() } catch {}
            Release-ComObject $excel
        }
        [GC]::Collect()
        [GC]::WaitForPendingFinalizers()
        $form.UseWaitCursor = $false
        $previewCombineButton.Enabled = $true
        $combineGenerateButton.Enabled = $true
        $productCombo.Enabled = $true
        $themeCombo.Enabled = $true
        $tabs.Enabled = $true
    }
})

$combineGenerateButton.Add_Click({
    $excel = $null
    $temporaryDirectory = $null
    $outputRollbackPath = $null
    $billingStoreRollbackPath = $null
    $billingTemporaryStorePath = $null
    $billingPendingStore = $null
    $billingStoreWillChange = $false
    $deductionPlan = $null
    $billingOperationKey = ""
    $operationLots = @()
    $currentStage = "Preparação da união"
    $combineGenerateButton.Enabled = $false
    $productCombo.Enabled = $false
    $themeCombo.Enabled = $false
    $tabs.Enabled = $false
    $form.UseWaitCursor = $true
    $combineStatusText.Text = "Validando as planilhas mestres..."
    Set-UiProgress 5 "Preparando a união de lotes..." "Normal"
    [Windows.Forms.Application]::DoEvents()
    try {
        $product = $script:CurrentProduct
        $consumeBalance = [bool]$combineConsumeBalanceCheck.Checked
        [void]$combineGrid.EndEdit()
        if ($combineGrid.Rows.Count -lt 2) {
            throw "Adicione pelo menos duas planilhas mestres $product para juntar os lotes."
        }

        $outputDirectory = [Environment]::GetFolderPath([Environment+SpecialFolder]::DesktopDirectory)
        if ([string]::IsNullOrWhiteSpace($outputDirectory)) { throw "O Windows não informou o caminho da Área de Trabalho." }
        if (-not [IO.Directory]::Exists($outputDirectory)) { [void][IO.Directory]::CreateDirectory($outputDirectory) }

        $pathSeen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        foreach ($row in $combineGrid.Rows) {
            $masterPath = [string]$row.Tag
            if (-not [IO.File]::Exists($masterPath)) {
                throw "A planilha '$($row.Cells[1].Value)' não foi encontrada. Remova-a da lista e selecione novamente."
            }
            Assert-MasterMatchesProduct $masterPath $product
            if (-not $pathSeen.Add($masterPath)) {
                throw "A mesma planilha foi adicionada mais de uma vez: $([IO.Path]::GetFileName($masterPath))."
            }
        }
        Set-UiProgress 12 "$($combineGrid.Rows.Count) arquivos selecionados" "Normal"

        $currentStage = "Abertura do Microsoft Excel"
        try {
            $excel = New-Object -ComObject Excel.Application
        }
        catch {
            throw "Não foi possível abrir o Microsoft Excel. Esta versão precisa do Excel instalado no Windows."
        }
        $excel.Visible = $false
        $excel.DisplayAlerts = $false
        $excel.ScreenUpdating = $false
        try { $excel.EnableEvents = $false } catch {}
        try { $excel.AskToUpdateLinks = $false } catch {}
        Set-UiProgress 20 "Microsoft Excel aberto em segundo plano" "Normal"

        $records = [Collections.Generic.List[object]]::new()
        $combinedItems = [Collections.Generic.List[object]]::new()
        $lotSeen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        $seriesSeen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        $chip1Seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        $chip2Seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        $expectedInvoiceKey = $null
        $displayInvoiceNumber = $null

        $validatedRecordNumber = 0
        foreach ($row in $combineGrid.Rows) {
            $validatedRecordNumber++
            $masterPath = [string]$row.Tag
            $currentStage = "Validação de $([IO.Path]::GetFileName($masterPath))"
            $combineStatusText.Text = "Validando $([IO.Path]::GetFileName($masterPath))..."
            $validationPercent = 20 + [int](18 * ($validatedRecordNumber / [double]$combineGrid.Rows.Count))
            Set-UiProgress $validationPercent "Validando lote $validatedRecordNumber de $($combineGrid.Rows.Count)..." "Normal"
            [Windows.Forms.Application]::DoEvents()

            $invoiceNumber = Get-InvoiceNumberFromFileName $masterPath $product
            $invoiceKey = Get-InvoiceComparisonKey $invoiceNumber
            if ($null -eq $expectedInvoiceKey) {
                $expectedInvoiceKey = $invoiceKey
                $displayInvoiceNumber = $invoiceNumber
            }
            elseif ($invoiceKey -ne $expectedInvoiceKey) {
                throw "As planilhas selecionadas não possuem a mesma NF. Encontradas NF $displayInvoiceNumber e NF $invoiceNumber."
            }

            if ($product -eq "TV5") {
                $masterData = Read-TV5MasterWorkbook $excel $masterPath -AllowUnknownRepair:(-not $consumeBalance)
            }
            else {
                $masterData = Read-MasterWorkbook $excel $masterPath -RequireInvoices -AllowUnknownRepair:(-not $consumeBalance)
            }
            Assert-ValidFilePart $masterData.Lot "lote"
            if (-not $lotSeen.Add($masterData.Lot)) {
                throw "O lote $($masterData.Lot) aparece em mais de uma planilha selecionada."
            }

            $exitInvoiceKeys = @($masterData.Items | ForEach-Object { Get-InvoiceComparisonKey $_.ExitInvoice } | Sort-Object -Unique)
            if ($exitInvoiceKeys.Count -ne 1) {
                throw "O lote $($masterData.Lot) possui mais de um valor na coluna NF DE SAÍDA."
            }
            if ($exitInvoiceKeys[0] -ne $expectedInvoiceKey) {
                throw "No lote $($masterData.Lot), a NF DE SAÍDA da planilha não corresponde à NF $displayInvoiceNumber informada no nome do arquivo."
            }

            $additional = Get-CombinedAdditionalMaintenance $row $product
            $updateMaster = ($additional.Count -gt 0)
            if ($updateMaster) { Assert-FileAvailableForReplace $masterPath }
            if ($product -eq "TV5") {
                Apply-TV5AdditionalMaintenance $masterData.Items $additional
            }
            else {
                Apply-AdditionalMaintenance $masterData.Items $additional
            }
            foreach ($item in $masterData.Items) {
                if (-not $seriesSeen.Add($item.Series)) {
                    throw "A SÉRIE $($item.Series) aparece em mais de um lote selecionado."
                }
                if ($product -eq "CB5") {
                    if (-not $chip1Seen.Add($item.Iccid1)) {
                        throw "O ICCID1 $($item.Iccid1) aparece em mais de um lote selecionado."
                    }
                    if (-not $chip2Seen.Add($item.Iccid2)) {
                        throw "O ICCID2 $($item.Iccid2) aparece em mais de um lote selecionado."
                    }
                }
                $combinedItems.Add($item)
            }
            $records.Add([pscustomobject]@{
                Path = $masterPath
                MasterData = $masterData
                Additional = $additional
                UpdateMaster = $updateMaster
                TemporaryMasterPath = $null
                RollbackMasterPath = $null
            })
        }

        $currentStage = if ($consumeBalance) { "Conferência dos componentes a faturar" } else { "Registro da união sem consumo de saldo" }
        $operationLots = @($records | ForEach-Object { [string]$_.MasterData.Lot })
        $billingOperationKey = Get-BillingOperationKey -Product $product -Invoice $displayInvoiceNumber -Lots $operationLots
        $deductionPlan = if ($consumeBalance) {
            Get-BillingDeductionPlan -Store $script:BillingComponentStore -Product $product -Items $combinedItems -OperationKey $billingOperationKey
        }
        else {
            Get-BillingNoDeductionPlan -Store $script:BillingComponentStore -Product $product -OperationKey $billingOperationKey
        }
        if (-not [bool]$deductionPlan.Valido) {
            $details = @($deductionPlan.Erros | ForEach-Object { "  • $_" }) -join "`r`n"
            throw "O saldo a faturar não é suficiente para concluir a união. Ajuste ou lance as quantidades na aba Componentes:`r`n$details"
        }
        # Toda união bem-sucedida é registrada, inclusive quando nenhuma baixa é
        # necessária. Assim, o mesmo conjunto de lotes nunca vira uma nova baixa.
        $billingStoreWillChange = (-not [bool]$deductionPlan.JaAplicada)

        $outputName = "$product - NF $displayInvoiceNumber.xlsx"
        $outputPath = [IO.Path]::Combine($outputDirectory, $outputName)
        $mastersToUpdate = @($records | Where-Object { $_.UpdateMaster })
        $currentStage = "Verificação do arquivo existente"
        $fileExists = [IO.File]::Exists($outputPath)
        if ($fileExists) {
            Assert-FileAvailableForReplace $outputPath
        }
        Set-UiProgress 40 "Aguardando sua confirmação" "Warning"
        if (-not (Show-CombinedConfirmation $product $records $combinedItems $outputName $fileExists $deductionPlan)) {
            $combineStatusText.Text = "Operação cancelada. Nenhum arquivo foi alterado."
            Set-UiProgress 0 "Operação cancelada; nenhum arquivo foi alterado" "Warning"
            return
        }
        $temporaryDirectory = [IO.Path]::Combine([IO.Path]::GetTempPath(), "GeradorPlanilhas_" + [Guid]::NewGuid().ToString("N"))
        [void][IO.Directory]::CreateDirectory($temporaryDirectory)
        if ($fileExists -or $mastersToUpdate.Count -gt 0 -or $billingStoreWillChange) {
            $currentStage = "Preparação da substituição"
            Set-UiProgress 48 "Preparando a substituição segura..." "Normal"
            $rollbackDirectory = [IO.Path]::Combine($temporaryDirectory, "ReversaoTemporaria")
            [void][IO.Directory]::CreateDirectory($rollbackDirectory)
            if ($fileExists) {
                $outputRollbackPath = [IO.Path]::Combine($rollbackDirectory, "Saida original - $outputName")
                Copy-Item -LiteralPath $outputPath -Destination $outputRollbackPath
            }
            for ($masterIndex = 0; $masterIndex -lt $mastersToUpdate.Count; $masterIndex++) {
                $record = $mastersToUpdate[$masterIndex]
                $record.RollbackMasterPath = [IO.Path]::Combine(
                    $rollbackDirectory,
                    ("Mestre {0:D2} original - {1}" -f ($masterIndex + 1), [IO.Path]::GetFileName($record.Path))
                )
                Copy-Item -LiteralPath $record.Path -Destination $record.RollbackMasterPath
            }
            if ($billingStoreWillChange) {
                Assert-FileAvailableForReplace $script:BillingComponentStorePath
                $billingStoreRollbackPath = [IO.Path]::Combine($rollbackDirectory, "Componentes a faturar original.json")
                Copy-Item -LiteralPath $script:BillingComponentStorePath -Destination $billingStoreRollbackPath
            }
        }
        if ($billingStoreWillChange) {
            $billingPendingStore = Copy-BillingComponentStore $script:BillingComponentStore
            $billingPendingStore = Apply-BillingDeductionPlan -Store $billingPendingStore -Plan $deductionPlan -OperationKey $billingOperationKey -Invoice $displayInvoiceNumber -Lots $operationLots
            $billingTemporaryStorePath = [IO.Path]::Combine($temporaryDirectory, "Componentes a faturar atualizado.json")
            Write-BillingComponentStore -Store $billingPendingStore -Path $billingTemporaryStorePath
        }
        $temporaryPath = [IO.Path]::Combine($temporaryDirectory, $outputName)
        for ($masterIndex = 0; $masterIndex -lt $mastersToUpdate.Count; $masterIndex++) {
            $record = $mastersToUpdate[$masterIndex]
            $record.TemporaryMasterPath = [IO.Path]::Combine(
                $temporaryDirectory,
                ("Mestre {0:D2} atualizada{1}" -f ($masterIndex + 1), [IO.Path]::GetExtension($record.Path))
            )
            $currentStage = "Preparação da mestre $([IO.Path]::GetFileName($record.Path))"
            Set-UiProgress 55 "Preparando mestre $($masterIndex + 1) de $($mastersToUpdate.Count)..." "Normal"
            Save-UpdatedMasterCopy $excel $record.Path $record.MasterData.Items $record.TemporaryMasterPath
        }

        $currentStage = "Geração da planilha $product com lotes unidos"
        $combineStatusText.Text = "Gerando ORÇAMENTO, MANUTENÇÃO e TABELA com $($records.Count) lotes..."
        Set-UiProgress 75 "Gerando o arquivo final com $($records.Count) lotes..." "Normal"
        [Windows.Forms.Application]::DoEvents()
        if ($product -eq "TV5") {
            Save-TV5Workbook $excel $combinedItems $temporaryPath
        }
        else {
            Save-CB5CombinedWorkbook $excel $combinedItems $temporaryPath
        }
        Assert-GeneratedFile $temporaryPath "$product com lotes unidos"

        $currentStage = "Gravação dos arquivos"
        Set-UiProgress 92 "Gravando arquivo final, mestres e saldos..." "Normal"
        if ($fileExists) { Assert-FileAvailableForReplace $outputPath }
        foreach ($record in $mastersToUpdate) { Assert-FileAvailableForReplace $record.Path }
        if ($billingStoreWillChange) { Assert-FileAvailableForReplace $script:BillingComponentStorePath }
        $transactions = [Collections.Generic.List[object]]::new()
        $transactions.Add([pscustomobject]@{
            TemporaryPath = $temporaryPath
            TargetPath = $outputPath
            Existed = $fileExists
            RollbackPath = $outputRollbackPath
        })
        foreach ($record in $mastersToUpdate) {
            $transactions.Add([pscustomobject]@{
                TemporaryPath = $record.TemporaryMasterPath
                TargetPath = $record.Path
                Existed = $true
                RollbackPath = $record.RollbackMasterPath
            })
        }
        if ($billingStoreWillChange) {
            $transactions.Add([pscustomobject]@{
                TemporaryPath = $billingTemporaryStorePath
                TargetPath = $script:BillingComponentStorePath
                Existed = $true
                RollbackPath = $billingStoreRollbackPath
            })
        }
        $committedTransactions = [Collections.Generic.List[object]]::new()
        try {
            foreach ($transaction in $transactions) {
                Move-Item -LiteralPath $transaction.TemporaryPath -Destination $transaction.TargetPath -Force
                $committedTransactions.Add($transaction)
            }
            Assert-GeneratedFile $outputPath "na Área de Trabalho"
            foreach ($record in $mastersToUpdate) { Assert-GeneratedFile $record.Path "da mestre atualizada" }
            if ($billingStoreWillChange) { [void](Read-BillingComponentStore -Path $script:BillingComponentStorePath) }
        }
        catch {
            for ($transactionIndex = $committedTransactions.Count - 1; $transactionIndex -ge 0; $transactionIndex--) {
                $transaction = $committedTransactions[$transactionIndex]
                try {
                    if ($transaction.Existed -and $null -ne $transaction.RollbackPath -and [IO.File]::Exists($transaction.RollbackPath)) {
                        Copy-Item -LiteralPath $transaction.RollbackPath -Destination $transaction.TargetPath -Force
                    }
                    elseif (-not $transaction.Existed -and [IO.File]::Exists($transaction.TargetPath)) {
                        Remove-Item -LiteralPath $transaction.TargetPath -Force
                    }
                }
                catch {}
            }
            throw
        }
        if ($billingStoreWillChange) {
            $script:BillingComponentStore = $billingPendingStore
            Update-BillingComponentsView
        }

        $currentStage = "Conclusão"
        $summary = [Collections.Generic.List[string]]::new()
        $summary.Add("CONCLUÍDO")
        foreach ($record in $records) {
            $summary.Add((Get-BillingSummary $product $record.MasterData $record.Additional))
        }
        $summary.Add("")
        $summary.Add("NF do nome: $displayInvoiceNumber")
        $summary.Add("Lotes unidos: $($records.Count)")
        $summary.Add("Peças totais: $($combinedItems.Count)")
        $summary.Add("Destino: $outputDirectory")
        foreach ($record in $records) {
            $summary.Add("")
            $summary.Add("Lote $($record.MasterData.Lot): $($record.MasterData.Items.Count) peças")
            foreach ($extra in $record.Additional) {
                $summary.Add("Extra $($extra.Code): $($extra.Quantity) primeiras peças")
            }
            if ($record.UpdateMaster) { $summary.Add("Mestre atualizada: $([IO.Path]::GetFileName($record.Path))") }
        }
        $summary.Add("")
        $summary.Add("Componentes a faturar:")
        if ([bool]$deductionPlan.JaAplicada) {
            $summary.Add("Baixa já registrada anteriormente; nenhum saldo foi descontado novamente.")
        }
        elseif (-not [bool]$deductionPlan.ConsumirSaldo) {
            $summary.Add("Consumo desmarcado: o saldo não foi consultado nem alterado. Textos de REPARO não cadastrados foram preservados na união.")
        }
        elseif (@($deductionPlan.Linhas).Count -eq 0) {
            $summary.Add("Nenhum componente cadastrado foi encontrado nos reparos. A união foi registrada para impedir uma baixa futura duplicada.")
        }
        else {
            foreach ($deduction in @($deductionPlan.Linhas)) {
                $summary.Add("$($deduction.Componente) — $($deduction.Nome): -$($deduction.Quantidade) | $($deduction.SaldoAnterior) → $($deduction.SaldoPosterior)")
            }
        }
        $summary.Add("")
        $summary.Add($outputName)
        $combineStatusText.Text = $summary -join "`r`n"
        $script:LastOutputDirectory = $outputDirectory
        $openFolderButton.Enabled = $true
        Set-UiProgress 100 "União concluída com sucesso" "Success"
        $combineSuccessMessage = "Os $($records.Count) lotes $product foram unidos com sucesso."
        if ($mastersToUpdate.Count -gt 0) { $combineSuccessMessage += " As mestres com manutenção adicional também foram atualizadas." }
        if ($billingStoreWillChange -and -not [bool]$deductionPlan.ConsumirSaldo) { $combineSuccessMessage += " A união foi registrada sem consultar nem consumir o saldo." }
        elseif ($billingStoreWillChange -and @($deductionPlan.Linhas).Count -gt 0) { $combineSuccessMessage += " Os componentes encontrados foram baixados do saldo a faturar." }
        elseif ($billingStoreWillChange) { $combineSuccessMessage += " A união foi registrada sem baixa de componentes." }
        elseif ([bool]$deductionPlan.JaAplicada) { $combineSuccessMessage += " A baixa dessa mesma união já existia e não foi repetida." }
        [Windows.Forms.MessageBox]::Show(
            $combineSuccessMessage,
            "Gerenciador de Planilhas",
            [Windows.Forms.MessageBoxButtons]::OK,
            [Windows.Forms.MessageBoxIcon]::Information
        ) | Out-Null
    }
    catch {
        $errorMessage = $_.Exception.Message
        $combineStatusText.Text = "ERRO EM: $currentStage`r`n$errorMessage"
        Set-UiProgress 0 "Erro em: $currentStage" "Error"
        [Windows.Forms.MessageBox]::Show(
            "Etapa: $currentStage`r`n`r`n$errorMessage",
            "Gerenciador de Planilhas",
            [Windows.Forms.MessageBoxButtons]::OK,
            [Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
    }
    finally {
        if ($null -ne $excel) {
            try { $excel.Quit() } catch {}
            Release-ComObject $excel
        }
        if ($null -ne $temporaryDirectory -and [IO.Directory]::Exists($temporaryDirectory)) {
            try { Remove-Item -LiteralPath $temporaryDirectory -Recurse -Force } catch {}
        }
        [GC]::Collect()
        [GC]::WaitForPendingFinalizers()
        [GC]::Collect()
        [GC]::WaitForPendingFinalizers()
        $form.UseWaitCursor = $false
        $combineGenerateButton.Enabled = $true
        $productCombo.Enabled = $true
        $themeCombo.Enabled = $true
        $tabs.Enabled = $true
    }
})

if ($script:IsInProcessHosted) {
    $form.MinimumSize = [Drawing.Size]::new(1, 1)
    $form.Dock = [Windows.Forms.DockStyle]::Fill
    $form.Add_HandleCreated({ try { Update-GeneratorResponsiveLayout; Update-RootLayout } catch {} })
    $form.Add_Disposed({
        try { Save-AppSettings } catch {}
        try { if ($null -ne $logoPicture.Image) { $logoPicture.Image.Dispose() } } catch {}
        try { if ($null -ne $script:AppIcon) { $script:AppIcon.Dispose() } } catch {}
        try { if ($null -ne $script:AppIconBitmap) { $script:AppIconBitmap.Dispose() } } catch {}
        try { $toolTip.Dispose() } catch {}
        try { Close-GeneratorSingleInstanceMutex } catch {}
    })
    try { Update-GeneratorResponsiveLayout; Update-RootLayout } catch {}
    $script:HostedControlExport = $form
    $script:HostedFormExport = $null
}
else {
    $form.MinimumSize = [Drawing.Size]::new([int]$minimumWidth, [int]$minimumHeight)
    $form.Size = [Drawing.Size]::new([int]$targetWidth, [int]$targetHeight)
    Initialize-EmbeddedModuleWindow $form
    $form.Add_Shown({
        if (-not $script:IsEmbedded) {
            $visibleArea = [Windows.Forms.Screen]::FromControl($form).WorkingArea
            if ($form.WindowState -eq [Windows.Forms.FormWindowState]::Normal) {
                $fittedWidth = [Math]::Min($form.Width, $visibleArea.Width)
                $fittedHeight = [Math]::Min($form.Height, $visibleArea.Height)
                $form.Size = [Drawing.Size]::new([int]$fittedWidth, [int]$fittedHeight)
            }
        }
        Update-RootLayout
    })
    if (-not $script:IsEmbedded) { Show-AppSplash }
    try { [void]$form.ShowDialog() }
    finally {
        Save-AppSettings
        if ($null -ne $logoPicture.Image) { $logoPicture.Image.Dispose() }
        if ($null -ne $script:AppIcon) { $script:AppIcon.Dispose() }
        if ($null -ne $script:AppIconBitmap) { $script:AppIconBitmap.Dispose() }
        $toolTip.Dispose()
        $form.Dispose()
        Close-GeneratorSingleInstanceMutex
    }
}

# GENERATOR_NATIVE_HOST_V120
