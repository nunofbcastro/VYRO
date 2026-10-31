import 'package:flutter/widgets.dart';

/// Idiomas suportados pela interface, pela ordem do seletor.
///
/// O valor guardado no perfil é a [tag] (por exemplo `pt-PT`). Valores antigos
/// (`pt`, `en`) continuam válidos. Qualquer valor desconhecido cai em pt-PT,
/// que é a língua de referência do produto.
enum VyroLanguage {
  ptPT('pt-PT', 'Português (Portugal)', 'PT', Locale('pt', 'PT')),
  ptBR('pt-BR', 'Português (Brasil)', 'BR', Locale('pt', 'BR')),
  en('en', 'English', 'EN', Locale('en')),
  it('it', 'Italiano', 'IT', Locale('it')),
  fr('fr', 'Français', 'FR', Locale('fr')),
  de('de', 'Deutsch', 'DE', Locale('de'));

  const VyroLanguage(this.tag, this.nativeName, this.badge, this.locale);

  /// Etiqueta guardada em `VyroProfile.locale` e na exportação.
  final String tag;

  /// Nome do idioma escrito nesse mesmo idioma, para o seletor.
  final String nativeName;

  /// Código curto mostrado no seletor.
  final String badge;

  final Locale locale;

  /// Ordem de procura de uma tradução. A última entrada é sempre a base
  /// inglesa ou portuguesa; se a chave falta em todas, a interface mostra a
  /// própria chave (o teste de cobertura impede isto nas línguas completas).
  List<VyroLanguage> get fallbackChain => switch (this) {
    VyroLanguage.ptPT => const [VyroLanguage.ptPT, VyroLanguage.en],
    VyroLanguage.ptBR => const [
      VyroLanguage.ptBR,
      VyroLanguage.ptPT,
      VyroLanguage.en,
    ],
    VyroLanguage.en => const [VyroLanguage.en],
    VyroLanguage.it => const [VyroLanguage.it, VyroLanguage.en],
    VyroLanguage.fr => const [VyroLanguage.fr, VyroLanguage.en],
    VyroLanguage.de => const [VyroLanguage.de, VyroLanguage.en],
  };

  /// Lê o valor guardado. Aceita tags antigas e tags com outra capitalização.
  static VyroLanguage fromStored(String? value) {
    final normalized = value?.trim().replaceAll('_', '-').toLowerCase();
    if (normalized == null) return ptPT;
    if (normalized == 'pt') return ptPT;
    if (normalized == 'en') return en;
    for (final language in values) {
      if (language.tag.toLowerCase() == normalized) return language;
    }
    return ptPT;
  }

  static VyroLanguage fromLocale(Locale locale) {
    if (locale.languageCode == 'pt') {
      return locale.countryCode == 'BR' ? ptBR : ptPT;
    }
    return switch (locale.languageCode) {
      'en' => en,
      'it' => it,
      'fr' => fr,
      'de' => de,
      _ => ptPT,
    };
  }
}
