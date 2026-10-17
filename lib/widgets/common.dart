import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Rounded card used across all screens (matches the Figma cards).
class SoftCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;

  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

/// Screen header from Figma: small uppercase label, a brown dot and the
/// serif title, an optional trailing widget, and a divider underneath.
class ScreenHeader extends StatelessWidget {
  final String eyebrow;
  final String title;
  final Widget? trailing;

  const ScreenHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(eyebrow, style: kMonoLabel),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(child: Text(title, style: kSerifTitle)),
                    ],
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
        const SizedBox(height: 12),
        const Divider(height: 1),
      ],
    );
  }
}

/// Pill-shaped label such as "21 DAYS TO EXAM" or "NEW".
/// [filled] gives the dark pill used for strong labels (e.g. "21 DAYS").
class PillLabel extends StatelessWidget {
  final String text;
  final Color color;
  final bool filled;

  const PillLabel(
    this.text, {
    super.key,
    this.color = AppColors.primary,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: filled ? color : color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text.toUpperCase(),
        style: kMonoMicro.copyWith(color: filled ? Colors.white : color),
      ),
    );
  }
}

/// Mastery bar with a percentage label.
class MasteryBar extends StatelessWidget {
  final double value;

  const MasteryBar({super.key, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 64,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 6,
              color: AppColors.primary,
              backgroundColor: AppColors.chip,
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 36,
          child: Text('${(value * 100).round()}%', textAlign: TextAlign.right),
        ),
      ],
    );
  }
}
