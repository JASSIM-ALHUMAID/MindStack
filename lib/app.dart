import 'package:flutter/material.dart';

import 'router.dart';
import 'theme/app_theme.dart';

class MindStackApp extends StatelessWidget {
  const MindStackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'MindStack',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      routerConfig: appRouter,
    );
  }
}
