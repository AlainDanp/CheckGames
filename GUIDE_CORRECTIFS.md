# Guide des Correctifs — CheckGames

> **5 bugs prioritaires** à corriger manuellement.  
> Chaque section indique : le fichier exact, le code actuel, le code corrigé et l'explication.

---

## Bug 01 — Race condition dans `_maybeTriggerBot`

**Fichier :** `lib/Bloc/checkgames_bloc.dart` — ligne ~605  
**Gravité :** CRITIQUE — le bot peut agir sur un état obsolète ou jouer alors que ce n'est plus son tour.

### Problème

`_maybeTriggerBot` vérifie `state.currentPlayerIndex` **avant** le délai, mais à l'intérieur du `Future.delayed`, `state` est réévalué au moment de l'exécution — qui peut être différent. Si le joueur humain joue rapidement, l'index a changé mais le bot s'exécute quand même.

```dart
// ❌ ACTUEL
void _maybeTriggerBot() {
  final humanIndex = state.players.indexWhere((p) => p.id == humanPlayerId);

  if (state.players.isEmpty) return;
  if (state.currentPlayerIndex == humanIndex) return;
  if (state.isPaused) return;

  final delayMs = GameSettingsService.instance.botDelayMs;

  Future.delayed(Duration(milliseconds: delayMs), () {
    // ⚠️ state.currentPlayerIndex peut avoir changé depuis l'appel
    if (state.players.isNotEmpty && state.currentPlayerIndex != 0 && !state.isPaused) {
      add(const BotActionRequested());
    }
  });
}
```

### Correctif

Capturer le numéro de tour (**snapshot**) au moment de l'appel, et le comparer au moment de l'exécution pour détecter un changement d'état.

```dart
// ✅ CORRIGÉ
void _maybeTriggerBot() {
  if (state.players.isEmpty) return;

  final humanIndex = state.players.indexWhere((p) => p.id == humanPlayerId);
  if (state.currentPlayerIndex == humanIndex) return;
  if (state.isPaused) return;
  if (state.isGameOver) return;

  // Capturer les valeurs ACTUELLES avant le délai
  final expectedPlayerIndex = state.currentPlayerIndex;
  final expectedPlayerId = state.players[expectedPlayerIndex].id;
  final delayMs = GameSettingsService.instance.botDelayMs;

  Future.delayed(Duration(milliseconds: delayMs), () {
    if (isClosed) return;

    // Vérifier que le tour n'a pas changé pendant le délai
    if (state.players.isEmpty) return;
    if (state.isGameOver) return;
    if (state.isPaused) return;
    if (state.currentPlayerIndex != expectedPlayerIndex) return;
    if (state.players[state.currentPlayerIndex].id != expectedPlayerId) return;
    if (state.currentPlayerIndex == humanIndex) return;

    add(const BotActionRequested());
  });
}
```

---

## Bug 03 — Imposition Valet non consommée en mode cumulus

**Fichier :** `lib/Bloc/checkgames_bloc.dart` — ligne ~114 (branche cumulus de `_onPlayCard`)  
**Gravité :** MOYEN — après une chaîne 7/Joker, la couleur imposée par un Valet peut rester active à tort.

### Problème

Quand un joueur joue un Valet (imposant ex. Cœur), puis qu'un 7 ou Joker est joué en cumulus, la branche cumulus émet un nouvel état **sans réinitialiser `imposedSuit`**. Après résolution du cumulus, la couleur Cœur reste imposée alors qu'elle ne devrait plus l'être.

```dart
// ❌ ACTUEL — branche cumulus (~ligne 114)
if (state.cardsToDraw > 0) {
  // ...
  emit(state.copyWith(
    players: players,
    discardPile: discard,
    drawPile: drawPile,
    currentPlayerIndex: nextIndex,
    cardsToDraw: draw,
    skipCount: 0,
    lastChecksPlayerId: checksPlayerId,
    previousPlayerIndex: state.currentPlayerIndex,
    lastDrawPlayerId: null,
    // ⚠️ imposedSuit non réinitialisé → reste actif après la chaîne
  ));
  return;
}
```

### Correctif

Dans la branche cumulus, forcer `imposedSuit` à `null` puisqu'un 7 ou Joker joué en contre-attaque annule implicitement toute imposition active.

```dart
// ✅ CORRIGÉ
if (state.cardsToDraw > 0) {
  // ...
  emit(state.copyWith(
    players: players,
    discardPile: discard,
    drawPile: drawPile,
    currentPlayerIndex: nextIndex,
    cardsToDraw: draw,
    skipCount: 0,
    imposedSuit: null, // ← Un 7/Joker en cumulus annule toute imposition
    lastChecksPlayerId: checksPlayerId,
    previousPlayerIndex: state.currentPlayerIndex,
    lastDrawPlayerId: null,
  ));
  return;
}
```

---

## Bug 05 — Tour bloqué quand le joueur courant quitte la partie

**Fichier :** `lib/services/firebase_room_service.dart` — méthode `leaveActiveGame`, ligne ~266  
**Gravité :** CRITIQUE — si c'est le tour du joueur qui quitte, `currentPlayerId` dans Firestore ne change jamais → la partie se bloque.

### Problème

`leaveActiveGame` retire le joueur de `playerOrder` et de `players`, mais **ne met jamais à jour `currentPlayerId`** dans le document `game_rooms/{roomId}`. Si ce champ pointe encore vers le joueur parti, personne ne peut jouer.

```dart
// ❌ ACTUEL — leaveActiveGame (~ligne 271)
await _firestore.runTransaction((transaction) async {
  // ...
  playerOrder.remove(playerId);

  // ⚠️ currentPlayerId dans roomDoc n'est jamais mis à jour
  // Si c'était son tour, la partie est bloquée indéfiniment

  transaction.update(
    roomRef.collection('game_state').doc('current'),
    {
      'playerOrder': playerOrder,
      'finishingOrder': finishingOrder,
      // ...
    },
  );
});
```

### Correctif

Après avoir retiré le joueur, vérifier si `currentPlayerId == playerId`. Si oui, calculer le prochain joueur actif et mettre à jour `currentPlayerId`.

```dart
// ✅ CORRIGÉ — dans leaveActiveGame, après playerOrder.remove(playerId)

// Récupérer le joueur courant AVANT de modifier playerOrder
final currentPlayerId = roomData['currentPlayerId'] as String? ?? '';

// Retirer le joueur
playerOrder.remove(playerId);

// Ajouter à finishingOrder s'il n'y est pas déjà
if (!finishingOrder.contains(playerId)) {
  finishingOrder.add(playerId);
}

// Si c'était son tour → passer au prochain joueur actif
String? nextPlayerId;
if (currentPlayerId == playerId && playerOrder.isNotEmpty) {
  // Trouver le prochain joueur actif dans playerOrder
  final actifs = playerOrder.where((id) => !finishingOrder.contains(id)).toList();
  if (actifs.isNotEmpty) {
    nextPlayerId = actifs.first;
    appLogger.d('Tour passé à $nextPlayerId après départ de $playerId');
  }
}

// ...
// Dans le transaction.update du roomDoc, ajouter nextPlayerId si calculé :
final roomUpdate = <String, dynamic>{
  'updatedAt': FieldValue.serverTimestamp(),
};
if (nextPlayerId != null) {
  roomUpdate['currentPlayerId'] = nextPlayerId;
}

transaction.update(roomRef, roomUpdate);
```

> **Note :** intégrer ce bloc dans la transaction existante, juste après le `playerOrder.remove(playerId)` actuel (ligne ~298). Le `roomUpdate` final doit être fusionné avec les updates existants sur `roomRef` (status, hostId, etc.).

---

## Bug 06 — Overlay CHECKS inséré sans vérifier que le context est encore valide

**Fichier :** `lib/ui/game_page.dart` — méthode `_showChecksOverlay`, ligne ~113  
**Gravité :** MOYEN — si le joueur quitte la page pendant l'animation CHECKS (ex. appui sur retour), l'insertion dans l'Overlay crashe ou laisse un overlay orphelin.

### Problème

La méthode vérifie `mounted` en entrée et dans le callback `onComplete`, mais **pas juste avant `Overlay.of(context).insert()`**. Entre le `setState` et l'insert, l'utilisateur peut avoir navigué, invalidant le context.

```dart
// ❌ ACTUEL
void _showChecksOverlay(String playerName) {
  if (!mounted || _isShowingChecks) return;

  // ...
  setState(() { _isShowingChecks = true; });
  bloc.add(const SetPaused(true));

  late OverlayEntry overlayEntry;
  overlayEntry = OverlayEntry(
    builder: (context) => Material(
      color: Colors.black.withOpacity(0.3),
      child: Center(
        child: ChecksOverlay(
          playerName: playerName,
          onComplete: () {
            if (mounted) {
              overlayEntry.remove();
              setState(() { _isShowingChecks = false; });
              bloc.add(const SetPaused(false));
            }
            // ⚠️ Si non mounted : l'overlay reste en mémoire, isPaused reste true
          },
        ),
      ),
    ),
  );

  Overlay.of(context).insert(overlayEntry); // ⚠️ context peut être invalide ici
}
```

### Correctif

Revérifier `mounted` juste avant l'insert, et dans `onComplete` nettoyer l'état même si le widget n'est plus monté (pour éviter un BLoC bloqué en pause).

```dart
// ✅ CORRIGÉ
void _showChecksOverlay(String playerName) {
  if (!mounted || _isShowingChecks) return;

  AudioService.instance.playChecks();
  final bloc = context.read<Bloc<CheckgamesEvent, CheckgamesState>>();

  setState(() { _isShowingChecks = true; });
  bloc.add(const SetPaused(true));

  late OverlayEntry overlayEntry;
  overlayEntry = OverlayEntry(
    builder: (context) => Material(
      color: Colors.black.withOpacity(0.3),
      child: Center(
        child: ChecksOverlay(
          playerName: playerName,
          onComplete: () {
            overlayEntry.remove(); // Toujours retirer l'overlay
            if (mounted) {
              setState(() { _isShowingChecks = false; });
            } else {
              _isShowingChecks = false; // Mise à jour directe si non monté
            }
            // Toujours débloquer le BLoC, monté ou non
            if (!bloc.isClosed) {
              bloc.add(const SetPaused(false));
            }
          },
        ),
      ),
    ),
  );

  // Vérifier une dernière fois avant d'insérer
  if (!mounted) {
    _isShowingChecks = false;
    if (!bloc.isClosed) bloc.add(const SetPaused(false));
    return;
  }

  Overlay.of(context).insert(overlayEntry);
}
```

---

## Bug 09 — Animation bot déclenchée sur un widget disposé

**Fichier :** `lib/ui/game_page.dart` — `BlocListener` animation bot, ligne ~396  
**Gravité :** MOYEN — si l'utilisateur quitte la partie pendant le tour d'un bot, le `addPostFrameCallback` s'exécute après la destruction du widget et peut crasher (RenderObject détruit, Overlay invalide).

### Problème

Le `BlocListener` enregistre un `addPostFrameCallback` sans vérifier `mounted` au moment où le callback s'exécute. Entre l'enregistrement et l'exécution (frame suivante), le widget peut avoir été détruit.

```dart
// ❌ ACTUEL
BlocListener<Bloc<CheckgamesEvent, CheckgamesState>, CheckgamesState>(
  listenWhen: (prev, curr) => curr.discardPile.length > prev.discardPile.length,
  listener: (ctx, state) {
    if (_skipNextBotAnimation) {
      _skipNextBotAnimation = false;
      return;
    }
    if (state.previousPlayerIndex != null && state.previousPlayerIndex! > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) =>
          // ⚠️ mounted non vérifié ici : widget peut être disposé
          _animateBotCard(
            state.players[state.previousPlayerIndex!].id,
            state.discardPile.last,
          ));
    }
  },
),
```

Même problème sur le listener pioche (~ligne 410) :

```dart
// ❌ ACTUEL
BlocListener<Bloc<CheckgamesEvent, CheckgamesState>, CheckgamesState>(
  listenWhen: (prev, curr) =>
      curr.lastDrawPlayerId != null &&
      curr.lastDrawPlayerId != prev.lastDrawPlayerId,
  listener: (ctx, state) => WidgetsBinding.instance.addPostFrameCallback((_) =>
      // ⚠️ mounted non vérifié
      _animateDrawCards(state.lastDrawPlayerId!, state.lastDrawCount)),
),
```

### Correctif

Ajouter un guard `if (!mounted) return;` **à l'intérieur** du callback, pas avant l'enregistrement.

```dart
// ✅ CORRIGÉ — listener animation bot
BlocListener<Bloc<CheckgamesEvent, CheckgamesState>, CheckgamesState>(
  listenWhen: (prev, curr) => curr.discardPile.length > prev.discardPile.length,
  listener: (ctx, state) {
    if (_skipNextBotAnimation) {
      _skipNextBotAnimation = false;
      return;
    }
    if (state.previousPlayerIndex != null && state.previousPlayerIndex! > 0) {
      final botId = state.players[state.previousPlayerIndex!].id;
      final topCard = state.discardPile.last;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return; // ← guard ajouté
        _animateBotCard(botId, topCard);
      });
    }
  },
),

// ✅ CORRIGÉ — listener animation pioche
BlocListener<Bloc<CheckgamesEvent, CheckgamesState>, CheckgamesState>(
  listenWhen: (prev, curr) =>
      curr.lastDrawPlayerId != null &&
      curr.lastDrawPlayerId != prev.lastDrawPlayerId,
  listener: (ctx, state) {
    final drawPlayerId = state.lastDrawPlayerId!;
    final drawCount = state.lastDrawCount;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return; // ← guard ajouté
      _animateDrawCards(drawPlayerId, drawCount);
    });
  },
),
```

> **Pourquoi capturer `botId`, `topCard`, etc. avant le callback ?**  
> Le `state` passé au `listener` est valide au moment de l'appel mais peut changer avant la frame suivante. Capturer les valeurs nécessaires immédiatement évite de lire un état potentiellement différent dans le callback.

---

## Récapitulatif

| # | Bug | Fichier | Priorité |
|---|-----|---------|----------|
| 01 | Race condition `_maybeTriggerBot` | `checkgames_bloc.dart` | CRITIQUE |
| 03 | Imposition Valet non consommée en cumulus | `checkgames_bloc.dart` | MOYEN |
| 05 | Tour bloqué si le joueur courant quitte | `firebase_room_service.dart` | CRITIQUE |
| 06 | Overlay CHECKS avec context invalide | `game_page.dart` | MOYEN |
| 09 | Animation bot sur widget disposé | `game_page.dart` | MOYEN |
