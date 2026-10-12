import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:spotube/services/audio_player/audio_player.dart';

class SleepTimerNotifier extends StateNotifier<Duration?> {
  final Ref ref;
  Timer? _timer;

  SleepTimerNotifier(this.ref) : super(null) {
    ref.onDispose(() {
      _timer?.cancel();
    });
  }

  void setSleepTimer(Duration duration) {
    _timer?.cancel();
    state = duration;

    _timer = Timer(duration, () async {
      state = null;
      await audioPlayer.pause();
    });
  }

  void cancelSleepTimer() {
    state = null;
    _timer?.cancel();
  }
}

final sleepTimerProvider = StateNotifierProvider<SleepTimerNotifier, Duration?>(
  (ref) => SleepTimerNotifier(ref),
);
