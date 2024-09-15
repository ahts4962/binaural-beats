import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'preferences.dart';

part 'locale.g.dart';

const Map<String, String> languageDisplayStrings = {
  'en': 'English',
  'ja': '日本語',
};

@Riverpod(keepAlive: true)
String systemLanguageCode(SystemLanguageCodeRef ref) {
  return Platform.localeName.split('_').first;
}

@Riverpod(keepAlive: true)
List<Locale> supportedLocales(SupportedLocalesRef ref) {
  return AppLocalizations.supportedLocales;
}

/// The locale used by the app.
@riverpod
class AppLocale extends _$AppLocale {
  @override
  Locale build() {
    final preferences = ref.watch(appPreferencesProvider);
    final systemLanguageCode = ref.watch(systemLanguageCodeProvider);
    final supportedLanguageCodes =
        ref.watch(supportedLocalesProvider).map((e) => e.languageCode).toList();

    var languageCode = preferences.getString('appLanguageCode');
    if (languageCode == null || !supportedLanguageCodes.contains(languageCode)) {
      if (supportedLanguageCodes.contains(systemLanguageCode)) {
        languageCode = systemLanguageCode;
      } else {
        languageCode = 'en';
      }
    }

    ref.listenSelf((previous, next) {
      preferences.setString('appLanguageCode', next.languageCode);
    });

    ref.onDispose(preferences.flush);

    return Locale(languageCode);
  }

  /// Sets value.
  void set(Locale value) {
    state = value;
  }
}
