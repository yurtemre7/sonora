import 'dart:developer';

class Logger {
  static const _prefix = '[SONORA | 道]';

  static void youkoso(String message) {
    log('$_prefix ようこそ $message へ!');
  }

  static void ikou(String destination) {
    log('$_prefix いこう -> $destination');
  }

  static void modoru(String destination) {
    log('$_prefix 戻る <- $destination');
  }

  static void meguru(String from, String to) {
    log('$_prefix 迷路? $from -> $to');
  }

  static void tsuuchi(String message) {
    log('$_prefix 通知: $message');
  }
}
