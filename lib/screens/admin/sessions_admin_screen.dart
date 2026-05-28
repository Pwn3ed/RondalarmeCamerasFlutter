import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/app_session.dart';
import '../../services/audit_log_service.dart';
import '../../services/session_service.dart';
import '../../services/user_service.dart';
import '../../theme/app_theme.dart';

class SessionsAdminScreen extends StatefulWidget {
  const SessionsAdminScreen({super.key});

  @override
  State<SessionsAdminScreen> createState() => _SessionsAdminScreenState();
}

class _SessionsAdminScreenState extends State<SessionsAdminScreen> {
  final _sessionService = SessionService();
  final _userService = UserService();
  final _auditLog = AuditLogService();

  bool _activeOnly = true;
  List<AppSession> _sessions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _sessions = await _sessionService.fetchSessions(activeOnly: _activeOnly);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, int> _activeCountByUser() {
    final map = <String, int>{};
    for (final s in _sessions.where((s) => s.isActive)) {
      map[s.uid] = (map[s.uid] ?? 0) + 1;
    }
    return map;
  }

  Future<void> _revokeSession(AppSession session) async {
    final adminUid = FirebaseAuth.instance.currentUser?.uid;
    await _sessionService.endSessionById(
      session.id,
      endReason: 'revoked_by_admin',
      revokedBy: adminUid,
    );
    await _auditLog.log(
      action: 'session_revoked',
      targetUid: session.uid,
      targetSessionId: session.id,
      metadata: {'reason': 'revoked_by_admin'},
    );
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sessão revogada')),
      );
    }
  }

  Future<void> _disableUser(String uid) async {
    final adminUid = FirebaseAuth.instance.currentUser?.uid;
    await _userService.setDisabled(uid, true);
    await _sessionService.revokeAllActiveForUser(
      uid,
      endReason: 'revoked_by_admin',
      revokedBy: adminUid,
    );
    await _auditLog.log(action: 'user_disabled', targetUid: uid);
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Conta bloqueada e sessões encerradas')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final multiDevice = _activeCountByUser();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sessões ativas'),
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: AppTheme.primaryWhite,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: Column(
        children: [
          SwitchListTile(
            title: const Text('Somente sessões ativas'),
            value: _activeOnly,
            onChanged: (v) {
              setState(() => _activeOnly = v);
              _load();
            },
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.primaryGreen,
                    ),
                  )
                : _sessions.isEmpty
                    ? const Center(child: Text('Nenhuma sessão encontrada'))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _sessions.length,
                          itemBuilder: (context, index) {
                            final s = _sessions[index];
                            final isMulti = (multiDevice[s.uid] ?? 0) > 1;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                title: Text(s.deviceLabel),
                                subtitle: Text(
                                  'UID: ${s.uid}\n'
                                  'Plataforma: ${s.platform} · v${s.appVersion}\n'
                                  'Device ID: ${s.deviceId}\n'
                                  'Último sinal: ${_formatDate(s.lastSeenAt)}'
                                  '${s.endedAt != null ? '\nEncerrada: ${s.endReason}' : ''}',
                                ),
                                isThreeLine: true,
                                leading: Icon(
                                  s.isActive ? Icons.phone_android : Icons.block,
                                  color: s.isActive
                                      ? AppTheme.primaryGreen
                                      : Colors.grey,
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isMulti && s.isActive)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        margin: const EdgeInsets.only(right: 8),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.shade100,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Text(
                                          'MULTI',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.orange,
                                          ),
                                        ),
                                      ),
                                    if (s.isActive)
                                      IconButton(
                                        icon: const Icon(Icons.logout, color: Colors.red),
                                        tooltip: 'Revogar sessão',
                                        onPressed: () => _revokeSession(s),
                                      ),
                                  ],
                                ),
                                onLongPress: s.isActive
                                    ? () => _showUserActions(context, s)
                                    : null,
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  void _showUserActions(BuildContext context, AppSession session) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.block, color: Colors.red),
              title: const Text('Bloquear conta deste usuário'),
              onTap: () {
                Navigator.pop(ctx);
                _disableUser(session.uid);
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.year} ${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }
}
