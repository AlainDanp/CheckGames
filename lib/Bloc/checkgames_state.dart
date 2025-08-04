import '../models/playing_card.dart';
import '../models/player_card.dart';
import '../models/card_suit.dart';
import '../models/card_value.dart';

class CheckgamesState {
  final List<Player> players;
  final int currentPlayerIndex;
  final List<PlayingCard> drawPile;
  final List<PlayingCard> discardPile;
  final bool isGameOver;

  // Effets spéciaux actifs
  final int skipCount;            // nombre de joueurs à sauter
  final int cardsToDraw;          // cartes à piocher par le suivant
  final CardSuit? imposedSuit;    // couleur imposée par un Valet

  const CheckgamesState({
    this.players = const [],
    this.currentPlayerIndex = 0,
    this.drawPile = const [],
    this.discardPile = const [],
    this.isGameOver = false,
    this.skipCount = 0,
    this.cardsToDraw = 0,
    this.imposedSuit,
  });

  Player? get currentPlayer =>
      players.isNotEmpty && currentPlayerIndex < players.length
          ? players[currentPlayerIndex]
          : null;

  bool isPlayerTurn(String playerId) =>
      players.isNotEmpty &&
          players[currentPlayerIndex].id == playerId;



  CheckgamesState copyWith({
    List<Player>? players,
    int? currentPlayerIndex,
    List<PlayingCard>? drawPile,
    List<PlayingCard>? discardPile,
    bool? isGameOver,
    int? skipCount,
    int? cardsToDraw,
    CardSuit? imposedSuit,
  }) {
    return CheckgamesState(
      players: players ?? this.players,
      currentPlayerIndex: currentPlayerIndex ?? this.currentPlayerIndex,
      drawPile: drawPile ?? this.drawPile,
      discardPile: discardPile ?? this.discardPile,
      isGameOver: isGameOver ?? this.isGameOver,
      skipCount: skipCount ?? this.skipCount,
      cardsToDraw: cardsToDraw ?? this.cardsToDraw,
      imposedSuit: imposedSuit ?? this.imposedSuit,
    );
  }
}
