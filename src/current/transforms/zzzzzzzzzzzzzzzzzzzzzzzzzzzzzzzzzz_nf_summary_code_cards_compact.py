from pathlib import Path

p=Path('src/generated/Modulos/Controle-NF-Entrada/Controle NF Entrada.ps1')
n=p.read_text(encoding='utf-8-sig')

def one(t,a,b,label):
    k=t.count(a)
    if k!=1: raise SystemExit(f'NF CODE CARDS COMPACT {label}: esperado 1, encontrado {k}')
    return t.replace(a,b,1)

n=one(n,'$cb.Text="CB5`r`n0"','$cb.Text="CB5: 0"','CB5 inicial')
n=one(n,'$tv.Text="TV5`r`n0"','$tv.Text="TV5: 0"','TV5 inicial')
n=one(n,'$tt.Text="TOTAL`r`n0"','$tt.Text="TOTAL: 0"','TOTAL inicial')
n=one(n,'$cv.Computador.Text="CB5`r`n"+([int]$item.Computador).ToString("N0")','$cv.Computador.Text="CB5: "+([int]$item.Computador).ToString("N0")','CB5 refresh')
n=one(n,'$cv.Teclado.Text="TV5`r`n"+([int]$item.Teclado).ToString("N0")','$cv.Teclado.Text="TV5: "+([int]$item.Teclado).ToString("N0")','TV5 refresh')
n=one(n,'$cv.Total.Text="TOTAL`r`n"+([int]$item.Total).ToString("N0")','$cv.Total.Text="TOTAL: "+([int]$item.Total).ToString("N0")','TOTAL refresh')
n+='\n# NF_RESUMO_CODE_CARDS_COMPACT_V02623\n'
p.write_text(n,encoding='utf-8')
print('NF RESUMO: OK - métricas dos quatro cards em uma linha, sem recorte vertical.')
