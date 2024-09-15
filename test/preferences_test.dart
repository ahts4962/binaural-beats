import 'package:binaural_beats/preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_async/fake_async.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  group('test AppPreferences', () {
    late final SharedPreferencesWithCache sharedPreferences;

    setUpAll(() async {
      // Necessary to test with new API (SharedPreferencesWithCache) (transitional measure).
      SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();

      SharedPreferences.setMockInitialValues({});
      sharedPreferences = await SharedPreferencesWithCache.create(
        cacheOptions: const SharedPreferencesWithCacheOptions(
          allowList: {'keyInt', 'keyDouble', 'keyBool', 'keyString'},
        ),
      );
    });

    setUp(() {
      sharedPreferences.clear();
    });

    test('test getXxx', () {
      final preferences = AppPreferences(sharedPreferences);

      expect(preferences.getInt('keyInt'), null);
      sharedPreferences.setInt('keyInt', 1);
      expect(preferences.getInt('keyInt'), 1);
      sharedPreferences.setDouble('keyInt', 2.0);
      expect(preferences.getInt('keyInt'), null);

      expect(preferences.getDouble('keyDouble'), null);
      sharedPreferences.setDouble('keyDouble', 1.0);
      expect(preferences.getDouble('keyDouble'), 1.0);
      sharedPreferences.setInt('keyDouble', 2);
      expect(preferences.getDouble('keyDouble'), null);

      expect(preferences.getBool('keyBool'), null);
      sharedPreferences.setBool('keyBool', true);
      expect(preferences.getBool('keyBool'), true);
      sharedPreferences.setInt('keyBool', 1);
      expect(preferences.getBool('keyBool'), null);

      expect(preferences.getString('keyString'), null);
      sharedPreferences.setString('keyString', 'value');
      expect(preferences.getString('keyString'), 'value');
      sharedPreferences.setBool('keyString', true);
      expect(preferences.getString('keyString'), null);
    });

    test('test getXxxWithDefault', () {
      fakeAsync((async) {
        final preferences = AppPreferences(sharedPreferences);

        expect(preferences.getIntWithDefault('keyInt', 1), 1);
        expect(sharedPreferences.getInt('keyInt'), null);
        expect(preferences.getDoubleWithDefault('keyDouble', 1.0), 1.0);
        expect(sharedPreferences.getDouble('keyDouble'), null);
        expect(preferences.getBoolWithDefault('keyBool', false), false);
        expect(sharedPreferences.getBool('keyBool'), null);
        async.elapse(const Duration(milliseconds: 1000));
        expect(preferences.getIntWithDefault('keyInt', 0), 1);
        expect(preferences.getDoubleWithDefault('keyDouble', 0.0), 1.0);
        expect(preferences.getBoolWithDefault('keyBool', true), false);
      });
    });

    test('test setXxx', () {
      fakeAsync((async) {
        final preferences = AppPreferences(sharedPreferences);

        preferences.setInt('keyInt', 1);
        preferences.setDouble('keyDouble', 2.0);
        async.elapse(const Duration(milliseconds: 300));
        preferences.setBool('keyBool', true);
        preferences.setString('keyString', 'value');
        async.elapse(const Duration(milliseconds: 300));
        expect(sharedPreferences.getInt('keyInt'), 1);
        expect(sharedPreferences.getDouble('keyDouble'), 2.0);
        expect(sharedPreferences.getBool('keyBool'), null);
        expect(sharedPreferences.getString('keyString'), null);
        preferences.setDouble('keyDouble', 3.0);
        async.elapse(const Duration(milliseconds: 100));
        preferences.setDouble('keyDouble', 4.0);
        async.elapse(const Duration(milliseconds: 600));
        expect(sharedPreferences.getDouble('keyDouble'), 4.0);
        expect(sharedPreferences.getBool('keyBool'), true);
        expect(sharedPreferences.getString('keyString'), 'value');
      });
    });

    test('test flush', () {
      final preferences = AppPreferences(sharedPreferences);

      preferences.setInt('keyInt', 1);
      preferences.setDouble('keyDouble', 1.0);
      preferences.setBool('keyBool', true);
      preferences.setString('keyString', 'value');
      expect(sharedPreferences.getInt('keyInt'), null);
      expect(sharedPreferences.getDouble('keyDouble'), null);
      expect(sharedPreferences.getBool('keyBool'), null);
      expect(sharedPreferences.getString('keyString'), null);
      expect(preferences.flush(), completes);
      expect(sharedPreferences.getInt('keyInt'), 1);
      expect(sharedPreferences.getDouble('keyDouble'), 1.0);
      expect(sharedPreferences.getBool('keyBool'), true);
      expect(sharedPreferences.getString('keyString'), 'value');
    });

    test('test TypeError', () async {
      final preferences = AppPreferences(sharedPreferences);

      await sharedPreferences.setDouble('keyInt', 1.0);
      await sharedPreferences.setInt('keyDouble', 1);
      await sharedPreferences.setString('keyBool', 'true');
      await sharedPreferences.setBool('keyString', true);
      expect(preferences.getInt('keyInt'), null);
      expect(preferences.getDouble('keyDouble'), null);
      expect(preferences.getBool('keyBool'), null);
      expect(preferences.getString('keyString'), null);
      expect(preferences.getIntWithDefault('keyInt', 2), 2);
      expect(preferences.getDoubleWithDefault('keyDouble', 2.0), 2.0);
      expect(preferences.getBoolWithDefault('keyBool', false), false);
    });
  });
}
