import json
from pathlib import Path

base = Path('assets/lang')
en = json.loads((base / 'en.json').read_text(encoding='utf-8'))

def flatten(d, prefix=''):
    items = {}
    for k, v in d.items():
        nk = f'{prefix}.{k}' if prefix else k
        if isinstance(v, dict):
            items.update(flatten(v, nk))
        else:
            items[nk] = v
    return items

flat_en = flatten(en)
for lang in ['ru', 'ka']:
    path = base / f'{lang}.json'
    data = json.loads(path.read_text(encoding='utf-8'))
    flat_lang = flatten(data)
    missing = sorted([k for k in flat_en if k not in flat_lang])
    untranslated = sorted([k for k, v in flat_lang.items() if isinstance(v, str) and v == flat_en.get(k)])
    print('---', lang, '---')
    print('missing', len(missing))
    for k in missing[:200]:
        print(k)
    print('untranslated', len(untranslated))
    for k in untranslated[:200]:
        print(k)
