import 'package:flutter/material.dart';

import '../planner_controller.dart';
import '../schedule.dart';
import '../theme.dart';
import 'history_page.dart';
import 'plan_page.dart';
import 'run_page.dart';
import 'today_page.dart';

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with WidgetsBindingObserver {
  int _index = 0;
  bool _wentAway = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = PlannerScope.of(context);
    if (state == AppLifecycleState.paused) {
      _wentAway = true;
      controller.appPaused();
      return;
    }
    if (state != AppLifecycleState.resumed || !_wentAway) return;
    _wentAway = false;
    controller.refreshOrigin().ignore();
    final left = controller.finishNavigation();
    if (left == null) return;
    setState(() => _index = 2);
    final following = nextVisit(controller.today.visits);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 6),
          persist: false,
          content: Text(
            following == null
                ? '${left.visit.client} concluída. Era a última parada.'
                : '${left.visit.client} concluída. Próxima: ${following.client}.',
          ),
          action: SnackBarAction(
            label: 'Desfazer',
            onPressed: () => controller.undoLeave(left.visit.id, left.previous),
          ),
        ),
      );
  }

  static const _nav = [
    (Icons.home_outlined, Icons.home, 'Home'),
    (Icons.account_tree_outlined, Icons.account_tree, 'Planejar'),
    (Icons.near_me_outlined, Icons.near_me, 'Executar'),
    (Icons.history_outlined, Icons.history, 'Histórico'),
  ];

  void _open(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 960;
    final pages = [
      TodayPage(onOpenPlan: () => _open(1), onOpenRun: () => _open(2)),
      const PlanPage(),
      const RunPage(),
      const HistoryPage(),
    ];

    final body = pages[_index];

    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _index == 0) return;
        setState(() => _index = 0);
      },
      child: wide ? _wide(body) : _phone(body),
    );
  }

  Widget _wide(Widget body) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            backgroundColor: AppColors.card,
            selectedIndex: _index,
            onDestinationSelected: _open,
            labelType: NavigationRailLabelType.all,
            indicatorColor: AppColors.mintSoft,
            selectedIconTheme: const IconThemeData(color: AppColors.mint),
            unselectedIconTheme: const IconThemeData(color: AppColors.muted),
            destinations: [
              for (final item in _nav)
                NavigationRailDestination(
                  icon: Icon(item.$1),
                  selectedIcon: Icon(item.$2),
                  label: Text(item.$3),
                ),
            ],
          ),
          const VerticalDivider(width: 1, color: AppColors.line),
          Expanded(child: body),
        ],
      ),
    );
  }

  Widget _phone(Widget body) {
    return Scaffold(
      body: SafeArea(bottom: false, child: body),
      bottomNavigationBar: _OpsNav(index: _index, onSelect: _open),
    );
  }
}

class _OpsNav extends StatelessWidget {
  const _OpsNav({required this.index, required this.onSelect});

  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              for (var i = 0; i < _ShellState._nav.length; i++)
                Expanded(
                  child: _NavItem(
                    icon: _ShellState._nav[i].$1,
                    selectedIcon: _ShellState._nav[i].$2,
                    label: _ShellState._nav[i].$3,
                    selected: i == index,
                    onTap: () => onSelect(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.mint : AppColors.muted;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            width: selected ? 16 : 0,
            height: 2,
            margin: const EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(
              color: AppColors.mint,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Icon(selected ? selectedIcon : icon, size: 20, color: color),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
