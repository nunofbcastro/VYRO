# Base nutricional offline

O VYRO calcula calorias e macros **sem Internet** a partir de uma base de
alimentos incluída na app: `assets/nutrition/foods.json`. Esse ficheiro é
**gerado** (nunca editado à mão) pelo script
`tool/nutrition/build_food_db.py`, a partir da lista curada
`tool/nutrition/foods_pt.tsv` e de tabelas oficiais de composição de
alimentos descarregadas legalmente.

```
foods_pt.tsv (curado à mão: nomes PT/EN, fonte + referência, porção, aliases, etiquetas de imagem)
        │
        ▼  build_food_db.py  (descarrega/usa build/usda, build/ciqual, build/taco)
assets/nutrition/foods.json  (131 alimentos, valores por 100 g, fonte de cada um)
        │
        ▼  FoodDatabase.load()  (lib/features/nutrition/data/food_database.dart)
fotografia, assistente, diário  →  kcal = gramas × kcal/100 g ÷ 100
```

## Fontes e licenças

| Fonte | Região | Licença | Referência no TSV |
|---|---|---|---|
| [USDA FoodData Central — SR Legacy 2018-04](https://fdc.nal.usda.gov/) | `int` | Domínio público (CC0 1.0), atribuição pedida | descrição exata do alimento (`food.csv`) |
| [Ciqual 2025 — ANSES](https://ciqual.anses.fr/) | `pt`, `eu` | Licence Ouverte / etalab-2.0 (atribuição obrigatória) | `alim_code` |
| [TACO 4.ª edição — NEPA/UNICAMP](https://www.cfn.org.br/wp-content/uploads/2017/03/taco_4_edicao_ampliada_e_revisada.pdf) | `br` | Reprodução permitida desde que citada a fonte | número do alimento na Tabela 1 |

Citações (também guardadas em `foods.json → sources`):

- U.S. Department of Agriculture, Agricultural Research Service. FoodData Central, SR Legacy (2018).
- Anses. 2025. Table de composition nutritionnelle des aliments Ciqual. doi:10.57745/RDMHWY
- NEPA/UNICAMP. Tabela Brasileira de Composição de Alimentos – TACO. 4. ed. Campinas, 2011.

A app mostra esta atribuição no ecrã de fotografia (`nutritionSourcesNote`)
e cada registo do diário guarda a origem em `food_entries.source`
(`usda_171477`, `ciqual_26024`, `taco_561`).

**Portugal (INSA / PortFIR TCA):** a tabela portuguesa é a referência ideal
para pratos nacionais, mas as condições de redistribuição não são claras. Não
está incluída. Para a adicionar: obter autorização escrita do INSA, criar um
loader `load_insa` em `build_food_db.py` (mesmo formato dos outros), acrescentar
a fonte a `SOURCES` com a licença e usar `source=insa` no TSV. Até lá, os
alimentos portugueses usam o equivalente Ciqual (bacalhau, pescada, sardinha,
polvo, chouriço, queijo de ovelha, pão caseiro…).

## Convenções

- Energia: kcal por 100 g. USDA usa o nutriente 1008 (fallback 2048/2047 —
  Atwater); Ciqual usa "Energie, Règlement UE N° 1169/2011 (kcal)"; TACO usa a
  coluna kcal da Tabela 1.
- Proteína (Ciqual: fator de Jones), hidratos totais, lípidos, fibra.
- Ciqual: `traces` → 0, `< x` → x/2, `-` → em falta. Energia ou macros em falta
  fazem o build falhar (nunca se inventa um valor).
- TACO: o PDF é lido com `taco_parser.py`; cada linha é validada
  (kJ/kcal entre 4,0 e 4,4 e energia a ±25 % do estimado por Atwater). Linhas
  inválidas são rejeitadas, nunca adivinhadas.
- Porções (`portion_g`, `portion_pt`) são **estimativas do VYRO** para sugerir
  quantidades. O utilizador confirma sempre as gramas.
- Valores variam com a variedade, a preparação e a amostra. Não são
  aconselhamento médico.

## Atualizar ou acrescentar alimentos

Ver a skill `.agents/skills/nutrition-database/SKILL.md` (passo a passo).
Resumo:

```bash
python -I tool/nutrition/build_food_db.py          # gera foods.json
python -I tool/nutrition/build_food_db.py --check  # falha se foods.json estiver desatualizado
flutter test test/food_database_test.dart
```

Requisitos de build (não da app): Python 3.10+, e `pip install pypdf` para as
linhas TACO. Os ficheiros de origem são guardados em `build/` (ignorado pelo
git) e só são descarregados se faltarem.
