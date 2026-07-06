import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/providers/current_user_profile_provider.dart';
import '../../../app/theme.dart';
import '../../../core/models/booth_model.dart';
import '../../../shared/widgets/theme_icon_chip.dart';
import '../booth/booth_detail_sheet.dart';

const _kLegendThemes = ['education', 'roads', 'water', 'skilling'];

/// Booth-level demand map: dot size = submission volume, dot color =
/// dominant theme category (the 4 legend colors). Every official only ever
/// sees their OWN constituency here, scoped via `currentUserProfileProvider`.
/// Tapping a booth opens a callout panel (submission count, dominant theme,
/// local context) via the shared `BoothDetailSheet`.
class ConstituencyMapScreen extends ConsumerWidget {
  const ConstituencyMapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Booth-Level Demand Map')),
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
        final maxVolume = booths
            .map((b) => b.submissionVolume)
            .fold<int>(1, (a, b) => b > a ? b : a);
        return Stack(
          children: [
            FlutterMap(
              options: MapOptions(initialCenter: center, initialZoom: 12),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.prajadhvani.app',
                ),
                MarkerLayer(
                  markers: booths.map((booth) {
                    final color = categoryColor(booth.dominantTheme ?? 'roads');
                    final size = 18.0 + (booth.submissionVolume / maxVolume) * 26.0;
                    return Marker(
                      point: LatLng(booth.lat, booth.lng),
                      width: size + 8,
                      height: size + 8,
                      child: GestureDetector(
                        onTap: () => showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          builder: (_) => BoothDetailSheet(booth: booth),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.85),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: appCardShadow,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            Positioned(
              left: 16,
              bottom: 16,
              child: _Legend(),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Could not load booths.')),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        boxShadow: appCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Dominant theme',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.inkFaint)),
          const SizedBox(height: 6),
          for (final id in _kLegendThemes)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: categoryColor(id), shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Text(kThemeLabels[id] ?? id, style: const TextStyle(fontSize: 11)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

final _boothsProvider =
    StreamProvider.family<List<BoothModel>, String>((ref, constituencyId) {
  return ref
      .watch(firestoreServiceProvider)
      .watchBoothsForConstituency(constituencyId);
});
