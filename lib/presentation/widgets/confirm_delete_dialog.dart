import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Asks the user to confirm deleting [what]. Returns `true` only when Delete
/// was tapped; Cancel and dismissing the dialog return `false`.
Future<bool> confirmDelete(
  BuildContext context, {
  required String title,
  required String what,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text('$what You can undo this right after.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
