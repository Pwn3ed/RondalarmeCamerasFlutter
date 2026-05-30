# CI/CD

Documentação do pipeline de integração contínua (CI) do projeto. Escrita para facilitar continuidade por humanos ou por outra IA.

## Estado atual

| Item | Status |
|------|--------|
| CI (GitHub Actions) | Implementado |
| CD Android (APK/AAB) | Não implementado |
| CD iOS | Não implementado |
| Deploy Firebase (regras/functions) | Não implementado |

O CI básico foi adicionado no commit `7fb4573` (`ci: add GitHub Actions workflow for analyze and test`).

## Arquivo do workflow

- Caminho: `.github/workflows/ci.yml`
- Plataforma: GitHub Actions
- Runner: `ubuntu-latest`

## Quando o CI roda

O workflow dispara em:

- **Push** para a branch `main`
- **Pull request** com destino à branch `main`

Não há jobs de release, deploy ou build de artefatos ainda.

## O que o pipeline faz

Ordem dos passos:

1. **Checkout** — clona o repositório
2. **Setup Flutter** — instala Flutter `3.35.5` (channel `stable`), com cache de dependências
3. **`flutter pub get`** — resolve dependências do `pubspec.yaml`
4. **Check de formatação** — `dart format --output=none --set-exit-if-changed .`
5. **Análise estática** — `flutter analyze --no-fatal-infos`
6. **Testes** — `flutter test`

Se qualquer passo falhar, o workflow inteiro falha.

## Decisões importantes (contexto para manutenção)

### Versão fixa do Flutter (política do projeto)

**Decisão:** o projeto usa Flutter **3.35.5** de forma intencional. Não é necessário atualizar o Flutter sempre que o CLI avisar que há versão nova.

Motivos:

- Builds reproduzíveis (dev local = CI = clone do repo)
- Menos risco de quebra por mudanças de API, lints ou dependências
- Upgrades passam a ser **eventos planejados**, não rotina contínua

Onde a versão está definida:

| Arquivo | Função |
|---------|--------|
| `.fvm/fvm_config.json` | Versão oficial para quem usa [FVM](https://fvm.app) |
| `.fvmrc` | Atalho da mesma versão (FVM lê este arquivo) |
| `.github/workflows/ci.yml` | Versão usada no GitHub Actions |
| `.vscode/settings.json` | IDE aponta para `.fvm/flutter_sdk` quando FVM está instalado |

Compatível com `pubspec.yaml` (`sdk: ^3.9.0`).

#### Setup local com FVM (recomendado)

```bash
# instalar FVM uma vez (ex.: dart pub global activate fvm)
fvm install
fvm use
fvm flutter pub get
fvm flutter run
```

Sem FVM, use Flutter **3.35.5** globalmente e ignore avisos de upgrade até uma atualização planejada.

#### Quando atualizar (checklist)

Atualizar só quando houver motivo claro, por exemplo:

- exigência de loja (Android `targetSdk`, Xcode mínimo)
- patch de segurança relevante
- dependência que exige Flutter mais novo
- bug corrigido apenas na versão nova

Procedimento de upgrade (branch separada):

1. Escolher nova versão e testar localmente (`flutter upgrade`, analyze, test, app manual)
2. Atualizar **todos** os arquivos da tabela acima para a mesma versão
3. Rodar `fvm install` se usar FVM
4. Abrir PR e validar CI antes de merge em `main`

### `--no-fatal-infos` no analyze

O comando usa `flutter analyze --no-fatal-infos` porque o projeto ainda possui avisos do tipo `info` (ex.: `deprecated_member_use`, `use_build_context_synchronously`). Isso evita que o CI quebre por avisos informativos, mas **erros e warnings continuam falhando o build**.

Se no futuro o código ficar limpo de `info`, pode-se remover `--no-fatal-infos` para análise mais estrita.

### Formatação aplicada no mesmo commit do CI

No commit que introduziu o CI, 22 arquivos em `lib/` foram formatados com `dart format .` para que o passo de formatação passasse na primeira execução do pipeline. Essas mudanças são apenas estilo (whitespace/line breaks), sem alteração de lógica.

## Como reproduzir o CI localmente

Na raiz do projeto:

```bash
# com FVM:
fvm flutter pub get
fvm dart format --output=none --set-exit-if-changed .
fvm flutter analyze --no-fatal-infos
fvm flutter test

# sem FVM (Flutter 3.35.5 global):
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze --no-fatal-infos
flutter test
```

Se o check de formatação falhar localmente:

```bash
dart format .
```

## Testes cobertos pelo CI

Hoje o CI executa os testes em `test/widget_test.dart`, focados em serialização e inferência de protocolo do model `Camera`. Não há widget tests de UI nem testes de integração com Firebase no pipeline.

## O que ainda não existe (CD)

Para referência de evolução futura:

- **Android release**: keystore de produção, `key.properties`, build de AAB/APK assinado
- **Play Store / Firebase App Distribution**: upload automatizado de artefatos
- **iOS**: runner macOS, certificados Apple, `GoogleService-Info.plist` (Android já tem `google-services.json` no repo)
- **Versionamento por tag**: release automático em tags `v*`

Detalhes de assinatura Android: o `android/app/build.gradle.kts` ainda usa **debug signing** no build type `release` — adequado para dev, insuficiente para publicação em loja.

## Arquivos relacionados

| Arquivo | Papel |
|---------|--------|
| `.github/workflows/ci.yml` | Definição do pipeline CI |
| `.fvm/fvm_config.json` | Versão fixa do Flutter (FVM) |
| `.fvmrc` | Versão fixa do Flutter (atalho FVM) |
| `.vscode/settings.json` | SDK Flutter da IDE via FVM |
| `pubspec.yaml` | Dependências e versão do SDK Dart |
| `analysis_options.yaml` | Regras de lint (`flutter_lints`) |
| `test/widget_test.dart` | Testes executados no CI |
| `android/app/google-services.json` | Config Firebase Android (já no repo) |
| `lib/firebase_options.dart` | Config Firebase gerada pelo FlutterFire |

## Secrets e segurança

O CI atual **não usa secrets**. Não há credenciais, keystores ou tokens configurados no GitHub Actions.

Arquivos sensíveis que **não** devem entrar no CI/repo:

- `android/key.properties`
- `android/app/upload-keystore.jks` (ou qualquer `.jks`/`.keystore`)
- `scripts/*-firebase-adminsdk-*.json` (já ignorado via `.gitignore`)

## Onde ver execuções

Após push para `main` ou abertura de PR:

- GitHub → aba **Actions** do repositório
- URL: https://github.com/Pwn3ed/RondalarmeCamerasFlutter/actions

## Próximos passos sugeridos

1. Corrigir os 5 avisos `info` do analyzer e remover `--no-fatal-infos`
2. Adicionar workflow de release Android (`.github/workflows/release-android.yml`)
3. Configurar branch protection exigindo CI verde antes de merge em `main`
4. (Opcional) adicionar cobertura com `flutter test --coverage`
