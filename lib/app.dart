import 'package:flutter/material.dart';

import 'presentation/widgets/app_gate.dart';
import 'router.dart';
import 'theme/app_theme.dart';

/// The root widget. Everything is shown behind the startup [AppGate].
class MindStackApp extends StatelessWidget {
  const MindStackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'MindStack',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      routerConfig: appRouter,
      builder: (context, child) => AppGate(child: child!),
    );
  }
}
