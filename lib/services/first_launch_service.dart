import 'package:shared_preferences/shared_preferences.dart';

class FirstLaunchService {
  static const String _keyIsFirstLaunch = 'is_first_launch';
  static const String _keyHasSeenWelcome = 'has_seen_welcome';

  /// Check if this is the first time the app is launched
  static Future<bool> isFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsFirstLaunch) ?? true;
  }

  /// Mark that the app has been launched (not first time anymore)
  static Future<void> markAsLaunched() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsFirstLaunch, false);
  }

  /// Check if user has seen the welcome screen
  static Future<bool> hasSeenWelcome() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyHasSeenWelcome) ?? false;
  }

  /// Mark that user has seen the welcome screen
  static Future<void> markWelcomeAsSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHasSeenWelcome, true);
    await markAsLaunched(); // Also mark as launched
  }
}

