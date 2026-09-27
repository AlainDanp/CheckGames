import 'dart:io' show Platform;
import 'dart:math';
import 'utils/app_logger.dart';

import 'package:checkgame/services/in_app_notification_service.dart';
import 'package:checkgame/services/local_notification_service.dart';
import 'package:checkgame/services/notification_service.dart';

import 'package:checkgame/ui/solo_mode_selection_screen.dart';
import 'package:checkgame/ui/arcade_mode_screen.dart';
import 'package:checkgame/ui/survival_mode_screen.dart';

import 'package:flutter/foundation.dart' show kIsWeb, PlatformDispatcher;
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
import 'ui/onboarding_screen.dart';

import 'repository/checkgame_repository.dart';
import 'theme/app_theme.dart';
import 'utils/page_transitions.dart';
import 'services/game_settings_service.dart';
import 'services/audio_service.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

import 'firebase_options.dart';

import 'package:shared_preferences/shared_preferences.dart';


Future<void> main() async {
  final WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Crashlytics: erreurs Flutter
  FlutterError.onError = (errorDetails) {
    FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
  };

  // Crashlytics: erreurs async
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  // Initialiser Firebase uniquement sur mobile
  final bool isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
  bool firebaseOk = false;

  if (isMobile) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      firebaseOk = true;
    } catch (e) {
      appLogger.e('Erreur initialisation Firebase', error: e);
    }
  } else {
    appLogger.d('Firebase ignoré sur cette plateforme');
  }

  // Initialiser les notifications uniquement sur mobile
  if (isMobile) {
    try {
      await LocalNotificationService.instance.init();
      await LocalNotificationService.instance.requestPermission();
      await NotificationService.instance.init();

      // Programmer les rappels toutes les 2h
      await LocalNotificationService.instance.setupPeriodicReminders();
    } catch (e) {
      appLogger.e('Erreur initialisation notifications', error: e);
    }
  }

  // Autoriser orientations portrait + paysage
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Initialiser le repository
  final repository = CheckgameRepository();
  await repository.init();

  // Initialiser paramètres du jeu
  await GameSettingsService.instance.init();

  // Appliquer paramètres audio
  final settings = GameSettingsService.instance;
  AudioService.instance.setSoundEnabled(settings.soundEnabled);
  AudioService.instance.loadMusicFromSettings();
  AudioService.instance.setMusicEnabled(settings.musicEnabled);

  FlutterNativeSplash.remove();

  runApp(MyApp(repository: repository, firebaseAvailable: firebaseOk));
}


class MyApp extends StatefulWidget {
  final CheckgameRepository repository;
  final bool firebaseAvailable;

  const MyApp({super.key, required this.repository, this.firebaseAvailable = true});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    InAppNotificationService.instance.navigatorKey = _navigatorKey;
    LocalNotificationService.onNotificationTap = _handleNotificationTap;
  }

  void _handleNotificationTap(String payload) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navigator = _navigatorKey.currentState;
      if (navigator == null) return;

      switch (payload) {
        case 'solo':
          navigator.push(
            MaterialPageRoute(
              builder: (_) => SoloModeSelectionScreen(repository: widget.repository),
            ),
          );
          break;

        case 'arcade':
          navigator.push(
            MaterialPageRoute(
              builder: (_) => ArcadeModeScreen(repository: widget.repository),
            ),
          );
          break;

        case 'survival':
          navigator.push(
            MaterialPageRoute(
              builder: (_) => SurvivalModeScreen(repository: widget.repository),
            ),
          );
          break;

        case 'random':
          final modes = ['solo', 'arcade', 'survival'];
          final randomMode = modes[Random().nextInt(modes.length)];
          _handleNotificationTap(randomMode);
          break;

        default:
          navigator.push(
            MaterialPageRoute(
              builder: (_) => SoloModeSelectionScreen(repository: widget.repository),
            ),
          );
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      LocalNotificationService.instance.refreshPeriodicReminders();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'checkgames',
      theme: AppTheme.lightTheme,
      builder: widget.firebaseAvailable
          ? null
          : (context, child) => Column(
        children: [
          MaterialBanner(
            content: const Text(
              'Mode hors-ligne — Le multijoueur est indisponible.',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: const Color(0xFFF57C00),
            actions: [
              TextButton(
                onPressed: () =>
                    ScaffoldMessenger.of(context).hideCurrentMaterialBanner(),
                child: const Text('OK', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
          Expanded(child: child ?? const SizedBox()),
        ],
      ),
      home: SplashScreen(
        nextScreen: StartupRouter(repository: widget.repository),
      ),

      onGenerateRoute: (settings) {
        // Menu principal (utilisé à la fin de l'onboarding)
        if (settings.name == '/main_menu') {
          return FadeRoute(page: MainMenuScreen(repository: widget.repository));
        }

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

        // Waiting room avec transition slide fade
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

/// Décide si on affiche l'onboarding ou le menu principal.
class StartupRouter extends StatelessWidget {
  final CheckgameRepository repository;
  const StartupRouter({super.key, required this.repository});

  Future<bool> _isOnboardingDone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('onboarding_completed') ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _isOnboardingDone(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final done = snapshot.data!;
        if (done) {
          return MainMenuScreen(repository: repository);
        }
        return OnboardingScreen();
      },
    );
  }
}
