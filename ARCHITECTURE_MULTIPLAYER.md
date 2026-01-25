# Architecture Multijoueur - Firebase comme Source Unique de Vérité

## 🎯 Principes

1. **Firebase = Unique source de vérité**
2. **Clients = UI + Intentions uniquement**
3. **Transactions atomiques** pour toutes les modifications d'état
4. **Pas de génération locale** de deck, cartes, ou état de jeu

---

## 📊 Structure Firestore Correcte

```
/game_rooms/{roomId}
  ├── hostId: string                    // UID de l'hôte
  ├── roomCode: string                  // Code à 6 caractères
  ├── status: string                    // "waiting" | "playing" | "finished"
  ├── maxPlayers: number                // 2-4
  ├── currentPlayers: number
  ├── currentPlayerId: string           // UID du joueur actuel
  ├── direction: number                 // 1 (sens horaire) | -1 (anti-horaire)
  ├── skipCount: number
  ├── cardsToDraw: number
  ├── imposedSuit: number?              // Index de CardSuit ou null
  ├── phase: string                     // "normal" | "duel" | "cumulus"
  ├── isGameOver: boolean
  ├── createdAt: timestamp
  ├── updatedAt: timestamp
  │
  ├── /players/{playerId}
  │   ├── playerName: string
  │   ├── position: number              // 0, 1, 2, 3
  │   ├── handSize: number              // Nombre de cartes (public)
  │   ├── isReady: boolean
  │   ├── joinedAt: timestamp
  │
  ├── /game_state/current
  │   ├── deckSize: number              // Nombre de cartes dans la pioche
  │   ├── discardPile: array            // Pile de défausse (visible)
  │   │   └── {suit: number, value: number}
  │   ├── playerOrder: array            // [uid1, uid2, uid3]
  │   ├── finishingOrder: array         // UIDs des joueurs terminés
  │   ├── lastAction: object
  │   │   ├── playerId: string
  │   │   ├── type: string
  │   │   ├── timestamp: timestamp
  │
  ├── /player_hands/{playerId}          // PRIVÉ - Sécurité Firestore
  │   └── cards: array
  │       └── {suit: number, value: number}
  │
  └── /actions/{actionId}                // Log des actions
      ├── playerId: string
      ├── type: string                   // "init_game" | "play_card" | "draw_card" | "end_turn"
      ├── data: object
      └── timestamp: timestamp
```

---

## 🔐 Règles de Sécurité Firestore

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Fonction helper : vérifier si l'utilisateur est dans la partie
    function isPlayerInRoom(roomId) {
      return exists(/databases/$(database)/documents/game_rooms/$(roomId)/players/$(request.auth.uid));
    }

    // Fonction helper : vérifier si c'est le tour du joueur
    function isPlayerTurn(roomId) {
      return get(/databases/$(database)/documents/game_rooms/$(roomId)).data.currentPlayerId == request.auth.uid;
    }

    match /game_rooms/{roomId} {
      // Lecture : tout utilisateur authentifié
      allow read: if request.auth != null;

      // Création : tout utilisateur authentifié
      allow create: if request.auth != null;

      // Mise à jour : uniquement via transactions (validées côté serveur)
      allow update: if request.auth != null && isPlayerInRoom(roomId);

      // Sous-collection players
      match /players/{playerId} {
        allow read: if request.auth != null;
        allow write: if request.auth != null;
      }

      // État du jeu (public)
      match /game_state/current {
        allow read: if request.auth != null;
        allow write: if request.auth != null && isPlayerInRoom(roomId);
      }

      // Mains des joueurs (PRIVÉ)
      match /player_hands/{playerId} {
        // Chaque joueur ne voit QUE sa propre main
        allow read: if request.auth != null && request.auth.uid == playerId;
        allow write: if request.auth != null && isPlayerInRoom(roomId);
      }

      // Log des actions
      match /actions/{actionId} {
        allow read: if request.auth != null && isPlayerInRoom(roomId);
        allow create: if request.auth != null && isPlayerInRoom(roomId);
      }
    }
  }
}
```

---

## 🏗️ Architecture des Services

### 1. GameMasterService (Logique Serveur)
**Responsabilité :** Initialiser et gérer l'état du jeu

```dart
class GameMasterService {
  final FirebaseFirestore _firestore;

  // SEULE méthode qui crée l'état initial du jeu
  Future<void> initializeGame(String roomId) async {
    await _firestore.runTransaction((transaction) async {
      // 1. Générer et mélanger le deck
      final deck = _generateDeck();

      // 2. Récupérer les joueurs
      final playersSnapshot = await _firestore
        .collection('game_rooms/$roomId/players')
        .orderBy('position')
        .get();

      final playerUids = playersSnapshot.docs.map((d) => d.id).toList();

      // 3. Distribuer les cartes
      final hands = <String, List<Map<String, int>>>{};
      for (var uid in playerUids) {
        hands[uid] = deck.take(5).map(_cardToJson).toList();
        deck.removeRange(0, 5);
      }

      // 4. Carte initiale sur la défausse
      final firstCard = _drawNonSpecialCard(deck);
      final discardPile = [_cardToJson(firstCard)];

      // 5. Sauvegarder dans Firestore (transaction atomique)
      transaction.update(
        _firestore.doc('game_rooms/$roomId'),
        {
          'status': 'playing',
          'currentPlayerId': playerUids[0],
          'direction': 1,
          'skipCount': 0,
          'cardsToDraw': 0,
          'imposedSuit': null,
          'phase': 'normal',
          'isGameOver': false,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );

      transaction.set(
        _firestore.doc('game_rooms/$roomId/game_state/current'),
        {
          'deckSize': deck.length,
          'discardPile': discardPile,
          'playerOrder': playerUids,
          'finishingOrder': [],
          'lastAction': {
            'playerId': 'system',
            'type': 'init_game',
            'timestamp': FieldValue.serverTimestamp(),
          },
        },
      );

      // Sauvegarder les mains (privées)
      for (var entry in hands.entries) {
        transaction.set(
          _firestore.doc('game_rooms/$roomId/player_hands/${entry.key}'),
          {'cards': entry.value},
        );
      }
    });
  }
}
```

### 2. GameActionService (Actions du joueur)
**Responsabilité :** Exécuter les actions via transactions atomiques

```dart
class GameActionService {
  final FirebaseFirestore _firestore;

  // Jouer une carte
  Future<void> playCard({
    required String roomId,
    required String playerId,
    required List<PlayingCard> cards,
    CardSuit? imposedSuit,
  }) async {
    await _firestore.runTransaction((transaction) async {
      // 1. Lire l'état actuel
      final roomDoc = await transaction.get(_firestore.doc('game_rooms/$roomId'));
      final gameStateDoc = await transaction.get(_firestore.doc('game_rooms/$roomId/game_state/current'));
      final handDoc = await transaction.get(_firestore.doc('game_rooms/$roomId/player_hands/$playerId'));

      // 2. Valider l'action
      final currentPlayerId = roomDoc.data()!['currentPlayerId'];
      if (currentPlayerId != playerId) {
        throw Exception('Ce n\'est pas votre tour !');
      }

      final hand = (handDoc.data()!['cards'] as List)
        .map((c) => PlayingCard(
          suit: CardSuit.values[c['suit']],
          value: CardValue.values[c['value']],
        ))
        .toList();

      // Vérifier que le joueur a bien les cartes
      if (!cards.every((c) => hand.contains(c))) {
        throw Exception('Carte non valide !');
      }

      // 3. Appliquer la logique de jeu
      final newHand = hand.where((c) => !cards.contains(c)).toList();
      final discardPile = List<Map<String, int>>.from(gameStateDoc.data()!['discardPile']);
      discardPile.addAll(cards.map(_cardToJson));

      // 4. Calculer le prochain joueur
      final playerOrder = List<String>.from(gameStateDoc.data()!['playerOrder']);
      final nextPlayerId = _getNextPlayer(playerOrder, playerId, roomDoc.data()!);

      // 5. Mettre à jour Firestore (atomique)
      transaction.update(_firestore.doc('game_rooms/$roomId'), {
        'currentPlayerId': nextPlayerId,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      transaction.update(_firestore.doc('game_rooms/$roomId/game_state/current'), {
        'discardPile': discardPile,
      });

      transaction.update(_firestore.doc('game_rooms/$roomId/player_hands/$playerId'), {
        'cards': newHand.map(_cardToJson).toList(),
      });

      // Log de l'action
      transaction.set(_firestore.collection('game_rooms/$roomId/actions').doc(), {
        'playerId': playerId,
        'type': 'play_card',
        'data': {'cards': cards.map(_cardToJson).toList()},
        'timestamp': FieldValue.serverTimestamp(),
      });
    });
  }
}
```

### 3. MultiplayerGameBloc (Client - Écoute uniquement)
**Responsabilité :** Écouter Firebase et émettre les états

```dart
class MultiplayerGameBloc extends Bloc<CheckgamesEvent, CheckgamesState> {
  final String roomId;
  final String playerId;

  StreamSubscription? _roomSubscription;
  StreamSubscription? _gameStateSubscription;
  StreamSubscription? _handSubscription;

  MultiplayerGameBloc({required this.roomId, required this.playerId})
    : super(const CheckgamesState()) {

    // Écouter les 3 sources de données
    _listenToRoom();
    _listenToGameState();
    _listenToPlayerHand();
  }

  void _listenToRoom() {
    _roomSubscription = _firestore
      .doc('game_rooms/$roomId')
      .snapshots()
      .listen((snapshot) {
        if (!snapshot.exists) return;

        final data = snapshot.data()!;
        add(UpdateRoomState(
          currentPlayerId: data['currentPlayerId'],
          status: data['status'],
          // ...
        ));
      });
  }

  void _listenToGameState() {
    _gameStateSubscription = _firestore
      .doc('game_rooms/$roomId/game_state/current')
      .snapshots()
      .listen((snapshot) {
        if (!snapshot.exists) return;

        final data = snapshot.data()!;
        add(UpdateGameState(
          discardPile: _deserializeCards(data['discardPile']),
          deckSize: data['deckSize'],
          // ...
        ));
      });
  }

  void _listenToPlayerHand() {
    _handSubscription = _firestore
      .doc('game_rooms/$roomId/player_hands/$playerId')
      .snapshots()
      .listen((snapshot) {
        if (!snapshot.exists) return;

        final data = snapshot.data()!;
        add(UpdatePlayerHand(
          cards: _deserializeCards(data['cards']),
        ));
      });
  }
}
```

---

## 🔄 Flux Complet

### Initialisation de la partie

```
HÔTE:
1. Clique "Démarrer la partie"
2. → GameMasterService.initializeGame(roomId)
3. → Transaction Firebase atomique :
   - Génère le deck
   - Distribue les cartes
   - Définit currentPlayerId
   - Sauvegarde tout dans Firestore

TOUS LES CLIENTS (y compris hôte):
4. ← Listeners détectent les changements
5. ← Blocs émettent les nouveaux états
6. ← UI se met à jour automatiquement
```

### Action de jeu (Jouer une carte)

```
JOUEUR ACTUEL:
1. Sélectionne et joue une carte
2. → GameActionService.playCard(...)
3. → Transaction Firebase atomique :
   - Vérifie que c'est son tour
   - Valide la carte
   - Met à jour l'état
   - Calcule le prochain joueur
   - Sauvegarde tout

TOUS LES CLIENTS:
4. ← Listeners détectent les changements
5. ← État synchronisé automatiquement
6. ← UI mise à jour
```

---

## 📝 Modifications à Apporter

### À SUPPRIMER
- ❌ `MultiplayerGameBloc._onStartGame` (génération locale)
- ❌ `MultiplayerGameBloc._onInitMultiplayerGame` (génération locale)
- ❌ Toute logique de génération de deck côté client
- ❌ Toute logique de calcul de prochain joueur côté client

### À CRÉER
- ✅ `GameMasterService` (logique serveur)
- ✅ `GameActionService` (transactions atomiques)
- ✅ Listeners multiples dans `MultiplayerGameBloc`
- ✅ Événements `UpdateRoomState`, `UpdateGameState`, `UpdatePlayerHand`

### À MODIFIER
- 🔄 `MultiplayerGamePage` : Appeler `GameMasterService` au lieu de `StartGame`
- 🔄 `GamePage` : Envoyer des intentions au lieu de modifier l'état localement
- 🔄 Firestore rules : Ajouter les règles de sécurité

---

Voulez-vous que je commence l'implémentation de cette architecture ?
