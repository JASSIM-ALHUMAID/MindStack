const List<String> _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Formats a date like "Nov 18, 2026".
String formatDate(DateTime d) => '${_months[d.month - 1]} ${d.day}, ${d.year}';

/// Midnight of the given day, used for day-based comparisons.
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Short interval label for rating buttons, e.g. "<10M", "1D", "12D".
String formatInterval(Duration d) {
  if (d.inMinutes < 60) return '<${d.inMinutes + 1}M';
  if (d.inHours < 24) return '${d.inHours}H';
  return '${(d.inHours / 24).round()}D';
}

/// "Today", "Tomorrow" or a date, used for the next due review.
String formatDueDay(DateTime due, [DateTime? now]) {
  final days = dateOnly(due).difference(dateOnly(now ?? DateTime.now())).inDays;
  if (days <= 0) return 'Today';
  if (days == 1) return 'Tomorrow';
  return formatDate(due);
}
