// main.dart
import 'package:flutter/material.dart';

void main() {
  runApp(DeansTodoApp());
}

/// Main app widget
class DeansTodoApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Dean's To-Do List",
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: TodoHomePage(),
    );
  }
}

/// Enum for time ranges
enum TimeRange { daily, weekly, monthly }

/// Simple Task model
class Task {
  String id; // simple id (for example purposes)
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

/// Home / main screen
class TodoHomePage extends StatefulWidget {
  @override
  _TodoHomePageState createState() => _TodoHomePageState();
}

class _TodoHomePageState extends State<TodoHomePage> {
  // Local in-memory list of tasks
  List<Task> tasks = [];

  // Current filter (null means show all)
  TimeRange? filterRange;

  // Whether to sort tasks: incomplete first
  bool sortIncompleteFirst = true;

  // Controllers used in dialogs (re-used)
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  TimeRange _dialogSelectedRange = TimeRange.daily;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  // Helper: color theme for a range
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

  // Generate a simple id
  String _nextId() {
    return DateTime.now().microsecondsSinceEpoch.toString();
  }

  // Add task (opens dialog)
  void _openAddTaskDialog() {
    _titleController.clear();
    _descController.clear();
    _dialogSelectedRange = TimeRange.daily;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Add Task'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _titleController,
                  decoration: InputDecoration(labelText: 'Title'),
                  autofocus: true,
                ),
                SizedBox(height: 8),
                TextField(
                  controller: _descController,
                  decoration: InputDecoration(labelText: 'Description'),
                  maxLines: 3,
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Text('Time range: '),
                    SizedBox(width: 8),
                    DropdownButton<TimeRange>(
                      value: _dialogSelectedRange,
                      items: TimeRange.values
                          .map((tr) => DropdownMenuItem(
                                value: tr,
                                child: Text(labelForRange(tr)),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val == null) return;
                        setState(() {
                          _dialogSelectedRange = val;
                        });
                        // Force rebuild of dialog's state
                        (context as Element).markNeedsBuild();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: Text('Add'),
              onPressed: () {
                final title = _titleController.text.trim();
                final desc = _descController.text.trim();
                if (title.isEmpty) {
                  // simple validation
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Please enter a title.')),
                  );
                  return;
                }
                setState(() {
                  tasks.add(Task(
                    id: _nextId(),
                    title: title,
                    description: desc,
                    range: _dialogSelectedRange,
                    done: false,
                  ));
                });
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // Edit existing task (dialog) - also offers delete
  void _openEditTaskDialog(Task task) {
    _titleController.text = task.title;
    _descController.text = task.description;
    _dialogSelectedRange = task.range;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Edit Task'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _titleController,
                  decoration: InputDecoration(labelText: 'Title'),
                  autofocus: true,
                ),
                SizedBox(height: 8),
                TextField(
                  controller: _descController,
                  decoration: InputDecoration(labelText: 'Description'),
                  maxLines: 3,
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Text('Time range: '),
                    SizedBox(width: 8),
                    DropdownButton<TimeRange>(
                      value: _dialogSelectedRange,
                      items: TimeRange.values
                          .map((tr) => DropdownMenuItem(
                                value: tr,
                                child: Text(labelForRange(tr)),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val == null) return;
                        setState(() {
                          _dialogSelectedRange = val;
                        });
                        (context as Element).markNeedsBuild();
                      },
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Checkbox(
                      value: task.done,
                      onChanged: (v) {
                        setState(() {
                          task.done = v ?? false;
                        });
                        // update dialog UI
                        (context as Element).markNeedsBuild();
                      },
                    ),
                    Text('Done'),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: Text(
                'Delete',
                style: TextStyle(color: Colors.red),
              ),
              onPressed: () {
                // Confirm delete
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('Delete Task?'),
                    content: Text('Are you sure you want to delete this task?'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text('Cancel')),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor:  Colors.red),
                        onPressed: () {
                          setState(() {
                            tasks.removeWhere((t) => t.id == task.id);
                          });
                          Navigator.of(context).pop(); // close confirm
                          Navigator.of(context).pop(); // close edit dialog
                        },
                        child: Text('Delete'),
                      ),
                    ],
                  ),
                );
              },
            ),
            TextButton(
              child: Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: Text('Save'),
              onPressed: () {
                final title = _titleController.text.trim();
                final desc = _descController.text.trim();
                if (title.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Please enter a title.')),
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
        );
      },
    );
  }

  // Toggle done status
  void _toggleDone(Task task, bool? value) {
    setState(() {
      task.done = value ?? false;
    });
  }

  // Filtered & sorted list presented to UI
  List<Task> get _visibleTasks {
    List<Task> filtered = (filterRange == null)
        ? List.from(tasks)
        : tasks.where((t) => t.range == filterRange).toList();

    // Optional sorting: incomplete first (or inverse)
    filtered.sort((a, b) {
      if (sortIncompleteFirst) {
        // incomplete (done=false) should come before done=true
        if (a.done == b.done) return b.createdAt.compareTo(a.createdAt);
        return a.done ? 1 : -1;
      } else {
        if (a.done == b.done) return b.createdAt.compareTo(a.createdAt);
        return a.done ? -1 : 1;
      }
    });

    return filtered;
  }

  // Progress counter string
  String get _progressText {
    final list = filterRange == null ? tasks : tasks.where((t) => t.range == filterRange).toList();
    if (list.isEmpty) return 'No tasks';
    final doneCount = list.where((t) => t.done).length;
    return '$doneCount of ${list.length} tasks done';
  }

  // Build filter chips row
  Widget _buildFilterRow() {
    return Wrap(
      spacing: 8,
      children: [
        ChoiceChip(
          label: Text('All'),
          selected: filterRange == null,
          onSelected: (_) => setState(() => filterRange = null),
        ),
        ChoiceChip(
          label: Text('Daily'),
          selected: filterRange == TimeRange.daily,
          onSelected: (_) => setState(() => filterRange = TimeRange.daily),
          avatar: CircleAvatar(backgroundColor: colorForRange(TimeRange.daily), radius: 8),
        ),
        ChoiceChip(
          label: Text('Weekly'),
          selected: filterRange == TimeRange.weekly,
          onSelected: (_) => setState(() => filterRange = TimeRange.weekly),
          avatar: CircleAvatar(backgroundColor: colorForRange(TimeRange.weekly), radius: 8),
        ),
        ChoiceChip(
          label: Text('Monthly'),
          selected: filterRange == TimeRange.monthly,
          onSelected: (_) => setState(() => filterRange = TimeRange.monthly),
          avatar: CircleAvatar(backgroundColor: colorForRange(TimeRange.monthly), radius: 8),
        ),
        SizedBox(width: 10),
        // Sorting toggle
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Sort: '),
            IconButton(
              tooltip: sortIncompleteFirst ? 'Incomplete first' : 'Completed first',
              onPressed: () => setState(() => sortIncompleteFirst = !sortIncompleteFirst),
              icon: Icon(sortIncompleteFirst ? Icons.filter_list : Icons.filter_list_off),
            )
          ],
        ),
      ],
    );
  }

  Widget _buildTaskTile(Task task) {
    return Card(
      color: colorForRange(task.range)?.withOpacity(0.20),
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: ListTile(
        onTap: () => _openEditTaskDialog(task),
        leading: Checkbox(
          value: task.done,
          onChanged: (v) => _toggleDone(task, v),
        ),
        title: Text(
          task.title,
          style: TextStyle(
            decoration: task.done ? TextDecoration.lineThrough : TextDecoration.none,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (task.description.isNotEmpty) Text(task.description),
            SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorForRange(task.range)?.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    labelForRange(task.range),
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'Created: ${task.createdAt.year}-${task.createdAt.month.toString().padLeft(2, '0')}-${task.createdAt.day.toString().padLeft(2, '0')}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
            ),
          ],
        ),
        trailing: Icon(Icons.edit),
      ),
    );
  }

  // Simple sample data (optional)
  void _addSampleTasks() {
    setState(() {
      tasks.addAll([
        Task(
            id: _nextId(),
            title: 'Approve weekly meeting agenda',
            description: 'Review items and attach documents',
            range: TimeRange.weekly,
            done: false),
        Task(
            id: _nextId(),
            title: 'Sign monthly budget report',
            description: 'Check expenses before signing',
            range: TimeRange.monthly,
            done: false),
        Task(
            id: _nextId(),
            title: 'Daily email review',
            description: 'Respond to high-priority emails',
            range: TimeRange.daily,
            done: true),
      ]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleTasks;
    return Scaffold(
      appBar: AppBar(
        title: Text("Dean's To-Do List"),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8),
            child: Row(
              children: [
                Expanded(child: Text(_progressText, style: TextStyle(color: Colors.white70))),
                IconButton(
                  tooltip: 'Add sample tasks',
                  icon: Icon(Icons.auto_fix_high_outlined),
                  onPressed: _addSampleTasks,
                ),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: _buildFilterRow(),
          ),
          SizedBox(height: 8),
          Expanded(
            child: visible.isEmpty
                ? Center(
                    child: Text(
                      'No tasks. Tap + to add one.',
                      style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.only(bottom: 16, top: 8),
                    itemCount: visible.length,
                    itemBuilder: (context, idx) {
                      final task = visible[idx];
                      return _buildTaskTile(task);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddTaskDialog,
        child: Icon(Icons.add),
        tooltip: 'Add Task',
      ),
    );
  }
}
