import 'package:flutter/material.dart';

import '../../../core/models/booth_model.dart';

import '../../../app/theme.dart';
import '../booth/booth_detail_sheet.dart';

/// Section 5.2: Google Map with booth markers color-coded green/amber/red by
/// open-issue density. Real GoogleMap wiring needs a Maps API key configured
/// for the platform; this list view (tap-to-open bottom sheet) mirrors the
/// exact interaction — tapping a booth reveals detail (Section 3.8
/// progressive disclosure) — without requiring that key to demo.
class ConstituencyMapScreen extends StatelessWidget {
  const ConstituencyMapScreen({super.key});

  static final _sampleBooths = [
    const BoothModel(
      id: 'b1',
      constituencyId: 'c1',
      name: 'Booth 12 — Gandhi Nagar',
      lat: 28.63,
      lng: 77.22,
      openIssueCount: 18,
    ),
    const BoothModel(
      id: 'b2',
      constituencyId: 'c1',
      name: 'Booth 7 — Lake Road',
      lat: 28.65,
      lng: 77.24,
      openIssueCount: 6,
    ),
    const BoothModel(
      id: 'b3',
      constituencyId: 'c1',
      name: 'Booth 3 — Market Square',
      lat: 28.61,
      lng: 77.20,
      openIssueCount: 2,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Constituency Map')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _sampleBooths.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final booth = _sampleBooths[index];
          final color = switch (booth.densityLevel) {
            'red' => AppColors.coralRed,
            'amber' => AppColors.amberWarning,
            _ => AppColors.leafGreen,
          };
          return Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            child: ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              leading: CircleAvatar(
                backgroundColor: color,
                child: const Icon(Icons.location_on_rounded, color: Colors.white),
              ),
              title: Text(booth.name),
              subtitle: Text('${booth.openIssueCount} open issues'),
              onTap: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => BoothDetailSheet(booth: booth),
              ),
            ),
          );
        },
      ),
    );
  }
}
