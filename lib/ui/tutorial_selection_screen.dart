import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import 'tutorial_screen.dart';
import 'tutorial_video_screen.dart';
import 'tutorial_interactive_screen.dart';

class TutorialSelectionScreen extends StatelessWidget {
  const TutorialSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
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
                        'TUTORIEL',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48), // Pour équilibrer le bouton retour
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Sous-titre
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Choisissez votre méthode d\'apprentissage',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // Modes de tutoriel
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      // Mode 1: Slides
                      _TutorialModeCard(
                        icon: Icons.slideshow,
                        title: 'Mode Slides',
                        subtitle: 'Apprenez à votre rythme',
                        description: 'Parcourez les règles page par page avec des illustrations et des exemples visuels.',
                        color: const Color(0xFF4CAF50),
                        onTap: () {
                          AudioService.instance.playButtonClick();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const TutorialScreen(),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 16),

                      // Mode 2: Vidéos
                      _TutorialModeCard(
                        icon: Icons.play_circle_filled,
                        title: 'Mode Vidéo',
                        subtitle: 'Regardez et apprenez',
                        description: 'Des vidéos explicatives pour comprendre rapidement les mécaniques du jeu.',
                        color: const Color(0xFFE91E63),
                        onTap: () {
                          AudioService.instance.playButtonClick();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const TutorialVideoScreen(),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 16),

                      // Mode 3: Interactif
                      _TutorialModeCard(
                        icon: Icons.sports_esports,
                        title: 'Mode Interactif',
                        subtitle: 'Pratiquez en jouant',
                        description: 'Un tutoriel guidé où vous jouez de vraies situations pour maîtriser le jeu.',
                        color: const Color(0xFFFF9800),
                        badge: 'Recommandé',
                        onTap: () {
                          AudioService.instance.playButtonClick();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const TutorialInteractiveScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // Footer
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Vous pouvez revenir au tutoriel à tout moment\ndepuis le menu principal',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TutorialModeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String description;
  final Color color;
  final String? badge;
  final VoidCallback onTap;

  const _TutorialModeCard({
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
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withOpacity(0.9),
                  color.withOpacity(0.7),
                ],
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
                // Badge si présent
                if (badge != null)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        badge!,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ),
                  ),

                // Contenu
                Row(
                  children: [
                    // Icône
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icon,
                        size: 36,
                        color: Colors.white,
                      ),
                    ),

                    const SizedBox(width: 16),

                    // Textes
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 20,
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

                    // Flèche
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
      ),
    );
  }
}
