import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

class HapticFeedbackHelper {
  static void light() {
    HapticFeedback.lightImpact();
  }
  static void medium() {
    HapticFeedback.mediumImpact();
  }
  static void heavy() {
    HapticFeedback.heavyImpact();
  }
  static Future<void> checksPattern() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(
        pattern: [0, 100, 50, 100, 50, 200],
      );
    }
  }
  static Future<void> victoryPattern() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(
        pattern: [0, 50, 100, 50, 100, 50],
      );
    }
  }
  static void error() {
    HapticFeedback.vibrate();
  }
}
