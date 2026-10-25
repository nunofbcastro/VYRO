#!/usr/bin/env python3
"""Builds assets/nutrition/foods.json from official food composition tables.

Reproducible; the app only reads the generated JSON (offline at runtime).

Usage (repository root):
    python -I tool/nutrition/build_food_db.py          # download once, then build
    python -I tool/nutrition/build_food_db.py --check  # fail if the asset is stale

Curated list: tool/nutrition/foods_pt.tsv — one row per VYRO food with the
Portuguese/English names, the source table and the exact reference in it,
the cuisine region (pt, eu, br, int), a typical portion, aliases and
image-model labels.

Sources (downloaded into build/, never committed):
  usda   USDA FoodData Central SR Legacy 2018-04 — public domain (CC0).
         ref = exact food description.
  ciqual Ciqual 2025 (ANSES, France) — Licence Ouverte / etalab-2.0.
         ref = alim_code.
  taco   TACO 4.ª edição (NEPA/UNICAMP, Brasil) — reproduction allowed with
         citation. ref = food number. Needs `pip install pypdf` (build only).

Per 100 g: energy (kcal), protein, carbohydrate, fat, fibre. Ciqual "traces"
→ 0, "< x" → x/2 (documented convention); missing energy/macros fail.
"""
import csv
import hashlib
import io
import json
import sys
import unicodedata
import urllib.request
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).parent))
from xlsx_reader import read_rows  # noqa: E402

TSV = ROOT / 'tool' / 'nutrition' / 'foods_pt.tsv'
OUT = ROOT / 'assets' / 'nutrition' / 'foods.json'
SCHEMA = 2

SOURCES = {
    'usda': {
        'name': 'USDA FoodData Central — SR Legacy (2018-04)',
        'license': 'Public domain (CC0 1.0)',
        'url': 'https://fdc.nal.usda.gov/fdc-datasets/FoodData_Central_sr_legacy_food_csv_2018-04.zip',
        'file': ROOT / 'build' / 'usda' / 'FoodData_Central_sr_legacy_food_csv_2018-04.zip',
    },
    'ciqual': {
        'name': 'Ciqual 2025 — ANSES (França)',
        'license': 'Licence Ouverte / etalab-2.0 (atribuição)',
        'url': 'https://entrepot.recherche.data.gouv.fr/api/access/datafile/666260',
        'citation': 'Anses. 2025. Table de composition nutritionnelle des aliments Ciqual. doi:10.57745/RDMHWY',
        'file': ROOT / 'build' / 'ciqual' / 'Table_Ciqual_2025_FR_2025_11_03.xlsx',
    },
    'taco': {
        'name': 'TACO 4.ª edição — NEPA/UNICAMP (Brasil)',
        'license': 'Reprodução permitida desde que citada a fonte',
        'url': 'https://www.cfn.org.br/wp-content/uploads/2017/03/taco_4_edicao_ampliada_e_revisada.pdf',
        'citation': 'NEPA/UNICAMP. Tabela Brasileira de Composição de Alimentos – TACO. 4. ed. Campinas, 2011.',
        'file': ROOT / 'build' / 'taco' / 'taco_4_edicao_ampliada_e_revisada.pdf',
    },
}


def download(source):
    info = SOURCES[source]
    path = info['file']
    if path.exists():
        return path
    path.parent.mkdir(parents=True, exist_ok=True)
    print(f"Downloading {info['name']} …")
    with urllib.request.urlopen(info['url']) as r, open(path, 'wb') as f:
        f.write(r.read())
    return path


def read_curated():
    rows = list(csv.DictReader(open(TSV, encoding='utf-8'), delimiter='\t'))
    keys = [r['key'] for r in rows]
    dupes = sorted({k for k in keys if keys.count(k) > 1})
    if dupes:
        sys.exit(f'Duplicate keys in foods_pt.tsv: {dupes}')
    unknown = sorted({r['source'] for r in rows} - SOURCES.keys())
    if unknown:
        sys.exit(f'Unknown sources: {unknown}')
    return rows


# ---------------------------------------------------------------- USDA

def load_usda(refs):
    z = zipfile.ZipFile(download('usda'))
    prefix = 'FoodData_Central_sr_legacy_food_csv_2018-04/'

    def table(name):
        return csv.DictReader(io.TextIOWrapper(z.open(prefix + name), encoding='utf-8'))

    ids = {}
    for food in table('food.csv'):
        if food['description'] in refs:
            ids.setdefault(food['description'], food['fdc_id'])
    fields = {'1008': 'kcal', '1003': 'protein', '1005': 'carbs', '1004': 'fat', '1079': 'fiber'}
    values = {fdc: {} for fdc in ids.values()}
    fallback = {fdc: {} for fdc in ids.values()}
    for n in table('food_nutrient.csv'):
        if n['fdc_id'] not in values:
            continue
        if n['nutrient_id'] in fields:
            values[n['fdc_id']][fields[n['nutrient_id']]] = float(n['amount'])
        elif n['nutrient_id'] in ('2047', '2048'):
            fallback[n['fdc_id']][n['nutrient_id']] = float(n['amount'])
    out = {}
    for ref, fdc in ids.items():
        v = values[fdc]
        if 'kcal' not in v:
            v['kcal'] = fallback[fdc].get('2048') or fallback[fdc].get('2047')
        out[ref] = dict(v, id=fdc, label=ref)
    return out


# -------------------------------------------------------------- Ciqual

def _norm(text):
    return ''.join(
        c for c in unicodedata.normalize('NFD', text.replace('\n', ' ').lower())
        if unicodedata.category(c) != 'Mn'
    )


def _ciqual_value(text):
    t = text.strip().replace(',', '.')
    if t in ('', '-'):
        return None
    if t.lower() == 'traces':
        return 0.0
    if t.startswith('<'):
        return float(t[1:].strip()) / 2
    return float(t)


def load_ciqual(refs):
    rows = read_rows(download('ciqual'))
    header = [_norm(h) for h in next(rows)]

    def col(*parts):
        for i, h in enumerate(header):
            if all(p in h for p in parts):
                return i
        sys.exit(f'Ciqual column not found: {parts}')

    c_code, c_name = col('alim_code'), col('alim_nom_fr')
    c_kcal = col('energie', 'reglement', 'kcal')
    c_prot = col('proteines', 'jones')
    c_carb = col('glucides')
    c_fat = col('lipides')
    c_fib = col('fibres alimentaires')
    out = {}
    for r in rows:
        code = r[c_code] if c_code < len(r) else ''
        if code not in refs:
            continue
        get = lambda i: _ciqual_value(r[i]) if i < len(r) else None
        out[code] = {
            'id': code,
            'label': r[c_name].replace('\n', ' '),
            'kcal': get(c_kcal),
            'protein': get(c_prot),
            'carbs': get(c_carb),
            'fat': get(c_fat),
            'fiber': get(c_fib) or 0.0,
        }
    return out


# ---------------------------------------------------------------- TACO

def load_taco(refs):
    try:
        import taco_parser
        rows, _rejected = taco_parser.parse(download('taco'))
    except ImportError:
        sys.exit('TACO rows need pypdf at build time: pip install pypdf')
    out = {}
    for ref in refs:
        row = rows.get(int(ref))
        if row:
            out[ref] = dict(row, id=ref, label=row['description'])
    return out


LOADERS = {'usda': load_usda, 'ciqual': load_ciqual, 'taco': load_taco}


def build():
    curated = read_curated()
    by_source = {}
    for row in curated:
        by_source.setdefault(row['source'], set()).add(row['source_ref'])
    data = {s: LOADERS[s](refs) for s, refs in by_source.items()}

    problems, foods = [], []
    split = lambda s: [x.strip() for x in (s or '').split('|') if x.strip()]
    for row in curated:
        v = data[row['source']].get(row['source_ref'])
        if v is None:
            problems.append(f"{row['key']}: {row['source']} ref not found or invalid: {row['source_ref']}")
            continue
        missing = [f for f in ('kcal', 'protein', 'carbs', 'fat') if v.get(f) is None]
        if missing:
            problems.append(f"{row['key']}: missing {missing} in {row['source']}")
            continue
        foods.append({
            'key': row['key'],
            'namePt': row['name_pt'],
            'nameEn': row['name_en'],
            'category': row['category'],
            'region': row['region'],
            'source': row['source'],
            'sourceRef': str(v['id']),
            'sourceLabel': v['label'],
            'kcal': round(v['kcal'], 1),
            'protein': round(v['protein'], 2),
            'carbs': round(v['carbs'], 2),
            'fat': round(v['fat'], 2),
            'fiber': round(v.get('fiber') or 0.0, 2),
            'portionG': float(row['portion_g']),
            'portionUnits': float(row['portion_units']) if row.get('portion_units') else None,
            'portionPt': row['portion_pt'],
            'portionEn': row['portion_en'],
            'aliases': split(row['aliases']),
            'visionLabels': split(row['vision_labels']),
        })
    if problems:
        sys.exit('Cannot build foods.json:\n  ' + '\n  '.join(problems))
    foods.sort(key=lambda f: (f['category'], f['namePt']))
    used = sorted({f['source'] for f in foods})
    return {
        'schemaVersion': SCHEMA,
        'sources': {
            s: {k: SOURCES[s][k] for k in ('name', 'license', 'url', 'citation') if k in SOURCES[s]}
            for s in used
        },
        'curatedList': 'tool/nutrition/foods_pt.tsv',
        # LF-normalised so the hash is the same on Windows checkouts.
        'curatedSha256': hashlib.sha256(TSV.read_bytes().replace(b'\r\n', b'\n')).hexdigest(),
        'portionNote': 'Typical portions are VYRO estimates for suggestions; users confirm grams.',
        'foods': foods,
    }


def main():
    db = build()
    text = json.dumps(db, ensure_ascii=False, indent=1) + '\n'
    if '--check' in sys.argv:
        current = OUT.read_text(encoding='utf-8') if OUT.exists() else ''
        if current != text:
            sys.exit('assets/nutrition/foods.json is out of date: run build_food_db.py')
        print('foods.json is up to date')
        return
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(text, encoding='utf-8', newline='\n')
    counts = {}
    for f in db['foods']:
        counts[f['source']] = counts.get(f['source'], 0) + 1
    print(f"Wrote {OUT.relative_to(ROOT)}: {len(db['foods'])} foods {counts}")


if __name__ == '__main__':
    main()
