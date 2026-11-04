import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../application/cards.dart';
import '../../application/core_providers.dart';
import '../../application/library.dart';
import '../../application/review.dart';
import '../../application/settings.dart';
import '../../domain/enums.dart';
import '../../domain/models/deck.dart';
import '../../domain/models/flashcard.dart';
import '../../domain/scheduler.dart';
import '../../theme/app_theme.dart';
import '../format.dart';
import '../save_feedback.dart';
import '../widgets/async_value_view.dart';
import '../widgets/common.dart';

class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key});

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  // Temporary UI detail owned by this screen only, so plain setState is enough.
  // The answer is revealed for one card id, so any change of card (rating,
  // Skip, Study, Drill) hides it again.
  String? _revealedId;

  Future<void> _rate(Rating rating) async {
    final notifier = ref.read(reviewProvider.notifier);
    final rated = await runSave(context, ref, () => notifier.rate(rating));
    // On failure the same card stays up with its answer shown, so the user
    // can pick a rating again.
    if (rated && mounted) setState(() => _revealedId = null);
  }

  @override
  Widget build(BuildContext context) {
    return AsyncValueView<ReviewState>(
      value: ref.watch(reviewProvider),
      data: _buildSession,
    );
  }

  Widget _buildSession(ReviewState review) {
    final settings = ref.watch(settingsProvider);
    final total = review.cardIds.length;
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
            icon: Icon(
              settings.ttsEnabled ? LucideIcons.volume2 : LucideIcons.volumeX,
              size: 18,
            ),
            label: Text(
              settings.ttsEnabled ? 'TTS ON' : 'TTS OFF',
              style: kMonoLabel,
            ),
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
          _SessionComplete(cardIds: review.cardIds)
        else
          AsyncValueView<Flashcard?>(
            value: ref.watch(currentReviewCardProvider),
            data: (card) => card == null
                ? SoftCard(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        const Text('This card no longer exists.'),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: () =>
                              ref.read(reviewProvider.notifier).skip(),
                          child: const Text('Skip'),
                        ),
                      ],
                    ),
                  )
                : _CardView(
                    card: card,
                    number: review.index + 1,
                    total: total,
                    showAnswer: _revealedId == card.id,
                    saving: review.saving,
                    onFlip: () => setState(
                      () =>
                          _revealedId = _revealedId == card.id ? null : card.id,
                    ),
                    onRate: (rating) => unawaited(_rate(rating)),
                  ),
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

  /// A rating is being written; the rating buttons are disabled.
  final bool saving;
  final VoidCallback onFlip;
  final ValueChanged<Rating> onRate;

  const _CardView({
    required this.card,
    required this.number,
    required this.total,
    required this.showAnswer,
    required this.saving,
    required this.onFlip,
    required this.onRate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final decks = ref.watch(decksProvider).valueOrNull;
    final deck = decks?.where((d) => d.id == card.deckId).firstOrNull;
    // Blank while the decks load; "Unknown" only once they say it is missing.
    final deckTitle = deck?.title ?? (decks == null ? '' : 'Unknown');
    final interval = card.isNew
        ? 'NEW'
        : '${card.intervalDays} DAY${card.intervalDays == 1 ? '' : 'S'}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(child: PillLabel('Card $number of $total')),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                'DECK: ${deckTitle.toUpperCase()}',
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
                  Text(
                    card.question,
                    style: kSerifTitle.copyWith(fontSize: 24),
                  ),
                  if (showAnswer) ...[
                    const SizedBox(height: 12),
                    Text(
                      card.answer,
                      style: const TextStyle(fontSize: 16, height: 1.5),
                    ),
                    if (card.sourceRef != null) ...[
                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      const SizedBox(height: 8),
                      Text(
                        'REF: ${card.sourceRef!.toUpperCase()}',
                        style: kMonoMicro,
                      ),
                    ],
                  ],
                  const SizedBox(height: 24),
                  Center(
                    child: Column(
                      children: [
                        const Icon(
                          LucideIcons.refreshCw,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          showAnswer
                              ? 'TAP CARD TO HIDE ANSWER'
                              : 'TAP TO REVEAL ANSWER',
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
                _RatingButton(
                  rating: r,
                  card: card,
                  onTap: saving ? null : () => onRate(r),
                ),
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
class _RatingButton extends ConsumerWidget {
  final Rating rating;
  final Flashcard card;

  /// Null while a rating is being saved.
  final VoidCallback? onTap;

  const _RatingButton({
    required this.rating,
    required this.card,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.read(clockProvider).now();
    final next = formatInterval(
      Sm2Scheduler.apply(card, rating, now: now).dueAt.difference(now),
    );
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
            Text(
              label,
              style: TextStyle(
                color: filled ? Colors.white : color,
                fontSize: 14,
              ),
            ),
            Text(
              next,
              style: kMonoMicro.copyWith(color: filled ? Colors.white : color),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionComplete extends ConsumerWidget {
  /// Ids of the cards in this session, in review order.
  final List<String> cardIds;

  const _SessionComplete({required this.cardIds});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncValueView<List<Flashcard>>(
      value: ref.watch(allCardsProvider),
      data: (cards) => AsyncValueView<List<Deck>>(
        value: ref.watch(decksProvider),
        data: (decks) => _buildSummary(ref, _reviewed(cards), decks),
      ),
    );
  }

  /// The session's cards as stored now, so intervals and due dates are the
  /// ones after rating. Cards deleted since are skipped.
  List<Flashcard> _reviewed(List<Flashcard> all) {
    final byId = {for (final c in all) c.id: c};
    return [for (final id in cardIds) ?byId[id]];
  }

  Widget _buildSummary(
    WidgetRef ref,
    List<Flashcard> reviewed,
    List<Deck> decks,
  ) {
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
                child: const Icon(
                  LucideIcons.circleCheck,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Session complete',
                style: kSerifTitle.copyWith(fontSize: 24),
              ),
              const SizedBox(height: 8),
              const Text(
                'Nice work.',
                style: TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              PillLabel('${cardIds.length} cards reviewed'),
              if (nextDue != null) ...[
                const SizedBox(height: 16),
                Text(
                  'NEXT DUE: ${formatDueDay(nextDue, ref.read(clockProvider).now()).toUpperCase()}',
                  style: kMonoLabel,
                ),
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
