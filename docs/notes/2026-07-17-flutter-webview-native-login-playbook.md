# Flutter WebView 앱의 네이티브 소셜 로그인 구현·검증 플레이북

> 적용 대상: Flutter가 WebView shell을 제공하고 웹 서비스가 화면·세션을 소유하는 앱
>
> 검증 사례: Granite Android release APK의 Google native login 설정 분리 및 기기 로그 확인

## 1. 목표와 경계

WebView 기반 앱에서 소셜 로그인은 다음 책임을 분리한다.

| 경계 | 소유자 | 책임 |
| --- | --- | --- |
| 로그인 화면, 앱 세션, 쿠키 | 웹 서버 | 로그인 UX, OAuth callback 처리, HttpOnly 세션 cookie 발급 |
| SDK 호출, 앱 서명, 앱 전환 | Flutter/native | provider SDK 실행, callback 수신, platform signing 설정 |
| native → web 연결 | bridge/session sync | provider token을 서버 교환 endpoint에 전달하고 웹 세션을 갱신 |

Flutter bridge는 cookie/token 저장소가 아니다. native SDK가 받은 짧은 수명의 provider token 또는 ID token은 **POST body로 서버의 session-exchange endpoint에만** 전달한다. URL query, bridge debug log, crash log에 token·cookie·authorization·email을 남기지 않는다.

```text
WebView login action
  → auth.native.login.requested
  → Flutter provider SDK
  → provider token / ID token
  → HTTPS POST: web session exchange endpoint
  → HttpOnly web session cookie
  → WebView authenticated route
```

## 2. 구현 구조

### 2.1 Bridge contract

웹은 명시적인 native capability를 받은 경우에만 native login을 요청해야 한다. native가 준비되지 않은 빌드에서는 웹 OAuth fallback을 유지한다.

권장 흐름:

1. WebView가 native-ready/capability handshake를 수신한다.
2. 웹이 `auth.native.login.requested`에 provider와 상대 `returnTo`를 넣어 전송한다.
3. Flutter handler는 allowlist에 있는 provider만 처리하고, `returnTo`가 `/`로 시작하며 `//`가 아닌지 검사한다.
4. provider SDK 성공 후 native가 session exchange POST를 실행한다.
5. 성공/실패를 bridge message로 웹에 돌려준다.

Granite의 handler는 provider login과 session sync를 별도 stage로 기록한다. 한 stage가 실패했는지 분리하지 않으면 SDK 문제와 서버 session 문제를 같은 "로그인 실패"로 오판하기 쉽다.

### 2.2 서비스 분리

WebView screen에 provider별 switch/case를 넣지 않는다.

- `NativeSocialLoginService`: provider별 SDK 결과를 공통 `NativeSocialLoginResult`로 정규화
- `NativeAuthBridgeHandler`: bridge request 검증, provider login 호출, session exchange orchestration
- `NativeAuthDiagnostics`: 민감값 없는 구조화 diagnostic 출력
- session request builder: token을 POST body에만 넣고 URL을 allowlist/정규화

이 분리는 EEUM 등 다른 WebView shell에서도 provider SDK만 교체해 재사용할 수 있다.

## 3. Google 로그인: client ID를 구분하는 법

Google Cloud Console의 OAuth client ID는 이름이 비슷해도 역할이 다르다.

| OAuth client type | 설정 위치 | 역할 | WebView native login에서의 사용 |
| --- | --- | --- | --- |
| **Android** | package name + signing SHA-1 | 설치 APK/AAB가 신뢰된 Android 앱인지 Google이 식별 | Android OAuth client를 생성하고 현재 signing certificate SHA-1을 등록 |
| **iOS** | bundle ID | iOS 앱 식별 | iOS OAuth client를 생성하고 bundle ID 등록 |
| **Web application** | authorized redirect URI, web origin | 서버가 검증할 Google ID token의 audience | `GOOGLE_SERVER_CLIENT_ID`에 사용 |

### 3.1 `GOOGLE_CLIENT_ID`와 `GOOGLE_SERVER_CLIENT_ID`

Granite Flutter 코드에서 Google SDK는 다음 두 값을 별도로 initialize한다.

```text
clientId       ← GOOGLE_CLIENT_ID
serverClientId ← GOOGLE_SERVER_CLIENT_ID
```

- `GOOGLE_CLIENT_ID`: 앱 OAuth client ID. Android release APK처럼 signing identity가 다른 설치물에 필요한 값은 Android OAuth client에서 만든다.
- `GOOGLE_SERVER_CLIENT_ID`: **Web application OAuth client ID**. native SDK가 발급받는 ID token의 `aud`이고, 서버가 해당 token을 검증할 때 기대하는 값이다.
- `GOOGLE_SERVER_CLIENT_ID`에 Android OAuth client ID를 넣지 않는다.
- Web OAuth redirect URI는 Web application OAuth client의 설정이다. Android native Google credential 흐름의 callback URL을 의미하지 않는다.

같은 backend와 audience를 쓰는 APK/AAB/IPA라면 server client ID는 보통 하나로 유지한다. Android upload-key APK와 Play App Signing 설치본의 차이는 Web client ID가 아니라 **Android OAuth client에 등록한 SHA-1**에서 처리한다.

### 3.2 Android signing SHA-1

직접 설치하는 release APK와 Google Play가 재서명해 설치하는 앱의 SHA-1은 다를 수 있다.

- 직접 설치 APK: 로컬 upload/release keystore certificate SHA-1
- Play Store 설치본: Google Play App Signing certificate SHA-1

각 SHA-1에 대해 package name이 같은 Android OAuth client를 준비한다. APK의 실제 certificate는 build artifact 기준으로 확인한다.

```bash
$ANDROID_HOME/build-tools/<version>/apksigner \
  verify --print-certs build/app/outputs/flutter-apk/app-release.apk
```

`Signer #1 certificate SHA-1 digest`가 Google Cloud Console에 등록한 Android OAuth client의 SHA-1과 일치해야 한다.

### 3.3 Granite APK build define

Granite production wrapper는 APK에서만 `GOOGLE_CLIENT_ID_APK`를 `GOOGLE_CLIENT_ID`로 override한다. server client ID는 환경 기본값을 유지한다.

```env
# Android 앱 OAuth client (기본값; iOS/공통 build에 사용)
GOOGLE_CLIENT_ID=<app-client-id>

# Android APK에서만 client identity가 다를 때
GOOGLE_CLIENT_ID_APK=<apk-android-client-id>

# Web application OAuth client; backend ID token audience
GOOGLE_SERVER_CLIENT_ID=<web-application-client-id>
```

빌드:

```bash
tool/flutter_granite.sh build apk --env prod
```

wrapper 동작은 test double Flutter로 검증한다. client ID를 artifact 문자열 검색으로 검증하지 않는다. Dart tree-shaking으로 특정 platform에서 실제로 소비되지 않는 const 문자열이 artifact에 남지 않을 수 있다.

> 현재 Granite wrapper는 `ipa`와 `apk`만 지원한다. Play AAB도 동일한 환경변수 정책으로 만들려면 wrapper에 `appbundle` target을 추가하고, raw `flutter build appbundle`로 secret/config injection을 우회하지 않는다.

## 4. Apple 로그인: iOS와 Android가 다른 이유

| 플랫폼 | native login 흐름 | 필수 설정 |
| --- | --- | --- |
| iOS | `Sign in with Apple` native API | Xcode capability/entitlement, Apple Developer App ID 및 bundle ID 설정 |
| Android | Apple의 web authentication flow | Apple Services ID와 HTTPS redirect URI, Android에서 돌아오는 callback 확인 |

Granite 구현은 iOS에서 native Apple credential을 요청한다. Android에서는 다음 build define이 비어 있으면 시작 전에 실패시킨다.

```env
APPLE_SERVICE_ID=<Apple Services ID>
APPLE_REDIRECT_URI=<HTTPS callback URL>
```

Apple은 같은 이름의 login이라도 Android에서는 web callback을 거치므로, iOS 성공만으로 Android callback을 검증했다고 볼 수 없다. provider login 성공과 서버 session sync 성공을 모두 실제 기기에서 확인한다.

## 5. 안전한 diagnostics와 현장 조사

### 5.1 남겨도 되는 값

다음처럼 provider·stage·상태·안전한 enum/HTTP status만 남긴다.

```text
granite-native-auth provider=google stage=provider_login status=started
granite-native-auth provider=google stage=provider_login status=failed errorCode=google-unknownError
granite-native-auth provider=apple stage=session_sync status=completed
```

- stage: `provider_login`, `session_sync`
- status: `started`, `completed`, `failed`
- errorCode: SDK enum name처럼 민감하지 않은 분류값
- providerStatus: 100–599 범위의 HTTP-like provider status만 허용

### 5.2 절대 남기지 않는 값

다음 값은 로그, URL, bridge error message, 공유된 logcat에 넣지 않는다.

- `id_token`, `access_token`, refresh token, authorization code
- cookie, authorization header, handoff code, OAuth state
- email, 사용자 식별자, provider의 raw exception message

### 5.3 Android 실기기 로그 절차

1. 새 APK를 설치한다.
2. 이전 로그를 clear한다.
3. 앱을 force-stop 후 시작한다.
4. 사용자 동작 한 번만 재현한다.
5. 앱 자체 diagnostic과 Google Play services 오류를 분리해 확인한다.

```bash
adb -s <device> logcat -c
adb -s <device> shell am force-stop <package>
adb -s <device> shell am start -W -n <package>/<activity>

adb -s <device> logcat -d -v threadtime flutter:I '*:S'
```

로그를 전달하거나 저장하기 전 token/email/cookie 등을 redaction한다. Google account chooser가 열렸다는 사실은 SDK UI 진입 증거일 뿐, token 발급이나 web session sync 성공 증거는 아니다.

## 6. 문제 해결 순서

### 증상 A: native login 버튼을 눌렀는데 웹 fallback으로 간다

1. native capability handshake가 광고되는지 확인한다.
2. bridge channel과 message direction/type을 확인한다.
3. native provider allowlist와 web의 provider name이 일치하는지 확인한다.
4. intentional fallback인지, native handler failure인지 로그 stage로 분리한다.

### 증상 B: Google account chooser 뒤 provider login이 실패한다

1. 실제 APK의 certificate SHA-1을 `apksigner`로 구한다.
2. Google Cloud Console Android OAuth client의 package name/SHA-1을 대조한다.
3. `GOOGLE_SERVER_CLIENT_ID`가 Web application OAuth client ID인지 확인한다.
4. backend가 그 Web client ID를 ID token audience로 허용하는지 확인한다.
5. direct APK, Play-installed build, 다른 keystore를 같은 것으로 가정하지 않는다.
6. safe diagnostic enum을 보되 raw token/exception text를 로그로 늘리지 않는다.

### 증상 C: provider login은 완료됐는데 웹은 비로그인 상태다

1. `provider_login=completed` 뒤 `session_sync=started`가 있는지 확인한다.
2. session exchange request가 HTTPS POST인지, endpoint와 return path가 allowlist인지 확인한다.
3. 응답이 WebView cookie jar에 HttpOnly web session을 설정하는지 확인한다.
4. native token을 Flutter 저장소나 URL parameter로 우회 전달하지 않는다.

### 증상 D: Apple은 iOS에서 되는데 Android에서 실패한다

1. Android build에 `APPLE_SERVICE_ID`와 `APPLE_REDIRECT_URI`가 주입됐는지 확인한다.
2. Apple Developer portal의 Services ID/redirect URL과 정확히 대조한다.
3. Android Custom Tab/browser callback 이후 앱 복귀와 session sync를 각각 검증한다.

## 7. release 검증 체크리스트

### 공통

- [ ] WebView bridge capability와 provider allowlist를 확인했다.
- [ ] provider login과 session sync를 별도로 실기기에서 확인했다.
- [ ] token/cookie/email/authorization 값이 logcat 및 bridge debug log에 없다.
- [ ] `flutter analyze`, `flutter test`, `git diff --check`가 통과했다.
- [ ] 실제 배포 artifact의 hash, signing certificate, 설치 기기를 기록했다.

### Android

- [ ] local APK signing SHA-1이 Android OAuth client에 등록됐다.
- [ ] Play App Signing SHA-1도 별도 Android OAuth client로 등록됐다.
- [ ] APK build wrapper가 intended `GOOGLE_CLIENT_ID_APK`와 unchanged server client ID를 Flutter에 전달하는지 테스트했다.
- [ ] Google chooser → provider login complete → session sync complete를 실기기 logcat으로 확인했다.

### iOS

- [ ] Sign in with Apple entitlement/capability와 provisioning profile을 확인했다.
- [ ] iOS native Apple login의 provider login 및 session sync를 실기기에서 확인했다.
- [ ] Android Apple web callback은 별도 기기에서 확인했다.
- [ ] IPA는 env define을 주입하는 release wrapper로 빌드했다.

## 8. Granite에서 확인된 결론

2026-07-17 Android release APK 조사에서 다음을 확인했다.

- APK-specific 설정이 필요할 때 server audience가 아니라 app client identity를 분리해야 했다.
- `GOOGLE_CLIENT_ID_APK`가 ignored env에 존재해도 wrapper가 dart define으로 주입하지 않으면 앱에 반영되지 않는다.
- wrapper 동작은 test double Flutter와 실제 production env를 사용해, secret을 출력하지 않고 검증할 수 있다.
- Google SDK의 generic failure만 기록하면 Cloud Console 설정, signing SHA, server audience 중 무엇이 문제인지 구분할 수 없다. provider login/session sync stage와 안전한 SDK error enum이 필요하다.

Apple callback smoke verification은 이 문서 작성 시점에 별도 후속 항목이다. Google 성공을 Apple 성공의 증거로 취급하지 않는다.
