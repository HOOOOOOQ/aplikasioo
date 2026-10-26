#!/usr/bin/env bash
# Smoke test instalasi APK di emulator Android (dipakai CI, bisa dijalankan lokal).
# Pemakaian: bash scripts/ci/emulator-smoke.sh [path-ke-apk]
# Semua output dicatat; exit code 1 bila install/launch gagal atau ada crash.

set -uo pipefail

APK="${1:-$(ls dist/*universal.apk 2>/dev/null | head -1)}"
PKG="com.edutask.sekolah"
ACTIVITY="$PKG/.MainActivity"
FAIL=0

echo "===== INFORMASI EMULATOR ====="
adb wait-for-device
adb shell getprop ro.build.version.sdk || true
adb shell getprop ro.build.version.release || true
adb shell getprop ro.product.cpu.abi || true
adb shell getprop ro.product.cpu.abilist || true

echo "===== APK YANG DIUJI ====="
ls -l "$APK" || { echo "APK tidak ditemukan"; exit 1; }
sha256sum "$APK" || true

echo "===== INSTALL ====="
if ! adb install -r "$APK"; then
  echo "!! adb install gagal, coba tanpa -r"
  adb uninstall "$PKG" >/dev/null 2>&1 || true
  if ! adb install "$APK"; then
    echo "!! INSTALL GAGAL TOTAL"
    FAIL=1
  fi
fi

echo "===== PAKET TERPASANG ====="
adb shell pm list packages | grep "$PKG" || { echo "!! paket tidak terdaftar"; FAIL=1; }
adb shell dumpsys package "$PKG" | grep -E "versionName|versionCode|minSdk|targetSdk|primaryCpuAbi" || true

echo "===== COLD START ====="
adb logcat -c || true
adb shell am start -W -n "$ACTIVITY" 2>&1 | tee /tmp/start.txt
grep -q "Status: ok" /tmp/start.txt || { echo "!! am start tidak melaporkan Status: ok"; FAIL=1; }

sleep 15
echo "===== PROSES ====="
PID=$(adb shell pidof "$PKG" | tr -d '\r')
echo "pid=$PID"
[ -n "$PID" ] || { echo "!! proses aplikasi tidak berjalan"; FAIL=1; }

echo "===== LOGCAT (crash?) ====="
adb logcat -d > /tmp/logcat.txt || true
if grep -q "FATAL EXCEPTION" /tmp/logcat.txt; then
  echo "!! FATAL EXCEPTION:"
  grep -B2 -A25 "FATAL EXCEPTION" /tmp/logcat.txt
  FAIL=1
fi
grep -iE "AndroidRuntime|flutter.*(error|exception)" /tmp/logcat.txt | tail -20 || true

echo "===== RELAUNCH (background -> foreground) ====="
adb shell input keyevent 3 || true
sleep 2
adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1 || true
sleep 5
adb logcat -d > /tmp/logcat2.txt || true
if grep -q "FATAL EXCEPTION" /tmp/logcat2.txt; then
  echo "!! Crash setelah relaunch"
  grep -B2 -A25 "FATAL EXCEPTION" /tmp/logcat2.txt
  FAIL=1
fi

echo "===== HASIL ====="
if [ "$FAIL" -eq 0 ]; then
  echo "LULUS: APK terpasang, aplikasi terbuka, tidak ada FATAL EXCEPTION."
else
  echo "GAGAL: lihat pesan !! di atas."
fi
exit "$FAIL"
