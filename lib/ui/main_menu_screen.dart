import 'package:flutter/material.dart';
import '../repository/checkgame_repository.dart';
import 'auth_screen.dart';
import 'settings_screen.dart';
import 'tutorial_selection_screen.dart';
import 'solo_mode_selection_screen.dart';
import '../services/audio_service.dart';

class MainMenuScreen extends StatelessWidget {
  final CheckgameRepository repository;

  const MainMenuScreen({super.key, required this.repository});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF145A32), Color(0xFF0B3D2E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo/Titre du jeu
                  const Icon(
                    Icons.casino,
                    size: 80,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'CHECKGAMES',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 2,
                      shadows: [
                        Shadow(
                          blurRadius: 10.0,
                          color: Colors.black45,
                          offset: Offset(2, 2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Le jeu de cartes',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white70,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 60),

                  // Bouton Jouer Solo
                  _MenuButton(
                    icon: Icons.person,
                    label: 'JOUER SOLO',
                    subtitle: 'Affronter le CPU',
                    onPressed: () {
                      AudioService.instance.playButtonClick();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SoloModeSelectionScreen(repository: repository),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 20),

                  // Bouton Jouer en Ligne
                  _MenuButton(
                    icon: Icons.public,
                    label: 'JOUER EN LIGNE',
                    subtitle: 'Affronter des joueurs',
                    gradient: LinearGradient(
                      colors: [Colors.orange.shade700, Colors.orange.shade900],
                    ),
                    onPressed: () {
                      AudioService.instance.playButtonClick();
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => AuthScreen()),
                      );
                    },
                  ),

                  const SizedBox(height: 20),

                  // Bouton Tutoriel
                  _MenuButton(
                    icon: Icons.school,
                    label: 'TUTORIEL',
                    subtitle: 'Apprendre les règles',
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade600, Colors.blue.shade800],
                    ),
                    onPressed: () {
                      AudioService.instance.playButtonClick();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TutorialSelectionScreen(),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 30),

                  // Bouton Paramètres
                  TextButton.icon(
                    icon: const Icon(Icons.settings, color: Colors.white70),
                    label: const Text(
                      'Paramètres',
                      style: TextStyle(color: Colors.white70),
                    ),
                    onPressed: () {
                      AudioService.instance.playButtonClick();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SettingsScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onPressed;
  final Gradient? gradient;

  const _MenuButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onPressed,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 100,
      decoration: BoxDecoration(
        gradient: gradient ??
            LinearGradient(
              colors: [Colors.green.shade700, Colors.green.shade900],
            ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 48,
                  color: Colors.white,
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white70,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
