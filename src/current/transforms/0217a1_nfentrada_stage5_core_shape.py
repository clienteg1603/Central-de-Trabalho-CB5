from pathlib import Path
p=Path('src/generated/Modulos/Controle-NF-Entrada/NFEntrada.Core.ps1')
s=p.read_text(encoding='utf-8-sig')
old='''    elseif ($null -eq $Store.Historico) {
        $Store.Historico = @()
    }
    if ($null -eq $Store.PSObject.Properties["Meta"]) {
'''
new='''    elseif ($null -eq $Store.Historico) {
        $Store.Historico = @()
    }
    if ($null -eq $Store.PSObject.Properties["Movimentacoes"]) {
        $movements = [Collections.Generic.List[object]]::new()
        foreach ($event in @($Store.Historico)) {
            if ([string]$event.Tipo -ne "Saida" -or $null -eq $event.Antes -or $null -eq $event.Depois) { continue }
            $qty = [int]$event.Antes.QuantidadeSaldo - [int]$event.Depois.QuantidadeSaldo
            if ($qty -le 0) { continue }
            [void]$movements.Add([pscustomobject]@{
                Id = [string]$event.Id
                DataHora = [string]$event.DataHora
                Produto = [string]$event.Produto
                RegistroId = [int]$event.RegistroId
                NFEntrada = [string]$event.NFEntrada
                Quantidade = $qty
                Referencia = [string]$event.Detalhes
                SaldoAntes = [int]$event.Antes.QuantidadeSaldo
                SaldoDepois = [int]$event.Depois.QuantidadeSaldo
                Origem = "Histórico legado"
            })
        }
        $Store | Add-Member -NotePropertyName Movimentacoes -NotePropertyValue @($movements)
    }
    elseif ($null -eq $Store.Movimentacoes) {
        $Store.Movimentacoes = @()
    }
    if ($null -eq $Store.PSObject.Properties["Meta"]) {
'''
if old not in s: raise SystemExit('Etapa 5: formato da base não encontrado')
s=s.replace(old,new,1)
anchor='''function Get-NFEntradaHistory {
    param([Parameter(Mandatory = $true)]$Store)
    [void](Ensure-NFEntradaStoreShape -Store $Store)
    return @($Store.Historico | Sort-Object { [DateTime]$_.DataHora } -Descending)
}
'''
extra='''
function Get-NFEntradaMovements {
    param([Parameter(Mandatory = $true)]$Store)
    [void](Ensure-NFEntradaStoreShape -Store $Store)
    return @($Store.Movimentacoes | Sort-Object { [DateTime]$_.DataHora } -Descending)
}

function Add-NFEntradaMovement {
    param($Store,[string]$Produto,[int]$RegistroId,[string]$NFEntrada,[int]$Quantidade,[string]$Referencia,[int]$SaldoAntes,[int]$SaldoDepois)
    [void](Ensure-NFEntradaStoreShape -Store $Store)
    $movement = [pscustomobject]@{
        Id = [guid]::NewGuid().ToString("N")
        DataHora = [DateTime]::Now.ToString("o")
        Produto = $Produto
        RegistroId = $RegistroId
        NFEntrada = $NFEntrada
        Quantidade = $Quantidade
        Referencia = $Referencia
        SaldoAntes = $SaldoAntes
        SaldoDepois = $SaldoDepois
        Origem = "Operação"
    }
    $Store.Movimentacoes = @($Store.Movimentacoes) + $movement
    return $movement
}
'''
if anchor not in s: raise SystemExit('Etapa 5: histórico não encontrado')
s=s.replace(anchor,anchor+extra,1)
p.write_text(s,encoding='utf-8')
print('Etapa 5: shape de movimentações aplicado')
