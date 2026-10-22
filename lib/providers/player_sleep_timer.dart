part of 'player_provider.dart';

/// Sleep timer, finish-song mode and fade-out.
extension PlayerSleepTimer on PlayerProvider {
  void _updateMediaNotificationControls() {
    audioHandler.updateSleepTimerState(
      active: sleepTimerDuration != null,
      label: '+1 min',
    );
  }

  bool get isFinishingCurrentSong => _isFinishingCurrentSong;
  @visibleForTesting
  set isFinishingCurrentSong(bool value) {
    _isFinishingCurrentSong = value;
    _notify();
  }

  void startSleepTimer(
    Duration duration, {
    bool? finishSong,
    int? fadeOutSecs,
  }) {
    stopSleepTimer();

    sleepTimerOriginalDuration = duration;
    sleepTimerDuration = duration;
    _isFadingOut = false;
    _isFinishingCurrentSong = false;
    _finishSongTargetSongId = null;
    _originalVolumeBeforeFade = audioHandler.player.volume;
    sleepTimerFinishSongActive =
        finishSong ?? SettingsProvider.instance.sleepTimerFinishSong;
    var fadeDurationSecs =
        fadeOutSecs ?? SettingsProvider.instance.sleepTimerFadeOutSeconds;

    _updateMediaNotificationControls();
    SleepTimerNotificationService().updateTimerNotification(duration);

    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (sleepTimerDuration == null) {
        timer.cancel();
        SleepTimerNotificationService().cancelNotification();
        return;
      }

      var remaining = sleepTimerDuration! - const Duration(seconds: 1);
      if (remaining.isNegative || remaining == Duration.zero) {
        sleepTimerDuration = Duration.zero;
        timer.cancel();
        _sleepTimer = null;

        if (sleepTimerFinishSongActive &&
            audioHandler.player.playing &&
            currentSong != null) {
          _startFinishingActiveSong(fadeDurationSecs);
        } else {
          await _finalizeSleepTimerStop();
        }
      } else {
        sleepTimerDuration = remaining;

        // When finishSong is NOT active, fade out occurs during the countdown
        if (!sleepTimerFinishSongActive &&
            fadeDurationSecs > 0 &&
            remaining.inSeconds <= fadeDurationSecs) {
          if (!_isFadingOut) {
            _isFadingOut = true;
            _originalVolumeBeforeFade = audioHandler.player.volume;
          }
          var fraction = remaining.inSeconds / fadeDurationSecs.toDouble();
          await audioHandler.player.setVolume(
            (_originalVolumeBeforeFade * fraction).clamp(0.0, 1.0),
          );
        }

        SleepTimerNotificationService().updateTimerNotification(remaining);
        _notify();
      }
    });

    _notify();
  }

  void _startFinishingActiveSong(int fadeDurationSecs) {
    _finishSongTimer?.cancel();
    _isFinishingCurrentSong = true;
    _finishSongTargetSongId = currentSong?.id;
    _originalVolumeBeforeFade = _volume;

    // Reset volume to normal volume in case it was attenuated
    audioHandler.player.setVolume(_originalVolumeBeforeFade);
    _isFadingOut = false;

    SleepTimerNotificationService().updateTimerNotification(
      Duration.zero,
      customBody: 'Finishing active song...',
    );

    _finishSongTimer = Timer.periodic(const Duration(milliseconds: 250), (
      timer,
    ) async {
      if (!_isFinishingCurrentSong || sleepTimerDuration == null) {
        timer.cancel();
        return;
      }

      // If playback stopped or user paused
      if (!audioHandler.player.playing) {
        timer.cancel();
        await _finalizeSleepTimerStop();
        return;
      }

      var song = currentSong;
      // If song changed or ended, pause immediately so next track does not play
      if (song == null ||
          (_finishSongTargetSongId != null &&
              song.id != _finishSongTargetSongId)) {
        timer.cancel();
        await audioHandler.pause();
        await _finalizeSleepTimerStop();
        return;
      }

      var songDuration = audioHandler.player.duration ?? song.duration;
      var pos = audioHandler.player.position;
      var remainingInSong = songDuration - pos;

      // Song reached its finish boundary
      if (remainingInSong <= const Duration(milliseconds: 250) ||
          pos >= songDuration) {
        timer.cancel();
        await audioHandler.pause();
        await _finalizeSleepTimerStop();
        return;
      }

      // Apply fade-out in the final fadeDurationSecs of the current song
      if (fadeDurationSecs > 0 &&
          remainingInSong.inSeconds <= fadeDurationSecs) {
        if (!_isFadingOut) {
          _isFadingOut = true;
        }
        var fraction =
            remainingInSong.inMilliseconds /
            (fadeDurationSecs * 1000).toDouble();
        await audioHandler.player.setVolume(
          (_originalVolumeBeforeFade * fraction).clamp(0.0, 1.0),
        );
      }
    });

    _notify();
  }

  Future<void> _finalizeSleepTimerStop() async {
    _finishSongTimer?.cancel();
    _finishSongTimer = null;
    _sleepTimer?.cancel();
    _sleepTimer = null;

    await audioHandler.pause();
    await audioHandler.player.setVolume(_volume);

    sleepTimerDuration = null;
    sleepTimerOriginalDuration = null;
    _isFadingOut = false;
    _isFinishingCurrentSong = false;
    _finishSongTargetSongId = null;
    sleepTimerFinishSongActive = false;

    _updateMediaNotificationControls();
    SleepTimerNotificationService().cancelNotification();
    _notify();
  }

  void stopSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _finishSongTimer?.cancel();
    _finishSongTimer = null;
    sleepTimerDuration = null;
    sleepTimerOriginalDuration = null;
    _isFinishingCurrentSong = false;
    _finishSongTargetSongId = null;
    sleepTimerFinishSongActive = false;
    if (_isFadingOut) {
      audioHandler.player.setVolume(_originalVolumeBeforeFade);
      _isFadingOut = false;
    }
    _updateMediaNotificationControls();
    SleepTimerNotificationService().cancelNotification();
    _notify();
  }

  void extendSleepTimer(Duration extension) {
    if (sleepTimerDuration == null) {
      startSleepTimer(extension);
      return;
    }
    _finishSongTimer?.cancel();
    _finishSongTimer = null;
    _isFinishingCurrentSong = false;
    _finishSongTargetSongId = null;

    if (_isFadingOut) {
      _isFadingOut = false;
      audioHandler.player.setVolume(_originalVolumeBeforeFade);
    }

    var newDuration = (sleepTimerDuration ?? Duration.zero) + extension;
    startSleepTimer(newDuration, finishSong: sleepTimerFinishSongActive);
  }
}
