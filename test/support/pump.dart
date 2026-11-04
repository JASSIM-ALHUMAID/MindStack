import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mindstack/theme/app_theme.dart';

/// Pumps [home] inside a themed `MaterialApp` and a `Scaffold`, reading
/// providers from [container].
Future<void> pumpInApp(
  WidgetTester tester,
  ProviderContainer container,
  Widget home,
) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(body: home),
      ),
    ),
  );
}

/// Pumps a `MaterialApp.router` for [router], reading providers from
/// [container].
Future<void> pumpRouter(
  WidgetTester tester,
  ProviderContainer container,
  GoRouter router,
) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(theme: buildAppTheme(), routerConfig: router),
    ),
  );
}
