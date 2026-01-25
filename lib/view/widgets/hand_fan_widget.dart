import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../models/playing_card.dart';
import '../../utils/responsive_sizing.dart';
import 'playing_card_widget.dart';

/// Widget qui affiche les cartes en éventail (comme une main de cartes)
class HandFanWidget extends StatelessWidget {
  final List<PlayingCard> cards;
  final Set<PlayingCard> selectedCards;
  final Function(PlayingCard) onCardTap;
  final bool enabled;
  final Map<PlayingCard, GlobalKey> cardKeys;

  const HandFanWidget({
    super.key,
    required this.cards,
    required this.selectedCards,
    required this.onCardTap,
    required this.enabled,
    required this.cardKeys,
  });

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) {
      return const SizedBox.shrink();
    }

    final sizing = context.sizing;
    final cardWidth = sizing.cardWidth;
    final cardHeight = sizing.cardHeight(cardWidth);

    // Paramètres de l'éventail
    final totalCards = cards.length;
    const maxAngle = 40.0; // Angle max de l'éventail en degrés (constant pour l'effet visuel)
    final fanRadius = sizing.fanRadius;

    // Espacement dynamique pour éviter le débordement d'écran
    // 95% de la largeur d'écran disponible pour les cartes
    final maxTotalWidth = sizing.screenWidth * 0.95;
    final cardSpacing = totalCards > 1
        ? ((maxTotalWidth - cardWidth) / (totalCards - 1))
            .clamp(30.0 * sizing.scaleFactor, sizing.fanCardSpacing)
        : 0.0;

    // Calculer l'angle pour chaque carte
    final angleStep = totalCards > 1 ? maxAngle / (totalCards - 1) : 0.0;
    final startAngle = -maxAngle / 2;

    // Calculer les dimensions nécessaires
    final totalWidth = (totalCards - 1) * cardSpacing + cardWidth;
    final maxHeight = cardHeight + 60 * sizing.scaleFactor; // Hauteur avec marge pour la rotation

    return SizedBox(
      width: totalWidth,
      height: maxHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (int i = 0; i < cards.length; i++)
            _buildCard(
              card: cards[i],
              index: i,
              totalCards: totalCards,
              cardWidth: cardWidth,
              cardHeight: cardHeight,
              startAngle: startAngle,
              angleStep: angleStep,
              fanRadius: fanRadius,
              cardSpacing: cardSpacing,
            ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required PlayingCard card,
    required int index,
    required int totalCards,
    required double cardWidth,
    required double cardHeight,
    required double startAngle,
    required double angleStep,
    required double fanRadius,
    required double cardSpacing,
  }) {
    final isSelected = selectedCards.contains(card);
    final angle = startAngle + (index * angleStep);
    final angleRad = angle * math.pi / 180;

    // Position horizontale (linéaire)
    final x = index * cardSpacing;

    // Position verticale (arc)
    // Les cartes au centre sont plus hautes
    final normalizedPos = (index - (totalCards - 1) / 2) / (totalCards / 2);
    final y = (normalizedPos * normalizedPos) * 30; // Courbe parabolique

    // Décalage vertical supplémentaire si la carte est sélectionnée (responsive)
    final selectedOffset = isSelected ? -20.0 * cardWidth / 84.0 : 0.0;

    return Positioned(
      left: x,
      top: y + selectedOffset,
      child: Transform.rotate(
        angle: angleRad,
        child: GestureDetector(
          key: cardKeys[card],
          onTap: enabled ? () => onCardTap(card) : null,
          child: PlayingCardWidget(
            card: card,
            isSelected: isSelected,
            width: cardWidth,
          ),
        ),
      ),
    );
  }
}
