import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../app/l10n/strings.dart';
import '../../core/ai/local_intelligence_repository.dart';
import '../../core/database/app_database.dart';
import '../../core/ui/vyro_ui.dart';
import '../nutrition/data/food_database.dart';
import '../nutrition/domain/food_product.dart' show dayKey;
import '../nutrition/meals.dart';
import '../nutrition/widgets/food_picker_sheet.dart';

String _text(BuildContext c, String pt, String en) =>
    stringsOf(c).isEnglish ? en : pt;
Future<String?> _editText(
  BuildContext context,
  String title, {
  String initial = '',
  bool number = false,
  int maxLength = 240,
}) async {
  final input = TextEditingController(text: initial);
  final result = await showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: input,
        autofocus: true,
        maxLength: maxLength,
        maxLines: number ? 1 : 3,
        keyboardType: number
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.multiline,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c),
          child: Text(stringsOf(c).get('cancel')),
        ),
        FilledButton(
          onPressed: () {
            if (input.text.trim().isNotEmpty)
              Navigator.pop(c, input.text.trim());
          },
          child: Text(stringsOf(c).get('save')),
        ),
      ],
    ),
  );
  // The route may still animate out while its text field is mounted.
  WidgetsBinding.instance.addPostFrameCallback((_) => input.dispose());
  return result;
}

class LocalIntelligencePage extends StatefulWidget {
  const LocalIntelligencePage({super.key, this.day});
  final DateTime? day;
  @override
  State<LocalIntelligencePage> createState() => _LocalIntelligencePageState();
}

class _LocalIntelligencePageState extends State<LocalIntelligencePage> {
  Map<String, String> _memory = {};
  List<LocalRecipe> _recipes = [];
  Map<String, num> _metrics = {};
  bool _learning = true, _loading = true;
  String? _error;
  LocalIntelligenceRepository get _repo =>
      AppServicesScope.of(context).localIntelligence;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loading) _load();
  }

  Future<void> _load() async {
    try {
      final repo = _repo;
      final memory = await repo.memories();
      final recipes = await repo.recipes();
      final metrics = await repo.metrics();
      final learning = await repo.learningEnabled();
      if (mounted)
        setState(() {
          _memory = memory;
          _recipes = recipes;
          _metrics = metrics;
          _learning = learning;
          _loading = false;
          _error = null;
        });
    } catch (_) {
      if (mounted)
        setState(() {
          _loading = false;
          _error = stringsOf(context).get('localError');
        });
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
      if (mounted) await _load();
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(stringsOf(context).get('localError'))),
        );
    }
  }

  Future<void> _memoryEdit([String? id]) async {
    final value = await _editText(
      context,
      _text(
        context,
        'Preferência confirmada por ti',
        'A preference you confirm',
      ),
      initial: _memory[id] ?? '',
    );
    if (value == null || !mounted) return;
    await _run(
      () => _repo.saveMemory(
        id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        value,
      ),
    );
  }

  Future<void> _recipeEdit([LocalRecipe? recipe]) async {
    final value = await Navigator.push<LocalRecipe>(
      context,
      MaterialPageRoute(builder: (_) => _RecipeEditor(recipe: recipe)),
    );
    if (value != null && mounted) await _run(() => _repo.saveRecipe(value));
  }

  Future<void> _log(LocalRecipe recipe) async {
    final services = AppServicesScope.of(context);
    final amount = await _editText(
      context,
      _text(context, 'Quantidade servida (g)', 'Serving weight (g)'),
      initial: '150',
      number: true,
      maxLength: 8,
    );
    final grams = double.tryParse((amount ?? '').replaceAll(',', '.'));
    if (grams == null ||
        !grams.isFinite ||
        grams <= 0 ||
        grams > 10000 ||
        !mounted)
      return;
    final t = stringsOf(context);
    var meal = mealForTime(DateTime.now());
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, update) => AlertDialog(
          title: Text(recipe.name),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${grams.round()} g · ${(recipe.asFood().kcal * grams / 100).round()} kcal',
              ),
              DropdownButton<String>(
                value: meal,
                isExpanded: true,
                items: [
                  for (final m in mealTypes)
                    DropdownMenuItem(value: m, child: Text(mealLabel(t, m))),
                ],
                onChanged: (v) {
                  if (v != null) update(() => meal = v);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(t.get('cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(t.get('add')),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(() async {
      final food = recipe.asFood();
      await services.nutritionRepository.addEntry(
        FoodEntriesCompanion.insert(
          day: dayKey(widget.day ?? DateTime.now()),
          mealType: meal,
          name: recipe.name,
          quantityGrams: grams,
          kcalPer100g: Value(food.kcal),
          proteinPer100g: Value(food.protein),
          carbsPer100g: Value(food.carbs),
          fatPer100g: Value(food.fat),
          source: Value(food.sourceKey),
        ),
      );
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _text(
                context,
                'Refeição adicionada ao diário',
                'Meal added to diary',
              ),
            ),
          ),
        );
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = stringsOf(context);
    return VyroSubpageScaffold(
      title: _text(context, 'Os teus dados locais', 'Your local data'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  _text(
                    context,
                    'Tudo fica neste dispositivo. Podes editar e apagar; estes dados acompanham a exportação local.',
                    'Everything stays on this device. Edit or delete it here; it is included in your local export.',
                  ),
                ),
                if (_error != null) Text(_error!),
                const SizedBox(height: 24),
                Text(
                  _text(
                    context,
                    'O que a VYRO sabe sobre ti',
                    'What VYRO knows about you',
                  ),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  _text(
                    context,
                    'Apenas preferências que adicionaste. O assistente não cria memórias automaticamente.',
                    'Only preferences you added. The assistant never creates memories automatically.',
                  ),
                ),
                const SizedBox(height: 8),
                for (final e in _memory.entries)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(e.value),
                    onTap: () => _memoryEdit(e.key),
                    trailing: IconButton(
                      tooltip: t.get('delete'),
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _run(() => _repo.deleteMemory(e.key)),
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: () => _memoryEdit(),
                  icon: const Icon(Icons.add),
                  label: Text(
                    _text(context, 'Adicionar preferência', 'Add preference'),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  _text(context, 'Receitas habituais', 'Your recipes'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  _text(
                    context,
                    'Nutrientes dos ingredientes e peso final cozinhado. Escolhe cada ingrediente no estado em que o pesaste.',
                    'Ingredient nutrients and final cooked weight. Select each ingredient in the state in which you weighed it.',
                  ),
                ),
                const SizedBox(height: 8),
                for (final recipe in _recipes)
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          title: Text(recipe.name),
                          subtitle: Text(
                            '${recipe.yieldGrams.round()} g · ${recipe.asFood().kcal.round()} kcal/100 g',
                          ),
                          onTap: () => _recipeEdit(recipe),
                          trailing: IconButton(
                            tooltip: t.get('delete'),
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () =>
                                _run(() => _repo.deleteRecipe(recipe.id)),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => _log(recipe),
                          icon: const Icon(Icons.add),
                          label: Text(
                            _text(
                              context,
                              'Registar uma porção',
                              'Log a serving',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _recipeEdit(),
                  icon: const Icon(Icons.add),
                  label: Text(_text(context, 'Criar receita', 'Create recipe')),
                ),
                const SizedBox(height: 24),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    _text(
                      context,
                      'Aprender com correções',
                      'Learn from corrections',
                    ),
                  ),
                  subtitle: Text(
                    _text(
                      context,
                      'Ordena sugestões a partir das tuas escolhas. Nunca confirma um alimento por ti nem guarda fotografias.',
                      'Ranks suggestions using your choices. Never confirms food for you or saves photos.',
                    ),
                  ),
                  value: _learning,
                  onChanged: (value) =>
                      _run(() => _repo.setLearningEnabled(value)),
                ),
                TextButton(
                  onPressed: () => _run(() => _repo.clearCorrections()),
                  child: Text(
                    _text(
                      context,
                      'Apagar correções aprendidas',
                      'Clear learned corrections',
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  _text(context, 'Qualidade e esforço', 'Quality and effort'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  _text(
                    context,
                    'Contadores locais, sem imagens, mensagens ou envio de dados. Não medem a precisão clínica ou nutricional.',
                    'Local counters, without images, messages or data uploads. They do not measure clinical or nutritional accuracy.',
                  ),
                ),
                for (final pair in <(String, String)>[
                  (
                    'photos',
                    _text(
                      context,
                      'Refeições confirmadas por foto',
                      'Photo meals confirmed',
                    ),
                  ),
                  (
                    'corrected',
                    _text(
                      context,
                      'Alimentos/porções corrigidos',
                      'Foods/portions corrected',
                    ),
                  ),
                  (
                    'removed',
                    _text(
                      context,
                      'Sugestões removidas',
                      'Suggestions removed',
                    ),
                  ),
                  (
                    'added',
                    _text(context, 'Alimentos acrescentados', 'Foods added'),
                  ),
                  (
                    'helpful',
                    _text(context, 'Respostas úteis', 'Helpful answers'),
                  ),
                  (
                    'unhelpful',
                    _text(
                      context,
                      'Respostas a melhorar',
                      'Answers to improve',
                    ),
                  ),
                ])
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(pair.$2),
                    trailing: Text(
                      '${_metrics[pair.$1] ?? 0}',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                if ((_metrics['photos'] ?? 0) > 0)
                  Text(
                    _text(
                          context,
                          'Tempo médio para confirmar: ',
                          'Average confirmation time: ',
                        ) +
                        ('${((_metrics['reviewMs'] ?? 0) / (_metrics['photos'] ?? 1) / 1000).round()} s'),
                  ),
                TextButton(
                  onPressed: () => _run(() => _repo.clearMetrics()),
                  child: Text(
                    _text(context, 'Repor contadores', 'Reset counters'),
                  ),
                ),
              ],
            ),
    );
  }
}

class _RecipeEditor extends StatefulWidget {
  const _RecipeEditor({this.recipe});
  final LocalRecipe? recipe;
  @override
  State<_RecipeEditor> createState() => _RecipeEditorState();
}

class _RecipeEditorState extends State<_RecipeEditor> {
  late final _name = TextEditingController(text: widget.recipe?.name ?? '');
  late final _yield = TextEditingController(
    text: widget.recipe?.yieldGrams.toString() ?? '',
  );
  late final _ingredients = [...?widget.recipe?.ingredients];
  String? _error;
  @override
  void dispose() {
    _name.dispose();
    _yield.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final db = await FoodDatabase.load();
    if (!mounted) return;
    final food = await showFoodPicker(context, db);
    if (food == null || !mounted) return;
    final value = await _editText(
      context,
      '${food.name(stringsOf(context).isEnglish)} (g)',
      initial: food.portionG.round().toString(),
      number: true,
      maxLength: 8,
    );
    final grams = double.tryParse((value ?? '').replaceAll(',', '.'));
    if (grams != null &&
        grams.isFinite &&
        grams > 0 &&
        grams <= 100000 &&
        mounted)
      setState(() => _ingredients.add(RecipeIngredient.fromFood(food, grams)));
  }

  void _save() {
    final recipe = LocalRecipe(
      id: widget.recipe?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name: _name.text.trim(),
      yieldGrams: double.tryParse(_yield.text.replaceAll(',', '.')) ?? 0,
      ingredients: List.of(_ingredients),
    );
    try {
      recipe.validate();
      Navigator.pop(context, recipe);
    } catch (_) {
      setState(
        () => _error = _text(
          context,
          'Indica um nome, ingredientes e peso final válido.',
          'Enter a name, ingredients and a valid final weight.',
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => VyroSubpageScaffold(
    title: _text(context, 'Receita habitual', 'Your recipe'),
    footer: VyroPrimaryButton(
      label: stringsOf(context).get('save'),
      onPressed: _save,
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        TextField(
          controller: _name,
          maxLength: 80,
          decoration: InputDecoration(
            labelText: _text(context, 'Nome', 'Name'),
          ),
        ),
        TextField(
          controller: _yield,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: _text(
              context,
              'Peso final depois de cozinhar (g)',
              'Final weight after cooking (g)',
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _text(
            context,
            'Os valores são estimativas calculadas a partir da base alimentar. Usa o peso da parte comestível; perdas de nutrientes na preparação não são modeladas.',
            'Values are estimates calculated from the food database. Use edible weights; nutrient losses during preparation are not modelled.',
          ),
        ),
        for (final i in _ingredients)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(i.name),
            subtitle: Text('${i.grams.round()} g'),
            trailing: IconButton(
              tooltip: stringsOf(context).get('delete'),
              icon: const Icon(Icons.close),
              onPressed: () => setState(() => _ingredients.remove(i)),
            ),
          ),
        OutlinedButton.icon(
          onPressed: _add,
          icon: const Icon(Icons.add),
          label: Text(
            _text(context, 'Adicionar ingrediente', 'Add ingredient'),
          ),
        ),
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    ),
  );
}
