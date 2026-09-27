# Guide : Mode Déconnexion — Pas de Reprise Possible

## Principe

Quand un joueur perd la connexion pendant une partie multijoueur, il est **automatiquement
retiré de la partie** (comme s'il avait cliqué "Quitter"). La partie continue sans lui.
Il ne peut pas rejoindre en cours de route — la room reste ouverte uniquement pour les
joueurs encore connectés.

**Ce que ce guide NE fait PAS :** reconnexion transparente, spectateur, pause de la partie.
C'est volontairement simple : déconnexion = élimination.

---

## Problème actuel

Le code a un système de présence (`setupPresence` / `markPlayerOffline`) mais il est
**purement manuel** : il ne détecte pas une coupure réseau réelle.

```
État actuel
────────────
markPlayerOffline()  ← appelé seulement si l'app se ferme proprement
setupPresence()      ← appelé au join, jamais mis à jour automatiquement

→ Si le téléphone perd le wifi : rien ne se passe côté serveur
→ La partie se fige si c'était son tour
```

---

## Solution choisie : Présence RTDB + Cloud Function

La Firebase **Realtime Database** (RTDB) expose un hook `onDisconnect()` traité
**côté serveur**, même si le client disparaît brutalement (avion, crash, batterie morte).
Une Cloud Function réagit à ce hook et appelle la logique `leaveActiveGame` existante.

```
Architecture
────────────────────────────────────────────────────────────────
App Flutter
  └── RTDB.onDisconnect()  →  marque le nœud "offline" dans RTDB

RTDB (présence)
  └── onChange trigger  →  Cloud Function "onPlayerDisconnect"

Cloud Function
  └── lit Firestore      →  appelle leaveActiveGame (transaction)

Firestore
  └── change detecté     →  MultiplayerGameBloc._listenToPlayers()
                          →  état mis à jour pour tous les clients
```

---

## Fichiers à créer / modifier

| Fichier | Action |
|---------|--------|
| `lib/services/presence_service.dart` | **Créer** — gère le nœud RTDB |
| `lib/ui/multiplayer_game_page.dart` | **Modifier** — appelle le service |
| `functions/src/index.ts` | **Créer** — Cloud Function Node.js |
| `lib/services/firebase_room_service.dart` | **Vérifier** — `leaveActiveGame` déjà OK |

---

## Étape 1 — Ajouter Firebase RTDB au projet

### pubspec.yaml

```yaml
dependencies:
  firebase_database: ^11.0.0   # ajouter cette ligne
```

### android/app/google-services.json

Le fichier existe déjà. RTDB est inclus automatiquement si la base est activée dans
la console Firebase (voir Étape 1b).

### Activer RTDB dans la console Firebase

1. Firebase Console → Build → Realtime Database → Créer une base de données
2. Choisir la région la plus proche (europe-west1 si vos serveurs Firestore sont en Europe)
3. Démarrer en **mode test** (vous sécuriserez avec des règles après)
4. Copier l'URL : `https://checkgame-XXXXX-default-rtdb.europe-west1.firebasedatabase.app`

### Règles RTDB minimales

```json
{
  "rules": {
    "presence": {
      "$roomId": {
        "$playerId": {
          ".read": "auth != null",
          ".write": "auth != null && auth.uid === $playerId"
        }
      }
    }
  }
}
```

---

## Étape 2 — `PresenceService` (nouveau fichier)

```dart
// lib/services/presence_service.dart
import 'package:firebase_database/firebase_database.dart';
import '../utils/app_logger.dart';

/// Gère la présence via Firebase Realtime Database.
///
/// Le nœud RTDB /presence/{roomId}/{playerId} vaut :
///   - { online: true }  pendant la session
///   - { online: false, disconnectedAt: <serverTimestamp> } quand la connexion coupe
///
/// Le hook onDisconnect() est exécuté côté serveur Firebase — même si l'app crashe.
class PresenceService {
  static final PresenceService instance = PresenceService._();
  PresenceService._();

  final _db = FirebaseDatabase.instance;
  DatabaseReference? _presenceRef;

  /// À appeler dès que le joueur entre dans la partie (après initState du wrapper).
  Future<void> setupPresence({
    required String roomId,
    required String playerId,
  }) async {
    _presenceRef = _db.ref('presence/$roomId/$playerId');

    // Ce que Firebase écrira automatiquement si la connexion coupe
    await _presenceRef!.onDisconnect().set({
      'online': false,
      'disconnectedAt': ServerValue.timestamp,
    });

    // Marquer comme connecté maintenant
    await _presenceRef!.set({
      'online': true,
      'connectedAt': ServerValue.timestamp,
    });

    appLogger.d('PresenceService: nœud RTDB initialisé pour $playerId');
  }

  /// À appeler dans dispose() ou quand le joueur quitte volontairement.
  /// Annule le hook onDisconnect et marque offline proprement.
  Future<void> removePresence() async {
    if (_presenceRef == null) return;
    try {
      // Annuler le hook onDisconnect (évite le double-déclenchement)
      await _presenceRef!.onDisconnect().cancel();
      // Marquer offline manuellement
      await _presenceRef!.set({
        'online': false,
        'disconnectedAt': ServerValue.timestamp,
      });
    } catch (e) {
      appLogger.w('PresenceService: erreur removePresence', error: e);
    }
    _presenceRef = null;
  }
}
```

---

## Étape 3 — Brancher dans `_MultiplayerGameWrapper`

```dart
// lib/ui/multiplayer_game_page.dart

class _MultiplayerGameWrapperState extends State<_MultiplayerGameWrapper> {

  @override
  void initState() {
    super.initState();
    // ... code existant (initializeGame pour l'hôte) ...

    // NOUVEAU : activer la présence RTDB
    PresenceService.instance.setupPresence(
      roomId: widget.roomId,
      playerId: widget.playerId,
    );
  }

  @override
  void dispose() {
    // NOUVEAU : retirer proprement la présence
    PresenceService.instance.removePresence();
    super.dispose();
  }
}
```

> **Important :** `removePresence()` annule le hook `onDisconnect` pour les quits
> volontaires. Ainsi la Cloud Function ne sera PAS appelée deux fois (une fois par
> le quit manuel via `leaveActiveGame`, une fois par RTDB).

---

## Étape 4 — Cloud Function `onPlayerDisconnect`

### Prérequis

```bash
npm install -g firebase-tools
firebase login
firebase init functions   # dans le dossier racine du projet
```

Choisir TypeScript.

### functions/src/index.ts

```typescript
import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

admin.initializeApp();
const db = admin.firestore();

/**
 * Déclenchée quand un nœud RTDB /presence/{roomId}/{playerId}
 * passe à { online: false }.
 *
 * Politique : déconnexion = élimination. Pas de reprise possible.
 */
export const onPlayerDisconnect = functions
  .database
  .ref('/presence/{roomId}/{playerId}')
  .onUpdate(async (change, context) => {
    const after = change.after.val() as { online: boolean } | null;

    // Agir uniquement quand online passe à false
    if (!after || after.online !== false) return null;

    const { roomId, playerId } = context.params;
    functions.logger.info(`Déconnexion détectée: joueur=${playerId} room=${roomId}`);

    // Vérifier que la partie est toujours en cours
    const roomRef = db.collection('game_rooms').doc(roomId);
    const roomSnap = await roomRef.get();

    if (!roomSnap.exists) return null;

    const roomData = roomSnap.data()!;
    if (roomData.status !== 'playing') return null;  // Pas encore commencée ou déjà finie

    // Vérifier que le joueur est encore actif (pas déjà sorti volontairement)
    const playerSnap = await roomRef.collection('players').doc(playerId).get();
    if (!playerSnap.exists) {
      functions.logger.info('Joueur déjà absent — ignoré');
      return null;
    }

    // ─── Même logique que leaveActiveGame() côté Dart ───────────────────────
    return db.runTransaction(async (tx) => {
      const gameStateRef = roomRef.collection('game_state').doc('current');
      const gameStateSnap = await tx.get(gameStateRef);

      // Retirer le joueur
      tx.delete(roomRef.collection('players').doc(playerId));
      tx.delete(roomRef.collection('player_hands').doc(playerId));

      if (gameStateSnap.exists) {
        const gs = gameStateSnap.data()!;
        const playerOrder: string[] = [...(gs.playerOrder ?? [])];
        const finishingOrder: string[] = [...(gs.finishingOrder ?? [])];

        playerOrder.splice(playerOrder.indexOf(playerId), 1);
        if (!finishingOrder.includes(playerId)) {
          finishingOrder.push(playerId);   // marquer comme abandon
        }

        const active = playerOrder.filter(id => !finishingOrder.includes(id));

        if (active.length <= 1) {
          // Dernier joueur en lice → victoire par forfait
          if (active.length === 1) finishingOrder.push(active[0]);

          tx.update(roomRef, {
            status: 'finished',
            isGameOver: true,
            phase: 'finished',
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }

        tx.update(gameStateRef, {
          playerOrder,
          finishingOrder,
          lastAction: {
            playerId,
            type: 'player_disconnected',   // ← distingue abandon vs quit volontaire
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
          },
        });
      }

      // Transfert de l'hôte si nécessaire
      if (roomData.hostId === playerId) {
        const playersSnap = await roomRef.collection('players').get();
        if (playersSnap.empty) {
          tx.delete(roomRef);
        } else {
          tx.update(roomRef, {
            hostId: playersSnap.docs[0].id,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
      }

      const currentPlayers = (roomData.currentPlayers as number) ?? 1;
      if (currentPlayers > 0) {
        tx.update(roomRef, {
          currentPlayers: currentPlayers - 1,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }

      functions.logger.info(`Joueur ${playerId} retiré de la partie (déconnexion)`);
    });
  });
```

### Déployer

```bash
cd functions
npm install
npm run build
firebase deploy --only functions
```

---

## Étape 5 — Afficher la déconnexion aux autres joueurs

`MultiplayerGameBloc._listenToPlayers()` écoute déjà la collection `players`.
Quand la Cloud Function supprime le document d'un joueur, le listener se déclenche
et `_tryEmitState()` réémet un état sans ce joueur.

Il reste à afficher un message. Dans `multiplayer_game_page.dart`, ajouter un
`BlocListener` qui réagit à `lastAction.type == 'player_disconnected'` :

```dart
// Dans MultiBlocListener existant, ajouter :
BlocListener<MultiplayerGameBloc, CheckgamesState>(
  listenWhen: (prev, curr) =>
      curr.errorMessage != prev.errorMessage &&
      curr.errorMessage != null,
  listener: (ctx, state) {
    // Déjà géré par le listener saveError existant.
    // Pour la déconnexion, écouter lastAction via le gameStateData du BLoC.
    // Alternative simple : afficher via le champ errorMessage.
  },
),
```

**Alternative plus simple** — dans `_listenToPlayers()` du BLoC, quand un joueur
disparaît, émettre un `errorMessage` temporaire :

```dart
// Dans _listenToPlayers() — après reconstruction des players :
final previousIds = state.players.map((p) => p.id).toSet();
final currentIds = updatedPlayers.map((p) => p.id).toSet();
final disconnectedIds = previousIds.difference(currentIds);

if (disconnectedIds.isNotEmpty && state.players.isNotEmpty) {
  final name = state.players
      .firstWhere((p) => disconnectedIds.contains(p.id), orElse: () => state.players.first)
      .name;
  _playersData = newPlayersData;
  emit(state.copyWith(errorMessage: '📵 $name a perdu la connexion'));
  // Reset après 3s
  Future.delayed(const Duration(seconds: 3), () {
    if (!isClosed) emit(state.copyWith(errorMessage: null));
  });
  return;
}
```

---

## Étape 6 — Bloquer la reconnexion

La règle "pas de reprise" est déjà naturelle : `joinRoomByCode()` vérifie
`status == 'waiting'`. Une partie en cours a `status == 'playing'`, donc le code
rejette automatiquement toute tentative de rejoindre.

Pour être explicite, ajouter un message dans `joinRoomByCode()` :

```dart
// Dans firebase_room_service.dart — joinRoomByCode()
if (roomData['status'] != 'waiting') {
  throw Exception('Cette partie est déjà en cours. La reconnexion n\'est pas possible.');
}
```

---

## Étape 7 — Cas : l'hôte se déconnecte

Actuellement, si la room est supprimée, `_listenToRoom()` émet :
```dart
emit(state.copyWith(
  errorMessage: '🚫 La partie a été fermée par l\'hôte',
  isGameOver: true,
  phase: GamePhase.finished,
));
```

Avec la Cloud Function, le comportement change : l'hôte est **retiré** et un
**nouveau hôte est désigné** (premier joueur restant). La room n'est PAS supprimée.
Le message actuel ne s'affichera donc plus.

Adapter le listener pour couvrir le transfert d'hôte :

```dart
void _listenToRoom() {
  _roomSubscription = _firestore
      .collection('game_rooms')
      .doc(roomId)
      .snapshots()
      .listen((snapshot) {
    if (!snapshot.exists) {
      // Room supprimée = tous les joueurs étaient partis
      emit(state.copyWith(
        errorMessage: '🚫 La partie a été fermée',
        isGameOver: true,
        phase: GamePhase.finished,
      ));
      return;
    }
    final data = snapshot.data()!;

    // Nouveau : détecter le changement d'hôte
    if (_roomData != null && _roomData!['hostId'] != data['hostId']) {
      final newHostId = data['hostId'] as String;
      // Si c'est moi le nouvel hôte : devenir responsable des actions hôte
      if (newHostId == playerId) {
        appLogger.i('Je suis le nouvel hôte');
        // Optionnel : émettre un message
      }
    }

    _roomData = data;
    _tryEmitState();
  });
}
```

---

## Séquences de déconnexion

### Cas 1 — Joueur non-hôte se déconnecte

```
1. Réseau coupé
2. RTDB détecte la coupure → écrit { online: false } sur /presence/{roomId}/{playerId}
3. Cloud Function onPlayerDisconnect se déclenche
4. Transaction Firestore :
   - Supprime players/{playerId}
   - Supprime player_hands/{playerId}
   - Retire playerId de playerOrder
   - Ajoute playerId à finishingOrder (abandon)
   - Si 1 joueur restant → status=finished, isGameOver=true
5. _listenToPlayers() tous les clients reçoivent le nouvel état
6. _tryEmitState() → CheckgamesState sans le joueur déconnecté
7. Snackbar "📵 [Nom] a perdu la connexion"
8. La partie continue normalement
```

### Cas 2 — Hôte se déconnecte, il reste des joueurs

```
1-4. Même que Cas 1
4b. hostId transféré au premier joueur restant dans players
5. _listenToRoom() → le nouveau hostId est différent
6. Si le nouveau hostId == playerId → ce joueur devient hôte
7. La partie continue
```

### Cas 3 — Il ne reste qu'un joueur après déconnexion

```
1-4. Même que Cas 1
4c. active.length == 1 → finishingOrder inclut le dernier
    status = 'finished', isGameOver = true
5. _listenToRoom() → isGameOver: true
6. GameOverSheet s'affiche (listener 2 dans MultiBlocListener)
7. Victoire par forfait
```

### Cas 4 — Quit volontaire (inchangé)

```
1. Joueur appuie "Quitter"
2. PresenceService.removePresence() → annule onDisconnect()
3. FirebaseRoomService.leaveActiveGame() → transaction directe
4. RTDB écrit { online: false } mais onDisconnect annulé → Cloud Function ignorée
   (La transaction Firestore a déjà eu lieu, le joueur n'existe plus dans players)
```

---

## Délai de déclenchement

Firebase RTDB détecte la déconnexion en **60–90 secondes** sur mobile (timeout TCP).
C'est inhérent au protocole réseau — on ne peut pas descendre en dessous de ~30 secondes
sans risquer des faux positifs (tunnel, mauvais wifi temporaire).

Pour informer les joueurs pendant l'attente, afficher un indicateur dans `_listenToPlayers()`
quand `isOnline == false` dans Firestore (mis à jour par `markPlayerOffline()` au dispose) :

```dart
// Dans _buildTopOpponent() — game_page.dart
// Ajouter un indicateur visuel si le joueur est offline
if (!player.isOnline)  // ← nécessite d'ajouter isOnline au modèle Player
  const Icon(Icons.wifi_off, color: Colors.orange, size: 14),
```

Mettre à jour `setupPresence()` pour aussi écrire dans Firestore :

```dart
// firebase_room_service.dart — setupPresence()
// Ajouter pour cohérence avec l'indicateur UI :
await playerRef.update({
  'isOnline': true,
  'lastSeen': FieldValue.serverTimestamp(),
});
// Note : déjà dans le code actuel — rien à changer ici
```

Et dans `markPlayerOffline()` (appelé dans dispose du wrapper) :

```dart
// Déjà dans le code — rien à changer
// Cette écriture Firestore sert à l'UI "offline indicator"
// La vraie élimination vient de la Cloud Function via RTDB
```

---

## Vérification

### Tests manuels

| Scénario | Attendu |
|----------|---------|
| Couper le wifi sur le téléphone d'un non-hôte | Après ~60s : joueur retiré, partie continue |
| Couper le wifi sur le téléphone de l'hôte | Après ~60s : hôte transféré, partie continue |
| 2 joueurs, non-hôte se déconnecte | GameOverSheet pour le joueur restant |
| Joueur tente `joinRoomByCode` sur partie `playing` | Exception "reconnexion impossible" |
| Quit volontaire via "Quitter" | Immédiat, pas de double-appel Cloud Function |

### Vérifier les logs Cloud Functions

```bash
firebase functions:log --only onPlayerDisconnect
```

### Vérifier la RTDB en console

Firebase Console → Realtime Database → onglet Données → `/presence/{roomId}/{playerId}`

---

## Récapitulatif des changements

```
Nouveaux fichiers
─────────────────
lib/services/presence_service.dart     ← nœud RTDB + onDisconnect hook
functions/src/index.ts                 ← Cloud Function déclenchée par RTDB

Modifications
─────────────
lib/ui/multiplayer_game_page.dart
  _MultiplayerGameWrapperState.initState()  ← appel PresenceService.setupPresence()
  _MultiplayerGameWrapperState.dispose()    ← appel PresenceService.removePresence()

lib/Bloc/multiplayer_bloc.dart
  _listenToRoom()     ← détecter transfert hôte
  _listenToPlayers()  ← émettre snackbar déconnexion

lib/services/firebase_room_service.dart
  joinRoomByCode()    ← message explicite si status != 'waiting'

pubspec.yaml
  firebase_database: ^11.0.0
```

---

## Limitations connues et hors-scope

- **Délai de ~60s** avant élimination : inhérent à TCP, non contournable sans
  heartbeat applicatif (complexifie l'implémentation, hors-scope de ce guide).
- **Reconnexion volontaire** : intentionnellement non supportée. Si l'utilisateur
  veut rejouer, il crée une nouvelle partie.
- **Mode spectateur** : non supporté. Un joueur éliminé voit le GameOverSheet.
- **Cloud Functions billing** : sur le plan Spark (gratuit), les Cloud Functions
  ne sont PAS disponibles. Passer au plan Blaze (pay-as-you-go, très faible coût
  pour ce volume).
