import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/providers/current_user_profile_provider.dart';
import '../../../app/theme.dart';
import '../../../core/models/booth_model.dart';
import '../booth/booth_detail_sheet.dart';

/// Every official only ever sees their OWN constituency here — booths are
/// scoped via the signed-in official's own `constituencyId`
/// (`currentUserProfileProvider`), never a global list. Markers are
/// color-coded green/amber/red by `booth.densityLevel` exactly as before;
/// only the rendering surface changed from Google Maps to a free
/// OpenStreetMap tile layer.
class ConstituencyMapScreen extends ConsumerWidget {
  const ConstituencyMapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Constituency Map')),
      body: profileAsync.when(
        data: (profile) {
          final constituencyId = profile?.constituencyId;
          if (constituencyId == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Your account isn\'t linked to a constituency yet.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return _BoothMap(constituencyId: constituencyId);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Could not load your profile.')),
      ),
    );
  }
}

class _BoothMap extends ConsumerWidget {
  const _BoothMap({required this.constituencyId});

  final String constituencyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boothsAsync = ref.watch(_boothsProvider(constituencyId));

    return boothsAsync.when(
      data: (booths) {
        if (booths.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No booth reference data for this constituency yet.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        final center = LatLng(booths.first.lat, booths.first.lng);
        return FlutterMap(
          options: MapOptions(initialCenter: center, initialZoom: 12),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.prajadhvani.app',
            ),
            MarkerLayer(
              markers: booths.map((booth) {
                final color = switch (booth.densityLevel) {
                  'red' => AppColors.coralRed,
                  'amber' => AppColors.amberWarning,
                  _ => AppColors.leafGreen,
                };
                return Marker(
                  point: LatLng(booth.lat, booth.lng),
                  width: 44,
                  height: 44,
                  child: GestureDetector(
                    onTap: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => BoothDetailSheet(booth: booth),
                    ),
                    child: Icon(Icons.location_on_rounded, color: color, size: 40),
                  ),
                );
              }).toList(),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Could not load booths.')),
    );
  }
}

final _boothsProvider =
    StreamProvider.family<List<BoothModel>, String>((ref, constituencyId) {
  return ref
      .watch(firestoreServiceProvider)
      .watchBoothsForConstituency(constituencyId);
});
