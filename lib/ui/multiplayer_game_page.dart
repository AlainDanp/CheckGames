import 'package:checkgame/services/presence_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../Bloc/multiplayer_bloc.dart';
import '../Bloc/checkgames_event.dart';
import '../Bloc/checkgames_state.dart';
import '../repository/checkgame_repository.dart';
import '../services/firebase_room_service.dart';
import '../services/game_master_service.dart';
import '../utils/app_logger.dart';
import 'game_page.dart';

// Widget wrapper qui initialise le jeu et affiche GamePage
class _MultiplayerGameWrapper extends StatefulWidget {
  final String roomId;
  final String playerId;
  final bool isHost;
  final String currentUserId;
  final String hostId;

  const _MultiplayerGameWrapper({
    required this.roomId,
    required this.isHost,
    required this.playerId,
    required this.currentUserId,
    required this.hostId,
  });

  @override
  State<_MultiplayerGameWrapper> createState() => _MultiplayerGameWrapperState();
}

class _MultiplayerGameWrapperState extends State<_MultiplayerGameWrapper> {
  @override
  void initState() {
    super.initState();

    // SEUL L'HÔTE initialise le jeu via GameMasterService
    if (widget.isHost) {
      appLogger.d('L\'hôte initialise le jeu via GameMasterService...');
      final gameMaster = GameMasterService();
      gameMaster.initializeGame(widget.roomId).then((_) {
        appLogger.d('Jeu initialisé avec succès par GameMasterService');
      }).catchError((error) {
        appLogger.e('Erreur lors de l\'initialisation du jeu', error: error);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur d\'initialisation: $error')),
          );
        }
      });
    } else {
      appLogger.d('Invité en attente de la synchronisation...');
    }
    PresenceService.instance.setupPresence(
        roomId: widget.roomId,
        playerId: widget.playerId,
    );
  }
  @override
  void dispose() {
    PresenceService.instance.removePresence();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isHost) {
      return GamePage(
        playerId: widget.currentUserId,
        roomId: widget.roomId,
        hostId: widget.hostId,
      );
    } else {
      return _WaitingForSyncScreen(
        child: GamePage(
          playerId: widget.currentUserId,
          roomId: widget.roomId,
          hostId: widget.hostId,
        ),
      );
    }
  }
}

// Widget pour afficher un écran de chargement jusqu'à ce que le jeu soit synchronisé
class _WaitingForSyncScreen extends StatelessWidget {
  final Widget child;

  const _WaitingForSyncScreen({required this.child});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<Bloc<CheckgamesEvent, CheckgamesState>, CheckgamesState, bool>(
      selector: (state) => state.players.isEmpty,
      builder: (context, isEmpty) {
        if (isEmpty) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Synchronisation avec l\'hôte...'),
                  SizedBox(height: 8),
                  Text(
                    'En attente du début de la partie',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        }

        return child;
      },
    );
  }
}

class MultiplayerGamePage extends StatefulWidget {
  final String roomId;

  const MultiplayerGamePage({super.key, required this.roomId});

  @override
  State<MultiplayerGamePage> createState() => _MultiplayerGamePageState();
}

class _MultiplayerGamePageState extends State<MultiplayerGamePage> {
  final _roomService = FirebaseRoomService();

  Future<Map<String, dynamic>> _getRoomData() async {
    // Récupérer les joueurs de la room Firebase
    final playersSnapshot = await FirebaseFirestore.instance
        .collection('game_rooms')
        .doc(widget.roomId)
        .collection('players')
        .orderBy('position')
        .get();

    final playerNames = playersSnapshot.docs
        .map((doc) => doc.data()['playerName'] as String)
        .toList();

    // Récupérer l'ID de l'hôte
    final roomDoc = await FirebaseFirestore.instance
        .collection('game_rooms')
        .doc(widget.roomId)
        .get();

    final hostId = roomDoc.data()?['hostId'] as String?;

    return {
      'playerNames': playerNames,
      'hostId': hostId,
    };
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final repository = CheckgameRepository();

    return FutureBuilder<void>(
      future: repository.init(),
      builder: (context, initSnapshot) {
        if (initSnapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // Récupérer les données de la room
        return FutureBuilder<Map<String, dynamic>>(
          future: _getRoomData(),
          builder: (context, roomDataSnapshot) {
            if (roomDataSnapshot.connectionState != ConnectionState.done) {
              return const Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Chargement des joueurs...'),
                    ],
                  ),
                ),
              );
            }

            if (!roomDataSnapshot.hasData) {
              return Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      const Text('Erreur lors du chargement de la partie'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Retour'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final roomData = roomDataSnapshot.data!;
            final playerNames = roomData['playerNames'] as List<String>;
            final hostId = roomData['hostId'] as String?;
            final isHost = currentUserId == hostId;

            if (playerNames.isEmpty) {
              return Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      const Text('Aucun joueur trouvé dans la partie'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Retour'),
                      ),
                    ],
                  ),
                ),
              );
            }

            appLogger.d('${isHost ? "HÔTE" : "INVITÉ"} - Jeu multijoueur avec ${playerNames.length} joueurs');

            // Fournir le Bloc comme un Bloc générique pour compatibilité avec GamePage
            return BlocProvider<Bloc<CheckgamesEvent, CheckgamesState>>(
              create: (_) => MultiplayerGameBloc(
                roomId: widget.roomId,
                playerId: currentUserId,
                repository: repository,
              ),
              child: _MultiplayerGameWrapper(
                roomId: widget.roomId,
                isHost: isHost,
                currentUserId: currentUserId,
                hostId: hostId!, playerId: '',
              ),
            );
          },
        );
      },
    );
  }
}
