import 'package:flutter/material.dart';
import '../../models/playing_card.dart';
import '../../models/card_suit.dart';
import '../../models/card_value.dart';

class PlayingCardWidget extends StatelessWidget {
  final PlayingCard card;
  final bool big;

  const PlayingCardWidget({super.key, required this.card, this.big = false});

  @override
  Widget build(BuildContext context) {
    final size = big ? const Size(120, 160) : const Size(80, 110);
    final isRed = _isRedSuit(card.suit);

    return SizedBox(
      width: size.width,
      height: size.height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [BoxShadow(blurRadius: 6, offset: Offset(0, 2), color: Colors.black12)],
          border: Border.all(color: Colors.black12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: DefaultTextStyle(
            style: TextStyle(
              color: isRed ? Colors.red.shade700 : Colors.black87,
              fontFamily: 'monospace',
            ),
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: _Corner(rank: _rankLabel(card.value), suit: _suitSymbol(card.suit)),
                ),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Transform.rotate(
                    angle: 3.14159,
                    child: _Corner(rank: _rankLabel(card.value), suit: _suitSymbol(card.suit)),
                  ),
                ),
                Center(
                  child: Text(
                    _centerGlyph(card),
                    style: TextStyle(fontSize: big ? 56 : 40),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _rankLabel(CardValue v) {
    switch (v) {
      case CardValue.ace:
        return 'A';
      case CardValue.jack:
        return 'J';
      case CardValue.queen:
        return 'Q';
      case CardValue.king:
        return 'K';
      case CardValue.joker:
        return '🃏';
      default:
        return v.label; // suppose que tu as un label pour 3,4,5,... etc.
    }
  }

  String _suitSymbol(CardSuit s) {
    switch (s) {
      case CardSuit.hearts:
        return '♥';
      case CardSuit.diamonds:
        return '♦';
      case CardSuit.clubs:
        return '♣';
      case CardSuit.spades:
        return '♠';
      case CardSuit.jokerRed:
        return '🃏R';
      case CardSuit.jokerBlack:
        return '🃏B';
    }
  }

  String _centerGlyph(PlayingCard c) {
    if (c.value == CardValue.joker) {
      return c.suit == CardSuit.jokerRed ? '🃏' : '🃏';
    }
    return _suitSymbol(c.suit);
  }

  bool _isRedSuit(CardSuit s) {
    return s == CardSuit.hearts || s == CardSuit.diamonds || s == CardSuit.jokerRed;
  }
}

class _Corner extends StatelessWidget {
  final String rank;
  final String suit;
  const _Corner({required this.rank, required this.suit});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(rank, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        Text(suit, style: const TextStyle(fontSize: 18)),
      ],
    );
  }
}
