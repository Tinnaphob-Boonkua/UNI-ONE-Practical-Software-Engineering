import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    runApp(const DeanApp());
  } catch (e) {
    runApp(MaterialApp(home: Scaffold(body: Center(child: Text('Init error: $e')))));
  }
}

class DeanApp extends StatelessWidget {
  const DeanApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dean Management',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF2255EE)),
      home: const SchedulePage(),
    );
  }
}

/* ---------------- Models ---------------- */

class DayEvent {
  final String id;
  final String title;
  final DateTime? start;
  final DateTime? end;
  final String location;
  bool done;
  DayEvent({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    required this.location,
    this.done = false,
  });
}

/* ---------------- Schedule Page ---------------- */

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key});
  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  late DateTime _visibleMonth; // first day of visible month
  DateTime? _selectedDay;

  final Map<DateTime, List<DayEvent>> _events = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month, 1);
    _selectedDay = _dateOnly(now);
    _loadFromFirestore();
  }

  Future<void> _loadFromFirestore() async {
    try {
      setState(() { _loading = true; _error = null; });

      // ---- Load locations ----
      final locSnap = await FirebaseFirestore.instance.collection('locations').get();
      final Map<String, String> locByDocId = {};
      final Map<int, String> locByNumber = {};
      for (final d in locSnap.docs) {
        final data = d.data();
        final name = (data['name'] ?? '').toString().trim();
        if (name.isEmpty) continue;
        locByDocId[d.id] = name;
        final match = RegExp(r'(\d+)$').firstMatch(d.id);
        if (match != null) {
          final n = int.tryParse(match.group(1)!);
          if (n != null) locByNumber[n] = name;
        }
      }
      String resolveLocation(dynamic raw) {
        if (raw == null) return 'Unknown location';
        if (raw is int) return locByNumber[raw] ?? 'Location #$raw';
        final s = raw.toString();
        return locByDocId[s] ??
            (int.tryParse(s) != null ? (locByNumber[int.parse(s)] ?? 'Location #$s') : s);
      }

      // ---- Load events ----
      final evSnap = await FirebaseFirestore.instance.collection('events').get();
      final Map<DateTime, List<DayEvent>> grouped = {};

      for (final d in evSnap.docs) {
        final data = d.data();
        if (data.isEmpty) continue; // skip empty docs

        final title = (data['title'] ?? 'Untitled').toString();

        DateTime? start;
        DateTime? end;
        final startRaw = data['start_'];
        final endRaw = data['end_'];
        if (startRaw is Timestamp) start = startRaw.toDate();
        if (endRaw is Timestamp) end = endRaw.toDate();
        if (start == null && startRaw is String && startRaw.isNotEmpty) {
          start = DateTime.tryParse(startRaw);
        }
        if (end == null && endRaw is String && endRaw.isNotEmpty) {
          end = DateTime.tryParse(endRaw);
        }

        DateTime? dateOnly;
        final dateRaw = data['date_'];
        if (dateRaw is String && dateRaw.isNotEmpty) dateOnly = DateTime.tryParse(dateRaw);

        final dayKey = _dateOnly(start ?? dateOnly ?? DateTime.now());
        final ev = DayEvent(
          id: d.id,
          title: title,
          start: start,
          end: end,
          location: resolveLocation(data['location_id']),
        );
        (grouped[dayKey] ??= []).add(ev);
      }

      // sort events in a day by time
      for (final list in grouped.values) {
        list.sort((a, b) {
          final at = a.start?.millisecondsSinceEpoch ?? 0;
          final bt = b.start?.millisecondsSinceEpoch ?? 0;
          return at.compareTo(bt);
        });
      }

      setState(() {
        _events..clear()..addAll(grouped);
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final days = _buildCalendarDays(_visibleMonth);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Schedule'),
        actions: [
          IconButton(tooltip: 'Refresh', icon: const Icon(Icons.refresh), onPressed: _loadFromFirestore),
          IconButton(
            tooltip: 'Today',
            icon: const Icon(Icons.today),
            onPressed: () => setState(() {
              final now = DateTime.now();
              _visibleMonth = DateTime(now.year, now.month, 1);
              _selectedDay = _dateOnly(now);
            }),
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          _MonthHeader(
            month: _visibleMonth,
            onPrev: () => setState(() => _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month - 1, 1)),
            onNext: () => setState(() => _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1, 1)),
          ),
          const SizedBox(height: 8),
          _WeekdayRow(),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Padding(padding: const EdgeInsets.all(16), child: Text('Error: $_error')))
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final cellWidth = constraints.maxWidth / 7;
                          final cellHeight = cellWidth; // square
                          return GridView.builder(
                            padding: EdgeInsets.zero,
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 7,
                              childAspectRatio: cellWidth / cellHeight,
                            ),
                            itemCount: days.length,
                            itemBuilder: (context, i) {
                              final day = days[i];
                              final isCurrentMonth = day.month == _visibleMonth.month;
                              final isSelected = _selectedDay != null && _sameDay(day, _selectedDay!);
                              final hasEvent = _hasEvents(day);
                              return InkWell(
                                onTap: isCurrentMonth ? () => setState(() => _selectedDay = _dateOnly(day)) : null,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
                                    border: Border.all(color: Theme.of(context).dividerColor),
                                  ),
                                  child: Stack(
                                    children: [
                                      Positioned(
                                        top: 6, left: 6,
                                        child: Text('${day.day}',
                                          style: TextStyle(fontWeight: FontWeight.w600, color: isCurrentMonth ? null : Colors.grey),
                                        ),
                                      ),
                                      if (hasEvent) const Positioned(right: 6, bottom: 6, child: _EventDot()),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
          ),
          _SelectedDayEvents(
            day: _selectedDay,
            events: _selectedDay == null ? const <DayEvent>[] : (_events[_selectedDay!] ?? const <DayEvent>[]),
            onToggle: (index, value) {
              if (_selectedDay == null) return;
              final key = _dateOnly(_selectedDay!);
              final list = _events[key];
              if (list == null || index < 0 || index >= list.length) return;
              setState(() => list[index].done = value);
            },
          ),
        ],
      ),
    );
  }

  bool _hasEvents(DateTime dt) => (_events[_dateOnly(dt)]?.isNotEmpty ?? false);
  static DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
  static bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  List<DateTime> _buildCalendarDays(DateTime month) {
    final first = DateTime(month.year, month.month, 1);
    final leading = first.weekday - 1; // Mon=1..Sun=7
    final firstBox = first.subtract(Duration(days: leading));
    return List.generate(42, (i) => DateTime(firstBox.year, firstBox.month, firstBox.day + i));
  }
}

/* ---------------- UI bits ---------------- */

class _MonthHeader extends StatelessWidget {
  final DateTime month;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  const _MonthHeader({required this.month, required this.onPrev, required this.onNext});

  @override
  Widget build(BuildContext context) {
    final label = _formatMonthYear(month);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          IconButton(onPressed: onPrev, icon: const Icon(Icons.chevron_left)),
          Expanded(
            child: Center(
              child: Text(label, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            ),
          ),
          IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_right)),
        ],
      ),
    );
  }

  String _formatMonthYear(DateTime m) {
    const names = ['January','February','March','April','May','June','July','August','September','October','November','December'];
    return '${names[m.month - 1]} ${m.year}';
  }
}

class _WeekdayRow extends StatelessWidget {
  final List<String> labels = const ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
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

class _EventDot extends StatelessWidget {
  const _EventDot();
  @override
  Widget build(BuildContext context) {
    return Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: Theme.of(context).colorScheme.primary));
  }
}

class _SelectedDayEvents extends StatelessWidget {
  final DateTime? day;
  final List<DayEvent> events;
  final void Function(int index, bool value) onToggle;
  const _SelectedDayEvents({required this.day, required this.events, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(border: Border(top: BorderSide(color: Theme.of(context).dividerColor))),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(day == null ? 'No day selected' : _humanDate(day!), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        if (events.isEmpty)
          Text('No events', style: Theme.of(context).textTheme.bodyMedium)
        else
          ...List.generate(events.length, (i) {
            final e = events[i];
            final timeLine = _formatTimeRange(e.start, e.end);

            final titleStyle = e.done
                ? const TextStyle(
                    decoration: TextDecoration.lineThrough,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey,
                  )
                : null;

            final subtitleStyle = e.done
                ? const TextStyle(
                    decoration: TextDecoration.lineThrough,
                    color: Colors.grey,
                  )
                : null;

            return CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: e.done,
              onChanged: (v) => onToggle(i, v ?? false),
              title: Text(e.title, style: titleStyle),
              subtitle: Text(
                [
                  if (timeLine.isNotEmpty) timeLine,
                  if (e.location.isNotEmpty) e.location,
                ].join(' • '),
               style: subtitleStyle,
              ),
            );
          }),
      ]),
    );
  }

  String _humanDate(DateTime d) {
    const wd = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    const mo = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${wd[d.weekday - 1]}, ${d.day} ${mo[d.month - 1]} ${d.year}';
  }

  String _two(int n) => n.toString().padLeft(2, '0');
  String _formatTime(DateTime t) => '${_two(t.hour)}:${_two(t.minute)}';
  String _formatTimeRange(DateTime? s, DateTime? e) {
    if (s == null && e == null) return '';
    if (s != null && e != null) return '${_formatTime(s)}–${_formatTime(e)}';
    if (s != null) return _formatTime(s);
    return _formatTime(e!);
  }
}
