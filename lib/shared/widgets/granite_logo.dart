import 'package:flutter/material.dart';

class GraniteLogo extends StatelessWidget {
  const GraniteLogo({
    this.size = 96,
    super.key,
  });

  static const assetName = 'assets/images/logo.png';

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.18),
      decoration: BoxDecoration(
        color: const Color(0xFF2F312D),
        borderRadius: BorderRadius.circular(size * 0.2),
      ),
      child: Image.asset(
        assetName,
        fit: BoxFit.contain,
        semanticLabel: 'GRANITE',
      ),
    );
  }
}
