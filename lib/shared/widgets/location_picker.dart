import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../app/theme.dart';
import '../../core/services/location_service.dart';

enum LocationPickMode { current, home, pin }

/// The submit-flow location control: "At my current location" (live GPS) /
/// "At my home" / "Drop a pin" pills, plus (for the pin mode) a small
/// tap-to-move map preview. Used by all three compose screens (text, voice,
/// photo) so the "which lat/lng gets attached to this ticket" logic lives
/// in one place instead of being re-implemented per input mode.
///
/// This only ever changes the ticket's plotted lat/lng — the citizen's
/// `pincode`/`constituencyId` (and therefore which MP it's routed to)
/// always stays their own home area, per the security rules' own-area
/// enforcement (Firestore `submissions` create rule). The caption below the
/// pills reflects that honestly rather than implying the pin changes
/// jurisdiction.
class LocationPicker extends StatefulWidget {
  const LocationPicker({
    super.key,
    required this.homeLat,
    required this.homeLng,
    required this.onChanged,
  });

  final double? homeLat;
  final double? homeLng;
  final ValueChanged<LatLng?> onChanged;

  @override
  State<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> {
  final _locationService = LocationService();
  LocationPickMode _mode = LocationPickMode.current;
  LatLng? _pin;
  bool _locating = false;
  String? _note;

  LatLng? get _homeLatLng => widget.homeLat != null && widget.homeLng != null
      ? LatLng(widget.homeLat!, widget.homeLng!)
      : null;

  @override
  void initState() {
    super.initState();
    _useCurrentLocation();
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _mode = LocationPickMode.current;
      _locating = true;
      _note = null;
    });
    final fix = await _locationService.getCurrentLatLng();
    if (!mounted) return;
    if (fix == null) {
      setState(() {
        _mode = LocationPickMode.home;
        _locating = false;
        _note = _homeLatLng == null
            ? "Couldn't get your location — pick a spot on the map instead."
            : "Couldn't get your location — using your home address instead.";
      });
      widget.onChanged(_homeLatLng);
      return;
    }
    final point = LatLng(fix.$1, fix.$2);
    setState(() {
      _pin = point;
      _locating = false;
    });
    widget.onChanged(point);
  }

  void _useHome() {
    setState(() {
      _mode = LocationPickMode.home;
      _note = null;
    });
    widget.onChanged(_homeLatLng);
  }

  void _useDropPin() {
    setState(() {
      _mode = LocationPickMode.pin;
      _note = null;
      _pin ??= _homeLatLng ?? const LatLng(28.6139, 77.2090);
    });
    widget.onChanged(_pin);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _Pill(
                icon: Icons.my_location_rounded,
                label: 'Current location',
                selected: _mode == LocationPickMode.current,
                loading: _locating && _mode == LocationPickMode.current,
                onTap: _useCurrentLocation,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _Pill(
                icon: Icons.home_rounded,
                label: 'At my home',
                selected: _mode == LocationPickMode.home,
                onTap: _useHome,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _Pill(
                icon: Icons.pin_drop_rounded,
                label: 'Drop a pin',
                selected: _mode == LocationPickMode.pin,
                onTap: _useDropPin,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _note ?? 'Routed to your home MP · pin only sets where this shows on the map.',
          style: TextStyle(fontSize: 11, color: AppColors.inkFaint),
        ),
        if (_mode == LocationPickMode.pin) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 160,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.md),
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: _pin ?? _homeLatLng ?? const LatLng(28.6139, 77.2090),
                  initialZoom: 15,
                  onTap: (tapPos, point) {
                    setState(() => _pin = point);
                    widget.onChanged(point);
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.prajadhvani.app',
                  ),
                  if (_pin != null)
                    MarkerLayer(markers: [
                      Marker(
                        point: _pin!,
                        width: 34,
                        height: 34,
                        child: const Icon(Icons.location_on_rounded,
                            color: AppColors.vermilion, size: 34),
                      ),
                    ]),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.loading = false,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.saffronMist : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppColors.saffronDeep : Colors.grey.shade200),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              const SizedBox(
                width: 13,
                height: 13,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(icon, size: 15, color: selected ? AppColors.saffronDeep : AppColors.inkFaint),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: selected ? AppColors.saffronDeep : AppColors.inkSoft,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
