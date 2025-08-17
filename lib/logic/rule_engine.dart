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
    if (cardToPlay.value == CardValue.two) return true;

      bool isRed(CardSuit s) => s == CardSuit.hearts ||
          s == CardSuit.diamonds || s == CardSuit.jokerRed;
      bool isBlack(CardSuit s) => s == CardSuit.clubs ||
          s == CardSuit.spades || s == CardSuit.jokerBlack;

      // Joker (rouge/noir) à jouer
      if (cardToPlay.value == CardValue.joker) {
        // Sous imposition : respecter le groupe de couleur
        if (imposedSuit != null) {
          return (isRed(imposedSuit)  && cardToPlay.suit == CardSuit.jokerRed) ||
              (isBlack(imposedSuit) && cardToPlay.suit == CardSuit.jokerBlack);
        }

        // Sur un Joker : Joker tjrs autorisé (peu importe la couleur)
        if (topCard.value == CardValue.joker) return true;

        // Sans imposition : Joker rouge sur couleur rouge, noir sur couleur noire
        return (isRed(topCard.suit)  && cardToPlay.suit == CardSuit.jokerRed) ||
            (isBlack(topCard.suit) && cardToPlay.suit == CardSuit.jokerBlack);
      }
      // Carte normale à jouer sur un Joker au-dessus :
      if (topCard.value == CardValue.joker) {
        // Si le Joker du dessus est rouge : seules les cartes rouges (ou un 2) passent
        if (topCard.suit == CardSuit.jokerRed)  return isRed(cardToPlay.suit);
        // Si le Joker du dessus est noir : seules les cartes noires (ou un 2) passent
        if (topCard.suit == CardSuit.jokerBlack) return isBlack(cardToPlay.suit);
      }
      /// S'il y a une couleur imposée (par le J précédent)

      if (imposedSuit != null) {
        // Un Valet peut toujours se poser pour ré-imposer
        if (cardToPlay.value == CardValue.jack) return true;
        // Sinon, respecter la couleur imposée OU la même valeur que le dessus
        return cardToPlay.suit == imposedSuit || cardToPlay.value == topCard.value;
      }
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