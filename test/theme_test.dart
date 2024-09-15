import 'package:binaural_beats/preferences.dart';
import 'package:binaural_beats/theme.dart';
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
  group('AppTheme', () {
    late final SharedPreferencesWithCache sharedPreferences;
    late ProviderContainer container;

    setUpAll(() async {
      // Necessary to test with new API (SharedPreferencesWithCache) (transitional measure).
      SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();

      SharedPreferences.setMockInitialValues({});
      sharedPreferences = await SharedPreferencesWithCache.create(
        cacheOptions: const SharedPreferencesWithCacheOptions(
          allowList: {'appThemeColor', 'appThemeMode'},
        ),
      );
    });

    setUp(() {
      sharedPreferences.clear();
      container = createContainer(overrides: [
        appPreferencesProvider.overrideWithValue(AppPreferences(sharedPreferences)),
      ]);
    });

    test('get and set values', () {
      fakeAsync((async) {
        final subscription = container.listen(appThemeProvider, (_, __) {});

        expect(container.read(appThemeProvider),
            AppThemeState(color: Color(Colors.blue.value), mode: ThemeMode.system));

        container.read(appThemeProvider.notifier).setColor(Color(Colors.red.value));
        expect(container.read(appThemeProvider),
            AppThemeState(color: Color(Colors.red.value), mode: ThemeMode.system));

        container.read(appThemeProvider.notifier).setMode(ThemeMode.dark);
        expect(container.read(appThemeProvider),
            AppThemeState(color: Color(Colors.red.value), mode: ThemeMode.dark));

        async.elapse(const Duration(milliseconds: 600));
        expect(sharedPreferences.getInt('appThemeColor'), Colors.red.value);
        expect(sharedPreferences.getInt('appThemeMode'), ThemeMode.dark.index);

        container.read(appThemeProvider.notifier).setColor(Color(Colors.green.value));
        container.read(appThemeProvider.notifier).setColor(Color(Colors.yellow.value));
        expect(container.read(appThemeProvider),
            AppThemeState(color: Color(Colors.yellow.value), mode: ThemeMode.dark));

        container.read(appThemeProvider.notifier).setMode(ThemeMode.light);
        expect(container.read(appThemeProvider),
            AppThemeState(color: Color(Colors.yellow.value), mode: ThemeMode.light));

        subscription.close();
        async.elapse(Duration.zero);
        expect(sharedPreferences.getInt('appThemeColor'), Colors.yellow.value);
        expect(sharedPreferences.getInt('appThemeMode'), ThemeMode.light.index);
      });
    });

    test('load from preferences', () {
      fakeAsync((async) {
        sharedPreferences.setInt('appThemeColor', Colors.green.value);
        sharedPreferences.setInt('appThemeMode', ThemeMode.light.index);

        final subscription = container.listen(appThemeProvider, (_, __) {});

        expect(container.read(appThemeProvider),
            AppThemeState(color: Color(Colors.green.value), mode: ThemeMode.light));

        subscription.close();
      });
    });

    test('invalid preferences', () {
      fakeAsync((async) {
        sharedPreferences.setDouble('appThemeColor', Colors.green.value.toDouble());
        sharedPreferences.setInt('appThemeMode', -1);

        final subscription = container.listen(appThemeProvider, (_, __) {});

        expect(container.read(appThemeProvider),
            AppThemeState(color: Color(Colors.blue.value), mode: ThemeMode.system));

        subscription.close();
      });
    });
  });
}
