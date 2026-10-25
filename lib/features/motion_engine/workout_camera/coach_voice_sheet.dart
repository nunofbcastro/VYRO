import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../../app/app_services.dart';
import '../../../app/l10n/strings.dart';
import '../../../core/ai/on_device_llm.dart';
import '../../../core/database/app_database.dart';
import '../../../core/ui/vyro_ui.dart';
import '../feedback_engine/coach_llm_phrases.dart';
import '../feedback_engine/coach_voice_settings.dart';
import '../feedback_engine/coach_voice_tts.dart';
import '../feedback_engine/voice_coach.dart';

/// Preferences for the voice coach, read and written through the local
/// key/value table.
CoachVoicePreferences coachVoicePreferencesFor(AppDatabase database) =>
    CoachVoicePreferences(
      read: database.getPreference,
      write: database.setPreference,
    );

/// Opens "Voz do treinador": voice list with preview, speed and pitch, and
/// the on-device phrase toggle. Used from the camera screen and from profile
/// settings.
Future<void> showCoachVoiceSheet(BuildContext context) {
  final services = AppServicesScope.of(context);
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => CoachVoiceSheet(
      preferences: coachVoicePreferencesFor(services.database),
      llm: services.llm,
    ),
  );
}

/// Sheet body. [voiceSource] and [previewer] default to the platform
/// text-to-speech engine; tests pass fakes.
class CoachVoiceSheet extends StatefulWidget {
  const CoachVoiceSheet({
    super.key,
    required this.preferences,
    required this.llm,
    this.voiceSource,
    this.previewer,
  });

  final CoachVoicePreferences preferences;
  final OnDeviceLlm llm;

  /// Local voices for a language. Default: the engine's voice list.
  final Future<List<CoachVoice>> Function(VoiceLanguage language)? voiceSource;

  /// Speaks [sample] with [settings]. Default: a separate engine instance, so
  /// the camera's coach is not interrupted by a preview.
  final Future<void> Function(
    CoachVoiceSettings settings,
    VoiceLanguage language,
    String sample,
  )?
  previewer;

  @override
  State<CoachVoiceSheet> createState() => _CoachVoiceSheetState();
}

class _CoachVoiceSheetState extends State<CoachVoiceSheet> {
  bool _started = false;
  bool _loading = true;
  CoachVoiceSettings _settings = const CoachVoiceSettings();
  List<CoachVoice> _voices = const [];
  bool _llmAvailable = false;
  FlutterTts? _previewTts;

  VoiceLanguage get _language =>
      _english ? VoiceLanguage.english : VoiceLanguage.portuguese;

  bool _english = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _english = stringsOf(context).isEnglish;
    _load();
  }

  @override
  void dispose() {
    final tts = _previewTts;
    if (tts != null) {
      tts.stop();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final settings = await widget.preferences.load();
    final voices = await (widget.voiceSource ?? _defaultVoices)(_language);
    final llmAvailable = await CoachLlmPhrases(widget.llm).isAvailable();
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _voices = voices;
      _llmAvailable = llmAvailable;
      _loading = false;
    });
  }

  Future<List<CoachVoice>> _defaultVoices(VoiceLanguage language) =>
      CoachVoiceTts(_engine()).loadLocalVoices(language);

  FlutterTts _engine() => _previewTts ??= FlutterTts();

  Future<void> _preview(CoachVoiceSettings settings) async {
    final sample = stringsOf(context).get('coachVoiceSample');
    final previewer = widget.previewer;
    if (previewer != null) {
      await previewer(settings, _language, sample);
      return;
    }
    final tts = _engine();
    try {
      await tts.stop();
      await CoachVoiceTts(tts).apply(settings, _language);
      await tts.speak(sample);
    } catch (_) {
      // Preview is optional; the settings still save.
    }
  }

  Future<void> _update(CoachVoiceSettings next) async {
    setState(() => _settings = next);
    await widget.preferences.save(next);
  }

  @override
  Widget build(BuildContext context) {
    final t = stringsOf(context);
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final llmOn = _llmAvailable && (_settings.llmPhrases ?? true);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  t.get('coachVoiceTitle'),
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 6),
                Text(
                  t.get('coachVoicePrivacy'),
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
                const SizedBox(height: 18),
                Text(
                  t.get('coachVoiceVoices'),
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 10),
                if (_loading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else ...[
                  VyroChoiceCard(
                    icon: Icons.phone_android_rounded,
                    title: t.get('coachVoiceDefault'),
                    subtitle: t.get('coachVoiceDefaultSubtitle'),
                    selected: !_settings.hasVoice,
                    onTap: () => _update(_settings.copyWith(clearVoice: true)),
                    trailing: _ListenAndRadio(
                      label: t.get('coachVoiceListen'),
                      selected: !_settings.hasVoice,
                      onListen: () =>
                          _preview(_settings.copyWith(clearVoice: true)),
                    ),
                  ),
                  for (var i = 0; i < _voices.length; i++) ...[
                    const SizedBox(height: 10),
                    _voiceCard(t, i),
                  ],
                  if (_voices.isEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant,
                        ),
                      ),
                      child: Text(
                        t.get('coachVoiceNone'),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 24),
                Text(
                  t.get('coachVoiceSpeed'),
                  style: theme.textTheme.titleSmall,
                ),
                Slider(
                  value: _settings.rate
                      .clamp(
                        CoachVoiceSettings.minRate,
                        CoachVoiceSettings.maxRate,
                      )
                      .toDouble(),
                  min: CoachVoiceSettings.minRate,
                  max: CoachVoiceSettings.maxRate,
                  label: _settings.rate.toStringAsFixed(2),
                  onChanged: (v) =>
                      setState(() => _settings = _settings.copyWith(rate: v)),
                  onChangeEnd: (v) => _update(_settings.copyWith(rate: v)),
                ),
                const SizedBox(height: 8),
                Text(
                  t.get('coachVoicePitch'),
                  style: theme.textTheme.titleSmall,
                ),
                Slider(
                  value: _settings.pitch
                      .clamp(
                        CoachVoiceSettings.minPitch,
                        CoachVoiceSettings.maxPitch,
                      )
                      .toDouble(),
                  min: CoachVoiceSettings.minPitch,
                  max: CoachVoiceSettings.maxPitch,
                  label: _settings.pitch.toStringAsFixed(2),
                  onChanged: (v) =>
                      setState(() => _settings = _settings.copyWith(pitch: v)),
                  onChangeEnd: (v) => _update(_settings.copyWith(pitch: v)),
                ),
                const SizedBox(height: 4),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  onPressed: () => _preview(_settings),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(t.get('coachVoiceTry')),
                ),
                const SizedBox(height: 24),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(t.get('coachVoiceLlmTitle')),
                  subtitle: Text(
                    _llmAvailable
                        ? t.get('coachVoiceLlmSubtitle')
                        : t.get('coachVoiceLlmUnavailable'),
                  ),
                  value: llmOn,
                  onChanged: _llmAvailable
                      ? (v) => _update(_settings.copyWith(llmPhrases: v))
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _voiceCard(VyroStrings t, int index) {
    final voice = _voices[index];
    final selected = _settings.selects(voice);
    return VyroChoiceCard(
      icon: Icons.record_voice_over_rounded,
      title: coachVoiceLabel(voice, index: index + 1, english: _english),
      subtitle: voice.locale,
      selected: selected,
      onTap: () => _update(
        _settings.copyWith(voiceName: voice.name, voiceLocale: voice.locale),
      ),
      trailing: _ListenAndRadio(
        label: t.get('coachVoiceListen'),
        selected: selected,
        onListen: () => _preview(
          _settings.copyWith(voiceName: voice.name, voiceLocale: voice.locale),
        ),
      ),
    );
  }
}

class _ListenAndRadio extends StatelessWidget {
  const _ListenAndRadio({
    required this.label,
    required this.selected,
    required this.onListen,
  });

  final String label;
  final bool selected;
  final VoidCallback onListen;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton.icon(
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: onListen,
          icon: const Icon(Icons.volume_up_rounded, size: 20),
          label: Text(label),
        ),
        Icon(
          selected
              ? Icons.radio_button_checked_rounded
              : Icons.radio_button_unchecked_rounded,
          color: selected ? scheme.primary : scheme.onSurfaceVariant,
        ),
      ],
    );
  }
}
