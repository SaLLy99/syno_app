import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:syno_app/theme.dart';
import 'package:syno_app/domain/entities/app_mode.dart';
import 'package:syno_app/presentation/providers/app_mode_provider.dart';

class MainShell extends ConsumerWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentMode = ref.watch(appModeProvider);
    final isBffMode = currentMode == AppMode.bff;

    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _calculateSelectedIndex(context),
        onTap: (int index) => _onItemTapped(index, context),
        type: BottomNavigationBarType.fixed,
        backgroundColor: CosmicColors.deepSpace,
        selectedItemColor: isBffMode ? AppMode.bff.color : AppMode.dating.color,
        unselectedItemColor: Colors.white.withOpacity(0.6),
        selectedFontSize: 12,
        unselectedFontSize: 12,
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: const Icon(Icons.explore_outlined),
            activeIcon: const Icon(Icons.explore),
            label: isBffMode ? 'Find Friends' : 'bottom_nav.discover'.tr(),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.favorite_border),
            activeIcon: const Icon(Icons.favorite),
            label: 'bottom_nav.likes'.tr(),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.people_outline),
            activeIcon: const Icon(Icons.people),
            label: 'bottom_nav.matches'.tr(),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.chat_bubble_outline),
            activeIcon: const Icon(Icons.chat_bubble),
            label: 'bottom_nav.chats'.tr(),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person_outline),
            activeIcon: const Icon(Icons.person),
            label: 'bottom_nav.profile'.tr(),
          ),
        ],
      ),
    );
  }

  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/discover')) {
      return 0;
    }
    if (location.startsWith('/likes')) {
      return 1;
    }
    if (location.startsWith('/matches')) {
      return 2;
    }
    if (location.startsWith('/chats')) {
      return 3;
    }
    if (location.startsWith('/profile')) {
      return 4;
    }
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    const List<String> paths = <String>['/discover', '/likes', '/matches', '/chats', '/profile'];
    if (index >= 0 && index < paths.length) {
      context.go(paths[index]);
    }
  }
}
