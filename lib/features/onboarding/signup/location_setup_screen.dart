import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/providers/onboarding_progress_provider.dart';
import '../../../app/theme.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/location_service.dart';
import '../../../shared/widgets/onboarding_progress_stepper.dart';
import '../../../shared/widgets/primary_button.dart';

/// Step 3 of 4, built as a 2-page `PageView` sharing one stepper position:
/// sub-step A pincode entry (prefilled from Aadhaar OCR if available), sub-
/// step B confirm on an OpenStreetMap view — tap anywhere to drop the pin
/// (flutter_map has no built-in drag-marker gesture, so tap-to-move is used
/// instead of drag).
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
  final _locationService = LocationService();
  final _firestoreService = FirestoreService();
  final _authService = AuthService();

  String? _resolvedArea;
  bool _resolving = false;
  bool _saving = false;
  LatLng? _pin;
  bool _helperVisible = true;
  HomeBoothMatch? _boothMatch;

  bool get _pincodeValid =>
      _locationService.isValidPincode(_pincodeController.text.trim());

  @override
  void initState() {
    super.initState();
    _prefillFromProfile();
  }

  Future<void> _prefillFromProfile() async {
    final uid = _authService.currentUser?.uid;
    if (uid == null) return;
    final existing = await _firestoreService.getUser(uid);
    if (!mounted || existing == null) return;
    if (existing.pincodeHome != null) {
      _pincodeController.text = existing.pincodeHome!;
      _onPincodeChanged(existing.pincodeHome!);
    }
    if (existing.addressHome != null) {
      _addressController.text = existing.addressHome!;
    }
  }

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
    final pincode = _pincodeController.text.trim();
    final results = await Future.wait([
      _locationService.resolveCentroid(pincode),
      _locationService.resolveHomeBooth(pincode),
    ]);
    if (!mounted) return;
    final centroid = results[0] as (double, double);
    final boothMatch = results[1] as HomeBoothMatch?;
    setState(() {
      _pin = LatLng(centroid.$1, centroid.$2);
      _boothMatch = boothMatch;
    });
    _pageController.animateToPage(
      1,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _thisIsntMe() {
    _pageController.animateToPage(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _confirmLocation() async {
    final uid = _authService.currentUser?.uid;
    if (uid == null || _pin == null) return;

    setState(() => _saving = true);
    final pincode = _pincodeController.text.trim();
    final match = _boothMatch ?? await _locationService.resolveHomeBooth(pincode);

    final existing = await _firestoreService.getUser(uid);
    final updated = (existing ??
            (throw StateError('User document missing after sign-in')))
        .copyWith(
      pincodeHome: pincode,
      addressHome: _addressController.text.trim(),
      lat: _pin!.latitude,
      lng: _pin!.longitude,
      constituencyId: match?.constituencyId,
      homeBoothId: match?.boothId,
      homeBoothName: match?.boothName,
    );
    await _firestoreService.upsertUser(updated);
    await ref
        .read(onboardingProgressProvider.notifier)
        .advanceTo(OnboardingStep.done);
    if (mounted) context.go('/signup/done');
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
        FlutterMap(
          options: MapOptions(
            initialCenter: _pin!,
            initialZoom: 15,
            onTap: (tapPosition, point) => setState(() => _pin = point),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.prajadhvani.app',
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: _pin!,
                  width: 40,
                  height: 40,
                  child: const Icon(Icons.location_on_rounded,
                      color: Colors.deepOrange, size: 40),
                ),
              ],
            ),
          ],
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
                  'Tap anywhere on the map to move the pin to your exact location',
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  boxShadow: appCardShadow,
                ),
                child: Text(
                  _boothMatch == null
                      ? 'Home constituency and booth will be confirmed once matched to your area.'
                      : 'Home constituency: ${_boothMatch!.constituencyId ?? "—"} · '
                          'Home booth: ${_boothMatch!.boothName ?? _boothMatch!.boothId}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
                ),
              ),
              const SizedBox(height: 10),
              PrimaryButton(
                label: 'Looks right',
                icon: Icons.check_circle_rounded,
                loading: _saving,
                onPressed: _confirmLocation,
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: _saving ? null : _thisIsntMe,
                child: const Text("This isn't me"),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
