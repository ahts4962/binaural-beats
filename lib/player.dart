import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'preferences.dart';

part 'player.freezed.dart';
part 'player.g.dart';

/// The state of the player of the binaural beats.
@freezed
class PlayerState with _$PlayerState {
  /// Set [frequenciesLimited] true to avoid the binaural beats and base frequency set too high.
  /// Set [volumesSynchronized] true to keep the left and right volume synchronized.
  const factory PlayerState({
    required double binauralBeatsFrequency,
    required double baseFrequency,
    required double leftVolume,
    required double rightVolume,
    required bool frequenciesLimited,
    required bool volumesSynchronized,
    required bool isPlaying,
  }) = _PlayerState;
}

@riverpod
class Player extends _$Player {
  // The default, minimum, and maximum values for each parameter.
  static const double defaultBinauralBeatsFrequency = 40;
  static const double minBinauralBeatsFrequency = 1;
  static const double maxBinauralBeatsFrequency = 10000;
  static const double intermediateBinauralBeatsFrequencyLimit = 1000;
  static const double defaultBaseFrequency = 440;
  static const double minBaseFrequency = 1;
  static const double maxBaseFrequency = 10000;
  static const double intermediateBaseFrequencyLimit = 1000;
  static const double defaultVolume = 0.5;
  static const double minVolume = 0;
  static const double maxVolume = 1;

  @override
  PlayerState build() {
    final preferences = ref.watch(appPreferencesProvider);

    // Load the parameters.
    var binauralBeatsFrequency =
        preferences.getDouble('binauralBeatsFrequency') ?? defaultBinauralBeatsFrequency;
    var baseFrequency = preferences.getDouble('baseFrequency') ?? defaultBaseFrequency;
    var leftVolume = preferences.getDouble('leftVolume') ?? defaultVolume;
    var rightVolume = preferences.getDouble('rightVolume') ?? defaultVolume;
    final frequenciesLimited = preferences.getBool('frequenciesLimited') ?? true;
    final volumesSynchronized = preferences.getBool('volumesSynchronized') ?? true;

    if (binauralBeatsFrequency < minBinauralBeatsFrequency ||
        binauralBeatsFrequency > maxBinauralBeatsFrequency) {
      binauralBeatsFrequency = defaultBinauralBeatsFrequency;
    } else if (frequenciesLimited &&
        binauralBeatsFrequency > intermediateBinauralBeatsFrequencyLimit) {
      binauralBeatsFrequency = intermediateBinauralBeatsFrequencyLimit;
    }
    if (baseFrequency < minBaseFrequency || baseFrequency > maxBaseFrequency) {
      baseFrequency = defaultBaseFrequency;
    } else if (frequenciesLimited && baseFrequency > intermediateBaseFrequencyLimit) {
      baseFrequency = intermediateBaseFrequencyLimit;
    }
    if (leftVolume < minVolume || leftVolume > maxVolume) {
      leftVolume = defaultVolume;
    }
    if (rightVolume < minVolume || rightVolume > maxVolume) {
      rightVolume = defaultVolume;
    }

    ref.listenSelf((previous, next) {
      preferences.setDouble('binauralBeatsFrequency', next.binauralBeatsFrequency);
      preferences.setDouble('baseFrequency', next.baseFrequency);
      preferences.setDouble('leftVolume', next.leftVolume);
      preferences.setDouble('rightVolume', next.rightVolume);
      preferences.setBool('frequenciesLimited', next.frequenciesLimited);
      preferences.setBool('volumesSynchronized', next.volumesSynchronized);
    });

    ref.onDispose(preferences.flush);

    return PlayerState(
      binauralBeatsFrequency: binauralBeatsFrequency,
      baseFrequency: baseFrequency,
      leftVolume: leftVolume,
      rightVolume: rightVolume,
      frequenciesLimited: frequenciesLimited,
      volumesSynchronized: volumesSynchronized,
      isPlaying: false,
    );
  }

  /// Set the binaural beats frequency to [value].
  void setBinauralBeatsFrequency(double value) {
    var binauralBeatsFrequency = value;
    if (state.frequenciesLimited) {
      binauralBeatsFrequency = binauralBeatsFrequency.clamp(
          minBinauralBeatsFrequency, intermediateBinauralBeatsFrequencyLimit);
    } else {
      binauralBeatsFrequency =
          binauralBeatsFrequency.clamp(minBinauralBeatsFrequency, maxBinauralBeatsFrequency);
    }
    state = state.copyWith(binauralBeatsFrequency: binauralBeatsFrequency);
  }

  /// Increments the binaural beats frequency by the given [value].
  void incrementBinauralBeatsFrequency(double value) {
    setBinauralBeatsFrequency(state.binauralBeatsFrequency + value);
  }

  /// Set the base frequency to [value].
  void setBaseFrequency(double value) {
    var baseFrequency = value;
    if (state.frequenciesLimited) {
      baseFrequency = baseFrequency.clamp(minBaseFrequency, intermediateBaseFrequencyLimit);
    } else {
      baseFrequency = baseFrequency.clamp(minBaseFrequency, maxBaseFrequency);
    }
    state = state.copyWith(baseFrequency: baseFrequency);
  }

  /// Increments the base frequency by the given [value].
  void incrementBaseFrequency(double value) {
    setBaseFrequency(state.baseFrequency + value);
  }

  /// Set frequenciesLimited to [value].
  void setFrequenciesLimited(bool value) {
    final frequenciesLimited = value;
    var binauralBeatsFrequency = state.binauralBeatsFrequency;
    var baseFrequency = state.baseFrequency;
    if (frequenciesLimited) {
      binauralBeatsFrequency = binauralBeatsFrequency.clamp(
          minBinauralBeatsFrequency, intermediateBinauralBeatsFrequencyLimit);
      baseFrequency = baseFrequency.clamp(minBaseFrequency, intermediateBaseFrequencyLimit);
    }
    state = state.copyWith(
      binauralBeatsFrequency: binauralBeatsFrequency,
      baseFrequency: baseFrequency,
      frequenciesLimited: frequenciesLimited,
    );
  }

  /// Set the left volume to [value].
  void setLeftVolume(double value) {
    var target = value;
    target = target.clamp(minVolume, maxVolume);
    var rightVolume = state.rightVolume;
    if (state.volumesSynchronized) {
      rightVolume += target - state.leftVolume;
      rightVolume = rightVolume.clamp(minVolume, maxVolume);
    }
    state = state.copyWith(leftVolume: target, rightVolume: rightVolume);
  }

  /// Increments the left volume by the given [value].
  void incrementLeftVolume(double value) {
    setLeftVolume(state.leftVolume + value);
  }

  /// Set the right volume to [value].
  void setRightVolume(double value) {
    var target = value;
    target = target.clamp(minVolume, maxVolume);
    var leftVolume = state.leftVolume;
    if (state.volumesSynchronized) {
      leftVolume += target - state.rightVolume;
      leftVolume = leftVolume.clamp(minVolume, maxVolume);
    }
    state = state.copyWith(leftVolume: leftVolume, rightVolume: target);
  }

  /// Increments the right volume by the given [value].
  void incrementRightVolume(double value) {
    setRightVolume(state.rightVolume + value);
  }

  /// Set volumesSynchronized to [value].
  void setVolumesSynchronized(bool value) {
    state = state.copyWith(volumesSynchronized: value);
  }

  /// Toggle isPlaying.
  void toggleIsPlaying() {
    state = state.copyWith(isPlaying: !state.isPlaying);
  }
}
