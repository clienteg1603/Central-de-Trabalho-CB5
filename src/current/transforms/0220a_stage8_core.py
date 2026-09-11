from pathlib import Path
p=Path('src/generated/Modulos/Controle-NF-Entrada/NFEntrada.Core.ps1')
s=p.read_text(encoding='utf-8-sig')
anchor='function Test-NFEntradaRecord {'
helper='''function Get-NFEntradaDuplicateRecord {\n    param(\n        [Parameter(Mandatory = $true)]$Store,\n        [Parameter(Mandatory = $true)][ValidateSet("COMPUTADOR DE BORDO V5", "TECLADO V5")][string]$Product,\n        [Parameter(Mandatory = $true)][string]$NFEntrada,\n        [int]$IgnoreId = 0\n    )\n    $nf = ConvertTo-NFEntradaText $NFEntrada\n    if ([string]::IsNullOrWhiteSpace($nf)) { return $null }\n    foreach ($existing in Get-NFEntradaProductRecords -Store $Store -Product $Product) {\n        if ([int]$existing.Id -eq $IgnoreId) { continue }\n        if ([string]::Equals((ConvertTo-NFEntradaText $existing.NFEntrada), $nf, [StringComparison]::OrdinalIgnoreCase)) { return $existing }\n    }\n    return $null\n}\n\n'''
if s.count(anchor)!=1: raise SystemExit('stage8 core anchor')
s=s.replace(anchor,helper+anchor,1)
old='''    foreach ($existing in Get-NFEntradaProductRecords -Store $Store -Product $Product) {\n        if ([int]$existing.Id -eq $IgnoreId) { continue }\n        if ([string]::Equals((ConvertTo-NFEntradaText $existing.NFEntrada), $nf, [StringComparison]::OrdinalIgnoreCase)) {\n            throw "A NF de Entrada $nf já está cadastrada em $(Get-NFEntradaProductDisplayName $Product)."\n        }\n    }\n'''
new='''    $duplicate = Get-NFEntradaDuplicateRecord -Store $Store -Product $Product -NFEntrada $nf -IgnoreId $IgnoreId\n    if ($null -ne $duplicate) { throw "A NF de Entrada $nf já está cadastrada em $(Get-NFEntradaProductDisplayName $Product)." }\n'''
if s.count(old)!=1: raise SystemExit('stage8 duplicate block')
s=s.replace(old,new,1)
p.write_text(s,encoding='utf-8')
