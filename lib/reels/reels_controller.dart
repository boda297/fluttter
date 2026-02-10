import 'package:flutter/foundation.dart';

/// ReelsController - مسؤول عن الـ index فقط
/// Manages only the current index state
class ReelsController extends ChangeNotifier {
  int currentIndex = 0;

  void updateIndex(int index) {
    if (currentIndex != index) {
      currentIndex = index;
      notifyListeners();
    }
  }

  void reset() {
    currentIndex = 0;
    notifyListeners();
  }
}

