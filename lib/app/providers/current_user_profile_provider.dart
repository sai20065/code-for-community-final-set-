import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/constituency_model.dart';
import '../../core/models/user_model.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';

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
final currentUserProfileProvider = StreamProvider<UserModel?>((ref) {
  final uid = AuthService().currentUser?.uid;
  if (uid == null) return Stream.value(null);
  return ref.watch(firestoreServiceProvider).watchUser(uid);
});
