# Câmeras e visibilidade pública

## Quem pode o quê

| Ação | Administrador | Cliente com acesso |
|------|---------------|---------------------|
| Cadastrar / excluir câmera | Sim | Não |
| Editar conexão (IP, protocolo, URL) | Sim | Não |
| **Atribuir usuários com acesso** | Sim (na tela do usuário) | Não |
| Ver IP, protocolo e dados técnicos | Sim (exceto modo privacidade) | Não |
| **Ligar/desligar “Câmera pública”** | Sim | **Sim (se tiver acesso e permissão)** |

## Modo privacidade (configurações)

Toggle **Modo privacidade** em Configurações (somente **administrador**) oculta na interface:

- URLs, paths, IP/porta e campos de conexão (cadastro/edição de câmera)
- Painel “Informações da Câmera” no player (admin)
- Detalhes técnicos em mensagens de erro do stream

O vídeo continua reproduzindo; apenas a exibição de dados sensíveis é mascarada para permitir capturas de tela sem vazar endpoints. A preferência é salva localmente (`shared_preferences`).

## Bloqueio de visibilidade pública (cliente)

O admin pode impedir que um cliente altere câmeras entre pública e privada:

- **Manual:** Usuários → menu ⋮ → *Bloquear visibilidade pública* / *Permitir visibilidade pública*
- **Automático:** mais de **10 alternâncias em 15 minutos** bloqueia o usuário (`publicToggleBlockedReason: auto`)

Campo no Firestore (`users/{uid}`):

- `canToggleCameraPublic` (bool, padrão `true`)
- `publicToggleBlockedReason` (`admin` ou `auto` quando bloqueado)

As regras Firestore também negam update de `isPublic` por clientes com `canToggleCameraPublic == false`.

Regras complementares (anti-abuso):

- Cliente pode **ler** entradas de `audit_logs` em que `actorUid` é o próprio UID (contagem de toggles).
- Cliente pode **desativar** o próprio `canToggleCameraPublic` (bloqueio automático); reativar só admin.

O painel no player continua visível (mostra status), mas o switch fica desativado com mensagem explicativa.

## Fluxo do administrador (atribuição)

1. **Adicionar câmera** — só dados técnicos; nenhum usuário é obrigatório.
2. **Usuários → toque no cliente** — lista das câmeras dele; botão **Adicionar** abre seleção de câmeras; ícone remove acesso.
3. **Editar câmera** — apenas dados técnicos e visibilidade pública (sem gestão de usuários).

Câmeras sem usuário ficam visíveis só para o admin até serem atribuídas na tela do usuário.

## Fluxo do cliente

1. Abrir **Minhas câmeras** (câmeras em que ele está em `assignedUserIds`).
2. Tocar na câmera para abrir o player.
3. Usar o painel **Câmera pública** (toggle + Saber mais) para privacidade.

## TV na sede (VMS)

Quando o sync Firestore está ativo no projeto **rondalarme-vms** (`docs/sync-cameras-publicas.md`), marcar **câmera pública** no app faz a câmera aparecer na TV (`/player`) em até ~30s; desmarcar remove da grade. Requisito: `streamPath` no cadastro no formato `app/{slug}` (ex.: `app/deni1`), alinhado ao path RTMP/MediaMTX.

## Miniatura na grid

- Ao assistir uma câmera no player, o app salva **localmente** um JPEG (último frame).
- A grid (**Minhas câmeras** / **Públicas**) exibe essa imagem no card; sem preview, mostra o placeholder verde.
- A miniatura é removida ao excluir a câmera. Não abre stream na lista (economia de rede/bateria).

## Modelo de dados

- Campo `assignedUserIds` (lista de UIDs) em cada documento `cameras/{id}`.
- Campo legado `ownerId` ainda é lido para câmeras antigas; novas gravações usam só a lista.

## Regras Firestore

- **Leitura:** admin, usuário em `assignedUserIds` (ou `ownerId` legado), ou câmera pública.
- **Cliente atualiza:** apenas `isPublic`, sem alterar a lista de acesso.
- **Admin:** create, update e delete completos.

Índice composto: `assignedUserIds` (array-contains) + `createdAt`.

```bash
firebase deploy --only firestore:rules,firestore:indexes
```

## Implementação no app

- Modelo: `lib/models/camera.dart` (`assignedUserIds`, `hasAccess`)
- Atribuição: `lib/screens/admin/user_cameras_screen.dart`, `lib/widgets/user_camera_picker_sheet.dart`
- Miniaturas: `lib/services/camera_preview_cache_service.dart`, `lib/widgets/camera_preview_thumbnail.dart`
- Permissão pública: `lib/utils/camera_permissions.dart`
- Anti-abuso: `lib/services/public_toggle_guard_service.dart`
