#!/usr/bin/env bash
# Build rilis Web EduTask ke build/web, opsional langsung disajikan lokal.
#
# Pemakaian:
#   export SUPABASE_URL="https://<project-ref>.supabase.co"
#   export SUPABASE_ANON_KEY="<anon-key>"
#   bash scripts/web/build_web.sh              # hasil di build/web
#   bash scripts/web/build_web.sh --serve      # build lalu sajikan di :8080
#
# Opsi:
#   WEB_PORT=8080                port untuk --serve
#   BASE_HREF=/edutask/          bila disajikan di sub-path
#   USE_PATH_URL_STRATEGY=1      URL bersih (butuh rewrite ke index.html)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/web/env_check.sh
. "$SCRIPT_DIR/env_check.sh"

SERVE=0
for arg in "$@"; do
  case "$arg" in
    --serve) SERVE=1 ;;
    -h|--help)
      sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "[web] argumen tidak dikenal: $arg" >&2; exit 2 ;;
  esac
done

check_flutter
check_config

cd "$ROOT_DIR" || exit 1
echo "[web] flutter pub get…"
flutter pub get || _fail "flutter pub get gagal"

DEFINES=()
while IFS= read -r line; do DEFINES+=("$line"); done < <(dart_defines)
if [ "${USE_PATH_URL_STRATEGY:-0}" = "1" ]; then
  DEFINES+=("--dart-define=USE_PATH_URL_STRATEGY=true")
fi

BUILD_ARGS=(web --release)
if [ -n "${BASE_HREF:-}" ]; then
  BUILD_ARGS+=("--base-href=${BASE_HREF}")
fi

echo "[web] flutter build ${BUILD_ARGS[*]}…"
flutter build "${BUILD_ARGS[@]}" "${DEFINES[@]}" || _fail "flutter build web gagal"

[ -f build/web/index.html ] || _fail "build/web/index.html tidak ditemukan"
echo "[web] selesai: $(du -sh build/web | cut -f1) di build/web"

if [ "$SERVE" = "1" ]; then
  command -v python3 >/dev/null 2>&1 || _fail "python3 dibutuhkan untuk --serve"
  echo "[web] menyajikan build/web di http://localhost:${WEB_PORT} (Ctrl+C untuk berhenti)"
  echo "[web] hanya untuk pratinjau lokal; jangan diekspos ke internet"
  cd build/web || exit 1
  exec python3 -m http.server "$WEB_PORT" --bind 127.0.0.1
fi

cat <<'EOF'

Langkah berikutnya:
  - Pratinjau lokal cepat : bash scripts/web/build_web.sh --serve
  - Hosting statis        : unggah isi build/web (Netlify/Cloudflare Pages/Vercel)
                            dan sertakan web/_redirects bila memakai path strategy
  - Sub-path (mis. /edutask/): BASE_HREF=/edutask/ bash scripts/web/build_web.sh
EOF
