// Fallback untuk platform tanpa implementasi notifikasi lokal (mis. Web).
// Tidak mengimpor plugin apa pun sehingga aman dikompilasi ke JavaScript.

class NotificationBackend {
  const NotificationBackend();

  Future<void> init() async {}

  bool get supported => false;

  Future<bool> requestPermission() async => false;

  Future<int> scheduleDeadline({
    required int id,
    required String title,
    required String body,
    required DateTime when,
  }) async =>
      0;

  Future<void> cancel(int id) async {}

  Future<void> cancelAll() async {}
}
