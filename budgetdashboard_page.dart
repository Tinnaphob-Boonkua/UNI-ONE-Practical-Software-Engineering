import 'package:flutter/material.dart';
import 'dart:math' as math;

void main() => runApp(const BudgetApp());

class BudgetApp extends StatelessWidget {
  const BudgetApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Budget Dashboard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F172A)),
        fontFamily: 'Roboto',
      ),
      home: const BudgetDashboardMinimal(),
    );
  }
}

class BudgetDashboardMinimal extends StatelessWidget {
  const BudgetDashboardMinimal({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // slate-50
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            // main scroll
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
              children: [
                // Header row: back + title + crest
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _circleBtn(icon: Icons.arrow_back, onTap: () {}),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Budget Dashboard',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                    // โลโก้ขวา (placeholder)
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.white,
                      child: Text(
                        'MU',
                        style: TextStyle(
                          color: Colors.blue.shade800,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Mahidol University',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),

                // KPI cards (2 บน)
                Row(
                  children: [
                    Expanded(child: _kpiCard(title: 'Total Budget', value: '\$12.4M')),
                    const SizedBox(width: 12),
                    Expanded(child: _kpiCard(title: 'Spent', value: '\$7.9M')),
                  ],
                ),
                const SizedBox(height: 12),
                // KPI card (Remaining)
                _kpiCard(title: 'Remaining', value: '\$4.5M'),

                const SizedBox(height: 16),

                // Spend by Category (donut + legend)
                _outlinedCard(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Spend by Category', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Donut (Spent 64% vs Remaining)
                          const SizedBox(
                            width: 140,
                            height: 140,
                            child: DonutChart(spentPct: 0.64),
                          ),
                          const SizedBox(width: 16),
                          // Legend แบบรายการ
                          const Expanded(child: SpendLegend()),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Monthly Budget vs Spent (line)
                _outlinedCard(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('Monthly Budget vs Spent', style: TextStyle(fontWeight: FontWeight.w700)),
                      SizedBox(height: 10),
                      SizedBox(height: 160, child: BudgetLineChart()),
                    ],
                  ),
                ),
              ],
            ),

            // bottom-left round button (grey)
            Positioned(
              left: 16,
              bottom: 24,
              child: _circleBtn(
                icon: Icons.arrow_back,
                onTap: () {},
                bg: const Color(0xFFE5E7EB), // slate-200
                fg: Colors.black87,
              ),
            ),

            // bottom-right "edit" pill
            Positioned(
              right: 16,
              bottom: 24,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE5E7EB),
                  foregroundColor: Colors.black87,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                  elevation: 0,
                ),
                onPressed: () {},
                child: const Text('edit'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- UI helpers ----------
  static Widget _kpiCard({required String title, required String value}) {
    return _outlinedCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  static Widget _outlinedCard({required Widget child, EdgeInsets? padding}) {
    return Container(
      margin: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1), // slate-300
      ),
      child: Padding(padding: padding ?? const EdgeInsets.all(12), child: child),
    );
  }

  static Widget _circleBtn({
    required IconData icon,
    required VoidCallback onTap,
    Color bg = const Color(0xFFF1F5F9), // slate-100
    Color fg = Colors.black87,
  }) {
    return Material(
      color: bg,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(width: 36, height: 36, child: Icon(icon, size: 18, color: fg)),
      ),
    );
  }
}

/* =========================
   Donut Chart (no packages)
========================= */
class DonutChart extends StatelessWidget {
  final double spentPct; // 0..1
  const DonutChart({super.key, required this.spentPct});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DonutPainter(spentPct),
      child: const SizedBox.expand(),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final double spentPct;
  _DonutPainter(this.spentPct);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerR = math.min(size.width, size.height) / 2;
    final innerR = outerR - 18; // ring thickness ~18
    final rect = Rect.fromCircle(center: center, radius: outerR);

    // Background ring (light grey)
    final bgPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = outerR - innerR
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFE5E7EB); // slate-200
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2, false, bgPaint);

    // Spent arc (emerald)
    final spentPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = outerR - innerR
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF34D399);
    canvas.drawArc(rect, -math.pi / 2, (math.pi * 2) * spentPct, false, spentPaint);

    // Inner hole (to make real donut)
    final hole = Paint()..color = Colors.white;
    canvas.drawCircle(center, innerR - 1, hole);
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) => old.spentPct != spentPct;
}

/* =========================
   Legend (fixed sample)
========================= */
class SpendLegend extends StatelessWidget {
  const SpendLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      _LegendItem('Faculty Ops', 0xFF34D399, '\$3.2M'),
      _LegendItem('Research Grants', 0xFF60A5FA, '\$2.1M'),
      _LegendItem('Facilities', 0xFFFBBF24, '\$1.5M'),
      _LegendItem('IT & Systems', 0xFFF472B6, '\$0.9M'),
      _LegendItem('Student Services', 0xFFA78BFA, '\$0.7M'),
      _LegendItem('Other', 0xFFD1D5DB, '\$0.3M'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map((e) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Color(e.color),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${e.label} — ${e.valueText}',
                  style: const TextStyle(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _LegendItem {
  final String label;
  final int color;
  final String valueText;
  _LegendItem(this.label, this.color, this.valueText);
}

/* =========================
   Line Chart (no packages)
========================= */
class BudgetLineChart extends StatelessWidget {
  const BudgetLineChart({super.key});

  @override
  Widget build(BuildContext context) {
    // demo data (k)
    final months = ['Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct'];
    final budget = [1100, 1120, 1150, 1200, 1280, 1300, 1320];
    final spent  = [ 980, 1030, 1060, 1115, 1210, 1275, 1240];

    return CustomPaint(
      painter: _LineChartPainter(
        labels: months,
        series: [
          _Series('Budget', budget.map((e) => e.toDouble()).toList(), const Color(0xFF60A5FA)),
          _Series('Spent',  spent.map((e) => e.toDouble()).toList(),  const Color(0xFF34D399)),
        ],
        minY: 900, maxY: 1400,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _Series {
  final String name;
  final List<double> y;
  final Color color;
  _Series(this.name, this.y, this.color);
}

class _LineChartPainter extends CustomPainter {
  final List<String> labels;
  final List<_Series> series;
  final double minY;
  final double maxY;

  _LineChartPainter({
    required this.labels,
    required this.series,
    required this.minY,
    required this.maxY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // padding
    const leftPad = 8.0;
    const rightPad = 8.0;
    const bottomPad = 22.0;
    const topPad = 8.0;

    final chartW = size.width - leftPad - rightPad;
    final chartH = size.height - topPad - bottomPad;
    final origin = Offset(leftPad, topPad + chartH);

    // grid lines (3 เส้น)
    final gridPaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..strokeWidth = 1;
    for (int i = 0; i < 3; i++) {
      final y = topPad + chartH * (i + 1) / 3;
      canvas.drawLine(Offset(leftPad, y), Offset(size.width - rightPad, y), gridPaint);
    }

    // scale function
    double xAt(int i) {
      if (labels.length == 1) return leftPad + chartW / 2;
      return leftPad + chartW * (i / (labels.length - 1));
    }
    double yAt(double v) {
      final t = ((v - minY) / (maxY - minY)).clamp(0.0, 1.0);
      return topPad + chartH * (1 - t);
    }

    // draw lines
    for (final s in series) {
      final p = Path();
      for (int i = 0; i < s.y.length; i++) {
        final pt = Offset(xAt(i), yAt(s.y[i]));
        if (i == 0) {
          p.moveTo(pt.dx, pt.dy);
        } else {
          p.lineTo(pt.dx, pt.dy);
        }
      }
      final paint = Paint()
        ..color = s.color
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke;
      canvas.drawPath(p, paint);
    }

    // x labels
    final tp = TextPainter(textAlign: TextAlign.center, textDirection: TextDirection.ltr);
    for (int i = 0; i < labels.length; i++) {
      tp.text = TextSpan(
        text: labels[i],
        style: const TextStyle(fontSize: 10, color: Colors.black54),
      );
      tp.layout();
      final x = xAt(i) - tp.width / 2;
      final y = topPad + chartH + 4;
      tp.paint(canvas, Offset(x, y));
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter old) =>
      old.labels != labels || old.series != series || old.minY != minY || old.maxY != maxY;
}
