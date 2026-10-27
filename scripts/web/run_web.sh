#!/usr/bin/env bash
# Jalankan EduTask versi Web di http://localhost:8080 (mode pengembangan).
#
# Pemakaian:
#   export SUPABASE_URL="https://<project-ref>.supabase.co"
#   export SUPABASE_ANON_KEY="<anon-key>"
#   bash scripts/web/run_web.sh
#
# Atau isi berkas .env.web (lihat .env.web.example) lalu jalankan tanpa export.
#
# Opsi:
#   WEB_PORT=8080            ganti port
#   WEB_HOST=127.0.0.1       batasi ke localhost saja (default)
#   WEB_HOST=0.0.0.0         bisa diakses dari HP di Wi-Fi yang sama (hati-hati!)
#   WEB_DEVICE=web-server    server tanpa jendela browser (default, cocok untuk
#                            Termux/SSH/CI). Pakai WEB_DEVICE=chrome untuk
#                            membuka Chrome otomatis dengan hot reload.
#   USE_PATH_URL_STRATEGY=1  URL bersih (/admin) alih-alih hash (/#/admin)
#
# Catatan keamanan: `flutter run -d web-server` adalah server pengembangan
# tanpa autentikasi. Jangan pakai WEB_HOST=0.0.0.0 di jaringan publik, dan
# jangan pakai mode ini untuk produksi.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/web/env_check.sh
. "$SCRIPT_DIR/env_check.sh"

WEB_HOST="${WEB_HOST:-127.0.0.1}"
WEB_DEVICE="${WEB_DEVICE:-web-server}"

check_flutter
check_config

echo "[web] flutter pub get…"
cd "$ROOT_DIR" || exit 1
flutter pub get || _fail "flutter pub get gagal"

DEFINES=()
while IFS= read -r line; do DEFINES+=("$line"); done < <(dart_defines)
if [ "${USE_PATH_URL_STRATEGY:-0}" = "1" ]; then
  DEFINES+=("--dart-define=USE_PATH_URL_STRATEGY=true")
  echo "[web] memakai path URL strategy (butuh server yang mengarahkan semua rute ke index.html)"
fi

echo "[web] menjalankan aplikasi di http://localhost:${WEB_PORT} (device: ${WEB_DEVICE})"
if [ "$WEB_HOST" = "0.0.0.0" ]; then
  # `hostname -I` ada di Linux/Termux, `ipconfig` di macOS.
  LAN_IP="$(hostname -I 2>/dev/null | awk '{print $1}' || true)"
  if [ -z "$LAN_IP" ]; then
    LAN_IP="$(ipconfig getifaddr en0 2>/dev/null || true)"
  fi
  echo "[web] server mendengarkan di semua antarmuka (0.0.0.0):"
  echo "[web]   komputer ini : http://localhost:${WEB_PORT}"
  if [ -n "$LAN_IP" ]; then
    echo "[web]   perangkat lain di Wi-Fi yang sama: http://${LAN_IP}:${WEB_PORT}"
  fi
  echo "[web] PERINGATAN: flutter run -d web-server tidak punya autentikasi."
  echo "[web]               Hanya lakukan ini di jaringan yang Anda percayai."
fi

exec flutter run -d "$WEB_DEVICE" \
  --web-hostname "$WEB_HOST" \
  --web-port "$WEB_PORT" \
  "${DEFINES[@]}"
