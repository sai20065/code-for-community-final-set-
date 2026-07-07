import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/providers/current_user_profile_provider.dart';
import '../../../app/theme.dart';
import '../../../core/models/booth_model.dart';
import '../../../l10n/app_localizations.dart';
import '../booth/booth_detail_sheet.dart';

/// Booth-level demand map: dot size = submission volume, dot color = density
/// band (red = hotspot / amber = moderate / green = mostly resolved, from
/// `BoothModel.densityLevel`, i.e. `openIssueCount`) rather than theme, so
/// the map answers "where does this MP need to look first" at a glance.
/// Every official only ever sees their OWN constituency here, scoped via
/// `currentUserProfileProvider`. Tapping a booth highlights it and opens a
/// callout panel (submission count, dominant theme, local context) via the
/// shared `BoothDetailSheet`.
Color _densityColor(String level) {
  switch (level) {
    case 'red':
      return AppColors.vermilion;
    case 'amber':
      return AppColors.saffron;
    default:
      return AppColors.teal;
  }
}
class ConstituencyMapScreen extends ConsumerWidget {
  const ConstituencyMapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);

    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.boothDemandMap)),
      body: profileAsync.when(
        data: (profile) {
          final constituencyId = profile?.constituencyId;
          if (constituencyId == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.notLinkedConstituency,
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return _BoothMap(constituencyId: constituencyId);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(child: Text(l10n.couldNotLoadProfile)),
      ),
    );
  }
}

class _BoothMap extends ConsumerStatefulWidget {
  const _BoothMap({required this.constituencyId});

  final String constituencyId;

  @override
  ConsumerState<_BoothMap> createState() => _BoothMapState();
}

class _BoothMapState extends ConsumerState<_BoothMap> {
  String? _selectedBoothId;

  @override
  Widget build(BuildContext context) {
    final boothsAsync = ref.watch(_boothsProvider(widget.constituencyId));

    return boothsAsync.when(
      data: (booths) {
        if (booths.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                AppLocalizations.of(context).noBoothData,
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
                    final color = _densityColor(booth.densityLevel);
                    final selected = booth.id == _selectedBoothId;
                    final size = 18.0 + (booth.submissionVolume / maxVolume) * 26.0;
                    return Marker(
                      point: LatLng(booth.lat, booth.lng),
                      width: size + 8,
                      height: size + 8,
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _selectedBoothId = booth.id);
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            builder: (_) => BoothDetailSheet(booth: booth),
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.85),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selected ? AppColors.indigo : Colors.white,
                              width: selected ? 3 : 2,
                            ),
                            boxShadow: appCardShadow,
                          ),
                          alignment: Alignment.center,
                          child: selected
                              ? Text(
                                  '${booth.openIssueCount}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                )
                              : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            const Positioned(
              left: 16,
              bottom: 16,
              child: _Legend(),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Center(child: Text(AppLocalizations.of(context).couldNotLoadBooths)),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      constraints: const BoxConstraints(maxWidth: 220),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        boxShadow: appCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.openIssueDensity,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.inkFaint)),
          const SizedBox(height: 6),
          _LegendRow(color: AppColors.vermilion, label: l10n.densityHigh),
          _LegendRow(color: AppColors.saffron, label: l10n.densityModerate),
          _LegendRow(color: AppColors.teal, label: l10n.densityLow),
          const SizedBox(height: 6),
          Text(
            l10n.dotSizeVolume,
            style: const TextStyle(fontSize: 9.5, color: AppColors.inkFaint, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 11)),
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
