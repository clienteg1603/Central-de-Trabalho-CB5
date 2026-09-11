from pathlib import Path
import json

plan = json.loads(Path('src/ci/nf_stage10_plan.json').read_text(encoding='utf-8'))
for item in plan['files']:
    path = Path(item['path'])
    text = path.read_text(encoding='utf-8-sig')
    for change in item['changes']:
        old = change['old']
        new = change['new']
        count = text.count(old)
        if count != 1:
            raise SystemExit(f"{path}: marcador {change['name']} encontrado {count} vez(es)")
        text = text.replace(old, new, 1)
    for marker in item.get('markers', []):
        if marker not in text:
            raise SystemExit(f"{path}: contrato ausente depois da etapa 10: {marker}")
    path.write_text(text, encoding='utf-8')
print('ETAPA 10 NF ENTRADA: OK')
