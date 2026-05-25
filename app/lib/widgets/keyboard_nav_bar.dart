import 'package:flutter/material.dart';

import '../theme.dart';

class KeyboardNavBar extends StatelessWidget {
  const KeyboardNavBar({super.key});

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    if (bottomInset <= 0) return const SizedBox.shrink();

    return Material(
      elevation: 8,
      color: AppColors.surfaceElevated,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.outline, width: 1)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              _NavBtn(
                icon: Icons.chevron_left_rounded,
                label: 'Préc',
                onPressed: () {
                  FocusScope.of(context).previousFocus();
                },
              ),
              const SizedBox(width: 8),
              _NavBtn(
                icon: Icons.chevron_right_rounded,
                label: 'Suiv',
                onPressed: () {
                  FocusScope.of(context).nextFocus();
                },
                isPrimary: true,
              ),
              const Spacer(),
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primaryDark,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  minimumSize: const Size(0, 48),
                ),
                icon: const Icon(Icons.keyboard_hide_outlined, size: 22),
                label: const Text(
                  'Terminé',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                onPressed: () => FocusManager.instance.primaryFocus?.unfocus(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavBtn extends StatelessWidget {
  const _NavBtn({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isPrimary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final bg = isPrimary ? AppColors.primary : AppColors.surfaceElevated;
    final fg = isPrimary ? Colors.white : AppColors.primaryDark;
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 24),
      label: Text(
        label,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        elevation: 0,
        side: isPrimary ? null : const BorderSide(color: AppColors.outline),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        minimumSize: const Size(0, 48),
      ),
    );
  }
}
