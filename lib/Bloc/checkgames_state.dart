import '../models/playing_card.dart';
import '../models/player_card.dart';
import '../models/card_suit.dart';

enum GamePhase {normal, duel, finished}

class CheckgamesState {
  final List<Player> players;
  final bool saveError;
  final int currentPlayerIndex;
  final List<PlayingCard> drawPile;
  final List<PlayingCard> discardPile;
  final bool isGameOver;
  final bool shouldWaitForResponse; // attendre avant de passer au suivant

  // Effets spéciaux actifs
  final int skipCount;            // nombre de joueurs à sauter
  final int cardsToDraw;          // cartes à piocher par le suivant
  final CardSuit? imposedSuit;  // couleur imposée par un Valet

  final GamePhase phase;
  final List<String> finishingOrder;
  final String? lastChecksPlayerId;  // ID du dernier joueur qui a dit "CHECKS"
  final bool isPaused; // Jeu en pause (pendant affichage de CHECKS par exemple)
  final String? errorMessage; // Message d'erreur pour les manœuvres invalides
  final int? previousPlayerIndex;  // Index du joueur qui vient de jouer (avant changement de tour)
  final String? lastDrawPlayerId;  // Joueur qui vient de piocher (reset à null après consommation)
  final int lastDrawCount;         // Nombre de cartes piochées (0 par défaut)

  const CheckgamesState({
    this.players = const [],
    this.currentPlayerIndex = 0,
    this.drawPile = const [],
    this.discardPile = const [],
    this.isGameOver = false,
    this.skipCount = 0,
    this.cardsToDraw = 0,
    this.imposedSuit,
    this.shouldWaitForResponse = false,
    this.phase = GamePhase.normal,
    this.finishingOrder = const<String>[],
    this.lastChecksPlayerId,
    this.isPaused = false,
    this.errorMessage,
    this.saveError = false,
    this.previousPlayerIndex,
    this.lastDrawPlayerId,
    this.lastDrawCount = 0,
  });

  static const Object _sentinel = Object();

  Player? get currentPlayer =>
      players.isNotEmpty &&
      currentPlayerIndex >= 0 &&
      currentPlayerIndex < players.length
          ? players[currentPlayerIndex]
          : null;

  bool isPlayerTurn(String playerId) {
    final player = currentPlayer;
    return player != null && player.id == playerId;
  }

  CheckgamesState copyWith({
    List<Player>? players,
    int? currentPlayerIndex,
    List<PlayingCard>? drawPile,
    List<PlayingCard>? discardPile,
    bool? isGameOver,
    int? skipCount,
    int? cardsToDraw,
    bool? shouldWaitForResponse,
    bool? saveError,
    //CardSuit? imposedSuit,
    Object? imposedSuit = _sentinel,
    GamePhase? phase,
    List<String>? finishingOrder,
    Object? lastChecksPlayerId = _sentinel,
    bool? isPaused,
    Object? errorMessage = _sentinel,
    Object? previousPlayerIndex = _sentinel,
    Object? lastDrawPlayerId = _sentinel,
    int? lastDrawCount,
  }) {
    final CardSuit? nextImposed = identical(imposedSuit, _sentinel)
        ? this.imposedSuit
        : imposedSuit as CardSuit?;

    final String? nextChecksPlayerId = identical(lastChecksPlayerId, _sentinel)
        ? this.lastChecksPlayerId
        : lastChecksPlayerId as String?;

    final String? nextErrorMessage = identical(errorMessage, _sentinel)
        ? this.errorMessage
        : errorMessage as String?;

    final int? nextPreviousPlayerIndex = identical(previousPlayerIndex, _sentinel)
        ? this.previousPlayerIndex
        : previousPlayerIndex as int?;

    final String? nextLastDrawPlayerId = identical(lastDrawPlayerId, _sentinel)
        ? this.lastDrawPlayerId
        : lastDrawPlayerId as String?;

    return CheckgamesState(
      players: players ?? this.players,
      currentPlayerIndex: currentPlayerIndex ?? this.currentPlayerIndex,
      drawPile: drawPile ?? this.drawPile,
      discardPile: discardPile ?? this.discardPile,
      isGameOver: isGameOver ?? this.isGameOver,
      skipCount: skipCount ?? this.skipCount,
      cardsToDraw: cardsToDraw ?? this.cardsToDraw,
      imposedSuit: nextImposed,
      phase: phase ?? this.phase,
      finishingOrder: finishingOrder ?? this.finishingOrder,
      shouldWaitForResponse: shouldWaitForResponse ?? this.shouldWaitForResponse,
      lastChecksPlayerId: nextChecksPlayerId,
      isPaused: isPaused ?? this.isPaused,
      errorMessage: nextErrorMessage,
      saveError: saveError ?? this.saveError,
      previousPlayerIndex: nextPreviousPlayerIndex,
      lastDrawPlayerId: nextLastDrawPlayerId,
      lastDrawCount: lastDrawCount ?? this.lastDrawCount,
    );
  }
}
