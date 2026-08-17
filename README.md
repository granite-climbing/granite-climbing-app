# Granite Climbing App

Granite 클라이밍 가이드 웹사이트를 모바일 앱 안에서 보여주는 Flutter 앱입니다.

`v1` 브랜치는 심사용 단순 WebView 앱입니다. 운영 빌드는 `https://v2.granite.kr/`를 바로 열고, 웹사이트가 화면과 이동을 소유합니다. 별도의 native 하단 nav, 네트워크 gate, 오프라인 번들 fallback은 두지 않습니다.

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

기본 온라인 URL은 `https://granite.kr/`입니다. 운영 빌드는 `config/prod.json`의 `https://v2.granite.kr/`를 사용합니다. 다른 URL을 열고 싶으면 `GRANITE_WEB_URL`을 지정합니다.

```bash
flutter run \
  --dart-define=GRANITE_WEB_URL=https://v2.granite.kr/
```

심사/운영 빌드는 `config/prod.json`을 사용해 production 값을 명시합니다.

```bash
flutter run --dart-define-from-file=config/prod.json
```

## 실행 옵션

| 옵션 | 기본값 | 설명 |
| --- | --- | --- |
| `GRANITE_WEB_URL` | `https://granite.kr/` | WebView가 여는 Granite web URL입니다. 운영 config는 `https://v2.granite.kr/`를 지정합니다. |
| `GRANITE_ENABLE_NATIVE_AUTH_BRIDGE` | `false` | `true`이면 WebView bridge가 `auth.native`/`auth.sessionSync` capability를 광고합니다. 운영 빌드에서는 실제 native auth가 붙기 전까지 기본값을 유지합니다. |
| `KAKAO_NATIVE_APP_KEY` | 빈 값 | Kakao Flutter SDK 초기화와 Android `kakao{key}://oauth` manifest placeholder에 사용합니다. iOS URL scheme은 `Info.plist`에 `kakao{key}` 형식으로 등록합니다. |
| `NAVER_CLIENT_ID` | 빈 값 | Naver Android/iOS native login SDK 초기화에 사용하는 Client ID입니다. |
| `NAVER_CLIENT_SECRET` | 빈 값 | Naver Android/iOS native login SDK 초기화에 사용하는 Client Secret입니다. git에 커밋하지 말고 ignored env/CI secret로 빌드 시 주입합니다. |
| `NAVER_CLIENT_NAME` | `GRANITE` | Naver 로그인 화면에 표시할 앱 이름입니다. |
| `NAVER_URL_SCHEME` | `graniteclimbingnaverlogin` | Naver iOS callback URL scheme입니다. Naver Developers 콘솔의 iOS URL Scheme과 일치해야 합니다. |
| `APPLE_SERVICE_ID` | 빈 값 | Android Apple 로그인에서 사용하는 Apple Services ID입니다. |
| `APPLE_REDIRECT_URI` | 빈 값 | Android Apple 로그인 후 앱으로 돌아오기 위한 서버 callback URL입니다. |

`--dart-define` 값은 앱을 다시 실행할 때 반영됩니다. 값을 바꾼 뒤에는 기존 실행을 멈추고 `flutter run`을 다시 실행하는 편이 가장 확실합니다.

## 네이티브 소셜 로그인

Kakao는 iOS와 Android의 로그인 경로를 구분합니다. iOS의 카카오 계정 로그인은 `ASWebAuthenticationSession` 기반 공식 REST OAuth 화면을 열어 카카오톡 로그인 버튼과 계정 직접 입력을 함께 제공하고, 짧게 만료되는 검증형 handoff를 WebView 세션으로 교환합니다. Android와 카카오톡 우선 로그인은 기존 `kakao_flutter_sdk_user` 경로를 유지합니다.

Naver는 Android 공식 네아로 SDK(`com.navercorp.nid:oauth`)와 iOS 공식 `NidThirdPartyLogin` SDK를 사용합니다. 채널명은 `com.granite.climbing/native_social_login`, method는 `loginWithNaver`이며 Dart define으로 받은 Client ID, Client Secret, Client Name을 native에 넘겨 SDK를 초기화합니다. Android는 SDK의 네이버 앱 또는 Custom Tab 인증 화면을 열고, 성공한 access token을 웹 세션 교환 API로 전달합니다.

Native 로그인에서 예외가 발생하면 앱은 `/api/auth/start/{provider}`를 WebView에 로드합니다. 웹 서버가 OAuth state cookie를 만든 뒤 provider authorize URL로 redirect하므로 사용자는 웹 로그인 fallback으로 이어집니다.

## App Store 언어

iOS 바이너리의 기본 개발 언어는 Korean으로 맞춥니다. App Store Connect의 Primary Language는 별도 메타데이터 설정이므로, Korean localization과 스크린샷이 승인된 뒤 App Information에서 Primary Language를 Korean으로 변경해야 합니다.

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

### 환경별 native 설정

Native 로그인 값과 API client secret은 코드나 `config/prod.json`에 넣지 않습니다. 로컬 전용 파일인 `config/local.env`, `config/prod.env`에서 관리하며, 두 파일은 `.gitignore`로 제외됩니다.

처음 설정할 때는 예시 파일을 복사합니다.

```bash
cp config/local.env.example config/local.env
cp config/prod.env.example config/prod.env
```

`tool/flutter_granite.sh`는 해당 env 파일을 읽어 모든 Granite dart-define을 주입합니다. 이미 설정된 shell/CI 환경변수는 env 파일보다 우선합니다. 따라서 CI에서는 `NAVER_CLIENT_SECRET` 같은 값을 CI secret으로 등록해 override할 수 있습니다.

운영 IPA는 반드시 wrapper로 만듭니다.

```bash
tool/flutter_granite.sh build ipa
```

다른 환경 파일을 명시하려면 `--env`를 사용합니다.

```bash
tool/flutter_granite.sh build ipa --env local
```

기본 export 설정은 `ios/ExportOptions.AppStoreConnect.plist`이며, IPA의 archive build number를 그대로 보존합니다. 결과물은 `build/ios/ipa/`에 생성됩니다.

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

`android/key.properties`의 `storeFile`, `storePassword`, `keyPassword`, `keyAlias` 값을 실제 upload keystore에 맞게 채운 뒤 App Bundle을 만듭니다. Android wrapper는 다음 작업으로 추가합니다. 그 전에는 production env를 shell에 로드한 뒤 기존 명령을 사용합니다.

```bash
set -a
. config/prod.env
set +a

flutter build appbundle --release \
  --dart-define-from-file=config/prod.json \
  --dart-define=NAVER_CLIENT_SECRET="$NAVER_CLIENT_SECRET"
```

빌드 결과물은 `build/app/outputs/bundle/release/app-release.aab`에 생성됩니다.

## 업데이트 전략

v1 앱은 native 화면 이동을 갖지 않고 운영 config의 `https://v2.granite.kr/`를 WebView로 엽니다. 따라서 같은 도메인의 웹 배포가 바뀌면 앱 업데이트 없이 새 웹 경험이 표시됩니다.

소셜 로그인도 우선 웹 경험을 기준으로 노출합니다. 앱에는 bridge handler를 미리 두되, 실제 native auth가 준비되기 전까지 `auth.native` capability를 광고하지 않아 고객에게 동작하지 않는 native 로그인 버튼이 보이지 않게 합니다.

앱스토어/플레이스토어 업데이트가 필요한 경우는 앱 이름, 아이콘, 권한, native WebView shell, signing 설정처럼 앱 바이너리에 들어가는 항목을 바꿀 때입니다.

Flutter 코드 자체를 앱 심사 없이 패치하려면 CodePush류 OTA 도구가 별도로 필요합니다. 이 저장소는 우선 WebView 기반 업데이트 전략을 기본값으로 두고, 추후 OTA가 필요해지면 계정과 app id가 필요한 Flutter OTA 도구를 별도 초기화합니다.
