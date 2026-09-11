from pathlib import Path
p=Path('src/generated/Central de Trabalho.ps1')
s=p.read_text(encoding='utf-8-sig')
if '0.21.6' not in s or '1.5.0' not in s: raise SystemExit('versoes base ausentes')
s=s.replace('0.21.6','0.21.7',1)
s=s.replace('1.5.0','1.6.0',1)
p.write_text(s,encoding='utf-8')
