import 'package:flutter/material.dart';

enum CardSuit {
  hearts,
  diamonds,
  clubs,
  spades ,
  jokerRed,
  jokerBlack
}

extension CardSuitSymbol on CardSuit {
  String get symbol {
    switch (this) {
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
  bool get isRed =>
      this == CardSuit.hearts || this == CardSuit.diamonds || this == CardSuit.jokerRed;

  bool get isBlack =>
      this == CardSuit.clubs || this == CardSuit.spades || this == CardSuit.jokerBlack;
}
