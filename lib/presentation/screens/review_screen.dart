import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../application/library.dart';
import '../../application/review.dart';
import '../../application/services.dart';
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
  // Revealing an answer belongs to one card in one session. A fresh session
  // must hide it even when its first card has the same id as before.
  String? _revealedId;
  int? _revealedSessionId;

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
            onPressed: () async {
              await runSave(
                context,
                ref,
                () => ref.read(settingsProvider.notifier).toggleTts(),
              );
            },
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
        if (review.finished)
          _SessionComplete(review: review)
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
                    showAnswer:
                        _revealedId == card.id &&
                        _revealedSessionId == review.sessionId,
                    saving: review.saving,
                    onFlip: () => setState(() {
                      final wasRevealed =
                          _revealedId == card.id &&
                          _revealedSessionId == review.sessionId;
                      _revealedId = wasRevealed ? null : card.id;
                      _revealedSessionId = review.sessionId;
                    }),
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
  final ReviewState review;

  const _SessionComplete({required this.review});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The summary uses committed session receipts, so unrelated history or
    // later card edits cannot change its counts, timing or assigned due date.
    // Deck names are optional labels and need not block the summary loading.
    return _buildSummary(
      ref,
      ref.watch(decksProvider).valueOrNull ?? const <Deck>[],
    );
  }

  String _formatElapsed(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    if (duration.inMinutes == 0) {
      return '${(milliseconds / 1000).toStringAsFixed(1)} s';
    }
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '${duration.inMinutes}m ${seconds}s';
  }

  Widget _buildSummary(WidgetRef ref, List<Deck> decks) {
    final reviewed = review.results.map((result) => result.card).toList();
    final nextDue = review.nextDue;

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
              Text(
                review.cardIds.isEmpty
                    ? 'Nothing due right now.'
                    : review.reviewedCount == 0
                    ? 'No cards were rated in this session.'
                    : 'Nice work.',
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  PillLabel('${review.reviewedCount} cards reviewed'),
                  if (review.reviewedCount > 0) ...[
                    PillLabel('Time: ${_formatElapsed(review.elapsedMs)}'),
                    PillLabel(
                      'Pace: ${review.secondsPerCard.toStringAsFixed(1)} s/card',
                    ),
                  ],
                ],
              ),
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
                  onPressed: () {
                    final notifier = ref.read(reviewProvider.notifier);
                    if (review.cardIds.isEmpty) {
                      unawaited(notifier.start());
                    } else {
                      notifier.restart();
                    }
                  },
                  icon: const Icon(LucideIcons.rotateCcw),
                  label: Text(
                    review.cardIds.isEmpty
                        ? 'Check for due cards'
                        : 'Review again',
                  ),
                ),
              ),
            ],
          ),
        ),
        if (reviewed.isNotEmpty) ...[
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
      ],
    );
  }
}
