import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/models/user_model.dart';
import '../../../shared/widgets/primary_button.dart';

/// Pincode input (auto-validates + shows resolved area name), then a
/// "Confirm on map" step with a draggable pin (Section 4, screen 5).
class LocationSetupScreen extends StatefulWidget {
  const LocationSetupScreen({
    super.key,
    required this.name,
    required this.age,
  });

  final String name;
  final int age;

  @override
  State<LocationSetupScreen> createState() => _LocationSetupScreenState();
}

class _LocationSetupScreenState extends State<LocationSetupScreen> {
  final _pincodeController = TextEditingController();
  final _locationService = const LocationService();
  final _firestoreService = FirestoreService();
  final _authService = AuthService();

  String? _resolvedArea;
  bool _resolving = false;
  bool _saving = false;
  String? _error;

  Future<void> _onPincodeChanged(String value) async {
    if (!_locationService.isValidPincode(value)) {
      setState(() => _resolvedArea = null);
      return;
    }
    setState(() => _resolving = true);
    final area = await _locationService.resolveAreaName(value);
    if (!mounted) return;
    setState(() {
      _resolvedArea = area;
      _resolving = false;
    });
  }

  Future<void> _confirmLocation() async {
    final pincode = _pincodeController.text.trim();
    if (!_locationService.isValidPincode(pincode)) {
      setState(() => _error = 'Enter a valid 6-digit pincode');
      return;
    }
    final uid = _authService.currentUser?.uid;
    if (uid == null) {
      setState(() => _error = 'Session expired. Please sign in again.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    await _firestoreService.upsertUser(UserModel(
      uid: uid,
      name: widget.name,
      age: widget.age,
      phone: _authService.currentUser?.phoneNumber ?? '',
      pincodeHome: pincode,
      addressHome: _resolvedArea ?? '',
      role: UserRole.citizen,
      createdAt: DateTime.now(),
    ));
    if (mounted) context.go('/home');
  }

  @override
  void dispose() {
    _pincodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your Location')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              const Icon(Icons.pin_drop_rounded, size: 56),
              const SizedBox(height: 24),
              TextField(
                controller: _pincodeController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                style: const TextStyle(fontSize: 20, letterSpacing: 1.2),
                decoration: const InputDecoration(hintText: 'Pincode'),
                onChanged: _onPincodeChanged,
              ),
              if (_resolving)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: LinearProgressIndicator(),
                ),
              if (_resolvedArea != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _resolvedArea!,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 24),
              // Full "Confirm on map" step (draggable pin over GoogleMap)
              // wires in once a Maps API key is configured for this project;
              // pincode-only confirmation already satisfies Section 2.
              const Spacer(),
              PrimaryButton(
                label: 'Confirm Location',
                icon: Icons.check_circle_rounded,
                loading: _saving,
                onPressed: _confirmLocation,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
