import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Availability of the operating system's language model.
enum LlmStatus {
  /// Ready to answer.
  available,

  /// Supported, but the system still has to download the model (Android).
  downloadable,

  /// The system is downloading or preparing the model.
  downloading,

  /// Not supported on this device / OS version, or turned off.
  unavailable;

  static LlmStatus parse(Object? raw) => switch (raw) {
    'available' => available,
    'downloadable' => downloadable,
    'downloading' => downloading,
    _ => unavailable,
  };
}

/// On-device LLM provided by the OS — no model bundled, no paid API, no
/// network inference:
/// - iOS 26+: Apple Intelligence via the Foundation Models framework
///   (`ios/Runner/AppDelegate.swift`);
/// - Android: Gemini Nano via ML Kit GenAI / AICore
///   (`android/.../llm/OnDeviceLlmChannel.kt`).
///
/// Everywhere else (web, desktop, older phones) [status] is
/// [LlmStatus.unavailable].
abstract interface class OnDeviceLlm {
  Future<LlmStatus> status();
  Future<LlmStatus> download();
  Future<String> generate(String prompt);
}

class PlatformOnDeviceLlm implements OnDeviceLlm {
  const PlatformOnDeviceLlm();

  static const _channel = MethodChannel('vyro/on_device_llm');

  static bool get _platformSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Future<LlmStatus> status() async {
    if (!_platformSupported) return LlmStatus.unavailable;
    try {
      return LlmStatus.parse(await _channel.invokeMethod<String>('status'));
    } catch (_) {
      return LlmStatus.unavailable;
    }
  }

  @override
  Future<LlmStatus> download() async {
    if (!_platformSupported) return LlmStatus.unavailable;
    try {
      return LlmStatus.parse(await _channel.invokeMethod<String>('download'));
    } catch (_) {
      return status();
    }
  }

  @override
  Future<String> generate(String prompt) async {
    if (!_platformSupported) {
      throw const LlmException('unavailable');
    }
    try {
      final text = await _channel.invokeMethod<String>('generate', {
        'prompt': prompt,
      });
      final trimmed = text?.trim() ?? '';
      if (trimmed.isEmpty) throw const LlmException('empty');
      return trimmed;
    } on PlatformException catch (error) {
      throw LlmException(error.code);
    }
  }
}

class LlmException implements Exception {
  const LlmException(this.code);
  final String code;

  @override
  String toString() => 'LlmException($code)';
}

/// Local facts the assistant may use. Built from on-device data only.
class AssistantContext {
  const AssistantContext({
    this.goal,
    this.kcalGoal,
    this.proteinGoal,
    this.kcalToday,
    this.proteinToday,
    this.foodsToday = const [],
    this.planTitle,
    this.nextWorkout,
    this.nextWorkoutDay,
    this.nextExercises = const [],
    this.weekDone,
    this.weekTotal,
  });

  final String? goal;
  final int? kcalGoal;
  final int? proteinGoal;
  final int? kcalToday;
  final int? proteinToday;
  final List<String> foodsToday;
  final String? planTitle;
  final String? nextWorkout;
  final String? nextWorkoutDay;
  final List<String> nextExercises;
  final int? weekDone;
  final int? weekTotal;
}

class ChatTurn {
  const ChatTurn({required this.fromUser, required this.text});
  final bool fromUser;
  final String text;
}

/// Builds the full prompt: safety instructions, the user's local context,
/// the recent conversation and the new question. Kept as plain text so the
/// same prompt works with both system models.
String buildAssistantPrompt({
  required String question,
  required AssistantContext context,
  List<ChatTurn> history = const [],
  bool english = false,
  int maxHistory = 6,
}) {
  final b = StringBuffer();
  if (english) {
    b.writeln(
      'You are the assistant inside VYRO, a nutrition and training app. '
      'Answer in English, briefly (at most 120 words), practical and kind. '
      'Never diagnose or give medical advice: for pain, injury, pregnancy, '
      'illness or medication, recommend a health professional. Do not invent '
      'exact nutrient values; say when you are unsure. The training plan '
      'comes from editable rules in the app; suggest small adjustments, never '
      'a replacement prescription. Use the user data below only when relevant.',
    );
    b.writeln('\nUser data (stored on this device):');
  } else {
    b.writeln(
      'És o assistente da VYRO, uma app de nutrição e treino. Responde em '
      'português de Portugal, de forma breve (no máximo 120 palavras), prática '
      'e simpática. Nunca faças diagnósticos nem dês conselhos médicos: para '
      'dor, lesão, gravidez, doença ou medicação, recomenda um profissional de '
      'saúde. Não inventes valores nutricionais exatos; diz quando não tens a '
      'certeza. O plano de treino vem de regras editáveis da app; sugere '
      'pequenos ajustes, nunca uma prescrição nova. Usa os dados abaixo só '
      'quando forem relevantes.',
    );
    b.writeln('\nDados do utilizador (guardados neste dispositivo):');
  }
  void line(String pt, String en, Object? value) {
    if (value == null) return;
    if (value is String && value.isEmpty) return;
    if (value is List && value.isEmpty) return;
    final shown = value is List ? value.join(', ') : '$value';
    b.writeln('- ${english ? en : pt}: $shown');
  }

  final c = context;
  final proteinWord = english ? 'protein' : 'proteína';
  final workoutsWord = english ? 'workouts' : 'treinos';
  line('Objetivo', 'Goal', c.goal);
  line(
    'Meta diária',
    'Daily target',
    c.kcalGoal == null
        ? null
        : '${c.kcalGoal} kcal, ${c.proteinGoal ?? '?'} g $proteinWord',
  );
  line(
    'Hoje',
    'Today',
    c.kcalToday == null
        ? null
        : '${c.kcalToday} kcal, ${c.proteinToday ?? 0} g $proteinWord',
  );
  line('Alimentos de hoje', 'Foods today', c.foodsToday.take(10).toList());
  line('Plano', 'Plan', c.planTitle);
  line(
    'Próximo treino',
    'Next workout',
    c.nextWorkout == null
        ? null
        : '${c.nextWorkout}${c.nextWorkoutDay == null ? '' : ' (${c.nextWorkoutDay})'}',
  );
  line('Exercícios', 'Exercises', c.nextExercises.take(8).toList());
  line(
    'Esta semana',
    'This week',
    c.weekTotal == null
        ? null
        : '${c.weekDone ?? 0}/${c.weekTotal} $workoutsWord',
  );

  final recent = history.length > maxHistory
      ? history.sublist(history.length - maxHistory)
      : history;
  if (recent.isNotEmpty) {
    b.writeln(english ? '\nConversation so far:' : '\nConversa até agora:');
    for (final turn in recent) {
      final who = turn.fromUser
          ? (english ? 'User' : 'Utilizador')
          : (english ? 'Assistant' : 'Assistente');
      b.writeln('$who: ${turn.text}');
    }
  }
  b.writeln();
  b.writeln('${english ? 'User' : 'Utilizador'}: ${question.trim()}');
  b.write(english ? 'Assistant:' : 'Assistente:');
  return b.toString();
}
