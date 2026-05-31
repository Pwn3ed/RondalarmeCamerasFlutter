import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Explica o que significa tornar a câmera pública.
void showPublicCameraHelpDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('O que é Câmera Pública?'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quando ativada, sua câmera fica visível para outras pessoas '
              'autorizadas a usar o aplicativo.',
              style: Theme.of(dialogContext).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            _HelpBullet(
              icon: Icons.public,
              text:
                  'Disponível em Câmeras Públicas para todos os usuários do aplicativo.',
            ),
            const SizedBox(height: 12),
            _HelpBullet(
              icon: Icons.dashboard_outlined,
              text: 'Disponível no painel de monitoramento da empresa.',
            ),
            const SizedBox(height: 16),
            Text(
              'Quando desativada, somente você consegue ver esta câmera.',
              style: Theme.of(dialogContext).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Dica: desative ao chegar em casa se quiser mais privacidade.',
              style: Theme.of(dialogContext).textTheme.bodySmall?.copyWith(
                color: AppTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Entendi'),
        ),
      ],
    ),
  );
}

class _HelpBullet extends StatelessWidget {
  final IconData icon;
  final String text;

  const _HelpBullet({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppTheme.lightGreen),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

/// Toggle simples de visibilidade pública, com opção de saber mais.
class PublicVisibilityPanel extends StatelessWidget {
  final bool isPublic;
  final bool isLoading;
  final ValueChanged<bool>? onChanged;
  final String? blockedMessage;

  const PublicVisibilityPanel({
    super.key,
    required this.isPublic,
    required this.isLoading,
    required this.onChanged,
    this.blockedMessage,
  });

  @override
  Widget build(BuildContext context) {
    final statusText = isPublic ? 'Ativada' : 'Desativada';
    final statusColor = isPublic ? AppTheme.lightGreen : AppTheme.textSecondary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Material(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isPublic ? AppTheme.lightGreen : AppTheme.borderDark,
              width: isPublic ? 1.5 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Câmera Pública',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            statusText,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (blockedMessage != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              blockedMessage!,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.orange.shade300,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (isLoading)
                      const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    else
                      Transform.scale(
                        scale: 1.2,
                        child: Switch(
                          value: isPublic,
                          onChanged: onChanged,
                          activeThumbColor: AppTheme.primaryWhite,
                          activeTrackColor: AppTheme.lightGreen,
                          inactiveThumbColor: AppTheme.textSecondary,
                          inactiveTrackColor: AppTheme.surfaceElevated,
                        ),
                      ),
                  ],
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => showPublicCameraHelpDialog(context),
                    icon: const Icon(Icons.info_outline, size: 18),
                    label: const Text('Saber mais'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.accentGreen,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 4,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
