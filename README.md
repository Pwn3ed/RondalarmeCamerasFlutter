# RondAlarme Câmeras Flutter

Aplicativo Flutter para visualização de câmeras de segurança com suporte a streams HLS.

## Funcionalidades

- **Lista de Câmeras**: Visualize todas as câmeras cadastradas
- **Cadastro de Câmeras**: Adicione novas câmeras com configurações personalizadas
- **Edição de Câmeras**: Modifique dados de câmeras já cadastradas
- **Player de Vídeo**: Reproduza streams HLS das câmeras em tempo real
- **Gerenciamento**: Ative/desative câmeras e exclua registros
- **Interface Moderna**: Design com tema verde, preto e branco

## Tecnologias Utilizadas

- **Flutter**: Framework principal
- **video_player**: Reprodução de streams HLS
- **provider**: Gerenciamento de estado
- **shared_preferences**: Armazenamento local
- **uuid**: Geração de IDs únicos

## Configuração do Servidor

O aplicativo espera que você tenha um servidor configurado que:

1. Recebe streams RTMP das câmeras
2. Converte para formato HLS
3. Disponibiliza os streams na rede

### Exemplo de Configuração (Node-Media-Server)

```javascript
const NodeMediaServer = require('node-media-server');

const config = {
  rtmp: {
    port: 1935,
    chunk_size: 60000,
    gop_cache: true,
    ping: 30,
    ping_timeout: 60
  },
  http: {
    port: 8080,
    allow_origin: '*'
  },
  trans: {
    ffmpeg: '/usr/bin/ffmpeg',
    tasks: [
      {
        app: 'live',
        hls: true,
        hlsFlags: '[hls_time=2:hls_list_size=3:hls_flags=delete_segments]',
        dash: true,
        dashFlags: '[f=dash:window_size=3:extra_window_size=5]'
      }
    ]
  }
};

const nms = new NodeMediaServer(config);
nms.run();
```

## Como Usar

### 1. Cadastrar uma Câmera

1. Toque no botão "+" na tela principal
2. Preencha as informações:
   - **Nome**: Nome da câmera
   - **Descrição**: Descrição opcional
   - **IP do Servidor**: IP do servidor HLS
   - **Porta**: Porta do servidor (ex: 8080)
   - **Caminho do Stream**: Caminho do arquivo .m3u8 (ex: /live/camera1.m3u8)

### 2. Visualizar Câmeras

- A tela principal mostra todas as câmeras cadastradas
- Toque em uma câmera para reproduzir o stream
- Use o switch para ativar/desativar câmeras
- Toque no ícone de editar (lápis) para modificar a câmera
- Toque no ícone de lixeira para excluir

### 3. Reproduzir Stream

- Toque em uma câmera para abrir o player
- O stream inicia automaticamente
- Use os controles para pausar/reproduzir
- Toque no ícone de refresh para reconectar
- Toque no ícone de editar para modificar a câmera

## Estrutura do Projeto

```
lib/
├── models/
│   └── camera.dart          # Modelo de dados da câmera
├── providers/
│   └── camera_provider.dart # Gerenciamento de estado
├── screens/
│   ├── cameras_list_screen.dart    # Lista de câmeras
│   ├── add_camera_screen.dart      # Cadastro de câmeras
│   ├── edit_camera_screen.dart     # Edição de câmeras
│   └── camera_player_screen.dart   # Player de vídeo
├── services/
│   └── camera_service.dart  # Serviços de dados
├── theme/
│   └── app_theme.dart       # Tema personalizado
└── main.dart                # Ponto de entrada
```

## Instalação

1. Clone o repositório
2. Execute `flutter pub get` para instalar as dependências
3. Execute `flutter run` para iniciar o aplicativo

## Configuração de Rede

O aplicativo está configurado para permitir tráfego HTTP (não seguro) para servidores de câmeras. Isso é necessário para conectar com servidores de streaming que não usam HTTPS.

### Permissões Configuradas:
- `INTERNET`: Acesso à internet
- `ACCESS_NETWORK_STATE`: Verificação do estado da rede
- `usesCleartextTraffic="true"`: Permite tráfego HTTP

### IPs Permitidos:
- `45.174.236.195` (seu servidor)
- `localhost` e `10.0.2.2` (para desenvolvimento)
- Redes locais: `192.168.0.0/16`, `10.0.0.0/8`, `172.16.0.0/12`

## Dependências

```yaml
dependencies:
  flutter:
    sdk: flutter
  video_player: ^2.8.2
  video_player_web: ^2.1.2
  http: ^1.1.2
  shared_preferences: ^2.2.2
  path_provider: ^2.1.2
  provider: ^6.1.1
  uuid: ^4.2.1
```

## Suporte

Para suporte ou dúvidas, entre em contato através dos canais oficiais do projeto.
