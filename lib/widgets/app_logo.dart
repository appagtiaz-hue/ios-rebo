import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AppLogo extends StatelessWidget {
  final double size;
  const AppLogo({this.size = 64, super.key});

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/images/logo.svg',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}
