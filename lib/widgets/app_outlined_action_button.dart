import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Botão outline de largura total, cantos moderadamente arredondados (padrão do app).
class AppOutlinedActionButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final IconData icon;
  final bool isLoading;

  const AppOutlinedActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.color,
    required this.icon,
    this.isLoading = false,
  });

  static ButtonStyle _style(Color color) {
    return OutlinedButton.styleFrom(
      foregroundColor: color,
      disabledForegroundColor: AppTheme.textMuted,
      side: BorderSide(color: color, width: 1.5),
      padding: const EdgeInsets.symmetric(vertical: 18),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: isLoading ? null : onPressed,
        style: _style(color),
        icon: isLoading
            ? SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: color,
                ),
              )
            : Icon(icon, size: 22),
        label: Text(
          label,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
