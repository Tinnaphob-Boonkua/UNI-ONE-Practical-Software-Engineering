import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'add_edit_event_page.dart';

class EventPage extends StatefulWidget {
  static const routeName = '/events';
  const EventPage({super.key});
  @override
  State<EventPage> createState() => _EventPageState();
}

class _EventPageState extends State<EventPage> {
  String _hm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  DateTime? _parse(dynamic v) =>
      v is Timestamp ? v.toDate() : (v is String ? DateTime.tryParse(v) : null);

  @override
  Widget build(BuildContext context) {
    final col = FirebaseFirestore.instance.collection('events');

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context)),
        title: const Text('Events'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add), label: const Text('add'),
        onPressed: () => Navigator.pushNamed(context, AddEditEventPage.routeName),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: col.snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
          final docs = snap.data?.docs ?? const [];
          if (docs.isEmpty) return const Center(child: Text('No events'));

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final d = docs[i];
              final m = d.data();
              final title = (m['title'] ?? 'Untitled').toString();
              final type  = (m['type'] ?? 'other').toString();
              final s = _parse(m['start_']);
              final e = _parse(m['end_']);
              final meta = (s != null && e != null)
                  ? '${_hm(s)} – ${_hm(e)}'
                  : (s != null ? _hm(s) : (e != null ? _hm(e) : ''));

              return ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: Theme.of(context).dividerColor),
                ),
                title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text([meta, type].where((x) => x.isNotEmpty).join('  •  ')),
                trailing: PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v == 'edit') {
                      await Navigator.pushNamed(
                        context,
                        AddEditEventPage.routeName,
                        arguments: {'id': d.id, ...m},
                      );
                    } else if (v == 'delete') {
                      await col.doc(d.id).delete();
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
                onTap: () => Navigator.pushNamed(
                  context,
                  AddEditEventPage.routeName,
                  arguments: {'id': d.id, ...m},
                ),
              );
            },
          );
        },
      ),
    );
  }
}
