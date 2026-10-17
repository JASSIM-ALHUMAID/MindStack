import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/course.dart';
import '../providers/library_provider.dart';
import '../route_names.dart';
import '../theme/app_theme.dart';

/// Bottom sheet that adds an empty deck to [course], then opens it in the
/// Deck Editor so the user can start adding cards. Same layout as Create Course.
Future<void> showCreateDeckSheet(BuildContext context, Course course) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.card,
    builder: (_) => _CreateDeckSheet(course: course),
  );
}

class _CreateDeckSheet extends ConsumerStatefulWidget {
  final Course course;

  const _CreateDeckSheet({required this.course});

  @override
  ConsumerState<_CreateDeckSheet> createState() => _CreateDeckSheetState();
}

class _CreateDeckSheetState extends ConsumerState<_CreateDeckSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final id = ref.read(decksProvider.notifier).add(
          courseId: widget.course.id,
          title: _titleController.text.trim(),
        );
    // Close the sheet, then open the new deck so cards can be added right away.
    final router = GoRouter.of(context);
    Navigator.pop(context);
    router.push(RouteNames.deckPath(id));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('NEW DECK · ${widget.course.title.toUpperCase()}', style: kMonoLabel),
            const SizedBox(height: 4),
            const Text('Create Deck', style: kSerifTitle),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleController,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _save(),
              decoration: const InputDecoration(
                labelText: 'Deck title',
                hintText: 'e.g. State management',
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Enter a deck title'
                  : null,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: _save, child: const Text('Save Deck')),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
