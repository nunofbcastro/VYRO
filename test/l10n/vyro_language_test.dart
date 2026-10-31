import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vyro/app/l10n/strings.dart';
import 'package:vyro/app/l10n/vyro_language.dart';
import 'package:vyro/core/database/app_database.dart';

/// Placeholders such as `{n}` or `{date}` in a string.
Set<String> _placeholders(String value) =>
    RegExp(r'\{(\w+)\}').allMatches(value).map((m) => m.group(1)!).toSet();

void main() {
  group('VyroLanguage stored values', () {
    test('legacy pt and en values still map to the right language', () {
      expect(VyroLanguage.fromStored('pt'), VyroLanguage.ptPT);
      expect(VyroLanguage.fromStored('en'), VyroLanguage.en);
    });

    test('every tag round-trips through fromStored', () {
      for (final language in VyroLanguage.values) {
        expect(VyroLanguage.fromStored(language.tag), language);
      }
    });

    test('tags are matched case-insensitively and accept underscores', () {
      expect(VyroLanguage.fromStored('pt_br'), VyroLanguage.ptBR);
      expect(VyroLanguage.fromStored(' IT '), VyroLanguage.it);
    });

    test('unknown or missing values fall back to pt-PT', () {
      expect(VyroLanguage.fromStored(null), VyroLanguage.ptPT);
      expect(VyroLanguage.fromStored(''), VyroLanguage.ptPT);
      expect(VyroLanguage.fromStored('klingon'), VyroLanguage.ptPT);
    });

    test('device locales map to the matching language', () {
      expect(
        VyroLanguage.fromLocale(const Locale('pt', 'BR')),
        VyroLanguage.ptBR,
      );
      expect(VyroLanguage.fromLocale(const Locale('pt')), VyroLanguage.ptPT);
      expect(
        VyroLanguage.fromLocale(const Locale('de', 'AT')),
        VyroLanguage.de,
      );
      expect(VyroLanguage.fromLocale(const Locale('es')), VyroLanguage.ptPT);
    });
  });

  group('profile import keeps the language', () {
    test('a valid tag is kept, an unknown one becomes pt-PT', () {
      expect(VyroProfile.fromJson(const {'locale': 'it'}).locale, 'it');
      expect(VyroProfile.fromJson(const {'locale': 'pt-BR'}).locale, 'pt-BR');
      expect(VyroProfile.fromJson(const {'locale': 'xx'}).locale, 'pt-PT');
      expect(VyroProfile.fromJson(const {'locale': 'pt'}).locale, 'pt-PT');
    });
  });

  group('VyroStrings lookup', () {
    test('each language returns its own text', () {
      expect(VyroStrings(const Locale('pt', 'PT')).get('lunch'), 'Almoço');
      expect(
        VyroStrings(const Locale('pt', 'BR')).get('breakfast'),
        'Café da manhã',
      );
      expect(VyroStrings(const Locale('it')).get('lunch'), 'Pranzo');
      expect(VyroStrings(const Locale('fr')).get('lunch'), 'Déjeuner');
      expect(VyroStrings(const Locale('de')).get('lunch'), 'Mittagessen');
    });

    test('an unknown key shows the key itself', () {
      expect(VyroStrings(const Locale('fr')).get('noSuchKey'), 'noSuchKey');
    });

    test('isEnglish is true for every non-Portuguese language', () {
      expect(VyroStrings(const Locale('pt', 'PT')).isEnglish, isFalse);
      expect(VyroStrings(const Locale('pt', 'BR')).isEnglish, isFalse);
      expect(VyroStrings(const Locale('en')).isEnglish, isTrue);
      expect(VyroStrings(const Locale('it')).isEnglish, isTrue);
    });

    test('supportedLocales lists every language once', () {
      final locales = VyroStrings.supportedLocales;
      expect(locales.length, VyroLanguage.values.length);
      expect(locales.toSet().length, locales.length);
    });
  });

  group('translation tables', () {
    final base = VyroStrings.tableFor(VyroLanguage.ptPT).keys.toSet();
    final others = [
      VyroLanguage.ptBR,
      VyroLanguage.en,
      VyroLanguage.it,
      VyroLanguage.fr,
      VyroLanguage.de,
    ];

    test('every language covers every key of the pt-PT base', () {
      for (final language in others) {
        final missing = base.difference(
          VyroStrings.tableFor(language).keys.toSet(),
        );
        expect(missing, isEmpty, reason: '${language.tag} misses keys');
      }
    });

    test('no language has a key that the pt-PT base does not have', () {
      for (final language in others) {
        final extra = VyroStrings.tableFor(
          language,
        ).keys.toSet().difference(base);
        expect(extra, isEmpty, reason: '${language.tag} has unknown keys');
      }
    });

    test('translated values keep the same placeholders as the base', () {
      for (final language in others) {
        VyroStrings.tableFor(language).forEach((key, value) {
          expect(
            _placeholders(value),
            _placeholders(VyroStrings.tableFor(VyroLanguage.ptPT)[key]!),
            reason: '${language.tag} "$key" changes its placeholders',
          );
        });
      }
    });

    test('no translated value is empty', () {
      for (final language in others) {
        for (final value in VyroStrings.tableFor(language).values) {
          expect(value.trim(), isNotEmpty, reason: language.tag);
        }
      }
    });
  });

  group('weekday names', () {
    test('every language names all seven days', () {
      for (final language in VyroLanguage.values) {
        final t = VyroStrings(language.locale);
        for (var day = 1; day <= 7; day++) {
          expect(
            t.get('wdShort$day'),
            isNot('wdShort$day'),
            reason: '${language.tag} short $day',
          );
          expect(
            t.get('wdLong$day'),
            isNot('wdLong$day'),
            reason: '${language.tag} long $day',
          );
        }
      }
    });

    test('Italian and German use their own day names', () {
      expect(VyroStrings(const Locale('it')).get('wdLong1'), 'Lunedì');
      expect(VyroStrings(const Locale('de')).get('wdLong1'), 'Montag');
    });
  });
}
