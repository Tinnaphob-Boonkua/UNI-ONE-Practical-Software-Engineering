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
    runApp(
      MaterialApp(
        home: Scaffold(body: Center(child: Text('Init error: $e'))),
      ),
    );
  }
}

class DeanApp extends StatelessWidget {
  const DeanApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dean Management',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF2255EE),
      ),
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
      setState(() {
        _loading = true;
        _error = null;
      });

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
        if (dateRaw is String && dateRaw.isNotEmpty) {
          dateOnly = DateTime.tryParse(dateRaw);
        }

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
        _events
          ..clear()
          ..addAll(grouped);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // ---- Add Event helpers ----

  String _formatYmd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // Display-friendly location fallback used right after saving (before next reload).
  String _resolveLocationAfterSave(dynamic raw) {
    if (raw == null) return 'Unknown location';
    if (raw is int) return 'Location #$raw';
    final s = raw.toString();
    if (int.tryParse(s) != null) return 'Location #$s';
    return s;
  }

  Future<void> _onAddPressed() async {
    final result = await showModalBottomSheet<_NewEventData>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _AddEventSheet(
        initialDate: _selectedDay ?? _dateOnly(DateTime.now()),
      ),
    );

    if (result == null) return; // user canceled

    try {
      final payload = <String, dynamic>{
        'title': result.title.trim().isEmpty ? 'Untitled' : result.title.trim(),
        'date_': _formatYmd(result.date),
        'location_id': (result.locationRaw?.trim().isEmpty ?? true)
            ? null
            : result.locationRaw!.trim(),
      };
      if (result.start != null) payload['start_'] = Timestamp.fromDate(result.start!);
      if (result.end != null) payload['end_'] = Timestamp.fromDate(result.end!);

      // write to Firestore
      final doc = await FirebaseFirestore.instance.collection('events').add(payload);

      // optimistic UI update
      final dayKey = _dateOnly(result.start ?? result.date);
      final ev = DayEvent(
        id: doc.id,
        title: payload['title'] as String,
        start: result.start,
        end: result.end,
        location: _resolveLocationAfterSave(payload['location_id']),
      );

      setState(() {
        (_events[dayKey] ??= []).add(ev);
        _events[dayKey]!.sort((a, b) {
          final at = a.start?.millisecondsSinceEpoch ?? 0;
          final bt = b.start?.millisecondsSinceEpoch ?? 0;
          return at.compareTo(bt);
        });
        _selectedDay = dayKey;
        _visibleMonth = DateTime(dayKey.year, dayKey.month, 1);
      });

      // If you prefer a full re-sync from Firestore instead:
      // await _loadFromFirestore();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add event: $e')),
      );
    }
  }

  // ---- Delete confirmation ----
  Future<bool> _confirmDelete(DayEvent ev, DateTime day) async {
    final dateLabel =
        '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete event?'),
            content: Text('Are you sure you want to delete:\n\n• ${ev.title}\n• $dateLabel'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton.tonal(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final days = _buildCalendarDays(_visibleMonth);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Schedule'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _loadFromFirestore,
          ),
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
            onPrev: () => setState(
              () => _visibleMonth = DateTime(
                _visibleMonth.year,
                _visibleMonth.month - 1,
                1,
              ),
            ),
            onNext: () => setState(
              () => _visibleMonth = DateTime(
                _visibleMonth.year,
                _visibleMonth.month + 1,
                1,
              ),
            ),
          ),
          const SizedBox(height: 8),
          _WeekdayRow(),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text('Error: $_error'),
                        ),
                      )
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
                              final isSelected =
                                  _selectedDay != null && _sameDay(day, _selectedDay!);
                              final hasEvent = _hasEvents(day);
                              return InkWell(
                                onTap: isCurrentMonth
                                    ? () => setState(() => _selectedDay = _dateOnly(day))
                                    : null,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Theme.of(context).colorScheme.primaryContainer
                                        : null,
                                    border: Border.all(
                                      color: Theme.of(context).dividerColor,
                                    ),
                                  ),
                                  child: Stack(
                                    children: [
                                      Positioned(
                                        top: 6,
                                        left: 6,
                                        child: Text(
                                          '${day.day}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: isCurrentMonth ? null : Colors.grey,
                                          ),
                                        ),
                                      ),
                                      if (hasEvent)
                                        const Positioned(
                                          right: 6,
                                          bottom: 6,
                                          child: _EventDot(),
                                        ),
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
            events: _selectedDay == null
                ? const <DayEvent>[]
                : (_events[_selectedDay!] ?? const <DayEvent>[]),
            onToggle: (index, value) async {
              if (!value) return; // act only when checked
              if (_selectedDay == null) return;
              final key = _dateOnly(_selectedDay!);
              final list = _events[key];
              if (list == null || index < 0 || index >= list.length) return;

              final ev = list[index];

              // Confirm first
              final ok = await _confirmDelete(ev, key);
              if (!ok) return;

              try {
                await FirebaseFirestore.instance.collection('events').doc(ev.id).delete();
                setState(() {
                  list.removeAt(index);
                  if (list.isEmpty) _events.remove(key);
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Deleted "${ev.title}"')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to delete: $e')),
                );
              }
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _onAddPressed,
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
    );
  }

  bool _hasEvents(DateTime dt) => (_events[_dateOnly(dt)]?.isNotEmpty ?? false);
  static DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  List<DateTime> _buildCalendarDays(DateTime month) {
    final first = DateTime(month.year, month.month, 1);
    final leading = first.weekday - 1; // Mon=1..Sun=7
    final firstBox = first.subtract(Duration(days: leading));
    return List.generate(
      42,
      (i) => DateTime(firstBox.year, firstBox.month, firstBox.day + i),
    );
  }
}

/* ---------------- UI bits ---------------- */

class _MonthHeader extends StatelessWidget {
  final DateTime month;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  const _MonthHeader({
    required this.month,
    required this.onPrev,
    required this.onNext,
  });

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
              child: Text(
                label,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_right)),
        ],
      ),
    );
  }

  String _formatMonthYear(DateTime m) {
    const names = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
    ];
    return '${names[m.month - 1]} ${m.year}';
  }
}

class _WeekdayRow extends StatelessWidget {
  final List<String> labels = const [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];
  @override
  Widget build(BuildContext context) {
    return Row(
      children: labels
          .map(
            (d) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Center(
                  child: Text(
                    d,
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _EventDot extends StatelessWidget {
  const _EventDot();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

class _SelectedDayEvents extends StatelessWidget {
  final DateTime? day;
  final List<DayEvent> events;

  /// When the checkbox is toggled. Should be async to allow confirmations.
  final Future<void> Function(int index, bool value) onToggle;

  const _SelectedDayEvents({
    required this.day,
    required this.events,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            day == null ? 'No day selected' : _humanDate(day!),
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (events.isEmpty)
            Text('No events', style: Theme.of(context).textTheme.bodyMedium)
          else
            ...List.generate(events.length, (i) {
              final e = events[i];
              final timeLine = _formatTimeRange(e.start, e.end);

              return CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                // Always show unchecked; checking triggers confirmation + deletion.
                value: false,
                onChanged: (v) => onToggle(i, v ?? false),
                title: Text(e.title),
                subtitle: Text(
                  [
                    if (timeLine.isNotEmpty) timeLine,
                    if (e.location.isNotEmpty) e.location,
                  ].join(' • '),
                ),
              );
            }),
        ],
      ),
    );
  }

  String _humanDate(DateTime d) {
    const wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const mo = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
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

/* -------- Add Event Sheet -------- */

class _NewEventData {
  final String title;
  final DateTime date;       // date-only
  final DateTime? start;     // full datetime or null
  final DateTime? end;       // full datetime or null
  final String? locationRaw; // stored as 'location_id' in Firestore
  _NewEventData({
    required this.title,
    required this.date,
    required this.start,
    required this.end,
    required this.locationRaw,
  });
}

class _AddEventSheet extends StatefulWidget {
  final DateTime initialDate;
  const _AddEventSheet({required this.initialDate});

  @override
  State<_AddEventSheet> createState() => _AddEventSheetState();
}

class _AddEventSheetState extends State<_AddEventSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();

  late DateTime _dateOnly;
  TimeOfDay? _startTod;
  TimeOfDay? _endTod;

  @override
  void initState() {
    super.initState();
    _dateOnly = DateTime(widget.initialDate.year, widget.initialDate.month, widget.initialDate.day);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOnly,
      firstDate: DateTime(_dateOnly.year - 2),
      lastDate: DateTime(_dateOnly.year + 3),
    );
    if (picked != null) {
      setState(() => _dateOnly = DateTime(picked.year, picked.month, picked.day));
    }
  }

  Future<void> _pickStart() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTod ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null) setState(() => _startTod = picked);
  }

  Future<void> _pickEnd() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTod ?? const TimeOfDay(hour: 10, minute: 0),
    );
    if (picked != null) setState(() => _endTod = picked);
  }

  DateTime? _compose(DateTime date, TimeOfDay? tod) {
    if (tod == null) return null;
    return DateTime(date.year, date.month, date.day, tod.hour, tod.minute);
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.event_note),
                      const SizedBox(width: 8),
                      Text(
                        'Add Event',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      hintText: 'e.g., Faculty meeting',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter a title' : null,
                  ),
                  const SizedBox(height: 12),

                  InkWell(
                    onTap: _pickDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Date',
                        border: OutlineInputBorder(),
                      ),
                      child: Text(_humanDate(_dateOnly)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: _pickStart,
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Start time (optional)',
                              border: OutlineInputBorder(),
                            ),
                            child: Text(_startTod == null ? '—' : _startTod!.format(context)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: _pickEnd,
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'End time (optional)',
                              border: OutlineInputBorder(),
                            ),
                            child: Text(_endTod == null ? '—' : _endTod!.format(context)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _locationCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Location / Location ID (optional)',
                      hintText: 'Room 201, Auditorium A, or a loc doc id',
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 16),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const Spacer(),
                      FilledButton.icon(
                        icon: const Icon(Icons.check),
                        label: const Text('Save'),
                        onPressed: () {
                          if (!_formKey.currentState!.validate()) return;

                          final start = _compose(_dateOnly, _startTod);
                          final end = _compose(_dateOnly, _endTod);

                          if (start != null && end != null && end.isBefore(start)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('End time must be after start time')),
                            );
                            return;
                          }

                          Navigator.pop(
                            context,
                            _NewEventData(
                              title: _titleCtrl.text,
                              date: _dateOnly,
                              start: start,
                              end: end,
                              locationRaw: _locationCtrl.text.trim().isEmpty ? null : _locationCtrl.text.trim(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _humanDate(DateTime d) {
    const wd = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    const mo = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${wd[d.weekday - 1]}, ${d.day} ${mo[d.month - 1]} ${d.year}';
  }
}
