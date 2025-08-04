import '../models/playing_card.dart';
import '../models/card_value.dart';
import '../models/card_suit.dart';

class RuleEngine {
  static bool canPlayCard({
    /// Vérifie si une carte peut être jouée sur une autre
    required PlayingCard cardToPlay,
    required PlayingCard topCard,
    CardSuit? imposedSuit,
  }) {
    if (cardToPlay.value == CardValue.two) {
      return true;

      /// Vérifie si une carte peut être jouée sur une autre
    }

    /// S'il y a une couleur imposée (par le J précédent)
    if (imposedSuit != null
        && cardToPlay.suit == imposedSuit)
      return true;

    /// sinon : même valeur ou même couleur
    return cardToPlay.suit == topCard.suit || cardToPlay.value == topCard.value;
  }

  /// Vérifie si une carte a un effet spécial
  static bool hasSpecialEffect(PlayingCard card) {
    return [
      CardValue.ace,
      CardValue.seven,
      CardValue.joker,
      CardValue.two,
      CardValue.jack,
    ].contains(card.value);
  }

  /// Retourne l'effet de la carte (sous forme d'action a aplliquer )
  static SpecialEffect? getEffect(PlayingCard card) {
    switch (card.value) {
      case CardValue.ace:
        return SpecialEffect.skipNextPlayer;
      case CardValue.seven:
        return SpecialEffect.drawTwo;
      case CardValue.joker:
        return SpecialEffect.drawFour;
      case CardValue.jack:
        return SpecialEffect.imposeColor;
      case CardValue.two:
        return SpecialEffect.wildcard;
      default:
        return null;
    }
    }

  static bool playerHasPlayableCard({
    required List<PlayingCard> hand,
    required PlayingCard topCard,
    CardSuit? imposedSuit,
  }) {
    return hand.any((card) => canPlayCard(
      cardToPlay: card,
      topCard: topCard,
      imposedSuit: imposedSuit,
    ));
  }

}
  enum SpecialEffect {
    skipNextPlayer,
    drawTwo,
    drawFour,
    imposeColor,
    wildcard,
}