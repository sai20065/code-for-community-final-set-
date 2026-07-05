import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/auth_service.dart';

/// Section 4, screen 11: language switch, edit address, logout.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.language_rounded),
            title: const Text('Language'),
            onTap: () => context.go('/language'),
          ),
          const ListTile(
            leading: Icon(Icons.location_on_rounded),
            title: Text('Edit address'),
          ),
          ListTile(
            leading: const Icon(Icons.logout_rounded),
            title: const Text('Logout'),
            onTap: () async {
              await authService.signOut();
              if (context.mounted) context.go('/language');
            },
          ),
        ],
      ),
    );
  }
}
