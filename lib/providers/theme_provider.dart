import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_colors.dart';

class ThemeProvider extends ChangeNotifier {
  static const _prefThemeMode = 'theme_mode';

  Color _primaryColor = AppColors.primary;
  Color _secondaryColor = AppColors.secondary;
  String _themeMode = 'system';
  bool _isLoading = false;

  Color get primaryColor => _primaryColor;
  Color get secondaryColor => _secondaryColor;
  String get themeMode => _themeMode;
  bool get isLoading => _isLoading;

  ThemeMode get themeModeEnum {
    switch (_themeMode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  ThemeProvider() {
    _loadLocalTheme();
    _loadThemeSettings();
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        _loadThemeSettings();
      } else {
        _primaryColor = AppColors.primary;
        _secondaryColor = AppColors.secondary;
        _themeMode = 'system';
        notifyListeners();
      }
    });
  }

  Future<void> _loadLocalTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final mode = prefs.getString(_prefThemeMode);
      if (mode != null && _isValidMode(mode)) {
        _themeMode = mode;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading local theme: $e');
    }
  }

  Future<void> _loadThemeSettings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data() ?? {};
        final themeColorValue = data['theme_color'] as int?;
        final themeModeValue = data['theme_mode'] as String?;

        if (themeColorValue != null) {
          _primaryColor = Color(themeColorValue);
          _secondaryColor = _generateSecondaryColor(_primaryColor);
        }

        if (themeModeValue != null && _isValidMode(themeModeValue)) {
          _themeMode = themeModeValue;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_prefThemeMode, themeModeValue);
        }
      }
    } catch (e) {
      debugPrint('Error loading theme settings: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Updates app theme immediately; Firestore is saved by settings screens.
  void setThemeMode(String mode) {
    if (!_isValidMode(mode)) return;

    _themeMode = mode;
    notifyListeners();

    SharedPreferences.getInstance().then((prefs) {
      prefs.setString(_prefThemeMode, mode);
    }).catchError((e) {
      debugPrint('Error saving local theme mode: $e');
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .set({'theme_mode': mode}, SetOptions(merge: true))
        .catchError((e) {
      debugPrint('Error saving theme mode: $e');
    });
  }

  Future<void> setPrimaryColor(Color color) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _primaryColor = color;
    _secondaryColor = _generateSecondaryColor(color);
    notifyListeners();

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({'theme_color': color.value}, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error saving theme color: $e');
      _primaryColor = AppColors.primary;
      _secondaryColor = AppColors.secondary;
      notifyListeners();
      rethrow;
    }
  }

  Color _generateSecondaryColor(Color primary) {
    return Color.fromRGBO(
      (primary.red * 0.7).round().clamp(0, 255),
      (primary.green * 0.7).round().clamp(0, 255),
      (primary.blue * 0.7).round().clamp(0, 255),
      1.0,
    );
  }

  void resetToDefault() {
    _primaryColor = AppColors.primary;
    _secondaryColor = AppColors.secondary;
    notifyListeners();
  }

  static bool _isValidMode(String mode) {
    return mode == 'light' || mode == 'dark' || mode == 'system';
  }
}
