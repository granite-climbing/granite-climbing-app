# Granite Climbing App

Granite 클라이밍 가이드 웹사이트를 모바일 앱 안에서 보여주는 Flutter 앱입니다.

`v1` 브랜치는 심사용 단순 WebView 앱입니다. 앱은 `https://granite.kr/`를 바로 열고, 웹사이트가 화면과 이동을 소유합니다. 별도의 native 하단 nav, 네트워크 gate, 오프라인 번들 fallback은 두지 않습니다.

## 준비

Flutter SDK와 각 플랫폼 개발 환경이 필요합니다.

```bash
cd /Users/scorchedrice/granite/granite-climbing-app
flutter doctor
flutter pub get
```

실행 가능한 기기는 아래 명령으로 확인합니다.

```bash
flutter devices
```

## 작업 컨벤션

앱 구조, bridge 경계, asset 관리, 테스트/커밋 규칙은 [AGENTS.md](AGENTS.md)를 기준으로 합니다.

## 기본 실행

기기가 하나만 연결되어 있으면 바로 실행할 수 있습니다.

```bash
flutter run
```

기기가 여러 개면 `flutter devices`에서 확인한 ID를 지정합니다.

```bash
flutter run -d <device-id>
```

기본 온라인 URL은 `https://granite.kr/`입니다. 다른 URL을 열고 싶으면 `GRANITE_WEB_URL`을 지정합니다.

```bash
flutter run \
  --dart-define=GRANITE_WEB_URL=https://granite.kr/
```

심사/운영 빌드는 `config/prod.json`을 사용해 production 값을 명시합니다.

```bash
flutter run --dart-define-from-file=config/prod.json
```

## 실행 옵션

| 옵션 | 기본값 | 설명 |
| --- | --- | --- |
| `GRANITE_WEB_URL` | `https://granite.kr/` | WebView가 여는 Granite web URL입니다. |

`--dart-define` 값은 앱을 다시 실행할 때 반영됩니다. 값을 바꾼 뒤에는 기존 실행을 멈추고 `flutter run`을 다시 실행하는 편이 가장 확실합니다.

## 테스트

```bash
flutter test
```

## v1 심사 빌드

제출 전 기본 점검은 아래 순서로 실행합니다.

```bash
flutter pub get
dart format --set-exit-if-changed lib test
flutter analyze
flutter test
```

iOS는 Xcode signing 설정이 맞는지 확인한 뒤 archive를 만듭니다. 로컬 컴파일만 먼저 확인하려면 `--no-codesign`을 사용합니다.

```bash
flutter build ios --release --no-codesign \
  --dart-define-from-file=config/prod.json

flutter build ipa --release \
  --dart-define-from-file=config/prod.json
```

Android release 빌드는 upload keystore가 필요합니다. `android/key.properties`는 git에 올리지 않습니다.

```bash
keytool -genkey -v \
  -keystore ~/granite-upload-keystore.jks \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias upload

cp android/key.properties.example android/key.properties
```

`android/key.properties`의 `storeFile`, `storePassword`, `keyPassword`, `keyAlias` 값을 실제 upload keystore에 맞게 채운 뒤 App Bundle을 만듭니다.

```bash
flutter build appbundle --release \
  --dart-define-from-file=config/prod.json
```

빌드 결과물은 `build/app/outputs/bundle/release/app-release.aab`에 생성됩니다.

## 업데이트 전략

v1 앱은 native 화면 이동을 갖지 않고 `https://granite.kr/`를 WebView로 엽니다. 따라서 웹이 v2로 교체되어도 같은 도메인에 배포되면 앱 업데이트 없이 새 웹 경험이 표시됩니다.

앱스토어/플레이스토어 업데이트가 필요한 경우는 앱 이름, 아이콘, 권한, native WebView shell, signing 설정처럼 앱 바이너리에 들어가는 항목을 바꿀 때입니다.

Flutter 코드 자체를 앱 심사 없이 패치하려면 CodePush류 OTA 도구가 별도로 필요합니다. 이 저장소는 우선 WebView 기반 업데이트 전략을 기본값으로 두고, 추후 OTA가 필요해지면 계정과 app id가 필요한 Flutter OTA 도구를 별도 초기화합니다.
