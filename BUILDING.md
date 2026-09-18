# Сборка Android APK

Проект закреплён на Godot `4.0.stable`. Android preset называется `Android`, а package ID — `org.badlandprototype.game`. Не меняйте его при настройке CI или локального окружения.

## Локальная сборка

Нужны Godot 4.0 stable с установленными export templates, JDK 11 и Android SDK (platform 33 и Build Tools 33.0.2). Пути к Android SDK и keystore должны быть настроены в Godot Editor: **Editor Settings → Export → Android**.

Из PowerShell в корне проекта:

```powershell
./scripts/build_android.ps1 `
  -Godot "D:\path\to\Godot_v4.0-stable_win64.exe" `
  -Mode debug `
  -Output "build/badland-port-local.apk"
```

Скрипт сначала открывает проект headless для импорта и проверки, затем вызывает Android export. Для release используйте `-Mode release`; локальный release keystore должен быть настроен в Godot Editor. Keystore и пароли не должны находиться в репозитории.

## GitHub Actions Secrets

В **GitHub → repository → Settings → Secrets and variables → Actions** создайте постоянные Secrets для development-сборок:

- `ANDROID_DEV_KEYSTORE_BASE64` — development keystore целиком в Base64;
- `ANDROID_DEV_KEY_ALIAS` — alias ключа внутри development keystore;
- `ANDROID_DEV_KEY_PASSWORD` — единый пароль keystore и ключа.

Development Secrets обязательны для push в `main`. Если их нет, workflow завершится явной ошибкой и не выпустит APK с новым случайным signing key.

Создайте development keystore один раз локально. `keytool` интерактивно спросит пароль; используйте один и тот же пароль для хранилища и ключа, поскольку Godot 4.0 принимает один пароль для debug keystore:

```powershell
keytool -genkeypair -v `
  -keystore "$env:USERPROFILE\badland-dev.keystore" `
  -alias badland-dev `
  -keyalg RSA -keysize 2048 -validity 10000 `
  -dname "CN=Badland Port Development,O=Badland Port,C=RU"
```

Сохраните keystore и пароль в безопасном месте. Затем преобразуйте именно этот файл в Base64 без переносов:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("$env:USERPROFILE\badland-dev.keystore")) | Set-Clipboard
```

Вставьте значение из буфера в `ANDROID_DEV_KEYSTORE_BASE64`, alias `badland-dev` — в `ANDROID_DEV_KEY_ALIAS`, а введённый пароль — в `ANDROID_DEV_KEY_PASSWORD`. Не сохраняйте Base64, keystore или пароль в файлах проекта.

Для production release создайте отдельные Secrets:

- `ANDROID_RELEASE_KEYSTORE_BASE64` — существующий release keystore целиком в Base64;
- `ANDROID_RELEASE_KEY_ALIAS` — alias ключа внутри keystore;
- `ANDROID_RELEASE_KEY_PASSWORD` — пароль ключа/keystore, который использует Godot.

`GITHUB_TOKEN` GitHub предоставляет workflow автоматически; создавать свой токен не нужно. Для получения Base64 production keystore без переносов:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("D:\secure\release.keystore")) | Set-Clipboard
```

Не сохраняйте полученную строку в файлах проекта и не добавляйте keystore в git.

## Development APK с телефона

После push в `main` откройте в репозитории **Releases → Latest Development Build** (`dev-latest`). Скачайте приложенный файл `badland-dev-YYYY-MM-DD-<short-sha>.apk` и откройте его на Android. Это прямая загрузка APK без ZIP-архива. При необходимости разрешите браузеру установку приложений из неизвестного источника.

Prerelease `dev-latest` всегда содержит только последнюю development-сборку. Диагностический GitHub Actions Artifact также сохраняется на 14 дней. Development `versionName` имеет вид `0.1.0-dev+<short-sha>`; tracked Android preset при этом не изменяется. В APK также встраиваются short SHA и UTC-время сборки для debug overlay.

### Стратегия versionCode

Workflow использует `versionCode = 100000 + GITHUB_RUN_NUMBER` для development и production. `GITHUB_RUN_NUMBER` — последовательный номер запусков этого workflow: каждый новый запуск получает большее значение. Поэтому следующий push в `main` и следующий production tag получают versionCode больше предыдущей CI-сборки без ручного редактирования `export_presets.cfg`. Повторный запуск одного и того же workflow сохраняет тот же versionCode, так как это та же исходная сборка.

## Быстрая локальная проверка

Для обычной разработки выполните только:

```powershell
./scripts/check.ps1 -Godot "D:\path\to\Godot_v4.0-stable_win64.exe"
```

Проверка запускает Godot headless editor для быстрой загрузки проекта и обнаружения очевидных ошибок загрузки/парсинга GDScript. Она не делает Android export, не создаёт APK, не запускает Gradle и не ждёт CI. Полная Android-сборка `scripts/build_android.ps1` нужна только вручную, для диагностики или при изменении build-инфраструктуры.

## Release по тегу

Сначала убедитесь, что три release Secret настроены. Затем локально создайте и отправьте тег вида `v*`:

```powershell
git tag -a v0.1.0 -m "Release v0.1.0"
git push origin v0.1.0
```

Workflow соберёт подписанный release APK, создаст GitHub Release для тега и приложит APK. Агент не должен создавать production tag или release без явного указания владельца проекта.
