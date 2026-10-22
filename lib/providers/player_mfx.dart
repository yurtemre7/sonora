part of 'player_provider.dart';

/// Volume, playback speed and music effects (MFX).
extension PlayerMfx on PlayerProvider {
  // ── Volume & Speed ────────────────────────────────────────────────────────

  double get volume => _volume;
  double get speed => _speed;

  Future<void> setVolume(double value) async {
    _volume = (value.clamp(0.0, 1.0) * 100).round() / 100;
    await audioHandler.setVolume(_volume);
    var prefs = SharedPreferencesAsync();
    await prefs.setDouble('volume', _volume);
    _notify();
  }

  Future<void> setSpeed(double value) async {
    _speed = value.clamp(0.5, 2.0);
    if (!isMfxPresetActive) {
      await audioHandler.setSpeed(_speed);
    }
    var prefs = SharedPreferencesAsync();
    await prefs.setDouble('speed', _speed);
    _notify();
  }

  // ── Experimental MFX ──────────────────────────────────────────────────────

  MfxPreset? get mfxPreset => _mfxPreset;
  bool get isMfxPresetActive => _mfxPreset != null && !_mfxPreset!.isNormal;
  bool isPreset(MfxPreset preset) {
    if (preset.isNormal) {
      return _mfxPreset == null || _mfxPreset!.isNormal;
    }
    return _mfxPreset == preset;
  }

  bool isPresetSpeed(double speed) =>
      _mfxPreset != null && (_mfxPreset!.speed - speed).abs() < 0.001;

  bool get isSlowed => _mfxPreset == MfxPreset.slowed;
  bool get isSuperSlowed => _mfxPreset == MfxPreset.superSlowed;
  bool get isNightcore => _mfxPreset == MfxPreset.nightcore;
  bool get isSpedUp => _mfxPreset == MfxPreset.spedUp;
  bool get isSuperSpedUp => _mfxPreset == MfxPreset.superSpedUp;
  bool get isReverbEnabled => _isReverbEnabled;
  bool get isLofiEnabled => _isLofiEnabled;
  bool get isBassBoostEnabled => _isBassBoostEnabled;
  bool get isCustomEqEnabled => _isCustomEqEnabled;
  bool get isBluetoothMfxPatchEnabled => _isBluetoothMfxPatchEnabled;
  List<double>? get customEqGains => _customEqGains;

  double get effectiveSpeed {
    if (_mfxPreset != null && !_mfxPreset!.isNormal) return _mfxPreset!.speed;
    return _speed;
  }

  Duration get effectiveDuration {
    var song = currentSong;
    if (song == null || song.duration.inMilliseconds <= 0) return Duration.zero;
    var speed = effectiveSpeed;
    if (speed <= 0 || speed == 1.0) return song.duration;
    return Duration(
      milliseconds: (song.duration.inMilliseconds / speed).round(),
    );
  }

  Duration calculateEffectiveDuration(Duration original, double speedFactor) {
    if (speedFactor <= 0 || original.inMilliseconds <= 0) return original;
    return Duration(
      milliseconds: (original.inMilliseconds / speedFactor).round(),
    );
  }

  bool get isMfxActive =>
      isMfxPresetActive ||
      _isReverbEnabled ||
      _isLofiEnabled ||
      _isBassBoostEnabled ||
      _isCustomEqEnabled ||
      _speed != 1.0;

  Future<void> _saveMfxSettings() async {
    var prefs = SharedPreferencesAsync();
    if (_mfxPreset != null && !_mfxPreset!.isNormal) {
      await prefs.setString('mfx_preset_name', _mfxPreset!.name);
      await prefs.setDouble('mfx_preset', _mfxPreset!.speed);
    } else {
      await prefs.remove('mfx_preset_name');
      await prefs.remove('mfx_preset');
    }
    await prefs.setBool('mfx_isSlowed', _isSlowed);
    await prefs.setBool('mfx_isSuperSlowed', _isSuperSlowed);
    await prefs.setBool('mfx_isSpedUp', _isSpedUp);
    await prefs.setBool('mfx_isSuperSpedUp', _isSuperSpedUp);
    await prefs.setBool('mfx_isNightcore', _isNightcore);
    await prefs.setBool('mfx_isReverbEnabled', _isReverbEnabled);
    await prefs.setBool('mfx_isLofiEnabled', _isLofiEnabled);
    await prefs.setBool('mfx_isBassBoostEnabled', _isBassBoostEnabled);
    await prefs.setBool('mfx_isCustomEqEnabled', _isCustomEqEnabled);
    await prefs.setBool('mfx_bluetoothMfxPatch', _isBluetoothMfxPatchEnabled);
    if (_customEqGains != null) {
      await prefs.setStringList(
        'mfx_customEqGains',
        _customEqGains!.map((e) => e.toString()).toList(),
      );
    } else {
      await prefs.remove('mfx_customEqGains');
    }
  }

  Future<void> setMfxPreset(MfxPreset? preset) async {
    if (preset == null || preset.isNormal) {
      _mfxPreset = null;
    } else {
      _mfxPreset = preset;
    }
    _isSuperSlowed = _mfxPreset == MfxPreset.superSlowed;
    _isSlowed = _mfxPreset == MfxPreset.slowed;
    _isSpedUp = _mfxPreset == MfxPreset.spedUp;
    _isNightcore = _mfxPreset == MfxPreset.nightcore;
    _isSuperSpedUp = _mfxPreset == MfxPreset.superSpedUp;
    await _saveMfxSettings();
    await _applyMfx();
  }

  Future<void> setMfxPresetFromSpeed(double? speed) =>
      setMfxPreset(MfxPreset.fromSpeed(speed));

  Future<void> setSlowed(bool value) =>
      setMfxPreset(value ? MfxPreset.slowed : null);
  Future<void> setSuperSlowed(bool value) =>
      setMfxPreset(value ? MfxPreset.superSlowed : null);
  Future<void> setSpedUp(bool value) =>
      setMfxPreset(value ? MfxPreset.spedUp : null);
  Future<void> setSuperSpedUp(bool value) =>
      setMfxPreset(value ? MfxPreset.superSpedUp : null);
  Future<void> setNightcore(bool value) =>
      setMfxPreset(value ? MfxPreset.nightcore : null);

  Future<void> setReverbEnabled(bool value) async {
    _isReverbEnabled = value;
    if (_isReverbEnabled) {
      _isLofiEnabled = false;
      _isBassBoostEnabled = false;
    }
    await _saveMfxSettings();
    await _applyMfx();
  }

  Future<void> setLofiEnabled(bool value) async {
    _isLofiEnabled = value;
    if (_isLofiEnabled) {
      _isReverbEnabled = false;
      _isBassBoostEnabled = false;
    }
    await _saveMfxSettings();
    await _applyMfx();
  }

  Future<void> setBassBoostEnabled(bool value) async {
    _isBassBoostEnabled = value;
    if (_isBassBoostEnabled) {
      _isReverbEnabled = false;
      _isLofiEnabled = false;
    }
    await _saveMfxSettings();
    await _applyMfx();
  }

  Future<void> setCustomEqBands(List<double> gains) async {
    _isLofiEnabled = false;
    _isBassBoostEnabled = false;
    _isReverbEnabled = false;
    _isCustomEqEnabled = true;
    _customEqGains = gains;
    await _saveMfxSettings();
    await _applyMfx();
  }

  Future<void> setBluetoothMfxPatchEnabled(bool value) async {
    _isBluetoothMfxPatchEnabled = value;
    await _saveMfxSettings();
    await _applyMfx();
  }

  Future<void> resetAllMfx() async {
    _mfxPreset = null;
    _isSlowed = false;
    _isSuperSlowed = false;
    _isSpedUp = false;
    _isSuperSpedUp = false;
    _isNightcore = false;
    _isBassBoostEnabled = false;
    _isReverbEnabled = false;
    _isLofiEnabled = false;
    _isCustomEqEnabled = false;
    _speed = 1.0;
    var prefs = SharedPreferencesAsync();
    await prefs.setDouble('speed', _speed);
    await _saveMfxSettings();
    await _applyMfx();
  }

  Future<void> _applyMfx() async {
    if (_mfxPreset != null && !_mfxPreset!.isNormal) {
      await audioHandler.setSpeed(_mfxPreset!.speed);
      await audioHandler.setPitch(_mfxPreset!.pitch);
    } else {
      await audioHandler.setSpeed(_speed);
      await audioHandler.setPitch(1.0);
    }

    var eqMode = 'off';
    if (_isLofiEnabled) {
      eqMode = 'lofi';
    } else if (_isReverbEnabled) {
      eqMode = 'warmth';
    } else if (_isBassBoostEnabled) {
      eqMode = 'bass_boost';
    } else if (_isCustomEqEnabled) {
      eqMode = 'custom';
    }
    await audioHandler.setEqMode(
      eqMode,
      customGains: _customEqGains,
      isBluetoothPatch: _isBluetoothMfxPatchEnabled,
    );
    _notify();
  }
}
