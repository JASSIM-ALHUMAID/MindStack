import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../application/quiz.dart';
import '../../application/review.dart';
import '../../application/tab.dart';
import '../../domain/quiz_builder.dart';
import '../../theme/app_theme.dart';
import '../save_feedback.dart';
import '../widgets/async_value_view.dart';
import '../widgets/common.dart';

class QuizScreen extends ConsumerWidget {
  const QuizScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(quizProvider);
    final quiz = value.valueOrNull;
    // A rebuild (Try again, or entering the tab) keeps showing the previous
    // quiz until the new one is ready; only the very first load spins.
    if (quiz == null) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          const ScreenHeader(eyebrow: 'MULTIPLE CHOICE', title: 'Quiz'),
          const SizedBox(height: 16),
          AsyncValueView<QuizState>(
            value: value,
            data: (_) => const SizedBox(),
          ),
        ],
      );
    }
    final total = quiz.questions.length;

    if (total == 0) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          const ScreenHeader(eyebrow: 'MULTIPLE CHOICE', title: 'Quiz'),
          const SizedBox(height: 16),
          SoftCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Icon(
                  LucideIcons.circleQuestionMark,
                  color: AppColors.primary,
                  size: 32,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Add at least $kMinQuizCards cards to start a quiz',
                  textAlign: TextAlign.center,
                  style: kSerifSection,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Each question needs three wrong answers taken from '
                  'your other cards.',
                  textAlign: TextAlign.center,
                  style: kBodySmall,
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () => ref.read(tabIndexProvider.notifier).set(1),
                  child: const Text('Go to Library'),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (quiz.finished) {
      final accuracy = (quiz.score * 100 / total).round();
      final missedIds = quiz.missedCardIds;
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          ScreenHeader(
            eyebrow: 'RESULTS · $total QUESTIONS',
            title: 'Quiz',
            trailing: PillLabel('${quiz.score}/$total'),
          ),
          const SizedBox(height: 16),
          SoftCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.chip,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    LucideIcons.award,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Quiz complete',
                  style: kSerifTitle.copyWith(fontSize: 24),
                ),
                const SizedBox(height: 4),
                Text(
                  '${quiz.score}/$total',
                  style: kSerifTitle.copyWith(
                    fontSize: 56,
                    height: 1,
                    letterSpacing: -1.4,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text('Correct out of $total questions.'),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: quiz.score / total,
                    minHeight: 6,
                    color: AppColors.primary,
                    backgroundColor: AppColors.chip,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => ref.read(quizProvider.notifier).restart(),
                    icon: const Icon(LucideIcons.rotateCcw),
                    label: const Text('Try again'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SoftCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('ACCURACY', style: kMonoLabel),
                      Text('$accuracy%', style: kSerifSection),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SoftCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('CADENCE', style: kMonoLabel),
                      Text(
                        '${quiz.secondsPerQuestion.round()}s / question',
                        style: kSerifSection,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text('WEAK CARDS', style: kMonoLabel),
                    ),
                    Text(
                      '${quiz.missed.length} WEAK CARD${quiz.missed.length == 1 ? '' : 'S'}',
                      style: kMonoLabel,
                    ),
                  ],
                ),
                if (quiz.missed.isEmpty) ...[
                  const SizedBox(height: 8),
                  const Text('No missed questions. Nice work.'),
                ],
                for (final i in quiz.missed) ...[
                  const Divider(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          quiz.questions[i].prompt,
                          style: kSerifTitle.copyWith(fontSize: 17),
                        ),
                      ),
                      const PillLabel('Missed', color: AppColors.danger),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    quiz.questions[i].options[quiz.questions[i].correctIndex],
                    style: kBodySmall,
                  ),
                ],
                if (missedIds.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () {
                      // Loads the queue in the background; the Review tab
                      // shows its own loading and error states.
                      unawaited(
                        ref
                            .read(reviewProvider.notifier)
                            .start(cardIds: missedIds),
                      );
                      ref.read(tabIndexProvider.notifier).set(2);
                    },
                    iconAlignment: IconAlignment.end,
                    icon: const Icon(LucideIcons.arrowRight, size: 16),
                    label: const Text('REVIEW WEAK CARDS', style: kMonoLabel),
                  ),
                ],
              ],
            ),
          ),
          if (missedIds.isNotEmpty) ...[
            const SizedBox(height: 12),
            SoftCard(
              color: AppColors.chip,
              child: Row(
                children: [
                  const Icon(
                    LucideIcons.bookmark,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Missed cards were marked "Again", so they are due in '
                      'your next review.',
                      style: kBodySmall.copyWith(color: AppColors.ink),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      );
    }

    final q = quiz.current!;
    final answered = quiz.selected != null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        ScreenHeader(
          eyebrow: 'QUESTION ${quiz.index + 1} OF $total',
          title: 'Quiz',
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (quiz.index + 1) / total,
            minHeight: 6,
            color: AppColors.primary,
            backgroundColor: AppColors.chip,
          ),
        ),
        const SizedBox(height: 16),
        SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'MULTIPLE CHOICE',
                      style: kMonoLabel,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  PillLabel('${q.points} pts', filled: true),
                  const SizedBox(width: 6),
                  PillLabel('Difficulty: ${q.difficulty.name}'),
                ],
              ),
              const SizedBox(height: 12),
              Text(q.prompt, style: kSerifTitle.copyWith(fontSize: 22)),
              const SizedBox(height: 12),
              for (var i = 0; i < q.options.length; i++) ...[
                _OptionTile(
                  letter: String.fromCharCode(65 + i),
                  text: q.options[i],
                  state: !answered
                      ? _OptionState.idle
                      : (i == q.correctIndex
                            ? _OptionState.correct
                            : (i == quiz.selected
                                  ? _OptionState.wrong
                                  : _OptionState.idle)),
                  // The answer shows at once; a failed miss log is reported
                  // in a SnackBar and the quiz carries on.
                  onTap: answered
                      ? null
                      : () => unawaited(
                          runSave(
                            context,
                            ref,
                            () => ref.read(quizProvider.notifier).select(i),
                          ),
                        ),
                ),
                const SizedBox(height: 8),
              ],
              if (answered) ...[
                const SizedBox(height: 8),
                SoftCard(
                  color: AppColors.tint,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('WHY', style: kMonoLabel),
                      const SizedBox(height: 4),
                      Text(q.explanation),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => ref.read(quizProvider.notifier).next(),
                    child: const Text('Next question'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

enum _OptionState { idle, correct, wrong }

class _OptionTile extends StatelessWidget {
  final String letter;
  final String text;
  final _OptionState state;
  final VoidCallback? onTap;

  const _OptionTile({
    required this.letter,
    required this.text,
    required this.state,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Correct = filled green with white text and a check mark (Figma).
    // Wrong = red outline and tint with a cross, so state is not shown by color alone.
    final (Color border, Color fill, Color ink) = switch (state) {
      _OptionState.correct => (
        AppColors.success,
        AppColors.success,
        Colors.white,
      ),
      _OptionState.wrong => (
        AppColors.danger,
        const Color(0xFFFBEAE8),
        AppColors.danger,
      ),
      _OptionState.idle => (AppColors.border, AppColors.card, AppColors.ink),
    };
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: state == _OptionState.correct ? Colors.white : null,
                shape: BoxShape.circle,
                border: Border.all(
                  color: state == _OptionState.idle ? AppColors.border : border,
                ),
              ),
              child: Text(
                letter,
                style: kMonoMicro.copyWith(
                  color: state == _OptionState.correct
                      ? AppColors.success
                      : ink,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(text, style: TextStyle(color: ink)),
            ),
            if (state == _OptionState.correct)
              const Icon(LucideIcons.check, color: Colors.white),
            if (state == _OptionState.wrong)
              const Icon(LucideIcons.x, color: AppColors.danger),
          ],
        ),
      ),
    );
  }
}
