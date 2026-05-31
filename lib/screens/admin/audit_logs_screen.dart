import 'package:flutter/material.dart';

import '../../models/audit_log_entry.dart';
import '../../services/audit_log_service.dart';
import '../../theme/app_theme.dart';

class AuditLogsScreen extends StatefulWidget {
  const AuditLogsScreen({super.key});

  @override
  State<AuditLogsScreen> createState() => _AuditLogsScreenState();
}

class _AuditLogsScreenState extends State<AuditLogsScreen> {
  final _auditLog = AuditLogService();
  final List<AuditLogEntry> _logs = [];
  bool _loading = true;
  bool _loadingMore = false;
  String? _actionFilter;

  static const _actions = [
    null,
    'login',
    'logout',
    'login_blocked',
    'multi_device_warning',
    'password_changed',
    'force_change_set',
    'reset_sent',
    'user_created',
    'user_disabled',
    'user_enabled',
    'session_revoked',
    'camera_created',
    'camera_updated',
    'camera_deleted',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool refresh = false}) async {
    if (refresh) {
      _logs.clear();
    }
    setState(() => _loading = true);

    try {
      final items = await _auditLog.fetchRecent(
        limit: 50,
        actionFilter: _actionFilter,
      );
      if (mounted) {
        setState(() {
          _logs
            ..clear()
            ..addAll(items);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _logs.isEmpty) return;
    setState(() => _loadingMore = true);

    try {
      // fetchRecent doesn't expose last doc easily - reload with larger limit for MVP
      final items = await _auditLog.fetchRecent(
        limit: _logs.length + 50,
        actionFilter: _actionFilter,
      );
      if (mounted) {
        setState(() {
          _logs
            ..clear()
            ..addAll(items);
          _loadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Logs de auditoria'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _load(refresh: true),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: DropdownButtonFormField<String?>(
              initialValue: _actionFilter,
              decoration: const InputDecoration(
                labelText: 'Filtrar por ação',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: _actions
                  .map(
                    (a) =>
                        DropdownMenuItem(value: a, child: Text(a ?? 'Todas')),
                  )
                  .toList(),
              onChanged: (v) {
                setState(() => _actionFilter = v);
                _load(refresh: true);
              },
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.primaryGreen,
                    ),
                  )
                : _logs.isEmpty
                ? RefreshIndicator(
                    onRefresh: () => _load(refresh: true),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(
                          height: 300,
                          child: Center(child: Text('Nenhum log encontrado')),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () => _load(refresh: true),
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: _logs.length + 1,
                      itemBuilder: (context, index) {
                        if (index == _logs.length) {
                          return Padding(
                            padding: const EdgeInsets.all(16),
                            child: Center(
                              child: _loadingMore
                                  ? const CircularProgressIndicator()
                                  : TextButton(
                                      onPressed: _loadMore,
                                      child: const Text('Carregar mais'),
                                    ),
                            ),
                          );
                        }

                        final log = _logs[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          child: ListTile(
                            title: Text(
                              log.action,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              '${log.actorEmail}\n'
                              '${_formatDate(log.createdAt)}'
                              '${log.targetUid != null ? '\nAlvo: ${log.targetUid}' : ''}',
                            ),
                            isThreeLine: true,
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _showDetail(log),
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

  void _showDetail(AuditLogEntry log) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(log.action),
        content: SingleChildScrollView(
          child: Text(
            'Ator: ${log.actorEmail} (${log.actorUid})\n'
            'Data: ${_formatDate(log.createdAt)}\n'
            '${log.targetUid != null ? 'Target UID: ${log.targetUid}\n' : ''}'
            '${log.targetCameraId != null ? 'Target Camera: ${log.targetCameraId}\n' : ''}'
            '${log.targetSessionId != null ? 'Target Session: ${log.targetSessionId}\n' : ''}'
            '\nMetadata:\n${log.metadata.entries.map((e) => '${e.key}: ${e.value}').join('\n')}',
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.year} ${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}:${d.second.toString().padLeft(2, '0')}';
  }
}
