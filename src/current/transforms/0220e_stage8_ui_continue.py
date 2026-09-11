from pathlib import Path
p=Path('src/generated/Modulos/Controle-NF-Entrada/Controle NF Entrada.ps1')
s=p.read_text(encoding='utf-8-sig')
a='''function Add-NFRecordFromUI {\n    $product = Get-SelectedProduct\n    if ([string]::IsNullOrWhiteSpace($product)) { return }\n    $record = Show-NFRecordDialog -Product $product\n'''
b='''function Add-NFRecordFromUI {\n    param([string]$DefaultDate = "", [string]$DefaultCode = "800")\n    $product = Get-SelectedProduct\n    if ([string]::IsNullOrWhiteSpace($product)) { return }\n    $defaultDate = if ([string]::IsNullOrWhiteSpace($DefaultDate)) { [DateTime]::Today.ToString("yyyy-MM-dd") } else { $DefaultDate }\n    $record = Show-NFRecordDialog -Product $product -DefaultDate $defaultDate -DefaultCode $DefaultCode\n'''
if s.count(a)!=1: raise SystemExit('stage8 add start')
s=s.replace(a,b,1)
a='''        Refresh-NFAll\n        Set-NFStatus ("Registro " + $record.NFEntrada + " incluído com sucesso.") "Success"\n'''
b='''        Refresh-NFAll\n        Set-NFStatus ("Registro " + $record.NFEntrada + " incluído com sucesso.") "Success"\n        if ([bool]$record.ContinuarCadastro) {\n            Add-NFRecordFromUI -DefaultDate ([string]$record.Data) -DefaultCode ([string]$record.Codigo)\n        }\n'''
if s.count(a)!=1: raise SystemExit('stage8 add continue')
s=s.replace(a,b,1)
p.write_text(s,encoding='utf-8')
