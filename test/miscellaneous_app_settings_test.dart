import 'package:binaural_beats/preferences.dart';
import 'package:binaural_beats/miscellaneous_app_settings.dart';
import 'package:fake_async/fake_async.dart';
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
  group('test MiscellaneousAppSettings', () {
    late final SharedPreferencesWithCache sharedPreferences;
    late ProviderContainer container;

    setUpAll(() async {
      // Necessary to test with new API (SharedPreferencesWithCache) (transitional measure).
      SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();

      SharedPreferences.setMockInitialValues({});
      sharedPreferences = await SharedPreferencesWithCache.create(
        cacheOptions: const SharedPreferencesWithCacheOptions(
          allowList: {'showTooltips'},
        ),
      );
    });

    setUp(() {
      sharedPreferences.clear();
      container = createContainer(overrides: [
        appPreferencesProvider.overrideWithValue(AppPreferences(sharedPreferences)),
      ]);
    });

    test('test default values', () {
      fakeAsync((async) {
        final subscription = container.listen(miscellaneousAppSettingsProvider, (_, __) {});

        expect(container.read(miscellaneousAppSettingsProvider).showTooltips, true);

        subscription.close();
        async.elapse(Duration.zero);
        expect(sharedPreferences.getBool('showTooltips'), true);
      });
    });

    test('test set methods', () {
      fakeAsync((async) {
        final subscription = container.listen(miscellaneousAppSettingsProvider, (_, __) {});

        container.read(miscellaneousAppSettingsProvider.notifier).setShowTooltips(false);
        expect(container.read(miscellaneousAppSettingsProvider).showTooltips, false);

        subscription.close();
        async.elapse(Duration.zero);
        expect(sharedPreferences.getBool('showTooltips'), false);
      });
    });
  });
}
