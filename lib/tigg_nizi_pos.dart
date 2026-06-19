import 'tigg_nizi_pos_platform_interface.dart';

export 'tigg_nizi_pos_platform_interface.dart';

enum B30ConnectionState { connected, disconnected, permissionDenied }

class TiggNiziPos {
  // ── Connection ─────────────────────────────────────────────────────────────

  /// Attempts to open the USB serial connection to the B30 device.
  ///
  /// Returns `true` if the device was found and opened immediately.
  /// Returns `false` if no device was found or if a USB permission dialog was
  /// shown to the user — in the latter case listen to [connectionStream] to
  /// receive the [B30ConnectionState.connected] event once the user grants
  /// permission.
  Future<bool> connect() => TiggNiziPosPlatform.instance.connect();

  /// Closes the USB serial connection.
  Future<void> disconnect() => TiggNiziPosPlatform.instance.disconnect();

  /// Returns `true` if a serial port is currently open.
  Future<bool> isConnected() => TiggNiziPosPlatform.instance.isConnected();

  /// Stream of connection state changes (attach / detach / permission denied).
  Stream<B30ConnectionState> get connectionStream {
    return TiggNiziPosPlatform.instance.connectionStream.map((event) {
      switch (event['state'] as String?) {
        case 'connected':
          return B30ConnectionState.connected;
        case 'permissionDenied':
          return B30ConnectionState.permissionDenied;
        default:
          return B30ConnectionState.disconnected;
      }
    });
  }

  // ── Raw command ────────────────────────────────────────────────────────────

  /// Sends a raw command string. A newline is appended automatically by the
  /// native layer. Use the high-level helpers below when possible.
  Future<void> sendCommand(String command) =>
      TiggNiziPosPlatform.instance.sendCommand(command);

  // ── Logo / Idle ────────────────────────────────────────────────────────────

  /// Shows the built-in idle / standby logo on the e-ink display.
  Future<void> showIdleLogo() => sendCommand('IDLE');

  /// Reads and displays a logo stored as [filename] on the device filesystem.
  Future<void> showLogoFromFile(String filename) =>
      sendCommand('FSREAD**$filename');

  // ── Display ────────────────────────────────────────────────────────────────

  /// Displays up to three lines of text.
  Future<void> displayText({
    required String mainTitle,
    required String subtitle,
    required String message,
  }) =>
      sendCommand('TEXT**$mainTitle**$subtitle**$message');

  /// Displays a QR code.
  ///
  /// [amount] — amount with currency, e.g. `"Rs. 1234.00"` (max 60 chars).
  /// [actionText] — instruction label, e.g. `"Scan to pay"` (max 44 chars).
  /// [qrData] — the QR payload / URL (max 399 chars for low error-correction).
  Future<void> displayQR({
    required String amount,
    required String actionText,
    required String qrData,
  }) =>
      sendCommand('QR**$amount**$actionText**$qrData');

  // ── Status screens ─────────────────────────────────────────────────────────

  /// Shows a loading / "please wait" screen.
  Future<void> displayLoading({
    required String amount,
    required String message,
  }) =>
      sendCommand('WAIT**$amount**$message');

  /// Shows a success confirmation screen.
  Future<void> displaySuccess({
    required String title,
    required String message,
  }) =>
      sendCommand('PASS**$title**$message');

  /// Shows a failure / error screen.
  Future<void> displayFailure({
    required String amount,
    required String message,
  }) =>
      sendCommand('FAIL**$amount**$message');

  /// Shows a warning screen.
  Future<void> displayWarning({
    required String title,
    required String message,
  }) =>
      sendCommand('WARN**$title**$message');

  /// Shows an informational screen.
  Future<void> displayInfo({
    required String title,
    required String message,
  }) =>
      sendCommand('INFO**$title**$message');

  // ── Device control ─────────────────────────────────────────────────────────

  /// Wakes the device from sleep.
  Future<void> wake() => sendCommand('WAKE');

  /// Puts the device to sleep / resets the display.
  Future<void> sleep() => sendCommand('RESET');

  /// Formats / clears the e-ink display.
  Future<void> formatDisplay() => sendCommand('FORMAT');

  /// Sets the screen-off timeout. [seconds] must be between 30 and 300.
  Future<void> setScreenTimeout(int seconds) {
    if (seconds < 30 || seconds > 300) {
      throw ArgumentError.value(
          seconds, 'seconds', 'Must be between 30 and 300');
    }
    return sendCommand('SCREENTIME**$seconds');
  }
}
