import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/services.dart';
import '../../application/startup.dart';
import '../../theme/app_theme.dart';

/// Shows [child] once the database is open and seeded. Until then it shows a
/// spinner, or on failure an explanation with a Retry button that reopens the
/// database.
class AppGate extends ConsumerWidget {
  /// Creates a gate in front of [child].
  const AppGate({super.key, required this.child});

  /// The app, shown once startup succeeded.
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final startup = ref.watch(appStartupProvider);
    return startup.when(
      data: (_) => child,
      loading: () => const _GateScaffold(
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => _StartupError(
        error: error,
        stack: stack,
        onRetry: ref.read(startupRetryProvider),
      ),
    );
  }
}

class _GateScaffold extends StatelessWidget {
  const _GateScaffold({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(child: child),
    );
  }
}

class _StartupError extends ConsumerStatefulWidget {
  const _StartupError({
    required this.error,
    required this.stack,
    required this.onRetry,
  });

  final Object error;
  final StackTrace stack;
  final VoidCallback onRetry;

  @override
  ConsumerState<_StartupError> createState() => _StartupErrorState();
}

class _StartupErrorState extends ConsumerState<_StartupError> {
  @override
  void initState() {
    super.initState();
    ref
        .read(loggerProvider)
        .error('Startup failed', widget.error, widget.stack);
  }

  @override
  Widget build(BuildContext context) {
    return _GateScaffold(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "MindStack couldn't open your data.",
                style: kSerifTitle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Try again. If this keeps happening, restart the app.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: widget.onRetry,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
