import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers/auth_state_provider.dart';
import '../../app/providers/current_user_profile_provider.dart';
import '../../app/providers/feed_providers.dart';
import '../../app/theme.dart';
import '../../core/models/feed_comment_model.dart';
import '../../l10n/app_localizations.dart';

void showCommentsSheet(BuildContext context, String ticketId) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => CommentsSheet(ticketId: ticketId),
  );
}

/// Comments under a post. Anyone can read; signed-in citizens with a
/// username can write. Each comment is screened server-side and may be
/// hidden (phone numbers, abuse, flooding, or three reports).
class CommentsSheet extends ConsumerStatefulWidget {
  const CommentsSheet({super.key, required this.ticketId});

  final String ticketId;

  @override
  ConsumerState<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends ConsumerState<CommentsSheet> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send(String uid, String username) async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ref.read(feedServiceProvider).addComment(
            ticketId: widget.ticketId,
            uid: uid,
            username: username,
            text: text,
          );
      _controller.clear();
      if (mounted) FocusScope.of(context).unfocus();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).somethingWentWrong)),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _actions(FeedComment c, String? myUid) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final service = ref.read(feedServiceProvider);
    final mine = c.uid == myUid;
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (mine)
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: AppColors.vermilion),
              title: Text(l10n.deleteComment),
              onTap: () => Navigator.of(sheet).pop('delete'),
            )
          else if (myUid != null)
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: Text(l10n.reportComment),
              onTap: () => Navigator.of(sheet).pop('report'),
            ),
        ]),
      ),
    );
    try {
      if (choice == 'delete') await service.deleteComment(c.id);
      if (choice == 'report') {
        await service.reportComment(c.id);
        messenger.showSnackBar(SnackBar(content: Text(l10n.commentReported)));
      }
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.somethingWentWrong)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(authStateProvider).valueOrNull;
    final username = ref.watch(currentUserProfileProvider).valueOrNull?.username;
    final comments = ref.watch(feedCommentsProvider(widget.ticketId));

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            Text(l10n.commentsTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Divider(height: 1),
            Expanded(
              child: comments.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => Center(child: Text(l10n.somethingWentWrong)),
                data: (list) => list.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(l10n.noCommentsYet,
                              textAlign: TextAlign.center, style: const TextStyle(color: AppColors.inkSoft)),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 2),
                        itemBuilder: (_, i) {
                          final c = list[i];
                          return ListTile(
                            onLongPress: user == null ? null : () => _actions(c, user.uid),
                            leading: CircleAvatar(
                              backgroundColor: AppColors.indigoMist,
                              child: Text(c.username.isEmpty ? '?' : c.username[0].toUpperCase(),
                                  style: const TextStyle(color: AppColors.indigoDeep, fontWeight: FontWeight.w800)),
                            ),
                            title: Text.rich(TextSpan(children: [
                              TextSpan(text: '@${c.username}  ',
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                              if (c.createdAt != null)
                                TextSpan(
                                  text: l10n.postedDaysAgo(DateTime.now().difference(c.createdAt!).inDays),
                                  style: const TextStyle(color: AppColors.inkFaint, fontSize: 11.5),
                                ),
                            ])),
                            subtitle: Text(c.text, style: const TextStyle(color: AppColors.ink, fontSize: 14)),
                          );
                        },
                      ),
              ),
            ),
            const Divider(height: 1),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                child: user == null
                    ? SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            GoRouter.of(context).push('/signin');
                          },
                          child: Text(l10n.signInToComment),
                        ),
                      )
                    : (username == null || username.isEmpty)
                        ? Text(l10n.needUsernameToComment, style: const TextStyle(color: AppColors.inkSoft))
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Expanded(
                                  child: TextField(
                                    controller: _controller,
                                    maxLength: 280,
                                    minLines: 1,
                                    maxLines: 4,
                                    textInputAction: TextInputAction.send,
                                    onSubmitted: (_) => _send(user.uid, username),
                                    decoration: InputDecoration(
                                      hintText: l10n.addComment,
                                      counterText: '',
                                      isDense: true,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(22)),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: _sending ? null : () => _send(user.uid, username),
                                  icon: const Icon(Icons.send_rounded, color: AppColors.indigoDeep),
                                ),
                              ]),
                              Padding(
                                padding: const EdgeInsets.only(left: 6, top: 4),
                                child: Text(l10n.commentPublicNote,
                                    style: const TextStyle(fontSize: 11, color: AppColors.inkFaint)),
                              ),
                            ],
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
