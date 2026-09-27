import 'dart:io' show Platform;
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../utils/app_logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class LocalNotificationService {
  static final LocalNotificationService instance =
  LocalNotificationService._();
  LocalNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
  FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Callback pour gérer la navigation quand on tap sur une notification
  static void Function(String payload)? onNotificationTap;

  /// Messages amusants pour les rappels
  static const List<Map<String, String>> _reminderMessages = [
    // Mode Solo / Rapide
    {
      'title': '🃏 Les cartes s\'ennuient...',
      'body': 'Elles n\'attendent que toi pour une partie rapide !',
      'payload': 'solo',
    },
    {
      'title': '😴 Le bot fait une sieste',
      'body': 'Réveille-le avec une bonne raclée !',
      'payload': 'solo',
    },
    {
      'title': '🎯 Partie rapide ?',
      'body': '2 minutes pour prouver que t\'es le boss !',
      'payload': 'solo',
    },
    // Mode Arcade
    {
      'title': '🔥 Ta série de victoires t\'attend !',
      'body': 'Viens battre ton record en mode Arcade !',
      'payload': 'arcade',
    },
    {
      'title': '🏆 Le classement Arcade a changé...',
      'body': 'Quelqu\'un essaie de te voler la 1ère place !',
      'payload': 'arcade',
    },
    {
      'title': '💪 Mode Arcade : Prêt à enchaîner ?',
      'body': 'Chaque victoire compte. Montre ce que tu vaux !',
      'payload': 'arcade',
    },
    {
      'title': '🎮 Arcade Time !',
      'body': 'Combien de victoires d\'affilée aujourd\'hui ?',
      'payload': 'arcade',
    },
    // Mode Survie
    {
      'title': '⏱️ Le chrono t\'appelle !',
      'body': 'Mode Survie : Combien de manches vas-tu tenir ?',
      'payload': 'survival',
    },
    {
      'title': '🌡️ La pression monte...',
      'body': 'Survie : Es-tu assez rapide pour survivre ?',
      'payload': 'survival',
    },
    {
      'title': '⚡ Test de réflexes !',
      'body': 'Le mode Survie n\'attend pas les lents...',
      'payload': 'survival',
    },
    {
      'title': '🎯 Survie : Nouveau défi ?',
      'body': 'Difficulté croissante, temps limité. Tu gères ?',
      'payload': 'survival',
    },
    // Messages généraux fun
    {
      'title': '🃏 Tes cartes te manquent !',
      'body': 'Reviens leur dire bonjour !',
      'payload': 'random',
    },
    {
      'title': '🤖 Le bot s\'entraîne en secret...',
      'body': 'Viens lui montrer qui commande !',
      'payload': 'random',
    },
    {
      'title': '📱 CheckGames a besoin de toi !',
      'body': 'Une petite partie pour la route ?',
      'payload': 'random',
    },
    {
      'title': '🎲 La chance sourit aux joueurs !',
      'body': 'Et si c\'était ton jour de chance ?',
      'payload': 'random',
    },
  ];

  /// Vérifie si les notifications sont supportées sur cette plateforme
  static bool get isSupported {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  Future<void> init() async {
    if (!isSupported) return;
    if (_initialized) return;

    tz.initializeTimeZones();

    const androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
    _initialized = true;
  }

  void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null && onNotificationTap != null) {
      onNotificationTap!(payload);
    }
  }
  Future<bool> requestPermission() async {
    if (!isSupported) return false;

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted ?? false;
    }

    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();

    if (ios != null) {
      final granted = await ios.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }

    return true;
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!isSupported || !_initialized) return;
    const androidDetails = AndroidNotificationDetails(
      'checkgames_channel',
      'Checkgames',
      channelDescription: 'Notifications du jeu CheckGames',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@drawable/ic_notification',
      sound: RawResourceAndroidNotificationSound('notification_sound'),
      playSound: true,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    await _plugin.show(id, title, body, details, payload: payload);
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
  }) async {
    if (!isSupported || !_initialized) return;

    const androidDetails = AndroidNotificationDetails(
      'checkgames_scheduled',
      'Rappels CheckGames',
      channelDescription: 'Rappels programmés',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledTime, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }

  Future<void> scheduleDailyNotification({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    if (!isSupported || !_initialized) return;

    const androidDetails = AndroidNotificationDetails(
      'checkgames_daily',
      'Rappel quotidien',
      channelDescription: 'Rappel quotidien pour jouer',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      _nextInstanceOfTime(hour, minute),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }
  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month,
        now.day, hour, minute);

    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
  Future<void> cancelNotification(int id) async {
    if (!isSupported || !_initialized) return;
    await _plugin.cancel(id);
  }

  Future<void> cancelAllNotifications() async {
    if (!isSupported || !_initialized) return;
    await _plugin.cancelAll();
  }

  /// Programme des rappels toutes les 2 heures avec messages aléatoires
  /// IDs utilisés : 1000-1011 (12 notifications pour couvrir 24h)
  Future<void> setupPeriodicReminders() async {
    if (!isSupported || !_initialized) return;

    // Annuler les anciens rappels
    await cancelPeriodicReminders();

    final random = Random();
    final now = tz.TZDateTime.now(tz.local);

    // Programmer 12 notifications
    for (int i = 0; i < 12; i++) {
      final hoursToAdd = (i + 1) * 4; // TEST: 1min, 2min, 3min...
      final scheduledTime = now.add(Duration(hours: hoursToAdd));

      // Choisir un message aléatoire
      final message = _reminderMessages[random.nextInt
        (_reminderMessages.length)];

      const androidDetails = AndroidNotificationDetails(
        'checkgames_reminder',
        'Rappels de jeu',
        channelDescription: 'Rappels pour jouer à CheckGames',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        icon: '@drawable/ic_notification', // Icône personnalisée
        sound: RawResourceAndroidNotificationSound('notification_sound'),
        // Son personnalisé
        playSound: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _plugin.zonedSchedule(
        1000 + i, // IDs 1000-1011
        message['title']!,
        message['body']!,
        scheduledTime,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: message['payload'],
      );
    }

    appLogger.i('12 rappels programmés');
  }

  /// Annule tous les rappels périodiques
  Future<void> cancelPeriodicReminders() async {
    if (!isSupported || !_initialized) return;

    for (int i = 0; i < 12; i++) {
      await _plugin.cancel(1000 + i);
    }
  }

  /// Reprogramme les rappels (à appeler quand l'app s'ouvre)
  Future<void> refreshPeriodicReminders() async {
    if (!isSupported || !_initialized) return;
    await setupPeriodicReminders();
  }

  /// Obtient un message aléatoire (utile pour tester)
  static Map<String, String> getRandomMessage() {
    final random = Random();
    return _reminderMessages[random.nextInt(_reminderMessages.length)];
  }
}