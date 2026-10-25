/// How urgent a message is. Higher values win.
enum FeedbackLevel {
  /// Positive confirmation ("Repetição concluída").
  success,

  /// Neutral guidance.
  info,

  /// Possible technique issue.
  warning,

  /// The analysis cannot work (camera, visibility).
  setup,
}

/// Something the analysis would like to tell the user this frame.
class FeedbackCandidate {
  const FeedbackCandidate(this.key, this.level, {this.confidence = 1});

  /// VyroStrings key of the message.
  final String key;
  final FeedbackLevel level;

  /// Evidence confidence (0–1); low-confidence technique messages are
  /// dropped instead of shown.
  final double confidence;
}

/// A message the UI should show (and optionally speak) now.
class FeedbackMessage {
  const FeedbackMessage(this.key, this.level, this.at);
  final String key;
  final FeedbackLevel level;
  final Duration at;
}

/// Chooses at most one message at a time: highest level first, then
/// confidence; technique messages need [minConfidence]; the same message is
/// not repeated within [repeatCooldown]; and messages are at least
/// [minGap] apart so the session is not interrupted constantly.
class FeedbackEngine {
  FeedbackEngine({
    this.minConfidence = 0.6,
    this.repeatCooldown = const Duration(seconds: 6),
    this.minGap = const Duration(milliseconds: 2200),
  });

  final double minConfidence;
  final Duration repeatCooldown;
  final Duration minGap;

  final _lastShown = <String, Duration>{};
  Duration? _lastAny;
  FeedbackMessage? current;

  /// Returns a new message to present, or null to keep the current one.
  FeedbackMessage? offer(List<FeedbackCandidate> candidates, Duration now) {
    final eligible = candidates.where((c) {
      if (c.level == FeedbackLevel.warning && c.confidence < minConfidence) {
        return false;
      }
      final last = _lastShown[c.key];
      return last == null || now - last >= repeatCooldown;
    }).toList();
    if (eligible.isEmpty) return null;
    eligible.sort((a, b) {
      final byLevel = b.level.index.compareTo(a.level.index);
      return byLevel != 0 ? byLevel : b.confidence.compareTo(a.confidence);
    });
    final best = eligible.first;
    final gapOk = _lastAny == null || now - _lastAny! >= minGap;
    // Setup problems may interrupt sooner; everything else waits its turn.
    if (!gapOk && best.level != FeedbackLevel.setup) return null;
    _lastShown[best.key] = now;
    _lastAny = now;
    return current = FeedbackMessage(best.key, best.level, now);
  }

  void reset() {
    _lastShown.clear();
    _lastAny = null;
    current = null;
  }
}
