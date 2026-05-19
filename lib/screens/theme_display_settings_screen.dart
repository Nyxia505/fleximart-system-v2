import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../providers/theme_provider.dart';

/// Theme & Display settings — same flow as other profile preference screens.
class ThemeDisplaySettingsScreen extends StatefulWidget {
  const ThemeDisplaySettingsScreen({super.key});

  @override
  State<ThemeDisplaySettingsScreen> createState() =>
      _ThemeDisplaySettingsScreenState();
}

class _ThemeDisplaySettingsScreenState extends State<ThemeDisplaySettingsScreen> {
  final user = FirebaseAuth.instance.currentUser;
  String _themeMode = 'system';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .get();
    final data = doc.data() ?? {};

    if (mounted) {
      setState(() {
        _themeMode = data['theme_mode'] as String? ?? 'system';
      });
    }
  }

  Future<void> _updateSetting(String key, dynamic value) async {
    if (user == null) return;
    try {
      final docRef =
          FirebaseFirestore.instance.collection('users').doc(user!.uid);
      final docSnapshot = await docRef.get();

      if (docSnapshot.exists) {
        await docRef.update({key: value});
      } else {
        await docRef.set({key: value}, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('Error saving theme setting $key: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save setting: ${e.toString()}'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      rethrow;
    }
  }

  void _onThemeModeSelected(String value) {
    setState(() => _themeMode = value);
    _updateSetting('theme_mode', value);
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    themeProvider.setThemeMode(value);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Theme mode updated!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Theme & Display'),
        backgroundColor: AppColors.secondary,
        foregroundColor: AppColors.white,
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Customize the appearance and display settings',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              'Theme',
              style: AppTextStyles.heading3(color: AppColors.textPrimary),
            ),
          ),
          ListTile(
            title: const Text('Theme Mode'),
            subtitle: Text(_getThemeModeDescription(_themeMode)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              showDialog(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('Select Theme Mode'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RadioListTile<String>(
                        title: const Text('Light'),
                        subtitle: const Text('Always use light theme'),
                        value: 'light',
                        groupValue: _themeMode,
                        activeColor: AppColors.primary,
                        onChanged: (value) {
                          if (value != null) {
                            _onThemeModeSelected(value);
                          }
                        },
                      ),
                      RadioListTile<String>(
                        title: const Text('Dark'),
                        subtitle: const Text('Always use dark theme'),
                        value: 'dark',
                        groupValue: _themeMode,
                        activeColor: AppColors.primary,
                        onChanged: (value) {
                          if (value != null) {
                            _onThemeModeSelected(value);
                          }
                        },
                      ),
                      RadioListTile<String>(
                        title: const Text('System'),
                        subtitle: const Text('Follow system theme'),
                        value: 'system',
                        groupValue: _themeMode,
                        activeColor: AppColors.primary,
                        onChanged: (value) {
                          if (value != null) {
                            _onThemeModeSelected(value);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  String _getThemeModeDescription(String mode) {
    switch (mode) {
      case 'light':
        return 'Always use light theme';
      case 'dark':
        return 'Always use dark theme';
      case 'system':
      default:
        return 'Follow system theme';
    }
  }
}
