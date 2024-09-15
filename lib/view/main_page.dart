import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../player.dart';
import '../tone_generator.dart';
import 'info_page.dart';
import 'settings_page.dart';

/// The main page of the application.
class MainPage extends ConsumerStatefulWidget {
  const MainPage({super.key});

  @override
  ConsumerState<MainPage> createState() => _MainPageState();
}

class _MainPageState extends ConsumerState<MainPage> {
  /// The maximum number of errors stored to show in snack bars.
  static const int _maxErrorCount = 5;

  late final StreamSubscription<String> _errorStreamSubscription;

  /// The number of errors stored to show in snack bars.
  int _errorCount = 0;

  @override
  void initState() {
    super.initState();

    // Listen to the player state changes and reflect them to the tone generator.
    final toneGenerator = ref.read(toneGeneratorProvider);
    ref.listenManual(playerProvider, (previous, next) {
      toneGenerator.setParameters(next.binauralBeatsFrequency.roundToDouble(),
          next.baseFrequency.roundToDouble(), next.leftVolume, next.rightVolume);
      if ((previous == null || !previous.isPlaying) && next.isPlaying) {
        toneGenerator.start();
      } else if ((previous == null || previous.isPlaying) && !next.isPlaying) {
        toneGenerator.stop();
      }
    });

    // Set up the snack bar to show errors.
    _errorStreamSubscription = toneGenerator.errorStream.listen((message) {
      if (mounted && _errorCount < _maxErrorCount) {
        _errorCount++;
        final messageText = Text(AppLocalizations.of(context)!.errorMessage(message));
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: messageText))
            .closed
            .then((_) => _errorCount--);
      }
    });
  }

  @override
  void dispose() {
    _errorStreamSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final playerState = ref.watch(playerProvider);
    final playerNotifier = ref.watch(playerProvider.notifier);

    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        // Binaural beats frequency slider
        _LabeledValue(
          label: l10n.binauralBeatsLabel,
          value: '${playerState.binauralBeatsFrequency.round()} Hz',
        ),
        Row(
          children: [
            _RepeatIconButton(
              icon: const Icon(Icons.arrow_left),
              onPressed: () => playerNotifier.incrementBinauralBeatsFrequency(-1),
            ),
            Expanded(
              child: Slider(
                value: log(playerState.binauralBeatsFrequency),
                min: log(Player.minBinauralBeatsFrequency),
                max: log(Player.maxBinauralBeatsFrequency),
                onChanged: (value) => playerNotifier.setBinauralBeatsFrequency(exp(value)),
              ),
            ),
            _RepeatIconButton(
              icon: const Icon(Icons.arrow_right),
              onPressed: () => playerNotifier.incrementBinauralBeatsFrequency(1),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Base frequency slider
        _LabeledValue(
          label: l10n.baseFrequencyLabel,
          value: '${playerState.baseFrequency.round()} Hz',
        ),
        Row(
          children: [
            _RepeatIconButton(
              icon: const Icon(Icons.arrow_left),
              onPressed: () => playerNotifier.incrementBaseFrequency(-1),
            ),
            Expanded(
              child: Slider(
                value: log(playerState.baseFrequency),
                min: log(Player.minBaseFrequency),
                max: log(Player.maxBaseFrequency),
                onChanged: (double value) => playerNotifier.setBaseFrequency(exp(value)),
              ),
            ),
            _RepeatIconButton(
              icon: const Icon(Icons.arrow_right),
              onPressed: () => playerNotifier.incrementBaseFrequency(1),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Limit frequencies switch
        Row(
          children: [
            Tooltip(
              message: l10n.limitFrequenciesTooltip,
              child: Row(
                children: [
                  SizedBox(
                    height: 24,
                    child: FittedBox(
                      fit: BoxFit.fill,
                      child: Switch(
                        value: playerState.frequenciesLimited,
                        onChanged: (value) => playerNotifier.setFrequenciesLimited(value),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(l10n.limitFrequenciesLabel, style: Theme.of(context).textTheme.titleSmall),
                ],
              ),
            ),
          ],
        ),
        const Divider(),
        // Left volume slider
        _LabeledValue(
          label: l10n.leftVolumeLabel,
          value: '${(playerState.leftVolume * 100).round()}%',
        ),
        Row(
          children: [
            _RepeatIconButton(
              icon: const Icon(Icons.arrow_left),
              onPressed: () => playerNotifier.incrementLeftVolume(-0.01),
            ),
            Expanded(
              child: Slider(
                value: playerState.leftVolume,
                min: Player.minVolume,
                max: Player.maxVolume,
                onChanged: (double value) => playerNotifier.setLeftVolume(value),
              ),
            ),
            _RepeatIconButton(
              icon: const Icon(Icons.arrow_right),
              onPressed: () => playerNotifier.incrementLeftVolume(0.01),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Right volume slider
        _LabeledValue(
          label: l10n.rightVolumeLabel,
          value: '${(playerState.rightVolume * 100).round()}%',
        ),
        Row(
          children: [
            _RepeatIconButton(
              icon: const Icon(Icons.arrow_left),
              onPressed: () => playerNotifier.incrementRightVolume(-0.01),
            ),
            Expanded(
              child: Slider(
                value: playerState.rightVolume,
                min: Player.minVolume,
                max: Player.maxVolume,
                onChanged: (double value) => playerNotifier.setRightVolume(value),
              ),
            ),
            _RepeatIconButton(
              icon: const Icon(Icons.arrow_right),
              onPressed: () => playerNotifier.incrementRightVolume(0.01),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Synchronize volumes switch
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              height: 24,
              child: FittedBox(
                fit: BoxFit.fill,
                child: Switch(
                  value: playerState.volumesSynchronized,
                  onChanged: (value) => playerNotifier.setVolumesSynchronized(value),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Text(l10n.synchronizeVolumesLabel, style: Theme.of(context).textTheme.titleSmall),
          ],
        ),
        const Divider(),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SizedBox(width: 40, height: 40),
            // Play/pause button
            IconButton.filled(
              icon: playerState.isPlaying ? const Icon(Icons.pause) : const Icon(Icons.play_arrow),
              iconSize: 40,
              onPressed: () => playerNotifier.toggleIsPlaying(),
            ),
            Column(
              children: [
                // Info button
                SizedBox(
                  width: 40,
                  height: 40,
                  child: Tooltip(
                    message: l10n.infoPageTitle,
                    child: IconButton(
                      icon: const Icon(Icons.info),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const InfoPage()),
                        );
                      },
                    ),
                  ),
                ),
                // Settings page button
                SizedBox(
                  width: 40,
                  height: 40,
                  child: Tooltip(
                    message: l10n.settingsPageTitle,
                    child: IconButton(
                      icon: const Icon(Icons.settings),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const SettingsPage()),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

/// An icon button that repeats the action when long pressed.
class _RepeatIconButton extends StatefulWidget {
  final void Function()? onPressed;
  final Widget icon;

  /// Creates a new repeat icon button.
  ///
  /// The [onPressed] function is called when the button is pressed. This function is also called
  /// repeatedly when the button is long pressed.
  /// The [icon] is the icon to display on the button.
  const _RepeatIconButton({
    required this.onPressed,
    required this.icon,
  });

  @override
  State<_RepeatIconButton> createState() => _RepeatIconButtonState();
}

class _RepeatIconButtonState extends State<_RepeatIconButton> {
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (_) {
        _timer?.cancel();
        _timer = Timer.periodic(const Duration(milliseconds: 50), (_) {
          widget.onPressed?.call();
        });
      },
      onLongPressEnd: (_) {
        _timer?.cancel();
      },
      child: IconButton(
        icon: widget.icon,
        onPressed: widget.onPressed,
      ),
    );
  }
}

/// A widget that displays a label and a value.
class _LabeledValue extends StatelessWidget {
  final String label;
  final String value;

  /// Creates a new labeled value with the given [label] and [value].
  const _LabeledValue({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ],
    );
  }
}
