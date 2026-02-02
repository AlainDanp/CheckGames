import 'package:flutter/material.dart';
import '../services/audio_service.dart';

class TutorialVideoScreen extends StatefulWidget {
  const TutorialVideoScreen({super.key});

  @override
  State<TutorialVideoScreen> createState() => _TutorialVideoScreenState();
}

class _TutorialVideoScreenState extends State<TutorialVideoScreen> {
  int _currentVideoIndex = 0;

  final List<TutorialVideo> _videos = [
    TutorialVideo(
      title: 'Introduction au jeu',
      description: 'Découvrez les bases de Checkgames et l\'objectif du jeu.',
      duration: '1:30',
      thumbnail: Icons.play_circle_outline,
      color: const Color(0xFF1565C0),
    ),
    TutorialVideo(
      title: 'Les règles de base',
      description: 'Comment jouer une carte : par couleur ou par valeur.',
      duration: '2:15',
      thumbnail: Icons.school,
      color: const Color(0xFF2E7D32),
    ),
    TutorialVideo(
      title: 'Le 2 - Carte passe-partout',
      description: 'Le 2 peut être joué sur n\'importe quelle carte !',
      duration: '0:45',
      thumbnail: Icons.all_inclusive,
      color: const Color(0xFF00796B),
    ),
    TutorialVideo(
      title: 'Les cartes spéciales',
      description: 'As, 7, Valet et Joker : leurs effets et stratégies.',
      duration: '3:00',
      thumbnail: Icons.auto_awesome,
      color: const Color(0xFF6A1B9A),
    ),
    TutorialVideo(
      title: 'Le système de cumul',
      description: 'Comment enchaîner les 7 et les Jokers pour des combos dévastateurs.',
      duration: '2:30',
      thumbnail: Icons.stacked_line_chart,
      color: const Color(0xFFEF6C00),
    ),
    TutorialVideo(
      title: 'Stratégies avancées',
      description: 'Conseils pour gagner plus souvent.',
      duration: '2:00',
      thumbnail: Icons.lightbulb,
      color: const Color(0xFFC62828),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF880E4F), Color(0xFF4A148C)],
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
                        'TUTORIEL VIDÉO',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
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

              // Lecteur vidéo (zone principale)
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildVideoPlayer(_videos[_currentVideoIndex]),
                ),
              ),

              const SizedBox(height: 16),

              // Titre et description de la vidéo courante
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    Text(
                      _videos[_currentVideoIndex].title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _videos[_currentVideoIndex].description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.8),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Liste des vidéos
              Expanded(
                flex: 2,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Column(
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(Icons.playlist_play, color: Colors.white70),
                            SizedBox(width: 8),
                            Text(
                              'Toutes les vidéos',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          itemCount: _videos.length,
                          itemBuilder: (context, index) {
                            final video = _videos[index];
                            final isSelected = index == _currentVideoIndex;

                            return _buildVideoListItem(video, index, isSelected);
                          },
                        ),
                      ),
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

  Widget _buildVideoPlayer(TutorialVideo video) {
    return Container(
      decoration: BoxDecoration(
        color: video.color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: video.color.withOpacity(0.5),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Fond avec icône
          Center(
            child: Icon(
              video.thumbnail,
              size: 80,
              color: Colors.white.withOpacity(0.3),
            ),
          ),

          // Bouton play
          Center(
            child: GestureDetector(
              onTap: () {
                AudioService.instance.playButtonClick();
                _showVideoNotAvailable();
              },
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 15,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.play_arrow,
                  size: 50,
                  color: video.color,
                ),
              ),
            ),
          ),

          // Durée
          Positioned(
            bottom: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.access_time, color: Colors.white, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    video.duration,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Numéro de la vidéo
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_currentVideoIndex + 1} / ${_videos.length}',
                style: TextStyle(
                  color: video.color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoListItem(TutorialVideo video, int index, bool isSelected) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            AudioService.instance.playButtonClick();
            setState(() {
              _currentVideoIndex = index;
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected
                  ? video.color.withOpacity(0.3)
                  : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: isSelected
                  ? Border.all(color: video.color, width: 2)
                  : null,
            ),
            child: Row(
              children: [
                // Numéro ou icône play
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isSelected ? video.color : Colors.white.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: isSelected
                        ? const Icon(Icons.play_arrow, color: Colors.white, size: 24)
                        : Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),

                const SizedBox(width: 12),

                // Infos
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        video.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : Colors.white70,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        video.duration,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                ),

                // Icône
                Icon(
                  video.thumbnail,
                  color: isSelected ? video.color : Colors.white30,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showVideoNotAvailable() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.video_library, color: Colors.purple),
            SizedBox(width: 12),
            Text('Bientôt disponible'),
          ],
        ),
        content: const Text(
          'Les vidéos tutorielles seront disponibles dans une prochaine mise à jour.\n\n'
          'En attendant, essayez le mode Slides ou le mode Interactif !',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class TutorialVideo {
  final String title;
  final String description;
  final String duration;
  final IconData thumbnail;
  final Color color;

  const TutorialVideo({
    required this.title,
    required this.description,
    required this.duration,
    required this.thumbnail,
    required this.color,
  });
}
