import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/library_provider.dart';
import '../providers/review_provider.dart';
import '../providers/tab_provider.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  // Planner inputs belong to this screen only, so plain setState is used.
  late DateTime _examDate = dateOnly(DateTime.now()).add(const Duration(days: 21));
  final TextEditingController _totalController = TextEditingController(text: '40');
  String? _planText;
  int? _planDays;

  // Placeholder study history (days of the last 4 weeks with no session).
  static const Set<int> _missedDays = {3, 6, 11, 12, 15, 18};

  @override
  void dispose() {
    _totalController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final today = dateOnly(DateTime.now());
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
    final days = _examDate.difference(dateOnly(DateTime.now())).inDays;
    if (total == null || total <= 0 || days <= 0) {
      setState(() {
        _planText = 'Enter a card total and an exam date in the future.';
        _planDays = null;
      });
      return;
    }
    final perDay = (total / days).ceil();
    setState(() {
      _planText = '$perDay cards per day to cover all $total cards. Review the weakest ones first.';
      _planDays = days;
    });
  }

  @override
  Widget build(BuildContext context) {
    final decks = ref.watch(decksProvider);
    final cards = ref.watch(cardsProvider);
    final avgMastery = cards.isEmpty
        ? 0.0
        : cards.fold<double>(0, (sum, c) => sum + c.mastery) / cards.length;
    final weakest = ([...cards]..sort((a, b) => a.mastery.compareTo(b.mastery)))
        .take(3)
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        const ScreenHeader(eyebrow: 'MASTERY · STREAK · EXAMS', title: 'Stats'),
        const SizedBox(height: 16),
        SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Study streak', style: kSerifSection),
                        Text('7-DAY STREAK', style: kMonoLabel),
                      ],
                    ),
                  ),
                  Text('7', style: kSerifTitle.copyWith(fontSize: 36)),
                  const Text(' DAYS', style: kMonoLabel),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  for (final d in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                    Expanded(child: Center(child: Text(d, style: kMonoMicro))),
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
                  for (var day = 1; day <= 28; day++)
                    Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _missedDays.contains(day) ? AppColors.chip : AppColors.primary,
                        borderRadius: BorderRadius.circular(8),
                        // Day 28 is today in the placeholder history.
                        border: day == 28
                            ? Border.all(color: AppColors.ink, width: 2)
                            : null,
                      ),
                      child: Text(
                        '$day',
                        style: TextStyle(
                          color: _missedDays.contains(day) ? AppColors.muted : Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
              const Divider(height: 24),
              Text('${28 - _missedDays.length} SESSIONS LOGGED (SAMPLE DATA)', style: kMonoLabel),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(child: Text('MASTERY BY DECK', style: kMonoLabel)),
                  Text('AVG: ${(avgMastery * 100).round()}%', style: kMonoLabel),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 200,
                child: _MasteryChart(
                  labels: [for (final d in decks) d.title],
                  values: [for (final d in decks) ref.watch(deckMasteryProvider(d.id))],
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
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(onPressed: _plan, child: const Text('Plan')),
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
                          const Expanded(child: Text('PLAN', style: kMonoLabel)),
                          if (_planDays != null) PillLabel('$_planDays days', filled: true),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('WEAKEST CARDS', style: kMonoLabel),
              const SizedBox(height: 8),
              for (final card in weakest)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Expanded(child: Text(card.question)),
                      const PillLabel('WEAK'),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    ref.read(reviewProvider.notifier).startWeak();
                    ref.read(tabIndexProvider.notifier).set(2);
                  },
                  child: Text('Drill ${weakest.length} weak cards now'),
                ),
              ),
            ],
          ),
        ),
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
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
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
