import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';


class AddEditEventPage extends StatefulWidget {
  static const routeName = '/add-edit';
  const AddEditEventPage({super.key});
  @override
  State<AddEditEventPage> createState() => _AddEditEventPageState();
}

class _AddEditEventPageState extends State<AddEditEventPage> {
  final _form = GlobalKey<FormState>();
  final _dateCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _periodCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  String? _docId;
  TimeOfDay? _startTod;
  TimeOfDay? _endTod;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final arg = ModalRoute.of(context)?.settings.arguments;
    if (arg is Map && _docId == null) {
      _docId = arg['id'] as String?;
      _titleCtrl.text = (arg['title'] ?? '').toString();
      _descCtrl.text  = (arg['description_'] ?? '').toString();
      _locationCtrl.text = (arg['location_id'] ?? '').toString();
      final ds = (arg['date_'] ?? '').toString();
      if (ds.isNotEmpty) _dateCtrl.text = ds;

      DateTime? _parse(dynamic v) =>
          v is Timestamp ? v.toDate() : (v is String ? DateTime.tryParse(v) : null);
      final s = _parse(arg['start_']);
      final e = _parse(arg['end_']);
      if (s != null) _startTod = TimeOfDay(hour: s.hour, minute: s.minute);
      if (e != null) _endTod   = TimeOfDay(hour: e.hour, minute: e.minute);
      if (_startTod != null && _endTod != null) {
        _periodCtrl.text = '${_startTod!.format(context)} - ${_endTod!.format(context)}';
      }
    }
  }

  @override
  void dispose() {
    _dateCtrl.dispose(); _titleCtrl.dispose(); _locationCtrl.dispose();
    _periodCtrl.dispose(); _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = _dateCtrl.text.isNotEmpty ? DateTime.parse(_dateCtrl.text) : now;
    final d = await showDatePicker(
      context: context, firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 3), initialDate: initial,
    );
    if (d != null) _dateCtrl.text = d.toIso8601String().split('T').first;
  }

  Future<void> _pickPeriod() async {
    final s = await showTimePicker(
      context: context, initialTime: _startTod ?? const TimeOfDay(hour: 9, minute: 0));
    if (s == null) return;
    final e = await showTimePicker(
      context: context, initialTime: _endTod ?? const TimeOfDay(hour: 10, minute: 0));
    if (e == null) return;
    setState(() { _startTod = s; _endTod = e;
      _periodCtrl.text = '${s.format(context)} - ${e.format(context)}'; });
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = _docId != null;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        title: Text(isEdit ? 'Edit Event' : 'Add Events'),
        actions: [
          if (isEdit)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                await FirebaseFirestore.instance.collection('events').doc(_docId).delete();
                if (!mounted) return; Navigator.pop(context, true);
              },
            )
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _form,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _Field(label: 'Event Date', hint: 'YYYY-MM-DD',
                        controller: _dateCtrl, readOnly: true, onTap: _pickDate),
                      _Field(label: 'Event Name', hint: 'ex: Penguin Dinner', controller: _titleCtrl),
                      _Field(label: 'Event Location (location_id)', hint: 'ex: 1',
                        controller: _locationCtrl, keyboard: TextInputType.text),
                      _Field(label: 'Event Period', hint: '09:00 - 10:00',
                        controller: _periodCtrl, readOnly: true, onTap: _pickPeriod),
                      _Field(label: 'Description', hint: 'Optional', controller: _descCtrl, maxLines: 3),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton(
                          onPressed: _save,
                          child: Text(isEdit ? 'save' : 'add'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_dateCtrl.text.trim().isEmpty) return;

    final date = DateTime.parse(_dateCtrl.text.trim());
    DateTime? compose(TimeOfDay? t) =>
        t == null ? null : DateTime(date.year, date.month, date.day, t.hour, t.minute);

    final payload = <String, dynamic>{
      'title': _titleCtrl.text.trim().isEmpty ? 'Untitled' : _titleCtrl.text.trim(),
      'description_': _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      'date_': _dateCtrl.text.trim(),                 // keep as YYYY-MM-DD
      'location_id': _locationCtrl.text.trim().isEmpty ? null : _locationCtrl.text.trim(),
      'type': 'other',
      'start_': compose(_startTod) == null ? null : Timestamp.fromDate(compose(_startTod)!),
      'end_':   compose(_endTod)   == null ? null : Timestamp.fromDate(compose(_endTod)!),
    };

    final col = FirebaseFirestore.instance.collection('events');
    if (_docId == null) {
      await col.add(payload);
    } else {
      await col.doc(_docId).update(payload);
    }
    if (!mounted) return; Navigator.pop(context, true);
  }
}

class _Field extends StatelessWidget {
  final String label, hint;
  final TextEditingController controller;
  final bool readOnly;
  final TextInputType? keyboard;
  final int maxLines;
  final VoidCallback? onTap;

  const _Field({
    required this.label,
    required this.hint,
    required this.controller,
    this.readOnly = false,
    this.keyboard,
    this.maxLines = 1,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          TextFormField(
            controller: controller,
            readOnly: readOnly,
            onTap: onTap,
            maxLines: maxLines,
            keyboardType: keyboard,
            decoration: InputDecoration(
              hintText: hint,
              filled: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
        ],
      ),
    );
  }
}
