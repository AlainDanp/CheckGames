import 'package:flutter/material.dart';
import '../../models/playing_card.dart';
import 'playing_card_widget.dart';

class AnimatedCardOverlay extends StatefulWidget {
  final List<PlayingCard> cards;
  final List<Offset> startPositions;
  final Offset endPosition;
  final Duration duration;
  final VoidCallback onComplete;

  const AnimatedCardOverlay({
    super.key,
    required this.cards,
    required this.startPositions,
    required this.endPosition,
    required this.duration,
    required this.onComplete,
  });

  @override
  State<AnimatedCardOverlay> createState() => _AnimatedCardOverlayState();
}

class _AnimatedCardOverlayState extends State<AnimatedCardOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<Animation<Offset>> _positionAnimations;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    // Animation pour chaque carte avec décalage temporel
    _positionAnimations = [];
    // Calculer le décalage max pour ne jamais dépasser 0.9 (laisser au moins 10% pour l'animation)
    final maxBegin = 0.7; // Maximum 70% de décalage pour la dernière carte
    final staggerPerCard = widget.cards.length > 1
        ? maxBegin / (widget.cards.length - 1)
        : 0.0;

    for (int i = 0; i < widget.cards.length; i++) {
      final start = widget.startPositions[i];
      final end = widget.endPosition;

      // Décalage progressif mais limité
      final begin = (i * staggerPerCard).clamp(0.0, maxBegin);
      final interval = Interval(begin, 1.0, curve: Curves.easeInOutCubic);

      _positionAnimations.add(
        Tween<Offset>(begin: start, end: end).animate(
          CurvedAnimation(parent: _controller, curve: interval),
        ),
      );
    }

    // Scale et rotation pour effet naturel plus dynamique
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutBack),
    );

    _rotationAnimation = Tween<double>(begin: 0, end: 0.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    // Animation d'opacité pour effet de "whoosh"
    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.3, curve: Curves.easeIn),
      ),
    );

    // Démarrer animation
    _controller.forward().then((_) => widget.onComplete());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          children: widget.cards.asMap().entries.map((entry) {
            final index = entry.key;
            final card = entry.value;
            final position = _positionAnimations[index].value;

            return Positioned(
              left: position.dx,
              top: position.dy,
              child: Opacity(
                opacity: _opacityAnimation.value,
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Transform.rotate(
                    angle: _rotationAnimation.value * (index % 2 == 0 ? 1 : -1),
                    child: Container(
                      decoration: BoxDecoration(
                        boxShadow: [
                          // Ombre dynamique pour effet de vitesse
                          BoxShadow(
                            color: Colors.black.withOpacity(0.4),
                            blurRadius: 20 * _controller.value,
                            spreadRadius: 2,
                            offset: Offset(
                              -10 * _controller.value,
                              5 * _controller.value,
                            ),
                          ),
                          // Glow effect
                          BoxShadow(
                            color: Colors.orange.withOpacity(0.3 * _controller.value),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: RepaintBoundary(
                        child: PlayingCardWidget(card: card, width: 84),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
