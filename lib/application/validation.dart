import '../domain/failures.dart';

/// Returns [value] trimmed, or throws [InvalidInput] for [field] with
/// [reason] when nothing is left.
String requireText(
  String value, {
  required String field,
  required String reason,
}) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) throw InvalidInput(field: field, reason: reason);
  return trimmed;
}
