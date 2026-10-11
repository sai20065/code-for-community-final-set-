import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/theme.dart';
import '../../../core/models/official_scope.dart';
import '../../../core/services/official_service.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../onboarding/auth/auth_common.dart';

/// The official types that can self-register (MPs are provisioned).
const _registrable = [
  OfficialType.mla,
  OfficialType.wardOfficer,
  OfficialType.tahsildar,
  OfficialType.districtOfficer,
];

/// Self-registration for MLAs and local officers: role → area → details →
/// proof. Creates the account and a *pending* application; nothing on the
/// government side opens until a Prajadhwani admin approves it.
///
/// Also used to re-apply after a rejection ([resubmit] = true): the account
/// already exists, so email/password are skipped.
class OfficialRegisterScreen extends StatefulWidget {
  const OfficialRegisterScreen({super.key, this.resubmit = false});

  final bool resubmit;

  @override
  State<OfficialRegisterScreen> createState() => _OfficialRegisterScreenState();
}

class _OfficialRegisterScreenState extends State<OfficialRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _designation = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _service = OfficialService();

  OfficialType? _type;
  PickedArea? _area;
  Uint8List? _proof;
  String? _existingProofPath;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.resubmit) _prefill();
  }

  Future<void> _prefill() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final app = await _service.watchApplication(uid).first;
    if (app == null || !mounted) return;
    setState(() {
      _name.text = app.name;
      _designation.text = app.designation ?? '';
      _type = app.officialType;
      _area = PickedArea(
        type: app.jurisdictionType,
        id: app.jurisdictionId,
        name: app.jurisdictionName,
        constituencyId: app.constituencyId,
      );
      _existingProofPath = app.proofPath;
    });
  }

  @override
  void dispose() {
    for (final c in [_name, _designation, _email, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickProof() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1800,
      imageQuality: 80,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (bytes.length > OfficialService.maxProofBytes) {
      setState(() => _error = 'That file is over 5 MB. Choose a smaller photo.');
      return;
    }
    setState(() {
      _proof = bytes;
      _error = null;
    });
  }

  Future<void> _pickArea() async {
    if (_type == null) return;
    final area = await showModalBottomSheet<PickedArea>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => _AreaPickerSheet(type: _type!),
    );
    if (area != null) setState(() => _area = area);
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (_type == null) return setState(() => _error = 'Choose your role.');
    if (_area == null) return setState(() => _error = 'Choose your area.');
    if (!_formKey.currentState!.validate()) return;
    if (_proof == null && _existingProofPath == null) {
      return setState(() =>
          _error = 'Add a photo of your ID or appointment letter.');
    }
    setState(() => _submitting = true);
    try {
      if (widget.resubmit) {
        await _service.resubmit(
          name: _name.text,
          designation: _designation.text,
          type: _type!,
          area: _area!,
          proofBytes: _proof,
          existingProofPath: _existingProofPath,
        );
      } else {
        await _service.register(
          name: _name.text,
          designation: _designation.text,
          type: _type!,
          area: _area!,
          email: _email.text,
          password: _password.text,
          proofBytes: _proof!,
          proofContentType: 'image/jpeg',
        );
      }
      if (mounted) context.go('/gov/pending');
    } on FirebaseAuthException catch (e) {
      setState(() {
        _submitting = false;
        _error = switch (e.code) {
          'email-already-in-use' =>
            'An account already uses this email. Sign in instead.',
          'weak-password' => 'Use a password of at least 6 characters.',
          'invalid-email' => 'That email address is not valid.',
          _ => 'Could not create the account. Try again.',
        };
      });
    } catch (e) {
      debugPrint('Official registration failed: $e');
      setState(() {
        _submitting = false;
        _error = 'Could not submit your application. Try again.';
      });
    }
  }

  Widget _step(int n, String title, Widget child) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: AppColors.indigo,
                  child: Text('$n',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 8),
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: widget.resubmit ? 'Update your application' : 'Register as an official',
      subtitle: 'MLAs and local officers get a dashboard for their own area '
          'once a Prajadhwani admin verifies their appointment.',
      backTo: widget.resubmit ? '/gov/pending' : '/gov/login',
      footer: widget.resubmit
          ? null
          : Center(
              child: TextButton(
                onPressed: () => context.go('/gov/login'),
                child: const Text('Already approved? Sign in'),
              ),
            ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _step(
              1,
              'Your role',
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 2.2,
                children: [
                  for (final t in _registrable)
                    _RoleTile(
                      type: t,
                      selected: _type == t,
                      onTap: () => setState(() {
                        if (_type != t) _area = null;
                        _type = t;
                      }),
                    ),
                ],
              ),
            ),
            _step(
              2,
              'Your area',
              OutlinedButton.icon(
                onPressed: _type == null ? null : _pickArea,
                icon: Icon(_type?.icon ?? Icons.place_rounded),
                label: Text(
                  _area?.name ??
                      (_type == null
                          ? 'Choose your role first'
                          : 'Choose ${_type!.areaNoun.toLowerCase()}'),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  alignment: Alignment.centerLeft,
                ),
              ),
            ),
            _step(
              3,
              'Your details',
              Column(
                children: [
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Full name',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                    validator: (v) =>
                        (v ?? '').trim().length < 3 ? 'Enter your full name' : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _designation,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Designation',
                      hintText: 'e.g. Assistant Executive Engineer',
                      prefixIcon: Icon(Icons.work_outline_rounded),
                    ),
                    validator: (v) =>
                        (v ?? '').trim().isEmpty ? 'Enter your designation' : null,
                  ),
                  if (!widget.resubmit) ...[
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Official email',
                        hintText: 'used to sign in and reset your password',
                        prefixIcon: Icon(Icons.alternate_email_rounded),
                      ),
                      validator: (v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                              .hasMatch((v ?? '').trim())
                          ? null
                          : 'Enter a valid email',
                    ),
                    const SizedBox(height: 10),
                    PasswordField(
                      controller: _password,
                      label: 'Password',
                      autofillHints: const [AutofillHints.newPassword],
                      validator: (v) => (v ?? '').length < 8
                          ? 'At least 8 characters'
                          : null,
                    ),
                    const SizedBox(height: 10),
                    PasswordField(
                      controller: _confirm,
                      label: 'Confirm password',
                      autofillHints: const [AutofillHints.newPassword],
                      validator: (v) => v != _password.text
                          ? "Passwords don't match"
                          : null,
                    ),
                  ],
                ],
              ),
            ),
            _step(
              4,
              'Proof of appointment',
              InkWell(
                onTap: _pickProof,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  height: 150,
                  decoration: BoxDecoration(
                    color: AppColors.indigoMist,
                    borderRadius: BorderRadius.circular(14),
                    image: _proof == null
                        ? null
                        : DecorationImage(
                            image: MemoryImage(_proof!), fit: BoxFit.cover),
                  ),
                  alignment: Alignment.center,
                  child: _proof != null
                      ? null
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.upload_file_rounded,
                                size: 34, color: AppColors.indigo),
                            const SizedBox(height: 6),
                            Text(
                              _existingProofPath != null
                                  ? 'Proof on file · tap to replace'
                                  : 'Photo of your government ID or appointment letter',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: AppColors.indigo),
                            ),
                            const Text('Only the Prajadhwani admin can see it.',
                                style: TextStyle(
                                    fontSize: 11.5, color: AppColors.inkSoft)),
                          ],
                        ),
                ),
              ),
            ),
            if (_error != null) AuthErrorBanner(_error!),
            PrimaryButton(
              label: widget.resubmit ? 'Re-submit for review' : 'Submit for review',
              icon: Icons.send_rounded,
              loading: _submitting,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleTile extends StatelessWidget {
  const _RoleTile({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final OfficialType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.indigo : AppColors.indigoMist,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              Icon(type.icon,
                  color: selected ? Colors.white : AppColors.indigo, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(type.shortLabel,
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: selected ? Colors.white : AppColors.indigoDeep)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Searchable list of the areas for one official type.
class _AreaPickerSheet extends StatefulWidget {
  const _AreaPickerSheet({required this.type});

  final OfficialType type;

  @override
  State<_AreaPickerSheet> createState() => _AreaPickerSheetState();
}

class _AreaPickerSheetState extends State<_AreaPickerSheet> {
  late final Future<List<(PickedArea, String)>> _future = _load();
  String _q = '';

  /// (area, subtitle) pairs. Reads the public reference collections.
  Future<List<(PickedArea, String)>> _load() async {
    final db = FirebaseFirestore.instance;
    final jt = widget.type.jurisdictionType;
    switch (widget.type) {
      case OfficialType.mla:
        final s = await db.collection('assemblies').get();
        final list = [
          for (final d in s.docs)
            (
              PickedArea(
                type: jt,
                id: d.id,
                name: '${d['acNo']}. ${d['name']}',
                constituencyId: d.data()['constituencyId'] as String?,
              ),
              '${d.data()['districtName'] ?? ''} · ${d.data()['constituencyName'] ?? ''}',
            ),
        ];
        list.sort((a, b) => int.parse(a.$1.id.split('-').last)
            .compareTo(int.parse(b.$1.id.split('-').last)));
        return list;
      case OfficialType.wardOfficer:
        final s = await db
            .collection('wards')
            .where('corporation', isEqualTo: 'BBMP')
            .get();
        final list = [
          for (final d in s.docs)
            (
              PickedArea(
                type: jt,
                id: d.id,
                name: '${d['wardNo']}. ${d['wardName']}',
                constituencyId: d.data()['constituencyId'] as String?,
              ),
              'Assembly: ${d.data()['assemblyConstituency'] ?? ''}',
            ),
        ];
        list.sort((a, b) => int.parse(a.$1.id.split('-').last)
            .compareTo(int.parse(b.$1.id.split('-').last)));
        return list;
      case OfficialType.tahsildar:
        final s = await db.collection('taluks').get();
        final list = [
          for (final d in s.docs)
            (
              PickedArea(
                type: jt,
                id: d.id,
                name: d.data()['talukName'] as String? ?? d.id,
                constituencyId: d.data()['constituencyId'] as String?,
              ),
              d.data()['districtName'] as String? ?? '',
            ),
        ];
        list.sort((a, b) => a.$1.name.compareTo(b.$1.name));
        return list;
      case OfficialType.districtOfficer:
      case OfficialType.mp:
        final s = await db.collection('districts').get();
        final list = [
          for (final d in s.docs)
            (
              PickedArea(
                type: 'district',
                id: d.id,
                name: d.data()['name'] as String? ?? d.id,
              ),
              'District',
            ),
        ];
        list.sort((a, b) => a.$1.name.compareTo(b.$1.name));
        return list;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (context, scroll) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search ${widget.type.areaNoun.toLowerCase()}',
                prefixIcon: const Icon(Icons.search_rounded),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<(PickedArea, String)>>(
              future: _future,
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = snap.data!
                    .where((e) =>
                        _q.isEmpty ||
                        e.$1.name.toLowerCase().contains(_q) ||
                        e.$2.toLowerCase().contains(_q))
                    .toList();
                return ListView.builder(
                  controller: scroll,
                  itemCount: items.length,
                  itemBuilder: (context, i) => ListTile(
                    leading: Icon(widget.type.icon, color: AppColors.indigo),
                    title: Text(items[i].$1.name),
                    subtitle: Text(items[i].$2),
                    onTap: () => Navigator.of(context).pop(items[i].$1),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
