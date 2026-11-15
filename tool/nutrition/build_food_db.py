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
  mcd_pt McDonald's Portugal published nutrition (product page or the
         counter PDF). ref = id in tool/nutrition/manufacturer_pt.json.
         Values are the published unit totals, converted to per 100 g.
         Fibre is stored when the table gives it, otherwise 0.
  kfc_pt KFC Portugal nutrition PDF (15 Apr 2025), same file and shape.
         The unit weight is derived from the per-unit row and the per-100 g
         row (they agree), then rounded to the nearest gram.
  bk_pt  Burger King Portugal menu nutrition published on burgerking.pt
         (Sanity dataset prod_bk_pt, consulted 14 Nov 2026). Same file.
         Rows whose nutrition block is a copy of a different product are
         left out. The Whopper is the named row (kJ agrees with kcal).
  subway_pt Subway Portugal PDF (Jan 2025). 15 cm subs include bread,
         protein, vegetables and the standard sauce. A row is kept only when
         kJ, kcal and the per-100 g columns agree.
  pans_pt Pans & Company table for Portugal (vivabem.pt, printed 12 Nov
         2026). Unit weight is unit kcal / per-100 g kcal. Drinks are not
         imported. Rows whose kJ and kcal disagree are left out.
  dominos_pt Domino's Pizza Portugal nutrition declaration (Jan 2020 table,
         PDF on the official Portuguese market cache). Unit = 1 slice or a
         sale portion; slice weight = portion kcal / per-100 g kcal. Only rows
         whose kJ agrees with kcal within 3% are kept (checked when the rows
         were imported; the kJ column is not stored in the JSON).
  insa   INSA Tabela da Composição de Alimentos v7.1 (2026, Portugal). Excel
         file, read with xlsx_reader. ref = INSA food code (column Cod).
         Values are per 100 g of edible part, as published. The INSA energy
         includes the fibre term, so the Atwater check uses 2 x fibre too.
         The terms require the source to be shown wherever the data is shown
         (see the citation in foods.json and the app's sources screen).
         Reuse terms are not an open licence: confirm with INSA before a
         public release. Downloaded to build/insa/ (SHA-256 checked).
  pizzahut_pt Pizza Hut Portugal "Informação nutricional" table (printed
         2 Nov 2026, vivabem.pt). Unit = 1 slice, piece, unit or serving;
         unit weight = portion kcal / per-100 g kcal. Rows whose kJ, kcal,
         Atwater or per-100 g columns disagree are left out. Salads are
         named "Salada <Name> (Pizza Hut)".

Brand sources (BRAND_SOURCES) share one shape in manufacturer_pt.json: the
published unit totals (grams, kcal, macros), converted to per 100 g.

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
MANUFACTURER = ROOT / 'tool' / 'nutrition' / 'manufacturer_pt.json'
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
    'mcd_pt': {
        'name': "McDonald's Portugal — informação nutricional publicada",
        'license': 'Valores publicados pelo fabricante na ficha do produto; citados com a data de consulta',
        'url': 'https://www.mcdonalds.pt/produtos/informacao-nutricional-alergenios',
        'citation': "McDonald's Portugal. Informação nutricional do balcão (PDF de 27 de outubro de 2026) e fichas de produto consultadas em 14 de novembro de 2026. O Big Tasty vem da ficha de produto: a linha do PDF não reconciliava kJ com kcal.",
        'file': MANUFACTURER,
    },
    'kfc_pt': {
        'name': 'KFC Portugal — tabela nutricional publicada',
        'license': 'Valores publicados pelo fabricante; citados com a data da tabela',
        'url': 'https://www.kfc.pt/wp-content/uploads/2025/05/44.-INF.NUTRICIONAL-KFC-15.04.2025.pdf',
        'citation': 'KFC Portugal. Tabela nutricional de 15 de abril de 2025. O peso da unidade é o quociente entre a linha «por unidade de consumo» e a linha «por 100 g», arredondado ao grama.',
        'file': MANUFACTURER,
    },
    'bk_pt': {
        'name': 'Burger King Portugal — informação nutricional do menu',
        'license': 'Valores publicados pelo fabricante no menu do site; citados com a data de consulta',
        'url': 'https://www.burgerking.pt/',
        'citation': 'Burger King Portugal. Informação nutricional do menu publicado no site (consultada em 14 de novembro de 2026). Ficaram de fora os artigos cujo bloco nutricional é uma cópia de outro produto. O Whopper é a linha com esse nome: os kJ batem certo com as kcal.',
        'file': MANUFACTURER,
    },
    'subway_pt': {
        'name': 'Subway Portugal — informação nutricional (janeiro de 2025)',
        'license': 'Valores publicados pelo fabricante; citados com a data da tabela',
        'url': 'https://subwaypt.com/pdf/portugal_nutritional_information_2025.pdf',
        'citation': 'Subway Portugal. Informação nutricional de janeiro de 2025. A Sub de 15 cm inclui pão, proteína, vegetais e molhos da receita padrão. Só entram linhas em que os kJ, as kcal e a coluna por 100 g concordam.',
        'file': MANUFACTURER,
    },
    'pizzahut_pt': {
        'name': 'Pizza Hut Portugal — tabela nutricional',
        'license': 'Valores publicados para os restaurantes em Portugal; citados com a data de impressão',
        'url': 'https://www.vivabem.pt/tabelas/tabela_pizza_hut.pdf',
        'citation': 'Pizza Hut Portugal. Informação nutricional, tabela válida para Portugal (impressa em 2 de novembro de 2026, documento PSA IC 001ph.47). O peso da unidade é o quociente entre a energia da porção e a energia por 100 g. Ficaram de fora as linhas em que os kJ, as kcal, o cálculo de Atwater ou a coluna por 100 g não concordam, os molhos e os doces.',
        'file': MANUFACTURER,
    },
    'insa': {
        'name': 'INSA — Tabela da Composição de Alimentos (v7.1, 2026)',
        'license': 'Utilização com indicação visível da fonte (termos do INSA)',
        'url': 'https://portfir.insa.min-saude.pt/wp-content/uploads/2025/11/insa_tca.xlsx',
        'citation': 'Fonte: Base de Dados da Composição de Alimentos. Instituto Nacional de Saúde Doutor Ricardo Jorge, I. P. - INSA. v 7.1 - 2026.',
        'file': ROOT / 'build' / 'insa' / 'insa_tca.xlsx',
        'sha256': '155d233b6e16e21848d766bb9a13c1965b8c990b6cd8e69e3f39f4df75c066ca',
    },
    'dominos_pt': {
        'name': "Domino's Pizza Portugal — declaração nutricional",
        'license': 'Valores publicados pelo fabricante para o mercado português; citados com a data da tabela',
        'url': 'https://cache.dominos.com/olo/6_13_2/assets/build/market/PT/_pt/pdf/nutricional.pdf',
        'citation': "Domino's Pizza Portugal. Declaração nutricional, valores médios da receita por 100 g e por porção, última atualização em janeiro de 2020 (consultada em 15 de novembro de 2026). A unidade é a fatia ou a dose de venda; o peso da fatia é o quociente entre as kcal por porção e as kcal por 100 g. Só entram linhas em que os kJ concordam com as kcal em 3%. A tabela de 2023, só por 100 g, não permite pesos por porção e não foi usada.",
        'file': MANUFACTURER,
    },
    'pans_pt': {
        'name': 'Pans & Company — tabela nutricional para Portugal',
        'license': 'Valores publicados para os restaurantes em Portugal; citados com a data de impressão',
        'url': 'https://www.vivabem.pt/tabelas/tabela_pans_company.pdf',
        'citation': 'Pans & Company. Tabela nutricional válida para Portugal (impressa em 12 de novembro de 2026, documento PSA IC 001pac.56). O peso da unidade é o quociente entre a energia da unidade e a energia por 100 g. Bebidas e linhas em que os kJ não concordam com as kcal ficaram de fora.',
        'file': MANUFACTURER,
    },
}


# Brand chains whose rows are published unit totals (see load_brand_pt).
BRAND_SOURCES = {'mcd_pt', 'kfc_pt', 'bk_pt', 'subway_pt', 'pans_pt', 'dominos_pt', 'pizzahut_pt'}


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


def load_insa(refs):
    """INSA TCA v7.1 (Excel). Energy includes 2 x fibre, so Atwater uses it too."""
    path = download('insa')
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    if digest != SOURCES['insa']['sha256']:
        sys.exit(f'INSA file hash mismatch: {digest}')
    rows = read_rows(path)
    header = None
    for r in rows:
        if r and r[0].strip() == 'Cod':
            header = [_norm(h) for h in r]
            break
    if header is None:
        sys.exit('INSA header row (Cod) not found')

    def col(*parts):
        for i, h in enumerate(header):
            if all(p in h for p in parts):
                return i
        sys.exit(f'INSA column not found: {parts}')

    c_name = col('nome do alimento')
    c_kcal = col('energia', 'kcal')
    c_fat = col('lipidos')
    c_carb = col('hidratos de carbono')
    c_fib = col('fibra')
    c_prot = col('proteinas')
    out = {}
    for r in rows:
        code = r[0].strip() if r else ''
        if code not in refs:
            continue
        cells = r + [''] * (c_prot + 1 - len(r))
        values = {}
        for field, i in (('kcal', c_kcal), ('protein', c_prot), ('carbs', c_carb),
                         ('fat', c_fat), ('fiber', c_fib)):
            t = cells[i].strip().replace(',', '.')
            values[field] = float(t) if t not in ('', '-') else None
        if any(values[f] is None for f in ('kcal', 'protein', 'carbs', 'fat')):
            continue
        fibre = values['fiber'] or 0.0
        expected = 4 * values['protein'] + 4 * values['carbs'] + 9 * values['fat'] + 2 * fibre
        if abs(values['kcal'] - expected) / values['kcal'] > 0.08:
            sys.exit(f'INSA {code}: kcal {values["kcal"]} disagrees with Atwater {expected:.0f}')
        out[code] = dict(values, fiber=fibre, id=code, label=cells[c_name].replace('\n', ' ').strip())
    return out


def load_brand_pt(refs):
    """Published unit totals → per 100 g. portion_g in the TSV must match."""
    products = json.loads(MANUFACTURER.read_text(encoding='utf-8'))
    out = {}
    for ref in refs:
        row = products.get(ref)
        if not row:
            continue
        grams = float(row['grams'])
        if grams <= 0:
            continue
        per100 = {
            field: float(row[field]) * 100 / grams
            for field in ('kcal', 'protein', 'carbs', 'fat')
        }
        expected = 4 * per100['protein'] + 4 * per100['carbs'] + 9 * per100['fat']
        if abs(per100['kcal'] - expected) / per100['kcal'] > 0.08:
            sys.exit(f'{ref}: published kcal {row["kcal"]} disagrees with Atwater {expected * grams / 100:.0f}')
        out[ref] = {
            'id': ref,
            'label': row['label'],
            'fiber': float(row.get('fiber') or 0) * 100 / grams,
            **per100,
            'grams': grams,
        }
    return out


LOADERS = {
    'usda': load_usda,
    'ciqual': load_ciqual,
    'insa': load_insa,
    'taco': load_taco,
    'mcd_pt': load_brand_pt,
    'kfc_pt': load_brand_pt,
    'bk_pt': load_brand_pt,
    'subway_pt': load_brand_pt,
    'pans_pt': load_brand_pt,
    'dominos_pt': load_brand_pt,
    'pizzahut_pt': load_brand_pt,
}


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
        if row['source'] in BRAND_SOURCES and float(row['portion_g']) != v['grams']:
            problems.append(
                f"{row['key']}: portion_g {row['portion_g']} != published grams {v['grams']}"
            )
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
