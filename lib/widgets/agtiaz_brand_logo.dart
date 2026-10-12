import 'package:flutter/material.dart';

class AgtiazBrandLogo extends StatelessWidget {
  const AgtiazBrandLogo({super.key, this.size = 112});
  final double size;
  static const asset = 'assets/images/agtiaz_white_logo.png';

  @override
  Widget build(BuildContext context) => ClipOval(
    child: SizedBox(
      width: size,
      height: size,
      child: ColoredBox(
        color: Colors.white,
        child: Transform.scale(
          // Remove the adaptive launcher's transparent safety margin in the UI.
          scale: 1.5,
          child: Image.asset(
            asset,
            fit: BoxFit.cover,
            excludeFromSemantics: true,
          ),
        ),
      ),
    ),
  );
}
