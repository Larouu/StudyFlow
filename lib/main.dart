import 'package:flutter/material.dart';

void main() => runApp(const StudyFlowApp());

class StudyFlowApp extends StatelessWidget {
  const StudyFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF3157D5),
      brightness: Brightness.light,
    );
    return MaterialApp(
      title: 'StudyFlow',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: scheme,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF7F8FC),
        cardTheme: const CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(18)),
          ),
        ),
      ),
      home: const StudyFlowShell(),
    );
  }
}

class StudyFlowShell extends StatefulWidget {
  const StudyFlowShell({super.key});

  @override
  State<StudyFlowShell> createState() => _StudyFlowShellState();
}

class _StudyFlowShellState extends State<StudyFlowShell> {
  int _selectedIndex = 0;
  bool _darkMode = false;

  static const _modules = <ModuleItem>[
    ModuleItem('Overview', Icons.grid_view_rounded),
    ModuleItem('Teams', Icons.groups_rounded),
    ModuleItem('Projects', Icons.view_kanban_rounded),
    ModuleItem('Tasks', Icons.check_circle_outline_rounded),
    ModuleItem('Calendar & reports', Icons.calendar_month_rounded),
    ModuleItem('Chat', Icons.forum_outlined),
    ModuleItem('Files', Icons.folder_outlined),
    ModuleItem('Training & coaching', Icons.school_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 850;
    final theme = Theme.of(context);
    return Theme(
      data: _darkMode
          ? ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF8DA8FF),
                brightness: Brightness.dark,
              ),
              useMaterial3: true,
              cardTheme: const CardThemeData(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(18)),
                ),
              ),
            )
          : theme,
      child: Scaffold(
        drawer: isCompact ? _buildDrawer(context) : null,
        appBar: isCompact
            ? AppBar(
                title: const Text('StudyFlow'),
                actions: [_buildThemeButton()],
              )
            : null,
        body: Row(
          children: [
            if (!isCompact) _buildRail(context),
            Expanded(
              child: _selectedIndex == 0
                  ? _Dashboard(onOpenModule: _selectModule)
                  : ModulePage(module: _modules[_selectedIndex]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRail(BuildContext context) {
    return NavigationRail(
      selectedIndex: _selectedIndex,
      onDestinationSelected: _selectModule,
      extended: MediaQuery.sizeOf(context).width >= 1150,
      leading: Padding(
        padding: const EdgeInsets.fromLTRB(8, 24, 8, 28),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: const Icon(Icons.auto_awesome, color: Colors.white),
            ),
            if (MediaQuery.sizeOf(context).width >= 1150) ...[
              const SizedBox(width: 10),
              const Text(
                'StudyFlow',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
            ],
          ],
        ),
      ),
      trailing: Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          children: [
            _buildThemeButton(),
            const SizedBox(height: 8),
            const CircleAvatar(
              radius: 18,
              backgroundColor: Color(0xFFFFD8B5),
              child: Text('AM'),
            ),
          ],
        ),
      ),
      destinations: [
        for (final module in _modules)
          NavigationRailDestination(
            icon: Icon(module.icon),
            selectedIcon: Icon(module.icon),
            label: Text(module.name),
          ),
      ],
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return NavigationDrawer(
      selectedIndex: _selectedIndex,
      onDestinationSelected: (index) {
        Navigator.pop(context);
        _selectModule(index);
      },
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(28, 28, 28, 18),
          child: Text(
            'StudyFlow',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
        ),
        for (final module in _modules)
          NavigationDrawerDestination(
            icon: Icon(module.icon),
            selectedIcon: Icon(module.icon),
            label: Text(_drawerLabel(module.name)),
          ),
      ],
    );
  }

  Widget _buildThemeButton() {
    return IconButton(
      tooltip: 'Toggle theme',
      onPressed: () => setState(() => _darkMode = !_darkMode),
      icon: Icon(
        _darkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
      ),
    );
  }

  void _selectModule(int index) => setState(() => _selectedIndex = index);
}

class _Dashboard extends StatelessWidget {
  const _Dashboard({required this.onOpenModule});

  final ValueChanged<int> onOpenModule;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final padding = width < 600 ? 20.0 : 36.0;
    return ListView(
      padding: EdgeInsets.fromLTRB(padding, 34, padding, 40),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Good morning, Alex',
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 8),
                  Text('Here is what is happening with your teams today.'),
                ],
              ),
            ),
            if (width >= 600)
              FilledButton.icon(
                onPressed: null,
                icon: Icon(Icons.add),
                label: Text('New item'),
              ),
          ],
        ),
        const SizedBox(height: 30),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth > 900
                ? 4
                : constraints.maxWidth > 550
                ? 2
                : 1;
            return GridView.count(
              crossAxisCount: columns,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 2.2,
              children: const [
                MetricCard(
                  'Active projects',
                  '4',
                  Icons.rocket_launch_outlined,
                  Color(0xFFE7EEFF),
                ),
                MetricCard(
                  'Tasks completed',
                  '68%',
                  Icons.check_circle_outline,
                  Color(0xFFE1F7EE),
                ),
                MetricCard(
                  'Due this week',
                  '7',
                  Icons.schedule_outlined,
                  Color(0xFFFFF1D9),
                ),
                MetricCard(
                  'Team members',
                  '12',
                  Icons.groups_outlined,
                  Color(0xFFF5E7FF),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 800) {
              return Column(
                children: [
                  _buildProjects(context, onOpenModule),
                  const SizedBox(height: 18),
                  _buildDeadlines(context),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildProjects(context, onOpenModule)),
                const SizedBox(width: 18),
                Expanded(child: _buildDeadlines(context)),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildProjects(BuildContext context, ValueChanged<int> onOpenModule) {
    return _Panel(
      title: 'Your projects',
      action: TextButton(
        onPressed: () => onOpenModule(2),
        child: const Text('View all'),
      ),
      child: Column(
        children: [
          _ProjectRow(
            'StudyFlow mobile app',
            '12 tasks',
            0.72,
            const Color(0xFF3157D5),
          ),
          _ProjectRow(
            'Data structures course',
            '8 tasks',
            0.45,
            const Color(0xFF7C5CFC),
          ),
          _ProjectRow(
            'Hackathon 2026',
            '5 tasks',
            0.88,
            const Color(0xFF10A873),
          ),
        ],
      ),
    );
  }

  Widget _buildDeadlines(BuildContext context) {
    return _Panel(
      title: 'Upcoming deadlines',
      action: TextButton(onPressed: () {}, child: const Text('Calendar')),
      child: const Column(
        children: [
          _DeadlineRow(
            'UX review',
            'Today, 4:00 PM',
            Icons.design_services_outlined,
            Color(0xFFFF8A65),
          ),
          _DeadlineRow(
            'Sprint demo',
            'Tomorrow, 10:00 AM',
            Icons.present_to_all_outlined,
            Color(0xFF7C5CFC),
          ),
          _DeadlineRow(
            'Final report',
            'Friday, Nov 6',
            Icons.description_outlined,
            Color(0xFF10A873),
          ),
        ],
      ),
    );
  }
}

class ModulePage extends StatelessWidget {
  const ModulePage({required this.module, super.key});

  final ModuleItem module;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(36),
      children: [
        Row(
          children: [
            Icon(
              module.icon,
              size: 30,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 14),
            Text(
              module.name,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Manage ${module.name.toLowerCase()} in one collaborative workspace.',
        ),
        const SizedBox(height: 28),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              children: [
                Icon(
                  module.icon,
                  size: 56,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 14),
                Text(
                  '${module.name} workspace',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  'This module is connected to the StudyFlow domain model. '
                  'Firebase repositories and role-based permissions are documented in docs/.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.add),
                  label: Text(
                    'Create ${module.name == 'Calendar & reports' ? 'event' : 'new item'}',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class MetricCard extends StatelessWidget {
  const MetricCard(this.label, this.value, this.icon, this.color, {super.key});
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(icon, size: 28, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(label),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.action,
    required this.child,
  });
  final String title;
  final Widget action;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 14),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                action,
              ],
            ),
            const Divider(height: 20),
            child,
          ],
        ),
      ),
    );
  }
}

class _ProjectRow extends StatelessWidget {
  const _ProjectRow(this.name, this.tasks, this.progress, this.color);
  final String name;
  final String tasks;
  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Text(tasks, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(width: 12),
              Text('${(progress * 100).round()}%'),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            color: color,
            minHeight: 7,
            borderRadius: BorderRadius.circular(8),
          ),
        ],
      ),
    );
  }
}

class _DeadlineRow extends StatelessWidget {
  const _DeadlineRow(this.title, this.date, this.icon, this.color);
  final String title;
  final String date;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: color.withAlpha(35),
        foregroundColor: color,
        child: Icon(icon, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(date),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}

class ModuleItem {
  const ModuleItem(this.name, this.icon);
  final String name;
  final IconData icon;
}

String _drawerLabel(String name) {
  switch (name) {
    case 'Calendar & reports':
      return 'Calendar';
    case 'Training & coaching':
      return 'Training';
    default:
      return name;
  }
}
