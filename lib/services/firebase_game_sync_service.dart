import 'package:cloud_firestore/cloud_firestore.dart';
import '../Bloc/checkgames_state.dart';
import '../models/playing_card.dart';
import '../models/player_card.dart';
import '../models/card_suit.dart';
import '../models/card_value.dart';

class FirebaseGameSyncService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Sauvegarder l'état du jeu
  Future<void> saveGameState(String roomId, CheckgamesState state) async {
    final stateData = _serializeState(state);

    await _firestore
        .collection('game_rooms')
        .doc(roomId)
        .collection('game_state')
        .doc('current')
        .set(stateData);
  }

  // Enregistrer une action
  Future<void> recordAction({
    required String roomId,
    required String playerId,
    required String type,
    required Map<String, dynamic> data,
  }) async {
    await _firestore
        .collection('game_rooms')
        .doc(roomId)
        .collection('actions')
        .add({
      'playerId': playerId,
      'type': type,
      'data': data,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // Stream de l'état du jeu
  Stream<DocumentSnapshot> watchGameState(String roomId) {
    return _firestore
        .collection('game_rooms')
        .doc(roomId)
        .collection('game_state')
        .doc('current')
        .snapshots();
  }

  // Stream des actions
  Stream<QuerySnapshot> watchActions(String roomId) {
    return _firestore
        .collection('game_rooms')
        .doc(roomId)
        .collection('actions')
        .orderBy('timestamp')
        .snapshots();
  }

  // Sérialiser l'état du jeu
  Map<String, dynamic> _serializeState(CheckgamesState state) {
    return {
      'players': state.players.map((p) => {
        'id': p.id,
        'name': p.name,
        'hand': p.hand.map((c) => {
          'suit': c.suit.index,
          'value': c.value.index,
        }).toList(),
      }).toList(),
      'currentPlayerIndex': state.currentPlayerIndex,
      'drawPile': state.drawPile.map((c) => {
        'suit': c.suit.index,
        'value': c.value.index,
      }).toList(),
      'discardPile': state.discardPile.map((c) => {
        'suit': c.suit.index,
        'value': c.value.index,
      }).toList(),
      'skipCount': state.skipCount,
      'cardsToDraw': state.cardsToDraw,
      'imposedSuit': state.imposedSuit?.index,
      'phase': state.phase.index,
      'finishingOrder': state.finishingOrder,
      'isGameOver': state.isGameOver,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  // Désérialiser l'état du jeu
  CheckgamesState deserializeState(Map<String, dynamic> data) {
    return CheckgamesState(
      players: (data['players'] as List).map((p) => Player(
        id: p['id'],
        name: p['name'],
        hand: (p['hand'] as List).map((c) => PlayingCard(
          suit: CardSuit.values[c['suit']],
          value: CardValue.values[c['value']],
        )).toList(),
      )).toList(),
      currentPlayerIndex: data['currentPlayerIndex'],
      drawPile: (data['drawPile'] as List).map((c) => PlayingCard(
        suit: CardSuit.values[c['suit']],
        value: CardValue.values[c['value']],
      )).toList(),
      discardPile: (data['discardPile'] as List).map((c) => PlayingCard(
        suit: CardSuit.values[c['suit']],
        value: CardValue.values[c['value']],
      )).toList(),
      skipCount: data['skipCount'],
      cardsToDraw: data['cardsToDraw'],
      imposedSuit: data['imposedSuit'] != null
          ? CardSuit.values[data['imposedSuit']]
          : null,
      phase: GamePhase.values[data['phase']],
      finishingOrder: List<String>.from(data['finishingOrder']),
      isGameOver: data['isGameOver'],
    );
  }
}