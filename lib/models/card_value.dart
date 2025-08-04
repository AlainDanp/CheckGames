enum CardValue {
  ace,
  two,
  three,
  four,
  five,
  six,
  seven,
  eight,
  nine,
  ten,
  jack,
  queen,
  king,
  joker
}

extension CardValueLabel on CardValue {
  String get label {
    switch (this) {
      case CardValue.ace: return 'A';
      case CardValue.two: return '2';
      case CardValue.three: return '3';
      case CardValue.four: return '4';
      case CardValue.five: return '5';
      case CardValue.six: return '6';
      case CardValue.seven: return '7';
      case CardValue.eight: return '8';
      case CardValue.nine: return '9';
      case CardValue.ten: return '10';
      case CardValue.jack: return 'J';
      case CardValue.queen: return 'Q';
      case CardValue.king: return 'K';
      case CardValue.joker: return 'JOKER';
    }
  }
}
