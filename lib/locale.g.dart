// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'locale.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$systemLanguageCodeHash() =>
    r'e961a6c4d6df225d1df2a640e917625a56df1196';

/// See also [systemLanguageCode].
@ProviderFor(systemLanguageCode)
final systemLanguageCodeProvider = Provider<String>.internal(
  systemLanguageCode,
  name: r'systemLanguageCodeProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$systemLanguageCodeHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef SystemLanguageCodeRef = ProviderRef<String>;
String _$supportedLocalesHash() => r'734a030ed6a389cc01801adbab053df5de8a8e2c';

/// See also [supportedLocales].
@ProviderFor(supportedLocales)
final supportedLocalesProvider = Provider<List<Locale>>.internal(
  supportedLocales,
  name: r'supportedLocalesProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$supportedLocalesHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef SupportedLocalesRef = ProviderRef<List<Locale>>;
String _$appLocaleHash() => r'beb76611e46402ae641398d2eef53d65678bec1e';

/// The locale used by the app.
///
/// Copied from [AppLocale].
@ProviderFor(AppLocale)
final appLocaleProvider =
    AutoDisposeNotifierProvider<AppLocale, Locale>.internal(
  AppLocale.new,
  name: r'appLocaleProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$appLocaleHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$AppLocale = AutoDisposeNotifier<Locale>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
