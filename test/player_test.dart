import 'package:binaural_beats/player.dart';
import 'package:binaural_beats/preferences.dart';
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
  group('test Player', () {
    late final SharedPreferencesWithCache sharedPreferences;
    late ProviderContainer container;

    setUpAll(() async {
      // Necessary to test with new API (SharedPreferencesWithCache) (transitional measure).
      SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();

      SharedPreferences.setMockInitialValues({});
      sharedPreferences = await SharedPreferencesWithCache.create(
        cacheOptions: const SharedPreferencesWithCacheOptions(
          allowList: {
            'binauralBeatsFrequency',
            'baseFrequency',
            'leftVolume',
            'rightVolume',
            'frequenciesLimited',
            'volumesSynchronized',
          },
        ),
      );
    });

    setUp(() {
      sharedPreferences.clear();
      container = createContainer(overrides: [
        appPreferencesProvider.overrideWithValue(AppPreferences(sharedPreferences)),
      ]);
    });

    test('test default value', () {
      final subscription = container.listen(playerProvider, (_, __) {});
      final playerState = container.read(playerProvider);
      expect(
        playerState,
        const PlayerState(
          binauralBeatsFrequency: Player.defaultBinauralBeatsFrequency,
          baseFrequency: Player.defaultBaseFrequency,
          leftVolume: Player.defaultVolume,
          rightVolume: Player.defaultVolume,
          frequenciesLimited: true,
          volumesSynchronized: true,
          isPlaying: false,
        ),
      );
      subscription.close();
    });

    test('test writing to shared preferences when disposed', () {
      fakeAsync((async) {
        final subscription = container.listen(playerProvider, (_, __) {});
        subscription.close();
        async.elapse(Duration.zero);
        expect(sharedPreferences.getDouble('binauralBeatsFrequency'),
            Player.defaultBinauralBeatsFrequency);
        expect(sharedPreferences.getDouble('baseFrequency'), Player.defaultBaseFrequency);
        expect(sharedPreferences.getDouble('leftVolume'), Player.defaultVolume);
        expect(sharedPreferences.getDouble('rightVolume'), Player.defaultVolume);
        expect(sharedPreferences.getBool('frequenciesLimited'), true);
        expect(sharedPreferences.getBool('volumesSynchronized'), true);
      });
    });

    test('test reading from shared preferences', () {
      sharedPreferences.setDouble('binauralBeatsFrequency', 12);
      sharedPreferences.setDouble('baseFrequency', 34);
      sharedPreferences.setDouble('leftVolume', 0.12);
      sharedPreferences.setDouble('rightVolume', 0.34);
      sharedPreferences.setBool('frequenciesLimited', false);
      sharedPreferences.setBool('volumesSynchronized', false);
      final subscription = container.listen(playerProvider, (_, __) {});
      final playerState = container.read(playerProvider);
      expect(
        playerState,
        const PlayerState(
          binauralBeatsFrequency: 12,
          baseFrequency: 34,
          leftVolume: 0.12,
          rightVolume: 0.34,
          frequenciesLimited: false,
          volumesSynchronized: false,
          isPlaying: false,
        ),
      );
      subscription.close();
    });

    test('test invalid shared preferences', () {
      fakeAsync((async) {
        sharedPreferences.setDouble('binauralBeatsFrequency', Player.minBinauralBeatsFrequency - 1);
        sharedPreferences.setDouble('baseFrequency', Player.minBaseFrequency - 1);
        sharedPreferences.setDouble('leftVolume', Player.minVolume - 0.01);
        sharedPreferences.setDouble('rightVolume', Player.minVolume - 0.01);
        var subscription = container.listen(playerProvider, (_, __) {});
        var playerState = container.read(playerProvider);
        expect(
          playerState,
          const PlayerState(
            binauralBeatsFrequency: Player.defaultBinauralBeatsFrequency,
            baseFrequency: Player.defaultBaseFrequency,
            leftVolume: Player.defaultVolume,
            rightVolume: Player.defaultVolume,
            frequenciesLimited: true,
            volumesSynchronized: true,
            isPlaying: false,
          ),
        );
        subscription.close();
        async.elapse(const Duration(seconds: 1));
        sharedPreferences.clear();

        sharedPreferences.setDouble('binauralBeatsFrequency', Player.maxBinauralBeatsFrequency + 1);
        sharedPreferences.setDouble('baseFrequency', Player.maxBaseFrequency + 1);
        sharedPreferences.setDouble('leftVolume', Player.maxVolume + 0.01);
        sharedPreferences.setDouble('rightVolume', Player.maxVolume + 0.01);
        sharedPreferences.setBool('frequenciesLimited', false);
        subscription = container.listen(playerProvider, (_, __) {});
        playerState = container.read(playerProvider);
        expect(
          playerState,
          const PlayerState(
            binauralBeatsFrequency: Player.defaultBinauralBeatsFrequency,
            baseFrequency: Player.defaultBaseFrequency,
            leftVolume: Player.defaultVolume,
            rightVolume: Player.defaultVolume,
            frequenciesLimited: false,
            volumesSynchronized: true,
            isPlaying: false,
          ),
        );
        subscription.close();
      });
    });

    test('test frequency limit', () {
      fakeAsync((async) {
        sharedPreferences.setDouble(
            'binauralBeatsFrequency',
            (Player.maxBinauralBeatsFrequency + Player.intermediateBinauralBeatsFrequencyLimit) /
                2);
        sharedPreferences.setDouble(
            'baseFrequency', (Player.maxBaseFrequency + Player.intermediateBaseFrequencyLimit) / 2);
        sharedPreferences.setBool('frequenciesLimited', false);
        var subscription = container.listen(playerProvider, (_, __) {});
        var playerState = container.read(playerProvider);
        expect(
          playerState,
          const PlayerState(
            binauralBeatsFrequency: (Player.maxBinauralBeatsFrequency +
                    Player.intermediateBinauralBeatsFrequencyLimit) /
                2,
            baseFrequency: (Player.maxBaseFrequency + Player.intermediateBaseFrequencyLimit) / 2,
            leftVolume: Player.defaultVolume,
            rightVolume: Player.defaultVolume,
            frequenciesLimited: false,
            volumesSynchronized: true,
            isPlaying: false,
          ),
        );
        subscription.close();
        async.elapse(const Duration(seconds: 1));
        sharedPreferences.clear();

        sharedPreferences.setDouble(
            'binauralBeatsFrequency',
            (Player.maxBinauralBeatsFrequency + Player.intermediateBinauralBeatsFrequencyLimit) /
                2);
        sharedPreferences.setDouble(
            'baseFrequency', (Player.maxBaseFrequency + Player.intermediateBaseFrequencyLimit) / 2);
        sharedPreferences.setBool('frequenciesLimited', true);
        subscription = container.listen(playerProvider, (_, __) {});
        playerState = container.read(playerProvider);
        expect(
          playerState,
          const PlayerState(
            binauralBeatsFrequency: Player.intermediateBinauralBeatsFrequencyLimit,
            baseFrequency: Player.intermediateBaseFrequencyLimit,
            leftVolume: Player.defaultVolume,
            rightVolume: Player.defaultVolume,
            frequenciesLimited: true,
            volumesSynchronized: true,
            isPlaying: false,
          ),
        );
      });
    });

    test('test setting frequencies', () {
      fakeAsync((async) {
        final subscription = container.listen(playerProvider, (_, __) {});

        container.read(playerProvider.notifier).setBinauralBeatsFrequency(12);
        container.read(playerProvider.notifier).setBaseFrequency(34);

        var playerState = container.read(playerProvider);
        expect(
          playerState,
          const PlayerState(
            binauralBeatsFrequency: 12,
            baseFrequency: 34,
            leftVolume: Player.defaultVolume,
            rightVolume: Player.defaultVolume,
            frequenciesLimited: true,
            volumesSynchronized: true,
            isPlaying: false,
          ),
        );

        container.read(playerProvider.notifier).incrementBinauralBeatsFrequency(1);
        container.read(playerProvider.notifier).incrementBaseFrequency(1);

        playerState = container.read(playerProvider);
        expect(
          playerState,
          const PlayerState(
            binauralBeatsFrequency: 13,
            baseFrequency: 35,
            leftVolume: Player.defaultVolume,
            rightVolume: Player.defaultVolume,
            frequenciesLimited: true,
            volumesSynchronized: true,
            isPlaying: false,
          ),
        );

        container.read(playerProvider.notifier).setFrequenciesLimited(false);
        container
            .read(playerProvider.notifier)
            .setBinauralBeatsFrequency(Player.maxBinauralBeatsFrequency + 100);
        container.read(playerProvider.notifier).setBaseFrequency(Player.maxBaseFrequency + 100);
        playerState = container.read(playerProvider);
        expect(
          playerState,
          const PlayerState(
            binauralBeatsFrequency: Player.maxBinauralBeatsFrequency,
            baseFrequency: Player.maxBaseFrequency,
            leftVolume: Player.defaultVolume,
            rightVolume: Player.defaultVolume,
            frequenciesLimited: false,
            volumesSynchronized: true,
            isPlaying: false,
          ),
        );

        container
            .read(playerProvider.notifier)
            .setBinauralBeatsFrequency(Player.minBinauralBeatsFrequency - 100);
        container.read(playerProvider.notifier).setBaseFrequency(Player.minBaseFrequency - 100);
        playerState = container.read(playerProvider);
        expect(
          playerState,
          const PlayerState(
            binauralBeatsFrequency: Player.minBinauralBeatsFrequency,
            baseFrequency: Player.minBaseFrequency,
            leftVolume: Player.defaultVolume,
            rightVolume: Player.defaultVolume,
            frequenciesLimited: false,
            volumesSynchronized: true,
            isPlaying: false,
          ),
        );

        container.read(playerProvider.notifier).setBinauralBeatsFrequency(
            (Player.maxBinauralBeatsFrequency + Player.intermediateBinauralBeatsFrequencyLimit) /
                2);
        container.read(playerProvider.notifier).setBaseFrequency(
            (Player.maxBaseFrequency + Player.intermediateBaseFrequencyLimit) / 2);
        playerState = container.read(playerProvider);
        expect(
          playerState,
          const PlayerState(
            binauralBeatsFrequency: (Player.maxBinauralBeatsFrequency +
                    Player.intermediateBinauralBeatsFrequencyLimit) /
                2,
            baseFrequency: (Player.maxBaseFrequency + Player.intermediateBaseFrequencyLimit) / 2,
            leftVolume: Player.defaultVolume,
            rightVolume: Player.defaultVolume,
            frequenciesLimited: false,
            volumesSynchronized: true,
            isPlaying: false,
          ),
        );

        container.read(playerProvider.notifier).setFrequenciesLimited(true);
        playerState = container.read(playerProvider);
        expect(
          playerState,
          const PlayerState(
            binauralBeatsFrequency: Player.intermediateBinauralBeatsFrequencyLimit,
            baseFrequency: Player.intermediateBaseFrequencyLimit,
            leftVolume: Player.defaultVolume,
            rightVolume: Player.defaultVolume,
            frequenciesLimited: true,
            volumesSynchronized: true,
            isPlaying: false,
          ),
        );

        subscription.close();
        async.elapse(Duration.zero);
        expect(sharedPreferences.getDouble('binauralBeatsFrequency'),
            Player.intermediateBinauralBeatsFrequencyLimit);
        expect(sharedPreferences.getDouble('baseFrequency'), Player.intermediateBaseFrequencyLimit);
        expect(sharedPreferences.getBool('frequenciesLimited'), true);
      });
    });

    test('test setting volumes', () {
      fakeAsync((async) {
        sharedPreferences.setDouble('leftVolume', 0.12);
        sharedPreferences.setDouble('rightVolume', 0.34);

        final subscription = container.listen(playerProvider, (_, __) {});

        container.read(playerProvider.notifier).setLeftVolume(0.24);
        var playerState = container.read(playerProvider);
        expect(
          playerState,
          const PlayerState(
            binauralBeatsFrequency: Player.defaultBinauralBeatsFrequency,
            baseFrequency: Player.defaultBaseFrequency,
            leftVolume: 0.24,
            rightVolume: 0.46,
            frequenciesLimited: true,
            volumesSynchronized: true,
            isPlaying: false,
          ),
        );

        container.read(playerProvider.notifier).setRightVolume(0.56);
        playerState = container.read(playerProvider);
        expect(
          playerState,
          const PlayerState(
            binauralBeatsFrequency: Player.defaultBinauralBeatsFrequency,
            baseFrequency: Player.defaultBaseFrequency,
            leftVolume: 0.34,
            rightVolume: 0.56,
            frequenciesLimited: true,
            volumesSynchronized: true,
            isPlaying: false,
          ),
        );

        container.read(playerProvider.notifier).setLeftVolume(Player.maxVolume + 0.5);
        playerState = container.read(playerProvider);
        expect(
          playerState,
          const PlayerState(
            binauralBeatsFrequency: Player.defaultBinauralBeatsFrequency,
            baseFrequency: Player.defaultBaseFrequency,
            leftVolume: Player.maxVolume,
            rightVolume: Player.maxVolume,
            frequenciesLimited: true,
            volumesSynchronized: true,
            isPlaying: false,
          ),
        );

        container.read(playerProvider.notifier).setRightVolume(Player.minVolume - 0.5);
        playerState = container.read(playerProvider);
        expect(
          playerState,
          const PlayerState(
            binauralBeatsFrequency: Player.defaultBinauralBeatsFrequency,
            baseFrequency: Player.defaultBaseFrequency,
            leftVolume: Player.minVolume,
            rightVolume: Player.minVolume,
            frequenciesLimited: true,
            volumesSynchronized: true,
            isPlaying: false,
          ),
        );

        container.read(playerProvider.notifier).setVolumesSynchronized(false);
        container.read(playerProvider.notifier).incrementLeftVolume(0.4);
        container.read(playerProvider.notifier).incrementRightVolume(0.5);
        playerState = container.read(playerProvider);
        expect(
          playerState,
          const PlayerState(
            binauralBeatsFrequency: Player.defaultBinauralBeatsFrequency,
            baseFrequency: Player.defaultBaseFrequency,
            leftVolume: 0.4,
            rightVolume: 0.5,
            frequenciesLimited: true,
            volumesSynchronized: false,
            isPlaying: false,
          ),
        );

        subscription.close();
        async.elapse(Duration.zero);
        expect(sharedPreferences.getDouble('leftVolume'), 0.4);
        expect(sharedPreferences.getDouble('rightVolume'), 0.5);
        expect(sharedPreferences.getBool('volumesSynchronized'), false);
      });
    });

    test('test toggleIsPlaying', () {
      final subscription = container.listen(playerProvider, (_, __) {});

      container.read(playerProvider.notifier).toggleIsPlaying();
      var playerState = container.read(playerProvider);
      expect(
        playerState,
        const PlayerState(
          binauralBeatsFrequency: Player.defaultBinauralBeatsFrequency,
          baseFrequency: Player.defaultBaseFrequency,
          leftVolume: Player.defaultVolume,
          rightVolume: Player.defaultVolume,
          frequenciesLimited: true,
          volumesSynchronized: true,
          isPlaying: true,
        ),
      );

      container.read(playerProvider.notifier).toggleIsPlaying();
      playerState = container.read(playerProvider);
      expect(
        playerState,
        const PlayerState(
          binauralBeatsFrequency: Player.defaultBinauralBeatsFrequency,
          baseFrequency: Player.defaultBaseFrequency,
          leftVolume: Player.defaultVolume,
          rightVolume: Player.defaultVolume,
          frequenciesLimited: true,
          volumesSynchronized: true,
          isPlaying: false,
        ),
      );

      subscription.close();
    });
  });
}
