import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syno_app/domain/entities/app_mode.dart';
import 'package:syno_app/presentation/providers/app_mode_provider.dart';

class ModeSelector extends ConsumerWidget {
  const ModeSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentMode = ref.watch(appModeProvider);

    return Container(
      height: 44,
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ModeTab(
              mode: AppMode.dating,
              isSelected: currentMode == AppMode.dating,
              onTap: () => _switchMode(ref, AppMode.dating),
            ),
          ),
          Expanded(
            child: _ModeTab(
              mode: AppMode.bff,
              isSelected: currentMode == AppMode.bff,
              onTap: () => _switchMode(ref, AppMode.bff),
            ),
          ),
        ],
      ),
    );
  }

  void _switchMode(WidgetRef ref, AppMode mode) {
    ref.read(appModeProvider.notifier).switchMode(mode);
  }
}

class _ModeTab extends StatelessWidget {
  final AppMode mode;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeTab({
    required this.mode,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: isSelected ? mode.color.withOpacity(0.8) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: mode.color.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              mode.icon,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(width: 6),
            Text(
              mode.label,
              style: TextStyle(
                color: Colors.white,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
