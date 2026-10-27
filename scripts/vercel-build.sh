
#!/usr/bin/env bash
set -euo pipefail

git clone --depth 1 --branch 3.35.7 \
  https://github.com/flutter/flutter.git /tmp/flutter-sdk

export PATH="/tmp/flutter-sdk/bin:$PATH"

flutter config --enable-web
flutter pub get

flutter build web --release \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"
