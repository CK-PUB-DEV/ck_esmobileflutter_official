import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_swipe_action_cell/flutter_swipe_action_cell.dart';
import 'package:pushtrial/services/messages_repository.dart';
import 'package:pushtrial/models/login.dart';
import 'package:pushtrial/models/school_message.dart';
import 'package:pushtrial/models/user.dart';
import 'package:pushtrial/models/user_data.dart';
import 'package:pushtrial/models/user_login.dart';
import 'package:pushtrial/services/message_read_store.dart';
import 'package:pushtrial/widgets/ui/ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What the school sent this person: SMS, tap texts and text blasts to their phone number, and
/// announcements sent to the student.
///
/// Everything from the last 30 days is listed, whether or not the old push job flagged it.
/// Items under 24 hours old are "New" (and were also popped up as alerts while they were
/// valid); older ones are history. Read state is kept on the phone only.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  // Slow responses can finish after the screen was closed; skip the update then.
  @override
  void setState(VoidCallback fn) {
    if (mounted) super.setState(fn);
  }

  User user = UserData.myUser;
  Login userLogin = UserDataLogin.myUserLogin;
  int studid = 0;
  List<SchoolMessage> messages = [];
  bool loading = true;
  bool failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final preferences = await SharedPreferences.getInstance();
    final userJson = preferences.getString('user');
    final loginJson = preferences.getString('userlogin');
    user = userJson == null ? UserData.myUser : User.fromJson(jsonDecode(userJson));
    userLogin = loginJson == null
        ? UserDataLogin.myUserLogin
        : Login.fromJson(jsonDecode(loginJson));
    studid = user.id;

    // From the school's server, whatever version it runs (see MessagesRepository).
    final fetched = await MessagesRepository.load(studid, userLogin.type);
    final ok = fetched != null;
    final loaded = fetched ?? messages;

    loaded.sort((a, b) {
      final x = a.createdAt, y = b.createdAt;
      if (x == null || y == null) return 0;
      return y.compareTo(x);
    });
    await MessageReadStore.apply(loaded, studid);
    setState(() {
      messages = loaded;
      failed = !ok && loaded.isEmpty;
      loading = false;
    });
  }

  /// Read state is kept on this phone only. Nothing is written to the school's server.
  Future<void> _markRead(SchoolMessage message) async {
    await MessageReadStore.markRead([message], studid);
    setState(() {});
  }

  /// Looking at the page counts as reading what it showed: remember those as read on leaving, so
  /// "New" and the Home bell clear. (They still read as unread while the page is open.)
  @override
  void dispose() {
    if (studid != 0 && messages.any((m) => !m.read)) {
      MessageReadStore.markRead(messages, studid);
    }
    super.dispose();
  }

  Widget _card(SchoolMessage message) {
    final theme = ShadTheme.of(context);
    final text = theme.textTheme;
    final unread = message.isUnread;
    final created = message.createdAt;
    final when = created == null ? '' : '${Fmt.date(created)} · ${Fmt.time(created)}';

    return AppCard(
      margin: const EdgeInsets.only(bottom: Gap.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            unread ? LucideIcons.bellRing : LucideIcons.bell,
            size: IconSize.row,
            color: unread ? theme.colorScheme.primary : theme.colorScheme.mutedForeground,
          ),
          Gap.wMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (message.title.isNotEmpty) ...[
                  Text(
                    message.title,
                    style: text.p.copyWith(
                      fontWeight: FontWeight.w600,
                      color: unread ? null : theme.colorScheme.mutedForeground,
                    ),
                  ),
                  Gap.hXs,
                ],
                Text(
                  message.message,
                  style: unread
                      ? text.p
                      : text.p.copyWith(color: theme.colorScheme.mutedForeground),
                ),
                if (when.isNotEmpty) ...[
                  Gap.hSm,
                  Text(when, style: text.muted),
                ],
              ],
            ),
          ),
          Gap.wSm,
          if (message.isRead)
            Icon(
              LucideIcons.circleCheck,
              size: IconSize.inline,
              color: theme.colorScheme.mutedForeground,
            )
          else if (unread)
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(top: Gap.xs + 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }

  Widget _swipeable(SchoolMessage message) {
    final theme = ShadTheme.of(context);
    return SwipeActionCell(
      key: ValueKey(message.key),
      trailingActions: message.isUnread
          ? [
              SwipeAction(
                content: Container(
                  alignment: Alignment.center,
                  margin: const EdgeInsets.only(bottom: Gap.md),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: theme.radius,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: Gap.md),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        LucideIcons.check,
                        size: IconSize.row,
                        color: theme.colorScheme.primaryForeground,
                      ),
                      Gap.hXs,
                      Text(
                        'Mark as read',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.small.copyWith(
                          color: theme.colorScheme.primaryForeground,
                        ),
                      ),
                    ],
                  ),
                ),
                onTap: (CompletionHandler handler) async {
                  await handler(true);
                  await _markRead(message);
                },
                color: Colors.transparent,
              ),
            ]
          : [],
      child: _card(message),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const AppPage(title: 'Notifications', body: LoadingSkeleton());
    }

    if (messages.isEmpty) {
      return AppPage(
        title: 'Notifications',
        onRefresh: _load,
        body: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.6,
              child: failed
                  ? ErrorState(onRetry: _load)
                  : const EmptyState(
                      icon: LucideIcons.bell,
                      title: 'No notifications',
                      message:
                          'Announcements and messages from your school in the last 30 days will show up here.',
                    ),
            ),
          ],
        ),
      );
    }

    final fresh = messages.where((m) => m.isNew).toList();
    final earlier = messages.where((m) => !m.isNew).toList();

    return AppPage(
      title: 'Notifications',
      onRefresh: _load,
      body: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(Gap.lg, Gap.sm, Gap.lg, Gap.xl),
        children: [
          if (fresh.isNotEmpty) ...[
            const SectionHeader('New', topGap: false),
            for (final m in fresh) _swipeable(m),
          ],
          if (earlier.isNotEmpty) ...[
            SectionHeader('Earlier', topGap: fresh.isNotEmpty),
            for (final m in earlier) _swipeable(m),
          ],
        ],
      ),
    );
  }
}
