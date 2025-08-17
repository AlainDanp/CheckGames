import '../models/card_suit.dart';
import '../models/playing_card.dart';

abstract class CheckgamesEvent{

}

class StartGame extends CheckgamesEvent{
  final List<String> playerNames;
  StartGame(this.playerNames);
}
// Démarre une partie avec certain nombres de jouers

class DrawCard extends CheckgamesEvent{
  final String playerId;
  final int count;
  DrawCard({required this.playerId, this.count = 1});
}
// un joueur pioche une carte

class PlayCard extends CheckgamesEvent {
  final String playerId;
  final List<PlayingCard> cards;
  final CardSuit? imposedSuit; // utilisé pour le Valet
  final int drawCount; // pour le 7 et jocker
  final bool skipNext; // pour le  A
  PlayCard({
    required this.playerId,
    required this.cards,
    this.imposedSuit,
    this.drawCount = 0,
    this.skipNext = false,
  });
}

class EndTurn extends CheckgamesEvent {
  EndTurn();
}
// Passe au joueur suivant


class RestartGame extends CheckgamesEvent{
  final bool keepPlayers;
  RestartGame({this.keepPlayers = true});
}
// Redémarre une nouvelle partie