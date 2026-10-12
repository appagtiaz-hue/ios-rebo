import 'package:flutter/material.dart';

@immutable
class HomePalette {
  const HomePalette._(this.dark);
  final bool dark;
  static HomePalette of(BuildContext context) =>
      HomePalette._(Theme.of(context).brightness == Brightness.dark);

  Color get background =>
      dark ? const Color(0xFF0E1B15) : const Color(0xFFFAFCF9);
  Color get panel => dark ? const Color(0xFF192B20) : const Color(0xFFF0F5EE);
  Color get ink => dark ? const Color(0xFFF4F7F1) : const Color(0xFF102019);
  Color get secondary =>
      dark ? const Color(0xFFCAD5C8) : const Color(0xFF506057);
  Color get border => dark ? const Color(0xFF36473B) : const Color(0xFFDCE5DB);
  Color get green => dark ? const Color(0xFFB0CBA3) : const Color(0xFF355B45);
  Color get greenSoft =>
      dark ? const Color(0xFF344E38) : const Color(0xFFE5EEE2);
  Color get button => green;
  Color get buttonInk => dark ? const Color(0xFF102019) : Colors.white;
  Color get gold => dark ? const Color(0xFFF1D185) : const Color(0xFF8A5B00);
  Color get goldSoft =>
      dark ? const Color(0xFF393320) : const Color(0xFFFAE9C8);
  Color get goldBorder =>
      dark ? const Color(0xFFCDAE64) : const Color(0xFFC19A55);
}
