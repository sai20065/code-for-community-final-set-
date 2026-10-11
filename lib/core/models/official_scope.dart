import 'package:flutter/material.dart';

import 'user_model.dart';

/// Official account types, matching `functions/src/officials/scope.ts`.
enum OfficialType { mp, mla, wardOfficer, tahsildar, districtOfficer }

OfficialType officialTypeFrom(String? raw) => OfficialType.values.firstWhere(
      (t) => t.name == raw,
      orElse: () => OfficialType.mp,
    );

extension OfficialTypeInfo on OfficialType {
  String get label => switch (this) {
        OfficialType.mp => 'Member of Parliament',
        OfficialType.mla => 'Member of Legislative Assembly',
        OfficialType.wardOfficer => 'BBMP Ward Officer',
        OfficialType.tahsildar => 'Tahsildar',
        OfficialType.districtOfficer => 'District Officer',
      };

  String get shortLabel => switch (this) {
        OfficialType.mp => 'MP',
        OfficialType.mla => 'MLA',
        OfficialType.wardOfficer => 'Ward Officer',
        OfficialType.tahsildar => 'Tahsildar',
        OfficialType.districtOfficer => 'District Officer',
      };

  IconData get icon => switch (this) {
        OfficialType.mp => Icons.account_balance_rounded,
        OfficialType.mla => Icons.how_to_vote_rounded,
        OfficialType.wardOfficer => Icons.holiday_village_rounded,
        OfficialType.tahsildar => Icons.location_city_rounded,
        OfficialType.districtOfficer => Icons.map_rounded,
      };

  /// The kind of area this type is responsible for.
  String get jurisdictionType => switch (this) {
        OfficialType.mp => 'constituency',
        OfficialType.mla => 'assembly',
        OfficialType.wardOfficer => 'bbmpWard',
        OfficialType.tahsildar => 'taluk',
        OfficialType.districtOfficer => 'district',
      };

  String get areaNoun => switch (this) {
        OfficialType.mp => 'Lok Sabha constituency',
        OfficialType.mla => 'Assembly constituency',
        OfficialType.wardOfficer => 'BBMP ward',
        OfficialType.tahsildar => 'Taluk',
        OfficialType.districtOfficer => 'District',
      };
}

/// The ticket / cluster field each jurisdiction type is matched on — same
/// as `scopeFieldFor` in firestore.rules.
const kScopeFieldFor = {
  'constituency': 'constituencyId',
  'assembly': 'assemblyId',
  'bbmpWard': 'bbmpWardId',
  'taluk': 'talukId',
  'district': 'districtId',
};

/// The slice of data an official works with: `publicTickets` /
/// `publicClusters` where [field] == [id].
@immutable
class OfficialScope {
  const OfficialScope({
    required this.type,
    required this.field,
    required this.id,
    required this.name,
    this.constituencyId,
  });

  final OfficialType type;
  final String field;
  final String id;
  final String name;

  /// Parent Lok Sabha seat, used to frame the map. Null if unknown.
  final String? constituencyId;

  /// Null when the account has no area yet (not approved / not linked).
  static OfficialScope? fromUser(UserModel user) {
    final type = officialTypeFrom(user.officialType);
    final jType = user.jurisdictionType ?? type.jurisdictionType;
    final id = user.jurisdictionId ??
        (type == OfficialType.mp ? user.constituencyId : null);
    if (id == null) return null;
    return OfficialScope(
      type: type,
      field: kScopeFieldFor[jType] ?? 'constituencyId',
      id: id,
      name: user.jurisdictionName ?? user.constituencyName ?? id,
      constituencyId: user.constituencyId,
    );
  }

  /// Key for `publicClustersProvider` / `publicAllTicketsProvider`. MPs use
  /// the bare constituency id so they share the public dashboard's cache.
  String get key => field == 'constituencyId' ? id : '$field:$id';

  @override
  bool operator ==(Object other) =>
      other is OfficialScope && other.field == field && other.id == id;

  @override
  int get hashCode => Object.hash(field, id);
}
