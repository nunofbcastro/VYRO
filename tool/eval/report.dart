/// Writes one evaluation run as Markdown (summary + per-photo detail).
library;

import 'scoring.dart';

/// Markdown report for one run. [meta] is shown as a key/value list.
String runMarkdown({
  required Map<String, Object?> meta,
  required List<ImageScore> images,
}) {
  final summary = EvalSummary.of(images);
  final b = StringBuffer()
    ..writeln('# Food vision evaluation: ${meta['strategy']}')
    ..writeln();
  for (final entry in meta.entries) {
    b.writeln('- **${entry.key}**: ${entry.value ?? '-'}');
  }
  b
    ..writeln()
    ..writeln('## Summary')
    ..writeln()
    ..write(summaryMarkdownTable([('${meta['strategy']}', summary)]))
    ..writeln()
    ..writeln(
      'Micro counts: TP ${summary.tp}, FP ${summary.fp}, FN ${summary.fn}. '
      'Exact meal = every required food found and nothing extra.',
    )
    ..writeln()
    ..writeln('## Per photo')
    ..writeln()
    ..writeln('| Photo | Exact | TP | FP | FN | Latency | Error |')
    ..writeln('|---|---|---|---|---|---|---|');
  for (final image in images) {
    b.writeln(
      '| ${image.file} | ${image.exactMeal ? 'yes' : 'no'} | ${image.tp} | '
      '${image.fp} | ${image.fn} | ${formatMs(image.latencyMs)} | '
      '${image.error ?? ''} |',
    );
  }
  for (final image in images) {
    b
      ..writeln()
      ..writeln('### ${image.file}')
      ..writeln();
    if (image.notes.isNotEmpty) b.writeln('${image.notes}\n');
    b
      ..writeln(
        '- **Predicted**: ${_list([for (final p in image.predicted) '${p.name}${p.key == null ? ' (no DB row)' : ' → ${p.key}'}'])}',
      )
      ..writeln(
        '- **Matched**: ${_list([for (final (l, p) in image.match.matched) '${l.name} ← ${p.name}'])}',
      )
      ..writeln(
        '- **Misses** (required): ${_list([for (final m in image.match.misses) m.name])}',
      )
      ..writeln(
        '- **Optional, not found**: ${_list([for (final m in image.match.optionalMisses) m.name])}',
      )
      ..writeln(
        '- **False positives**: ${_list([for (final p in image.match.falsePositives) p.name])}',
      )
      ..writeln('- **Suggestions (not scored)**: ${_list(image.suggestions)}');
    if (image.error != null) b.writeln('- **Error**: `${image.error}`');
    if (image.appDetail != null && image.appDetail!.isNotEmpty) {
      b
        ..writeln()
        ..writeln('<details><summary>App diagnostics</summary>')
        ..writeln()
        ..writeln('```text')
        ..writeln(image.appDetail)
        ..writeln('```')
        ..writeln('</details>');
    }
    if (image.rawAnswers.isNotEmpty) {
      b
        ..writeln()
        ..writeln('<details><summary>Raw model answers</summary>')
        ..writeln();
      for (final raw in image.rawAnswers) {
        b
          ..writeln('```text')
          ..writeln(raw)
          ..writeln('```');
      }
      b.writeln('</details>');
    }
  }
  return b.toString();
}

String _list(List<String> items) => items.isEmpty ? '-' : items.join(', ');
