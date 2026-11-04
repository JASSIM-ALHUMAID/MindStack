import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/core_providers.dart';
import '../save_feedback.dart';
import 'common.dart';

/// Renders an [AsyncValue] with the app's loading and error states.
///
/// While there is no value it shows [loading] (a centered spinner by
/// default); on error a [SoftCard] with [failureMessage], never the raw
/// error. Each distinct error is logged once, not on every rebuild.
class AsyncValueView<T> extends ConsumerStatefulWidget {
  /// Creates a view of [value] that builds its content with [data].
  const AsyncValueView({
    super.key,
    required this.value,
    required this.data,
    this.loading,
  });

  /// The value to render.
  final AsyncValue<T> value;

  /// Builds the content once a value is available.
  final Widget Function(T value) data;

  /// Replaces the default spinner while loading.
  final Widget? loading;

  @override
  ConsumerState<AsyncValueView<T>> createState() => _AsyncValueViewState<T>();
}

class _AsyncValueViewState<T> extends ConsumerState<AsyncValueView<T>> {
  Object? _loggedError;

  @override
  void initState() {
    super.initState();
    _logIfNew();
  }

  @override
  void didUpdateWidget(AsyncValueView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _logIfNew();
  }

  void _logIfNew() {
    final value = widget.value;
    if (!value.hasError) {
      _loggedError = null;
      return;
    }
    final error = value.error!;
    if (identical(error, _loggedError)) return;
    _loggedError = error;
    ref
        .read(loggerProvider)
        .error(
          'Could not load data',
          error,
          value.stackTrace ?? StackTrace.current,
        );
  }

  @override
  Widget build(BuildContext context) {
    return widget.value.when(
      data: widget.data,
      error: (error, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: SoftCard(child: Text(failureMessage(error))),
      ),
      loading: () =>
          widget.loading ?? const Center(child: CircularProgressIndicator()),
    );
  }
}
