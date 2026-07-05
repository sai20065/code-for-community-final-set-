import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../app/providers/onboarding_progress_provider.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/location_service.dart';
import '../../../shared/widgets/onboarding_progress_stepper.dart';
import '../../../shared/widgets/primary_button.dart';

/// Step 3 of 4, built as a 2-page `PageView` sharing one stepper position
/// (Phase 2, Section 7): sub-step A pincode entry, sub-step B confirm on
/// map with a draggable pin.
class LocationSetupScreen extends ConsumerStatefulWidget {
  const LocationSetupScreen({super.key});

  @override
  ConsumerState<LocationSetupScreen> createState() =>
      _LocationSetupScreenState();
}

class _LocationSetupScreenState extends ConsumerState<LocationSetupScreen> {
  final _pageController = PageController();
  final _pincodeController = TextEditingController();
  final _addressController = TextEditingController();
  final _locationService = const LocationService();
  final _firestoreService = FirestoreService();
  final _authService = AuthService();

  String? _resolvedArea;
  bool _resolving = false;
  bool _saving = false;
  LatLng? _pin;
  GoogleMapController? _mapController;
  bool _helperVisible = true;

  bool get _pincodeValid => _locationService.isValidPincode(_pincodeController.text.trim());

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

  Future<void> _goToMap() async {
    if (!_pincodeValid) return;
    final centroid = await _locationService.resolveCentroid(
      _pincodeController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _pin = LatLng(centroid.$1, centroid.$2));
    _pageController.animateToPage(
      1,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _confirmLocation() async {
    final uid = _authService.currentUser?.uid;
    if (uid == null || _pin == null) return;

    setState(() => _saving = true);
    final existing = await _firestoreService.getUser(uid);
    final updated = (existing ??
            (throw StateError('User document missing after OTP verify')))
        .copyWith(
      pincodeHome: _pincodeController.text.trim(),
      addressHome: _addressController.text.trim(),
      lat: _pin!.latitude,
      lng: _pin!.longitude,
    );
    await _firestoreService.upsertUser(updated);
    // TODO: call resolveConstituency Cloud Function once scaffolded — don't
    // block navigation on it (Phase 2, Section 7).
    await ref
        .read(onboardingProgressProvider.notifier)
        .advanceTo(OnboardingStep.done);
    if (mounted) context.go('/home');
  }

  @override
  void dispose() {
    _pageController.dispose();
    _pincodeController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            const OnboardingProgressStepper(currentStep: 3),
            const SizedBox(height: 12),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _pincodeStep(),
                  _mapStep(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pincodeStep() {
    return Padding(
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
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: Colors.green, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    _resolvedArea!,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          TextField(
            controller: _addressController,
            decoration: const InputDecoration(
              hintText: 'Your address (street, area)',
            ),
          ),
          const Spacer(),
          PrimaryButton(
            label: 'Next',
            icon: Icons.arrow_forward_rounded,
            onPressed: _pincodeValid ? _goToMap : null,
          ),
        ],
      ),
    );
  }

  Widget _mapStep() {
    if (_pin == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(target: _pin!, zoom: 15),
          onMapCreated: (controller) => _mapController = controller,
          markers: {
            Marker(
              markerId: const MarkerId('home'),
              position: _pin!,
              draggable: true,
              onDragEnd: (newPosition) => setState(() => _pin = newPosition),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueOrange,
              ),
            ),
          },
        ),
        if (_helperVisible)
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: GestureDetector(
              onTap: () => setState(() => _helperVisible = false),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Drag the pin to your exact location',
                  style: TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        Positioned(
          left: 24,
          right: 24,
          bottom: 24,
          child: PrimaryButton(
            label: 'Confirm Location',
            icon: Icons.check_circle_rounded,
            loading: _saving,
            onPressed: _confirmLocation,
          ),
        ),
      ],
    );
  }
}
