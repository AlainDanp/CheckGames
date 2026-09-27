import 'package:checkgame/services/push_notification_service.dart';
import 'in_app_notification_service.dart';
import 'local_notification_service.dart';
import '../utils/app_logger.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final _local = LocalNotificationService.instance;
  final _push = PushNotificationService.instance;
  final _inApp = InAppNotificationService.instance;

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    try {
      await _local.init();
      await _push.init();
      await _local.requestPermission();
      _initialized = true;
    } catch (e) {
      appLogger.e('Erreur init NotificationService', error: e);
    }
  }

  // Victoire (choisir une seule notification in-app)
  void notifyVictory({required int winStreak, bool isHighScore = false}) {
    if (isHighScore) {
      // High score : notification spéciale + notification locale
      _inApp.showAchievement('Nouveau Record !', message: 'Série : $winStreak');
      _local.showNotification(
        id: 1,
        title: 'Nouveau Record !',
        body: 'Série de $winStreak victoires !',
      );
    } else {
      // Victoire normale
      _inApp.showSuccess('Victoire !', message: 'Série : $winStreak');
    }
  }

  void notifyDefeat() {
    _inApp.showError('Partie terminée');
  }

  // Survie
  void notifySurvivalRecord({required int rounds, required String difficulty}) {
    _inApp.showAchievement('Record Survie !', message: '$rounds manches - $difficulty');
    _local.showNotification(
      id: 2,
      title: 'Record Survie !',
      body: '$rounds manches en difficulté $difficulty',
    );
  }

  // Rappel quotidien
  void setupDailyReminder({required int hour, required int minute}) {
    _local.scheduleDailyNotification(
      id: 100,
      title: 'CheckGames',
      body: 'Prêt pour une partie ?',
      hour: hour,
      minute: minute,
    );
  }

  // Désactiver le rappel quotidien
  void cancelDailyReminder() {
    _local.cancelNotification(100);
  }

  // ===== RAPPELS TOUTES LES 2H =====

  /// Active les rappels toutes les 2 heures
  Future<void> enablePeriodicReminders() async {
    await _local.setupPeriodicReminders();
  }

  /// Désactive les rappels toutes les 2 heures
  Future<void> disablePeriodicReminders() async {
    await _local.cancelPeriodicReminders();
  }

  /// Rafraîchit les rappels (à appeler quand l'app s'ouvre)
  Future<void> refreshReminders() async {
    await _local.refreshPeriodicReminders();
  }

  /// Envoie une notification de test pour voir le résultat
  void testReminderNotification() {
    final message = LocalNotificationService.getRandomMessage();
    _local.showNotification(
      id: 9999,
      title: message['title']!,
      body: message['body']!,
      payload: message['payload'],
    );
  }
}