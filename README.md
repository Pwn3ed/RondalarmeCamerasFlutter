# Rondalarme Câmeras

Aplicativo Flutter para monitoramento de câmeras de segurança em tempo real.

## 🚀 Como Rodar

```bash
git clone https://github.com/pwn3ed/rondalarmecamerasflutter.git
cd rondalarmecamerasflutter
git checkout dev         # branch de desenvolvimento (main = oficial)
fvm install && fvm use   # opcional: ver docs/CI_CD.md
fvm flutter pub get
fvm flutter run
```

> Firebase já configurado. Basta clonar e executar.  
> O projeto usa **Flutter 3.35.5** fixado (FVM + CI). Sem FVM, use essa versão globalmente.

## 📱 Funcionalidades

- Autenticação de usuários (login/registro)
- Cadastro e gerenciamento de câmeras
- Reprodução de streams HLS/HTTP
- Modo fullscreen com rotação automática
- Sincronização em nuvem via Firebase

## 🛠️ Tecnologias

- Flutter 3.35.5 (versão fixada — ver `docs/CI_CD.md`)
- Firebase (Auth + Firestore)
- video_player
- Provider (gerenciamento de estado)

## 📋 Requisitos

- Flutter SDK **3.35.5** (ou [FVM](https://fvm.app) apontando para `.fvm/fvm_config.json`)
- Android/iOS device ou emulador

## 📦 Build

```bash
# Android
flutter build apk --release

# iOS
flutter build ios --release
```

## 📜 Licença

Copyright © 2025 Diego Michel Prestes. Todos os direitos reservados.