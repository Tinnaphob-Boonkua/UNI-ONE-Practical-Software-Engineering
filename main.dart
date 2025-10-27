import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'document_page.dart'; 

void main() => runApp(const DeanSchedulerApp());

class DeanSchedulerApp extends StatelessWidget {
  const DeanSchedulerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dean Scheduler',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        scaffoldBackgroundColor: const Color(0xFFF4F4F5),
        fontFamily: 'Roboto',
      ),
      home: const HomePage(),
       routes: {
      '/documents': (context) => const DocumentPage(),
  },
    );
  }
}

/// ------------------------ HOME ------------------------
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            const _TopBar(),
            const SizedBox(height: 12),
            _WeekStrip(
              selected: _selectedDate,
              onSelect: (d) => setState(() => _selectedDate = d),
            ),
            const SizedBox(height: 10),
            _SectionHeader(
              title:
                  '${DateFormat.EEEE().format(_selectedDate)} ${_selectedDate.day} ${DateFormat.MMM().format(_selectedDate).toLowerCase()} ${_selectedDate.year}',
              trailingText: 'Schedule view',
              onTapTrailing: () {},
            ),
            const SizedBox(height: 8),

            // ====== Events (ตัวอย่างตามภาพ) ======
            const _EventCard(
              title: 'Faculty Meeting',
              location: 'Meeting Room',
              timeRange: '10:00 – 12:00',
              note: 'Review semester budget and schedule',
            ),
            const _DividerLine(),
            const _EventCard(
              title: 'Research Seminar',
              location: 'Auditorium Hall',
              timeRange: '14:00 – 15:30',
              note: 'Guest speaker from Chulalongkorn University',
            ),
            const _DividerLine(),
            const _EventCard(
              title: 'Budget Review',
              location: "Dean's Office",
              timeRange: '16:00 – 17:00',
              note: 'Approve Q4 budget request',
            ),
            const SizedBox(height: 8),
            const _RightLink(text: 'View all events'),
            const SizedBox(height: 18),

            // ====== Menu ======
            const Text('Menu',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            _MenuTile(
              icon: Icons.check_circle_outlined,
              title: 'Todo-List',
              onTap: () {},
            ),
            _MenuTile(
              icon: Icons.event_outlined,
              title: 'Event',
              onTap: () {},
            ),
            _MenuTile(
              icon: Icons.description_outlined,
              title: 'View document',
              onTap: () => Navigator.pushNamed(context, '/documents'),
            ),
            _MenuTile(
              icon: Icons.pie_chart_outline_rounded,
              title: 'Budget Dashboard',
              onTap: () {},
            ),
            _MenuTile(
              icon: Icons.chat_bubble_outline_rounded,
              title: 'Chat',
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }
}

/// ------------------------ WIDGETS ------------------------

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(icon: const Icon(Icons.menu), onPressed: () {}),
        const SizedBox(width: 4),
        const Expanded(
          child: Text(
            'Hi, Usagi 👋',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.notifications_none_rounded),
          onPressed: () {},
        ),
      ],
    );
  }
}

class _WeekStrip extends StatelessWidget {
  final DateTime selected;
  final void Function(DateTime) onSelect;

  const _WeekStrip({required this.selected, required this.onSelect});

 
  DateTime _startOfWeek(DateTime d) => d.subtract(Duration(days: d.weekday % 7));

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final start = _startOfWeek(selected);
    final days = List.generate(7, (i) => DateTime(start.year, start.month, start.day + i));

    final hasEvent = <int, bool>{
      0: true,  // Sun
      2: true,  // Tue
      3: true,  // Wed
      5: true,  // Fri
    };

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: days.asMap().entries.map((e) {
          final index = e.key;
          final day = e.value;
          final isSelected = DateUtils.isSameDay(day, selected);
          final isToday = DateUtils.isSameDay(day, now);

          return _DayChip(
            label: DateFormat.E().format(day), // Sun, Mon, ...
            dayNumber: day.day,
            active: isSelected,
            showDot: hasEvent[index] ?? false,
            todayRing: !isSelected && isToday, // เส้นบางๆ รอบวันนี้ (ตามภาพวง)
            onTap: () => onSelect(day),
          );
        }).toList(),
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  final String label;
  final int dayNumber;
  final bool active;
  final bool showDot;
  final bool todayRing;
  final VoidCallback onTap;

  const _DayChip({
    required this.label,
    required this.dayNumber,
    required this.onTap,
    this.active = false,
    this.showDot = false,
    this.todayRing = false,
  });

  @override
  Widget build(BuildContext context) {
    final ringColor = active
        ? const Color(0xFF2563EB)
        : (todayRing ? const Color(0xFF94A3B8) : Colors.transparent);

    return InkWell(
      borderRadius: BorderRadius.circular(28),
      onTap: onTap,
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Container(
            width: 54,
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? const Color(0xFFEFF6FF) : Colors.transparent,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: ringColor, width: active ? 2 : 1),
            ),
            child: Text(
              '$dayNumber',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: 6),
          if (showDot)
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFF2563EB),
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String trailingText;
  final VoidCallback? onTapTrailing;

  const _SectionHeader({
    required this.title,
    required this.trailingText,
    this.onTapTrailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const Spacer(),
        InkWell(
          onTap: onTapTrailing,
          child: const Text(
            'Schedule view',
            style: TextStyle(
              decoration: TextDecoration.underline,
              color: Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _DividerLine extends StatelessWidget {
  const _DividerLine();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 10),
      child: Divider(height: 1),
    );
  }
}

class _EventCard extends StatelessWidget {
  final String title;
  final String location;
  final String timeRange;
  final String note;

  const _EventCard({
    super.key,
    required this.title,
    required this.location,
    required this.timeRange,
    required this.note,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 2),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 12, color: Colors.red),
                  const SizedBox(width: 4),
                  Text(location, style: const TextStyle(fontSize: 12)),
                ],
              ),
              const SizedBox(height: 6),
              _TimePill(text: timeRange),
              const SizedBox(height: 6),
              Text(note, style: const TextStyle(fontSize: 12, color: Colors.black87)),
            ],
          ),
        ),
      ],
    );
  }
}

class _TimePill extends StatelessWidget {
  final String text;
  const _TimePill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(40),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }
}

class _RightLink extends StatelessWidget {
  final String text;
  const _RightLink({required this.text});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: InkWell(
        onTap: () {},
        child: Text(
          text,
          style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _MenuTile({required this.icon, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        leading: Icon(icon, size: 26),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      ),
    );
  }
}
