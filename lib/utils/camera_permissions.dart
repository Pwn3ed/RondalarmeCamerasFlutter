import '../models/app_user.dart';
import '../providers/auth_provider.dart';
import '../models/camera.dart';

/// Painel de visibilidade pública no player (cliente com acesso ou admin).
bool shouldShowPublicVisibilityPanel(Camera camera, AuthProvider auth) {
  if (auth.isAdmin) return true;
  final uid = auth.appUser?.uid ?? auth.user?.uid;
  if (uid == null) return false;
  return camera.hasAccess(uid);
}

/// Cliente/admin atribuído pode alternar, salvo bloqueio explícito no perfil.
bool canTogglePublicVisibility(Camera camera, AuthProvider auth) {
  if (auth.isAdmin) return true;
  if (!(auth.appUser?.canToggleCameraPublic ?? true)) return false;
  final uid = auth.appUser?.uid ?? auth.user?.uid;
  if (uid == null) return false;
  return camera.hasAccess(uid);
}

String? publicToggleBlockedMessage(AppUser? user) {
  if (user == null || user.canToggleCameraPublic) return null;
  if (user.publicToggleBlockedReason == 'auto') {
    return 'Bloqueado por uso excessivo. Contate o administrador.';
  }
  return 'Alteração de visibilidade bloqueada pelo administrador.';
}
