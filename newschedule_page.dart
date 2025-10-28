import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'event_page.dart';

class SchedulePage extends StatefulWidget {
  static const routeName = '/schedule';
  const SchedulePage({super.key});
  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  DateTime _visibleMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime? _selectedDay = DateTime.now();

  // --- helpers ---
  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
  String _hm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  DateTime? _parseMaybeTsOrIso(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
    return null;
  }

  DateTime? _getDateOnlyFrom(Map<String, dynamic> m) {
    // first try explicit date_ (YYYY-MM-DD), else fallback to start_
    final ds = (m['date_'] ?? '').toString();
    if (ds.isNotEmpty) return DateTime.tryParse(ds);
    return _parseMaybeTsOrIso(m['start_'])?.let(_dateOnly);
  }

  @override
  Widget build(BuildContext context) {
    final days = _buildCalendarDays(_visibleMonth);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('events').snapshots(),
      builder: (context, snap) {
        // build in-memory index: dateOnly -> list of docs
        final byDay = <DateTime, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
        if (snap.hasData) {
          for (final doc in snap.data!.docs) {
            final d = _getDateOnlyFrom(doc.data());
            if (d == null) continue;
            final key = _dateOnly(d);
            (byDay[key] ??= []).add(doc);
          }
          // sort each day by start time
          for (final list in byDay.values) {
            list.sort((a, b) {
              final sa = _parseMaybeTsOrIso(a['start_'])?.millisecondsSinceEpoch ?? 0;
              final sb = _parseMaybeTsOrIso(b['start_'])?.millisecondsSinceEpoch ?? 0;
              return sa.compareTo(sb);
            });
          }
        }

        List<QueryDocumentSnapshot<Map<String, dynamic>>> eventsOn(DateTime day) {
          return byDay[_dateOnly(day)] ?? const [];
        }

        return Scaffold(
          appBar: AppBar(
            // ✅ ปุ่มย้อนกลับไปหน้าเดิม (HomePage)
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              tooltip: 'Back',
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text('Schedule View'),
            actions: [
              IconButton.filledTonal(
                icon: const Icon(Icons.event),
                tooltip: 'Open Events',
                onPressed: () => Navigator.pushNamed(context, EventPage.routeName),
              ),
            ],
          ),
          body: Column(
            children: [
              const SizedBox(height: 8),
              _MonthHeader(
                month: _visibleMonth,
                onPrev: () => setState(() {
                  _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month - 1, 1);
                }),
                onNext: () => setState(() {
                  _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1, 1);
                }),
              ),
              const SizedBox(height: 8),
              _WeekdayRow(),
              const Divider(height: 1),
              Expanded(
                child: GridView.builder(
                  padding: EdgeInsets.zero,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                  ),
                  itemCount: days.length,
                  itemBuilder: (context, i) {
                    final d = days[i];
                    final inMonth = d.month == _visibleMonth.month;
                    final isSelected = _selectedDay != null &&
                        d.year == _selectedDay!.year &&
                        d.month == _selectedDay!.month &&
                        d.day == _selectedDay!.day;
                    final has = eventsOn(d).isNotEmpty;

                    return InkWell(
                      onTap: inMonth ? () => setState(() => _selectedDay = d) : null,
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primaryContainer
                              : null,
                          border: Border.all(color: Theme.of(context).dividerColor),
                        ),
                        child: Stack(
                          children: [
                            Positioned(
                              top: 6, left: 6,
                              child: Text('${d.day}', style: TextStyle(color: inMonth ? null : Colors.grey)),
                            ),
                            if (has)
                              Positioned(
                                right: 6, bottom: 6,
                                child: Container(
                                  width: 8, height: 8,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              // Selected-day list
              Padding(
                padding: const EdgeInsets.fromLTRB(16,10,16,16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedDay == null
                          ? 'No day selected'
                          : _selectedDay!.toIso8601String().split('T').first,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    for (final doc in _selectedDay == null ? const [] : eventsOn(_selectedDay!))
                      Builder(builder: (_) {
                        final m = doc.data();
                        final title = (m['title'] ?? 'Untitled').toString();
                        final start = _parseMaybeTsOrIso(m['start_']);
                        final end   = _parseMaybeTsOrIso(m['end_']);
                        final meta = (start != null && end != null)
                            ? '${_hm(start)} – ${_hm(end)}'
                            : (start != null ? _hm(start) : (end != null ? _hm(end) : ''));
                        final type = (m['type'] ?? 'other').toString();
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.event),
                          title: Text(title),
                          subtitle: Text([meta, type].where((s) => s.isNotEmpty).join('  •  ')),
                        );
                      }),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<DateTime> _buildCalendarDays(DateTime month) {
    final first = DateTime(month.year, month.month, 1);
    final leading = first.weekday - 1;
    final firstBox = first.subtract(Duration(days: leading));
    return List.generate(42, (i) => DateTime(firstBox.year, firstBox.month, firstBox.day + i));
  }
}

class _MonthHeader extends StatelessWidget {
  final DateTime month;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  const _MonthHeader({required this.month, required this.onPrev, required this.onNext});
  @override
  Widget build(BuildContext context) {
    const names = [
      'January','February','March','April','May','June',
      'July','August','September','October','November','December'
    ];
    final label = '${names[month.month - 1]} ${month.year}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          IconButton(onPressed: onPrev, icon: const Icon(Icons.chevron_left)),
          Expanded(child: Center(
            child: Text(label, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          )),
          IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_right)),
        ],
      ),
    );
  }
}

class _WeekdayRow extends StatelessWidget {
  final labels = const ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
  @override
  Widget build(BuildContext context) {
    return Row(
      children: labels.map((d) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Center(child: Text(d, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700))),
        ),
      )).toList(),
    );
  }
}

extension<T> on T {
  R let<R>(R Function(T) block) => block(this);
}
