import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class RondalarmeBrandTitle extends StatelessWidget {
  final double fontSize;
  final FontWeight fontWeight;
  final TextAlign textAlign;

  const RondalarmeBrandTitle({
    super.key,
    this.fontSize = 22,
    this.fontWeight = FontWeight.w700,
    this.textAlign = TextAlign.start,
  });

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontSize: fontSize, fontWeight: fontWeight);

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: 'Ronda',
            style: style.copyWith(color: AppTheme.textPrimary),
          ),
          TextSpan(
            text: 'larme',
            style: style.copyWith(color: AppTheme.lightGreen),
          ),
        ],
      ),
      textAlign: textAlign,
    );
  }
}
