# Base nutricional offline

O VYRO calcula calorias e macros **sem Internet** a partir de uma base de
alimentos incluída na app: `assets/nutrition/foods.json`. Esse ficheiro é
**gerado** (nunca editado à mão) pelo script
`tool/nutrition/build_food_db.py`, a partir da lista curada
`tool/nutrition/foods_pt.tsv` e de tabelas oficiais de composição de
alimentos descarregadas legalmente.

```
foods_pt.tsv (curado à mão: nomes PT/EN, fonte + referência, porção, unidades da porção, aliases, etiquetas de imagem)
        │
        ▼  build_food_db.py  (descarrega/usa build/usda, build/ciqual, build/taco)
assets/nutrition/foods.json  (168 alimentos, valores por 100 g, fonte de cada um)
        │
        ▼  FoodDatabase.load()  (lib/features/nutrition/data/food_database.dart)
fotografia, assistente, diário  →  kcal = gramas × kcal/100 g ÷ 100

Receitas habituais do utilizador (guardadas só no dispositivo, ver abaixo) são
uma terceira origem: os valores por 100 g são calculados a partir dos
ingredientes e do peso final cozinhado. Não entram em `foods.json`.
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
- `portion_units` (coluna opcional, última do TSV; preenchida em 82 dos 168
  alimentos) indica quantas peças correspondem a `portion_g`: 3 sardinhas = 120 g
  ⇒ `portion_units = 3`. A app escala a contagem de peças por
  `portion_g × peças ÷ portion_units`. Sem valor, a contagem não multiplica a
  porção (ex.: arroz, sopas).
- Valores variam com a variedade, a preparação e a amostra. Não são
  aconselhamento médico.

## Equivalências aproximadas

Alguns nomes usados em fotografias ou em conversa não existem como tal nas
tabelas. Nesses casos o VYRO usa o alimento mais próximo, com a referência
indicada no campo sourceLabel de cada alimento. O utilizador confirma sempre o
alimento e as gramas.

- Água das Pedras (com ou sem limão): água com gás (sem limão) ou limonada
  (com limão, Ciqual «Limonade, sucrée»). A versão aromatizada pode ter
  açúcar; a limonada é a estimativa conservadora.
- Molho de cerveja: molho castanho de carne (USDA «Gravy, beef, canned»).
- Sidra e Somersby: Ciqual «Cidre (aliment moyen)».
- Refresco de laranja (Sumol): Ciqual «Jus d'orange, à base de concentré»
  (não há refrigerante de laranja na Ciqual).
- Pizza de pepperoni: Ciqual «Pizza au chorizo ou salami».
- Pizza inteira (individual, 350 g ≈ 3 fatias de uma pizza grande): mesmas
  referências USDA/Ciqual das fatias (a composição por 100 g é a mesma; só a
  porção muda). Fatias: 110 g cada (8 fatias ≈ 880 g). O nome «pizza» sem
  mais nada refere-se à pizza inteira; as fatias usam «fatia de pizza».
  Francesinha: não existe na base (ainda sem referência adequada).
- Molho de hambúrguer (Big Mac, molho especial): Ciqual «Sauce burger».
- Natas para cozinha: USDA «Cream, fluid, light whipping» (creme de leite
  no Brasil tem teor de gordura diferente; a estimativa é aproximada).
- Croissant misto: Ciqual «Croissant au jambon fromage, fait maison».
- Sandes mista: Ciqual «Sandwich pain polaire, jambon fromage».
- Presunto: Ciqual «Jambon cru» (curado). O fiambre (cozido) mantém a sua linha.
- Bife de vaca frito: Ciqual «Boeuf, steak ou bifteck grillé/poêlé».
- Ketchup: Ciqual «Ketchup, préemballé» (11008).
- Molho de tomate (para massa): USDA «Sauce, pasta, spaghetti/marinara,
  ready-to-serve» (171192). Não é o molho de carne (bolonhesa).
- Queijo ralado: USDA «Cheese, parmesan, grated» (171247).
- Mostarda: USDA «Mustard, prepared, yellow» (172234), mostarda amarela.
- Molho de soja (shoyu): Ciqual «Sauce soja, préemballée» (11104).
- Molho de iogurte: Ciqual «Sauce au yaourt, faite maison» (11166). Não é o
  tzatziki (sem pepino nem alho); o nome tzatziki não está nos aliases.

## Receitas habituais (locais)

Em Nutrição → Receitas habituais (`LocalRecipe` em
`lib/core/ai/local_intelligence_repository.dart`), o utilizador cria receitas
com:

- **peso final cozinhado** (`yieldGrams`, entre 0 e 100 kg), que é o denominador;
- ingredientes escolhidos da base, cada um com a **quantidade usada no estado em
  que foi pesado** (cru, cozido…) e um instantâneo dos seus valores por 100 g.

Valores por 100 g da receita = Σ(nutriente do ingrediente × gramas do
ingrediente) ÷ peso final cozinhado. Assim, a água perdida ou ganha na cozedura
é refletida pelo peso final, não por suposição. Limites: 100 receitas, 100
ingredientes por receita, nome até 80 caracteres. Ao registar uma porção, o
utilizador indica os gramas servidos (por omissão 150 g) e a receita fica como
alimento com origem `recipe`. Receitas e os seus valores são guardados só no
dispositivo e incluídos na exportação local.

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
