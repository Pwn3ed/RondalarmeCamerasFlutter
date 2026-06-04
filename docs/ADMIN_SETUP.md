# Configuração do administrador inicial

## Opção automatizada (recomendada para reset total)

Se você quer apagar todos os usuários e criar apenas o primeiro admin:

1. Gere/baixe uma service account no Firebase Console  
   **Project settings** → **Service accounts** → **Generate new private key**
2. Salve o JSON em local seguro (fora do git), por exemplo: `/tmp/service-account.json`
3. Configure o arquivo local:

```bash
cd scripts
cp bootstrap-admin.config.example.json bootstrap-admin.config.json
```

4. Edite `bootstrap-admin.config.json` com seu e-mail/senha/caminho da service account
5. Execute com comando único:

```bash
cd scripts
npm install
npm run bootstrap-admin:auto
```

Se preferir, ainda pode executar via argumentos:

```bash
cd scripts
npm install
npm run bootstrap-admin -- \
  --service-account /tmp/service-account.json \
  --email admin@exemplo.com \
  --password "SenhaForte123" \
  --display-name "Administrador" \
  --wipe-users true \
  --wipe-cameras false \
  --confirm WIPE_ALL
```

O script:
- remove todos os usuários do **Firebase Authentication**
- limpa as coleções `users`, `sessions` e `audit_logs`
- opcionalmente limpa `cameras` (se `--wipe-cameras true`)
- cria o usuário admin no Auth e o documento `users/{uid}` com `role: "admin"`

Depois disso, abra o app e crie os demais usuários pelo menu de administração.

## 1. Criar conta no Firebase Authentication

1. Abra o [Firebase Console](https://console.firebase.google.com/) → projeto `rondalarmecamerasflutter`
2. Vá em **Authentication** → **Users** → **Add user**
3. Crie o e-mail e senha do administrador

## 2. Criar documento do admin no Firestore

1. Vá em **Firestore Database** → coleção `users`
2. Crie documento com ID = **UID** do usuário criado no passo 1
3. Campos:

```json
{
  "email": "admin@exemplo.com",
  "displayName": "Administrador",
  "role": "admin",
  "mustChangePassword": false,
  "disabled": false,
  "maxDevices": 99,
  "createdAt": "<timestamp agora>"
}
```

## 3. Publicar regras de segurança

Na raiz do projeto do app:

```bash
firebase deploy --only firestore:rules,firestore:indexes
```

(Requer Firebase CLI logado no projeto.)

## 4. Primeiro login

Abra o app, faça login com a conta admin. O menu de administração (ícone de escudo) permite:

- **Usuários** — criar, editar (nome, tipo, dispositivos, permissões) clientes ou outros administradores; senha gerada automaticamente na criação
- **Sessões** — ver/revogar dispositivos conectados
- **Logs** — auditoria de ações
