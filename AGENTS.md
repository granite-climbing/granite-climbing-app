# Granite Climbing App

Granite 웹 경험을 모바일 앱 안에서 안정적으로 실행하기 위한 Flutter hybrid shell.

## 프로젝트 개요

- **서비스명**: Granite (그래나이트)
- **앱 역할**: `https://granite.kr/` 웹사이트를 WebView로 렌더하는 얇은 앱 shell이다.
- **사용자**: 자연 볼더링 정보를 탐색하고 기록하려는 클라이머
- **기본 웹 URL**: `GRANITE_WEB_URL` dart define으로 주입하며, 기본값은 `https://granite.kr/`이다.
- **로컬 개발 기준**: iOS simulator는 `http://localhost:3000/`, Android emulator는 `http://10.0.2.2:3000/`, 실기기는 개발 머신 LAN IP를 사용한다.
- **v1 기준**: 심사용 단순 WebView 앱이다. 웹사이트가 화면 이동을 소유하며 native 하단 nav는 표시하지 않는다.

## 기술 스택

| 영역 | 기술 |
|------|------|
| 프레임워크 | Flutter |
| 언어 | Dart |
| WebView | `webview_flutter` |
| 외부 이동 | `url_launcher` |
| 공유 | `share_plus` |
| 테스트 | `flutter_test` |
| 정적 자산 | `assets/images` |

## 제품 단계

1. **Hybrid Shell Baseline**
   - `https://granite.kr/` WebView
   - 첫 WebView 로딩 중 시작 화면 overlay
2. **Bridge & Session Sync**
   - `FlutterWebView` JavaScript channel
   - envelope schema, handler 분리, debug log
   - native login handoff와 web session sync
3. **Native Navigation UI**
   - v1에서는 표시하지 않는다.
   - v2 브랜치에서 하단 nav, 앱 asset 기반 icon, WebView URL 이동과 native shell state 연결을 다룬다.
4. **Native Capability Expansion**
   - 공유, 외부 브라우저, push, deep link, 권한 요청
   - 앱 lifecycle과 WebView lifecycle 정리
5. **Release Hardening**
   - dev/staging/prod URL 설정 분리
   - crash/log 정책, store metadata, platform별 QA

## 디렉터리 구조

```
granite-climbing-app/
├── lib/
│   ├── app/                    # 앱 composition
│   ├── core/                   # constants, app-level primitives
│   ├── data/
│   │   └── bridge/             # bridge codec/controller/handlers/debug log
│   ├── features/
│   │   ├── auth/               # native auth, session handoff
│   │   ├── navigation/         # external navigation service
│   │   ├── share/              # native share service
│   │   └── webview/            # online WebView screen
│   └── shared/
│       └── widgets/            # shared app widgets
├── assets/
│   ├── images/                 # app images/logos
├── test/
└── AGENTS.md
```

## 작업 원칙

### Hybrid App Boundary

- Granite의 콘텐츠와 주요 화면은 기본적으로 `https://granite.kr/` 웹사이트가 소유한다.
- Flutter는 앱 shell, WebView lifecycle, native capability, native session을 소유한다.
- Bridge는 token/cookie 공유 통로가 아니다. Native app session은 Flutter가 보관하고, web session은 Granite web server가 HttpOnly cookie로 보관한다.
- 앱 로그인 상태를 웹에 반영해야 할 때는 짧은 수명의 handoff code 또는 서버 검증 가능한 sync credential만 전달한다.
- 실제 native auth가 준비되기 전까지 운영 빌드는 `auth.native` capability를 광고하지 않는다. WebView 안의 웹 로그인은 그대로 동작하게 두고, bridge handler는 향후 웹 요청을 안전하게 받을 수 있게 유지한다.
- Bridge message envelope, lifecycle handshake, namespace, 보안 정책은 `../granite-v2/docs/bridge/protocol.md`를 따른다.

### WebView

- WebView 화면은 JSON 파싱, message routing, auth sync 세부 구현을 직접 갖지 않는다.
- WebView와 bridge 연결은 `BridgeController`를 통해 수행한다.
- Web에서 Flutter로 보내는 표준 channel 이름은 `FlutterWebView`다.
- Flutter에서 Web으로 보내는 메시지는 `window.GraniteBridge.receive(...)`를 호출한다.
- URL은 `GRANITE_WEB_URL`로 주입한다.

### Bridge

- Message schema 변경은 codec/schema 테스트를 먼저 추가한다.
- 기능별 처리는 `BridgeHandler`로 분리한다. `WebViewScreen`에 switch/case를 늘리지 않는다.
- 새 namespace는 `app.*`, `auth.*`, `navigation.*`, `share.*`처럼 기능 경계가 드러나게 둔다.
- debug log에는 최근 message만 남기고, `handoff`, `token`, `cookie`, `authorization`, `email`, `secret` 계열 값은 반드시 마스킹한다.
- Web 쪽 변경이 필요한 bridge 작업은 `../granite-v2/lib/bridge`와 `../granite-v2/docs/bridge`를 함께 확인한다.

### UI / Design

- 앱 shell UI는 웹 콘텐츠를 가리지 않는 얇은 native layer로 둔다.
- v1은 native 하단 nav를 표시하지 않는다. native nav 작업은 v2 브랜치에서 이어간다.
- 버튼/아이콘은 고정된 터치 영역을 갖게 만들고, 텍스트가 들어가는 경우 작은 화면에서 줄바꿈/잘림을 확인한다.
- WebView 내부 콘텐츠의 레이아웃 문제는 Flutter padding으로 보정하지 않는다. 웹 CSS에서 해결할 문제와 native shell 문제를 분리한다.
- platform status bar, safe area, bottom inset은 Flutter widget tree에서 명시적으로 다룬다.

### Assets

- 새 asset을 추가하면 `pubspec.yaml`의 `flutter.assets`에 포함되는지 확인한다.
- PNG/JPG 같은 bitmap은 `assets/images/`에 둔다.
- asset 파일명은 소문자 snake_case를 사용한다.
- 사용하지 않는 asset은 남기지 않는다.

## 코딩 컨벤션

- Dart formatter 기준을 따른다. 수동 정렬보다 `dart format` 결과를 우선한다.
- `flutter_lints` 경고는 기본적으로 수정한다.
- 비동기 작업은 의도적으로 기다리지 않을 때만 `unawaited(...)`를 사용한다.
- 화면 widget은 composition을 우선하고, 상태/서비스/handler 책임을 한 파일에 몰아넣지 않는다.
- 외부 입력, bridge payload, URL은 신뢰하지 않고 codec/service 계층에서 정규화한다.
- 테스트에서 platform channel/WebView는 fake platform 또는 recording double로 검증한다.

## 테스트 / 검증

변경 범위에 따라 아래 명령을 사용한다.

```bash
dart format lib test
flutter analyze
flutter test
git diff --check
```

- UI widget 변경은 가능한 한 widget test를 추가한다.
- bridge/auth/navigation/share 변경은 handler/service 단위 테스트를 추가한다.
- WebView 실제 동작은 `../granite-v2/docs/bridge/smoke-test.md` 흐름으로 별도 확인한다.

## 커밋 컨벤션

커밋 메시지 접두어는 `granite-v2`와 맞춰 아래를 사용한다.

- `feat:` 사용자에게 보이는 기능 추가
- `fix:` 버그 수정
- `docs:` 문서 변경
- `chore:` 빌드, 설정, dependency, generated metadata 변경
- `refactor:` 동작 변경 없는 구조 개선
- `test:` 테스트 추가/수정

커밋은 가능한 한 한 가지 의도를 담는다.

- UI 구현과 asset 추가가 같은 기능의 일부라면 한 커밋에 묶을 수 있다.
- bridge protocol 변경과 UI 변경은 분리한다.
- generated file이나 platform lockfile 변경은 왜 바뀌었는지 커밋 본문이나 PR 설명에 남긴다.
- 사용자 변경사항이 섞인 worktree에서는 관련 없는 파일을 되돌리지 않는다.

## 환경 / 실행 옵션

모든 옵션은 `flutter run` 뒤에 `--dart-define=이름=값` 형태로 전달한다.
심사/운영 빌드는 `--dart-define-from-file=config/prod.json`을 사용한다.

| 옵션 | 기본값 | 설명 |
|----|----|----|
| `GRANITE_WEB_URL` | `https://granite.kr/` | WebView가 여는 Granite web URL |
| `GRANITE_ENABLE_NATIVE_AUTH_BRIDGE` | `false` | true이면 `auth.native`와 `auth.sessionSync` capability를 WebView에 광고한다. 운영 빌드는 실제 native auth 준비 전까지 false 유지 |
| `APPLE_SERVICE_ID` | 빈 값 | Android Apple 로그인에서 사용하는 Apple Services ID |
| `APPLE_REDIRECT_URI` | 빈 값 | Android Apple 로그인 후 앱으로 돌아오기 위한 서버 callback URL |

로컬 `granite-v2` 확인 예시:

```bash
flutter run \
  --dart-define=GRANITE_WEB_URL=http://localhost:3000/
```

Android emulator:

```bash
flutter run \
  --dart-define=GRANITE_WEB_URL=http://10.0.2.2:3000/
```

## 참고 문서

- 앱 실행 안내: [README.md](README.md)
- Bridge protocol: [../granite-v2/docs/bridge/protocol.md](../granite-v2/docs/bridge/protocol.md)
- Bridge implementation steps: [../granite-v2/docs/bridge/implementation-steps.md](../granite-v2/docs/bridge/implementation-steps.md)
- Bridge smoke test: [../granite-v2/docs/bridge/smoke-test.md](../granite-v2/docs/bridge/smoke-test.md)
- Granite v2 conventions: [../granite-v2/AGENTS.md](../granite-v2/AGENTS.md)
