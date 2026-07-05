import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/primary_button.dart';

/// Single question per screen (Section 3.2): name, then age — not one long form.
class BasicInfoScreen extends StatefulWidget {
  const BasicInfoScreen({super.key});

  @override
  State<BasicInfoScreen> createState() => _BasicInfoScreenState();
}

class _BasicInfoScreenState extends State<BasicInfoScreen> {
  int _step = 0;
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  void _next() {
    if (_step == 0) {
      if (_nameController.text.trim().isEmpty) return;
      setState(() => _step = 1);
    } else {
      if (_ageController.text.trim().isEmpty) return;
      context.go('/signup/location', extra: {
        'name': _nameController.text.trim(),
        'age': int.tryParse(_ageController.text.trim()) ?? 0,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isName = _step == 0;
    return Scaffold(
      appBar: AppBar(title: Text(isName ? 'Your Name' : 'Your Age')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Icon(isName ? Icons.person_rounded : Icons.cake_rounded,
                  size: 56),
              const SizedBox(height: 24),
              if (isName)
                TextField(
                  key: const ValueKey('name'),
                  controller: _nameController,
                  style: const TextStyle(fontSize: 20),
                  decoration: const InputDecoration(hintText: 'Full name'),
                )
              else
                TextField(
                  key: const ValueKey('age'),
                  controller: _ageController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 20),
                  decoration: const InputDecoration(hintText: 'Age'),
                ),
              const Spacer(),
              Align(
                alignment: Alignment.bottomRight,
                child: SizedBox(
                  width: 160,
                  child: PrimaryButton(
                    label: 'Next',
                    icon: Icons.arrow_forward_rounded,
                    onPressed: _next,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
