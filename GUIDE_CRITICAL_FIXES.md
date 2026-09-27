# Guide de correction des problèmes critiques — CheckGames

> **Portée :** Ce guide couvre les 4 problèmes critiques identifiés dans l'analyse qualité.
> Chaque section indique les fichiers concernés, le code exact à modifier et la vérification.

---

## Table des matières

1. [Remplacer les `print()` par un vrai logger](#1-remplacer-les-print-par-un-vrai-logger)
2. [Gérer les erreurs silencieuses](#2-gérer-les-erreurs-silencieuses)
3. [Corriger l'ID joueur codé en dur](#3-corriger-lid-joueur-codé-en-dur)
4. [Afficher les erreurs à l'utilisateur](#4-afficher-les-erreurs-à-lutilisateur)

---

## 1. Remplacer les `print()` par un vrai logger

### Pourquoi c'est critique

- **Fuite d'informations** : les UIDs Firebase et emails apparaissent dans les logs de production
- **Flood console** : 71+ appels `print()` rendent le débogage illisible
- **Crashlytics ne capture pas** les `print()`, donc les erreurs importantes sont invisibles

### 1.1 — Ajouter le package `logger`

**Fichier : `pubspec.yaml`**

```yaml
dependencies:
  # ... dépendances existantes ...
  logger: ^2.4.0      # ← ajouter cette ligne
```

```bash
flutter pub get
```

### 1.2 — Créer un logger partagé

**Fichier à créer : `lib/utils/app_logger.dart`**

```dart
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:logger/logger.dart';

/// Logger singleton partagé dans toute l'app.
/// En release : niveau Warning uniquement (rien de sensible dans les logs).
/// En debug : tous les niveaux.
final appLogger = Logger(
  level: kReleaseMode ? Level.warning : Level.debug,
  printer: PrettyPrinter(
    methodCount: 1,
    errorMethodCount: 5,
    lineLength: 80,
    colors: true,
    printEmojis: true,
  ),
);
```

### 1.3 — Remplacer les `print()` fichier par fichier

#### `lib/services/firebase_auth_service.dart`

Remplacer l'import et tous les `print()` :

```dart
// AVANT (ligne 1)
// aucun import de logger

// APRÈS
import '../utils/app_logger.dart';
```

| Ligne | Avant | Après |
|-------|-------|-------|
| 21 | `print('🔐 Tentative inscription: $email');` | `appLogger.d('Tentative inscription');` |
| 26 | `print('✅ Utilisateur créé: ${userCredential.user?.uid}');` | `appLogger.i('Utilisateur créé');` |
| 39 | `print('✅ Profil utilisateur créé dans Firestore');` | `appLogger.i('Profil Firestore créé');` |
| 41 | `print('⚠️ Erreur Firestore (profil non créé): $firestoreError');` | `appLogger.w('Profil Firestore non créé', error: firestoreError);` |
| 47 | `print('❌ Erreur inscription: $e');` | `appLogger.e('Erreur inscription', error: e);` |
| 58 | `print('🔐 Tentative connexion: $email');` | `appLogger.d('Tentative connexion');` |
| 63 | `print('✅ Connexion réussie: ${userCredential.user?.uid}');` | `appLogger.i('Connexion réussie');` |
| 70 | `print('✅ lastSeen mis à jour');` | `appLogger.d('lastSeen mis à jour');` |
| 72 | `print('⚠️ Erreur mise à jour lastSeen: $firestoreError');` | `appLogger.w('Erreur lastSeen', error: firestoreError);` |
| 78 | `print('❌ Erreur connexion: $e');` | `appLogger.e('Erreur connexion', error: e);` |
| 86 | `print('🔐 Tentative connexion anonyme');` | `appLogger.d('Tentative connexion anonyme');` |
| 88 | `print('✅ Connexion anonyme réussie: ${userCredential.user?.uid}');` | `appLogger.i('Connexion anonyme réussie');` |
| 102 | `print('✅ Profil anonyme créé: $generatedUsername');` | `appLogger.i('Profil anonyme créé');` |
| 104 | `print('⚠️ Erreur Firestore (profil anonyme non créé): $firestoreError');` | `appLogger.w('Profil anonyme Firestore non créé', error: firestoreError);` |
| 110 | `print('❌ Erreur connexion anonyme: $e');` | `appLogger.e('Erreur connexion anonyme', error: e);` |
| 123 | `print('📖 Lecture profil: $userId');` | `appLogger.d('Lecture profil utilisateur');` |
| 127 | `print('⚠️ Profil non trouvé, création d\'un profil par défaut');` | `appLogger.w('Profil non trouvé, création par défaut');` |
| 144 | `print('✅ Profil récupéré: ${data?[\'username\']}');` | `appLogger.d('Profil récupéré');` |
| 147 | `print('❌ Erreur lecture profil: $e');` | `appLogger.e('Erreur lecture profil', error: e);` |

> **Règle impérative** : ne jamais passer `userId`, `email`, `uid` ou toute donnée personnelle
> en paramètre du logger. Les messages doivent rester génériques.

#### `lib/services/local_notification_service.dart`

**Ligne 355 :**
```dart
// AVANT
print('✅ 12 rappels programmés (toutes les 2h)');

// APRÈS
import '../utils/app_logger.dart'; // en haut du fichier

appLogger.i('12 rappels programmés');
```

#### `lib/main.dart`

Les deux `print()` restants dans `main()` :

```dart
// AVANT
print('Erreur Firebase: $e');
print('Firebase/Notifications skipped on: ${Platform.operatingSystem}');

// APRÈS
import 'utils/app_logger.dart';

appLogger.e('Erreur initialisation Firebase', error: e);
appLogger.d('Firebase ignoré sur cette plateforme');
```

### 1.4 — Vérification

```bash
# Doit retourner 0 résultat après correction complète
grep -r "^\s*print(" lib/
```

```bash
flutter analyze
```

---

## 2. Gérer les erreurs silencieuses

### Pourquoi c'est critique

Dans `checkgame_repository.dart`, les erreurs Hive sont avalées sans trace.
Si la sauvegarde échoue, le joueur perd ses stats sans le savoir.

### 2.1 — `lib/repository/checkgame_repository.dart`

#### Méthode `savePlayerStats` (lignes 40–51)

```dart
// AVANT
Future<void> savePlayerStats(PlayerStats stats) async {
  if (_statsBox == null) {
    return;
  }
  try {
    await _statsBox!.put(stats.playerName, stats);
  } catch (e) {
    // Ignorer les erreurs silencieusement (on pourrait logger ici)
    return;
  }
}

// APRÈS
Future<void> savePlayerStats(PlayerStats stats) async {
  if (_statsBox == null) {
    appLogger.w('savePlayerStats: box non initialisée');
    return;
  }
  try {
    await _statsBox!.put(stats.playerName, stats);
  } catch (e, stack) {
    appLogger.e('Échec sauvegarde stats', error: e, stackTrace: stack);
    rethrow; // ← laisser remonter pour que l'appelant puisse réagir
  }
}
```

#### Méthode `saveGameHistory` (lignes 64–80)

```dart
// AVANT
Future<void> saveGameHistory(GameHistory history) async {
  if (_historyBox == null) {
    return;
  }
  try {
    await _historyBox!.add(history);
    if (_historyBox!.length > 50) {
      await _historyBox!.deleteAt(0);
    }
  } catch (e) {
    // Ignorer les erreurs silencieusement
    return;
  }
}

// APRÈS
Future<void> saveGameHistory(GameHistory history) async {
  if (_historyBox == null) {
    appLogger.w('saveGameHistory: box non initialisée');
    return;
  }
  try {
    await _historyBox!.add(history);
    if (_historyBox!.length > 50) {
      await _historyBox!.deleteAt(0);
    }
  } catch (e, stack) {
    appLogger.e('Échec sauvegarde historique', error: e, stackTrace: stack);
    // Pas de rethrow ici : perdre l'historique est non-bloquant pour l'utilisateur
  }
}
```

#### Ajouter l'import en haut du fichier

```dart
import '../utils/app_logger.dart';
```

### 2.2 — `lib/Bloc/checkgames_bloc.dart` — sauvegardes en fin de partie

Les appels `repository.saveGameHistory(...)` et `repository.recordGameResult(...)`
(lignes ~271–288 et ~322–340) ne gèrent pas les erreurs. Entourer chaque bloc :

```dart
// AVANT (exemple lignes 271-276)
repository.saveGameHistory(GameHistory(
  date: DateTime.now(),
  playerNames: playerNames,
  finishingOrder: order,
  hadDuel: true,
));

// APRÈS
try {
  await repository.saveGameHistory(GameHistory(
    date: DateTime.now(),
    playerNames: playerNames,
    finishingOrder: order,
    hadDuel: true,
  ));
} catch (e) {
  appLogger.e('Sauvegarde historique échouée (fin duel)', error: e);
}
```

> Faire la même chose pour les deux blocs `recordGameResult` et les deux blocs
> `saveGameHistory` présents dans `_onPlayCard`.

### 2.3 — Vérification

```bash
# Plus aucun catch vide
grep -n "catch (e)" lib/repository/checkgame_repository.dart
```

Chaque `catch` doit contenir au minimum un `appLogger.e(...)`.

---

## 3. Corriger l'ID joueur codé en dur

### Pourquoi c'est critique

```dart
// lib/Bloc/checkgames_bloc.dart — ligne 173
if (event.playerId == '0') {
```

Ce test suppose que le joueur humain a **toujours** l'ID `'0'`. En mode multijoueur
ou si l'ordre des joueurs change, ce test est faux et le message d'erreur ne
s'affiche plus (ou s'affiche pour le mauvais joueur).

### 3.1 — Identifier le joueur humain par son rôle, pas son ID

#### Approche recommandée : passer `humanPlayerId` au BLoC

**`lib/Bloc/checkgames_bloc.dart`**

```dart
// AVANT
class CheckGameBloc extends Bloc<CheckgamesEvent, CheckgamesState> {
  final CheckgameRepository repository;
  final AnalyticsService _analytics = AnalyticsService();

  CheckGameBloc({required this.repository}) : super(const CheckgamesState()) {

// APRÈS
class CheckGameBloc extends Bloc<CheckgamesEvent, CheckgamesState> {
  final CheckgameRepository repository;
  final String humanPlayerId;          // ← nouveau champ
  final AnalyticsService _analytics = AnalyticsService();

  CheckGameBloc({
    required this.repository,
    this.humanPlayerId = '0',          // ← '0' reste le défaut en solo
  }) : super(const CheckgamesState()) {
```

#### Utiliser `humanPlayerId` dans `_onPlayCard`

```dart
// AVANT (ligne ~173)
if (event.playerId == '0') {

// APRÈS
if (event.playerId == humanPlayerId) {
```

#### Mettre à jour `_maybeTriggerBot`

```dart
// AVANT (ligne ~576)
if (state.currentPlayerIndex == 0) return; // joueur humain

// APRÈS — retrouver l'index du joueur humain dynamiquement
final humanIndex = state.players.indexWhere((p) => p.id == humanPlayerId);
if (state.currentPlayerIndex == humanIndex) return;
```

### 3.2 — Mettre à jour les constructeurs appelants

Partout où `CheckGameBloc` est instancié, le comportement par défaut (`humanPlayerId = '0'`)
reste identique — **aucune modification requise dans les écrans existants**.

Pour le futur mode multijoueur, passer l'UID Firebase :

```dart
// Exemple dans un écran multijoueur futur
CheckGameBloc(
  repository: widget.repository,
  humanPlayerId: FirebaseAuth.instance.currentUser?.uid ?? '0',
)
```

### 3.3 — Vérification

```bash
grep -n "playerId == '0'" lib/
grep -n "currentPlayerIndex == 0" lib/Bloc/checkgames_bloc.dart
```

Les deux commandes doivent retourner **0 résultat**.

```bash
flutter analyze
flutter test
```

---

## 4. Afficher les erreurs à l'utilisateur

### Pourquoi c'est critique

Actuellement, quand une opération échoue (sauvegarde Hive, Firebase init, etc.),
l'utilisateur ne voit rien. Il ne sait pas pourquoi le jeu se comporte de façon
inattendue.

### 4.1 — Créer un helper `AppSnackbar`

**Fichier à créer : `lib/utils/app_snackbar.dart`**

```dart
import 'package:flutter/material.dart';

/// Affiche des messages contextuels cohérents dans toute l'app.
/// Utilisation : AppSnackbar.error(context, 'Message');
abstract class AppSnackbar {
  static void error(BuildContext context, String message) {
    _show(context, message, backgroundColor: const Color(0xFFB00020));
  }

  static void warning(BuildContext context, String message) {
    _show(context, message, backgroundColor: const Color(0xFFF57C00));
  }

  static void info(BuildContext context, String message) {
    _show(context, message, backgroundColor: const Color(0xFF1565C0));
  }

  static void _show(
    BuildContext context,
    String message, {
    required Color backgroundColor,
  }) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(color: Colors.white)),
          backgroundColor: backgroundColor,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
  }
}
```

### 4.2 — Gérer les erreurs Firebase dans `main.dart`

L'initialisation Firebase échoue silencieusement. Comme `main()` s'exécute avant
tout widget, on ne peut pas afficher de snackbar ici — mais on peut afficher
une bannière dans `MyApp` si Firebase n'est pas disponible.

**`lib/main.dart`**

```dart
// AVANT
runApp(MyApp(repository: repository));

// APRÈS
bool firebaseOk = true;
if (isMobile) {
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    appLogger.e('Erreur initialisation Firebase', error: e);
    firebaseOk = false;
  }
}

runApp(MyApp(repository: repository, firebaseAvailable: firebaseOk));
```

**`lib/main.dart` — classe `MyApp`**

```dart
class MyApp extends StatefulWidget {
  final CheckgameRepository repository;
  final bool firebaseAvailable;   // ← nouveau paramètre

  const MyApp({
    super.key,
    required this.repository,
    this.firebaseAvailable = true,
  });
  // ...
}
```

Dans `build()`, afficher une bannière si Firebase est indisponible :

```dart
@override
Widget build(BuildContext context) {
  return MaterialApp(
    navigatorKey: _navigatorKey,
    debugShowCheckedModeBanner: false,
    title: 'checkgames',
    theme: AppTheme.lightTheme,
    builder: widget.firebaseAvailable
        ? null
        : (context, child) => Column(
              children: [
                MaterialBanner(
                  content: const Text(
                    'Mode hors-ligne — Le multijoueur est indisponible.',
                    style: TextStyle(color: Colors.white),
                  ),
                  backgroundColor: const Color(0xFFF57C00),
                  actions: [
                    TextButton(
                      onPressed: () =>
                          ScaffoldMessenger.of(context).hideCurrentMaterialBanner(),
                      child: const Text('OK', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
                Expanded(child: child ?? const SizedBox()),
              ],
            ),
    home: SplashScreen(
      nextScreen: StartupRouter(repository: widget.repository),
    ),
    // ... reste inchangé
  );
}
```

### 4.3 — Erreur de sauvegarde en fin de partie

**`lib/Bloc/checkgames_bloc.dart`**

Le BLoC ne peut pas afficher de UI directement. La bonne approche est d'émettre
un état portant un flag `saveError` que l'écran de résultat affiche.

**`lib/Bloc/checkgames_state.dart`** — ajouter un champ :

```dart
// Dans CheckgamesState, ajouter :
final bool saveError;

// Dans le constructeur :
const CheckgamesState({
  // ... champs existants ...
  this.saveError = false,
});

// Dans copyWith :
CheckgamesState copyWith({
  // ... paramètres existants ...
  bool? saveError,
}) {
  return CheckgamesState(
    // ... champs existants ...
    saveError: saveError ?? this.saveError,
  );
}
```

**`lib/Bloc/checkgames_bloc.dart`** — dans les blocs de sauvegarde :

```dart
try {
  await repository.saveGameHistory(/* ... */);
  for (int i = 0; i < order.length; i++) {
    await repository.recordGameResult(/* ... */);
  }
} catch (e) {
  appLogger.e('Sauvegarde fin de partie échouée', error: e);
  emit(state.copyWith(
    // ... autres champs de fin de partie ...
    saveError: true,
  ));
  return;
}

emit(state.copyWith(
  // ... champs de fin de partie normaux ...
  saveError: false,
));
```

**`lib/ui/game_page.dart`** — dans le `BlocListener` existant, réagir à `saveError` :

```dart
BlocListener<CheckGameBloc, CheckgamesState>(
  listenWhen: (prev, curr) =>
      curr.saveError && !prev.saveError,
  listener: (context, state) {
    AppSnackbar.warning(
      context,
      'Résultats non sauvegardés — vérifiez votre espace de stockage.',
    );
  },
  // ...
)
```

Ajouter l'import en haut de `game_page.dart` :

```dart
import '../utils/app_snackbar.dart';
```

### 4.4 — Erreurs Firebase Auth dans `auth_screen.dart`

Si l'écran d'authentification ne gère pas déjà les erreurs Firebase :

```dart
// Exemple pattern à appliquer dans les boutons de connexion/inscription
try {
  await FirebaseAuthService().signIn(email: email, password: password);
} on FirebaseAuthException catch (e) {
  if (!context.mounted) return;
  final message = switch (e.code) {
    'user-not-found'  => 'Aucun compte avec cet email.',
    'wrong-password'  => 'Mot de passe incorrect.',
    'too-many-requests' => 'Trop de tentatives. Réessayez plus tard.',
    _ => 'Erreur de connexion. Réessayez.',
  };
  AppSnackbar.error(context, message);
} catch (e) {
  if (!context.mounted) return;
  AppSnackbar.error(context, 'Erreur inattendue. Réessayez.');
}
```

---

## Checklist de vérification finale

### Commandes à lancer dans l'ordre

```bash
# 1. Aucun print() restant dans lib/
grep -rn "^\s*print(" lib/

# 2. Aucun catch vide restant
grep -rn "catch (e) {" lib/

# 3. Analyse statique
flutter analyze

# 4. Tests unitaires
flutter test
```

### Tests manuels à effectuer

| Scénario | Résultat attendu |
|----------|-----------------|
| Lancer l'app en mode debug | Logs visibles dans la console avec niveaux colorés |
| Lancer l'app en mode release | Seuls les warnings/erreurs apparaissent dans les logs |
| Désactiver le réseau, lancer l'app | Bannière "Mode hors-ligne" visible |
| Jouer une partie et gagner | Pas de crash, message d'erreur si la sauvegarde échoue |
| Jouer une carte invalide (joueur humain) | Message d'erreur "Manœuvre impossible" visible |
| Jouer une carte invalide (bot) | Aucun message visible (comportement inchangé) |

---

## Résumé des fichiers modifiés

| Fichier | Action |
|---------|--------|
| `pubspec.yaml` | Ajouter `logger: ^2.4.0` |
| `lib/utils/app_logger.dart` | **Créer** — singleton logger |
| `lib/utils/app_snackbar.dart` | **Créer** — helper snackbar |
| `lib/services/firebase_auth_service.dart` | Remplacer 19 `print()` |
| `lib/services/local_notification_service.dart` | Remplacer 1 `print()` |
| `lib/main.dart` | Remplacer 2 `print()`, passer `firebaseAvailable` |
| `lib/repository/checkgame_repository.dart` | Logger les erreurs + `rethrow` sur stats |
| `lib/Bloc/checkgames_state.dart` | Ajouter `saveError` |
| `lib/Bloc/checkgames_bloc.dart` | `humanPlayerId`, try/catch sauvegardes, `saveError` |
| `lib/ui/game_page.dart` | Écouter `saveError`, afficher snackbar |

---

## Ordre d'implémentation recommandé

```
Étape 1 ── Créer app_logger.dart et app_snackbar.dart (10 min)
Étape 2 ── Remplacer tous les print() (20 min)
             → firebase_auth_service.dart
             → local_notification_service.dart
             → main.dart
Étape 3 ── Corriger checkgame_repository.dart (15 min)
Étape 4 ── Corriger l'ID joueur dans checkgames_bloc.dart (15 min)
Étape 5 ── Ajouter saveError dans state + bloc (20 min)
Étape 6 ── Brancher AppSnackbar dans game_page.dart (10 min)
Étape 7 ── flutter analyze + flutter test + tests manuels (20 min)
```

**Durée totale estimée : ~2 heures**
