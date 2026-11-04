import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Hosts the content of a modal bottom sheet with its own
/// [ScaffoldMessenger], so SnackBars raised while the sheet is open (for
/// example a failed save) appear inside the sheet instead of behind the modal
/// barrier on the page underneath.
///
/// Open the sheet with `backgroundColor: Colors.transparent` and
/// `isScrollControlled: true`. The card-coloured panel hugs [child] at the
/// bottom; tapping the transparent area above it closes the sheet.
class SheetScaffold extends StatelessWidget {
  /// Wraps [child], the sheet's form content.
  const SheetScaffold({required this.child, super.key});

  /// The sheet content, laid out at its natural height.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        // The scaffold shrinks for the keyboard and removes the inset from the
        // content's MediaQuery, so the content needs no inset padding itself.
        body: Column(
          children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.maybePop(context),
              ),
            ),
            Material(
              color: AppColors.card,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              clipBehavior: Clip.antiAlias,
              child: SizedBox(
                width: double.infinity,
                child: SingleChildScrollView(child: child),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
