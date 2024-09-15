import 'package:binaural_beats/locale.dart';
import 'package:binaural_beats/preferences.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

ProviderContainer createContainer({
  ProviderContainer? parent,
  List<Override> overrides = const [],
  List<ProviderObserver>? observers,
}) {
  final container = ProviderContainer(
    parent: parent,
    overrides: overrides,
    observers: observers,
  );

  addTearDown(container.dispose);

  return container;
}

void main() {
  group('AppLocale', () {
    late final SharedPreferencesWithCache sharedPreferences;

    setUpAll(() async {
      // Necessary to test with new API (SharedPreferencesWithCache) (transitional measure).
      SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();

      SharedPreferences.setMockInitialValues({});
      sharedPreferences = await SharedPreferencesWithCache.create(
        cacheOptions: const SharedPreferencesWithCacheOptions(
          allowList: {'appLanguageCode'},
        ),
      );
    });

    setUp(() {
      sharedPreferences.clear();
    });

    test('get and set', () {
      fakeAsync((async) {
        final container = createContainer(overrides: [
          appPreferencesProvider.overrideWithValue(AppPreferences(sharedPreferences)),
          systemLanguageCodeProvider.overrideWithValue('en'),
          supportedLocalesProvider.overrideWithValue(const [Locale('en'), Locale('ja')]),
        ]);

        final subscription = container.listen(appLocaleProvider, (_, __) {});

        expect(container.read(appLocaleProvider), const Locale('en'));
        async.elapse(const Duration(milliseconds: 600));
        expect(sharedPreferences.getString('appLanguageCode'), 'en');

        container.read(appLocaleProvider.notifier).set(const Locale('ja'));
        expect(container.read(appLocaleProvider), const Locale('ja'));

        subscription.close();
        async.elapse(Duration.zero);
        expect(sharedPreferences.getString('appLanguageCode'), 'ja');
      });
    });

    test('use system locale as default', () {
      final container = createContainer(overrides: [
        appPreferencesProvider.overrideWithValue(AppPreferences(sharedPreferences)),
        systemLanguageCodeProvider.overrideWithValue('ja'),
        supportedLocalesProvider.overrideWithValue(const [Locale('en'), Locale('ja')]),
      ]);

      expect(container.read(appLocaleProvider), const Locale('ja'));
    });

    test('use en if system locale not supported', () {
      final container = createContainer(overrides: [
        appPreferencesProvider.overrideWithValue(AppPreferences(sharedPreferences)),
        systemLanguageCodeProvider.overrideWithValue('es'),
        supportedLocalesProvider.overrideWithValue(const [Locale('en'), Locale('ja')]),
      ]);

      expect(container.read(appLocaleProvider), const Locale('en'));
    });

    test('read from preferences', () {
      final container = createContainer(overrides: [
        appPreferencesProvider.overrideWithValue(AppPreferences(sharedPreferences)),
        systemLanguageCodeProvider.overrideWithValue('en'),
        supportedLocalesProvider.overrideWithValue(const [Locale('en'), Locale('ja')]),
      ]);
      sharedPreferences.setString('appLanguageCode', 'ja');

      expect(container.read(appLocaleProvider), const Locale('ja'));
    });

    test('use en if preferences have unsupported locale', () {
      final container = createContainer(overrides: [
        appPreferencesProvider.overrideWithValue(AppPreferences(sharedPreferences)),
        systemLanguageCodeProvider.overrideWithValue('en'),
        supportedLocalesProvider.overrideWithValue(const [Locale('en'), Locale('ja')]),
      ]);
      sharedPreferences.setString('appLanguageCode', 'es');

      expect(container.read(appLocaleProvider), const Locale('en'));
    });
  });
}
