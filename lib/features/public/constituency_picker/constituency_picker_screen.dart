import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers/public_data_providers.dart';
import '../../../app/theme.dart';
import '../../../l10n/app_localizations.dart';

/// Lets a visitor with no account pick which constituency's public
/// dashboard to look at.
///
/// The signed-out entry point into the whole public surface: reached from
/// the Welcome screen's "Explore your area" action, or automatically
/// whenever a public screen has no constituency to show.
class ConstituencyPickerScreen extends ConsumerStatefulWidget {
  const ConstituencyPickerScreen({super.key});

  @override
  ConsumerState<ConstituencyPickerScreen> createState() =>
      _ConstituencyPickerScreenState();
}

class _ConstituencyPickerScreenState
    extends ConsumerState<ConstituencyPickerScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final constituenciesAsync = ref.watch(allConstituenciesProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go('/welcome'),
        ),
        title: Text(l10n.chooseConstituency),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                autofocus: false,
                decoration: InputDecoration(
                  hintText: l10n.searchConstituency,
                  prefixIcon: const Icon(Icons.search_rounded),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                  ),
                ),
                onChanged: (value) => setState(() => _query = value.trim()),
              ),
            ),
            Expanded(
              child: constituenciesAsync.when(
                data: (all) {
                  final filtered = _query.isEmpty
                      ? all
                      : all
                          .where((c) => c.name
                              .toLowerCase()
                              .contains(_query.toLowerCase()))
                          .toList();
                  if (filtered.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(l10n.noConstituenciesFound,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.inkFaint)),
                      ),
                    );
                  }
                  return ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final c = filtered[index];
                      return ListTile(
                        title: Text(c.name),
                        subtitle: Text(
                          c.mpName == null || c.mpName!.isEmpty
                              ? c.state
                              : '${c.state} · ${c.mpName}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () async {
                          await ref
                              .read(publicConstituencyProvider.notifier)
                              .select(c.id);
                          if (context.mounted) context.go('/public/dashboard');
                        },
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(l10n.somethingWentWrong,
                        textAlign: TextAlign.center),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
