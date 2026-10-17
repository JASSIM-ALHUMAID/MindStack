import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/course.dart';
import '../models/deck.dart';
import '../providers/library_provider.dart';
import '../route_names.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/create_course_sheet.dart';
import '../widgets/create_deck_sheet.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courses = ref.watch(coursesProvider);
    final decks = ref.watch(decksProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        ScreenHeader(
          eyebrow: 'COURSES AND DECKS',
          title: 'Library',
          trailing: FilledButton.icon(
            onPressed: () => showCreateCourseSheet(context),
            icon: const Icon(LucideIcons.plus, size: 18),
            label: const Text('Course'),
          ),
        ),
        const SizedBox(height: 16),
        if (courses.isEmpty)
          // Matches the Library (Empty State) frame: centered text, no card.
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 200),
            child: Center(child: Text('No courses yet. Tap + Course to add one.')),
          ),
        for (final course in courses) ...[
          _CourseCard(
            course: course,
            decks: decks.where((d) => d.courseId == course.id).toList(),
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

  const _CourseCard({required this.course, required this.decks});

  @override
  Widget build(BuildContext context) {
    final days = course.daysToExam();
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
          Text('${decks.length} ${decks.length == 1 ? 'DECK' : 'DECKS'}', style: kMonoLabel),
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
            _DeckRow(deck: deck),
          ],
          const Divider(height: 1),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => showCreateDeckSheet(context, course),
              icon: const Icon(LucideIcons.plus, size: 16),
              label: const Text('Deck'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeckRow extends ConsumerWidget {
  final Deck deck;

  const _DeckRow({required this.deck});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(deckCardsProvider(deck.id)).length;
    final mastery = ref.watch(deckMasteryProvider(deck.id));
    return InkWell(
      onTap: () => context.push(RouteNames.deckPath(deck.id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(deck.title, style: const TextStyle(fontSize: 16)),
                  Text('$count ${count == 1 ? 'CARD' : 'CARDS'}', style: kMonoLabel),
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
