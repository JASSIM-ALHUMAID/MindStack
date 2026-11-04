import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/clock.dart';
import '../core/ids.dart';
import '../core/logger.dart';

/// The time source. Override in tests with a fixed clock.
final clockProvider = Provider<Clock>((ref) => const SystemClock());

/// The id source. Override in tests with a sequential generator.
final idGeneratorProvider = Provider<IdGenerator>((ref) => UuidGenerator());

/// The error log. Override in tests to record calls.
final loggerProvider = Provider<AppLogger>((ref) => const FlutterAppLogger());
