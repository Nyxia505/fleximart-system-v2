/// Optional auto-fill when an OTP push is received on a verify screen.
/// OTP is shown only in the device notification tray, not in-app.
class OtpPopupService {
  OtpPopupService._();
  static final OtpPopupService instance = OtpPopupService._();

  /// Set on verify screens to auto-fill when a push arrives.
  void Function(String)? onOtpReceived;
}
