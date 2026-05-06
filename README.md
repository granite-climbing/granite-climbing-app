# Granite Climbing App

Granite 클라이밍 가이드 웹사이트를 모바일 앱 안에서 보여주는 Flutter 앱입니다.

앱은 시작 화면을 먼저 보여준 뒤 네트워크 상태를 확인합니다. 연결이 정상이라면 온라인 WebView로 `https://granite.kr/`를 열고, 연결이 없거나 서버 확인에 실패하면 앱에 포함된 오프라인 번들(`assets/offline_web/index.html`)을 엽니다. 연결이 느리다고 판단되면 온라인 WebView 위에 불안정한 연결 안내와 저장된 코스 보기 버튼을 표시합니다.

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

## 실행 옵션

모든 옵션은 `flutter run` 뒤에 `--dart-define=이름=값` 형태로 붙입니다. 여러 옵션을 동시에 줄 수 있습니다.

```bash
flutter run -d <device-id> \
  --dart-define=GRANITE_WEB_URL=https://granite.kr/ \
  --dart-define=GRANITE_START_DELAY_MS=1200 \
  --dart-define=GRANITE_NETWORK_CHECK_TIMEOUT_MS=5000
```

`--dart-define` 값은 앱을 다시 실행할 때 반영됩니다. 값을 바꾼 뒤에는 기존 실행을 멈추고 `flutter run`을 다시 실행하는 편이 가장 확실합니다.

| 옵션 | 기본값 | 설명 |
| --- | --- | --- |
| `GRANITE_WEB_URL` | `https://granite.kr/` | 온라인 상태일 때 WebView가 여는 URL입니다. |
| `GRANITE_FORCE_OFFLINE` | `false` | `true`로 주면 네트워크 확인을 하지 않고 무조건 오프라인 번들을 엽니다. |
| `GRANITE_START_DELAY_MS` | `0` | 시작 화면을 최소로 유지할 시간입니다. 밀리초 단위입니다. |
| `GRANITE_NETWORK_CHECK_URL` | `https://granite.kr/` | 네트워크 품질 확인용 URL입니다. 앱은 이 주소로 `HEAD` 요청을 보냅니다. |
| `GRANITE_NETWORK_CHECK_TIMEOUT_MS` | `3500` | 네트워크 확인 요청 제한 시간입니다. 제한 시간 안에 실패하면 오프라인 번들로 이동합니다. |
| `GRANITE_SLOW_NETWORK_THRESHOLD_MS` | `2500` | 확인 요청이 이 시간 이상 걸리면 느린 연결로 판단합니다. 온라인 WebView는 열지만 불안정한 연결 안내를 표시합니다. |
| `GRANITE_WEBVIEW_FIRST_LOAD_WARNING_MS` | `8000` | 온라인 WebView의 첫 페이지 로딩이 이 시간보다 오래 걸리면 불안정한 연결 안내를 표시합니다. `0`이면 즉시 표시합니다. |

## 자주 쓰는 실행 예시

### 기본 온라인 모드

```bash
flutter run
```

### 강제 오프라인 모드

네트워크 상태와 상관없이 앱에 포함된 저장 코스 화면만 확인합니다.

```bash
flutter run \
  --dart-define=GRANITE_FORCE_OFFLINE=true
```

### 시작 화면 지연 확인

시작 화면을 최소 1.5초 동안 유지합니다.

```bash
flutter run \
  --dart-define=GRANITE_START_DELAY_MS=1500
```

### 느린 연결 안내 바로 확인

네트워크 확인 결과를 느린 연결로 분류하기 쉽게 임계값을 아주 낮춥니다.

```bash
flutter run \
  --dart-define=GRANITE_SLOW_NETWORK_THRESHOLD_MS=1
```

### 첫 WebView 로딩 안내 바로 확인

온라인 WebView 첫 로딩 경고를 즉시 띄웁니다.

```bash
flutter run \
  --dart-define=GRANITE_WEBVIEW_FIRST_LOAD_WARNING_MS=0
```

### 서버 확인 실패 상황 확인

네트워크 확인 URL을 실패하는 주소로 지정하면 오프라인 번들로 이동하는 흐름을 확인할 수 있습니다.

```bash
flutter run \
  --dart-define=GRANITE_NETWORK_CHECK_URL=https://127.0.0.1:1/ \
  --dart-define=GRANITE_NETWORK_CHECK_TIMEOUT_MS=1000
```

## 오프라인 번들 갱신

오프라인 화면은 `assets/offline_web/index.html`과 `assets/offline_web/images/`에 들어 있습니다. 기본적으로 이 저장소와 같은 상위 폴더에 있는 `granite-climbing.github.io` 프로젝트의 `content`와 `public/images`를 읽어 생성합니다.

```bash
node tool/build_offline_seed.mjs
```

다른 위치의 웹 프로젝트를 쓰려면 경로를 인자로 넘깁니다.

```bash
node tool/build_offline_seed.mjs /path/to/granite-climbing.github.io
```

생성 후 앱을 다시 실행하면 갱신된 오프라인 번들이 포함됩니다.

## 테스트

```bash
flutter test
```
