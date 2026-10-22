part of 'player_provider.dart';

/// Shuffle, repeat and queue editing.
extension PlayerQueue on PlayerProvider {
  // ── Shuffle ───────────────────────────────────────────────────────────────

  /// Toggles shuffle mode on/off.
  ///
  /// Shuffles only the tracks after the currently playing song in the queue,
  /// preserving seamless active track playback. Restores original order after
  /// the current track when disabled.
  Future<void> toggleShuffle() async {
    unawaited(HapticFeedback.lightImpact());
    if (currentSong == null) return;
    var current = currentSong!;

    if (isShuffled) {
      // Restore exact original order
      var origIndex = _originalQueue.indexWhere((s) => s.id == current.id);
      if (origIndex >= 0) {
        queue = List<Song>.from(_originalQueue);
        currentIndex = origIndex;
      }
      isShuffled = false;

      // When unshuffling, the currentIndex changes, so we must reload the whole playlist
      // to sync the AudioHandler's internal queue while preserving current playback position.
      try {
        var currentPosition = audioHandler.playbackState.value.updatePosition;
        await audioHandler.loadPlaylist(
          queue.map(_songToMediaItem).toList(),
          initialIndex: currentIndex,
          initialPosition: currentPosition,
        );
        if (isPlaying) {
          await audioHandler.play();
        }
      } catch (_) {}
    } else {
      // Shuffle only the songs after the current index.
      var remaining = queue.sublist(currentIndex + 1);
      remaining.shuffle();

      var newQueue = <Song>[];
      newQueue.addAll(queue.sublist(0, currentIndex + 1));
      newQueue.addAll(remaining);

      queue = newQueue;
      isShuffled = true;

      // Update the audio handler's playlist source after current index
      var remainingMediaItems = queue
          .sublist(currentIndex + 1)
          .map(_songToMediaItem)
          .toList();
      try {
        await audioHandler.updatePlaylistAfter(
          currentIndex,
          remainingMediaItems,
        );
      } on PlayerInterruptedException {
        await audioHandler.loadPlaylist(
          queue.map(_songToMediaItem).toList(),
          initialIndex: currentIndex,
        );
        if (isPlaying) {
          await audioHandler.play();
        }
      }
    }

    _notify();
  }

  /// Plays a list of songs shuffled, picking a random track to start, and sets shuffle mode to enabled.
  Future<void> quickShuffle(List<Song> songsList, {String? playlistId}) async {
    if (songsList.isEmpty) return;

    _playlistContext = playlistId;

    // Clone the list and shuffle it
    var shuffled = List<Song>.from(songsList)..shuffle();

    // Pick the first shuffled song as the starting track
    var startingSong = shuffled.first;

    statsService.recordShuffleSessionStart();

    await _loadAndPlay(
      song: startingSong,
      songList: shuffled,
      originalQueue: songsList,
      shuffled: true,
    );
  }

  // ── Repeat ────────────────────────────────────────────────────────────────

  /// Cycles the repeat mode: off → all → one → off.
  Future<void> cycleRepeatMode() async {
    unawaited(HapticFeedback.lightImpact());
    switch (repeatMode) {
      case RepeatMode.off:
        repeatMode = RepeatMode.all;
        await audioHandler.setRepeatMode(AudioServiceRepeatMode.all);
        break;
      case RepeatMode.all:
        repeatMode = RepeatMode.one;
        await audioHandler.setRepeatMode(AudioServiceRepeatMode.one);
        break;
      case RepeatMode.one:
        repeatMode = RepeatMode.off;
        await audioHandler.setRepeatMode(AudioServiceRepeatMode.none);
        break;
    }
    _notify();
  }

  // ── Queue manipulation ────────────────────────────────────────────────────

  /// Removes the song at [index] from the queue.
  Future<void> removeFromQueue(int index) async {
    if (index < 0 || index >= queue.length) return;

    var removedId = queue[index].id;
    queue.removeAt(index);
    _originalQueue.removeWhere((s) => s.id == removedId);
    await audioHandler.removeQueueItemAt(index);

    // Adjust currentIndex if needed.
    if (index < currentIndex) {
      currentIndex--;
    } else if (index == currentIndex) {
      // If the removed song was playing, clamp to bounds.
      if (currentIndex >= queue.length) {
        currentIndex = queue.isEmpty ? -1 : queue.length - 1;
      }
    }

    _notify();
  }

  /// Reorders a song in the queue from [oldIndex] to [newIndex].
  Future<void> reorderQueue(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= queue.length) return;
    if (newIndex < 0 || newIndex >= queue.length) return;

    var song = queue.removeAt(oldIndex);
    queue.insert(newIndex, song);

    // Keep currentIndex tracking the same song.
    if (oldIndex == currentIndex) {
      currentIndex = newIndex;
    } else if (oldIndex < currentIndex && newIndex >= currentIndex) {
      currentIndex--;
    } else if (oldIndex > currentIndex && newIndex <= currentIndex) {
      currentIndex++;
    }

    _notify();

    await audioHandler.moveQueueItem(oldIndex, newIndex);
  }

  /// Appends [song] to the end of the queue.
  Future<void> addToQueue(Song song) async {
    queue.add(song);
    await audioHandler.addQueueItem(_songToMediaItem(song));
    _notify();
    ImagePreflightService.instance.preflightQueueUpcoming(queue, currentIndex);
  }

  /// Appends multiple [songs] to the end of the queue.
  Future<void> addSongsToQueue(List<Song> songs) async {
    if (songs.isEmpty) return;
    queue.addAll(songs);
    _originalQueue.addAll(songs);
    await audioHandler.addQueueItems(songs.map(_songToMediaItem).toList());
    _notify();
    ImagePreflightService.instance.preflightQueueUpcoming(queue, currentIndex);
  }

  Future<void> _loadAndPlay({
    required Song song,
    required List<Song> songList,
    required List<Song> originalQueue,
    required bool shuffled,
  }) async {
    var requestToken = ++_playRequestToken;
    // Cleared so the media item listener re-arms once the new song loads.
    _resetListenSession();

    queue = List<Song>.from(songList);
    _originalQueue = List<Song>.from(originalQueue);
    isShuffled = shuffled;

    var index = queue.indexWhere((s) => s.id == song.id);
    currentIndex = index >= 0 ? index : 0;

    _notify();

    var mediaItems = queue.map(_songToMediaItem).toList();
    try {
      await audioHandler.loadPlaylist(mediaItems, initialIndex: currentIndex);
      if (requestToken != _playRequestToken) return;

      await audioHandler.play();
      if (requestToken != _playRequestToken) return;
    } on PlayerInterruptedException {
      if (requestToken != _playRequestToken) return;
      rethrow;
    }

    _notify();
    ImagePreflightService.instance.preflightQueueUpcoming(queue, currentIndex);
  }

  /// Inserts [song] immediately after the currently playing song.
  Future<void> playNext(Song song) async {
    var insertIndex = currentIndex + 1;
    if (insertIndex >= queue.length) {
      queue.add(song);
    } else {
      queue.insert(insertIndex, song);
    }
    await audioHandler.insertQueueItemAt(insertIndex, _songToMediaItem(song));
    _notify();
    ImagePreflightService.instance.preflightQueueUpcoming(queue, currentIndex);
  }

  /// Inserts multiple [songs] immediately after the currently playing song.
  Future<void> playNextSongs(List<Song> songs) async {
    if (songs.isEmpty) return;
    var insertIndex = currentIndex + 1;
    if (insertIndex >= queue.length) {
      queue.addAll(songs);
    } else {
      queue.insertAll(insertIndex, songs);
    }
    await audioHandler.insertQueueItemsAt(
      insertIndex,
      songs.map(_songToMediaItem).toList(),
    );
    _notify();
    ImagePreflightService.instance.preflightQueueUpcoming(queue, currentIndex);
  }
}
