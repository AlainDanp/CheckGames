import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase doit déjà être initialisé dans main.dart
  // On vérifie juste qu'il est prêt
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp();
  }
  print('Background message: ${message.messageId}');
}

class PushNotificationService {
  static final PushNotificationService instance = PushNotificationService._();
  PushNotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localPlugin =
      FlutterLocalNotificationsPlugin();

  String? _fcmToken;
  String? get fcmToken => _fcmToken;
  bool _initialized = false;

  /// Vérifie si les notifications push sont supportées
  static bool get isSupported {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  Future<void> init() async {
    if (!isSupported || _initialized) return;

    try {
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Initialiser le plugin local pour afficher les notifs au premier plan
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const settings = InitializationSettings(
        android: androidInit,
        iOS: iosInit,
      );
      await _localPlugin.initialize(settings);

      // Créer le channel Android
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'push_channel',
        'Notifications Push',
        description: 'Notifications push du serveur',
        importance: Importance.max,
      );

      final androidPlugin = _localPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(channel);

      // Demander permission
      final permission = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (permission.authorizationStatus == AuthorizationStatus.authorized) {
        print('Push permission accordée');

        _fcmToken = await _messaging.getToken();
        print('FCM Token: $_fcmToken');

        _messaging.onTokenRefresh.listen((token) {
          _fcmToken = token;
          _saveTokenToServer(token);
        });

        _setupMessageListeners();
      }

      _initialized = true;
    } catch (e) {
      print('Erreur init push notifications: $e');
    }
  }

  void _setupMessageListeners() {
    // Notification reçue AU PREMIER PLAN
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('🔔 Foreground message: ${message.notification?.title}');
      _showLocalNotification(message);
    });

    // Quand on clique sur la notif
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('🟢 Notification tapped: ${message.data}');
      _handleNotificationTap(message.data);
    });
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    const androidDetails = AndroidNotificationDetails(
      'push_channel',
      'Notifications Push',
      channelDescription: 'Notifications push du serveur',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@drawable/ic_notification',
      sound: RawResourceAndroidNotificationSound('notification_sound'),
      playSound: true,
    );

    const details = NotificationDetails(android: androidDetails);

    await _localPlugin.show(
      message.hashCode,
      notification.title,
      notification.body,
      details,
      payload: message.data.toString(),
    );
  }

  void _handleNotificationTap(Map<String, dynamic> data) {
    final type = data['type'];

    switch (type) {
      case 'challenge':
        print('👉 Aller vers défi');
        break;
      case 'friend_request':
        print('👉 Aller vers demandes d’amis');
        break;
      case 'game_invite':
        print('👉 Aller vers invitation de partie');
        break;
      default:
        print('Type inconnu: $type');
    }
  }

  Future<void> _saveTokenToServer(String token) async {
    // TODO: envoyer le token à Firestore ou ton backend
  }

  Future<void> subscribeToTopic(String topic) async {
    if (!isSupported || !_initialized) return;
    try {
      await _messaging.subscribeToTopic(topic);
    } catch (e) {
      print('Erreur subscribe topic: $e');
    }
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    if (!isSupported || !_initialized) return;
    try {
      await _messaging.unsubscribeFromTopic(topic);
    } catch (e) {
      print('Erreur unsubscribe topic: $e');
    }
  }
}
