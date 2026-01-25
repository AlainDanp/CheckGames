# Guide : Mode Multijoueur avec Firebase

## 📋 Vue d'ensemble

Ce guide vous aidera à transformer votre jeu de cartes en mode multijoueur en temps réel en utilisant Firebase comme backend.

---

## 🎯 Architecture du Mode Multijoueur

### Fonctionnalités cibles :
- ✅ Authentification des joueurs (Firebase Auth)
- ✅ Création et recherche de parties
- ✅ Synchronisation en temps réel avec Firestore
- ✅ Gestion des tours et des actions
- ✅ Chat en temps réel (optionnel)
- ✅ Historique des parties
- ✅ Présence en ligne (Online/Offline)

---

## 📦 Étape 1 : Configuration de Firebase

### 1.1 Créer un projet Firebase

1. Allez sur [Firebase Console](https://console.firebase.google.com)
2. Créez un nouveau projet
3. Activez les services suivants :
   - **Authentication** (Email/Password + Anonymous)
   - **Cloud Firestore**
   - **Cloud Functions** (optionnel, pour la logique serveur)

### 1.2 Configurer Firebase pour Flutter

#### Installation FlutterFire CLI

```bash
# Installer FlutterFire CLI
dart pub global activate flutterfire_cli

# Configurer Firebase pour votre projet
flutterfire configure
```

Suivez les instructions pour sélectionner votre projet Firebase et les plateformes (Android, iOS, Web).

### 1.3 Ajouter les packages Firebase

Modifiez `pubspec.yaml` :

```yaml
dependencies:
  flutter:
    sdk: flutter

  # Firebase Core
  firebase_core: ^2.24.2

  # Firebase Auth
  firebase_auth: ^4.16.0

  # Cloud Firestore
  cloud_firestore: ^4.14.0

  # Firebase Storage (optionnel pour avatars)
  firebase_storage: ^11.6.0

  # Gestion de l'état
  flutter_bloc: ^8.1.3

  # Vos autres dépendances existantes...
```

Installez les packages :
```bash
flutter pub get
```

### 1.4 Initialiser Firebase dans main.dart

```dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // Généré par flutterfire configure

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialiser Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialiser le repository
  final repository = CheckgameRepository();
  await repository.init();

  runApp(MyApp(repository: repository));
}
```

---

## 🗄️ Étape 2 : Structure Firestore

### 2.1 Collections et Documents

```
firestore/
├── users/                      # Profils utilisateurs
│   └── {userId}/
│       ├── username: string
│       ├── email: string
│       ├── avatarUrl: string
│       ├── wins: number
│       ├── losses: number
│       ├── createdAt: timestamp
│       └── lastSeen: timestamp
│
├── game_rooms/                 # Salles de jeu
│   └── {roomId}/
│       ├── hostId: string
│       ├── roomCode: string (6 chars)
│       ├── maxPlayers: number (default: 4)
│       ├── currentPlayers: number
│       ├── status: string (waiting/playing/finished)
│       ├── createdAt: timestamp
│       ├── updatedAt: timestamp
│       │
│       ├── players/           # Sous-collection
│       │   └── {playerId}/
│       │       ├── playerName: string
│       │       ├── position: number (0-3)
│       │       ├── isReady: boolean
│       │       ├── isOnline: boolean
│       │       └── joinedAt: timestamp
│       │
│       ├── game_state/        # Sous-collection
│       │   └── current/
│       │       ├── players: array
│       │       ├── currentPlayerIndex: number
│       │       ├── drawPile: array
│       │       ├── discardPile: array
│       │       ├── skipCount: number
│       │       ├── cardsToDraw: number
│       │       ├── imposedSuit: number
│       │       ├── phase: number
│       │       ├── finishingOrder: array
│       │       └── updatedAt: timestamp
│       │
│       └── actions/           # Sous-collection
│           └── {actionId}/
│               ├── playerId: string
│               ├── type: string (play_card/draw_card/end_turn)
│               ├── data: map
│               └── timestamp: timestamp
│
└── chat_messages/             # Messages de chat (optionnel)
    └── {roomId}/
        └── messages/
            └── {messageId}/
                ├── playerId: string
                ├── playerName: string
                ├── message: string
                └── timestamp: timestamp
```

### 2.2 Règles de sécurité Firestore

Créez `firestore.rules` :

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Helper functions
    function isSignedIn() {
      return request.auth != null;
    }

    function isOwner(userId) {
      return isSignedIn() && request.auth.uid == userId;
    }

    // Users collection
    match /users/{userId} {
      allow read: if isSignedIn();
      allow create: if isOwner(userId);
      allow update: if isOwner(userId);
      allow delete: if isOwner(userId);
    }

    // Game rooms collection
    match /game_rooms/{roomId} {
      // Anyone can read rooms to join
      allow read: if isSignedIn();

      // Only authenticated users can create rooms
      allow create: if isSignedIn() && request.resource.data.hostId == request.auth.uid;

      // Only host can update room status
      allow update: if isSignedIn() &&
        (resource.data.hostId == request.auth.uid ||
         isPlayerInRoom(roomId));

      // Only host can delete
      allow delete: if isSignedIn() && resource.data.hostId == request.auth.uid;

      // Players sub-collection
      match /players/{playerId} {
        allow read: if isSignedIn();
        allow create: if isSignedIn() && playerId == request.auth.uid;
        allow update: if isSignedIn() && playerId == request.auth.uid;
        allow delete: if isSignedIn() && playerId == request.auth.uid;
      }

      // Game state sub-collection
      match /game_state/{stateId} {
        allow read: if isSignedIn() && isPlayerInRoom(roomId);
        allow write: if isSignedIn() && isPlayerInRoom(roomId);
      }

      // Actions sub-collection
      match /actions/{actionId} {
        allow read: if isSignedIn() && isPlayerInRoom(roomId);
        allow create: if isSignedIn() &&
          request.resource.data.playerId == request.auth.uid;
      }
    }

    // Chat messages
    match /chat_messages/{roomId}/messages/{messageId} {
      allow read: if isSignedIn();
      allow create: if isSignedIn() &&
        request.resource.data.playerId == request.auth.uid;
    }

    // Helper to check if user is in room
    function isPlayerInRoom(roomId) {
      return exists(/databases/$(database)/documents/game_rooms/$(roomId)/players/$(request.auth.uid));
    }
  }
}
```

Déployez les règles :
```bash
firebase deploy --only firestore:rules
```

---

## 📱 Étape 3 : Services Flutter

### 3.1 Service d'authentification

Créez `lib/services/firebase_auth_service.dart` :

```dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Utilisateur actuel
  User? get currentUser => _auth.currentUser;

  // Stream d'état d'authentification
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Inscription avec email/password
  Future<UserCredential> signUp({
    required String email,
    required String password,
    required String username,
  }) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Créer le profil utilisateur dans Firestore
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'username': username,
        'email': email,
        'avatarUrl': '',
        'wins': 0,
        'losses': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'lastSeen': FieldValue.serverTimestamp(),
      });

      return userCredential;
    } catch (e) {
      rethrow;
    }
  }

  // Connexion avec email/password
  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Mettre à jour lastSeen
      await _firestore.collection('users').doc(userCredential.user!.uid).update({
        'lastSeen': FieldValue.serverTimestamp(),
      });

      return userCredential;
    } catch (e) {
      rethrow;
    }
  }

  // Connexion anonyme (pour tester rapidement)
  Future<UserCredential> signInAnonymously({String? username}) async {
    try {
      final userCredential = await _auth.signInAnonymously();

      // Créer un profil anonyme
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'username': username ?? 'Joueur${DateTime.now().millisecondsSinceEpoch % 10000}',
        'email': '',
        'avatarUrl': '',
        'wins': 0,
        'losses': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'lastSeen': FieldValue.serverTimestamp(),
      });

      return userCredential;
    } catch (e) {
      rethrow;
    }
  }

  // Déconnexion
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Récupérer les données du profil
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    return doc.data();
  }

  // Mettre à jour le profil
  Future<void> updateProfile(String userId, Map<String, dynamic> data) async {
    await _firestore.collection('users').doc(userId).update(data);
  }
}
```

### 3.2 Service de gestion des salles

Créez `lib/services/firebase_room_service.dart` :

```dart
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

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
}
```

### 3.3 Service de synchronisation du jeu

Créez `lib/services/firebase_game_sync_service.dart` :

```dart
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
```

---

## 🎮 Étape 4 : Adapter le BLoC pour Firebase

### 4.1 Créer un MultiplayerGameBloc

Créez `lib/Bloc/multiplayer_bloc.dart` :

```dart
import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firebase_game_sync_service.dart';
import 'checkgames_state.dart';
import 'checkgames_event.dart';

class MultiplayerGameBloc extends Bloc<CheckgamesEvent, CheckgamesState> {
  final FirebaseGameSyncService _syncService;
  final String roomId;
  final String playerId;

  StreamSubscription? _gameStateSubscription;

  MultiplayerGameBloc({
    required this.roomId,
    required this.playerId,
    required FirebaseGameSyncService syncService,
  }) : _syncService = syncService,
       super(const CheckgamesState()) {

    on<StartGame>(_onStartGame);
    on<PlayCard>(_onPlayCard);
    on<DrawCard>(_onDrawCard);
    on<EndTurn>(_onEndTurn);
    on<SyncGameState>(_onSyncGameState);
    on<SetPaused>(_onSetPaused);

    // Écouter les changements d'état en temps réel
    _gameStateSubscription = _syncService.watchGameState(roomId).listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        add(SyncGameState(data));
      }
    });
  }

  @override
  Future<void> close() {
    _gameStateSubscription?.cancel();
    return super.close();
  }

  Future<void> _onPlayCard(PlayCard event, Emitter<CheckgamesState> emit) async {
    // Vérifier que c'est le tour du joueur
    if (state.players.isEmpty || state.players[state.currentPlayerIndex].id != playerId) {
      return; // Pas le tour de ce joueur
    }

    // Utiliser la logique existante de CheckGameBloc
    // ... (copier la logique de _onPlayCard depuis checkgames_bloc.dart) ...

    // Enregistrer l'action dans Firebase
    await _syncService.recordAction(
      roomId: roomId,
      playerId: playerId,
      type: 'play_card',
      data: {
        'cards': event.cards.map((c) => {
          'suit': c.suit.index,
          'value': c.value.index,
        }).toList(),
        'imposedSuit': event.imposedSuit?.index,
      },
    );

    // Sauvegarder le nouvel état
    await _syncService.saveGameState(roomId, state);
  }

  void _onSyncGameState(SyncGameState event, Emitter<CheckgamesState> emit) {
    // Ne synchroniser que si ce n'est pas le joueur actuel qui a fait l'action
    // (pour éviter les boucles)
    final newState = _syncService.deserializeState(event.stateData);
    emit(newState);
  }

  // Autres handlers...
}

// Nouvel événement
class SyncGameState extends CheckgamesEvent {
  final Map<String, dynamic> stateData;
  const SyncGameState(this.stateData);
}
```

---

## 🖥️ Étape 5 : Interface Utilisateur

### 5.1 Écran de connexion

Créez `lib/ui/auth_screen.dart` :

```dart
import 'package:flutter/material.dart';
import '../services/firebase_auth_service.dart';

class AuthScreen extends StatefulWidget {
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _authService = FirebaseAuthService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  bool _isLogin = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isLogin ? 'Connexion' : 'Inscription'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!_isLogin)
              TextField(
                controller: _usernameController,
                decoration: InputDecoration(labelText: 'Nom d\'utilisateur'),
              ),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(labelText: 'Mot de passe'),
              obscureText: true,
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                try {
                  if (_isLogin) {
                    await _authService.signIn(
                      email: _emailController.text,
                      password: _passwordController.text,
                    );
                  } else {
                    await _authService.signUp(
                      email: _emailController.text,
                      password: _passwordController.text,
                      username: _usernameController.text,
                    );
                  }
                  Navigator.pushReplacementNamed(context, '/lobby');
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString())),
                  );
                }
              },
              child: Text(_isLogin ? 'Se connecter' : 'S\'inscrire'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _isLogin = !_isLogin;
                });
              },
              child: Text(_isLogin
                ? 'Pas de compte ? Inscription'
                : 'Déjà un compte ? Connexion'),
            ),
            SizedBox(height: 16),
            OutlinedButton(
              onPressed: () async {
                try {
                  await _authService.signInAnonymously();
                  Navigator.pushReplacementNamed(context, '/lobby');
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString())),
                  );
                }
              },
              child: Text('Jouer en anonyme'),
            ),
          ],
        ),
      ),
    );
  }
}
```

### 5.2 Écran de lobby

Créez `lib/ui/multiplayer_lobby_screen.dart` :

```dart
import 'package:flutter/material.dart';
import '../services/firebase_room_service.dart';
import '../services/firebase_auth_service.dart';

class MultiplayerLobbyScreen extends StatelessWidget {
  final _roomService = FirebaseRoomService();
  final _authService = FirebaseAuthService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Multijoueur'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: () async {
              await _authService.signOut();
              Navigator.pushReplacementNamed(context, '/auth');
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              icon: Icon(Icons.add),
              label: Text('Créer une partie'),
              onPressed: () async {
                final user = _authService.currentUser!;
                final profile = await _authService.getUserProfile(user.uid);

                final roomRef = await _roomService.createRoom(
                  hostId: user.uid,
                  playerName: profile!['username'],
                );

                Navigator.pushNamed(
                  context,
                  '/waiting-room',
                  arguments: {
                    'roomId': roomRef.id,
                    'isHost': true,
                  },
                );
              },
            ),
            SizedBox(height: 20),
            ElevatedButton.icon(
              icon: Icon(Icons.login),
              label: Text('Rejoindre avec code'),
              onPressed: () {
                _showJoinDialog(context);
              },
            ),
            SizedBox(height: 40),
            Text('Parties disponibles', style: TextStyle(fontSize: 18)),
            SizedBox(height: 10),
            Expanded(
              child: StreamBuilder(
                stream: _roomService.getAvailableRooms(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Center(child: CircularProgressIndicator());
                  }

                  final rooms = snapshot.data!.docs;

                  if (rooms.isEmpty) {
                    return Center(child: Text('Aucune partie disponible'));
                  }

                  return ListView.builder(
                    itemCount: rooms.length,
                    itemBuilder: (context, index) {
                      final room = rooms[index];
                      final data = room.data() as Map<String, dynamic>;

                      return ListTile(
                        title: Text('Partie ${data['roomCode']}'),
                        subtitle: Text('${data['currentPlayers']}/${data['maxPlayers']} joueurs'),
                        trailing: ElevatedButton(
                          child: Text('Rejoindre'),
                          onPressed: () async {
                            try {
                              final user = _authService.currentUser!;
                              final profile = await _authService.getUserProfile(user.uid);

                              await _roomService.joinRoomByCode(
                                roomCode: data['roomCode'],
                                playerId: user.uid,
                                playerName: profile!['username'],
                              );

                              Navigator.pushNamed(
                                context,
                                '/waiting-room',
                                arguments: {
                                  'roomId': room.id,
                                  'isHost': false,
                                },
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(e.toString())),
                              );
                            }
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showJoinDialog(BuildContext context) {
    final codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Rejoindre une partie'),
        content: TextField(
          controller: codeController,
          decoration: InputDecoration(
            labelText: 'Code de la partie',
            hintText: 'Entrez le code à 6 caractères',
          ),
          textCapitalization: TextCapitalization.characters,
          maxLength: 6,
        ),
        actions: [
          TextButton(
            child: Text('Annuler'),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            child: Text('Rejoindre'),
            onPressed: () async {
              try {
                final user = _authService.currentUser!;
                final profile = await _authService.getUserProfile(user.uid);

                final roomId = await _roomService.joinRoomByCode(
                  roomCode: codeController.text.toUpperCase(),
                  playerId: user.uid,
                  playerName: profile!['username'],
                );

                Navigator.pop(context);
                Navigator.pushNamed(
                  context,
                  '/waiting-room',
                  arguments: {
                    'roomId': roomId,
                    'isHost': false,
                  },
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(e.toString())),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
```

### 5.3 Écran de salle d'attente

(Similaire au guide Supabase, adaptez avec les services Firebase)

---

## 🚀 Étape 6 : Fonctionnalités avancées

### 6.1 Présence en ligne

```dart
// Dans firebase_room_service.dart
void setupPresence(String roomId, String playerId) {
  final playerRef = _firestore
      .collection('game_rooms')
      .doc(roomId)
      .collection('players')
      .doc(playerId);

  // Marquer comme online
  playerRef.update({'isOnline': true});

  // Marquer comme offline à la déconnexion
  playerRef.update({
    'isOnline': false,
    'lastSeen': FieldValue.serverTimestamp(),
  }).onError((error, stackTrace) {
    // Gérer l'erreur
  });
}
```

### 6.2 Chat en temps réel

```dart
class FirebaseChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> sendMessage(String roomId, String playerId, String message) async {
    await _firestore
        .collection('chat_messages')
        .doc(roomId)
        .collection('messages')
        .add({
      'playerId': playerId,
      'message': message,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> watchMessages(String roomId) {
    return _firestore
        .collection('chat_messages')
        .doc(roomId)
        .collection('messages')
        .orderBy('timestamp')
        .snapshots();
  }
}
```

---

## ✅ Checklist d'implémentation

- [ ] Configuration Firebase
- [ ] Règles de sécurité Firestore
- [ ] Service d'authentification
- [ ] Service de gestion des salles
- [ ] Service de synchronisation
- [ ] Adaptation du BLoC
- [ ] Interface de connexion
- [ ] Interface de lobby
- [ ] Interface de salle d'attente
- [ ] Interface de jeu multijoueur
- [ ] Gestion des déconnexions
- [ ] Présence en ligne
- [ ] Chat (optionnel)
- [ ] Tests

---

## 🎓 Ressources utiles

- [Firebase Flutter Documentation](https://firebase.google.com/docs/flutter/setup)
- [Cloud Firestore Documentation](https://firebase.google.com/docs/firestore)
- [Firebase Auth Documentation](https://firebase.google.com/docs/auth)
- [Firestore Security Rules](https://firebase.google.com/docs/firestore/security/get-started)

---

## 💡 Avantages de Firebase vs Supabase

✅ **Synchronisation en temps réel native** avec Firestore
✅ **Offline support** : Les données sont mises en cache
✅ **Scalabilité automatique** : Firebase gère l'infrastructure
✅ **Présence en ligne** facile à implémenter
✅ **Gratuit jusqu'à 50k lectures/jour**

Bon courage pour l'implémentation ! 🚀
