import 'dart:async';
import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'tone_generator.g.dart';

@Riverpod(keepAlive: true)
ToneGenerator toneGenerator(ToneGeneratorRef ref) {
  return ToneGenerator(const MethodChannel('ahts4962.com/binaural_beats/tone_generator'));
}

/// A class that generates and plays binaural beats.
class ToneGenerator {
  final MethodChannel _methodChannel;
  final StreamController<String> _errorStreamController = StreamController<String>.broadcast();

  /// Creates a new ToneGenerator.
  ///
  /// The [methodChannel] is the communication channel with the platform.
  /// This class calls MethodChannel.setMethodCallHandler,
  /// so method call handler is overwritten for this channel.
  ToneGenerator(MethodChannel methodChannel) : _methodChannel = methodChannel {
    _methodChannel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'reportError':
          String message = call.arguments;
          _errorStreamController.add(message);
        default:
          throw MissingPluginException();
      }
    });
  }

  /// A stream that emits error messages.
  Stream<String> get errorStream => _errorStreamController.stream;

  /// Sets the parameters of the binaural beats.
  ///
  /// [binauralBeatsFrequency] and [baseFrequency] are in Hz and must be greater than 0.
  /// The actual frequencies reproduced will be approximately [baseFrequency] ±
  /// [binauralBeatsFrequency]/2, and these must be less than 22.05 kHz.
  /// [leftVolume] and [rightVolume] must be between 0 and 1.
  Future<void> setParameters(double binauralBeatsFrequency, double baseFrequency, double leftVolume,
      double rightVolume) async {
    assert(binauralBeatsFrequency > 0);
    assert(baseFrequency > 0);
    assert(leftVolume >= 0 && leftVolume <= 1);
    assert(rightVolume >= 0 && rightVolume <= 1);

    try {
      double leftFrequency = (baseFrequency - binauralBeatsFrequency / 2).ceilToDouble();
      double rightFrequency = (baseFrequency + binauralBeatsFrequency / 2).ceilToDouble();
      assert(leftFrequency < 22050 && rightFrequency < 22050);

      if (leftFrequency < 1) {
        leftFrequency = 1;
      }
      if (rightFrequency < 1) {
        rightFrequency = 1;
      }

      await _methodChannel.invokeMethod<void>('setWaveParameters', <String, double>{
        'leftFrequency': leftFrequency,
        'rightFrequency': rightFrequency,
        'leftVolume': leftVolume,
        'rightVolume': rightVolume,
      });
    } on PlatformException catch (e) {
      _errorStreamController.add('Error in ToneGenerator.setParameters: ${e.message}');
    }
  }

  /// Starts playing the binaural beats.
  Future<void> start() async {
    try {
      await _methodChannel.invokeMethod<void>('startPlayingTone');
    } on PlatformException catch (e) {
      _errorStreamController.add('Error in ToneGenerator.start: ${e.message}');
    }
  }

  /// Stops playing the binaural beats.
  Future<void> stop() async {
    try {
      await _methodChannel.invokeMethod<void>('stopPlayingTone');
    } on PlatformException catch (e) {
      _errorStreamController.add('Error in ToneGenerator.stop: ${e.message}');
    }
  }

  /// Gets the current audio device information.
  ///
  /// Throws a [PlatformException] if the method call fails.
  Future<String> getAudioDeviceInfo() async {
    final deviceInfo = await _methodChannel.invokeMethod<String>('getAudioDeviceInfo');
    if (deviceInfo == null) {
      throw PlatformException(code: 'Error in ToneGenerator.getAudioDeviceInfo');
    } else {
      return deviceInfo;
    }
  }
}
