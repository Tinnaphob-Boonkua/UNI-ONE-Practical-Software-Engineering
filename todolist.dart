import 'package:flutter/material.dart';

void main() {
  runApp(DeansTodoApp());
}

class DeansTodoApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Dean's To-Do List",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: TodoHomePage(),
    );
  }
}

enum TimeRange { daily, weekly, monthly }

class Task {
  String id;
  String title;
  String description;
  TimeRange range;
  bool done;
  DateTime createdAt;

  Task({
    required this.id,
    required this.title,
    required this.description,
    required this.range,
    this.done = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

class TodoHomePage extends StatefulWidget {
  @override
  _TodoHomePageState createState() => _TodoHomePageState();
}

class _TodoHomePageState extends State<TodoHomePage> {
  List<Task> tasks = [];
  TimeRange? filterRange;
  bool sortIncompleteFirst = true;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  TimeRange _dialogSelectedRange = TimeRange.daily;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Color colorForRange(TimeRange r) {
    switch (r) {
      case TimeRange.daily:
        return Colors.teal.shade200;
      case TimeRange.weekly:
        return Colors.orange.shade200;
      case TimeRange.monthly:
        return Colors.blueGrey.shade200;
    }
  }

  String labelForRange(TimeRange r) {
    switch (r) {
      case TimeRange.daily:
        return 'Daily';
      case TimeRange.weekly:
        return 'Weekly';
      case TimeRange.monthly:
        return 'Monthly';
    }
  }

  String _nextId() => DateTime.now().microsecondsSinceEpoch.toString();

  /// 🧩 Responsive Dialog Wrapper
  Widget _responsiveDialog({required Widget child}) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth < 400 ? screenWidth * 0.9 : 400.0;
    return Center(
      child: Container(
        width: dialogWidth,
        child: SingleChildScrollView(child: child),
      ),
    );
  }

  /// ➕ Add New Task Dialog
  void _showAddTaskDialog() {
    _titleController.clear();
    _descController.clear();
    _dialogSelectedRange = TimeRange.daily;

    showDialog(
      context: context,
      builder: (context) {
        return _responsiveDialog(
          child: AlertDialog(
            title: const Text('Add New Task'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                  autofocus: true,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _descController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Time range: '),
                    const SizedBox(width: 8),
                    DropdownButton<TimeRange>(
                      value: _dialogSelectedRange,
                      items: TimeRange.values
                          .map((tr) => DropdownMenuItem(
                                value: tr,
                                child: Text(labelForRange(tr)),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _dialogSelectedRange = val);
                      },
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                child: const Text('Cancel'),
                onPressed: () => Navigator.of(context).pop(),
              ),
              ElevatedButton(
                child: const Text('Add'),
                onPressed: () {
                  final title = _titleController.text.trim();
                  final desc = _descController.text.trim();
                  if (title.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a title.')),
                    );
                    return;
                  }
                  setState(() {
                    tasks.add(Task(
                      id: _nextId(),
                      title: title,
                      description: desc,
                      range: _dialogSelectedRange,
                    ));
                  });
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// ❗ Delete confirmation dialog
  Future<void> _confirmDelete(Task task) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Task?'),
          content: Text(
            'Are you sure you want to delete the task:\n\n"${task.title}"?',
            style: const TextStyle(fontSize: 15),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Yes, Delete'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      setState(() => tasks.removeWhere((t) => t.id == task.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Task "${task.title}" deleted.')),
      );
    }
  }

  /// ✏️ Edit Existing Task Dialog
  void _openEditTaskDialog(Task task) {
    _titleController.text = task.title;
    _descController.text = task.description;
    _dialogSelectedRange = task.range;

    showDialog(
      context: context,
      builder: (context) {
        return _responsiveDialog(
          child: AlertDialog(
            title: const Text('Edit Task'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                  autofocus: true,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _descController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Time range: '),
                    const SizedBox(width: 8),
                    DropdownButton<TimeRange>(
                      value: _dialogSelectedRange,
                      items: TimeRange.values
                          .map((tr) => DropdownMenuItem(
                                value: tr,
                                child: Text(labelForRange(tr)),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _dialogSelectedRange = val);
                      },
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                child: const Text('Cancel'),
                onPressed: () => Navigator.of(context).pop(),
              ),
              TextButton(
                child: const Text('Delete', style: TextStyle(color: Colors.red)),
                onPressed: () async {
                  Navigator.of(context).pop(); // close edit dialog
                  await _confirmDelete(task); // show delete confirmation
                },
              ),
              ElevatedButton(
                child: const Text('Save'),
                onPressed: () {
                  final title = _titleController.text.trim();
                  final desc = _descController.text.trim();
                  if (title.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter a title.')),
                    );
                    return;
                  }
                  setState(() {
                    task.title = title;
                    task.description = desc;
                    task.range = _dialogSelectedRange;
                  });
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// 🧾 Filtered Task List
  List<Task> get _visibleTasks {
    List<Task> filtered = (filterRange == null)
        ? List.from(tasks)
        : tasks.where((t) => t.range == filterRange).toList();

    filtered.sort((a, b) {
      if (a.done == b.done) {
        return b.createdAt.compareTo(a.createdAt);
      }
      return sortIncompleteFirst
          ? (a.done ? 1 : -1)
          : (a.done ? -1 : 1);
    });
    return filtered;
  }

  String get _progressText {
    final list = filterRange == null ? tasks : tasks.where((t) => t.range == filterRange).toList();
    if (list.isEmpty) return 'No tasks';
    final doneCount = list.where((t) => t.done).length;
    return '$doneCount of ${list.length} tasks done';
  }

  Widget _buildFilterRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          ChoiceChip(
            label: const Text('All'),
            selected: filterRange == null,
            onSelected: (_) => setState(() => filterRange = null),
          ),
          const SizedBox(width: 6),
          for (var range in TimeRange.values) ...[
            ChoiceChip(
              label: Text(labelForRange(range), style: const TextStyle(fontSize: 12)),
              selected: filterRange == range,
              onSelected: (_) => setState(() => filterRange = range),
              avatar: CircleAvatar(
                backgroundColor: colorForRange(range),
                radius: 6,
              ),
            ),
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }

  Widget _buildTaskTile(Task task) {
    return Card(
      color: colorForRange(task.range).withOpacity(0.18),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        onTap: () => _openEditTaskDialog(task),
        leading: Checkbox(
          value: task.done,
          onChanged: (v) => setState(() => task.done = v ?? false),
        ),
        title: Text(
          task.title,
          style: TextStyle(
            fontSize: 15,
            decoration: task.done ? TextDecoration.lineThrough : null,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (task.description.isNotEmpty)
              Text(
                task.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13),
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: colorForRange(task.range).withOpacity(0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    labelForRange(task.range),
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'Created: ${task.createdAt.year}-${task.createdAt.month.toString().padLeft(2, '0')}-${task.createdAt.day.toString().padLeft(2, '0')}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                ),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right, size: 18),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleTasks;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Dean's To-Do List",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildFilterRow(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _progressText,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
              ),
            ),
            Expanded(
              child: visible.isEmpty
                  ? Center(
                      child: Text(
                        'No tasks. Tap + to add one.',
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 80, top: 8),
                      itemCount: visible.length,
                      itemBuilder: (context, idx) => _buildTaskTile(visible[idx]),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTaskDialog,
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 6,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _progressText,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
                ),
              ),
              Icon(Icons.menu, size: 20, color: Colors.grey.shade700),
            ],
          ),
        ),
      ),
    );
  }
}
