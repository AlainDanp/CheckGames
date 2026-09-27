import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/app_logger.dart';

class FirebaseRoomService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Générer un code de salle unique
  String _generateRoomCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return List.generate(6, (index) => chars[random.nextInt(chars.length)]).join();
  }

  // Créer une salle
  Future<DocumentReference> createRoom({
    required String hostId,
    required String playerName,
    int maxPlayers = 4,
  }) async {
    final roomCode = _generateRoomCode();

    // Créer la salle
    final roomRef = await _firestore.collection('game_rooms').add({
      'hostId': hostId,
      'roomCode': roomCode,
      'maxPlayers': maxPlayers,
      'currentPlayers': 1,
      'status': 'waiting',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Ajouter l'hôte comme premier joueur
    await roomRef.collection('players').doc(hostId).set({
      'playerName': playerName,
      'position': 0,
      'isReady': true,
      'isOnline': true,
      'joinedAt': FieldValue.serverTimestamp(),
    });

    return roomRef;
  }

  // Rejoindre une salle par code
  Future<String> joinRoomByCode({
    required String roomCode,
    required String playerId,
    required String playerName,
  }) async {
    // Rechercher la salle par code
    final querySnapshot = await _firestore
        .collection('game_rooms')
        .where('roomCode', isEqualTo: roomCode)
        .where('status', isEqualTo: 'waiting')
        .limit(1)
        .get();

    if (querySnapshot.docs.isEmpty) {
      throw Exception('Salle non trouvée ou partie déjà commencée');
    }

    final roomDoc = querySnapshot.docs.first;
    final roomData = roomDoc.data();
    final roomId = roomDoc.id;

    // Vérifier si la salle est pleine
    if (roomData['currentPlayers'] >= roomData['maxPlayers']) {
      throw Exception('La salle est pleine');
    }

    // Vérifier si le joueur n'est pas déjà dans la salle
    final playerDoc = await roomDoc.reference
        .collection('players')
        .doc(playerId)
        .get();

    if (playerDoc.exists) {
      return roomId; // Déjà dans la salle
    }

    // Trouver la première position libre
    final playersSnapshot = await roomDoc.reference
        .collection('players')
        .orderBy('position')
        .get();

    int position = 0;
    for (var doc in playersSnapshot.docs) {
      if (doc.data()['position'] == position) {
        position++;
      } else {
        break;
      }
    }

    // Ajouter le joueur dans une transaction
    await _firestore.runTransaction((transaction) async {
      final roomSnapshot = await transaction.get(roomDoc.reference);
      final currentPlayers = roomSnapshot.data()!['currentPlayers'] as int;

      // Vérifier à nouveau si la salle n'est pas pleine
      if (currentPlayers >= roomData['maxPlayers']) {
        throw Exception('La salle est pleine');
      }

      // Ajouter le joueur
      transaction.set(
        roomDoc.reference.collection('players').doc(playerId),
        {
          'playerName': playerName,
          'position': position,
          'isReady': false,
          'isOnline': true,
          'joinedAt': FieldValue.serverTimestamp(),
        },
      );

      // Incrémenter le compteur
      transaction.update(roomDoc.reference, {
        'currentPlayers': currentPlayers + 1,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    return roomId;
  }

  // Quitter une salle
  Future<void> leaveRoom(String roomId, String playerId) async {
    final roomRef = _firestore.collection('game_rooms').doc(roomId);

    await _firestore.runTransaction((transaction) async {
      final roomSnapshot = await transaction.get(roomRef);

      if (!roomSnapshot.exists) return;

      final roomData = roomSnapshot.data()!;
      final currentPlayers = roomData['currentPlayers'] as int;

      // Supprimer le joueur
      transaction.delete(roomRef.collection('players').doc(playerId));

      // Si c'était le dernier joueur, supprimer la salle
      if (currentPlayers <= 1) {
        transaction.delete(roomRef);
      } else {
        // Sinon, décrémenter le compteur
        transaction.update(roomRef, {
          'currentPlayers': currentPlayers - 1,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Si c'était l'hôte, transférer à un autre joueur
        if (roomData['hostId'] == playerId) {
          // Trouver un nouveau hôte (premier joueur qui n'est pas celui qui part)
          final playersSnapshot = await roomRef.collection('players').limit(2).get();
          final newHost = playersSnapshot.docs.firstWhere(
                (doc) => doc.id != playerId,
            orElse: () => playersSnapshot.docs.first,
          );

          transaction.update(roomRef, {
            'hostId': newHost.id,
          });
        }
      }
    });
  }

  // Chat en temps réel
  Future<void> sendMessage(String roomId, String playerId, String playerName, String message) async {
    await _firestore
        .collection('chat_messages')
        .doc(roomId)
        .collection('messages')
        .add({
      'playerId': playerId,
      'playerName': playerName,
      'message': message,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> watchMessages(String roomId){
    return _firestore
        .collection('chat_messages')
        .doc(roomId)
        .collection('messages')
        .orderBy('timestamp')
        .snapshots();
  }

  // Marquer un joueur comme prêt
  Future<void> setPlayerReady(String roomId, String playerId, bool ready) async {
    await _firestore
        .collection('game_rooms')
        .doc(roomId)
        .collection('players')
        .doc(playerId)
        .update({'isReady': ready});
  }

  // Démarrer la partie
  Future<void> startGame(String roomId) async {
    // Vérifier que tous les joueurs sont prêts
    final playersSnapshot = await _firestore
        .collection('game_rooms')
        .doc(roomId)
        .collection('players')
        .get();

    final allReady = playersSnapshot.docs.every((doc) => doc.data()['isReady'] == true);

    if (!allReady) {
      throw Exception('Tous les joueurs ne sont pas prêts');
    }

    // Mettre à jour le statut de la salle
    await _firestore.collection('game_rooms').doc(roomId).update({
      'status': 'playing',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Stream de la salle
  Stream<DocumentSnapshot> watchRoom(String roomId) {
    return _firestore.collection('game_rooms').doc(roomId).snapshots();
  }

  // Système de présence - Marquer le joueur comme online
  Future<void> setupPresence(String roomId, String playerId) async {
    final playerRef = _firestore
        .collection('game_rooms')
        .doc(roomId)
        .collection('players')
        .doc(playerId);

    // Marquer comme online
    await playerRef.update({
      'isOnline': true,
      'lastSeen': FieldValue.serverTimestamp(),
    });
  }

  // Marquer le joueur comme offline
  Future<void> markPlayerOffline(String roomId, String playerId) async {
    try {
      await _firestore
          .collection('game_rooms')
          .doc(roomId)
          .collection('players')
          .doc(playerId)
          .update({
        'isOnline': false,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Le joueur a peut-être déjà quitté la salle
      appLogger.w('Erreur mise à jour présence', error: e);
    }
  }

  // Quitter une partie en cours (pendant le jeu)
  Future<void> leaveActiveGame(String roomId, String playerId) async {
    appLogger.d('Joueur quitte la partie');

    final roomRef = _firestore.collection('game_rooms').doc(roomId);

    await _firestore.runTransaction((transaction) async {
      final roomSnapshot = await transaction.get(roomRef);

      if (!roomSnapshot.exists) {
        appLogger.w('La room n\'existe plus');
        return;
      }

      final roomData = roomSnapshot.data()!;

      // Récupérer le game_state pour vérifier les joueurs actifs
      final gameStateSnapshot = await transaction.get(
        roomRef.collection('game_state').doc('current'),
      );

      // Supprimer le joueur de la collection players
      transaction.delete(roomRef.collection('players').doc(playerId));

      // Supprimer la main du joueur
      transaction.delete(roomRef.collection('player_hands').doc(playerId));

      if (gameStateSnapshot.exists) {
        final gameState = gameStateSnapshot.data()!;
        final playerOrder = List<String>.from(gameState['playerOrder'] ?? []);
        final finishingOrder = List<String>.from(gameState['finishingOrder'] ?? []);
        final currentPlayerId = roomData['currentPlayerId'] as String? ?? '';

        // Retirer le joueur du playerOrder
        playerOrder.remove(playerId);

        // Ajouter à finishingOrder s'il n'y est pas déjà (abandon)
        if (!finishingOrder.contains(playerId)) {
          finishingOrder.add(playerId);
        }

        // Vérifier s'il ne reste qu'un seul joueur actif
        final activePlayers = playerOrder.where((id) => !finishingOrder.contains(id)).toList();
        appLogger.d('Joueurs actifs restants: ${activePlayers.length}');

        // Si c'était son tour → passer au prochain joueur actif
        if (currentPlayerId == playerId && activePlayers.isNotEmpty) {
          transaction.update(roomRef, {
            'currentPlayerId': activePlayers.first,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          appLogger.d('Tour passé à ${activePlayers.first} après départ de $playerId');
        }

        if (activePlayers.length <= 1) {
          appLogger.i('Un seul joueur restant — fin de partie');

          if (activePlayers.length == 1) {
            finishingOrder.add(activePlayers.first);
          }

          transaction.update(roomRef, {
            'status': 'finished',
            'isGameOver': true,
            'phase': 'finished',
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        // Mettre à jour le game_state
        transaction.update(
          roomRef.collection('game_state').doc('current'),
          {
            'playerOrder': playerOrder,
            'finishingOrder': finishingOrder,
            'lastAction': {
              'playerId': playerId,
              'type': 'player_left',
              'timestamp': FieldValue.serverTimestamp(),
            },
          },
        );
      }

      // Si c'était l'hôte, transférer ou supprimer la room
      if (roomData['hostId'] == playerId) {
        final playersSnapshot = await roomRef.collection('players').get();

        if (playersSnapshot.docs.isEmpty) {
          appLogger.d('Plus de joueurs — suppression room');
          transaction.delete(roomRef);
        } else {
          // Transférer l'hôte au premier joueur restant
          final newHost = playersSnapshot.docs.first;
          appLogger.d('Transfert de l\'hôte');
          transaction.update(roomRef, {
            'hostId': newHost.id,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      // Décrémenter le compteur de joueurs
      final currentPlayers = roomData['currentPlayers'] as int;
      if (currentPlayers > 0) {
        transaction.update(roomRef, {
          'currentPlayers': currentPlayers - 1,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      appLogger.i('Joueur a quitté la partie avec succès');
    });
  }

  // Stream des joueurs dans la salle
  Stream<QuerySnapshot> watchRoomPlayers(String roomId) {
    return _firestore
        .collection('game_rooms')
        .doc(roomId)
        .collection('players')
        .orderBy('position')
        .snapshots();
  }

  // Récupérer les salles disponibles
  Stream<QuerySnapshot> getAvailableRooms() {
    return _firestore
        .collection('game_rooms')
        .where('status', isEqualTo: 'waiting')
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots();
  }

  // Nettoyer les salles vides ou abandonnees
  Future<void> cleanupEmptyRooms() async {
    try {
      // Recuperer les salles en attente
      final roomsSnapshot = await _firestore
          .collection('game_rooms')
          .where('status', isEqualTo: 'waiting')
          .get();

      for (final roomDoc in roomsSnapshot.docs) {
        final roomData = roomDoc.data();
        final currentPlayers = roomData['currentPlayers'] as int? ?? 0;
        final createdAt = roomData['createdAt'] as Timestamp?;

        // Supprimer si 0 joueurs
        if (currentPlayers <= 0) {
          await roomDoc.reference.delete();
          appLogger.d('Salle supprimée (0 joueurs)');
          continue;
        }

        // Supprimer les salles de plus de 2 heures
        if (createdAt != null) {
          final age = DateTime.now().difference(createdAt.toDate());
          if (age.inHours >= 2) {
            await roomDoc.reference.delete();
            appLogger.d('Salle supprimée (trop ancienne)');
          }
        }
      }
    } catch (e) {
      appLogger.e('Erreur nettoyage salles', error: e);
    }
  }
}