#!/usr/bin/env bash
# Utilitas bersama untuk scripts/web/run_web.sh dan build_web.sh.
# Tidak menyimpan kredensial; hanya membaca dari environment atau berkas
# .env.web (tidak pernah di-commit).
#
# Dipakai dengan `source`, bukan dijalankan langsung.

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENV_FILE="${ENV_FILE:-$ROOT_DIR/.env.web}"

# Muat berkas env bila ada (format: KEY=nilai, satu per baris).
if [ -f "$ENV_FILE" ]; then
  # shellcheck disable=SC1090
  set -a
  . "$ENV_FILE"
  set +a
  echo "[web] memuat konfigurasi dari $ENV_FILE"
fi

: "${SUPABASE_URL:=}"
: "${SUPABASE_ANON_KEY:=}"
WEB_PORT="${WEB_PORT:-8080}"

_fail() {
  echo "[web] ERROR: $1" >&2
  exit 1
}

check_flutter() {
  command -v flutter >/dev/null 2>&1 \
    || _fail "flutter tidak ditemukan di PATH. Pasang Flutter 3.35.x: https://docs.flutter.dev/get-started/install"
}

check_config() {
  [ -n "$SUPABASE_URL" ] \
    || _fail "SUPABASE_URL kosong. Set lewat environment atau .env.web (lihat .env.web.example)."
  [ -n "$SUPABASE_ANON_KEY" ] \
    || _fail "SUPABASE_ANON_KEY kosong. Set lewat environment atau .env.web (lihat .env.web.example)."

  case "$SUPABASE_URL" in
    https://*) ;;
    *) _fail "SUPABASE_URL harus diawali https:// (nilai sekarang: '${SUPABASE_URL}')" ;;
  esac

  # Jangan pernah mencetak kunci. Cukup panjangnya sebagai konfirmasi.
  echo "[web] SUPABASE_URL = $SUPABASE_URL"
  echo "[web] SUPABASE_ANON_KEY = (${#SUPABASE_ANON_KEY} karakter, tidak ditampilkan)"
}

# Argumen --dart-define yang identik untuk `flutter run` maupun `flutter build`.
dart_defines() {
  printf '%s\n' \
    "--dart-define=SUPABASE_URL=$SUPABASE_URL" \
    "--dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY"
}
