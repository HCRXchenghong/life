import 'package:flutter/material.dart';

enum AppDestination { schedule, toolbox, assistant, hosts, me }

class DaylinkBottomNavigation extends StatelessWidget {
  const DaylinkBottomNavigation({
    super.key,
    required this.currentDestination,
    required this.onSelected,
  });

  final AppDestination currentDestination;
  final ValueChanged<AppDestination> onSelected;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEDEFF2))),
      ),
      child: SizedBox(
        height: 66 + bottomInset,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Row(
            children: [
              _NavigationItem(
                key: const Key('nav-schedule'),
                icon: Icons.event_available_outlined,
                label: '日程',
                active: currentDestination == AppDestination.schedule,
                onTap: () => onSelected(AppDestination.schedule),
              ),
              _NavigationItem(
                key: const Key('nav-toolbox'),
                icon: Icons.grid_view_rounded,
                label: '工具箱',
                active: currentDestination == AppDestination.toolbox,
                onTap: () => onSelected(AppDestination.toolbox),
              ),
              _NavigationItem(
                key: const Key('nav-assistant'),
                icon: Icons.auto_awesome_outlined,
                label: '助手',
                active: currentDestination == AppDestination.assistant,
                onTap: () => onSelected(AppDestination.assistant),
              ),
              _NavigationItem(
                key: const Key('nav-hosts'),
                icon: Icons.desktop_windows_outlined,
                label: '主机',
                active: currentDestination == AppDestination.hosts,
                onTap: () => onSelected(AppDestination.hosts),
              ),
              _NavigationItem(
                key: const Key('nav-me'),
                icon: Icons.person_outline_rounded,
                label: '我的',
                active: currentDestination == AppDestination.me,
                onTap: () => onSelected(AppDestination.me),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavigationItem extends StatelessWidget {
  const _NavigationItem({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    required this.active,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFF3370FF) : const Color(0xFF646A73);
    return Expanded(
      child: Semantics(
        selected: active,
        button: true,
        child: InkResponse(
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 23, color: color),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  height: 1.2,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
