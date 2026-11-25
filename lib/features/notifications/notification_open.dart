import 'package:flutter/foundation.dart';

class NotificationOpen extends ChangeNotifier {
  String? _payload;
  bool get inAttesa => _payload != null;

  void ricevi(String payload) {
    _payload = payload;
    notifyListeners();
  }

  String? consuma() {
    final payload = _payload;
    _payload = null;
    return payload;
  }
}
