# Guide : Mode Multijoueur avec Supabase

## 📋 Vue d'ensemble

Ce guide vous aidera à transformer votre jeu de cartes en mode multijoueur en temps réel en utilisant Supabase comme backend.

---

## 🎯 Architecture du Mode Multijoueur

### Fonctionnalités cibles :
- ✅ Authentification des joueurs
- ✅ Création et recherche de parties
- ✅ Synchronisation en temps réel de l'état du jeu
- ✅ Gestion des tours et des actions
- ✅ Chat en temps réel (optionnel)
- ✅ Historique des parties

---

## 📦 Étape 1 : Configuration de Supabase

### 1.1 Créer un projet Supabase

1. Allez sur [supabase.com](https://supabase.com)
2. Créez un compte et un nouveau projet
3. Notez votre **API URL** et **anon key** (Settings → API)

### 1.2 Ajouter Supabase à Flutter

Modifiez `pubspec.yaml` :

```yaml
dependencies:
  supabase_flutter: ^2.3.0
  # Vos autres dépendances...
```

Puis installez :
```bash
flutter pub get
```

### 1.3 Initialiser Supabase dans main.dart

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'VOTRE_SUPABASE_URL',
    anonKey: 'VOTRE_SUPABASE_ANON_KEY',
  );

  // ... reste du code
  runApp(MyApp());
}

// Helper pour accéder facilement à Supabase
final supabase = Supabase.instance.client;
```

---

## 🗄️ Étape 2 : Structure de la Base de Données

### 2.1 Table `profiles` (Profils utilisateurs)

```sql
CREATE TABLE profiles (
  id UUID REFERENCES auth.users PRIMARY KEY,
  username TEXT UNIQUE NOT NULL,
  avatar_url TEXT,
  wins INTEGER DEFAULT 0,
  losses INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Trigger pour créer automatiquement un profil après inscription
CREATE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, username)
  VALUES (new.id, new.email);
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
```

### 2.2 Table `game_rooms` (Salles de jeu)

```sql
CREATE TABLE game_rooms (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  host_id UUID REFERENCES profiles(id) NOT NULL,
  room_code TEXT UNIQUE NOT NULL,
  max_players INTEGER DEFAULT 4,
  current_players INTEGER DEFAULT 1,
  status TEXT DEFAULT 'waiting', -- waiting, playing, finished
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index pour recherche rapide par code
CREATE INDEX idx_room_code ON game_rooms(room_code);
CREATE INDEX idx_room_status ON game_rooms(status);
```

### 2.3 Table `game_states` (État du jeu en temps réel)

```sql
CREATE TABLE game_states (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  room_id UUID REFERENCES game_rooms(id) ON DELETE CASCADE,
  state_data JSONB NOT NULL, -- État complet du jeu (BLoC state)
  current_player_index INTEGER DEFAULT 0,
  turn_number INTEGER DEFAULT 1,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index pour accès rapide
CREATE INDEX idx_game_state_room ON game_states(room_id);
```

### 2.4 Table `room_players` (Joueurs dans une salle)

```sql
CREATE TABLE room_players (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  room_id UUID REFERENCES game_rooms(id) ON DELETE CASCADE,
  player_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  player_name TEXT NOT NULL,
  position INTEGER NOT NULL, -- 0, 1, 2, 3
  is_ready BOOLEAN DEFAULT false,
  joined_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(room_id, player_id),
  UNIQUE(room_id, position)
);

-- Index pour requêtes fréquentes
CREATE INDEX idx_room_players_room ON room_players(room_id);
CREATE INDEX idx_room_players_player ON room_players(player_id);
```

### 2.5 Table `player_actions` (Actions des joueurs)

```sql
CREATE TABLE player_actions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  room_id UUID REFERENCES game_rooms(id) ON DELETE CASCADE,
  player_id UUID REFERENCES profiles(id),
  action_type TEXT NOT NULL, -- play_card, draw_card, end_turn, etc.
  action_data JSONB NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index pour historique
CREATE INDEX idx_actions_room ON player_actions(room_id, created_at);
```

### 2.6 Politiques de sécurité (Row Level Security)

```sql
-- Activer RLS sur toutes les tables
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE game_rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE game_states ENABLE ROW LEVEL SECURITY;
ALTER TABLE room_players ENABLE ROW LEVEL SECURITY;
ALTER TABLE player_actions ENABLE ROW LEVEL SECURITY;

-- Politiques pour profiles
CREATE POLICY "Profils publics en lecture" ON profiles
  FOR SELECT USING (true);

CREATE POLICY "Utilisateurs peuvent modifier leur profil" ON profiles
  FOR UPDATE USING (auth.uid() = id);

-- Politiques pour game_rooms
CREATE POLICY "Salles publiques en lecture" ON game_rooms
  FOR SELECT USING (true);

CREATE POLICY "Créateurs peuvent gérer leurs salles" ON game_rooms
  FOR ALL USING (auth.uid() = host_id);

-- Politiques pour room_players
CREATE POLICY "Joueurs peuvent voir les membres de leur salle" ON room_players
  FOR SELECT USING (
    room_id IN (SELECT room_id FROM room_players WHERE player_id = auth.uid())
  );

CREATE POLICY "Joueurs peuvent rejoindre une salle" ON room_players
  FOR INSERT WITH CHECK (player_id = auth.uid());

-- Politiques pour game_states
CREATE POLICY "Joueurs peuvent voir l'état de leur partie" ON game_states
  FOR SELECT USING (
    room_id IN (SELECT room_id FROM room_players WHERE player_id = auth.uid())
  );

-- Politiques pour player_actions
CREATE POLICY "Joueurs peuvent créer leurs actions" ON player_actions
  FOR INSERT WITH CHECK (player_id = auth.uid());

CREATE POLICY "Joueurs peuvent voir les actions de leur partie" ON player_actions
  FOR SELECT USING (
    room_id IN (SELECT room_id FROM room_players WHERE player_id = auth.uid())
  );
```

---

## 📱 Étape 3 : Implémentation Flutter

### 3.1 Service d'authentification

Créez `lib/services/auth_service.dart` :

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Inscription
  Future<AuthResponse> signUp(String email, String password, String username) async {
    final response = await _supabase.auth.signUp(
      email: email,
      password: password,
    );

    if (response.user != null) {
      // Mettre à jour le username
      await _supabase
          .from('profiles')
          .update({'username': username})
          .eq('id', response.user!.id);
    }

    return response;
  }

  // Connexion
  Future<AuthResponse> signIn(String email, String password) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // Connexion anonyme (pour tester rapidement)
  Future<AuthResponse> signInAnonymously() async {
    return await _supabase.auth.signInAnonymously();
  }

  // Déconnexion
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  // Utilisateur actuel
  User? get currentUser => _supabase.auth.currentUser;

  // Stream d'état d'authentification
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;
}
```

### 3.2 Service de gestion des salles

Créez `lib/services/room_service.dart` :

```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';

class RoomService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Générer un code de salle unique
  String _generateRoomCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return List.generate(6, (index) => chars[random.nextInt(chars.length)]).join();
  }

  // Créer une salle
  Future<Map<String, dynamic>> createRoom({
    required String hostId,
    required String playerName,
    int maxPlayers = 4,
  }) async {
    final roomCode = _generateRoomCode();

    // Créer la salle
    final roomResponse = await _supabase
        .from('game_rooms')
        .insert({
          'host_id': hostId,
          'room_code': roomCode,
          'max_players': maxPlayers,
          'current_players': 1,
          'status': 'waiting',
        })
        .select()
        .single();

    // Ajouter l'hôte comme premier joueur
    await _supabase.from('room_players').insert({
      'room_id': roomResponse['id'],
      'player_id': hostId,
      'player_name': playerName,
      'position': 0,
      'is_ready': true,
    });

    return roomResponse;
  }

  // Rejoindre une salle
  Future<void> joinRoom({
    required String roomCode,
    required String playerId,
    required String playerName,
  }) async {
    // Vérifier que la salle existe et n'est pas pleine
    final room = await _supabase
        .from('game_rooms')
        .select('id, current_players, max_players, status')
        .eq('room_code', roomCode)
        .single();

    if (room['status'] != 'waiting') {
      throw Exception('La partie a déjà commencé');
    }

    if (room['current_players'] >= room['max_players']) {
      throw Exception('La salle est pleine');
    }

    // Trouver la première position libre
    final existingPlayers = await _supabase
        .from('room_players')
        .select('position')
        .eq('room_id', room['id'])
        .order('position');

    int position = 0;
    for (var player in existingPlayers) {
      if (player['position'] == position) {
        position++;
      } else {
        break;
      }
    }

    // Ajouter le joueur
    await _supabase.from('room_players').insert({
      'room_id': room['id'],
      'player_id': playerId,
      'player_name': playerName,
      'position': position,
      'is_ready': false,
    });

    // Incrémenter le compteur de joueurs
    await _supabase
        .from('game_rooms')
        .update({'current_players': room['current_players'] + 1})
        .eq('id', room['id']);
  }

  // Marquer un joueur comme prêt
  Future<void> setPlayerReady(String roomId, String playerId, bool ready) async {
    await _supabase
        .from('room_players')
        .update({'is_ready': ready})
        .eq('room_id', roomId)
        .eq('player_id', playerId);
  }

  // Démarrer la partie
  Future<void> startGame(String roomId) async {
    // Vérifier que tous les joueurs sont prêts
    final players = await _supabase
        .from('room_players')
        .select('is_ready')
        .eq('room_id', roomId);

    if (!players.every((p) => p['is_ready'] == true)) {
      throw Exception('Tous les joueurs ne sont pas prêts');
    }

    await _supabase
        .from('game_rooms')
        .update({'status': 'playing'})
        .eq('id', roomId);
  }

  // Écouter les changements de salle en temps réel
  Stream<List<Map<String, dynamic>>> watchRoomPlayers(String roomId) {
    return _supabase
        .from('room_players')
        .stream(primaryKey: ['id'])
        .eq('room_id', roomId)
        .order('position');
  }

  // Écouter l'état de la salle
  Stream<Map<String, dynamic>> watchRoom(String roomId) {
    return _supabase
        .from('game_rooms')
        .stream(primaryKey: ['id'])
        .eq('id', roomId)
        .map((rows) => rows.first);
  }
}
```

### 3.3 Service de synchronisation du jeu

Créez `lib/services/game_sync_service.dart` :

```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../Bloc/checkgames_state.dart';

class GameSyncService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Sauvegarder l'état du jeu
  Future<void> saveGameState(String roomId, CheckgamesState state) async {
    final stateJson = {
      'players': state.players.map((p) => {
        'id': p.id,
        'name': p.name,
        'hand': p.hand.map((c) => {'suit': c.suit.index, 'value': c.value.index}).toList(),
      }).toList(),
      'currentPlayerIndex': state.currentPlayerIndex,
      'drawPile': state.drawPile.map((c) => {'suit': c.suit.index, 'value': c.value.index}).toList(),
      'discardPile': state.discardPile.map((c) => {'suit': c.suit.index, 'value': c.value.index}).toList(),
      'skipCount': state.skipCount,
      'cardsToDraw': state.cardsToDraw,
      'imposedSuit': state.imposedSuit?.index,
      'phase': state.phase.index,
      'finishingOrder': state.finishingOrder,
    };

    // Vérifier si un état existe déjà
    final existing = await _supabase
        .from('game_states')
        .select('id')
        .eq('room_id', roomId)
        .maybeSingle();

    if (existing != null) {
      // Mettre à jour
      await _supabase
          .from('game_states')
          .update({
            'state_data': stateJson,
            'current_player_index': state.currentPlayerIndex,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('room_id', roomId);
    } else {
      // Créer
      await _supabase.from('game_states').insert({
        'room_id': roomId,
        'state_data': stateJson,
        'current_player_index': state.currentPlayerIndex,
      });
    }
  }

  // Enregistrer une action
  Future<void> recordAction({
    required String roomId,
    required String playerId,
    required String actionType,
    required Map<String, dynamic> actionData,
  }) async {
    await _supabase.from('player_actions').insert({
      'room_id': roomId,
      'player_id': playerId,
      'action_type': actionType,
      'action_data': actionData,
    });
  }

  // Écouter les changements d'état en temps réel
  Stream<Map<String, dynamic>?> watchGameState(String roomId) {
    return _supabase
        .from('game_states')
        .stream(primaryKey: ['id'])
        .eq('room_id', roomId)
        .map((rows) => rows.isNotEmpty ? rows.first : null);
  }

  // Écouter les actions en temps réel
  Stream<List<Map<String, dynamic>>> watchActions(String roomId) {
    return _supabase
        .from('player_actions')
        .stream(primaryKey: ['id'])
        .eq('room_id', roomId)
        .order('created_at');
  }
}
```

---

## 🎮 Étape 4 : Adapter le BLoC pour le Multijoueur

### 4.1 Créer un nouveau BLoC pour le multijoueur

Créez `lib/Bloc/multiplayer_bloc.dart` :

```dart
import 'package:flutter_bloc/flutter_bloc.dart';
import '../services/game_sync_service.dart';
import 'checkgames_state.dart';
import 'checkgames_event.dart';

class MultiplayerGameBloc extends Bloc<CheckgamesEvent, CheckgamesState> {
  final GameSyncService _syncService;
  final String roomId;
  final String playerId;

  MultiplayerGameBloc({
    required this.roomId,
    required this.playerId,
    required GameSyncService syncService,
  }) : _syncService = syncService,
       super(const CheckgamesState()) {

    on<StartGame>(_onStartGame);
    on<PlayCard>(_onPlayCard);
    on<DrawCard>(_onDrawCard);
    on<EndTurn>(_onEndTurn);
    on<SyncGameState>(_onSyncGameState);

    // Écouter les changements d'état en temps réel
    _syncService.watchGameState(roomId).listen((stateData) {
      if (stateData != null) {
        add(SyncGameState(stateData));
      }
    });
  }

  Future<void> _onPlayCard(PlayCard event, Emitter<CheckgamesState> emit) async {
    // Vérifier que c'est le tour du joueur
    if (state.players[state.currentPlayerIndex].id != playerId) {
      return; // Pas le tour de ce joueur
    }

    // Logique normale du jeu (comme dans CheckGameBloc)
    // ... votre logique existante ...

    // Enregistrer l'action
    await _syncService.recordAction(
      roomId: roomId,
      playerId: playerId,
      actionType: 'play_card',
      actionData: {
        'cards': event.cards.map((c) => {'suit': c.suit.index, 'value': c.value.index}).toList(),
        'imposedSuit': event.imposedSuit?.index,
      },
    );

    // Sauvegarder le nouvel état
    await _syncService.saveGameState(roomId, state);
  }

  void _onSyncGameState(SyncGameState event, Emitter<CheckgamesState> emit) {
    // Reconstruire l'état depuis les données Supabase
    // ... conversion JSON → CheckgamesState ...

    // Émettre le nouvel état
    emit(newState);
  }
}

// Nouvel événement pour la synchronisation
class SyncGameState extends CheckgamesEvent {
  final Map<String, dynamic> stateData;
  const SyncGameState(this.stateData);
}
```

---

## 🖥️ Étape 5 : Interface Utilisateur

### 5.1 Écran de lobby

Créez `lib/ui/lobby_screen.dart` :

```dart
import 'package:flutter/material.dart';

class LobbyScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Checkgames - Multijoueur')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                // Créer une nouvelle partie
                Navigator.pushNamed(context, '/create-room');
              },
              child: Text('Créer une partie'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Rejoindre une partie
                Navigator.pushNamed(context, '/join-room');
              },
              child: Text('Rejoindre une partie'),
            ),
          ],
        ),
      ),
    );
  }
}
```

### 5.2 Écran de salle d'attente

Créez `lib/ui/waiting_room_screen.dart` :

```dart
import 'package:flutter/material.dart';
import '../services/room_service.dart';

class WaitingRoomScreen extends StatelessWidget {
  final String roomId;
  final String roomCode;
  final bool isHost;

  const WaitingRoomScreen({
    required this.roomId,
    required this.roomCode,
    required this.isHost,
  });

  @override
  Widget build(BuildContext context) {
    final roomService = RoomService();

    return Scaffold(
      appBar: AppBar(
        title: Text('Salle : $roomCode'),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: roomService.watchRoomPlayers(roomId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          final players = snapshot.data!;

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: players.length,
                  itemBuilder: (context, index) {
                    final player = players[index];
                    return ListTile(
                      leading: CircleAvatar(child: Text('${index + 1}')),
                      title: Text(player['player_name']),
                      trailing: Icon(
                        player['is_ready'] ? Icons.check_circle : Icons.pending,
                        color: player['is_ready'] ? Colors.green : Colors.grey,
                      ),
                    );
                  },
                ),
              ),

              // Boutons d'action
              Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    if (isHost)
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            try {
                              await roomService.startGame(roomId);
                              Navigator.pushReplacementNamed(
                                context,
                                '/multiplayer-game',
                                arguments: {'roomId': roomId},
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(e.toString())),
                              );
                            }
                          },
                          child: Text('Démarrer la partie'),
                        ),
                      )
                    else
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            // Toggle ready
                          },
                          child: Text('Prêt / Pas prêt'),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
```

---

## 🚀 Étape 6 : Points d'attention et Optimisations

### 6.1 Gestion de la latence

- **Prédiction optimiste** : Afficher immédiatement l'action du joueur local avant confirmation du serveur
- **Rollback** : Si le serveur rejette l'action, annuler l'affichage
- **Indicateurs visuels** : Montrer quand une action est "en attente de confirmation"

### 6.2 Sécurité

- ✅ **Validation côté serveur** : Créez des fonctions PostgreSQL pour valider les actions
- ✅ **Rate limiting** : Limitez le nombre d'actions par seconde par joueur
- ✅ **Anti-triche** : Validez que les cartes jouées sont bien dans la main du joueur

### 6.3 Gestion des déconnexions

```dart
// Détecter une déconnexion
supabase.auth.onAuthStateChange.listen((data) {
  if (data.event == AuthChangeEvent.signedOut) {
    // Retourner au lobby
  }
});

// Reconnecter automatiquement
Future<void> reconnectToRoom(String roomId) async {
  // Vérifier si la partie existe encore
  // Rejoindre la partie en cours
}
```

---

## 📊 Étape 7 : Fonctionnalités avancées (Optionnel)

### 7.1 Chat en temps réel

```sql
CREATE TABLE chat_messages (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  room_id UUID REFERENCES game_rooms(id) ON DELETE CASCADE,
  player_id UUID REFERENCES profiles(id),
  message TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

### 7.2 Classement (Leaderboard)

```sql
CREATE VIEW leaderboard AS
SELECT
  username,
  wins,
  losses,
  (wins::float / NULLIF(wins + losses, 0)) as win_rate
FROM profiles
ORDER BY wins DESC, win_rate DESC
LIMIT 100;
```

### 7.3 Spectateurs

```sql
ALTER TABLE room_players ADD COLUMN is_spectator BOOLEAN DEFAULT false;
```

---

## ✅ Checklist d'implémentation

- [ ] Configuration Supabase
- [ ] Création des tables
- [ ] Service d'authentification
- [ ] Service de gestion des salles
- [ ] Service de synchronisation
- [ ] Adaptation du BLoC
- [ ] Interface de lobby
- [ ] Interface de salle d'attente
- [ ] Interface de jeu multijoueur
- [ ] Gestion des erreurs et déconnexions
- [ ] Tests multijoueurs
- [ ] Optimisation des performances

---

## 🎓 Ressources utiles

- [Documentation Supabase Flutter](https://supabase.com/docs/reference/dart/introduction)
- [Realtime avec Supabase](https://supabase.com/docs/guides/realtime)
- [Row Level Security](https://supabase.com/docs/guides/auth/row-level-security)
- [Flutter BLoC Pattern](https://bloclibrary.dev/)

---

## 💡 Conseils

1. **Commencez petit** : Testez d'abord avec 2 joueurs avant d'augmenter
2. **Testez en local** : Utilisez l'émulateur Supabase pour le développement
3. **Logs** : Ajoutez beaucoup de logs pour déboguer les problèmes de sync
4. **Versions** : Gérez les versions du protocole pour éviter les incompatibilités

Bon courage pour l'implémentation ! 🚀
