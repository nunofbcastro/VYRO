import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/l10n/strings.dart';
import '../../core/database/app_database.dart';
import 'domain/body_weight.dart';

/// What the sheet hands back to the caller, which owns the database writes.
sealed class BodyWeightSheetResult {
  const BodyWeightSheetResult();
}

/// The user confirmed a valid weight and day.
class BodyWeightSaved extends BodyWeightSheetResult {
  const BodyWeightSaved({required this.weightKg, required this.day});
  final double weightKg;
  final DateTime day;
}

/// The user confirmed deleting the entry that was being edited.
class BodyWeightDeleteRequested extends BodyWeightSheetResult {
  const BodyWeightDeleteRequested();
}

/// Opens the add sheet ([entry] null) or the edit sheet for [entry].
Future<BodyWeightSheetResult?> showBodyWeightSheet(
  BuildContext context, {
  BodyMeasurement? entry,
}) => showModalBottomSheet<BodyWeightSheetResult>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => BodyWeightSheet(entry: entry),
);

/// Body of the add/edit weight sheet. Pops with a [BodyWeightSheetResult].
class BodyWeightSheet extends StatefulWidget {
  const BodyWeightSheet({super.key, this.entry, this.now});

  /// Entry to edit; null when adding.
  final BodyMeasurement? entry;

  /// Clock used for "today" and the date limits. Defaults to the device clock.
  final DateTime? now;

  @override
  State<BodyWeightSheet> createState() => _BodyWeightSheetState();
}

class _BodyWeightSheetState extends State<BodyWeightSheet> {
  late final TextEditingController _controller;
  late DateTime _day;
  String? _error;

  DateTime get _now => widget.now ?? DateTime.now();

  bool _filled = false;

  @override
  void initState() {
    super.initState();
    _day = bodyDay(widget.entry?.measuredAt ?? _now);
    _controller = TextEditingController();
  }

  /// The pre-filled value depends on the locale (decimal comma in pt-PT), so
  /// it is set once the locale is known.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_filled) return;
    _filled = true;
    final entry = widget.entry;
    if (entry != null) {
      _controller.text = formatBodyWeightInput(
        entry.weightKg,
        english: stringsOf(context).isEnglish,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _select(DateTime day) => setState(() => _day = bodyDay(day));

  Future<void> _pickDate() async {
    final today = bodyDay(_now);
    final picked = await showDatePicker(
      context: context,
      initialDate: _day.isAfter(today) ? today : _day,
      firstDate: bodyWeightFirstDay(_now),
      lastDate: today,
    );
    if (picked != null) _select(picked);
  }

  void _save() {
    final t = stringsOf(context);
    final value = parseBodyWeight(_controller.text);
    if (value == null) {
      setState(() => _error = t.get('weightInvalid'));
      return;
    }
    if (_day.isAfter(bodyDay(_now))) {
      setState(() => _error = t.get('weightFuture'));
      return;
    }
    Navigator.pop(context, BodyWeightSaved(weightKg: value, day: _day));
  }

  Future<void> _delete() async {
    final t = stringsOf(context);
    final entry = widget.entry;
    if (entry == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.get('weightDeleteTitle')),
        content: Text(
          t
              .get('weightDeleteBody')
              .replaceAll('{date}', formatBodyDate(bodyDay(entry.measuredAt)))
              .replaceAll(
                '{value}',
                formatBodyWeight(entry.weightKg, english: t.isEnglish),
              ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.get('cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(t.get('weightDeleteConfirm')),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      Navigator.pop(context, const BodyWeightDeleteRequested());
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = stringsOf(context);
    final theme = Theme.of(context);
    final today = bodyDay(_now);
    final yesterday = DateTime(today.year, today.month, today.day - 1);
    final isToday = isSameBodyDay(_day, today);
    final isYesterday = isSameBodyDay(_day, yesterday);
    final isEdit = widget.entry != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            t.get(isEdit ? 'weightEditTitle' : 'logWeight'),
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: !isEdit,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              LengthLimitingTextInputFormatter(5),
            ],
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            decoration: InputDecoration(
              labelText: t.get('weight'),
              suffixText: 'kg',
              errorText: _error,
            ),
          ),
          const SizedBox(height: 20),
          Text(t.get('weightDate'), style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: Text(t.get('weightToday')),
                selected: isToday,
                onSelected: (_) => _select(today),
              ),
              ChoiceChip(
                label: Text(t.get('yesterday')),
                selected: isYesterday,
                onSelected: (_) => _select(yesterday),
              ),
              ChoiceChip(
                avatar: const Icon(Icons.calendar_today_outlined, size: 16),
                label: Text(
                  isToday || isYesterday
                      ? t.get('weightOtherDate')
                      : formatBodyDate(_day),
                ),
                selected: !isToday && !isYesterday,
                onSelected: (_) => _pickDate(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(t.get('weightSheetHint'), style: theme.textTheme.bodySmall),
          const SizedBox(height: 20),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
            onPressed: _save,
            child: Text(t.get('weightSaveEntry')),
          ),
          if (isEdit) ...[
            const SizedBox(height: 4),
            TextButton.icon(
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 48),
                foregroundColor: theme.colorScheme.error,
              ),
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline),
              label: Text(t.get('weightDeleteEntry')),
            ),
          ],
        ],
      ),
    );
  }
}
