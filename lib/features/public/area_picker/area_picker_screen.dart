import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers/public_data_providers.dart';
import '../../../app/theme.dart';
import '../../../core/models/district_model.dart';
import '../../../core/models/taluk_model.dart';
import '../../../core/models/ward_model.dart';

/// The "choose your place" flow: **District → Taluk** everywhere in
/// Karnataka, and **District → BBMP ward** inside Bengaluru Urban, where a
/// taluk covers most of the city and is useless as an area choice.
///
/// Picking a sub-unit does two things: it sets
/// [publicConstituencyProvider] to that unit's parent Lok Sabha constituency
/// (the scope every ticket, cluster and official account is actually keyed
/// on) and it records the unit itself in [selectedAreaProvider], which the
/// map uses to frame the camera and highlight that one polygon.
///
/// Replaces the flat 543-row constituency list as the primary entry point —
/// people know which district and taluk they live in; almost nobody knows
/// their Lok Sabha constituency by name.
class AreaPickerScreen extends ConsumerStatefulWidget {
  const AreaPickerScreen({super.key});

  @override
  ConsumerState<AreaPickerScreen> createState() => _AreaPickerScreenState();
}

/// The district whose wards come from the GBA ward layer instead of taluks.
/// Matched case-insensitively on district name because the KGIS source data
/// spells it "Bengaluru Urban" while older rows use "Bangalore Urban".
bool _isBengaluruUrban(String districtName) {
  final n = districtName.toLowerCase();
  return (n.contains('bengaluru') || n.contains('bangalore')) &&
      n.contains('urban');
}

class _AreaPickerScreenState extends ConsumerState<AreaPickerScreen> {
  String _query = '';
  String? _districtId;
  String _districtName = '';

  bool get _atDistrictLevel => _districtId == null;

  Future<void> _choose({
    required AreaKind kind,
    required String id,
    required String name,
    required String? constituencyId,
  }) async {
    ref.read(selectedAreaProvider.notifier).state = SelectedArea(
      kind: kind,
      id: id,
      name: name,
      districtName: _districtName,
      constituencyId: constituencyId,
    );
    // A sub-unit with no parent constituency (the source data leaves a
    // handful null) still selects fine — the map just falls back to whatever
    // constituency was already in view rather than blanking out.
    if (constituencyId != null && constituencyId.isNotEmpty) {
      await ref.read(publicConstituencyProvider.notifier).select(constituencyId);
    }
    if (mounted) context.go('/public/map');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (!_atDistrictLevel) {
              setState(() {
                _districtId = null;
                _districtName = '';
                _query = '';
              });
              return;
            }
            context.canPop() ? context.pop() : context.go('/welcome');
          },
        ),
        title: Text(_atDistrictLevel ? 'Choose your district' : _districtName),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                key: ValueKey(_districtId ?? 'districts'),
                decoration: InputDecoration(
                  hintText: _atDistrictLevel
                      ? 'Search districts'
                      : 'Search within $_districtName',
                  prefixIcon: const Icon(Icons.search_rounded),
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (v) => setState(() => _query = v.trim()),
              ),
            ),
            _Breadcrumb(
              districtName: _districtName,
              onReset: () => setState(() {
                _districtId = null;
                _districtName = '';
                _query = '';
              }),
            ),
            Expanded(
              child: _atDistrictLevel
                  ? _DistrictList(
                      query: _query,
                      onSelect: (d) => setState(() {
                        _districtId = d.id;
                        _districtName = d.name;
                        _query = '';
                      }),
                    )
                  : _isBengaluruUrban(_districtName)
                      ? _WardList(
                          query: _query,
                          onSelect: (w) => _choose(
                            kind: AreaKind.ward,
                            id: w.id,
                            name: w.wardName,
                            constituencyId: w.constituencyId,
                          ),
                        )
                      : _TalukList(
                          districtId: _districtId!,
                          query: _query,
                          onSelect: (t) => _choose(
                            kind: AreaKind.taluk,
                            id: t.id,
                            name: t.talukName,
                            constituencyId: t.constituencyId,
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Breadcrumb extends StatelessWidget {
  const _Breadcrumb({required this.districtName, required this.onReset});

  final String districtName;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    if (districtName.isEmpty) return const SizedBox(height: 8);
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            InkWell(
              onTap: onReset,
              child: const Text('Karnataka',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.indigo)),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Icon(Icons.chevron_right_rounded,
                  size: 14, color: AppColors.inkFaint),
            ),
            Text(districtName,
                style: const TextStyle(fontSize: 12, color: AppColors.inkSoft)),
          ],
        ),
      ),
    );
  }
}

class _DistrictList extends ConsumerWidget {
  const _DistrictList({required this.query, required this.onSelect});

  final String query;
  final void Function(DistrictModel district) onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(allDistrictsProvider);
    return async.when(
      data: (all) {
        final filtered = query.isEmpty
            ? all
            : all
                .where((d) =>
                    d.name.toLowerCase().contains(query.toLowerCase()))
                .toList();
        if (filtered.isEmpty) {
          return const _Empty(
            message: 'No districts match that search.',
            hint: 'District data is seeded for Karnataka only right now.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final d = filtered[i];
            return _AreaTile(
              icon: Icons.map_outlined,
              tint: AppColors.indigo,
              title: d.name,
              subtitle: _isBengaluruUrban(d.name)
                  ? 'BBMP / GBA wards'
                  : 'Taluks',
              onTap: () => onSelect(d),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const _Empty(
        message: 'Could not load districts.',
        hint: 'Check your connection and try again.',
      ),
    );
  }
}

class _TalukList extends ConsumerWidget {
  const _TalukList({
    required this.districtId,
    required this.query,
    required this.onSelect,
  });

  final String districtId;
  final String query;
  final void Function(TalukModel taluk) onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(taluksForDistrictProvider(districtId));
    return async.when(
      data: (all) {
        final filtered = query.isEmpty
            ? all
            : all
                .where((t) =>
                    t.talukName.toLowerCase().contains(query.toLowerCase()))
                .toList();
        if (filtered.isEmpty) {
          return const _Empty(
            message: 'No taluks here yet.',
            hint: 'Try another district, or search by name.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final t = filtered[i];
            return _AreaTile(
              icon: Icons.location_city_rounded,
              tint: AppColors.teal,
              title: t.talukName,
              subtitle: _representativeLine(
                mlaName: t.mlaName,
                assembly: t.assemblyConstituency,
              ),
              onTap: () => onSelect(t),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const _Empty(
        message: 'Could not load taluks.',
        hint: 'Check your connection and try again.',
      ),
    );
  }
}

class _WardList extends ConsumerWidget {
  const _WardList({required this.query, required this.onSelect});

  final String query;
  final void Function(WardModel ward) onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Wards are keyed by corporation, not district — Bengaluru Urban is the
    // only district with a ward layer at all, so the two are equivalent here.
    final async = ref.watch(wardsForCorporationProvider('GBA'));
    return async.when(
      data: (all) {
        final filtered = query.isEmpty
            ? all
            : all
                .where((w) =>
                    w.wardName.toLowerCase().contains(query.toLowerCase()) ||
                    w.assemblyConstituency
                        .toLowerCase()
                        .contains(query.toLowerCase()))
                .toList();
        if (filtered.isEmpty) {
          return const _Empty(
            message: 'No wards match that search.',
            hint: 'Search by ward name or assembly segment.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final w = filtered[i];
            return _AreaTile(
              icon: Icons.holiday_village_rounded,
              tint: AppColors.saffronDeep,
              title: w.wardName,
              subtitle: _representativeLine(
                mlaName: w.mlaName,
                assembly: w.assemblyConstituency,
              ),
              onTap: () => onSelect(w),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const _Empty(
        message: 'Could not load wards.',
        hint: 'Check your connection and try again.',
      ),
    );
  }
}

/// "MLA · Assembly segment", degrading to just the segment while the MLA
/// roster is unseeded rather than showing a dangling separator.
String _representativeLine({String? mlaName, String? assembly}) {
  final mla = (mlaName ?? '').trim();
  final seat = (assembly ?? '').trim();
  if (mla.isNotEmpty && seat.isNotEmpty) return '$mla · $seat';
  if (mla.isNotEmpty) return mla;
  if (seat.isNotEmpty) return seat;
  return 'Tap to see the map';
}

class _AreaTile extends StatelessWidget {
  const _AreaTile({
    required this.icon,
    required this.tint,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color tint;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.md),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 19, color: tint),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11.5, color: AppColors.inkFaint),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.inkFaint),
            ],
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.message, required this.hint});

  final String message;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.travel_explore_rounded,
                size: 40, color: AppColors.indigoMist),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(hint,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.inkFaint, height: 1.4)),
          ],
        ),
      ),
    );
  }
}
