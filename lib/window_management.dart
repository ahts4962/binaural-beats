import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'preferences.dart';

MethodChannel? _windowMethodChannel;

/// Returns the scale factor of the monitor where the window is located.
///
/// If the method fails, default value (100) is returned.
/// This method is only available on Windows.
Future<double> _getScaleFactor() async {
  assert(Platform.isWindows);
  _windowMethodChannel ??= const MethodChannel('ahts4962.com/binaural_beats/window');
  try {
    return await _windowMethodChannel!.invokeMethod<double>('getScaleFactor') ?? 100;
  } on PlatformException {
    return 100;
  }
}

/// Initializes the host window.
///
/// Sets the window size, position, maximized state, and title.
/// Parameters are restored from the preferences.
/// This method is only available on Windows, Linux, and macOS.
Future<void> initializeWindow(AppPreferences preferences) async {
  assert(Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  await windowManager.ensureInitialized();

  var left = preferences.getDoubleWithDefault('windowLeft', 10);
  var top = preferences.getDoubleWithDefault('windowTop', 10);
  final width = preferences.getDoubleWithDefault('windowWidth', 380);
  final height = preferences.getDoubleWithDefault('windowHeight', 555);
  bool maximized = preferences.getBoolWithDefault('windowMaximized', false);
  if (Platform.isWindows) {
    // In Windows, return values of windowManager.getPosition depend on the scale factor
    // of the monitor where the window is located.
    // To set the correct position, we need to adjust the values.
    final currentScaleFactor = await _getScaleFactor();
    var scaleFactor = preferences.getDoubleWithDefault('windowScaleFactor', currentScaleFactor);
    if (scaleFactor < 100 || scaleFactor > 500) {
      scaleFactor = 100;
      preferences.setDouble('windowScaleFactor', scaleFactor);
    }
    left *= scaleFactor / currentScaleFactor;
    top *= scaleFactor / currentScaleFactor;
  }

  WindowOptions windowOptions = WindowOptions(
    title: 'Binaural Beats',
    minimumSize: const Size(260, 350),
    size: Size(width, height),
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.setPosition(Offset(left, top));
    if (maximized) {
      windowManager.maximize();
    }
  });
}

/// The widget that manages the window events.
class WindowManagerWidget extends ConsumerStatefulWidget {
  final Widget child;

  const WindowManagerWidget({required this.child, super.key});

  @override
  ConsumerState<WindowManagerWidget> createState() => _WindowManagerWidgetState();
}

class _WindowManagerWidgetState extends ConsumerState<WindowManagerWidget> with WindowListener {
  @override
  void initState() {
    super.initState();
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      windowManager.addListener(this);

      // Prevent the window from being closed to wait for saving preferences.
      windowManager.setPreventClose(true);
    }
  }

  @override
  void dispose() {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }

  /// Save the current window position and size to the local storage.
  Future<void> _updatePreferences(AppPreferences preferences) async {
    if (await windowManager.isMinimized()) {
      return;
    }

    final position = await windowManager.getPosition();
    preferences.setDouble('windowLeft', position.dx);
    preferences.setDouble('windowTop', position.dy);
    if (Platform.isWindows) {
      final scaleFactor = await _getScaleFactor();
      preferences.setDouble('windowScaleFactor', scaleFactor);
    }

    if (await windowManager.isMaximized()) {
      preferences.setBool('windowMaximized', true);
      return;
    }

    final size = await windowManager.getSize();
    preferences.setDouble('windowWidth', size.width);
    preferences.setDouble('windowHeight', size.height);
    preferences.setBool('windowMaximized', false);
  }

  @override
  void onWindowEvent(String eventName) {
    switch (eventName) {
      case 'resized' || 'moved' || 'maximize' || 'unmaximize' || 'focus' || 'blur' || 'restore':
        final preferences = ref.read(appPreferencesProvider);
        _updatePreferences(preferences);
    }
  }

  @override
  void onWindowClose() {
    final preferences = ref.read(appPreferencesProvider);
    () async {
      await _updatePreferences(preferences);
      await preferences.flush();
      await windowManager.destroy();
    }();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
