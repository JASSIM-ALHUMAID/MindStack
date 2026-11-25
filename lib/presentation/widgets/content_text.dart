import 'package:flutter/widgets.dart';

final _letter = RegExp(r'\p{L}', unicode: true);
final _rtlLetter = RegExp(
  r'[\p{Script=Arabic}\p{Script=Hebrew}]',
  unicode: true,
);

/// The direction [text] is written in, from its first letter: right to left
/// for Arabic or Hebrew, otherwise left to right. Null when it has no letters,
/// so the surrounding direction is used.
TextDirection? textDirectionOf(String text) {
  final first = _letter.firstMatch(text);
  if (first == null) return null;
  return _rtlLetter.hasMatch(first[0]!) ? TextDirection.rtl : TextDirection.ltr;
}

/// [text] ready to sit inside an English line, such as a deck title in
/// "DECK: …". Right-to-left text is wrapped in invisible Unicode isolate marks
/// (U+2068, U+2069) so it keeps its own order; other text is unchanged.
String isolateDirection(String text) =>
    textDirectionOf(text) == TextDirection.rtl ? '\u2068$text\u2069' : text;

/// [Text] for content the user wrote or imported (cards, drafts, quiz
/// options, titles). It is laid out in its own direction, so Arabic reads
/// right to left inside the English interface.
class ContentText extends StatelessWidget {
  const ContentText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    final direction = textDirectionOf(text);
    final child = Text(
      text,
      style: style,
      textAlign: textAlign,
      textDirection: direction,
      maxLines: maxLines,
      overflow: overflow,
    );
    if (textAlign != null ||
        direction == null ||
        direction == Directionality.of(context)) {
      return child;
    }
    // A short line would otherwise sit on the interface's side, not its own.
    return Align(
      alignment: AlignmentDirectional.topStart.resolve(direction),
      heightFactor: 1,
      child: child,
    );
  }
}
