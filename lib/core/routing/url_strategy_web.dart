import 'package:flutter_web_plugins/url_strategy.dart';

/// Mengatur bentuk URL pada Flutter Web.
///
/// Default aplikasi adalah **hash strategy** (`/#/admin`) karena bekerja di
/// semua static host tanpa konfigurasi tambahan, termasuk `flutter run
/// -d web-server` dan `python -m http.server`.
///
/// Strategi path (`/admin`) hanya diaktifkan lewat
/// `--dart-define=USE_PATH_URL_STRATEGY=true` setelah host dikonfigurasi
/// mengarahkan semua rute ke `index.html` (lihat `web/_redirects` dan
/// `docs/round5-edutask.md`).
void configureUrlStrategy({required bool usePathStrategy}) {
  if (usePathStrategy) {
    usePathUrlStrategy();
  }
}
