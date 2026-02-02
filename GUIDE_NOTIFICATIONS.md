# Guide : Ajouter des Notifications au Jeu CheckGames

## Table des matières
1. [Types de notifications](#types-de-notifications)
2. [Notifications locales](#notifications-locales)
3. [Notifications Push (Firebase)](#notifications-push-firebase)
4. [Notifications In-App](#notifications-in-app)
5. [Implémentation recommandée](#implémentation-recommandée)

---

## Types de notifications

| Type | Description | Cas d'usage |
|------|-------------|-------------|
| **Locales** | Programmées sur l'appareil | Rappels, événements quotidiens |
| **Push (FCM)** | Envoyées depuis un serveur | Défis multijoueur, mises à jour |
| **In-App** | Affichées dans l'application | Succès, récompenses, alertes |

---

## Notifications locales

### 1. Installation

```yaml
# pubspec.yaml
dependencies:
  flutter_local_notifications: ^17.0.0
  timezone: ^0.9.2
```

### 2. Configuration Android

```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<manifest>
    <!-- Permissions -->
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
    <uses-permission android:name="android.permission.VIBRATE"/>
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>

    <application>
        <!-- Receiver pour les notifications programmées -->
        <receiver
            android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver"
            android:exported="false"/>
        <receiver
            android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver"
            android:exported="false">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
            </intent-filter>
        </receiver>
    </application>
</manifest>
```

### 3. Configuration iOS

```xml
<!-- ios/Runner/Info.plist -->
<key>UIBackgroundModes</key>
<array>
    <string>fetch</string>
    <string>remote-notification</string>
</array>
```

### 4. Service de notifications locales

```dart
// lib/services/local_notification_service.dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class LocalNotificationService {
  static final LocalNotificationService instance = LocalNotificationService._();
  LocalNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    // Initialiser timezone
    tz.initializeTimeZones();

    // Configuration Android
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // Configuration iOS
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
    // Gérer le tap sur la notification
    final payload = response.payload;
    if (payload != null) {
      // Naviguer vers l'écran approprié selon le payload
      print('Notification tapped: $payload');
    }
  }

  /// Demander la permission (iOS et Android 13+)
  Future<bool> requestPermission() async {
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

  /// Afficher une notification immédiate
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'checkgames_channel',
      'CheckGames',
      channelDescription: 'Notifications du jeu CheckGames',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
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

  /// Programmer une notification
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'checkgames_scheduled',
      'Rappels CheckGames',
      channelDescription: 'Rappels programmés',
      importance: Importance.high,
      priority: Priority.high,
    );

    const details = NotificationDetails(android: androidDetails);

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

  /// Notification quotidienne à une heure fixe
  Future<void> scheduleDailyNotification({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'checkgames_daily',
      'Rappel quotidien',
      channelDescription: 'Rappel quotidien pour jouer',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );

    const details = NotificationDetails(android: androidDetails);

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      _nextInstanceOfTime(hour, minute),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // Répète chaque jour
    );
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);

    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  /// Annuler une notification
  Future<void> cancelNotification(int id) async {
    await _plugin.cancel(id);
  }

  /// Annuler toutes les notifications
  Future<void> cancelAllNotifications() async {
    await _plugin.cancelAll();
  }
}
```

### 5. Utilisation

```dart
// Dans main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalNotificationService.instance.init();
  await LocalNotificationService.instance.requestPermission();
  runApp(MyApp());
}

// Exemples d'utilisation
class NotificationExamples {
  // Notification de victoire
  void notifyVictory(int winStreak) {
    LocalNotificationService.instance.showNotification(
      id: 1,
      title: 'Victoire !',
      body: 'Vous avez une série de $winStreak victoires !',
      payload: 'arcade_mode',
    );
  }

  // Rappel quotidien à 19h
  void setupDailyReminder() {
    LocalNotificationService.instance.scheduleDailyNotification(
      id: 100,
      title: 'CheckGames vous attend !',
      body: 'Venez battre votre record !',
      hour: 19,
      minute: 0,
    );
  }

  // Notification programmée (ex: bonus disponible dans 4h)
  void notifyBonusReady() {
    LocalNotificationService.instance.scheduleNotification(
      id: 200,
      title: 'Bonus disponible !',
      body: 'Votre bonus quotidien est prêt à être récupéré.',
      scheduledTime: DateTime.now().add(const Duration(hours: 4)),
      payload: 'daily_bonus',
    );
  }
}
```

---

## Notifications Push (Firebase)

### 1. Installation

```yaml
# pubspec.yaml
dependencies:
  firebase_core: ^2.24.0
  firebase_messaging: ^14.7.0
```

### 2. Configuration Firebase

Suivre les étapes de configuration Firebase si pas déjà fait :
- Créer un projet Firebase
- Ajouter `google-services.json` (Android) et `GoogleService-Info.plist` (iOS)

### 3. Service Firebase Messaging

```dart
// lib/services/push_notification_service.dart
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Handler pour les messages en arrière-plan (doit être top-level)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Background message: ${message.messageId}');
}

class PushNotificationService {
  static final PushNotificationService instance = PushNotificationService._();
  PushNotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localPlugin = FlutterLocalNotificationsPlugin();

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  Future<void> init() async {
    // Configurer le handler background
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Demander la permission
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('Permission accordée');

      // Obtenir le token FCM
      _fcmToken = await _messaging.getToken();
      print('FCM Token: $_fcmToken');

      // Écouter les changements de token
      _messaging.onTokenRefresh.listen((token) {
        _fcmToken = token;
        _saveTokenToServer(token);
      });

      // Configurer les listeners
      _setupMessageListeners();
    }
  }

  void _setupMessageListeners() {
    // Message reçu quand l'app est au premier plan
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Foreground message: ${message.notification?.title}');
      _showLocalNotification(message);
    });

    // Quand l'utilisateur tape sur une notification (app en arrière-plan)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('Notification tapped: ${message.data}');
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
    // Naviguer selon le type de notification
    final type = data['type'];
    switch (type) {
      case 'challenge':
        // Naviguer vers un défi multijoueur
        break;
      case 'friend_request':
        // Naviguer vers les demandes d'amis
        break;
      case 'game_invite':
        // Naviguer vers une invitation de partie
        break;
    }
  }

  Future<void> _saveTokenToServer(String token) async {
    // Envoyer le token à votre serveur/Firebase
    // Pour associer ce token à l'utilisateur
  }

  /// S'abonner à un topic (ex: tous les joueurs, une ligue, etc.)
  Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
  }

  /// Se désabonner d'un topic
  Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
  }
}
```

### 4. Envoi depuis Firebase Console ou serveur

**Via Firebase Console :**
1. Aller sur Firebase Console > Cloud Messaging
2. Créer une nouvelle campagne
3. Cibler par topic ou token

**Via serveur (Node.js exemple) :**

```javascript
const admin = require('firebase-admin');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

// Envoyer à un utilisateur spécifique
async function sendToUser(fcmToken, title, body, data) {
  const message = {
    notification: { title, body },
    data: data,
    token: fcmToken,
  };

  await admin.messaging().send(message);
}

// Envoyer à un topic (tous les abonnés)
async function sendToTopic(topic, title, body) {
  const message = {
    notification: { title, body },
    topic: topic,
  };

  await admin.messaging().send(message);
}

// Exemple: notifier un défi
sendToUser(
  'user_fcm_token',
  'Nouveau défi !',
  'Alex vous défie en mode Arcade !',
  { type: 'challenge', challengeId: '123' }
);
```

---

## Notifications In-App

### 1. Service de notifications In-App

```dart
// lib/services/in_app_notification_service.dart
import 'package:flutter/material.dart';

enum NotificationType { success, warning, error, info, achievement }

class InAppNotification {
  final String title;
  final String? message;
  final NotificationType type;
  final Duration duration;
  final VoidCallback? onTap;
  final IconData? icon;

  const InAppNotification({
    required this.title,
    this.message,
    this.type = NotificationType.info,
    this.duration = const Duration(seconds: 3),
    this.onTap,
    this.icon,
  });
}

class InAppNotificationService {
  static final InAppNotificationService instance = InAppNotificationService._();
  InAppNotificationService._();

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  OverlayEntry? _currentOverlay;

  BuildContext? get _context => navigatorKey.currentContext;

  /// Afficher une notification en haut de l'écran
  void show(InAppNotification notification) {
    if (_context == null) return;

    // Fermer la notification précédente
    _currentOverlay?.remove();

    _currentOverlay = OverlayEntry(
      builder: (context) => _NotificationWidget(
        notification: notification,
        onDismiss: () {
          _currentOverlay?.remove();
          _currentOverlay = null;
        },
      ),
    );

    Overlay.of(_context!)?.insert(_currentOverlay!);

    // Auto-dismiss
    Future.delayed(notification.duration, () {
      _currentOverlay?.remove();
      _currentOverlay = null;
    });
  }

  /// Raccourcis
  void showSuccess(String title, {String? message}) {
    show(InAppNotification(
      title: title,
      message: message,
      type: NotificationType.success,
      icon: Icons.check_circle,
    ));
  }

  void showError(String title, {String? message}) {
    show(InAppNotification(
      title: title,
      message: message,
      type: NotificationType.error,
      icon: Icons.error,
    ));
  }

  void showAchievement(String title, {String? message}) {
    show(InAppNotification(
      title: title,
      message: message,
      type: NotificationType.achievement,
      icon: Icons.emoji_events,
      duration: const Duration(seconds: 4),
    ));
  }

  void showInfo(String title, {String? message}) {
    show(InAppNotification(
      title: title,
      message: message,
      type: NotificationType.info,
      icon: Icons.info,
    ));
  }
}

class _NotificationWidget extends StatefulWidget {
  final InAppNotification notification;
  final VoidCallback onDismiss;

  const _NotificationWidget({
    required this.notification,
    required this.onDismiss,
  });

  @override
  State<_NotificationWidget> createState() => _NotificationWidgetState();
}

class _NotificationWidgetState extends State<_NotificationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(_controller);

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _getColor() {
    switch (widget.notification.type) {
      case NotificationType.success:
        return Colors.green;
      case NotificationType.warning:
        return Colors.orange;
      case NotificationType.error:
        return Colors.red;
      case NotificationType.achievement:
        return Colors.amber;
      case NotificationType.info:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: () {
                widget.notification.onTap?.call();
                widget.onDismiss();
              },
              onHorizontalDragEnd: (_) => widget.onDismiss(),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _getColor(),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: _getColor().withOpacity(0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    if (widget.notification.icon != null) ...[
                      Icon(
                        widget.notification.icon,
                        color: Colors.white,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.notification.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          if (widget.notification.message != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              widget.notification.message!,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: widget.onDismiss,
                      icon: const Icon(Icons.close, color: Colors.white70),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

### 2. Utilisation des notifications In-App

```dart
// Dans main.dart
void main() {
  runApp(MaterialApp(
    navigatorKey: InAppNotificationService.instance.navigatorKey,
    home: MyHomePage(),
  ));
}

// Exemples d'utilisation
class GameNotifications {
  final _notif = InAppNotificationService.instance;

  void onVictory() {
    _notif.showSuccess('Victoire !', message: 'Vous avez gagné la partie');
  }

  void onDefeat() {
    _notif.showError('Défaite', message: 'Le bot a gagné cette manche');
  }

  void onNewHighScore(int score) {
    _notif.showAchievement(
      'Nouveau Record !',
      message: 'Score : $score victoires',
    );
  }

  void onLevelUp(String difficulty) {
    _notif.showInfo(
      'Niveau supérieur',
      message: 'Difficulté : $difficulty',
    );
  }

  void onUnlock(String achievement) {
    _notif.show(InAppNotification(
      title: 'Succès débloqué !',
      message: achievement,
      type: NotificationType.achievement,
      icon: Icons.star,
      duration: const Duration(seconds: 5),
    ));
  }
}
```

---

## Implémentation recommandée

### Scénarios de notifications pour CheckGames

| Scénario | Type | Implémentation |
|----------|------|----------------|
| Victoire/Défaite | In-App | Immédiat pendant le jeu |
| Nouveau high score | In-App + Local | Célébration + sauvegarde |
| Rappel quotidien | Local | Programmé à heure fixe |
| Défi multijoueur | Push | Depuis le serveur |
| Bonus disponible | Local | Programmé après X heures |
| Ami en ligne | Push | Temps réel via FCM |
| Récompense débloquée | In-App | Pendant le jeu |

### Architecture recommandée

```
lib/
├── services/
│   ├── notification_service.dart      # Service unifié
│   ├── local_notification_service.dart
│   ├── push_notification_service.dart
│   └── in_app_notification_service.dart
```

### Service unifié

```dart
// lib/services/notification_service.dart
class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final _local = LocalNotificationService.instance;
  final _push = PushNotificationService.instance;
  final _inApp = InAppNotificationService.instance;

  Future<void> init() async {
    await _local.init();
    await _push.init();
    await _local.requestPermission();
  }

  // Victoire
  void notifyVictory({required int winStreak, bool isHighScore = false}) {
    _inApp.showSuccess('Victoire !', message: 'Série : $winStreak');

    if (isHighScore) {
      _inApp.showAchievement('Nouveau Record !');
      _local.showNotification(
        id: 1,
        title: 'Nouveau Record !',
        body: 'Série de $winStreak victoires !',
      );
    }
  }

  // Défaite
  void notifyDefeat() {
    _inApp.showError('Partie terminée');
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

  // Désactiver le rappel
  void cancelDailyReminder() {
    _local.cancelNotification(100);
  }
}
```

### Initialisation dans main.dart

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase (si utilisé)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Notifications
  await NotificationService.instance.init();

  runApp(MaterialApp(
    navigatorKey: InAppNotificationService.instance.navigatorKey,
    home: MainMenuScreen(),
  ));
}
```

---

## Checklist d'implémentation

- [ ] Ajouter les dépendances dans `pubspec.yaml`
- [ ] Configurer Android (`AndroidManifest.xml`)
- [ ] Configurer iOS (`Info.plist`)
- [ ] Créer `LocalNotificationService`
- [ ] Créer `InAppNotificationService`
- [ ] (Optionnel) Créer `PushNotificationService` pour le multijoueur
- [ ] Créer `NotificationService` unifié
- [ ] Initialiser dans `main.dart`
- [ ] Intégrer aux événements du jeu (victoire, défaite, records)
- [ ] Ajouter option de rappel dans les paramètres
- [ ] Tester sur Android et iOS

---

## Ressources

- [flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications)
- [firebase_messaging](https://pub.dev/packages/firebase_messaging)
- [Documentation Firebase Cloud Messaging](https://firebase.google.com/docs/cloud-messaging)
