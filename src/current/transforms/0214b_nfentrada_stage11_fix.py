from pathlib import Path
p = Path('src/generated/Modulos/Controle-NF-Entrada/Controle NF Entrada.ps1')
t = p.read_text(encoding='utf-8-sig')
old = '''        Set-NFStatus ("Integridade: " + [string]$report.Situacao + " • " + [string]$report.Erros.Count + " erro(s) • " + [string]$report.Avisos.Count + " aviso(s)") (if ($report.Situacao -eq "ERRO") { "Error" } elseif ($report.Situacao -eq "ATENÇÃO") { "Warning" } else { "Success" })'''
new = '''        $statusKind = "Success"
        if ($report.Situacao -eq "ERRO") { $statusKind = "Error" }
        elseif ($report.Situacao -eq "ATENÇÃO") { $statusKind = "Warning" }
        Set-NFStatus ("Integridade: " + [string]$report.Situacao + " • " + [string]$report.Erros.Count + " erro(s) • " + [string]$report.Avisos.Count + " aviso(s)") $statusKind'''
if t.count(old) != 1:
    raise SystemExit('Etapa 11 fix: marcador de status não encontrado uma vez.')
t = t.replace(old,new,1)
p.write_text(t,encoding='utf-8')
print('ETAPA 11 FIX: OK')
