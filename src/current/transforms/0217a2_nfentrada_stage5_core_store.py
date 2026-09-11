from pathlib import Path
p=Path('src/generated/Modulos/Controle-NF-Entrada/NFEntrada.Core.ps1')
s=p.read_text(encoding='utf-8-sig')

def rep(a,b,label):
    global s
    if a not in s: raise SystemExit('Etapa 5 store: '+label)
    s=s.replace(a,b,1)

rep('''            Historico = @()
            Meta = [pscustomobject]@{
''','''            Historico = @()
            Movimentacoes = @()
            Meta = [pscustomobject]@{
''','store importado')
rep('''        Historico = @()
        Meta = [pscustomobject]@{
''','''        Historico = @()
        Movimentacoes = @()
        Meta = [pscustomobject]@{
''','store vazio')
rep('''            $store.Historico = @($previous.Historico)
        }
        catch {}
''','''            $store.Historico = @($previous.Historico)
            $store.Movimentacoes = @($previous.Movimentacoes)
        }
        catch {}
''','preservação na importação')
old='''    if (-not $found) { throw "O registro selecionado não foi encontrado." }
    $Store.Produtos.PSObject.Properties[$Product].Value = @($records)
    [void](Add-NFEntradaHistoryEvent -Store $Store -Tipo "Saida" -Produto $Product -RegistroId $Id -NFEntrada $after.NFEntrada -Antes $before -Depois $after -Detalhes ("Saída de " + $Quantidade + " peça(s) • " + $saida))
    return $after
}

function Remove-NFEntradaRecord {
'''
new='''    if (-not $found) { throw "O registro selecionado não foi encontrado." }
    $Store.Produtos.PSObject.Properties[$Product].Value = @($records)
    [void](Add-NFEntradaMovement -Store $Store -Produto $Product -RegistroId $Id -NFEntrada $after.NFEntrada -Quantidade $Quantidade -Referencia $saida -SaldoAntes ([int]$before.QuantidadeSaldo) -SaldoDepois ([int]$after.QuantidadeSaldo))
    [void](Add-NFEntradaHistoryEvent -Store $Store -Tipo "Saida" -Produto $Product -RegistroId $Id -NFEntrada $after.NFEntrada -Antes $before -Depois $after -Detalhes ("Saída de " + $Quantidade + " peça(s) • " + $saida))
    return $after
}

function Remove-NFEntradaRecord {
'''
rep(old,new,'registro da saída')
p.write_text(s,encoding='utf-8')
print('Etapa 5: armazenamento de movimentações aplicado')
