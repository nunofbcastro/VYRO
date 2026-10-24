import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:drift/drift.dart' show Value;
import 'package:image_picker/image_picker.dart';

import '../../app/app_services.dart';
import '../../app/l10n/strings.dart';
import '../../core/database/app_database.dart';
import '../../core/platform/image_temp_file.dart';
import '../../core/widgets/vyro_widgets.dart';
import 'domain/food_recognition_service.dart';

class PhotoFoodPage extends StatefulWidget {
  const PhotoFoodPage({super.key, this.day});
  final DateTime? day;

  @override
  State<PhotoFoodPage> createState() => _PhotoFoodPageState();
}

class _PhotoFoodPageState extends State<PhotoFoodPage> {
  final _picker = ImagePicker();
  final _recognizer = LiteRtFoodRecognitionService();
  Uint8List? _photo;
  List<FoodCandidate>? _candidates;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _photo = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = stringsOf(context);
    return ContentPage(
      title: t.get('photo'),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.privacy_tip_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(t.get('photoLocalPrivacy'))),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  t.get('photoModelCaveat'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        if (_photo case final photo?) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.memory(
              photo,
              height: 230,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 14),
        ],
        if (kIsWeb)
          Card(
            child: ListTile(
              leading: const Icon(Icons.phone_android),
              title: Text(t.get('photoNativeOnly')),
            ),
          )
        else ...[
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _chooseImage(ImageSource.camera),
            icon: const Icon(Icons.photo_camera_outlined),
            label: Text(t.get('takePhoto')),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _busy ? null : () => _chooseImage(ImageSource.gallery),
            icon: const Icon(Icons.photo_library_outlined),
            label: Text(t.get('choosePhoto')),
          ),
        ],
        if (_busy) ...[
          const SizedBox(height: 20),
          const Center(child: CircularProgressIndicator()),
          const SizedBox(height: 8),
          Center(child: Text(t.get('photoAnalyzing'))),
        ],
        if (_error != null) ...[
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(t.get(_error!)),
              subtitle: Text(t.get('photoManualFallback')),
            ),
          ),
        ],
        if (_candidates case final candidates?) ...[
          const SizedBox(height: 20),
          SectionTitle(
            t.get(candidates.isEmpty ? 'photoNoMatch' : 'foodReview'),
          ),
          if (candidates.isEmpty)
            Card(
              child: ListTile(
                leading: const Icon(Icons.help_outline),
                title: Text(t.get('photoUnknown')),
                subtitle: Text(t.get('photoManualFallback')),
              ),
            ),
          for (final candidate in candidates)
            Card(
              child: ListTile(
                leading: const Icon(Icons.restaurant_outlined),
                title: Text(_localizedFoodLabel(candidate.label, t)),
                subtitle: Text(
                  '${(candidate.confidence * 100).toStringAsFixed(1)}% · ${t.get('photoHypothesis')}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _confirmCandidate(candidate),
              ),
            ),
        ],
        if (_photo == null) ...[
          const SizedBox(height: 18),
          Center(child: Text(t.get('photoNoImage'))),
        ],
      ],
    );
  }

  Future<void> _chooseImage(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 88,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      // Photo-picker/camera temporary file is deleted as soon as bytes are read.
      await deleteTemporaryImage(file.path);
      if (!mounted) return;
      setState(() {
        _photo = bytes;
        _candidates = null;
        _error = null;
        _busy = true;
      });
      try {
        final candidates = await _recognizer.recognize(bytes);
        if (mounted) setState(() => _candidates = candidates);
      } on FormatException {
        if (mounted) setState(() => _error = 'photoInvalidImage');
      } catch (_) {
        if (mounted) setState(() => _error = 'photoModelError');
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    } catch (_) {
      if (mounted)
        setState(() {
          _error = 'cameraError';
          _busy = false;
        });
    }
  }

  Future<void> _confirmCandidate(FoodCandidate candidate) async {
    final t = stringsOf(context);
    final services = AppServicesScope.of(context);
    final draft = await showDialog<_PhotoFoodDraft>(
      context: context,
      builder: (_) =>
          _PhotoFoodDialog(candidate: _localizedFoodLabel(candidate.label, t)),
    );
    if (draft == null) return;
    await services.nutritionRepository.addEntry(
      FoodEntriesCompanion.insert(
        day: _dayKey(widget.day ?? DateTime.now()),
        mealType: draft.meal,
        name: draft.name,
        quantityGrams: draft.quantityGrams,
        kcalPer100g: Value(draft.kcalPer100g),
        proteinPer100g: Value(draft.proteinPer100g),
        carbsPer100g: Value(draft.carbsPer100g),
        fatPer100g: Value(draft.fatPer100g),
        source: const Value('photo_suggestion'),
      ),
    );
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t.get('entryAdded'))));
      Navigator.pop(context);
    }
  }
}

class _PhotoFoodDialog extends StatefulWidget {
  const _PhotoFoodDialog({required this.candidate});
  final String candidate;

  @override
  State<_PhotoFoodDialog> createState() => _PhotoFoodDialogState();
}

class _PhotoFoodDialogState extends State<_PhotoFoodDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  final _quantity = TextEditingController();
  final _kcal = TextEditingController();
  final _protein = TextEditingController();
  final _carbs = TextEditingController();
  final _fat = TextEditingController();
  String _meal = 'snack';

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.candidate);
  }

  @override
  void dispose() {
    _name.dispose();
    _quantity.dispose();
    _kcal.dispose();
    _protein.dispose();
    _carbs.dispose();
    _fat.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = stringsOf(context);
    return AlertDialog(
      title: Text(t.get('foodReview')),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(t.get('photoConfirmNote')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _meal,
                decoration: InputDecoration(labelText: t.get('selectMeal')),
                items: [
                  for (final value in ['breakfast', 'lunch', 'dinner', 'snack'])
                    DropdownMenuItem(value: value, child: Text(t.get(value))),
                ],
                onChanged: (value) => setState(() => _meal = value ?? _meal),
              ),
              _field(_name, t.get('foodName'), required: true),
              _field(
                _quantity,
                '${t.get('quantity')} (${t.get('grams')})',
                required: true,
                number: true,
              ),
              _field(_kcal, t.get('kcalPer100'), number: true),
              _field(_protein, t.get('proteinPer100'), number: true),
              _field(_carbs, t.get('carbsPer100'), number: true),
              _field(_fat, t.get('fatPer100'), number: true),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t.get('cancel')),
        ),
        FilledButton(onPressed: _save, child: Text(t.get('confirmFood'))),
      ],
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = false,
    bool number = false,
  }) => TextFormField(
    controller: controller,
    keyboardType: number
        ? const TextInputType.numberWithOptions(decimal: true)
        : TextInputType.text,
    decoration: InputDecoration(labelText: label),
    validator: (value) {
      final raw = value?.trim() ?? '';
      if (required && raw.isEmpty) return stringsOf(context).get('error');
      if (number && raw.isNotEmpty && _parse(raw) == null)
        return stringsOf(context).get('error');
      if (identical(controller, _quantity) && (_parse(raw) ?? 0) <= 0)
        return stringsOf(context).get('error');
      return null;
    },
  );

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      _PhotoFoodDraft(
        meal: _meal,
        name: _name.text.trim(),
        quantityGrams: _parse(_quantity.text)!,
        kcalPer100g: _parse(_kcal.text),
        proteinPer100g: _parse(_protein.text),
        carbsPer100g: _parse(_carbs.text),
        fatPer100g: _parse(_fat.text),
      ),
    );
  }
}

class _PhotoFoodDraft {
  const _PhotoFoodDraft({
    required this.meal,
    required this.name,
    required this.quantityGrams,
    required this.kcalPer100g,
    required this.proteinPer100g,
    required this.carbsPer100g,
    required this.fatPer100g,
  });
  final String meal;
  final String name;
  final double quantityGrams;
  final double? kcalPer100g;
  final double? proteinPer100g;
  final double? carbsPer100g;
  final double? fatPer100g;
}

String _dayKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

double? _parse(String value) =>
    double.tryParse(value.trim().replaceAll(',', '.'));

String _localizedFoodLabel(String label, VyroStrings strings) {
  if (strings.isEnglish) return label.replaceAll('_', ' ');
  const common = {
    'Apple': 'Maçã',
    'Banana': 'Banana',
    'Bread': 'Pão',
    'Chicken': 'Frango',
    'Egg': 'Ovo',
    'French fries': 'Batatas fritas',
    'Hamburger': 'Hambúrguer',
    'Omelette': 'Omeleta',
    'Pasta': 'Massa',
    'Pizza': 'Pizza',
    'Rice': 'Arroz',
    'Salad': 'Salada',
    'Salmon': 'Salmão',
    'Soup': 'Sopa',
    'Tomato': 'Tomate',
  };
  final plain = label.replaceAll('_', ' ');
  return common[label] ?? plain;
}
