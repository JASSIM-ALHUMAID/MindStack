import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/review.dart';
import '../../application/services.dart';
import '../../application/stats.dart';
import '../../application/tab.dart';
import '../../core/dates.dart';
import '../../domain/models/flashcard.dart';
import '../../domain/streak.dart';
import '../../theme/app_theme.dart';
import '../format.dart';
import '../widgets/async_value_view.dart';
import '../widgets/common.dart';

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  // Planner inputs belong to this screen only, so plain setState is used.
  late DateTime _examDate = dateOnly(ref.read(clockProvider).now())
      .add(const Duration(days: 21));
  final TextEditingController _totalController = TextEditingController(
    text: '40',
  );
  String? _planText;
  int? _planDays;

  /// Inline message under the planner inputs; null when they are valid.
  String? _planError;

  @override
  void dispose() {
    _totalController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final today = dateOnly(ref.read(clockProvider).now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _examDate,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365 * 2)),
    );
    if (picked != null) setState(() => _examDate = picked);
  }

  void _plan() {
    final total = int.tryParse(_totalController.text.trim());
    // Rounded: a daylight-saving change makes one day 23 or 25 hours long.
    final days =
        (_examDate.difference(dateOnly(ref.read(clockProvider).now())).inHours /
                24)
            .round();
    final error = total == null || total <= 0
        ? 'Enter a whole number of cards, 1 or more.'
        : (days <= 0 ? 'Pick an exam date after today.' : null);
    if (error != null) {
      setState(() {
        _planError = error;
        _planText = null;
        _planDays = null;
      });
      return;
    }
    final perDay = (total! / days).ceil();
    setState(() {
      _planError = null;
      _planText =
          '$perDay ${perDay == 1 ? 'card' : 'cards'} per day to cover all '
          '$total cards. Review the weakest ones first.';
      _planDays = days;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        const ScreenHeader(eyebrow: 'MASTERY · STREAK · EXAMS', title: 'Stats'),
        const SizedBox(height: 16),
        SoftCard(
          child: AsyncValueView<StreakInfo>(
            value: ref.watch(streakProvider),
            data: (streak) => _StreakSection(streak: streak),
          ),
        ),
        const SizedBox(height: 16),
        SoftCard(
          child: AsyncValueView<List<DeckMastery>>(
            value: ref.watch(masteryByDeckProvider),
            data: (decks) => _MasterySection(decks: decks),
          ),
        ),
        const SizedBox(height: 16),
        SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Exam quota planner', style: kSerifSection),
              const SizedBox(height: 8),
              const Text(
                "Set an exam date and I'll spread the cards so every card is covered.",
                style: TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('EXAM DATE', style: kMonoLabel),
                        const SizedBox(height: 4),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: _pickDate,
                            child: Text(formatDate(_examDate)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('TOTAL CARDS', style: kMonoLabel),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _totalController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            isDense: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (_planError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _planError!,
                  style: kBodySmall.copyWith(color: AppColors.danger),
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _plan,
                  child: const Text('Plan'),
                ),
              ),
              if (_planText != null) ...[
                const SizedBox(height: 12),
                SoftCard(
                  color: AppColors.tint,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text('PLAN', style: kMonoLabel),
                          ),
                          if (_planDays != null)
                            PillLabel('$_planDays days', filled: true),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(_planText!),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        SoftCard(
          child: AsyncValueView<List<Flashcard>>(
            value: ref.watch(weakestCardsProvider),
            data: (weakest) => _WeakestSection(weakest: weakest),
          ),
        ),
      ],
    );
  }
}

/// Current and best streak, and the last 28 days as a grid.
class _StreakSection extends StatelessWidget {
  final StreakInfo streak;

  const _StreakSection({required this.streak});

  static const List<String> _weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final current = streak.current;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Study streak', style: kSerifSection),
                  Text(
                    'BEST: ${streak.best} ${streak.best == 1 ? 'DAY' : 'DAYS'}',
                    style: kMonoLabel,
                  ),
                ],
              ),
            ),
            Text('$current', style: kSerifTitle.copyWith(fontSize: 36)),
            Text(current == 1 ? ' DAY' : ' DAYS', style: kMonoLabel),
          ],
        ),
        const SizedBox(height: 12),
        // Columns follow the real weekdays of the first row's dates.
        Row(
          children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: Center(
                  child: Text(
                    _weekdays[streak.dayAt(i).weekday - 1],
                    style: kMonoMicro,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          children: [
            for (var i = 0; i < streak.days.length; i++)
              _DayCell(
                date: streak.dayAt(i),
                studied: streak.days[i],
                today: i == streak.days.length - 1,
              ),
          ],
        ),
        const Divider(height: 24),
        Text(
          streak.isEmpty
              ? 'No reviews yet. Rate a card in Review to start a streak.'
              : '${streak.studyDays} STUDY DAYS IN THE LAST $kStreakGridDays',
          style: streak.isEmpty ? kBodySmall : kMonoLabel,
        ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  final DateTime date;
  final bool studied;
  final bool today;

  const _DayCell({
    required this.date,
    required this.studied,
    required this.today,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          '${formatDate(date)}: ${studied ? 'studied' : 'no review'}'
          '${today ? ', today' : ''}',
      excludeSemantics: true,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: studied ? AppColors.primary : AppColors.chip,
          borderRadius: BorderRadius.circular(8),
          border: today ? Border.all(color: AppColors.ink, width: 2) : null,
        ),
        child: Text(
          '${date.day}',
          style: TextStyle(
            color: studied ? Colors.white : AppColors.muted,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

/// Average mastery and the per-deck mastery chart.
class _MasterySection extends StatelessWidget {
  final List<DeckMastery> decks;

  const _MasterySection({required this.decks});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: Text('MASTERY BY DECK', style: kMonoLabel)),
            Text(
              'AVG: ${(averageMastery(decks) * 100).round()}%',
              style: kMonoLabel,
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (decks.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'No decks yet. Add one in Library.',
                style: kBodySmall,
              ),
            ),
          )
        else
          SizedBox(
            height: 200,
            child: _MasteryChart(
              labels: [for (final d in decks) d.title],
              values: [for (final d in decks) d.mastery],
            ),
          ),
      ],
    );
  }
}

/// The reviewed cards with the lowest mastery and the button that drills
/// exactly those cards.
class _WeakestSection extends ConsumerWidget {
  final List<Flashcard> weakest;

  const _WeakestSection({required this.weakest});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('WEAKEST CARDS', style: kMonoLabel),
        const SizedBox(height: 8),
        if (weakest.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No reviews yet. Cards you review show here, weakest first.',
              style: kBodySmall,
            ),
          ),
        for (final card in weakest)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(child: Text(card.question)),
                const SizedBox(width: 8),
                PillLabel('${(card.mastery * 100).round()}% · weak'),
              ],
            ),
          ),
        if (weakest.isNotEmpty) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                // Loads the queue in the background; the Review tab shows its
                // own loading and error states.
                unawaited(
                  ref
                      .read(reviewProvider.notifier)
                      .start(cardIds: [for (final c in weakest) c.id]),
                );
                ref.read(tabIndexProvider.notifier).set(2);
              },
              child: Text(
                'Drill ${weakest.length} weak '
                '${weakest.length == 1 ? 'card' : 'cards'} now',
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Mastery by deck as a bar chart (fl_chart). Values are 0.0 to 1.0.
class _MasteryChart extends StatelessWidget {
  final List<String> labels;
  final List<double> values;

  const _MasteryChart({required this.labels, required this.values});

  @override
  Widget build(BuildContext context) {
    return BarChart(
      BarChartData(
        minY: 0,
        maxY: 100,
        alignment: BarChartAlignment.spaceAround,
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),
        barTouchData: const BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              getTitlesWidget: (value, meta) => SideTitleWidget(
                meta: meta,
                child: Text(
                  '${(values[value.toInt()] * 100).round()}%',
                  style: kMonoLabel,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (value, meta) => SideTitleWidget(
                meta: meta,
                child: SizedBox(
                  width: 64,
                  child: Text(
                    labels[value.toInt()],
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: kMonoLabel.copyWith(fontSize: 9),
                  ),
                ),
              ),
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < values.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: values[i] * 100,
                  width: 22,
                  color: AppColors.primary,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(6),
                  ),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: 100,
                    color: AppColors.chip,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
