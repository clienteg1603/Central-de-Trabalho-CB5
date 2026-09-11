from pathlib import Path
p=Path('src/generated/Central de Trabalho.ps1')
s=p.read_text(encoding='utf-8-sig')
for a,b in [('$script:AppVersion = "0.21.5"','$script:AppVersion = "0.21.6"'),('$script:NFEntradaVersion = "1.4.0"','$script:NFEntradaVersion = "1.5.0"')]:
    if a not in s: raise SystemExit('versao ausente: '+a)
    s=s.replace(a,b,1)
p.write_text(s,encoding='utf-8')
print('versoes etapa 4 aplicadas')
