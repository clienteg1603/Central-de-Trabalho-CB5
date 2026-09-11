from pathlib import Path
p=Path('src/generated/Modulos/Controle-NF-Entrada/NFEntrada.Core.ps1')
s=p.read_text(encoding='utf-8-sig')
anchor='function Remove-NFEntradaRecord {\n'
if anchor not in s: raise SystemExit('anchor core ausente')
fn=r'''function Register-NFEntradaOutput {
    param(
        [Parameter(Mandatory = $true)]$Store,
        [Parameter(Mandatory = $true)][ValidateSet("COMPUTADOR DE BORDO V5", "TECLADO V5")][string]$Product,
        [Parameter(Mandatory = $true)][int]$Id,
        [Parameter(Mandatory = $true)][int]$Quantidade,
        [Parameter(Mandatory = $true)][string]$NFSaida
    )
    if ($Quantidade -le 0) { throw "A quantidade de saída deve ser maior que zero." }
    $saida = ConvertTo-NFEntradaText $NFSaida
    if ([string]::IsNullOrWhiteSpace($saida)) { throw "Informe a NF de Saída ou referência da movimentação." }
    $records = @(Get-NFEntradaProductRecords -Store $Store -Product $Product)
    $found = $false
    $before = $null
    $after = $null
    foreach ($existing in $records) {
        if ([int]$existing.Id -ne $Id) { continue }
        $saldoAtual = [int]$existing.QuantidadeSaldo
        if ($saldoAtual -le 0) { throw "Esta NF já está encerrada e não possui saldo disponível." }
        if ($Quantidade -gt $saldoAtual) { throw "A quantidade de saída não pode ser maior que o saldo atual ($saldoAtual)." }
        $before = Copy-NFEntradaRecordSnapshot $existing
        $existing.QuantidadeSaldo = $saldoAtual - $Quantidade
        $atual = ConvertTo-NFEntradaText $existing.NFSaida
        $existing.NFSaida = if ([string]::IsNullOrWhiteSpace($atual)) { $saida } else { $atual + [Environment]::NewLine + $saida }
        $after = Copy-NFEntradaRecordSnapshot $existing
        $found = $true
        break
    }
    if (-not $found) { throw "O registro selecionado não foi encontrado." }
    $Store.Produtos.PSObject.Properties[$Product].Value = @($records)
    [void](Add-NFEntradaHistoryEvent -Store $Store -Tipo "Saida" -Produto $Product -RegistroId $Id -NFEntrada $after.NFEntrada -Antes $before -Depois $after -Detalhes ("Saída de " + $Quantidade + " peça(s) • " + $saida))
    return $after
}

'''
s=s.replace(anchor,fn+anchor,1)
p.write_text(s,encoding='utf-8')
print('core etapa 4 aplicado')
