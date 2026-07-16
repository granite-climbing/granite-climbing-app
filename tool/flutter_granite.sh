#!/usr/bin/env bash
set -euo pipefail

APP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULT_ENVIRONMENT="prod"
EXPORT_OPTIONS_FILE="${FLUTTER_GRANITE_EXPORT_OPTIONS_FILE:-$APP_ROOT/ios/ExportOptions.AppStoreConnect.plist}"

die() {
  echo "$*" >&2
  exit 64
}

usage() {
  cat <<'USAGE'
Usage:
  tool/flutter_granite.sh build ipa [--env local|prod] [Flutter IPA options]
  tool/flutter_granite.sh build apk [--env local|prod] [Flutter APK options]

The wrapper reads config/<environment>.env by default. Environment variables
already present in the shell or CI override values in that file.
USAGE
}

read_env_file_value() {
  local file="$1"
  local key="$2"
  local line=""
  local value=""

  [[ -f "$file" ]] || return 1

  line="$(
    sed -nE "s/^[[:space:]]*(export[[:space:]]+)?${key}=//p" "$file" |
      tail -n 1
  )"
  [[ -n "$line" ]] || return 1

  value="${line%$'\r'}"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"

  if [[ "$value" == \"*\" && "$value" == *\" ]]; then
    value="${value:1:${#value}-2}"
  elif [[ "$value" == \'*\' && "$value" == *\' ]]; then
    value="${value:1:${#value}-2}"
  fi

  printf '%s' "$value"
}

config_value() {
  local key="$1"
  local value="${!key:-}"

  if [[ -n "$value" ]]; then
    printf '%s' "$value"
    return 0
  fi

  read_env_file_value "$ENV_FILE" "$key"
}

append_dart_define() {
  local key="$1"
  local value=""

  value="$(config_value "$key" || true)"
  [[ -n "$value" ]] || return 0
  dart_defines+=("--dart-define=$key=$value")
}

build_target="${2:-}"
[[ "${1:-}" == "build" && ( "$build_target" == "ipa" || "$build_target" == "apk" ) ]] || {
  usage
  die "Only 'build ipa' and 'build apk' are supported."
}
shift 2

environment="$DEFAULT_ENVIRONMENT"
forward_args=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)
      [[ $# -ge 2 ]] || die "--env requires local or prod."
      environment="$2"
      shift 2
      ;;
    --env=*)
      environment="${1#--env=}"
      shift
      ;;
    *)
      forward_args+=("$1")
      shift
      ;;
  esac
done

[[ "$environment" == "local" || "$environment" == "prod" ]] || die "--env must be local or prod."
ENV_FILE="${FLUTTER_GRANITE_ENV_FILE:-$APP_ROOT/config/$environment.env}"
[[ -f "$ENV_FILE" ]] || die "Environment file not found: $ENV_FILE"
if [[ "$build_target" == "ipa" ]]; then
  [[ -f "$EXPORT_OPTIONS_FILE" ]] || die "Export options file not found: $EXPORT_OPTIONS_FILE"
fi

naver_client_secret="$(config_value NAVER_CLIENT_SECRET || true)"
[[ -n "$naver_client_secret" ]] || die "NAVER_CLIENT_SECRET is required for a $build_target build. Set it in the shell, CI, or $ENV_FILE."

if [[ "$build_target" == "apk" ]]; then
  google_client_id_apk="$(config_value GOOGLE_CLIENT_ID_APK || true)"
  if [[ -n "$google_client_id_apk" ]]; then
    GOOGLE_CLIENT_ID="$google_client_id_apk"
  fi
fi

dart_defines=()
for key in \
  GRANITE_WEB_URL \
  KAKAO_NATIVE_APP_KEY \
  NAVER_CLIENT_ID \
  NAVER_CLIENT_SECRET \
  NAVER_CLIENT_NAME \
  NAVER_URL_SCHEME \
  GOOGLE_CLIENT_ID \
  GOOGLE_SERVER_CLIENT_ID \
  APPLE_SERVICE_ID \
  APPLE_REDIRECT_URI
do
  append_dart_define "$key"
done

has_export_options="false"
if [[ ${#forward_args[@]} -gt 0 ]]; then
  for argument in "${forward_args[@]}"; do
    if [[ "$argument" == "--export-options-plist" || "$argument" == --export-options-plist=* ]]; then
      has_export_options="true"
      break
    fi
  done
fi

command=(flutter build "$build_target" --release)
if [[ "$build_target" == "ipa" && "$has_export_options" == "false" ]]; then
  command+=("--export-options-plist=$EXPORT_OPTIONS_FILE")
fi
if [[ ${#forward_args[@]} -gt 0 ]]; then
  command+=("${forward_args[@]}")
fi
command+=("${dart_defines[@]}")

cd "$APP_ROOT"
exec "${command[@]}"
