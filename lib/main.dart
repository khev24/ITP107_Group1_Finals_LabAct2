import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'boxes.dart';
import 'task.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();

  // TaskAdapter comes from task.g.dart (part of task.dart).
  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(TaskAdapter());
  }

  // New box name on purpose: the old 'todoBox' stored plain Maps, which
  // cannot be read as Task objects.
  boxTasks = await Hive.openBox<Task>('tasksBox');

  runApp(const MyApp());
}

/// boxes.dart declares `late Box boxTasks;` (untyped). It is opened as
/// Box<Task> in main(), so this typed view is safe.
Box<Task> get taskBox => boxTasks as Box<Task>;

// ───────────────────────── Theme colors ─────────────────────────

const Color backgroundColor = Color(0xFF0B0D12);
const Color surfaceColor = Color(0xFF181B23);
const Color cardColor = Color(0xFF20242D);

const Color cyanColor = Color(0xFF5DE7E1);
const Color orangeColor = Color(0xFFFFB45C);
const Color pinkColor = Color(0xFFD86BFF);
const Color blueColor = Color(0xFF7DA7FF);

const Color primaryText = Color(0xFFF4F5F7);
const Color secondaryText = Color(0xFFA8ADB8);
const Color borderColor = Color(0xFF303540);

// ───────────────────────── Helpers ─────────────────────────

const List<String> taskCategories = [
  'Academic',
  'Project',
  'Personal',
  'Work',
  'Other',
];

Color categoryColor(String category) {
  switch (category) {
    case 'Academic':
      return cyanColor;
    case 'Project':
      return pinkColor;
    case 'Personal':
      return orangeColor;
    case 'Work':
      return blueColor;
    default:
      return secondaryText;
  }
}

IconData categoryIcon(String category) {
  switch (category) {
    case 'Academic':
      return Icons.school_outlined;
    case 'Project':
      return Icons.folder_open_outlined;
    case 'Personal':
      return Icons.person_outline;
    case 'Work':
      return Icons.work_outline;
    default:
      return Icons.label_outline;
  }
}

String formatDate(DateTime date) {
  const months = [
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
    'December',
  ];

  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

/// Whole calendar days from [from] to [to] (negative if [to] is earlier).
/// Uses UTC so daylight-saving shifts can never skew the result.
int daysBetween(DateTime from, DateTime to) {
  final a = DateTime.utc(from.year, from.month, from.day);
  final b = DateTime.utc(to.year, to.month, to.day);
  return b.difference(a).inDays;
}

({String label, Color color}) deadlineStatus(DateTime deadline) {
  final days = daysBetween(DateTime.now(), deadline);

  if (days < 0) {
    final late = -days;
    return (
      label: 'Overdue by $late day${late == 1 ? '' : 's'}',
      color: pinkColor,
    );
  }
  if (days == 0) return (label: 'Due today', color: orangeColor);
  if (days == 1) return (label: 'Due tomorrow', color: orangeColor);
  return (label: '$days days left', color: cyanColor);
}

Widget _pickerTheme(BuildContext context, Widget? child) {
  return Theme(
    data: ThemeData.dark().copyWith(
      colorScheme: const ColorScheme.dark(
        primary: cyanColor,
        secondary: pinkColor,
        surface: surfaceColor,
      ),
    ),
    child: child!,
  );
}

// ───────────────────────── App ─────────────────────────

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const inputRadius = BorderRadius.all(Radius.circular(14));

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'To-Do List',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: backgroundColor,
        colorScheme: const ColorScheme.dark(
          primary: cyanColor,
          secondary: pinkColor,
          surface: surfaceColor,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: backgroundColor,
          elevation: 0,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: surfaceColor,
          labelStyle: TextStyle(color: secondaryText),
          hintStyle: TextStyle(color: secondaryText),
          errorStyle: TextStyle(color: pinkColor),
          prefixIconColor: cyanColor,
          border: OutlineInputBorder(
            borderRadius: inputRadius,
            borderSide: BorderSide(color: borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: inputRadius,
            borderSide: BorderSide(color: borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: inputRadius,
            borderSide: BorderSide(color: cyanColor, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: inputRadius,
            borderSide: BorderSide(color: pinkColor),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: inputRadius,
            borderSide: BorderSide(color: pinkColor, width: 2),
          ),
        ),
      ),
      home: const HomePage(),
    );
  }
}

// ───────────────────────── Home page ─────────────────────────

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  /// Keys swiped away but whose disk delete has not finished yet. Hiding them
  /// immediately keeps Dismissible happy (it must leave the tree right away).
  final Set<dynamic> _removedKeys = <dynamic>{};

  String _selectedCategory = 'All';

  bool get _hasFilters => _selectedCategory != 'All';

  // ───────────── Actions ─────────────

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _resetFilters() {
    setState(() => _selectedCategory = 'All');
  }

  /// Opens the form. [key] + [existing] = edit mode, otherwise add mode.
  Future<void> _openTaskForm({dynamic key, Task? existing}) async {
    final Task? result = await showDialog<Task>(
      context: context,
      builder: (dialogContext) => TaskFormDialog(existing: existing),
    );

    if (result == null) return;

    if (key == null) {
      await taskBox.add(result);
      _showMessage('Task added successfully.');
    } else {
      await taskBox.put(key, result);
      _showMessage('Task updated successfully.');
    }
  }

  Future<bool> _confirmDelete(Task task) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: surfaceColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text(
            'Delete Task?',
            style: TextStyle(
              color: primaryText,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Delete "${task.taskName}"?',
            style: const TextStyle(color: secondaryText),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: secondaryText),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: pinkColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    return confirmed ?? false;
  }

  // ───────────── Filtering / grouping ─────────────

  List<String> _categoryList(List<MapEntry<dynamic, Task>> entries) {
    final list = <String>[...taskCategories];
    for (final e in entries) {
      if (!list.contains(e.value.category)) list.add(e.value.category);
    }
    return list;
  }

  bool _matches(Task task, String selectedCategory) {
    return selectedCategory == 'All' || task.category == selectedCategory;
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 18) return 'Good Afternoon';
    return 'Good Evening';
  }

  // ───────────── Small shared widgets ─────────────

  Widget _chip({
    required String label,
    required Color color,
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, Color color, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: secondaryText, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(
    String title, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: primaryText,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          if (actionLabel != null)
            GestureDetector(
              onTap: onAction,
              child: Text(
                actionLabel,
                style: const TextStyle(
                  color: orangeColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ───────────── Header / search / tabs ─────────────

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 50,
          height: 50,
          padding: const EdgeInsets.all(2.5),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: [cyanColor, pinkColor]),
          ),
          child: Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: surfaceColor,
            ),
            child: const Icon(Icons.checklist_rounded, color: cyanColor),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _greeting(),
                style: const TextStyle(color: secondaryText, fontSize: 13),
              ),
              const SizedBox(height: 2),
              const Text(
                "My To-Do's",
                style: TextStyle(
                  color: primaryText,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
        Tooltip(
          message: 'Clear filters',
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: _hasFilters ? _resetFilters : null,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: surfaceColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: _hasFilters ? cyanColor : borderColor,
                ),
              ),
              child: Icon(
                Icons.filter_alt_off_outlined,
                color: _hasFilters ? cyanColor : secondaryText,
                size: 22,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryTabs(
    List<MapEntry<dynamic, Task>> entries,
    List<String> categories,
    String selected,
  ) {
    final tabs = <String>['All', ...categories];

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final name = tabs[index];
          final count = name == 'All'
              ? entries.length
              : entries.where((e) => e.value.category == name).length;
          final isSelected = name == selected;
          final color = name == 'All' ? cyanColor : categoryColor(name);

          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = name),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: isSelected
                    ? color.withValues(alpha: 0.15)
                    : surfaceColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected ? color : borderColor,
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    name == 'All' ? Icons.grid_view_rounded : categoryIcon(name),
                    size: 18,
                    color: isSelected ? color : secondaryText,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    name,
                    style: TextStyle(
                      color: isSelected ? color : secondaryText,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$count',
                    style: TextStyle(
                      color: isSelected ? color : secondaryText,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ───────────── Hero / category overview / schedule ─────────────

  Widget _heroStat(String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(color: secondaryText, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard(List<MapEntry<dynamic, Task>> entries) {
    final now = DateTime.now();
    final total = entries.length;
    final overdue = entries
        .where((e) => daysBetween(now, e.value.deadlineDate) < 0)
        .length;
    final dueToday = entries
        .where((e) => daysBetween(now, e.value.deadlineDate) == 0)
        .length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF183C43), Color(0xFF24212F)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Manage Your Daily\nTasks & Goals.',
            style: TextStyle(
              color: primaryText,
              fontSize: 24,
              height: 1.2,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Track and complete your routine tasks efficiently.',
            style: TextStyle(color: secondaryText, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _heroStat('$total', 'Total', cyanColor),
              const SizedBox(width: 10),
              _heroStat('$dueToday', 'Due today', orangeColor),
              const SizedBox(width: 10),
              _heroStat('$overdue', 'Overdue', pinkColor),
            ],
          ),
        ],
      ),
    );
  }

  // ───────────── Task list ─────────────

  Widget _buildGroupHeader(String category, int count) {
    final accent = categoryColor(category);

    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12, top: 6),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(categoryIcon(category), color: accent, size: 17),
          ),
          const SizedBox(width: 10),
          Text(
            category,
            style: const TextStyle(
              color: primaryText,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          _chip(label: '$count', color: accent),
        ],
      ),
    );
  }

  List<Widget> _buildGroupedTasks(
    List<MapEntry<dynamic, Task>> filtered,
    List<String> categories,
  ) {
    final widgets = <Widget>[];

    for (final category in categories) {
      final items =
          filtered.where((e) => e.value.category == category).toList()
            ..sort(
              (a, b) => a.value.deadlineDate.compareTo(b.value.deadlineDate),
            );
      if (items.isEmpty) continue;

      widgets.add(_buildGroupHeader(category, items.length));
      for (final entry in items) {
        widgets.add(buildTaskCard(entry.key, entry.value));
      }
    }

    return widgets;
  }

  Widget buildTaskCard(dynamic key, Task task) {
    final Color accent = categoryColor(task.category);
    final status = deadlineStatus(task.deadlineDate);

    return Dismissible(
      key: ValueKey(key),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) => _confirmDelete(task),
      onDismissed: (direction) async {
        setState(() => _removedKeys.add(key));
        await taskBox.delete(key);
        _removedKeys.remove(key);
        _showMessage('Task deleted successfully.');
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.only(right: 24),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: pinkColor,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(
          Icons.delete_outline,
          color: Colors.white,
          size: 28,
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Padding(
            padding: const EdgeInsets.all(17),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: accent.withValues(alpha: 0.35)),
                  ),
                  child: Icon(
                    categoryIcon(task.category),
                    color: accent,
                    size: 25,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.taskName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: primaryText,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _chip(
                        label: status.label,
                        color: status.color,
                        icon: Icons.schedule,
                      ),
                      if (task.description.trim().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Icon(
                                Icons.notes_outlined,
                                size: 14,
                                color: blueColor,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                task.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: secondaryText,
                                  fontSize: 13,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 4),
                      _infoRow(
                        Icons.person_outline,
                        cyanColor,
                        task.studentName,
                      ),
                      _infoRow(
                        Icons.location_on_outlined,
                        pinkColor,
                        task.location,
                      ),
                      _infoRow(
                        Icons.play_circle_outline,
                        orangeColor,
                        'Start: ${formatDate(task.startDate)}',
                      ),
                      _infoRow(
                        Icons.flag_outlined,
                        orangeColor,
                        'Deadline: ${formatDate(task.deadlineDate)}',
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Edit task',
                  onPressed: () => _openTaskForm(key: key, existing: task),
                  icon: const Icon(
                    Icons.edit_outlined,
                    color: secondaryText,
                  ),
                ),
              ],
            ),
          ),
      ),
    );
  }

  Widget _buildMessageState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
      child: Column(
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: cyanColor.withValues(alpha: 0.10),
              shape: BoxShape.circle,
              border: Border.all(color: cyanColor.withValues(alpha: 0.3)),
            ),
            child: Icon(icon, color: cyanColor, size: 45),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: const TextStyle(
              color: primaryText,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: secondaryText, fontSize: 14),
          ),
        ],
      ),
    );
  }

  // ───────────── Build ─────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: ValueListenableBuilder<Box<Task>>(
          valueListenable: taskBox.listenable(),
          builder: (context, box, child) {
            // Pair each Hive key with its Task so edit/delete use the real
            // key instead of the list position.
            final entries = <MapEntry<dynamic, Task>>[];
            for (final key in box.keys) {
              if (_removedKeys.contains(key)) continue;
              final task = box.get(key);
              if (task != null) entries.add(MapEntry(key, task));
            }

            final categories = _categoryList(entries);
            final selected = (_selectedCategory == 'All' ||
                    categories.contains(_selectedCategory))
                ? _selectedCategory
                : 'All';

            final filtered =
                entries.where((e) => _matches(e.value, selected)).toList();

            return ListView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 110),
              children: [
                _buildHeader(),
                const SizedBox(height: 18),
                _buildCategoryTabs(entries, categories, selected),
                const SizedBox(height: 18),
                _buildHeroCard(entries),
                const SizedBox(height: 24),
                if (entries.isEmpty)
                  _buildMessageState(
                    icon: Icons.checklist_rounded,
                    title: 'No tasks yet',
                    subtitle: 'Tap the + button to add your first task.',
                  )
                else if (filtered.isEmpty)
                  _buildMessageState(
                    icon: Icons.folder_open_outlined,
                    title: 'No tasks here',
                    subtitle: 'There are no tasks in this category yet.',
                  )
                else ...[
                  _sectionTitle(
                    selected == 'All' ? 'All Tasks' : '$selected Tasks',
                  ),
                  ..._buildGroupedTasks(filtered, categories),
                  const SizedBox(height: 10),
                  const Center(
                    child: Text(
                      'Swipe a task left to delete • Tap the pencil to edit',
                      style: TextStyle(color: secondaryText, fontSize: 12),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openTaskForm(),
        tooltip: 'Add task',
        backgroundColor: orangeColor,
        foregroundColor: backgroundColor,
        elevation: 8,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, size: 30),
      ),
    );
  }
}

// ───────────────────────── Add / Edit dialog ─────────────────────────

/// One dialog for both adding and editing. It owns (and disposes) its own
/// controllers and returns a complete [Task] when the user saves.
class TaskFormDialog extends StatefulWidget {
  const TaskFormDialog({super.key, this.existing});

  final Task? existing;

  @override
  State<TaskFormDialog> createState() => _TaskFormDialogState();
}

class _TaskFormDialogState extends State<TaskFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _studentNameController;
  late final TextEditingController _taskNameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _locationController;

  late String _category;
  late DateTime _startDate;
  late DateTime _deadlineDate;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();

    final task = widget.existing;
    final today = dateOnly(DateTime.now());

    _studentNameController = TextEditingController(
      text: task?.studentName ?? '',
    );
    _taskNameController = TextEditingController(text: task?.taskName ?? '');
    _descriptionController = TextEditingController(
      text: task?.description ?? '',
    );
    _locationController = TextEditingController(text: task?.location ?? '');

    _category = task?.category ?? taskCategories.first;
    _startDate = task?.startDate ?? today;
    _deadlineDate = task?.deadlineDate ?? today;

    // Guard against inconsistent stored data.
    if (_deadlineDate.isBefore(_startDate)) _deadlineDate = _startDate;
  }

  @override
  void dispose() {
    _studentNameController.dispose();
    _taskNameController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  String? Function(String?) _required(String label) {
    return (value) {
      if (value == null || value.trim().isEmpty) {
        return '$label cannot be empty.';
      }
      return null;
    };
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: _pickerTheme,
    );

    if (picked == null) return;

    setState(() {
      _startDate = picked;
      // The deadline can never be earlier than the start date.
      if (_deadlineDate.isBefore(_startDate)) _deadlineDate = _startDate;
    });
  }

  Future<void> _pickDeadlineDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadlineDate,
      firstDate: _startDate,
      lastDate: DateTime(2100),
      builder: _pickerTheme,
    );

    if (picked == null) return;

    setState(() => _deadlineDate = picked);
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    Navigator.pop(
      context,
      Task(
        studentName: _studentNameController.text.trim(),
        taskName: _taskNameController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _category,
        startDate: _startDate,
        deadlineDate: _deadlineDate,
        location: _locationController.text.trim(),
      ),
    );
  }

  Widget _dateTile({
    required String label,
    required DateTime date,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined, color: cyanColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: secondaryText,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    formatDate(date),
                    style: const TextStyle(
                      color: primaryText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: secondaryText),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // If an older task has a category that is not in the list, keep it
    // selectable so the dropdown never crashes.
    final categories = taskCategories.contains(_category)
        ? taskCategories
        : [...taskCategories, _category];

    return AlertDialog(
      backgroundColor: surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
      ),
      title: Text(
        _isEditing ? 'Edit Task' : 'Add New Task',
        style: const TextStyle(
          color: primaryText,
          fontWeight: FontWeight.bold,
          fontSize: 22,
        ),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _studentNameController,
                  autofocus: !_isEditing,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  style: const TextStyle(color: primaryText),
                  decoration: const InputDecoration(
                    labelText: 'Student Name',
                    hintText: 'Enter student name...',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: _required('Student name'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _taskNameController,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.next,
                  style: const TextStyle(color: primaryText),
                  decoration: const InputDecoration(
                    labelText: 'Task Name',
                    hintText: 'Enter your task...',
                    prefixIcon: Icon(Icons.check_circle_outline),
                  ),
                  validator: _required('Task name'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  textCapitalization: TextCapitalization.sentences,
                  keyboardType: TextInputType.multiline,
                  minLines: 2,
                  maxLines: 4,
                  style: const TextStyle(color: primaryText),
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Describe the task...',
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                  validator: _required('Description'),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _category,
                  isExpanded: true,
                  dropdownColor: cardColor,
                  iconEnabledColor: secondaryText,
                  style: const TextStyle(color: primaryText, fontSize: 16),
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: [
                    for (final category in categories)
                      DropdownMenuItem<String>(
                        value: category,
                        child: Text(category),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _category = value);
                  },
                ),
                const SizedBox(height: 16),
                _dateTile(
                  label: 'Start Date',
                  date: _startDate,
                  onTap: _pickStartDate,
                ),
                const SizedBox(height: 16),
                _dateTile(
                  label: 'Deadline Date',
                  date: _deadlineDate,
                  onTap: _pickDeadlineDate,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _locationController,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  style: const TextStyle(color: primaryText),
                  decoration: const InputDecoration(
                    labelText: 'Location',
                    hintText: 'Where will this be done?',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                  validator: _required('Location'),
                  onFieldSubmitted: (_) => _submit(),
                ),
              ],
            ),
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Cancel',
            style: TextStyle(color: secondaryText),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: cyanColor,
            foregroundColor: backgroundColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: _submit,
          child: Text(
            _isEditing ? 'Save Changes' : 'Add Task',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}