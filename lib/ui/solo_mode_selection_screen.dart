import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../Bloc/checkgames_bloc.dart';
import '../Bloc/checkgames_event.dart';
import '../Bloc/checkgames_state.dart';
import '../repository/checkgame_repository.dart';
import '../services/audio_service.dart';
import '../services/game_settings_service.dart';
import '../services/arcade_leaderboard_service.dart';
import '../services/survival_leaderboard_service.dart';
import 'game_page.dart';
import 'arcade_mode_screen.dart';
import 'survival_mode_screen.dart';

class SoloModeSelectionScreen extends StatelessWidget {
  final CheckgameRepository repository;

  const SoloModeSelectionScreen({super.key, required this.repository});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF145A32), Color(0xFF0B3D2E)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        AudioService.instance.playButtonClick();
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                    ),
                    const Expanded(
                      child: Text(
                        'MODE SOLO',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Choisissez votre mode de jeu',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // Modes de jeu
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      // Mode Normal
                      _SoloModeCard(
                        icon: Icons.play_circle_filled,
                        title: 'Partie Rapide',
                        subtitle: 'Mode classique',
                        description: 'Une partie simple contre l\'ordinateur. Parfait pour s\'entraîner ou jouer rapidement.',
                        color: Colors.green.shade700,
                        onTap: () {
                          AudioService.instance.playButtonClick();
                          _startNormalGame(context);
                        },
                      ),

                      const SizedBox(height: 20),

                      // Mode Arcade
                      _SoloModeCard(
                        icon: Icons.local_fire_department,
                        title: 'Mode Arcade',
                        subtitle: 'Enchaînez les victoires !',
                        description: 'Gagnez un maximum de parties d\'affilée et inscrivez votre nom au classement !',
                        color: Colors.orange.shade700,
                        onTap: () {
                          AudioService.instance.playButtonClick();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ArcadeModeScreen(repository: repository),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 20),

                      // Mode Survie
                      _SoloModeCard(
                        icon: Icons.timer,
                        title: 'Mode Survie',
                        subtitle: 'Temps limité !',
                        description: 'Jouez contre la montre ! Difficulté croissante à chaque manche.',
                        color: Colors.cyan.shade700,
                        badge: 'NOUVEAU',
                        onTap: () {
                          AudioService.instance.playButtonClick();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SurvivalModeScreen(repository: repository),
                            ),
                          );
                        },
                      ),

                      const Spacer(),

                      // Afficher les meilleurs scores
                      FutureBuilder<List<int>>(
                        future: Future.wait([
                          ArcadeLeaderboardService.instance.getBestScore(),
                          SurvivalLeaderboardService.instance.getBestScore(),
                        ]),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const SizedBox.shrink();

                          final arcadeScore = snapshot.data![0];
                          final survivalScore = snapshot.data![1];

                          if (arcadeScore == 0 && survivalScore == 0) {
                            return const SizedBox.shrink();
                          }

                          return Column(
                            children: [
                              if (arcadeScore > 0)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.amber.withOpacity(0.4)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.local_fire_department, color: Colors.orange, size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Arcade : $arcadeScore victoires',
                                        style: const TextStyle(
                                          color: Colors.amber,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (survivalScore > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.cyan.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.cyan.withOpacity(0.4)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.timer, color: Colors.cyan, size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Survie : $survivalScore manches',
                                        style: const TextStyle(
                                          color: Colors.cyan,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startNormalGame(BuildContext context) {
    final playerNames = GameSettingsService.instance.generatePlayerNames();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider<Bloc<CheckgamesEvent, CheckgamesState>>(
          create: (_) => CheckGameBloc(repository: repository)
            ..add(StartGame(playerNames)),
          child: const GamePage(),
        ),
      ),
    );
  }
}

class _SoloModeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String description;
  final Color color;
  final String? badge;
  final VoidCallback onTap;

  const _SoloModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.color,
    this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, color.withOpacity(0.7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.4),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Badge
              if (badge != null)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      badge!,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

              Row(
                children: [
                  // Icône
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 40, color: Colors.white),
                  ),

                  const SizedBox(width: 20),

                  // Textes
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.9),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          description,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.8),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.white.withOpacity(0.7),
                    size: 20,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
