import '../exercise_analysis/exercise_analysis_engine.dart';
import '../repetition_counter/rep_counter_engine.dart';
import 'feedback_engine.dart';

/// Language of the spoken coach. Follows the app language.
enum VoiceLanguage { portuguese, english }

/// Order in which queued phrases are spoken (highest first). Rep counts beat
/// form cues, so a cue never delays a count.
enum VoicePriority { cue, encouragement, repCount, summary }

/// One phrase to speak. [at] is when it was queued; stale phrases (older than
/// [VoiceCoach.staleAfter]) are dropped unless they are the summary.
class VoicePhrase {
  const VoicePhrase(this.text, this.priority, this.at);

  final String text;
  final VoicePriority priority;
  final Duration at;

  @override
  String toString() => 'VoicePhrase($text, $priority, ${at.inMilliseconds} ms)';
}

/// What the page observed in one analysed frame, or at the end of a set.
class VoiceObservation {
  const VoiceObservation({
    required this.at,
    this.ready = false,
    this.repEvent,
    this.fullReps = 0,
    this.partialReps = 0,
    this.feedback,
    this.summary,
    this.framingKey,
  });

  final Duration at;

  /// The body is framed and the set is counting (readiness gate passed).
  final bool ready;

  /// Top framing issue before a set (positioning), as a key that
  /// [VoiceCoach] resolves with its text callback (for example `frTooClose`).
  final String? framingKey;

  /// Rep event of this frame, if any.
  final RepEventType? repEvent;

  /// Counts after this frame.
  final int fullReps;
  final int partialReps;

  /// Message the existing [FeedbackEngine] chose for this frame, if any.
  final FeedbackMessage? feedback;

  /// Set-end summary; when present, pending phrases are replaced by it.
  final SetSummary? summary;
}

/// Turns camera-engine events into short spoken phrases.
///
/// Pure Dart with no speech dependency: [observe] queues phrases, [next]
/// returns the next one to speak at a given time (highest priority first,
/// stale phrases dropped), and [clear] silences the queue. The page plays
/// each phrase with a text-to-speech engine and waits for it to finish.
///
/// Phrases are fixed templates in PT-PT and EN. No language model is used, and
/// no phrase claims that a movement is correct or safe.
class VoiceCoach {
  VoiceCoach({
    required this.language,
    bool enabled = true,
    this.staleAfter = const Duration(seconds: 2),
    this.cueMinInterval = const Duration(seconds: 4),
    this.cueRepeatCooldown = const Duration(seconds: 10),
    this.maxPending = 4,
    this.framingMinInterval = const Duration(seconds: 5),
    String Function(String key)? cueText,
  }) : _enabled = enabled,
       _cueText = cueText ?? ((key) => key);

  /// Minimum time between two framing prompts (before a set).
  final Duration framingMinInterval;

  final VoiceLanguage language;

  /// Phrases older than this are dropped when their turn comes.
  final Duration staleAfter;

  /// Minimum time between two form or visibility cues.
  final Duration cueMinInterval;

  /// A cue with the same key is not repeated within this time.
  final Duration cueRepeatCooldown;

  /// Upper bound on queued phrases; the lowest priority is dropped first.
  final int maxPending;

  /// Resolves a feedback key (for example `mfTrunkUpright`) to the text to
  /// speak. The page passes the localised string.
  final String Function(String key) _cueText;

  bool _enabled;
  int? _target;
  List<String> _bank = const [];
  int _bankIndex = 0;
  final _pending = <VoicePhrase>[];
  bool _startCueGiven = false;
  Duration? _lastCueAt;
  Duration? _lastFramingAt;
  final _lastCueSpoken = <String, Duration>{};

  bool get enabled => _enabled;
  int? get target => _target;
  int get pendingCount => _pending.length;

  /// Turning the coach off drops everything queued.
  void setEnabled(bool value) {
    _enabled = value;
    if (!value) clear();
  }

  /// Resets per-set state (start cue, cue throttling, queue). [targetReps] is
  /// optional; without it milestones fall back to every five reps.
  void startSet({int? targetReps}) {
    _target = targetReps;
    _pending.clear();
    _startCueGiven = false;
    _lastCueAt = null;
    _lastFramingAt = null;
    _lastCueSpoken.clear();
  }

  /// Sets the target for milestones without resetting the start cue, so a cue
  /// given during positioning is not repeated when the set starts.
  void setTarget(int? targetReps) => _target = targetReps;

  /// Drops every queued phrase. The page calls this for the silence button.
  void clear() => _pending.clear();

  /// Generated encouragement phrases (validated by `coach_llm_phrases.dart`)
  /// used only in the non-count milestones: "Já são 5. <phrase>" and the
  /// halfway milestone. Count-critical phrases ("Mais duas!", "Última!",
  /// "Objetivo atingido!") stay fixed. An empty list means fixed templates.
  void setEncouragementBank(List<String> phrases) {
    _bank = List.of(phrases);
    _bankIndex = 0;
  }

  /// Queues a set comment after the summary (for example one written by the
  /// on-device model). It is never stale, so it can be spoken a few seconds
  /// after the set ends, and it never replaces the summary.
  List<VoicePhrase> addCommentary(String text, Duration at) {
    if (!_enabled || text.trim().isEmpty) return const [];
    final phrase = VoicePhrase(text, VoicePriority.summary, at);
    _enqueue(phrase);
    return [phrase];
  }

  /// Queues the phrases for [o] and returns them (for inspection and tests).
  List<VoicePhrase> observe(VoiceObservation o) {
    if (!_enabled) return const [];
    final queued = <VoicePhrase>[];
    void add(String text, VoicePriority priority) {
      final phrase = VoicePhrase(text, priority, o.at);
      queued.add(phrase);
      _enqueue(phrase);
    }

    final summary = o.summary;
    if (summary != null) {
      _pending.clear();
      add(_summaryText(summary), VoicePriority.summary);
      return queued;
    }

    if (o.ready &&
        !_startCueGiven &&
        o.fullReps == 0 &&
        o.partialReps == 0 &&
        _cueAllowed('start', o.at)) {
      _startCueGiven = true;
      add(_t(_startPt, _startEn), VoicePriority.cue);
    }

    final framingKey = o.framingKey;
    if (framingKey != null) {
      final last = _lastFramingAt;
      if (last == null || o.at - last >= framingMinInterval) {
        _lastFramingAt = o.at;
        add(_cueText(framingKey), VoicePriority.cue);
      }
    }

    switch (o.repEvent) {
      case RepEventType.full:
        add(_countWord(o.fullReps), VoicePriority.repCount);
        final milestone = _milestone(o.fullReps);
        if (milestone != null) add(milestone, VoicePriority.encouragement);
      case RepEventType.partial:
        add(_t(_partialPt, _partialEn), VoicePriority.repCount);
      case RepEventType.abandoned:
      case null:
        break;
    }

    final feedback = o.feedback;
    if (feedback != null) {
      if (feedback.level == FeedbackLevel.setup) {
        if (_cueAllowed('visibility', o.at)) {
          add(_t(_lostPt, _lostEn), VoicePriority.cue);
        }
      } else if (feedback.level == FeedbackLevel.warning ||
          feedback.level == FeedbackLevel.info) {
        // Partial reps are announced above; successes are counted instead.
        if (feedback.key != 'mfPartialRep' && _cueAllowed(feedback.key, o.at)) {
          add(_cueText(feedback.key), VoicePriority.cue);
        }
      }
    }
    return queued;
  }

  /// Removes and returns the next phrase to speak at [now], or null. Stale
  /// phrases are discarded on the way; the summary is never stale.
  VoicePhrase? next(Duration now) {
    while (_pending.isNotEmpty) {
      var best = 0;
      for (var i = 1; i < _pending.length; i++) {
        if (_pending[i].priority.index > _pending[best].priority.index) {
          best = i;
        }
      }
      final phrase = _pending.removeAt(best);
      if (phrase.priority != VoicePriority.summary &&
          now - phrase.at > staleAfter) {
        continue;
      }
      return phrase;
    }
    return null;
  }

  void _enqueue(VoicePhrase phrase) {
    _pending.add(phrase);
    while (_pending.length > maxPending) {
      var worst = 0;
      for (var i = 1; i < _pending.length; i++) {
        if (_pending[i].priority.index < _pending[worst].priority.index) {
          worst = i;
        }
      }
      _pending.removeAt(worst);
    }
  }

  bool _cueAllowed(String key, Duration now) {
    final last = _lastCueAt;
    if (last != null && now - last < cueMinInterval) return false;
    final sameLast = _lastCueSpoken[key];
    if (sameLast != null && now - sameLast < cueRepeatCooldown) return false;
    _lastCueAt = now;
    _lastCueSpoken[key] = now;
    return true;
  }

  String? _milestone(int n) {
    final target = _target;
    if (target == null) {
      if (n > 0 && n % 5 == 0) {
        return _encouraged(
          'Já são $n.',
          'That\'s $n.',
          _t('Boa!', 'Nice!'),
          _t('Boa!', 'Nice!'),
        );
      }
      return null;
    }
    final remaining = target - n;
    if (remaining <= 0) return _t('Objetivo atingido!', 'Target reached!');
    if (remaining == 1) return _t('Última!', 'Last one!');
    if (remaining == 2) return _t('Mais duas!', 'Two more!');
    if (target >= 6 && n == target ~/ 2) {
      return _encouraged(
        '',
        '',
        _t('Metade feita!', 'Halfway there!'),
        _t('Metade feita!', 'Halfway there!'),
      );
    }
    return null;
  }

  /// [prefix] + one generated phrase when the bank has one, else [fallback].
  /// [prefix] never holds a count the bank could change: callers pass the
  /// number themselves.
  String _encouraged(
    String prefix,
    String prefixEn,
    String fallback,
    String fallbackEn,
  ) {
    if (_bank.isEmpty) {
      return language == VoiceLanguage.portuguese
          ? (prefix.isEmpty ? fallback : '$prefix $fallback')
          : (prefixEn.isEmpty ? fallbackEn : '$prefixEn $fallbackEn');
    }
    final phrase = _bank[_bankIndex % _bank.length];
    _bankIndex++;
    final head = language == VoiceLanguage.portuguese ? prefix : prefixEn;
    return head.isEmpty ? phrase : '$head $phrase';
  }

  String _countWord(int n) {
    final words = language == VoiceLanguage.portuguese
        ? _ptNumbers
        : _enNumbers;
    return n >= 0 && n < words.length ? words[n] : '$n';
  }

  String _summaryText(SetSummary s) {
    final f = s.fullReps, p = s.partialReps;
    if (f == 0 && p == 0 && s.holdTime > Duration.zero) {
      final seconds = s.holdTime.inSeconds;
      return _t(
        'Boa! $seconds segundos em posição.',
        'Good! $seconds seconds in position.',
      );
    }
    if (f == 0 && p == 0) {
      return _t(
        'Série terminada. Nenhuma repetição contada.',
        'Set finished. No reps counted.',
      );
    }
    final partial = _t(
      switch (p) {
        0 => 'sem incompletas',
        1 => '1 incompleta',
        _ => '$p incompletas',
      },
      switch (p) {
        0 => 'no partial reps',
        1 => '1 partial rep',
        _ => '$p partial reps',
      },
    );
    if (f == 0) {
      return _t('Série terminada, $partial.', 'Set finished, $partial.');
    }
    final full = _t(
      f == 1 ? '1 repetição' : '$f repetições',
      f == 1 ? '1 rep' : '$f reps',
    );
    return _t('Boa! $full, $partial.', 'Good! $full, $partial.');
  }

  String _t(String pt, String en) =>
      language == VoiceLanguage.portuguese ? pt : en;

  static const _startPt = 'Estou a ver-te. Quando quiseres, começa.';
  static const _startEn = 'I can see you. Start when you are ready.';
  static const _lostPt = 'Não te vejo bem, afasta-te um pouco.';
  static const _lostEn = 'I can\'t see you well, step back a little.';
  static const _partialPt = 'Essa foi incompleta.';
  static const _partialEn = 'That one was partial.';

  static const _ptNumbers = [
    'Zero', 'Um', 'Dois', 'Três', 'Quatro', 'Cinco', 'Seis', 'Sete', //
    'Oito', 'Nove', 'Dez', 'Onze', 'Doze', 'Treze', 'Catorze', 'Quinze', //
    'Dezasseis', 'Dezassete', 'Dezoito', 'Dezanove', 'Vinte',
  ];
  static const _enNumbers = [
    'Zero', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', //
    'Nine', 'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', //
    'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen', 'Twenty',
  ];
}
