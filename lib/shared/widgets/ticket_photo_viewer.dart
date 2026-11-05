import 'package:flutter/material.dart';

import '../../core/services/work_service.dart';

/// "View photo" for the people who handle a report (officials, the assigned
/// worker, the admin). Fetches the ORIGINAL photo through the server, which
/// checks the report is theirs, then shows it full screen.
class ViewPhotoButton extends StatefulWidget {
  const ViewPhotoButton({super.key, required this.ticketId, this.service});

  final String ticketId;
  final WorkService? service;

  @override
  State<ViewPhotoButton> createState() => _ViewPhotoButtonState();
}

class _ViewPhotoButtonState extends State<ViewPhotoButton> {
  bool _busy = false;

  Future<void> _open() async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final url = await (widget.service ?? WorkService()).ticketPhoto(widget.ticketId);
      if (!mounted) return;
      if (url == null) {
        messenger.showSnackBar(const SnackBar(content: Text('This report has no photo.')));
      } else {
        await Navigator.of(context).push(MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => TicketPhotoScreen(url: url),
        ));
      }
    } catch (_) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Could not open the photo. It may not be in your area.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => TextButton.icon(
        style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
        icon: _busy
            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.photo_outlined, size: 16),
        label: const Text('View photo', style: TextStyle(fontSize: 12)),
        onPressed: _busy ? null : _open,
      );
}

class TicketPhotoScreen extends StatelessWidget {
  const TicketPhotoScreen({super.key, required this.url});

  final String url;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: const Text('Report photo'),
        ),
        body: Center(
          child: InteractiveViewer(
            maxScale: 5,
            child: Image.network(
              url,
              fit: BoxFit.contain,
              loadingBuilder: (_, child, progress) => progress == null
                  ? child
                  : const Center(child: CircularProgressIndicator()),
              errorBuilder: (_, __, ___) => const Padding(
                padding: EdgeInsets.all(24),
                child: Text('The photo could not be loaded.',
                    style: TextStyle(color: Colors.white)),
              ),
            ),
          ),
        ),
      );
}
