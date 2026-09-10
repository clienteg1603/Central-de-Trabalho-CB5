#!/usr/bin/env python3
from pathlib import Path

path = Path("src/generated/Central de Trabalho.ps1")
text = path.read_text(encoding="utf-8-sig")

old_version = '$script:AppVersion = "0.17.0"'
new_version = '$script:AppVersion = "0.17.1"'
if text.count(old_version) != 1:
    raise SystemExit("Transformação 0.17.1: versão-base 0.17.0 não encontrada exatamente uma vez.")
text = text.replace(old_version, new_version, 1)

old_callback = '    $Control.Add_SizeChanged({ Set-RoundedRegion $target $r }.GetNewClosure())'
new_callback = '''    # O callback pode disparar depois que a criação inicial da janela terminou.\n    # Capturamos o ScriptBlock da função para não depender da resolução de nome\n    # dentro do módulo dinâmico criado por GetNewClosure().\n    $roundAction = ${function:Set-RoundedRegion}\n    $Control.Add_SizeChanged({ & $roundAction $target $r }.GetNewClosure())'''
if text.count(old_callback) != 1:
    raise SystemExit("Transformação 0.17.1: callback antigo de Set-RoundedRegion não encontrado exatamente uma vez.")
text = text.replace(old_callback, new_callback, 1)

path.write_text(text, encoding="utf-8-sig")
print("0.17.1: escopo persistente e callback Set-RoundedRegion preparados.")
