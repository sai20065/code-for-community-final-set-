import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const kAppLocaleKey = 'app_locale';

/// Backed by `shared_preferences` (Phase 2, Section 8) so splash routing can
/// tell "language chosen" from "not chosen" before any network call
/// resolves, and so the choice survives app restarts.
class SelectedLanguageNotifier extends StateNotifier<String?> {
  SelectedLanguageNotifier() : super(null) {
    _load();
  }

  final Completer<void> _readyCompleter = Completer<void>();

  /// Resolves once the persisted value has been read, so callers (like
  /// splash routing) never act on the initial `null` before the disk read
  /// completes.
  Future<void> get ready => _readyCompleter.future;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString(kAppLocaleKey);
    if (!_readyCompleter.isCompleted) _readyCompleter.complete();
  }

  Future<void> select(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kAppLocaleKey, languageCode);
    state = languageCode;
  }
}

final selectedLanguageProvider =
    StateNotifierProvider<SelectedLanguageNotifier, String?>(
  (ref) => SelectedLanguageNotifier(),
);
