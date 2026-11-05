import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/constituency_model.dart';
import '../../core/models/user_model.dart';
import '../../core/services/firestore_service.dart';
import 'auth_state_provider.dart';

final firestoreServiceProvider = Provider<FirestoreService>((ref) => FirestoreService());

/// Live `constituencies/{id}` doc — shared by the citizen "your MP" card
/// and the official constituency map (outline + MP identity).
final constituencyProvider =
    StreamProvider.family<ConstituencyModel?, String>((ref, constituencyId) {
  return ref.watch(firestoreServiceProvider).watchConstituency(constituencyId);
});

/// Live `users/{uid}` doc for the signed-in citizen/official. Centralizes
/// what would otherwise be duplicated `getUser()` calls across the compose
/// screens (location autofill), onboarding prefill, and every official
/// screen (which needs the signed-in official's own `constituencyId` to
/// scope their view to just their constituency).
///
/// Watches [authStateProvider] rather than reading `currentUser` once: this
/// provider is first read on Splash/Welcome, *before* sign-in, and a
/// one-time read cached "no user" for the whole session — so a citizen who
/// signed up saw an empty profile (no name, no place) until they restarted
/// the app.
final currentUserProfileProvider = StreamProvider<UserModel?>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return Stream.value(null);
  return ref.watch(firestoreServiceProvider).watchUser(user.uid);
});
