import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

/// EmailJS + optional Gmail SMTP. Loaded from assets → local storage → Firestore.
class EmailJsConfig {
  EmailJsConfig._();

  static const String _prefsTemplateKey = 'emailjs_template_id';
  static const String _prefsSmtpPassKey = 'emailjs_smtp_pass';

  static const String defaultServiceId = 'service_1dhvvdp';
  static const String defaultPublicKey = 'TMXZA9w62NrPr-zjY';
  static const String defaultPrivateKey = 'mgsii9qp4xF4Fphe19cj_';
  static const String defaultTemplateId = 'template_ac0np7l';

  static String serviceId = defaultServiceId;
  static String publicKey = defaultPublicKey;
  static String? privateKey = defaultPrivateKey;
  static String templateId = defaultTemplateId;
  static List<String> templateIds = [];
  static String? smtpUser = 'queenyvonnedalahay@gmail.com';
  static String? smtpPass;

  static bool _loaded = false;

  static List<String> get allTemplateIds {
    final ids = <String>{};
    if (templateId.trim().isNotEmpty) ids.add(templateId.trim());
    ids.addAll(templateIds.map((e) => e.trim()).where((e) => e.isNotEmpty));
    return ids.toList();
  }

  static bool get canUseEmailJs => allTemplateIds.isNotEmpty;

  static bool get hasSmtp =>
      (smtpUser?.isNotEmpty ?? false) && (smtpPass?.isNotEmpty ?? false);

  static bool get hasExplicitTemplate =>
      templateId.trim().isNotEmpty || templateIds.isNotEmpty;

  static Future<void> ensureLoaded() async {
    if (_loaded) return;
    await _loadAllSources();
    _loaded = true;
  }

  /// Reload only SMTP fields (e.g. after Firestore admin updates smtpPass).
  static Future<void> reloadSmtpFromFirestore() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('emailjs')
          .get();
      if (doc.exists) {
        final data = doc.data() ?? {};
        final user = data['smtpUser'] as String?;
        final pass = data['smtpPass'] as String?;
        if (user != null && user.trim().isNotEmpty) smtpUser = user.trim();
        if (pass != null && pass.trim().isNotEmpty) smtpPass = pass.trim();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ reloadSmtpFromFirestore: $e');
    }
  }

  static void _loadFromDartDefine() {
    const envPass = String.fromEnvironment('SMTP_PASS');
    if (envPass.trim().isNotEmpty) {
      smtpPass = envPass.replaceAll(' ', '');
      if (kDebugMode) debugPrint('📧 Loaded SMTP_PASS from --dart-define');
    }
  }

  static Future<void> _loadAllSources() async {
    await _loadFromAssets();
    await _loadFromLocalPrefs();

    try {
      final doc = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('emailjs')
          .get();
      if (doc.exists) {
        _applyMap(doc.data() ?? {}, preserveSmtpIfEmpty: true);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Could not load app_config/emailjs: $e');
      }
    }

    // Secrets + dart-define last so SMTP is never wiped by empty Firestore fields.
    await _loadFromSecretsAsset();
    _loadFromDartDefine();

    if (hasSmtp) {
      await saveLocal(smtpPass: smtpPass);
    }

    if (kDebugMode) {
      debugPrint(
        '📧 EmailJS: templateId=${templateId.isEmpty ? "(none)" : templateId}, '
        'smtp=${hasSmtp}, smtpUser=${smtpUser ?? "(none)"}',
      );
    }
  }

  static Future<void> saveLocal({String? templateId, String? smtpPass}) async {
    final prefs = await SharedPreferences.getInstance();
    if (templateId != null && templateId.trim().isNotEmpty) {
      final tid = templateId.trim();
      await prefs.setString(_prefsTemplateKey, tid);
      EmailJsConfig.templateId = tid;
    }
    if (smtpPass != null && smtpPass.trim().isNotEmpty) {
      final pass = smtpPass.trim();
      await prefs.setString(_prefsSmtpPassKey, pass);
      EmailJsConfig.smtpPass = pass;
    }
    _loaded = true;
  }

  static Future<void> _loadFromLocalPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tid = prefs.getString(_prefsTemplateKey);
      if (tid != null && tid.trim().isNotEmpty) {
        templateId = tid.trim();
      }
      final pass = prefs.getString(_prefsSmtpPassKey);
      if (pass != null && pass.trim().isNotEmpty) {
        smtpPass = pass.trim();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Could not load local EmailJS prefs: $e');
      }
    }
  }

  static Future<void> _loadFromAssets() async {
    try {
      final raw = await rootBundle.loadString('assets/config/emailjs.json');
      _applyMap(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Could not load assets/config/emailjs.json: $e');
      }
    }
  }

  /// Local-only credentials (gitignored). See emailjs.secrets.example.json.
  static Future<void> _loadFromSecretsAsset() async {
    const paths = [
      'assets/config/emailjs.secrets.json',
      'config/emailjs.secrets.json',
    ];
    for (final path in paths) {
      try {
        final raw = await rootBundle.loadString(path);
        final cleaned = raw.replaceFirst('\uFEFF', '');
        _applyMap(jsonDecode(cleaned) as Map<String, dynamic>);
        if (kDebugMode && hasSmtp) {
          debugPrint('📧 Loaded SMTP from $path');
        } else if (kDebugMode) {
          debugPrint('⚠️ $path loaded but smtpPass missing');
        }
        return;
      } catch (e) {
        if (kDebugMode) debugPrint('⚠️ Could not load $path: $e');
      }
    }
  }

  static void _applyMap(
    Map<String, dynamic> data, {
    bool preserveSmtpIfEmpty = false,
  }) {
    serviceId = (data['serviceId'] as String?)?.trim() ?? serviceId;
    publicKey = (data['publicKey'] as String?)?.trim() ?? publicKey;
    final pk = data['privateKey'] as String?;
    if (pk != null && pk.trim().isNotEmpty) privateKey = pk.trim();

    final tid = data['templateId'] as String?;
    if (tid != null && tid.trim().isNotEmpty) templateId = tid.trim();

    final list = data['templateIds'];
    if (list is List) {
      templateIds = list
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    final user = data['smtpUser'] as String?;
    if (user != null && user.trim().isNotEmpty) smtpUser = user.trim();
    final pass = data['smtpPass'] as String?;
    if (pass != null && pass.trim().isNotEmpty) {
      smtpPass = pass.trim();
    } else if (!preserveSmtpIfEmpty &&
        pass != null &&
        pass.isEmpty &&
        !hasSmtp) {
      smtpPass = null;
    }
  }

  static void resetForTesting() => _loaded = false;

  /// Call after saving local/Firestore config so the next send uses new values.
  static void invalidateCache() {
    _loaded = false;
  }

  /// Force reload (e.g. before sending OTP on web).
  static Future<void> forceReload() async {
    _loaded = false;
    await ensureLoaded();
  }
}
