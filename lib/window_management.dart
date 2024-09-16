import 'dart:io';
import 'package:flutter/services.dart';

import 'preferences.dart';

MethodChannel _windowMethodChannel = const MethodChannel('ahts4962.com/binaural_beats/window');

/// Initializes the host window.
///
/// Set an event listener that restores the window position and size from the preferences
/// when the window is ready, and saves the window position and size to the preferences
/// when the window is closed.
/// This method is only available on Windows.
void initializeWindow(AppPreferences preferences) {
  assert(Platform.isWindows);

  _windowMethodChannel.setMethodCallHandler((call) async {
    if (call.method == 'onWindowReady') {
      // Load window placement from preferences.
      var left = preferences.getInt('windowLeft');
      var top = preferences.getInt('windowTop');
      var right = preferences.getInt('windowRight');
      var bottom = preferences.getInt('windowBottom');
      var maximizedLeft = preferences.getInt('windowMaximizedLeft');
      var maximizedTop = preferences.getInt('windowMaximizedTop');
      var maximized = preferences.getBool('windowMaximized');
      if (left == null ||
          top == null ||
          right == null ||
          bottom == null ||
          maximizedLeft == null ||
          maximizedTop == null ||
          maximized == null ||
          left > 0x7FFFFFFF ||
          top > 0x7FFFFFFF ||
          right > 0x7FFFFFFF ||
          bottom > 0x7FFFFFFF ||
          maximizedLeft > 0x7FFFFFFF ||
          maximizedTop > 0x7FFFFFFF ||
          left > right ||
          top > bottom) {
        // Set default values.
        left = 10;
        top = 10;
        right = 390;
        bottom = 565;
        maximizedLeft = 0;
        maximizedTop = 0;
        maximized = false;
      }
      await _windowMethodChannel.invokeMethod<void>('setWindowPlacement', <String, dynamic>{
        'left': left,
        'top': top,
        'right': right,
        'bottom': bottom,
        'maximizedLeft': maximizedLeft,
        'maximizedTop': maximizedTop,
        'maximized': maximized,
      });
    } else if (call.method == 'onWindowClose') {
      // Save window placement to preferences.
      final placement =
          await _windowMethodChannel.invokeMethod<Map<dynamic, dynamic>>('getWindowPlacement');
      if (placement != null) {
        preferences.setInt('windowLeft', placement['left']);
        preferences.setInt('windowTop', placement['top']);
        preferences.setInt('windowRight', placement['right']);
        preferences.setInt('windowBottom', placement['bottom']);
        preferences.setInt('windowMaximizedLeft', placement['maximizedLeft']);
        preferences.setInt('windowMaximizedTop', placement['maximizedTop']);
        preferences.setBool('windowMaximized', placement['maximized']);
      }
      await preferences.flush();
      await _windowMethodChannel.invokeMethod<void>('destroyWindow');
    }
  });
}
