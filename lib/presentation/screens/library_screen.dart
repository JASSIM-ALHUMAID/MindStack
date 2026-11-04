import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../application/cards.dart';
import '../../application/library.dart';
import '../../application/services.dart';
import '../../domain/models/course.dart';
import '../../domain/models/deck.dart';
import '../../domain/models/deck_stats.dart';
import '../../route_names.dart';
import '../../theme/app_theme.dart';
import '../widgets/async_value_view.dart';
import '../widgets/common.dart';
import '../widgets/create_course_sheet.dart';
import '../widgets/create_deck_sheet.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courses = ref.watch(coursesProvider);
    final decks = ref.watch(decksProvider);
    final stats = ref.watch(deckStatsProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        ScreenHeader(
          eyebrow: 'COURSES AND DECKS',
          title: 'Library',
          trailing: FilledButton.icon(
            onPressed: () => unawaited(showCreateCourseSheet(context)),
            icon: const Icon(LucideIcons.plus, size: 18),
            label: const Text('Course'),
          ),
        ),
        const SizedBox(height: 16),
        AsyncValueView<List<Course>>(
          value: courses,
          data: (courses) => AsyncValueView<List<Deck>>(
            value: decks,
            data: (decks) => AsyncValueView<Map<String, DeckStats>>(
              value: stats,
              data: (stats) => _CourseList(
                courses: courses,
                decks: decks,
                stats: stats,
                now: ref.read(clockProvider).now(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CourseList extends StatelessWidget {
  final List<Course> courses;
  final List<Deck> decks;
  final Map<String, DeckStats> stats;
  final DateTime now;

  const _CourseList({
    required this.courses,
    required this.decks,
    required this.stats,
    required this.now,
  });

  @override
  Widget build(BuildContext context) {
    if (courses.isEmpty) {
      // Matches the Library (Empty State) frame: centered text, no card.
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 200),
        child: Center(child: Text('No courses yet. Tap + Course to add one.')),
      );
    }
    return Column(
      children: [
        for (final course in courses) ...[
          _CourseCard(
            course: course,
            decks: decks.where((d) => d.courseId == course.id).toList(),
            stats: stats,
            now: now,
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class _CourseCard extends StatelessWidget {
  final Course course;
  final List<Deck> decks;
  final Map<String, DeckStats> stats;
  final DateTime now;

  const _CourseCard({
    required this.course,
    required this.decks,
    required this.stats,
    required this.now,
  });

  @override
  Widget build(BuildContext context) {
    final days = course.daysToExam(now);
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  course.title,
                  style: kSerifTitle.copyWith(fontSize: 20),
                ),
              ),
              const SizedBox(width: 8),
              PillLabel('$days days to exam'),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${decks.length} ${decks.length == 1 ? 'DECK' : 'DECKS'}',
            style: kMonoLabel,
          ),
          const SizedBox(height: 8),
          if (decks.isEmpty) ...[
            const Divider(height: 1),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text(
                'No decks yet. Add a deck to start adding cards.',
                style: kBodySmall,
              ),
            ),
          ],
          for (final deck in decks) ...[
            const Divider(height: 1),
            _DeckRow(deck: deck, stats: stats[deck.id]),
          ],
          const Divider(height: 1),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => unawaited(showCreateDeckSheet(context, course)),
              icon: const Icon(LucideIcons.plus, size: 16),
              label: const Text('Deck'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeckRow extends StatelessWidget {
  final Deck deck;

  /// Null for a deck that has no cards yet.
  final DeckStats? stats;

  const _DeckRow({required this.deck, required this.stats});

  @override
  Widget build(BuildContext context) {
    final count = stats?.cardCount ?? 0;
    final mastery = stats?.mastery ?? 0.0;
    return InkWell(
      onTap: () => unawaited(context.push<void>(RouteNames.deckPath(deck.id))),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(deck.title, style: const TextStyle(fontSize: 16)),
                  Text(
                    '$count ${count == 1 ? 'CARD' : 'CARDS'}',
                    style: kMonoLabel,
                  ),
                ],
              ),
            ),
            MasteryBar(value: mastery),
          ],
        ),
      ),
    );
  }
}
