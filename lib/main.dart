import 'dart:io' show Platform;
import 'dart:math';
import 'package:checkgame/services/in_app_notification_service.dart';
import 'package:checkgame/services/local_notification_service.dart';
import 'package:checkgame/services/notification_service.dart';
import 'package:checkgame/ui/solo_mode_selection_screen.dart';
import 'package:checkgame/ui/arcade_mode_screen.dart';
import 'package:checkgame/ui/survival_mode_screen.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import 'ui/main_menu_screen.dart';
import 'ui/auth_screen.dart';
import 'ui/multiplayer_lobby_screen.dart';
import 'ui/waiting_room_screen.dart';
import 'ui/multiplayer_game_page.dart';
import 'ui/profile_screen.dart';
import 'ui/splash_screen.dart';
import 'repository/checkgame_repository.dart';
import 'theme/app_theme.dart';
import 'utils/page_transitions.dart';
import 'services/game_settings_service.dart';
import 'services/audio_service.dart';

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

/// Clé globale pour la navigation
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Repository global pour les notifications
late CheckgameRepository globalRepository;

Future<void> main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Initialiser les notifications uniquement sur mobile
  final isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  if (isMobile) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e) {
      print('Erreur Firebase: $e');
    }
  } else {
    print('Firebase & Notifications skipped on ${Platform.operatingSystem}');
  }

  if (isMobile) {
    try {
      await LocalNotificationService.instance.init();
      await LocalNotificationService.instance.requestPermission();
      await NotificationService.instance.init();

      // Configurer le callback pour la navigation
      LocalNotificationService.onNotificationTap = _handleNotificationTap;

      // Programmer les rappels toutes les 2h
      await LocalNotificationService.instance.setupPeriodicReminders();
    } catch (e) {
      print('Erreur notifications: $e');
    }
  }

  // Permettre toutes les orientations (portrait et paysage)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Initialiser le repository
  final repository = CheckgameRepository();
  await repository.init();
  globalRepository = repository; // Stocker globalement pour les notifications

  // Initialiser les paramètres du jeu
  await GameSettingsService.instance.init();

  // Appliquer les paramètres audio
  final settings = GameSettingsService.instance;
  AudioService.instance.setSoundEnabled(settings.soundEnabled);
  AudioService.instance.loadMusicFromSettings(); // Charger la musique sélectionnée
  AudioService.instance.setMusicEnabled(settings.musicEnabled);

  // Retirer le splash screen
  FlutterNativeSplash.remove();

  // Assigner la clé de navigation aux services
  InAppNotificationService.instance.navigatorKey = navigatorKey;

  runApp(MyApp(repository: repository));
}

/// Gère le tap sur une notification et navigue vers le bon écran
void _handleNotificationTap(String payload) {
  // Attendre que le navigator soit prêt
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;

    switch (payload) {
      case 'solo':
        navigator.push(MaterialPageRoute(
          builder: (_) => SoloModeSelectionScreen(repository: globalRepository),
        ));
        break;

      case 'arcade':
        navigator.push(MaterialPageRoute(
          builder: (_) => ArcadeModeScreen(repository: globalRepository),
        ));
        break;

      case 'survival':
        navigator.push(MaterialPageRoute(
          builder: (_) => SurvivalModeScreen(repository: globalRepository),
        ));
        break;

      case 'random':
        // Choisir un mode aléatoire
        final modes = ['solo', 'arcade', 'survival'];
        final randomMode = modes[Random().nextInt(modes.length)];
        _handleNotificationTap(randomMode);
        break;

      default:
        // Par défaut, aller au menu solo
        navigator.push(MaterialPageRoute(
          builder: (_) => SoloModeSelectionScreen(repository: globalRepository),
        ));
    }
  });
}

class MyApp extends StatefulWidget {
  final CheckgameRepository repository;
  const MyApp({super.key, required this.repository});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Reprogrammer les rappels quand l'app revient au premier plan
    if (state == AppLifecycleState.resumed) {
      LocalNotificationService.instance.refreshPeriodicReminders();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Synchroniser la clé du navigator pour InAppNotificationService
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'checkgames',
      theme: AppTheme.lightTheme,
      home: SplashScreen(nextScreen: MainMenuScreen(repository: widget.repository)),
      onGenerateRoute: (settings) {
        // Auth screen avec transition fade
        if (settings.name == '/auth') {
          return FadeRoute(page: AuthScreen());
        }

        // Profile screen avec transition slide
        if (settings.name == '/profile') {
          return SlideRightRoute(page: const ProfileScreen());
        }

        // Lobby avec transition slide
        if (settings.name == '/lobby') {
          return SlideRightRoute(page: MultiplayerLobbyScreen());
        }

        // Waiting room avec transition slide + fade
        if (settings.name == '/waiting-room') {
          final args = settings.arguments as Map<String, dynamic>?;
          if (args != null) {
            return SlideAndFadeRoute(
              page: WaitingRoomScreen(
                roomId: args['roomId'] as String,
                roomCode: args['roomCode'] as String? ?? '',
                isHost: args['isHost'] as bool? ?? false,
              ),
            );
          }
        }

        // Multiplayer game avec transition scale
        if (settings.name == '/multiplayer-game') {
          final args = settings.arguments as Map<String, dynamic>?;
          if (args != null) {
            return ScaleRoute(
              page: MultiplayerGamePage(
                roomId: args['roomId'] as String,
              ),
            );
          }
        }
        return null;
      },
    );
  }
}
