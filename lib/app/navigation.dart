import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/models/user_model.dart';
import 'providers/current_user_profile_provider.dart';

/// The screen a signed-in person calls "home". Officials and admins must never
/// be sent to the citizen home, whatever screen they came from.
String homeRouteFor(UserModel? user) {
  if (user?.role == UserRole.admin) return '/admin';
  if (user?.role == UserRole.official) {
    return user?.officialType == 'fieldWorker' ? '/worker/tasks' : '/gov/dashboard';
  }
  return '/home';
}

/// Back button for screens shared by citizens and officials: go back when
/// there is somewhere to go, otherwise to the viewer's own home.
void goBackOrHome(BuildContext context, {String? citizenFallback}) {
  if (context.canPop()) {
    context.pop();
    return;
  }
  final user = ProviderScope.containerOf(context, listen: false)
      .read(currentUserProfileProvider)
      .valueOrNull;
  final home = homeRouteFor(user);
  context.go(home == '/home' && citizenFallback != null ? citizenFallback : home);
}
