enum CardSuit { hearts, diamonds, clubs, spades ,joker}

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
      case CardSuit.joker:
        return 'joker';
    }
  }
}
