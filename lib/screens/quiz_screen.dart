import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../providers/quiz_provider.dart';
import '../providers/review_provider.dart';
import '../providers/tab_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class QuizScreen extends ConsumerWidget {
  const QuizScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quiz = ref.watch(quizProvider);
    final total = quiz.questions.length;

    if (quiz.finished) {
      final accuracy = total == 0 ? 0 : (quiz.score * 100 / total).round();
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
                  child: const Icon(LucideIcons.award, color: AppColors.primary),
                ),
                const SizedBox(height: 12),
                Text('Quiz complete', style: kSerifTitle.copyWith(fontSize: 24)),
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
                    value: total == 0 ? 0 : quiz.score / total,
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
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ACCURACY', style: kMonoLabel),
                Text('$accuracy%', style: kSerifSection),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SoftCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(child: Text('WEAK CARDS', style: kMonoLabel)),
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
                        child: Text(quiz.questions[i].prompt, style: kSerifTitle.copyWith(fontSize: 17)),
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
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () {
                    ref.read(reviewProvider.notifier).startWeak();
                    ref.read(tabIndexProvider.notifier).set(2);
                  },
                  iconAlignment: IconAlignment.end,
                  icon: const Icon(LucideIcons.arrowRight, size: 16),
                  label: const Text('REVIEW WEAK CARDS', style: kMonoLabel),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final q = quiz.current!;
    final answered = quiz.selected != null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        ScreenHeader(eyebrow: 'QUESTION ${quiz.index + 1} OF $total', title: 'Quiz'),
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
                          : (i == quiz.selected ? _OptionState.wrong : _OptionState.idle)),
                  onTap: answered ? null : () => ref.read(quizProvider.notifier).select(i),
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
      _OptionState.correct => (AppColors.success, AppColors.success, Colors.white),
      _OptionState.wrong => (AppColors.danger, const Color(0xFFFBEAE8), AppColors.danger),
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
                border: Border.all(color: state == _OptionState.idle ? AppColors.border : border),
              ),
              child: Text(
                letter,
                style: kMonoMicro.copyWith(
                  color: state == _OptionState.correct ? AppColors.success : ink,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: TextStyle(color: ink))),
            if (state == _OptionState.correct) const Icon(LucideIcons.check, color: Colors.white),
            if (state == _OptionState.wrong) const Icon(LucideIcons.x, color: AppColors.danger),
          ],
        ),
      ),
    );
  }
}
