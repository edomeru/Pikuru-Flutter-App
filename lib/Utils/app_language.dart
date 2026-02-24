import 'package:flutter/material.dart';

/// Global language state — persists across navigation without any package.
/// Import this wherever you need to read or change the current language.
class AppLanguage {
  AppLanguage._();

  // ✅ Single source of truth for selected language code
  static final ValueNotifier<String> current = ValueNotifier('en');

  static const List<LanguageOption> options = [
    LanguageOption(code: 'en', name: 'English', nativeName: 'English', flag: '🇺🇸'),
    LanguageOption(code: 'ja', name: 'Japanese', nativeName: '日本語', flag: '🇯🇵'),
  ];

  static LanguageOption get selected =>
      options.firstWhere((l) => l.code == current.value);

  static String get selectedLabel => selected.nativeName;
}

class LanguageOption {
  final String code;
  final String name;
  final String nativeName;
  final String flag;

  const LanguageOption({
    required this.code,
    required this.name,
    required this.nativeName,
    required this.flag,
  });
}