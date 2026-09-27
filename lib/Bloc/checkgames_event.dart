import 'package:equatable/equatable.dart';
import '../models/card_suit.dart';
import '../models/playing_card.dart';

abstract class CheckgamesEvent extends Equatable {
  const CheckgamesEvent();

  @override
  List<Object?> get props => [];
}

class StartGame extends CheckgamesEvent{
  final List<String> playerNames;
  StartGame(this.playerNames);

  @override
  List<Object?> get props => [playerNames];
}


class DrawCard extends CheckgamesEvent{
  final String playerId;
  final int count;
  DrawCard({required this.playerId, this.count = 1});

  @override
  List<Object?> get props => [playerId, count];
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

  @override
  List<Object?> get props => [playerId, cards, imposedSuit, drawCount, skipNext];
}

class EndTurn extends CheckgamesEvent {
  final String playerId;
  const EndTurn({required this.playerId});

  @override
  List<Object?> get props => [playerId]; // Important pour Equatable
}
// Passe au joueur suivant


class RestartGame extends CheckgamesEvent{
  final bool keepPlayers;
  RestartGame({this.keepPlayers = true});

  @override
  List<Object?> get props => [keepPlayers];
}
// Redémarre une nouvelle partie

class BotActionRequested extends CheckgamesEvent {
  const BotActionRequested();

  @override
  List<Object?> get props => [];
}

class PlayerLeft extends CheckgamesEvent {
  final String playerId;
  const PlayerLeft(this.playerId);

  @override
  List<Object?> get props => [playerId];
}


class SetPaused extends CheckgamesEvent {
  final bool isPaused;
  const SetPaused(this.isPaused);

  @override
  List<Object?> get props => [isPaused];
}

// Event pour synchroniser l'état du jeu avec Firebase (multiplayer)
class SyncGameState extends CheckgamesEvent {
  final Map<String, dynamic> stateData;
  const SyncGameState(this.stateData);

  @override
  List<Object?> get props => [stateData];
}

// Événement spécifique pour initialiser un jeu multijoueur
class InitMultiplayerGame extends CheckgamesEvent {
  final List<String> playerNames;
  const InitMultiplayerGame(this.playerNames);

  @override
  List<Object?> get props => [playerNames];
}