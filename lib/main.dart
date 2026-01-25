import 'dart:io' show Platform;
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

Future<void> main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Firebase is only supported on Android, iOS, and Web
  // Skip initialization on Windows/Linux/macOS desktop platforms
  if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e) {
      print('Erreur Firebase: $e');
    }
  } else {
    print('Firebase skipped on desktop platform (${Platform.operatingSystem})');
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

  // Initialiser les paramètres du jeu
  await GameSettingsService.instance.init();

  // Appliquer les paramètres audio
  final settings = GameSettingsService.instance;
  AudioService.instance.setSoundEnabled(settings.soundEnabled);
  AudioService.instance.loadMusicFromSettings(); // Charger la musique sélectionnée
  AudioService.instance.setMusicEnabled(settings.musicEnabled);

  // Retirer le splash screen
  FlutterNativeSplash.remove();

  runApp(MyApp(repository: repository));
}

class MyApp extends StatelessWidget {
  final CheckgameRepository repository;

  const MyApp({super.key, required this.repository});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'checkgames',
      theme: AppTheme.lightTheme,
      home: SplashScreen(nextScreen: MainMenuScreen(repository: repository)),
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
