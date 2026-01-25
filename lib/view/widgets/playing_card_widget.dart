import 'package:flutter/material.dart';
import '../../models/playing_card.dart';
import '../../models/card_suit.dart';
import '../../models/card_value.dart';

class PlayingCardWidget extends StatelessWidget {
  final PlayingCard card;
  final double width;
  final VoidCallback? onTap;
  final bool selectedFlag;

  const PlayingCardWidget({
    super.key,
    required this.card,
    this.width = 84,
    bool? selected,
    bool? isSelected,
    this.onTap,
  }) : selectedFlag = selected ?? isSelected ?? false;

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

    final isJoker = card.suit == CardSuit.jokerRed || card.suit == CardSuit.jokerBlack;
    final cardBackground = isJoker
        ? (card.suit == CardSuit.jokerRed ? Colors.red.shade50 : Colors.grey.shade100)
        : Colors.white;

    final borderColor = selectedFlag
        ? const Color(0xFF0E766E)
        : (isJoker
        ? (card.suit == CardSuit.jokerRed ? Colors.red.shade300 : Colors.grey.shade400)
        : Colors.black12);
    final borderWidth = selectedFlag ? 3.0 : (isJoker ? 2.0 : 1.0);

    // 1. Définition du visuel de la carte (le rectangle blanc)
    final cardVisual = Container(
      width: width,
      height: h,
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: [
          BoxShadow(
            blurRadius: selectedFlag ? 14 : 8,
            color: Colors.black26,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: 8, top: 6,
            child: Text(valueLabel(card.value),
                style: TextStyle(fontSize: 16, color: color, fontWeight: FontWeight.bold)),
          ),
          Positioned(
            left: 10, top: 24,
            child: Text(suitSymbol(card.suit), style: TextStyle(fontSize: 16, color: color)),
          ),
          Center(
            child: Text(
              valueLabel(card.value) == 'JOKER' ? '🃏' : suitSymbol(card.suit),
              style: TextStyle(
                fontSize: valueLabel(card.value) == 'JOKER' ? 44 : 36,
                color: color,
              ),
            ),
          ),
          Positioned(
            right: 8, bottom: 6,
            child: Text(valueLabel(card.value),
                style: TextStyle(fontSize: 16, color: color, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    // 2. Gestion du Drag and Drop et du Tap
    return Draggable<List<PlayingCard>>(
      // On envoie une liste car le jeu accepte les coups doubles
      data: [card],

      // Ce qui suit le doigt
      feedback: Material(
        color: Colors.transparent,
        child: Opacity(
          opacity: 0.8,
          child: cardVisual,
        ),
      ),

      // Ce qui reste en main pendant qu'on glisse
      childWhenDragging: Opacity(
        opacity: 0.4,
        child: cardVisual,
      ),

      // Le widget interactif normal
      child: GestureDetector(
        onTap: onTap,
        child: cardVisual,
      ),
    );
  }
}