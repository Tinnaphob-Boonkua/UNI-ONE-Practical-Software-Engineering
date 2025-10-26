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
      home: const DashboardPage(),
    );
  }
}

/* =========================
   Shared Models & Helpers
========================= */
class CategorySlice {
  String name;
  double amount; // stored in thousands; UI shows M
  CategorySlice(this.name, this.amount);
  CategorySlice copy() => CategorySlice(name, amount);
}

class BudgetData {
  String university;
  double totalM; // thousands → $XM on UI
  double spentM;
  List<CategorySlice> categories;

  // monthly series (values in thousands, e.g. 1100 = $1.1M)
  List<double> monthlyBudget;
  List<double> monthlySpent;

  BudgetData({
    required this.university,
    required this.totalM,
    required this.spentM,
    required this.categories,
    required this.monthlyBudget,
    required this.monthlySpent,
  });

  double get remainingM => (totalM - spentM).clamp(0, double.infinity);
  double get spentPct => totalM <= 0 ? 0 : (spentM / totalM).clamp(0, 1);

  BudgetData copy() => BudgetData(
        university: university,
        totalM: totalM,
        spentM: spentM,
        categories: categories.map((e) => e.copy()).toList(),
        monthlyBudget: List<double>.from(monthlyBudget),
        monthlySpent: List<double>.from(monthlySpent),
      );

  static BudgetData sample() => BudgetData(
        university: 'Mahidol University',
        totalM: 12400, // $12.4M
        spentM: 7900,  // $7.9M
        categories: [
          CategorySlice('Faculty Ops', 3200),
          CategorySlice('Research Grants', 2100),
          CategorySlice('Facilities', 1500),
          CategorySlice('IT & Systems', 900),
          CategorySlice('Student Services', 700),
          CategorySlice('Other', 300),
        ],
        monthlyBudget: [1100, 1120, 1150, 1200, 1280, 1300, 1320, 1200, 1180, 1160, 1140, 1120],
        monthlySpent:  [ 980, 1030, 1060, 1115, 1210, 1275, 1240, 1180, 1170, 1130, 1100, 1080],
      );
}

String fmtMoneyM(double thousands) => '\$${(thousands / 1000).toStringAsFixed(1)}M';

/* =========================
   Dashboard (Left)
========================= */
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  BudgetData data = BudgetData.sample();
  final List<String> _months = const [
    'Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec','Jan','Feb','Mar'
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _circleBtn(icon: Icons.arrow_back, onTap: () {}),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text('Budget Dashboard',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.white,
                      child: Text('MU',
                          style: TextStyle(
                              color: Colors.blueAccent,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(data.university,
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(child: _kpiCard('Total Budget', _fmt(data.totalM))),
                    const SizedBox(width: 12),
                    Expanded(child: _kpiCard('Spent', _fmt(data.spentM))),
                  ],
                ),
                const SizedBox(height: 12),
                _kpiCard('Remaining', _fmt(data.remainingM)),

                const SizedBox(height: 16),

                _outlinedCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Spend by Category',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                              width: 140,
                              height: 140,
                              child: DonutChart(spentPct: data.spentPct)),
                          const SizedBox(width: 16),
                          Expanded(child: SpendLegend.dynamicList(data.categories)),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                _outlinedCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Monthly Budget vs Spent',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 160,
                        child: BudgetLineChart(
                          labels: _months,
                          budget: data.monthlyBudget,
                          spent: data.monthlySpent,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

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
                onPressed: () async {
                  final updated = await Navigator.push<BudgetData>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditDashboardPage(initial: data),
                    ),
                  );
                  if (updated != null) setState(() => data = updated);
                },
                child: const Text('edit'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kpiCard(String title, String value) => _outlinedCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 12, color: Colors.black54)),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          ],
        ),
      );

  Widget _outlinedCard({required Widget child}) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
        ),
        padding: const EdgeInsets.all(12),
        child: child,
      );

  Widget _circleBtn({
    required IconData icon,
    required VoidCallback onTap,
    Color bg = const Color(0xFFF1F5F9),
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

  String _fmt(double thousands) => '\$${(thousands / 1000).toStringAsFixed(1)}M';
}

/* =========================
   Edit Page (Right)
========================= */
class EditDashboardPage extends StatefulWidget {
  final BudgetData initial;
  const EditDashboardPage({super.key, required this.initial});

  @override
  State<EditDashboardPage> createState() => _EditDashboardPageState();
}

class _EditDashboardPageState extends State<EditDashboardPage> {
  late BudgetData draft;
  final _uniCtrl = TextEditingController();
  final _totalCtrl = TextEditingController();
  final _spentCtrl = TextEditingController();

  final List<String> _months = const [
    'Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec','Jan','Feb','Mar'
  ];

  @override
  void initState() {
    super.initState();
    draft = widget.initial.copy();
    _uniCtrl.text = draft.university;
    _totalCtrl.text = (draft.totalM / 1000).toStringAsFixed(1);
    _spentCtrl.text = (draft.spentM / 1000).toStringAsFixed(1);

    if (draft.monthlyBudget.length != 12) {
      draft.monthlyBudget = [
        ...draft.monthlyBudget,
        ...List<double>.filled(12, 0.0),
      ].take(12).toList();
    }
    if (draft.monthlySpent.length != 12) {
      draft.monthlySpent = [
        ...draft.monthlySpent,
        ...List<double>.filled(12, 0.0),
      ].take(12).toList();
    }
  }

  @override
  void dispose() {
    _uniCtrl.dispose();
    _totalCtrl.dispose();
    _spentCtrl.dispose();
    super.dispose();
  }

  void _syncTotals() {
    final t = double.tryParse(_totalCtrl.text) ?? (draft.totalM / 1000);
    final s = double.tryParse(_spentCtrl.text) ?? (draft.spentM / 1000);
    setState(() {
      draft.university = _uniCtrl.text.trim().isEmpty
          ? 'Mahidol University'
          : _uniCtrl.text.trim();
      draft.totalM = t * 1000;
      draft.spentM = s * 1000;
    });
  }

  void _addCategory() =>
      setState(() => draft.categories.add(CategorySlice('New Category', 100)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Row(
              children: [
                _roundIconBtn(icon: Icons.arrow_back, onTap: () => Navigator.pop(context)),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('Edit Dashboard',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.shield_outlined, color: Colors.blue.shade800),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // University
            _outlinedCard(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _uniCtrl,
                      onChanged: (_) => _syncTotals(),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'University',
                      ),
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
                    ),
                  ),
                  _redDot(() {
                    setState(() {
                      _uniCtrl.text = 'Mahidol University';
                      _syncTotals();
                    });
                  }),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Totals
            Row(
              children: [
                Expanded(
                  child: _outlinedCard(
                    child: Row(
                      children: [
                        Expanded(child: _labelSmall('Total Budget')),
                        SizedBox(
                          width: 120,
                          child: TextField(
                            controller: _totalCtrl,
                            onChanged: (_) => _syncTotals(),
                            keyboardType:
                                const TextInputType.numberWithOptions(decimal: true),
                            decoration: _numDecor('M'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _outlinedCard(
                    child: Row(
                      children: [
                        Expanded(child: _labelSmall('Spent')),
                        SizedBox(
                          width: 120,
                          child: TextField(
                            controller: _spentCtrl,
                            onChanged: (_) => _syncTotals(),
                            keyboardType:
                                const TextInputType.numberWithOptions(decimal: true),
                            decoration: _numDecor('M'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            _outlinedCard(
              child: Row(
                children: [
                  Expanded(child: _labelSmall('Remaining')),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Text(fmtMoneyM(draft.remainingM),
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 8),
                  _redDot(() {
                    setState(() {
                      draft.spentM = (draft.totalM * 0.6);
                      _spentCtrl.text = (draft.spentM / 1000).toStringAsFixed(1);
                    });
                  }),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Categories
            Row(
              children: [
                const Text('Spend by Category',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(width: 6),
                _redDot(() => setState(() => draft.categories.clear())),
              ],
            ),
            _outlinedCard(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
              child: Column(
                children: [
                  SizedBox(
                    height: 150,
                    child: Row(
                      children: [
                        SizedBox(
                          height: 140,
                          width: 140,
                          child: DonutChart(spentPct: draft.spentPct),
                        ),
                        const SizedBox(width: 16),
                        Expanded(child: SpendLegend.dynamicList(draft.categories)),
                      ],
                    ),
                  ),
                  const Divider(),
                  Column(
                    children: [
                      for (int i = 0; i < draft.categories.length; i++)
                        _catRow(
                          draft.categories[i],
                          onRemove: () => setState(() => draft.categories.removeAt(i)),
                        ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _addCategory,
                          icon: const Icon(Icons.add_circle_outline),
                          label: const Text('add'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Monthly Budget vs Spent (Editable)
            Row(
              children: [
                const Text('Monthly Budget vs Spent',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(width: 6),
                _redDot(() {
                  setState(() {
                    draft.monthlyBudget = List<double>.filled(12, 1000.0); // $1.0M each
                    draft.monthlySpent  = List<double>.filled(12, 800.0);  // $0.8M each
                  });
                }),
              ],
            ),
            _outlinedCard(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 160,
                    child: BudgetLineChart(
                      labels: _months,
                      budget: draft.monthlyBudget,
                      spent: draft.monthlySpent,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _seriesEditorRow(
                    label: 'Budget',
                    values: draft.monthlyBudget,
                    onChanged: (i, vM) =>
                        setState(() => draft.monthlyBudget[i] = vM * 1000),
                    showInMillions: true,
                  ),
                  const SizedBox(height: 8),
                  _seriesEditorRow(
                    label: 'Spent',
                    values: draft.monthlySpent,
                    onChanged: (i, vM) =>
                        setState(() => draft.monthlySpent[i] = vM * 1000),
                    showInMillions: true,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Tip: enter values in millions (e.g., 1.1 = \$1.1M)',
                    style: TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      _syncTotals();
                      Navigator.pop(context, draft);
                    },
                    child: const Text('confirm'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ======= edit helpers =======
  Widget _seriesEditorRow({
    required String label,
    required List<double> values, // stored in thousands
    required void Function(int index, double valueInMillions) onChanged,
    bool showInMillions = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
        const SizedBox(height: 6),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 12,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (_, i) {
              final displayed = showInMillions ? (values[i] / 1000) : values[i];
              final ctrl = TextEditingController(text: displayed.toStringAsFixed(1));
              return SizedBox(
                width: 74,
                child: TextField(
                  controller: ctrl,
                  onChanged: (txt) {
                    final v = double.tryParse(txt);
                    if (v != null) onChanged(i, v); // v in M
                  },
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    isDense: true,
                    labelText: _months[i % _months.length],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    suffixText: showInMillions ? 'M' : '',
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _catRow(CategorySlice c, {required VoidCallback onRemove}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              initialValue: c.name,
              decoration: const InputDecoration(
                isDense: true,
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => c.name = v,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 120,
            child: TextFormField(
              initialValue: (c.amount / 1000).toStringAsFixed(1),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                isDense: true,
                labelText: 'Amt (M)',
                border: OutlineInputBorder(),
                prefixText: '\$',
              ),
              onChanged: (v) {
                final d = double.tryParse(v);
                if (d != null) setState(() => c.amount = d * 1000);
              },
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.cancel, color: Colors.redAccent),
          ),
        ],
      ),
    );
  }

  static InputDecoration _numDecor(String suffix) => InputDecoration(
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        prefixText: '\$',
        suffixText: suffix,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      );

  static Widget _labelSmall(String t) =>
      Text(t, style: const TextStyle(fontSize: 12, color: Colors.black54));

  static Widget _redDot(VoidCallback onTap) => InkResponse(
        onTap: onTap,
        radius: 16,
        child: const Icon(Icons.cancel, color: Colors.redAccent, size: 20),
      );

  static Widget _outlinedCard({required Widget child, EdgeInsets? padding}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Color(0xFFCBD5E1)),
      ),
      child: Padding(padding: padding ?? const EdgeInsets.all(12), child: child),
    );
  }

  static Widget _roundIconBtn({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: const Color(0xFFF1F5F9),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const SizedBox(
          width: 36,
          height: 36,
          child: Icon(Icons.arrow_back, size: 18, color: Colors.black87),
        ),
      ),
    );
  }
}

/* =========================
   Charts (Shared)
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
    final innerR = outerR - 18; // ring thickness
    final rect = Rect.fromCircle(center: center, radius: outerR);

    final bgPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = outerR - innerR
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFE5E7EB);
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2, false, bgPaint);

    final spentPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = outerR - innerR
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF34D399);
    canvas.drawArc(rect, -math.pi / 2, (math.pi * 2) * spentPct, false, spentPaint);

    final hole = Paint()..color = Colors.white;
    canvas.drawCircle(center, innerR - 1, hole);
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) => old.spentPct != spentPct;
}

class SpendLegend extends StatelessWidget {
  final List<_LegendItem> items;
  const SpendLegend(this.items, {super.key});

  factory SpendLegend.dynamicList(List<CategorySlice> cats) {
    final palette = const [
      0xFF34D399, // emerald
      0xFF60A5FA, // blue
      0xFFFBBF24, // amber
      0xFFF472B6, // pink
      0xFFA78BFA, // violet
      0xFFD1D5DB, // gray
    ];
    final list = <_LegendItem>[];
    for (var i = 0; i < cats.length; i++) {
      final c = cats[i];
      list.add(_LegendItem(c.name, palette[i % palette.length], fmtMoneyM(c.amount)));
    }
    return SpendLegend(list);
  }

  @override
  Widget build(BuildContext context) {
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

class BudgetLineChart extends StatelessWidget {
  final List<String> labels;      // 12 month labels
  final List<double> budget;      // thousands
  final List<double> spent;       // thousands

  const BudgetLineChart({
    super.key,
    required this.labels,
    required this.budget,
    required this.spent,
  });

  @override
  Widget build(BuildContext context) {
    final all = [...budget, ...spent];
    final minV = (all.isEmpty ? 0 : all.reduce(math.min)).toDouble();
    final maxV = (all.isEmpty ? 1 : all.reduce(math.max)).toDouble();
    final pad = (maxV - minV).abs() * 0.15 + 1;

    return CustomPaint(
      painter: _LineChartPainter(
        labels: labels,
        series: [
          _Series('Budget', budget, const Color(0xFF60A5FA)),
          _Series('Spent',  spent,  const Color(0xFF34D399)),
        ],
        minY: (minV - pad).clamp(0, double.infinity),
        maxY: (maxV + pad),
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
    const leftPad = 8.0;
    const rightPad = 8.0;
    const bottomPad = 22.0;
    const topPad = 8.0;

    final chartW = size.width - leftPad - rightPad;
    final chartH = size.height - topPad - bottomPad;

    // grid
    final gridPaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..strokeWidth = 1;
    for (int i = 0; i < 3; i++) {
      final y = topPad + chartH * (i + 1) / 3;
      canvas.drawLine(Offset(leftPad, y), Offset(size.width - rightPad, y), gridPaint);
    }

    double xAt(int i) {
      if (labels.length <= 1) return leftPad + chartW / 2;
      return leftPad + chartW * (i / (labels.length - 1));
    }

    double yAt(double v) {
      if (maxY <= minY) return topPad + chartH / 2;
      final t = ((v - minY) / (maxY - minY)).clamp(0.0, 1.0);
      return topPad + chartH * (1 - t);
    }

    for (final s in series) {
      final p = Path();
      for (int i = 0; i < s.y.length; i++) {
        final pt = Offset(xAt(i), yAt(s.y[i]));
        if (i == 0) p.moveTo(pt.dx, pt.dy);
        else p.lineTo(pt.dx, pt.dy);
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
      tp.text = TextSpan(text: labels[i],
          style: const TextStyle(fontSize: 10, color: Colors.black54));
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
