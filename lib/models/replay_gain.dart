import 'dart:math' as math;

/// Which ReplayGain value playback uses to level loudness.
enum ReplayGainMode {
  off,
  track,
  album;

  static ReplayGainMode fromStorage(String? value) {
    return ReplayGainMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => ReplayGainMode.off,
    );
  }
}

/// ReplayGain values read from a file's tags. Gains are in dB relative to the
/// ReplayGain reference level; peaks are linear sample peaks (1.0 = full scale).
class ReplayGainInfo {
  const ReplayGainInfo({
    this.trackGain,
    this.albumGain,
    this.trackPeak,
    this.albumPeak,
  });

  final double? trackGain;
  final double? albumGain;
  final double? trackPeak;
  final double? albumPeak;

  bool get hasGain => trackGain != null || albumGain != null;
}

/// MediaItem extras keys carrying a song's ReplayGain values to the handler.
abstract final class ReplayGainExtras {
  static const trackGain = 'rg_track_gain';
  static const albumGain = 'rg_album_gain';
  static const trackPeak = 'rg_track_peak';
  static const albumPeak = 'rg_album_peak';

  /// Builds extras for a song's gains, or `null` when it has none.
  static Map<String, dynamic>? build({
    double? trackGain,
    double? albumGain,
    double? trackPeak,
    double? albumPeak,
  }) {
    if (trackGain == null && albumGain == null) return null;
    return {
      ReplayGainExtras.trackGain: ?trackGain,
      ReplayGainExtras.albumGain: ?albumGain,
      ReplayGainExtras.trackPeak: ?trackPeak,
      ReplayGainExtras.albumPeak: ?albumPeak,
    };
  }

  /// Reads the gains back from MediaItem extras.
  static ReplayGainInfo? parse(Map<String, dynamic>? extras) {
    if (extras == null) return null;
    double? value(String key) => (extras[key] as num?)?.toDouble();
    var info = ReplayGainInfo(
      trackGain: value(trackGain),
      albumGain: value(albumGain),
      trackPeak: value(trackPeak),
      albumPeak: value(albumPeak),
    );
    return info.hasGain ? info : null;
  }
}

/// Linear volume multiplier for [info] in [mode].
///
/// Returns 1.0 when levelling is off or the song has no usable gain. Album
/// mode falls back to the track gain when the album gain is missing. A known
/// peak caps the multiplier so the result never clips.
double replayGainMultiplier(ReplayGainInfo? info, ReplayGainMode mode) {
  if (info == null || mode == ReplayGainMode.off) return 1.0;

  var gain = mode == ReplayGainMode.album
      ? info.albumGain ?? info.trackGain
      : info.trackGain ?? info.albumGain;
  if (gain == null || !gain.isFinite) return 1.0;

  // Clipping depends on this track's own samples, so its peak is the exact
  // limit; the album peak is a safe (larger or equal) stand-in.
  var peak = info.trackPeak ?? info.albumPeak;

  var multiplier = math.pow(10, gain / 20).toDouble();
  if (peak != null && peak > 0 && multiplier * peak > 1.0) {
    multiplier = 1.0 / peak;
  }
  return multiplier;
}

/// Combines the user/fade [volume] with the ReplayGain [multiplier] into the
/// player volume. The player cannot amplify, so the result is capped at 1.0.
double effectiveReplayGainVolume(double volume, double multiplier) =>
    (volume * multiplier).clamp(0.0, 1.0).toDouble();
