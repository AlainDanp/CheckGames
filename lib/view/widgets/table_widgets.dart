import 'package:flutter/material.dart';

import '../../models/playing_card.dart';
import '../../models/card_suit.dart';
import '../../models/card_value.dart';
import '../../models/player_card.dart';
import '../../utils/responsive_sizing.dart';

class CardBack extends StatelessWidget {
  const CardBack({super.key, this.width = 68});
  final double width;

  @override
  Widget build(BuildContext context) {
    final h = width * 1.45;
    return Container(
      width: width,
      height: h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          colors: [Color(0xFF0B6E4F), Color(0xFF074E3B)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white24, width: 2),
        boxShadow: const [BoxShadow(blurRadius: 8, color: Colors.black26, offset: Offset(0, 4))],
      ),
      child: const Center(child: Icon(Icons.casino, color: Colors.white70, size: 28)),
    );
  }
}

class DeckWidget extends StatelessWidget {
  const DeckWidget({super.key, required this.count, required this.enabled, required this.onTap});
  final int count;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Dimensionnement responsive pour la pile de pioche
    final sizing = context.sizing;
    final double cardW = sizing.tableCardWidth;
    final double w = cardW * 1.43; // marge proportionnelle pour le badge
    final double h = sizing.cardHeight(cardW) + 16 * sizing.scaleFactor;

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: SizedBox(
        width: w,
        height: h,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(left: 6, top: 6, child: CardBack(width: cardW)),
            Positioned(left: 12, top: 12, child: CardBack(width: cardW)),
            CardBack(width: cardW),
            Positioned(
              right: -6, bottom: -6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: enabled ? Colors.teal.shade700 : Colors.black45,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white24),
                ),
                child: Text('$count', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class DiscardWidget extends StatelessWidget {
  const DiscardWidget({
    super.key,
    required this.top,
    this.previousCards,
    this.onCardsDropped // Ajoutez ce callback
  });

  final PlayingCard top;
  final List<PlayingCard>? previousCards;
  final Function(List<PlayingCard>)? onCardsDropped; // Callback pour traiter l'action

  @override
  Widget build(BuildContext context) {
    final cardsToShow = <PlayingCard>[];

    if (previousCards != null && previousCards!.isNotEmpty) {
      final startIndex = (previousCards!.length - 3).clamp(0, previousCards!.length);
      cardsToShow.addAll(previousCards!.sublist(startIndex));
    }
    cardsToShow.add(top);

    final sizing = context.sizing;
    final cardWidth = sizing.tableCardWidth;
    final cardSpacing = 20.0 * sizing.scaleFactor;
    final totalWidth = cardWidth + (cardsToShow.length - 1) * cardSpacing;
    return DragTarget<List<PlayingCard>>(
      onWillAccept: (data) => true, // Vous pouvez ajouter une condition de tour ici
      onAccept: (cards) {
        if (onCardsDropped != null) {
          onCardsDropped!(cards);
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: isHovering ? const EdgeInsets.all(14) : EdgeInsets.zero,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: isHovering ? Colors.white.withOpacity(0.2) : Colors.transparent,
          ),
          child: SizedBox(
            width: totalWidth,
            height: cardWidth * 1.45,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (int i = 0; i < cardsToShow.length; i++)
                  Positioned(
                    left: i * cardSpacing,
                    child: _CardFront(card: cardsToShow[i], width: cardWidth),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CardFront extends StatelessWidget {
  const _CardFront({required this.card, this.width = 68});
  final PlayingCard card;
  final double width;

  @override
  Widget build(BuildContext context) {
    final h = width * 1.45;
    final isRed = card.suit == CardSuit.hearts ||
                  card.suit == CardSuit.diamonds ||
                  card.suit == CardSuit.jokerRed;
    final color = isRed ? Colors.red.shade700 : Colors.black87;

    String suitSymbol(CardSuit s) {
      switch (s) {
        case CardSuit.hearts: return '♥';
        case CardSuit.diamonds: return '♦';
        case CardSuit.clubs: return '♣';
        case CardSuit.spades: return '♠';
        case CardSuit.jokerRed: return '🃏';
        case CardSuit.jokerBlack: return '🃏';
      }
    }

    String valueLabel(CardValue v) {
      switch (v) {
        case CardValue.ace: return 'A';
        case CardValue.king: return 'K';
        case CardValue.queen: return 'Q';
        case CardValue.jack: return 'J';
        case CardValue.ten: return '10';
        case CardValue.nine: return '9';
        case CardValue.eight: return '8';
        case CardValue.seven: return '7';
        case CardValue.six: return '6';
        case CardValue.five: return '5';
        case CardValue.four: return '4';
        case CardValue.three: return '3';
        case CardValue.two: return '2';
        case CardValue.joker: return 'JOKER';
      }
    }

    // Fond spécial pour les jokers
    final isJoker = card.suit == CardSuit.jokerRed || card.suit == CardSuit.jokerBlack;
    final cardBackground = isJoker
        ? (card.suit == CardSuit.jokerRed
            ? Colors.red.shade50
            : Colors.grey.shade100)
        : Colors.white;
    final borderColor = isJoker
        ? (card.suit == CardSuit.jokerRed
            ? Colors.red.shade300
            : Colors.grey.shade400)
        : Colors.black12;

    return Container(
      width: width, height: h,
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: isJoker ? 2 : 1),
        boxShadow: const [BoxShadow(blurRadius: 8, color: Colors.black26, offset: Offset(0, 4))],
      ),
      child: Stack(
        children: [
          Positioned(left: 8, top: 6,
              child: Text(valueLabel(card.value), style: TextStyle(fontSize: 16, color: color, fontWeight: FontWeight.bold))),
          Positioned(left: 10, top: 24,
              child: Text(suitSymbol(card.suit), style: TextStyle(fontSize: 16, color: color))),
          Center(child: Text(
            valueLabel(card.value) == 'JOKER' ? '🃏' : suitSymbol(card.suit),
            style: TextStyle(fontSize: valueLabel(card.value) == 'JOKER' ? 44 : 36, color: color),
          )),
          Positioned(right: 8, bottom: 6,
              child: Text(valueLabel(card.value), style: TextStyle(fontSize: 16, color: color, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }
}

class OpponentsRow extends StatelessWidget {
  const OpponentsRow({
    super.key,
    required this.players,
    required this.myIndex,
    this.botCardKeys,
  });
  final List<Player> players;
  final int myIndex;
  final Map<String, GlobalKey>? botCardKeys; // Keys pour l'animation des cartes des bots

  @override
  Widget build(BuildContext context) {
    final opponents = <Player>[];
    for (var i = 0; i < players.length; i++) {
      if (i != myIndex) opponents.add(players[i]);
    }

    // Dimensionnement responsive pour les adversaires
    final sizing = context.sizing;
    final double backW = sizing.opponentCardWidth;
    final double spacing = sizing.opponentCardSpacing;

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 0,
      runSpacing: 8,
      children: opponents.map((p) {
        final n = p.hand.length;

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: sizing.opponentHorizontalPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Nom du joueur
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  p.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Cartes retournées
              Row(
                key: botCardKeys?[p.id], // Key pour localiser la position du bot
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (int i = 0; i < n.clamp(1, 5); i++)
                    Padding(
                      padding: EdgeInsets.only(left: i > 0 ? spacing : 0),
                      child: CardBack(width: backW),
                    ),
                ],
              ),

              const SizedBox(height: 8),

              // Badge avec le nombre de cartes
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.orange.shade700,
                      Colors.orange.shade900,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  '+$n',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
