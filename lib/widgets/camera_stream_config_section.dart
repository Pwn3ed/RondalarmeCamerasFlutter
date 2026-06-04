import 'package:flutter/material.dart';
import '../models/camera_protocol.dart';
import '../theme/app_theme.dart';

/// Campos de conexão conforme o protocolo selecionado.
class CameraStreamConfigSection extends StatelessWidget {
  final CameraProtocol protocol;
  final ValueChanged<CameraProtocol?> onProtocolChanged;
  final bool isManualMode;
  final ValueChanged<bool> onManualModeChanged;
  final TextEditingController serverIpController;
  final TextEditingController serverPortController;
  final TextEditingController streamPathController;
  final TextEditingController manualUrlController;
  final TextEditingController rtspUrlController;
  final TextEditingController httpFileUrlController;
  final bool privacyMode;

  const CameraStreamConfigSection({
    super.key,
    required this.protocol,
    required this.onProtocolChanged,
    required this.isManualMode,
    required this.onManualModeChanged,
    required this.serverIpController,
    required this.serverPortController,
    required this.streamPathController,
    required this.manualUrlController,
    required this.rtspUrlController,
    required this.httpFileUrlController,
    this.privacyMode = false,
  });

  String _protocolHint() {
    switch (protocol) {
      case CameraProtocol.hls:
        return 'Stream via servidor (HLS gerado a partir do caminho RTMP/Intelbras).';
      case CameraProtocol.rtsp:
        return 'Acesso direto à câmera ou DVR pela URL RTSP (porta 554, credenciais, etc.).';
      case CameraProtocol.httpFile:
        return 'Arquivo de vídeo servido por HTTP (.mp4 ou .mkv). Útil para links diretos ou testes.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Conexão da câmera',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppTheme.accentGreen,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<CameraProtocol>(
              value: protocol,
              decoration: const InputDecoration(
                labelText: 'Protocolo *',
                prefixIcon: Icon(Icons.settings_input_component),
              ),
              items: CameraProtocol.values
                  .map((p) => DropdownMenuItem(value: p, child: Text(p.label)))
                  .toList(),
              onChanged: onProtocolChanged,
            ),
            if (!privacyMode) ...[
              const SizedBox(height: 8),
              Text(
                _protocolHint(),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 16),
            if (privacyMode)
              Text(
                'Servidor, caminho e URLs ocultos no modo privacidade. '
                'Desative em Configurações para editar ou visualizar.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textMuted,
                ),
              )
            else ...[
              if (protocol == CameraProtocol.hls) ..._hlsFields(context),
              if (protocol == CameraProtocol.rtsp) ..._rtspFields(),
              if (protocol == CameraProtocol.httpFile) ..._httpFileFields(),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _hlsFields(BuildContext context) {
    return [
      Row(
        children: [
          Text('Modo:', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(width: 16),
          Text(
            isManualMode ? 'Manual' : 'Automático',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppTheme.accentGreen,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          Switch(
            value: isManualMode,
            onChanged: onManualModeChanged,
            thumbColor: const WidgetStatePropertyAll(AppTheme.primaryGreen),
          ),
        ],
      ),
      const SizedBox(height: 16),
      if (!isManualMode) ...[
        Text(
          'Preencha os campos para gerar a URL HLS automaticamente:',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: serverIpController,
          decoration: const InputDecoration(
            labelText: 'Servidor (DDNS/IP) *',
            hintText: 'rondagprs.ddns.net',
            prefixIcon: Icon(Icons.dns),
          ),
          enableSuggestions: false,
          autocorrect: false,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Informe o servidor';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: serverPortController,
          decoration: const InputDecoration(
            labelText: 'Porta *',
            hintText: '8888',
            prefixIcon: Icon(Icons.settings_ethernet),
          ),
          enableSuggestions: false,
          autocorrect: false,
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Informe a porta';
            }
            final port = int.tryParse(value.trim());
            if (port == null || port < 1 || port > 65535) {
              return 'Porta inválida (1-65535)';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: streamPathController,
          decoration: const InputDecoration(
            labelText: 'Caminho *',
            hintText: 'app/deni',
            prefixIcon: Icon(Icons.folder),
          ),
          enableSuggestions: false,
          autocorrect: false,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Informe o caminho';
            }
            return null;
          },
        ),
      ],
      if (isManualMode) ...[
        Text(
          'URL completa do stream HLS:',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: manualUrlController,
          decoration: const InputDecoration(
            labelText: 'URL HLS *',
            hintText: 'http://servidor.com:8888/app/stream/video1_stream.m3u8',
            prefixIcon: Icon(Icons.link),
          ),
          enableSuggestions: false,
          autocorrect: false,
          maxLines: 2,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Digite a URL do stream';
            }
            final v = value.trim().toLowerCase();
            if (!v.startsWith('http://') && !v.startsWith('https://')) {
              return 'URL deve começar com http:// ou https://';
            }
            return null;
          },
        ),
      ],
    ];
  }

  List<Widget> _rtspFields() {
    return [
      TextFormField(
        controller: rtspUrlController,
        decoration: const InputDecoration(
          labelText: 'URL RTSP *',
          hintText:
              'rtsp://usuario:senha@192.168.1.10:554/cam/realmonitor?channel=1',
          prefixIcon: Icon(Icons.settings_input_antenna),
          helperText:
              'Use o IP da rede (não localhost). MediaMTX: porta 8554 — ufw allow 8554/tcp',
        ),
        enableSuggestions: false,
        autocorrect: false,
        maxLines: 2,
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Informe a URL RTSP';
          }
          if (!value.trim().toLowerCase().startsWith('rtsp://')) {
            return 'URL deve começar com rtsp://';
          }
          return null;
        },
      ),
    ];
  }

  List<Widget> _httpFileFields() {
    return [
      TextFormField(
        controller: httpFileUrlController,
        decoration: const InputDecoration(
          labelText: 'URL do vídeo *',
          hintText: 'http://192.168.1.10:8080/gravacao.mp4',
          prefixIcon: Icon(Icons.movie),
          helperText:
              'Use o IP do PC na rede Wi‑Fi (não localhost). Servidor: python -m http.server 8080 --bind 0.0.0.0',
        ),
        enableSuggestions: false,
        autocorrect: false,
        maxLines: 2,
        validator: validateHttpFileUrlField,
      ),
    ];
  }
}
