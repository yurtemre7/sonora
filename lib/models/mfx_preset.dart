import 'package:material_ui/material_ui.dart';
import 'package:sonora/utils/l10n_extension.dart';

/// Predefined Music Effects (MFX) speed & matching pitch presets.
enum MfxPreset {
  superSlowed(
    speed: 0.70,
    icon: Icons.fast_rewind_rounded,
  ),
  slowed075(
    speed: 0.75,
    icon: Icons.fast_rewind_rounded,
    displayTitle: '25% slower',
  ),
  slowed080(
    speed: 0.80,
    icon: Icons.fast_rewind_rounded,
    displayTitle: '20% slower',
  ),
  slowed(
    speed: 0.85,
    icon: Icons.fast_rewind_rounded,
  ),
  slowed090(
    speed: 0.90,
    icon: Icons.fast_rewind_rounded,
    displayTitle: '10% slower',
  ),
  slowed095(
    speed: 0.95,
    icon: Icons.fast_rewind_rounded,
    displayTitle: '5% slower',
  ),
  normal(
    speed: 1.00,
    icon: Icons.play_arrow_rounded,
  ),
  spedUp105(
    speed: 1.05,
    icon: Icons.fast_forward_rounded,
    displayTitle: '5% faster',
  ),
  spedUp110(
    speed: 1.10,
    icon: Icons.fast_forward_rounded,
    displayTitle: '10% faster',
  ),
  spedUp115(
    speed: 1.15,
    icon: Icons.fast_forward_rounded,
    displayTitle: '15% faster',
  ),
  spedUp120(
    speed: 1.20,
    icon: Icons.fast_forward_rounded,
    displayTitle: '20% faster',
  ),
  spedUp(
    speed: 1.25,
    icon: Icons.fast_forward_rounded,
  ),
  nightcore(
    speed: 1.30,
    icon: Icons.bolt_rounded,
  ),
  superSpedUp(
    speed: 1.50,
    icon: Icons.fast_forward_rounded,
  );

  const MfxPreset({
    required this.speed,
    required this.icon,
    this.displayTitle,
  });

  /// The playback speed multiplier.
  final double speed;

  /// The icon representing this preset in the UI.
  final IconData icon;

  /// Explicit display title override if available.
  final String? displayTitle;

  /// The pitch multiplier, matching speed.
  double get pitch => speed;

  /// Whether this preset represents default, unaltered playback (1.0x).
  bool get isNormal => speed == 1.0;

  /// Localized or formatted title for preset cards.
  String getTitle(BuildContext context) {
    return switch (this) {
      MfxPreset.superSlowed => context.l10n.mfxSuperSlowed,
      MfxPreset.slowed075 => context.l10n.mfxPercentSlower('25'),
      MfxPreset.slowed080 => context.l10n.mfxPercentSlower('20'),
      MfxPreset.slowed => context.l10n.mfxSlowed,
      MfxPreset.slowed090 => context.l10n.mfxPercentSlower('10'),
      MfxPreset.slowed095 => context.l10n.mfxPercentSlower('5'),
      MfxPreset.normal => context.l10n.mfxNormal,
      MfxPreset.spedUp105 => context.l10n.mfxPercentFaster('5'),
      MfxPreset.spedUp110 => context.l10n.mfxPercentFaster('10'),
      MfxPreset.spedUp115 => context.l10n.mfxPercentFaster('15'),
      MfxPreset.spedUp120 => context.l10n.mfxPercentFaster('20'),
      MfxPreset.spedUp => context.l10n.mfxSpedUp,
      MfxPreset.nightcore => context.l10n.mfxNightcore,
      MfxPreset.superSpedUp => context.l10n.mfxSuperSpedUp,
    };
  }

  /// Localized subtitle displaying `{speed}x Speed`.
  String getSubtitle(BuildContext context) {
    if (isNormal) return context.l10n.mfxSpeedSubtitle('1.0');
    return context.l10n.mfxSpeedSubtitle(speed.toStringAsFixed(2));
  }

  /// Finds a preset matching [speed] with floating-point tolerance.
  static MfxPreset? fromSpeed(double? speed) {
    if (speed == null) return null;
    for (var preset in MfxPreset.values) {
      if ((preset.speed - speed).abs() < 0.001) {
        return preset;
      }
    }
    return null;
  }

  /// Finds a preset by its enum [name].
  static MfxPreset? fromName(String? name) {
    if (name == null) return null;
    for (var preset in MfxPreset.values) {
      if (preset.name == name) {
        return preset;
      }
    }
    return null;
  }
}
