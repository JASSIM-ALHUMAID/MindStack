import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../application/library.dart';
import '../../domain/models/course.dart';
import '../../route_names.dart';
import '../../theme/app_theme.dart';
import '../save_feedback.dart';

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
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final commands = ref.read(libraryCommandsProvider);
    final router = GoRouter.of(context);
    final navigator = Navigator.of(context);
    String? deckId;
    final saved = await runSave(context, ref, () async {
      deckId = await commands.createDeck(
        courseId: widget.course.id,
        title: _titleController.text,
      );
    });
    if (!mounted) return;
    if (!saved) {
      setState(() => _saving = false);
      return;
    }
    // Close the sheet, then open the new deck so cards can be added right away.
    navigator.pop();
    // Fire-and-forget: this sheet is closed, so nothing waits on the pop result.
    unawaited(router.push<void>(RouteNames.deckPath(deckId!)));
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
            Text(
              'NEW DECK · ${widget.course.title.toUpperCase()}',
              style: kMonoLabel,
            ),
            const SizedBox(height: 4),
            const Text('Create Deck', style: kSerifTitle),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleController,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => unawaited(_save()),
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
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: const Text('Save Deck'),
              ),
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
