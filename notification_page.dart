import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/* ================================
   NOTIFICATIONS PAGE
   - Events (from `events`)
   - Chat messages (from `chats/dean_secretary/messages`)
   - Merged & sorted desc by time
================================ */
class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  // Hardcoded roles (match your ChatPage IDs)
  static const String _deanId = 'dean';
  static const String _secretaryId = 'secretary';

  String get _chatId {
    final ids = [_deanId, _secretaryId]..sort();
    return ids.join('_'); // "dean_secretary"
  }

  String _format12h(DateTime? dt) {
    if (dt == null) return '';
    int h = dt.hour % 12;
    if (h == 0) h = 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final suffix = dt.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $suffix';
  }

  String _timeAgo(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'now';
    if (d.inHours < 1) return '${d.inMinutes}m ago';
    if (d.inDays < 1) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    // Events stream
    final eventsStream = FirebaseFirestore.instance
        .collection('events')
        .orderBy('date_', descending: true)
        .snapshots();

    // Chat stream (no composite index needed)
    final chatStream = FirebaseFirestore.instance
        .collection('chats')
        .doc(_chatId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(200)
        .snapshots();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
              child: Row(
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => Navigator.maybePop(context),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: Color(0xFFBDBDBD),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.chevron_left, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Notifications',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            Container(height: 1, color: Colors.black.withOpacity(0.06)),

            // Merge events + chats
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: eventsStream,
                builder: (context, evSnap) {
                  if (evSnap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (evSnap.hasError) {
                    return Center(child: Text('Error (events): ${evSnap.error}'));
                  }

                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: chatStream,
                    builder: (context, chatSnap) {
                      if (chatSnap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (chatSnap.hasError) {
                        return Center(child: Text('Error (chat): ${chatSnap.error}'));
                      }

                      final now = DateTime.now();

                      // ----- Map events to items
                      final evDocs = evSnap.data?.docs ?? [];
                      final eventItems = evDocs.map<_NotifItem>((doc) {
                        final data = doc.data();

                        final evTitle = (data['title'] ?? 'Untitled').toString();
                        final loc = (data['location_id'] ?? 'Unknown location').toString();
                        final dateStr = (data['date_'] ?? '').toString();
                        final startRaw = data['start_'];

                        DateTime? day;
                        if (dateStr.isNotEmpty) {
                          try {
                            final d = DateTime.parse(dateStr);
                            day = DateTime(d.year, d.month, d.day);
                          } catch (_) {}
                        }

                        DateTime? start;
                        if (startRaw is Timestamp) start = startRaw.toDate();
                        if (start == null && startRaw is String && startRaw.isNotEmpty) {
                          try {
                            start = DateTime.parse(startRaw);
                          } catch (_) {}
                        }

                        final eventMoment =
                            start ?? (day != null ? DateTime(day.year, day.month, day.day, 23, 59) : null);

                        final isPast = eventMoment != null && eventMoment.isBefore(now);
                        final opacity = isPast ? 0.45 : 1.0;

                        const title = 'Event soon';
                        final timeLabel = _format12h(start);
                        final subtitle =
                            timeLabel.isEmpty ? evTitle : '$evTitle starts at $timeLabel • $loc';

                        return _NotifItem(
                          kind: _NotifKind.event,
                          title: title,
                          subtitle: subtitle,
                          when: eventMoment ?? now,
                          opacity: opacity,
                          onTap: () => Navigator.pushNamed(context, '/schedule'),
                        );
                      }).toList();

                      // ----- Map chat messages to items (show sender)
                      final chatDocs = chatSnap.data?.docs ?? [];
                      final chatItems = chatDocs.map<_NotifItem>((doc) {
                        final data = doc.data();
                        final sender = (data['senderId'] ?? '').toString();
                        final text = (data['text'] ?? '').toString();

                        DateTime when = now;
                        final ts = data['createdAt'];
                        if (ts is Timestamp) when = ts.toDate();

                        final who = sender == _secretaryId
                            ? 'Secretary'
                            : sender == _deanId
                                ? 'Dean'
                                : sender.isEmpty
                                    ? 'Unknown'
                                    : sender;

                        return _NotifItem(
                          kind: _NotifKind.chat,
                          title: 'New message — $who',
                          subtitle: text,
                          when: when,
                          opacity: 1.0,
                          onTap: () => Navigator.pushNamed(context, '/chat'),
                        );
                      }).toList();

                      // Merge & sort (newest first)
                      final all = <_NotifItem>[...eventItems, ...chatItems]
                        ..sort((a, b) => b.when.compareTo(a.when));

                      if (all.isEmpty) {
                        return const Center(child: Text('No notifications'));
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.only(top: 8),
                        itemCount: all.length,
                        separatorBuilder: (_, __) =>
                            Divider(height: 1, color: Colors.black.withOpacity(0.08)),
                        itemBuilder: (context, i) {
                          final n = all[i];

                          final row = Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        n.title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15.5,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        n.subtitle,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  _timeAgo(n.when),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black45,
                                  ),
                                ),
                              ],
                            ),
                          );

                          return Opacity(
                            opacity: n.opacity,
                            child: InkWell(
                              onTap: n.onTap,
                              child: row,
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ================================
   Internal item model
================================ */
enum _NotifKind { event, chat }

class _NotifItem {
  final _NotifKind kind;
  final String title;
  final String subtitle;
  final DateTime when;
  final double opacity;
  final VoidCallback? onTap;

  _NotifItem({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.when,
    required this.opacity,
    required this.onTap,
  });
}
