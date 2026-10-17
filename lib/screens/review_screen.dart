import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/flashcard.dart';
import '../providers/library_provider.dart';
import '../providers/review_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';

class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key});

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  bool _showAnswer = false;

  void _rate(Rating rating) {
    ref.read(reviewProvider.notifier).rate(rating);
    setState(() => _showAnswer = false);
  }

  @override
  Widget build(BuildContext context) {
    final review = ref.watch(reviewProvider);
    final settings = ref.watch(settingsProvider);
    final total = review.queue.length;
    final done = review.index.clamp(0, total);
    final percent = total == 0 ? 0 : (done * 100 / total).round();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        ScreenHeader(
          eyebrow: review.finished
              ? "TODAY'S QUEUE · COMPLETE"
              : "TODAY'S QUEUE · $total DUE",
          title: 'Review',
          trailing: TextButton.icon(
            onPressed: () => ref.read(settingsProvider.notifier).toggleTts(),
            icon: Icon(settings.ttsEnabled ? LucideIcons.volume2 : LucideIcons.volumeX, size: 18),
            label: Text(settings.ttsEnabled ? 'TTS ON' : 'TTS OFF', style: kMonoLabel),
          ),
        ),
        const SizedBox(height: 16),
        if (total > 0 && !review.finished) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: done / total,
              minHeight: 6,
              color: AppColors.primary,
              backgroundColor: AppColors.chip,
            ),
          ),
          const SizedBox(height: 6),
          Text('$done / $total CARDS ($percent%)', style: kMonoLabel),
          const SizedBox(height: 16),
        ],
        if (total == 0)
          const SoftCard(
            padding: EdgeInsets.all(32),
            child: Center(child: Text('Nothing due right now.')),
          )
        else if (review.finished)
          _SessionComplete(queue: review.queue)
        else
          _CardView(
            card: review.current!,
            number: review.index + 1,
            total: total,
            showAnswer: _showAnswer,
            onFlip: () => setState(() => _showAnswer = !_showAnswer),
            onRate: _rate,
          ),
      ],
    );
  }
}

class _CardView extends ConsumerWidget {
  final Flashcard card;
  final int number;
  final int total;
  final bool showAnswer;
  final VoidCallback onFlip;
  final ValueChanged<Rating> onRate;

  const _CardView({
    required this.card,
    required this.number,
    required this.total,
    required this.showAnswer,
    required this.onFlip,
    required this.onRate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deck = ref.watch(decksProvider).where((d) => d.id == card.deckId).firstOrNull;
    final interval = card.isNew ? 'NEW' : '${card.intervalDays} DAY${card.intervalDays == 1 ? '' : 'S'}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(child: PillLabel('Card $number of $total')),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                'DECK: ${(deck?.title ?? 'Unknown').toUpperCase()}',
                style: kMonoMicro,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text('INTERVAL: $interval', style: kMonoMicro),
          ],
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onFlip,
          borderRadius: BorderRadius.circular(16),
          child: SoftCard(
            color: showAnswer ? AppColors.tint : AppColors.card,
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 220),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(showAnswer ? 'ANSWER' : 'QUESTION', style: kMonoLabel),
                  const SizedBox(height: 12),
                  Text(card.question, style: kSerifTitle.copyWith(fontSize: 24)),
                  if (showAnswer) ...[
                    const SizedBox(height: 12),
                    Text(card.answer, style: const TextStyle(fontSize: 16, height: 1.5)),
                    if (card.sourceRef != null) ...[
                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      const SizedBox(height: 8),
                      Text('REF: ${card.sourceRef!.toUpperCase()}', style: kMonoMicro),
                    ],
                  ],
                  const SizedBox(height: 24),
                  Center(
                    child: Column(
                      children: [
                        const Icon(LucideIcons.refreshCw, size: 18, color: AppColors.primary),
                        const SizedBox(height: 4),
                        Text(
                          showAnswer ? 'TAP CARD TO HIDE ANSWER' : 'TAP TO REVEAL ANSWER',
                          style: kMonoLabel,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (showAnswer) ...[
          const Text('RATE RECALL ACCURACY', style: kMonoLabel),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 2.6,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: [
              for (final r in Rating.values)
                _RatingButton(rating: r, card: card, onTap: () => onRate(r)),
            ],
          ),
        ] else
          const Center(
            child: Text('TAP CARD TO REVEAL RECALL OPTIONS', style: kMonoLabel),
          ),
      ],
    );
  }
}

/// One of the four colored rating buttons. Shows when the card would come
/// back if the user picked this rating (computed with the real scheduler).
class _RatingButton extends StatelessWidget {
  final Rating rating;
  final Flashcard card;
  final VoidCallback onTap;

  const _RatingButton({required this.rating, required this.card, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final next = formatInterval(card.applyRating(rating, now: now).dueAt.difference(now));
    final color = switch (rating) {
      Rating.again => AppColors.danger,
      Rating.hard => AppColors.hard,
      Rating.good => AppColors.success,
      Rating.easy => AppColors.primary,
    };
    final filled = rating == Rating.easy;
    final label = rating.name[0].toUpperCase() + rating.name.substring(1);

    return Material(
      color: filled ? color : AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: color),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: TextStyle(color: filled ? Colors.white : color, fontSize: 14)),
            Text(next, style: kMonoMicro.copyWith(color: filled ? Colors.white : color)),
          ],
        ),
      ),
    );
  }
}

class _SessionComplete extends ConsumerWidget {
  /// The cards in this session (as they were before rating).
  final List<Flashcard> queue;

  const _SessionComplete({required this.queue});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ids = {for (final c in queue) c.id};
    // Look up the updated cards so intervals and due dates are after rating.
    final reviewed = ref.watch(cardsProvider).where((c) => ids.contains(c.id)).toList();
    final decks = ref.watch(decksProvider);
    final nextDue = reviewed.isEmpty
        ? null
        : reviewed.map((c) => c.dueAt).reduce((a, b) => a.isBefore(b) ? a : b);

    return Column(
      children: [
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
                child: const Icon(LucideIcons.circleCheck, color: AppColors.primary),
              ),
              const SizedBox(height: 12),
              Text('Session complete', style: kSerifTitle.copyWith(fontSize: 24)),
              const SizedBox(height: 8),
              const Text('Nice work.', style: TextStyle(color: AppColors.muted)),
              const SizedBox(height: 12),
              PillLabel('${queue.length} cards reviewed'),
              if (nextDue != null) ...[
                const SizedBox(height: 16),
                Text('NEXT DUE: ${formatDueDay(nextDue).toUpperCase()}', style: kMonoLabel),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => ref.read(reviewProvider.notifier).restart(),
                  icon: const Icon(LucideIcons.rotateCcw),
                  label: const Text('Review again'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('CARDS REVIEWED', style: kMonoLabel),
              for (final c in reviewed) ...[
                const Divider(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.question),
                          Text(
                            '${decks.where((d) => d.id == c.deckId).firstOrNull?.title ?? ''}'
                            ' · Interval ${c.intervalDays}d',
                            style: kMonoMicro,
                          ),
                        ],
                      ),
                    ),
                    if (c.mastery >= 0.8)
                      const PillLabel('Mastered', color: AppColors.success),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
