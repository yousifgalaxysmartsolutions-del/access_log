import 'package:flutter/material.dart';

import '../app.dart';
import '../core/di/injection.dart';
import '../core/localization/app_strings.dart';
import '../core/routes/app_routes.dart';
import '../core/session/session_manager.dart';
import '../core/theme/app_tokens.dart';
import '../mock/mock_data.dart';
import 'dashboard/cap_dashboard_screen.dart';
import 'incidents/incident_list_screen.dart';
import 'map/tower_map_screen.dart';
import 'more/more_screens.dart';
import 'requests/my_requests_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const CapDashboardScreen(),
      const IncidentListScreen(),
      const MyRequestsScreen(),
      const MoreHubScreen(),
    ];
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 70,
        title: Row(
          children: [
            GestureDetector(
              onLongPress: () =>
                  Navigator.pushNamed(context, AppRoutes.prototypeDemo),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.ink,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Center(
                  child: Text(
                    '+',
                    style: TextStyle(
                      color: AppColors.orange,
                      fontSize: 29,
                      height: 1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Flexible(
              child: Text(
                'Access Log+',
                style: AppTypography.section,
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: context.tr('Dark mode', 'الوضع الليلي'),
            onPressed: () => AccessLogApp.of(context).toggleTheme(),
            icon: Icon(
              AccessLogApp.of(context).isDark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
            ),
          ),
          IconButton(
            tooltip: context.strings.t('language'),
            onPressed: () => AccessLogApp.of(context).toggleLocale(),
            icon: const Icon(Icons.language),
          ),
          IconButton(
            tooltip: context.tr('Notifications', 'الإشعارات'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const NotificationCenterScreen(),
              ),
            ),
            icon: Badge(
              label: const Text('3'),
              backgroundColor: AppColors.orange,
              child: const Icon(Icons.notifications_none_rounded),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 4, end: 12),
            child: CircleAvatar(
              radius: 17,
              backgroundColor: AppColors.orange,
              child: Builder(
                builder: (context) {
                  final sessionUserName =
                      services.isRegistered<SessionManager>()
                      ? services<SessionManager>().user?.name
                      : null;
                  final initials =
                      sessionUserName != null && sessionUserName.isNotEmpty
                      ? sessionUserName.substring(0, 1).toUpperCase()
                      : MockData.engineer.initials;
                  return Text(
                    initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: IndexedStack(index: index, children: pages),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Semantics(
        button: true,
        label: context.tr('Open Tower Map', 'فتح خريطة الأبراج'),
        child: FloatingActionButton.large(
          heroTag: 'tower-map-navigation-button',
          tooltip: context.tr('Tower Map', 'خريطة الأبراج'),
          backgroundColor: AppColors.orange,
          foregroundColor: AppColors.ink,
          elevation: 5,
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TowerMapScreen()),
          ),
          child: const Icon(Icons.map_rounded, size: 30),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        height: 76,
        padding: EdgeInsets.zero,
        notchMargin: 8,
        shape: const CircularNotchedRectangle(),
        child: Row(
          children: [
            _ShellDestination(
              selected: index == 0,
              icon: Icons.home_outlined,
              selectedIcon: Icons.home_rounded,
              label: context.tr('Home', 'الرئيسية'),
              onTap: () => setState(() => index = 0),
            ),
            _ShellDestination(
              selected: index == 1,
              icon: Icons.assignment_outlined,
              selectedIcon: Icons.assignment,
              label: context.tr('Incidents', 'البلاغات'),
              onTap: () => setState(() => index = 1),
            ),
            const SizedBox(width: 76),
            _ShellDestination(
              selected: index == 2,
              icon: Icons.inbox_outlined,
              selectedIcon: Icons.inbox,
              label: context.tr('My Requests', 'طلباتي'),
              onTap: () => setState(() => index = 2),
            ),
            _ShellDestination(
              selected: index == 3,
              icon: Icons.grid_view_outlined,
              selectedIcon: Icons.grid_view_rounded,
              label: context.tr('More', 'المزيد'),
              onTap: () => setState(() => index = 3),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShellDestination extends StatelessWidget {
  const _ShellDestination({
    required this.selected,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? AppColors.orange
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: InkWell(
          onTap: onTap,
          child: SizedBox.expand(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(3, 8, 3, 5),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(selected ? selectedIcon : icon, color: color, size: 23),
                  const SizedBox(height: 3),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
