import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/providers/selected_language_provider.dart';
import 'app/router.dart';
import 'app/theme.dart';
import 'firebase_options.dart';
import 'l10n/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ProviderScope(child: PrajaDhvaniApp()));
}

class PrajaDhvaniApp extends ConsumerWidget {
  const PrajaDhvaniApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The whole app re-renders in the citizen's chosen language the moment
    // they pick one (persisted via `selectedLanguageProvider`); until then it
    // defaults to the device/`en` locale. This is what makes "change language
    // → everything changes" work app-wide, not just on one screen.
    final languageCode = ref.watch(selectedLanguageProvider);
    return MaterialApp.router(
      title: 'Prajadhwani',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.citizen,
      routerConfig: appRouter,
      locale: languageCode != null ? Locale(languageCode) : null,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}
