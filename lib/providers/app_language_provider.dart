import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Global language codes ────────────────────────────────────────────────────
// 'en' = English   |   'ja' = Japanese
typedef AppLangCode = String;

const kLangEn = 'en';
const kLangJa = 'ja';

// ── Persistence helper ────────────────────────────────────────────────────────
const _kPrefKey = 'app_lang';

Future<String> loadSavedLang() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(_kPrefKey) ?? kLangEn;
}

Future<void> saveLang(String code) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_kPrefKey, code);
}

// ── Provider ──────────────────────────────────────────────────────────────────
// Initialised to 'en'; call setLang via the notifier to change globally.
final appLangProvider = StateNotifierProvider<AppLangNotifier, String>((ref) {
  return AppLangNotifier();
});

class AppLangNotifier extends StateNotifier<String> {
  AppLangNotifier() : super(kLangEn) {
    _restore();
  }

  Future<void> _restore() async {
    final saved = await loadSavedLang();
    if (saved != state) state = saved;
  }

  Future<void> setLang(String code) async {
    if (state == code) return;
    state = code;
    await saveLang(code);
  }
}