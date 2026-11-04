import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../application/core_providers.dart';
import '../../application/library.dart';
import '../../core/dates.dart';
import '../../theme/app_theme.dart';
import '../format.dart';
import '../save_feedback.dart';
import 'sheet_scaffold.dart';

Future<void> showCreateCourseSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const SheetScaffold(child: _CreateCourseSheet()),
  );
}

class _CreateCourseSheet extends ConsumerStatefulWidget {
  const _CreateCourseSheet();

  @override
  ConsumerState<_CreateCourseSheet> createState() => _CreateCourseSheetState();
}

class _CreateCourseSheetState extends ConsumerState<_CreateCourseSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _dateController = TextEditingController();
  DateTime? _examDate;
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final today = dateOnly(ref.read(clockProvider).now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _examDate ?? today.add(const Duration(days: 14)),
      firstDate: today,
      lastDate: today.add(const Duration(days: 365 * 2)),
    );
    if (picked != null) {
      setState(() {
        _examDate = picked;
        _dateController.text = formatDate(picked);
      });
    }
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final commands = ref.read(libraryCommandsProvider);
    final navigator = Navigator.of(context);
    final saved = await runSave(
      context,
      ref,
      () => commands.createCourse(
        title: _titleController.text,
        examDate: _examDate!,
      ),
    );
    // The sheet may have been dismissed while saving; then there is nothing
    // left to close or re-enable.
    if (!mounted) return;
    if (saved) {
      navigator.pop();
    } else {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('NEW COURSE', style: kMonoLabel),
            const SizedBox(height: 4),
            const Text('Create Course', style: kSerifTitle),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Course title',
                hintText: 'e.g. SWE463 - Mobile Development',
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? 'Enter a course title'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _dateController,
              readOnly: true,
              onTap: _pickDate,
              decoration: const InputDecoration(
                labelText: 'Exam date',
                hintText: 'e.g. Nov 18, 2026',
                suffixIcon: Icon(LucideIcons.calendar),
              ),
              validator: (_) => _examDate == null ? 'Pick an exam date' : null,
            ),
            const SizedBox(height: 8),
            const Text(
              'Why: an exam date spreads reviews so every card is covered before the exam.',
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: const Text('Save Course'),
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
