# Guide de Migration: CheckGames Flutter → React Native TypeScript

## Table des Matières

1. [Vue d'ensemble](#vue-densemble)
2. [Setup Projet React Native](#setup-projet-react-native)
3. [Architecture & State Management](#architecture--state-management)
4. [Migration des Modèles de Données](#migration-des-modèles-de-données)
5. [Migration de la Logique Métier](#migration-de-la-logique-métier)
6. [Migration du Stockage Local](#migration-du-stockage-local)
7. [Configuration Firebase](#configuration-firebase)
8. [Migration des Services](#migration-des-services)
9. [Migration des Composants UI](#migration-des-composants-ui)
10. [Navigation & Écrans](#navigation--écrans)
11. [Animations](#animations)
12. [Audio](#audio)
13. [Tests](#tests)
14. [Ordre de Migration Recommandé](#ordre-de-migration-recommandé)

---

## Vue d'ensemble

### Statistiques du Projet

- **41 fichiers Dart** à migrer
- **2 BLoCs** (CheckGameBloc: 697 lignes, MultiplayerGameBloc: 493 lignes)
- **7 Services** (Auth, Room, GameMaster, GameAction, Audio, Animation, GameSync)
- **10 Widgets** réutilisables
- **6 Écrans** principaux
- **Firebase** (Auth, Firestore, Storage)

### Mapping Global des Technologies

| Flutter | React Native TypeScript |
|---------|------------------------|
| **State Management** | |
| flutter_bloc | Redux Toolkit + react-redux |
| BlocBuilder | useSelector hook |
| BlocListener | useEffect + useSelector |
| equatable | TypeScript interfaces |
| **Storage** | |
| Hive | react-native-mmkv (recommandé) |
| Hive adapters | JSON.parse/stringify |
| **Firebase** | |
| firebase_core | @react-native-firebase/app |
| firebase_auth | @react-native-firebase/auth |
| cloud_firestore | @react-native-firebase/firestore |
| **Audio** | |
| audioplayers | react-native-sound ou expo-av |
| **Navigation** | |
| Navigator.push | React Navigation |
| **UI/Animations** | |
| Widgets | React Components |
| AnimatedBuilder | react-native-reanimated v3 |
| LayoutBuilder | useWindowDimensions |
| **Utils** | |
| GlobalKey | useRef |
| MediaQuery | useWindowDimensions |

---

## Setup Projet React Native

### Option 1: Expo (Recommandé pour démarrer)

```bash
# Créer le projet
npx create-expo-app checkgames-rn --template expo-template-blank-typescript

cd checkgames-rn

# Installer les dépendances de base
npm install @reduxjs/toolkit react-redux
npm install @react-navigation/native @react-navigation/stack @react-navigation/bottom-tabs
npm install expo-av # Pour l'audio
npm install react-native-mmkv # Pour le storage

# Firebase
npm install @react-native-firebase/app @react-native-firebase/auth @react-native-firebase/firestore

# UI & Animations
npm install react-native-reanimated react-native-gesture-handler
npm install @gorhom/bottom-sheet
npm install react-native-safe-area-context react-native-screens

# Dev dependencies
npm install --save-dev @testing-library/react-native @testing-library/jest-native
```

### Option 2: React Native CLI (Plus de contrôle)

```bash
npx react-native init CheckGamesRN --template react-native-template-typescript

cd CheckGamesRN

# Installer les mêmes dépendances qu'au dessus (sauf expo-av, utiliser react-native-sound)
npm install react-native-sound
```

### Structure de Dossiers Recommandée

```
src/
├── store/                   # Redux Toolkit (remplace Bloc/)
│   ├── slices/
│   │   ├── gameSlice.ts
│   │   └── multiplayerSlice.ts
│   └── index.ts
├── types/                   # TypeScript types (remplace models/)
│   ├── card.types.ts
│   ├── player.types.ts
│   ├── game.types.ts
│   └── stats.types.ts
├── utils/
│   ├── gameLogic/          # Pure functions (remplace logic/)
│   │   ├── ruleEngine.ts
│   │   └── deckGenerator.ts
│   └── responsive.ts
├── services/               # Services externes
│   ├── storage/
│   │   ├── statsStorage.ts
│   │   └── historyStorage.ts
│   ├── firebase/
│   │   ├── auth.service.ts
│   │   ├── room.service.ts
│   │   ├── gameMaster.service.ts
│   │   └── gameAction.service.ts
│   ├── audio.service.ts
│   └── animation.service.ts
├── components/             # Composants réutilisables (remplace view/widgets/)
│   ├── PlayingCard.tsx
│   ├── HandFan.tsx
│   ├── TableWidgets.tsx
│   ├── SuitPickerSheet.tsx
│   ├── GameOverSheet.tsx
│   ├── ChecksOverlay.tsx
│   ├── PauseMenu.tsx
│   └── ErrorMessage.tsx
├── screens/               # Écrans (remplace ui/)
│   ├── MainMenuScreen.tsx
│   ├── AuthScreen.tsx
│   ├── MultiplayerLobbyScreen.tsx
│   ├── WaitingRoomScreen.tsx
│   ├── GameScreen.tsx
│   └── MultiplayerGameScreen.tsx
├── navigation/
│   └── AppNavigator.tsx
├── assets/
│   ├── audio/
│   └── images/
└── App.tsx
```

---

## Architecture & State Management

### BLoC → Redux Toolkit

#### Flutter BLoC Pattern (Avant)

```dart
// checkgames_bloc.dart
class CheckgamesBloc extends Bloc<CheckgamesEvent, CheckgamesState> {
  CheckgamesBloc(this._repository) : super(CheckgamesState.initial()) {
    on<StartGameEvent>(_onStartGame);
    on<PlayCardEvent>(_onPlayCard);
    on<DrawCardEvent>(_onDrawCard);
  }

  Future<void> _onStartGame(
    StartGameEvent event,
    Emitter<CheckgamesState> emit,
  ) async {
    // Logique...
    emit(state.copyWith(isGameOver: false));
  }
}

// Usage dans UI
BlocBuilder<CheckgamesBloc, CheckgamesState>(
  builder: (context, state) {
    return Text('Cards: ${state.players[0].hand.length}');
  },
)
```

#### React Native Redux (Après)

```typescript
// store/slices/gameSlice.ts
import { createSlice, PayloadAction } from '@reduxjs/toolkit';
import { GameState, Player, PlayingCard } from '../../types/game.types';

const initialState: GameState = {
  players: [],
  currentPlayerIndex: 0,
  drawPile: [],
  discardPile: [],
  isGameOver: false,
  skipCount: 0,
  cardsToDraw: 0,
  imposedSuit: null,
  phase: 'normal',
  finishingOrder: [],
  lastChecksPlayerId: null,
  isPaused: false,
  errorMessage: null,
};

const gameSlice = createSlice({
  name: 'game',
  initialState,
  reducers: {
    startGame: (state, action: PayloadAction<{ playerNames: string[] }>) => {
      // Logique d'initialisation
      const deck = generateFullDeck();
      const shuffled = shuffleDeck(deck);

      state.players = action.payload.playerNames.map((name, index) => ({
        id: `player_${index}`,
        name,
        hand: shuffled.slice(index * 5, (index + 1) * 5),
      }));

      state.drawPile = shuffled.slice(action.payload.playerNames.length * 5);
      state.discardPile = [state.drawPile.pop()!];
      state.isGameOver = false;
    },

    playCard: (state, action: PayloadAction<{ playerId: string; cardIndex: number; chosenSuit?: CardSuit }>) => {
      const { playerId, cardIndex, chosenSuit } = action.payload;
      const player = state.players.find(p => p.id === playerId);

      if (!player) return;

      const card = player.hand[cardIndex];
      const topCard = state.discardPile[state.discardPile.length - 1];

      // Validation
      if (!canPlayCard({ cardToPlay: card, topCard, imposedSuit: state.imposedSuit, pendingDraw: state.cardsToDraw })) {
        state.errorMessage = 'Coup invalide';
        return;
      }

      // Appliquer effets
      player.hand.splice(cardIndex, 1);
      state.discardPile.push(card);

      const effect = getSpecialEffect(card);
      applyEffect(state, effect, chosenSuit);

      // Vérifier victoire
      if (player.hand.length === 0) {
        state.finishingOrder.push(playerId);
      }

      // Prochain joueur
      state.currentPlayerIndex = getNextPlayerIndex(state);
    },

    drawCard: (state) => {
      const currentPlayer = state.players[state.currentPlayerIndex];

      if (state.drawPile.length === 0) {
        // Recycler la défausse
        const topCard = state.discardPile.pop()!;
        state.drawPile = shuffleDeck(state.discardPile);
        state.discardPile = [topCard];
      }

      currentPlayer.hand.push(state.drawPile.pop()!);
    },

    // ... autres actions
  },
});

export const { startGame, playCard, drawCard } = gameSlice.actions;
export default gameSlice.reducer;
```

#### Store Configuration

```typescript
// store/index.ts
import { configureStore } from '@reduxjs/toolkit';
import gameReducer from './slices/gameSlice';
import multiplayerReducer from './slices/multiplayerSlice';

export const store = configureStore({
  reducer: {
    game: gameReducer,
    multiplayer: multiplayerReducer,
  },
});

export type RootState = ReturnType<typeof store.getState>;
export type AppDispatch = typeof store.dispatch;

// Hooks typés
import { TypedUseSelectorHook, useDispatch, useSelector } from 'react-redux';
export const useAppDispatch = () => useDispatch<AppDispatch>();
export const useAppSelector: TypedUseSelectorHook<RootState> = useSelector;
```

#### Usage dans les Composants

```tsx
// components/PlayerHand.tsx
import React from 'react';
import { View } from 'react-native';
import { useAppSelector, useAppDispatch } from '../store';
import { playCard } from '../store/slices/gameSlice';
import PlayingCard from './PlayingCard';

export default function PlayerHand() {
  const dispatch = useAppDispatch();
  const currentPlayer = useAppSelector(state => state.game.players[state.game.currentPlayerIndex]);

  const handleCardPress = (cardIndex: number) => {
    dispatch(playCard({ playerId: currentPlayer.id, cardIndex }));
  };

  return (
    <View>
      {currentPlayer.hand.map((card, index) => (
        <PlayingCard
          key={index}
          card={card}
          onPress={() => handleCardPress(index)}
        />
      ))}
    </View>
  );
}
```

---

## Migration des Modèles de Données

### Enums & Types

```typescript
// types/card.types.ts

export enum CardSuit {
  Hearts = 'hearts',
  Diamonds = 'diamonds',
  Clubs = 'clubs',
  Spades = 'spades',
  JokerRed = 'jokerRed',
  JokerBlack = 'jokerBlack',
}

export enum CardValue {
  Ace = 'ace',
  Two = 'two',
  Three = 'three',
  Four = 'four',
  Five = 'five',
  Six = 'six',
  Seven = 'seven',
  Eight = 'eight',
  Nine = 'nine',
  Ten = 'ten',
  Jack = 'jack',
  Queen = 'queen',
  King = 'king',
  Joker = 'joker',
}

export interface PlayingCard {
  suit: CardSuit;
  value: CardValue;
}

export enum SpecialEffect {
  SkipNextPlayer = 'skipNextPlayer',
  DrawTwo = 'drawTwo',
  DrawFour = 'drawFour',
  ImposeColor = 'imposeColor',
  Wildcard = 'wildcard',
}
```

```typescript
// types/player.types.ts
import { PlayingCard } from './card.types';

export interface Player {
  id: string;
  name: string;
  hand: PlayingCard[];
}
```

```typescript
// types/game.types.ts
import { Player } from './player.types';
import { PlayingCard, CardSuit } from './card.types';

export type GamePhase = 'normal' | 'duel' | 'finished';

export interface GameState {
  players: Player[];
  currentPlayerIndex: number;
  drawPile: PlayingCard[];
  discardPile: PlayingCard[];
  isGameOver: boolean;
  skipCount: number;
  cardsToDraw: number;
  imposedSuit: CardSuit | null;
  phase: GamePhase;
  finishingOrder: string[];
  lastChecksPlayerId: string | null;
  isPaused: boolean;
  errorMessage: string | null;
}
```

### Stats & History (Stockage Local)

```typescript
// types/stats.types.ts

export interface PlayerStats {
  playerName: string;
  gamesPlayed: number;
  wins: number;
  podiums: number; // Top 3
  positionCounts: Record<number, number>; // { 1: 5, 2: 3, 3: 2, 4: 1 }
  lastPlayed: Date;
}

export interface GameHistory {
  id: string;
  date: Date;
  playerNames: string[];
  finishingOrder: string[];
  hadDuel: boolean;
}
```

---

## Migration de la Logique Métier

### RuleEngine (Pure Functions)

```typescript
// utils/gameLogic/ruleEngine.ts
import { PlayingCard, CardSuit, CardValue, SpecialEffect } from '../../types/card.types';

interface CanPlayCardParams {
  cardToPlay: PlayingCard;
  topCard: PlayingCard;
  imposedSuit?: CardSuit | null;
  pendingDraw?: number;
}

export function canPlayCard({
  cardToPlay,
  topCard,
  imposedSuit = null,
  pendingDraw = 0,
}: CanPlayCardParams): boolean {
  // Wildcard (2) joue toujours
  if (cardToPlay.value === CardValue.Two) {
    return true;
  }

  // Cumulus actif (7 ou Joker): seulement 7 ou Joker
  if (pendingDraw > 0) {
    return cardToPlay.value === CardValue.Seven || cardToPlay.value === CardValue.Joker;
  }

  // Joker rouge/noir: doit respecter groupe couleur
  if (cardToPlay.value === CardValue.Joker) {
    if (topCard.value === CardValue.Joker) {
      return areSameJokerGroup(cardToPlay.suit, topCard.suit);
    }
    return isMatchingJokerGroup(cardToPlay.suit, topCard.suit);
  }

  // Imposition couleur (Valet)
  if (imposedSuit) {
    return cardToPlay.suit === imposedSuit || cardToPlay.value === CardValue.Two;
  }

  // Règle normale: même couleur OU même valeur
  return cardToPlay.suit === topCard.suit || cardToPlay.value === topCard.value;
}

export function getSpecialEffect(card: PlayingCard): SpecialEffect | null {
  switch (card.value) {
    case CardValue.Ace:
      return SpecialEffect.SkipNextPlayer;
    case CardValue.Seven:
      return SpecialEffect.DrawTwo;
    case CardValue.Joker:
      return SpecialEffect.DrawFour;
    case CardValue.Jack:
      return SpecialEffect.ImposeColor;
    case CardValue.Two:
      return SpecialEffect.Wildcard;
    default:
      return null;
  }
}

function areSameJokerGroup(suit1: CardSuit, suit2: CardSuit): boolean {
  const redJokers = [CardSuit.JokerRed, CardSuit.Hearts, CardSuit.Diamonds];
  const blackJokers = [CardSuit.JokerBlack, CardSuit.Clubs, CardSuit.Spades];

  return (
    (redJokers.includes(suit1) && redJokers.includes(suit2)) ||
    (blackJokers.includes(suit1) && blackJokers.includes(suit2))
  );
}

function isMatchingJokerGroup(jokerSuit: CardSuit, topCardSuit: CardSuit): boolean {
  const redGroup = [CardSuit.Hearts, CardSuit.Diamonds];
  const blackGroup = [CardSuit.Clubs, CardSuit.Spades];

  if (jokerSuit === CardSuit.JokerRed) {
    return redGroup.includes(topCardSuit);
  }
  if (jokerSuit === CardSuit.JokerBlack) {
    return blackGroup.includes(topCardSuit);
  }
  return false;
}

export function calculateNextPlayerIndex(
  currentIndex: number,
  playerCount: number,
  skipCount: number,
  direction: 1 | -1 = 1
): number {
  let nextIndex = currentIndex;

  for (let i = 0; i <= skipCount; i++) {
    nextIndex = (nextIndex + direction + playerCount) % playerCount;
  }

  return nextIndex;
}
```

### DeckGenerator

```typescript
// utils/gameLogic/deckGenerator.ts
import { PlayingCard, CardSuit, CardValue } from '../../types/card.types';

export function generateFullDeck(): PlayingCard[] {
  const deck: PlayingCard[] = [];

  const normalSuits = [CardSuit.Hearts, CardSuit.Diamonds, CardSuit.Clubs, CardSuit.Spades];
  const normalValues = [
    CardValue.Ace, CardValue.Two, CardValue.Three, CardValue.Four, CardValue.Five,
    CardValue.Six, CardValue.Seven, CardValue.Eight, CardValue.Nine, CardValue.Ten,
    CardValue.Jack, CardValue.Queen, CardValue.King,
  ];

  // 52 cartes normales
  normalSuits.forEach(suit => {
    normalValues.forEach(value => {
      deck.push({ suit, value });
    });
  });

  // 2 Jokers
  deck.push({ suit: CardSuit.JokerRed, value: CardValue.Joker });
  deck.push({ suit: CardSuit.JokerBlack, value: CardValue.Joker });

  // Vérification unicité
  if (!checkUniqueness(deck)) {
    throw new Error('Deck contains duplicate cards');
  }

  if (deck.length !== 54) {
    throw new Error(`Invalid deck size: ${deck.length}`);
  }

  return deck;
}

export function shuffleDeck(deck: PlayingCard[]): PlayingCard[] {
  const shuffled = [...deck];

  for (let i = shuffled.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [shuffled[i], shuffled[j]] = [shuffled[j], shuffled[i]];
  }

  return shuffled;
}

export function getFirstNonSpecialCard(deck: PlayingCard[]): number {
  const specialValues = [CardValue.Ace, CardValue.Seven, CardValue.Jack, CardValue.Joker];

  for (let i = 0; i < deck.length; i++) {
    if (!specialValues.includes(deck[i].value)) {
      return i;
    }
  }

  return 0;
}

function checkUniqueness(deck: PlayingCard[]): boolean {
  const seen = new Set<string>();

  for (const card of deck) {
    const key = `${card.suit}-${card.value}`;
    if (seen.has(key)) {
      return false;
    }
    seen.add(key);
  }

  return true;
}
```

---

## Migration du Stockage Local

### Hive → MMKV

#### Flutter Hive (Avant)

```dart
// repository/checkgame_repository.dart
class CheckgameRepository {
  static const _statsBoxName = 'player_stats';
  static const _historyBoxName = 'game_history';

  Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(PlayerStatsAdapter());
    Hive.registerAdapter(GameHistoryAdapter());
    await Hive.openBox<PlayerStats>(_statsBoxName);
    await Hive.openBox<GameHistory>(_historyBoxName);
  }

  Future<void> savePlayerStats(PlayerStats stats) async {
    final box = Hive.box<PlayerStats>(_statsBoxName);
    await box.put(stats.playerName, stats);
  }

  PlayerStats? getPlayerStats(String playerName) {
    final box = Hive.box<PlayerStats>(_statsBoxName);
    return box.get(playerName);
  }
}
```

#### React Native MMKV (Après)

```typescript
// services/storage/statsStorage.ts
import { MMKV } from 'react-native-mmkv';
import { PlayerStats, GameHistory } from '../../types/stats.types';

const storage = new MMKV({
  id: 'checkgames-storage',
});

// Player Stats
export function savePlayerStats(stats: PlayerStats): void {
  const key = `stats_${stats.playerName}`;
  storage.set(key, JSON.stringify(stats));
}

export function getPlayerStats(playerName: string): PlayerStats | null {
  const key = `stats_${playerName}`;
  const data = storage.getString(key);

  if (!data) return null;

  const parsed = JSON.parse(data);
  return {
    ...parsed,
    lastPlayed: new Date(parsed.lastPlayed),
  };
}

export function getAllPlayerStats(): PlayerStats[] {
  const allKeys = storage.getAllKeys();
  const statsKeys = allKeys.filter(key => key.startsWith('stats_'));

  return statsKeys
    .map(key => {
      const data = storage.getString(key);
      if (!data) return null;
      const parsed = JSON.parse(data);
      return {
        ...parsed,
        lastPlayed: new Date(parsed.lastPlayed),
      };
    })
    .filter((stats): stats is PlayerStats => stats !== null);
}

export function updatePlayerStats(playerName: string, updates: Partial<PlayerStats>): void {
  const existing = getPlayerStats(playerName);

  if (!existing) {
    const newStats: PlayerStats = {
      playerName,
      gamesPlayed: 0,
      wins: 0,
      podiums: 0,
      positionCounts: {},
      lastPlayed: new Date(),
      ...updates,
    };
    savePlayerStats(newStats);
  } else {
    const updated = { ...existing, ...updates };
    savePlayerStats(updated);
  }
}

// Game History
export function saveGameHistory(history: GameHistory): void {
  const key = `history_${history.id}`;
  storage.set(key, JSON.stringify(history));
}

export function getAllGameHistory(): GameHistory[] {
  const allKeys = storage.getAllKeys();
  const historyKeys = allKeys.filter(key => key.startsWith('history_'));

  return historyKeys
    .map(key => {
      const data = storage.getString(key);
      if (!data) return null;
      const parsed = JSON.parse(data);
      return {
        ...parsed,
        date: new Date(parsed.date),
      };
    })
    .filter((history): history is GameHistory => history !== null)
    .sort((a, b) => b.date.getTime() - a.date.getTime());
}

export function clearAllData(): void {
  storage.clearAll();
}
```

#### Alternative: AsyncStorage (Plus simple, moins performant)

```typescript
// services/storage/statsStorage.ts
import AsyncStorage from '@react-native-async-storage/async-storage';

export async function savePlayerStats(stats: PlayerStats): Promise<void> {
  const key = `stats_${stats.playerName}`;
  await AsyncStorage.setItem(key, JSON.stringify(stats));
}

export async function getPlayerStats(playerName: string): Promise<PlayerStats | null> {
  const key = `stats_${playerName}`;
  const data = await AsyncStorage.getItem(key);

  if (!data) return null;

  const parsed = JSON.parse(data);
  return {
    ...parsed,
    lastPlayed: new Date(parsed.lastPlayed),
  };
}
```

---

## Configuration Firebase

### Android Setup

1. Télécharger `google-services.json` depuis Firebase Console
2. Placer dans `android/app/google-services.json`
3. Modifier `android/build.gradle`:

```gradle
buildscript {
  dependencies {
    classpath('com.google.gms:google-services:4.4.0')
  }
}
```

4. Modifier `android/app/build.gradle`:

```gradle
apply plugin: 'com.google.gms.google-services'

dependencies {
  implementation platform('com.google.firebase:firebase-bom:32.7.0')
}
```

### iOS Setup

1. Télécharger `GoogleService-Info.plist` depuis Firebase Console
2. Ajouter dans Xcode: `ios/CheckGamesRN/GoogleService-Info.plist`
3. Modifier `ios/Podfile`:

```ruby
platform :ios, '13.0'

target 'CheckGamesRN' do
  use_frameworks! :linkage => :static

  pod 'Firebase/Core'
  pod 'Firebase/Auth'
  pod 'Firebase/Firestore'

  # ...
end
```

4. Exécuter `cd ios && pod install`

### Initialisation

```typescript
// App.tsx
import React, { useEffect } from 'react';
import { Provider } from 'react-redux';
import firebase from '@react-native-firebase/app';
import { store } from './src/store';
import AppNavigator from './src/navigation/AppNavigator';

export default function App() {
  useEffect(() => {
    // Firebase s'initialise automatiquement
    console.log('Firebase initialized:', firebase.app().name);
  }, []);

  return (
    <Provider store={store}>
      <AppNavigator />
    </Provider>
  );
}
```

---

## Migration des Services

### Firebase Auth Service

```typescript
// services/firebase/auth.service.ts
import auth, { FirebaseAuthTypes } from '@react-native-firebase/auth';
import firestore from '@react-native-firebase/firestore';

export interface UserProfile {
  uid: string;
  username: string;
  email?: string;
  wins: number;
  losses: number;
  avatarUrl?: string;
}

class FirebaseAuthService {
  async signUpWithEmail(email: string, password: string, username: string): Promise<UserProfile> {
    const credential = await auth().createUserWithEmailAndPassword(email, password);
    const user = credential.user;

    // Créer profil Firestore
    const profile: UserProfile = {
      uid: user.uid,
      username,
      email,
      wins: 0,
      losses: 0,
    };

    await firestore().collection('users').doc(user.uid).set(profile);

    return profile;
  }

  async signInWithEmail(email: string, password: string): Promise<UserProfile> {
    const credential = await auth().signInWithEmailAndPassword(email, password);
    const user = credential.user;

    const doc = await firestore().collection('users').doc(user.uid).get();
    return doc.data() as UserProfile;
  }

  async signInAnonymously(username: string): Promise<UserProfile> {
    const credential = await auth().signInAnonymously();
    const user = credential.user;

    const profile: UserProfile = {
      uid: user.uid,
      username,
      wins: 0,
      losses: 0,
    };

    await firestore().collection('users').doc(user.uid).set(profile);

    return profile;
  }

  async signOut(): Promise<void> {
    await auth().signOut();
  }

  getCurrentUser(): FirebaseAuthTypes.User | null {
    return auth().currentUser;
  }

  async getUserProfile(uid: string): Promise<UserProfile | null> {
    const doc = await firestore().collection('users').doc(uid).get();
    return doc.exists ? (doc.data() as UserProfile) : null;
  }

  async updateUserProfile(uid: string, updates: Partial<UserProfile>): Promise<void> {
    await firestore().collection('users').doc(uid).update(updates);
  }

  onAuthStateChanged(callback: (user: FirebaseAuthTypes.User | null) => void) {
    return auth().onAuthStateChanged(callback);
  }
}

export default new FirebaseAuthService();
```

### Firebase Room Service

```typescript
// services/firebase/room.service.ts
import firestore from '@react-native-firebase/firestore';
import auth from '@react-native-firebase/auth';

export interface GameRoom {
  id: string;
  hostId: string;
  hostName: string;
  code: string;
  status: 'waiting' | 'playing' | 'finished';
  maxPlayers: number;
  createdAt: Date;
}

export interface RoomPlayer {
  id: string;
  playerName: string;
  position: number;
  isReady: boolean;
  isOnline: boolean;
  handSize: number;
}

class FirebaseRoomService {
  generateRoomCode(): string {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    let code = '';
    for (let i = 0; i < 6; i++) {
      code += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    return code;
  }

  async createRoom(hostName: string, maxPlayers: number = 4): Promise<GameRoom> {
    const currentUser = auth().currentUser;
    if (!currentUser) throw new Error('Not authenticated');

    const code = this.generateRoomCode();

    const room: Omit<GameRoom, 'id'> = {
      hostId: currentUser.uid,
      hostName,
      code,
      status: 'waiting',
      maxPlayers,
      createdAt: new Date(),
    };

    const roomRef = await firestore().collection('game_rooms').add(room);

    // Ajouter le host comme premier joueur
    await roomRef.collection('players').doc(currentUser.uid).set({
      id: currentUser.uid,
      playerName: hostName,
      position: 0,
      isReady: false,
      isOnline: true,
      handSize: 0,
    });

    return { ...room, id: roomRef.id };
  }

  async joinRoom(roomCode: string, playerName: string): Promise<GameRoom> {
    const currentUser = auth().currentUser;
    if (!currentUser) throw new Error('Not authenticated');

    // Trouver la room par code
    const snapshot = await firestore()
      .collection('game_rooms')
      .where('code', '==', roomCode)
      .where('status', '==', 'waiting')
      .limit(1)
      .get();

    if (snapshot.empty) {
      throw new Error('Room not found or already started');
    }

    const roomDoc = snapshot.docs[0];
    const roomData = roomDoc.data() as GameRoom;

    // Vérifier nombre de joueurs
    const playersSnapshot = await roomDoc.ref.collection('players').get();
    if (playersSnapshot.size >= roomData.maxPlayers) {
      throw new Error('Room is full');
    }

    // Ajouter le joueur
    await roomDoc.ref.collection('players').doc(currentUser.uid).set({
      id: currentUser.uid,
      playerName,
      position: playersSnapshot.size,
      isReady: false,
      isOnline: true,
      handSize: 0,
    });

    return { ...roomData, id: roomDoc.id };
  }

  async setReady(roomId: string, ready: boolean): Promise<void> {
    const currentUser = auth().currentUser;
    if (!currentUser) throw new Error('Not authenticated');

    await firestore()
      .collection('game_rooms')
      .doc(roomId)
      .collection('players')
      .doc(currentUser.uid)
      .update({ isReady: ready });
  }

  async leaveRoom(roomId: string): Promise<void> {
    const currentUser = auth().currentUser;
    if (!currentUser) throw new Error('Not authenticated');

    const roomRef = firestore().collection('game_rooms').doc(roomId);
    const roomDoc = await roomRef.get();
    const roomData = roomDoc.data() as GameRoom;

    // Supprimer le joueur
    await roomRef.collection('players').doc(currentUser.uid).delete();

    // Si c'était le host, transférer ou supprimer la room
    if (roomData.hostId === currentUser.uid) {
      const playersSnapshot = await roomRef.collection('players').get();

      if (playersSnapshot.empty) {
        // Plus de joueurs, supprimer la room
        await roomRef.delete();
      } else {
        // Transférer le host au prochain joueur
        const newHost = playersSnapshot.docs[0];
        await roomRef.update({
          hostId: newHost.id,
          hostName: newHost.data().playerName,
        });
      }
    }
  }

  streamAvailableRooms(callback: (rooms: GameRoom[]) => void) {
    return firestore()
      .collection('game_rooms')
      .where('status', '==', 'waiting')
      .orderBy('createdAt', 'desc')
      .onSnapshot(snapshot => {
        const rooms = snapshot.docs.map(doc => ({
          id: doc.id,
          ...doc.data(),
          createdAt: doc.data().createdAt.toDate(),
        })) as GameRoom[];

        callback(rooms);
      });
  }

  streamRoomPlayers(roomId: string, callback: (players: RoomPlayer[]) => void) {
    return firestore()
      .collection('game_rooms')
      .doc(roomId)
      .collection('players')
      .orderBy('position')
      .onSnapshot(snapshot => {
        const players = snapshot.docs.map(doc => doc.data()) as RoomPlayer[];
        callback(players);
      });
  }
}

export default new FirebaseRoomService();
```

### Audio Service

```typescript
// services/audio.service.ts
import Sound from 'react-native-sound';

// Enable playback in silence mode (iOS)
Sound.setCategory('Playback');

interface SoundEffect {
  sound: Sound;
  isLoaded: boolean;
}

class AudioService {
  private sounds: Map<string, SoundEffect> = new Map();
  private backgroundMusic: Sound | null = null;
  private soundEnabled: boolean = true;
  private musicEnabled: boolean = true;

  async init(): Promise<void> {
    // Charger les SFX
    await this.loadSound('cardMove', require('../assets/audio/card_move.mp3'));
    await this.loadSound('checks', require('../assets/audio/checks.mp3'));
    await this.loadSound('buttonClick', require('../assets/audio/button_click.mp3'));

    // Charger la musique
    this.backgroundMusic = await this.loadMusic(require('../assets/audio/background_music.mp3'));
  }

  private loadSound(name: string, file: any): Promise<void> {
    return new Promise((resolve, reject) => {
      const sound = new Sound(file, error => {
        if (error) {
          console.error(`Failed to load sound ${name}:`, error);
          reject(error);
          return;
        }

        this.sounds.set(name, { sound, isLoaded: true });
        resolve();
      });
    });
  }

  private loadMusic(file: any): Promise<Sound> {
    return new Promise((resolve, reject) => {
      const music = new Sound(file, error => {
        if (error) {
          console.error('Failed to load music:', error);
          reject(error);
          return;
        }

        music.setVolume(0.3);
        music.setNumberOfLoops(-1); // Loop infiniment
        resolve(music);
      });
    });
  }

  playSound(name: string): void {
    if (!this.soundEnabled) return;

    const soundEffect = this.sounds.get(name);
    if (!soundEffect || !soundEffect.isLoaded) {
      console.warn(`Sound ${name} not loaded`);
      return;
    }

    soundEffect.sound.play(success => {
      if (!success) {
        console.warn(`Failed to play sound ${name}`);
      }
    });
  }

  playMusic(): void {
    if (!this.musicEnabled || !this.backgroundMusic) return;

    this.backgroundMusic.play(success => {
      if (!success) {
        console.warn('Failed to play music');
      }
    });
  }

  pauseMusic(): void {
    if (this.backgroundMusic) {
      this.backgroundMusic.pause();
    }
  }

  stopMusic(): void {
    if (this.backgroundMusic) {
      this.backgroundMusic.stop();
    }
  }

  toggleSound(): void {
    this.soundEnabled = !this.soundEnabled;
  }

  toggleMusic(): void {
    this.musicEnabled = !this.musicEnabled;

    if (this.musicEnabled) {
      this.playMusic();
    } else {
      this.pauseMusic();
    }
  }

  isSoundEnabled(): boolean {
    return this.soundEnabled;
  }

  isMusicEnabled(): boolean {
    return this.musicEnabled;
  }

  release(): void {
    // Libérer tous les sons
    this.sounds.forEach(({ sound }) => sound.release());
    this.sounds.clear();

    if (this.backgroundMusic) {
      this.backgroundMusic.release();
      this.backgroundMusic = null;
    }
  }
}

export default new AudioService();
```

---

## Migration des Composants UI

### PlayingCard Component

```tsx
// components/PlayingCard.tsx
import React from 'react';
import { TouchableOpacity, View, Text, StyleSheet } from 'react-native';
import { PlayingCard, CardSuit, CardValue } from '../types/card.types';

interface PlayingCardProps {
  card: PlayingCard;
  selected?: boolean;
  disabled?: boolean;
  onPress?: () => void;
  size?: 'small' | 'medium' | 'large';
}

export default function PlayingCardComponent({
  card,
  selected = false,
  disabled = false,
  onPress,
  size = 'medium',
}: PlayingCardProps) {
  const isRed = [CardSuit.Hearts, CardSuit.Diamonds, CardSuit.JokerRed].includes(card.suit);
  const cardColor = isRed ? '#E74C3C' : '#2C3E50';

  const sizeStyles = {
    small: { width: 50, height: 70 },
    medium: { width: 70, height: 100 },
    large: { width: 90, height: 130 },
  };

  return (
    <TouchableOpacity
      onPress={onPress}
      disabled={disabled || !onPress}
      style={[
        styles.card,
        sizeStyles[size],
        selected && styles.cardSelected,
        disabled && styles.cardDisabled,
      ]}
    >
      <View style={styles.cardContent}>
        <Text style={[styles.value, { color: cardColor }]}>
          {getCardValueSymbol(card.value)}
        </Text>
        <Text style={[styles.suit, { color: cardColor }]}>
          {getCardSuitSymbol(card.suit)}
        </Text>
      </View>
    </TouchableOpacity>
  );
}

function getCardValueSymbol(value: CardValue): string {
  const symbols: Record<CardValue, string> = {
    [CardValue.Ace]: 'A',
    [CardValue.Two]: '2',
    [CardValue.Three]: '3',
    [CardValue.Four]: '4',
    [CardValue.Five]: '5',
    [CardValue.Six]: '6',
    [CardValue.Seven]: '7',
    [CardValue.Eight]: '8',
    [CardValue.Nine]: '9',
    [CardValue.Ten]: '10',
    [CardValue.Jack]: 'J',
    [CardValue.Queen]: 'Q',
    [CardValue.King]: 'K',
    [CardValue.Joker]: '🃏',
  };
  return symbols[value];
}

function getCardSuitSymbol(suit: CardSuit): string {
  const symbols: Record<CardSuit, string> = {
    [CardSuit.Hearts]: '♥',
    [CardSuit.Diamonds]: '♦',
    [CardSuit.Clubs]: '♣',
    [CardSuit.Spades]: '♠',
    [CardSuit.JokerRed]: '★',
    [CardSuit.JokerBlack]: '★',
  };
  return symbols[suit];
}

const styles = StyleSheet.create({
  card: {
    backgroundColor: '#FFFFFF',
    borderRadius: 8,
    borderWidth: 2,
    borderColor: '#34495E',
    justifyContent: 'center',
    alignItems: 'center',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.25,
    shadowRadius: 3.84,
    elevation: 5,
  },
  cardSelected: {
    borderColor: '#3498DB',
    borderWidth: 3,
    transform: [{ translateY: -10 }],
  },
  cardDisabled: {
    opacity: 0.5,
  },
  cardContent: {
    alignItems: 'center',
  },
  value: {
    fontSize: 24,
    fontWeight: 'bold',
  },
  suit: {
    fontSize: 32,
    marginTop: 5,
  },
});
```

### HandFan Component (Disposition en éventail)

```tsx
// components/HandFan.tsx
import React from 'react';
import { View, StyleSheet, Dimensions } from 'react-native';
import { PlayingCard as PlayingCardType } from '../types/card.types';
import PlayingCard from './PlayingCard';

interface HandFanProps {
  cards: PlayingCardType[];
  selectedIndex?: number;
  onCardPress?: (index: number) => void;
  disabled?: boolean;
}

export default function HandFan({
  cards,
  selectedIndex,
  onCardPress,
  disabled = false,
}: HandFanProps) {
  const screenWidth = Dimensions.get('window').width;
  const cardWidth = 70;
  const cardHeight = 100;
  const fanRadius = screenWidth * 0.8;
  const spreadAngle = Math.min(cards.length * 8, 60); // Max 60 degrés

  const getCardTransform = (index: number, totalCards: number) => {
    const angleStep = spreadAngle / Math.max(totalCards - 1, 1);
    const angle = (index * angleStep) - (spreadAngle / 2);
    const angleRad = (angle * Math.PI) / 180;

    const x = fanRadius * Math.sin(angleRad);
    const y = fanRadius * (1 - Math.cos(angleRad));

    return {
      transform: [
        { translateX: x },
        { translateY: -y },
        { rotate: `${angle}deg` },
      ],
      zIndex: index,
    };
  };

  return (
    <View style={styles.container}>
      {cards.map((card, index) => {
        const transform = getCardTransform(index, cards.length);

        return (
          <View
            key={index}
            style={[
              styles.cardWrapper,
              {
                left: screenWidth / 2 - cardWidth / 2,
                zIndex: transform.zIndex,
              },
              transform,
            ]}
          >
            <PlayingCard
              card={card}
              selected={selectedIndex === index}
              disabled={disabled}
              onPress={() => onCardPress?.(index)}
              size="medium"
            />
          </View>
        );
      })}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    height: 150,
    width: '100%',
    position: 'relative',
  },
  cardWrapper: {
    position: 'absolute',
    bottom: 0,
  },
});
```

### SuitPickerSheet (Bottom Sheet pour choisir couleur)

```tsx
// components/SuitPickerSheet.tsx
import React from 'react';
import { View, Text, TouchableOpacity, StyleSheet } from 'react-native';
import BottomSheet, { BottomSheetBackdrop } from '@gorhom/bottom-sheet';
import { CardSuit } from '../types/card.types';

interface SuitPickerSheetProps {
  visible: boolean;
  onSuitSelect: (suit: CardSuit) => void;
  onDismiss: () => void;
}

export default function SuitPickerSheet({
  visible,
  onSuitSelect,
  onDismiss,
}: SuitPickerSheetProps) {
  const bottomSheetRef = React.useRef<BottomSheet>(null);

  React.useEffect(() => {
    if (visible) {
      bottomSheetRef.current?.expand();
    } else {
      bottomSheetRef.current?.close();
    }
  }, [visible]);

  const suits = [
    { suit: CardSuit.Hearts, label: '♥ Coeur', color: '#E74C3C' },
    { suit: CardSuit.Diamonds, label: '♦ Carreau', color: '#E74C3C' },
    { suit: CardSuit.Clubs, label: '♣ Trèfle', color: '#2C3E50' },
    { suit: CardSuit.Spades, label: '♠ Pique', color: '#2C3E50' },
  ];

  return (
    <BottomSheet
      ref={bottomSheetRef}
      index={-1}
      snapPoints={['40%']}
      enablePanDownToClose
      onClose={onDismiss}
      backdropComponent={props => (
        <BottomSheetBackdrop {...props} disappearsOnIndex={-1} appearsOnIndex={0} />
      )}
    >
      <View style={styles.content}>
        <Text style={styles.title}>Choisir une couleur</Text>

        <View style={styles.suitContainer}>
          {suits.map(({ suit, label, color }) => (
            <TouchableOpacity
              key={suit}
              style={[styles.suitButton, { borderColor: color }]}
              onPress={() => {
                onSuitSelect(suit);
                onDismiss();
              }}
            >
              <Text style={[styles.suitLabel, { color }]}>{label}</Text>
            </TouchableOpacity>
          ))}
        </View>
      </View>
    </BottomSheet>
  );
}

const styles = StyleSheet.create({
  content: {
    flex: 1,
    padding: 20,
  },
  title: {
    fontSize: 20,
    fontWeight: 'bold',
    textAlign: 'center',
    marginBottom: 20,
  },
  suitContainer: {
    gap: 15,
  },
  suitButton: {
    padding: 20,
    borderRadius: 10,
    borderWidth: 2,
    alignItems: 'center',
  },
  suitLabel: {
    fontSize: 24,
    fontWeight: 'bold',
  },
});
```

---

## Navigation & Écrans

### Navigation Setup

```tsx
// navigation/AppNavigator.tsx
import React from 'react';
import { NavigationContainer } from '@react-navigation/native';
import { createStackNavigator } from '@react-navigation/stack';
import MainMenuScreen from '../screens/MainMenuScreen';
import AuthScreen from '../screens/AuthScreen';
import MultiplayerLobbyScreen from '../screens/MultiplayerLobbyScreen';
import WaitingRoomScreen from '../screens/WaitingRoomScreen';
import GameScreen from '../screens/GameScreen';
import MultiplayerGameScreen from '../screens/MultiplayerGameScreen';

export type RootStackParamList = {
  MainMenu: undefined;
  Auth: undefined;
  MultiplayerLobby: undefined;
  WaitingRoom: { roomId: string };
  Game: { playerNames: string[] };
  MultiplayerGame: { roomId: string };
};

const Stack = createStackNavigator<RootStackParamList>();

export default function AppNavigator() {
  return (
    <NavigationContainer>
      <Stack.Navigator
        initialRouteName="MainMenu"
        screenOptions={{
          headerStyle: { backgroundColor: '#3498DB' },
          headerTintColor: '#FFF',
          headerTitleStyle: { fontWeight: 'bold' },
        }}
      >
        <Stack.Screen
          name="MainMenu"
          component={MainMenuScreen}
          options={{ title: 'CheckGames' }}
        />
        <Stack.Screen
          name="Auth"
          component={AuthScreen}
          options={{ title: 'Connexion' }}
        />
        <Stack.Screen
          name="MultiplayerLobby"
          component={MultiplayerLobbyScreen}
          options={{ title: 'Multijoueur' }}
        />
        <Stack.Screen
          name="WaitingRoom"
          component={WaitingRoomScreen}
          options={{ title: 'Salle d\'attente' }}
        />
        <Stack.Screen
          name="Game"
          component={GameScreen}
          options={{ headerShown: false }}
        />
        <Stack.Screen
          name="MultiplayerGame"
          component={MultiplayerGameScreen}
          options={{ headerShown: false }}
        />
      </Stack.Navigator>
    </NavigationContainer>
  );
}
```

### Main Menu Screen

```tsx
// screens/MainMenuScreen.tsx
import React from 'react';
import { View, Text, TouchableOpacity, StyleSheet } from 'react-native';
import { StackNavigationProp } from '@react-navigation/stack';
import { RootStackParamList } from '../navigation/AppNavigator';
import audioService from '../services/audio.service';

type MainMenuScreenNavigationProp = StackNavigationProp<RootStackParamList, 'MainMenu'>;

interface Props {
  navigation: MainMenuScreenNavigationProp;
}

export default function MainMenuScreen({ navigation }: Props) {
  React.useEffect(() => {
    audioService.playMusic();
  }, []);

  const handleSoloPress = () => {
    audioService.playSound('buttonClick');
    navigation.navigate('Game', { playerNames: ['Vous', 'Bot 1', 'Bot 2', 'Bot 3'] });
  };

  const handleMultiplayerPress = () => {
    audioService.playSound('buttonClick');
    navigation.navigate('Auth');
  };

  return (
    <View style={styles.container}>
      <Text style={styles.title}>CheckGames</Text>
      <Text style={styles.subtitle}>Jeu de cartes UNO-like</Text>

      <View style={styles.buttonContainer}>
        <TouchableOpacity style={styles.button} onPress={handleSoloPress}>
          <Text style={styles.buttonText}>Jouer Solo</Text>
        </TouchableOpacity>

        <TouchableOpacity style={[styles.button, styles.buttonSecondary]} onPress={handleMultiplayerPress}>
          <Text style={styles.buttonText}>Multijoueur</Text>
        </TouchableOpacity>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#2ECC71',
    padding: 20,
  },
  title: {
    fontSize: 48,
    fontWeight: 'bold',
    color: '#FFF',
    marginBottom: 10,
  },
  subtitle: {
    fontSize: 18,
    color: '#ECF0F1',
    marginBottom: 50,
  },
  buttonContainer: {
    width: '100%',
    gap: 20,
  },
  button: {
    backgroundColor: '#3498DB',
    padding: 20,
    borderRadius: 10,
    alignItems: 'center',
  },
  buttonSecondary: {
    backgroundColor: '#E74C3C',
  },
  buttonText: {
    fontSize: 20,
    fontWeight: 'bold',
    color: '#FFF',
  },
});
```

---

## Animations

### Card Animation avec react-native-reanimated

```tsx
// components/AnimatedCard.tsx
import React from 'react';
import { StyleSheet } from 'react-native';
import Animated, {
  useAnimatedStyle,
  useSharedValue,
  withSpring,
  withTiming,
} from 'react-native-reanimated';
import PlayingCard from './PlayingCard';
import { PlayingCard as PlayingCardType } from '../types/card.types';

interface AnimatedCardProps {
  card: PlayingCardType;
  fromX: number;
  fromY: number;
  toX: number;
  toY: number;
  onAnimationComplete?: () => void;
}

export default function AnimatedCard({
  card,
  fromX,
  fromY,
  toX,
  toY,
  onAnimationComplete,
}: AnimatedCardProps) {
  const translateX = useSharedValue(fromX);
  const translateY = useSharedValue(fromY);
  const scale = useSharedValue(1);

  React.useEffect(() => {
    // Animation vers la destination
    translateX.value = withSpring(toX, {}, () => {
      if (onAnimationComplete) {
        onAnimationComplete();
      }
    });
    translateY.value = withSpring(toY);
    scale.value = withTiming(1.2, { duration: 200 }, () => {
      scale.value = withTiming(1, { duration: 200 });
    });
  }, []);

  const animatedStyle = useAnimatedStyle(() => ({
    transform: [
      { translateX: translateX.value },
      { translateY: translateY.value },
      { scale: scale.value },
    ],
  }));

  return (
    <Animated.View style={[styles.container, animatedStyle]}>
      <PlayingCard card={card} size="medium" />
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  container: {
    position: 'absolute',
  },
});
```

---

## Tests

### Redux Slice Tests

```typescript
// __tests__/gameSlice.test.ts
import gameReducer, { startGame, playCard, drawCard } from '../store/slices/gameSlice';
import { GameState } from '../types/game.types';
import { CardValue, CardSuit } from '../types/card.types';

describe('gameSlice', () => {
  it('should initialize game with 4 players', () => {
    const initialState: GameState = gameReducer(undefined, { type: '@@INIT' });

    const state = gameReducer(initialState, startGame({
      playerNames: ['Player1', 'Player2', 'Player3', 'Player4'],
    }));

    expect(state.players).toHaveLength(4);
    expect(state.players[0].hand).toHaveLength(5);
    expect(state.discardPile).toHaveLength(1);
    expect(state.isGameOver).toBe(false);
  });

  it('should play a valid card', () => {
    const initialState: GameState = {
      players: [
        {
          id: 'p1',
          name: 'Player1',
          hand: [
            { suit: CardSuit.Hearts, value: CardValue.Five },
            { suit: CardSuit.Diamonds, value: CardValue.Seven },
          ],
        },
      ],
      currentPlayerIndex: 0,
      drawPile: [],
      discardPile: [{ suit: CardSuit.Hearts, value: CardValue.Three }],
      isGameOver: false,
      skipCount: 0,
      cardsToDraw: 0,
      imposedSuit: null,
      phase: 'normal',
      finishingOrder: [],
      lastChecksPlayerId: null,
      isPaused: false,
      errorMessage: null,
    };

    const state = gameReducer(initialState, playCard({
      playerId: 'p1',
      cardIndex: 0,
    }));

    expect(state.players[0].hand).toHaveLength(1);
    expect(state.discardPile).toHaveLength(2);
    expect(state.discardPile[1].value).toBe(CardValue.Five);
  });
});
```

### Component Tests

```typescript
// __tests__/PlayingCard.test.tsx
import React from 'react';
import { render, fireEvent } from '@testing-library/react-native';
import PlayingCard from '../components/PlayingCard';
import { CardSuit, CardValue } from '../types/card.types';

describe('PlayingCard', () => {
  const mockCard = {
    suit: CardSuit.Hearts,
    value: CardValue.Ace,
  };

  it('should render correctly', () => {
    const { getByText } = render(<PlayingCard card={mockCard} />);

    expect(getByText('A')).toBeTruthy();
    expect(getByText('♥')).toBeTruthy();
  });

  it('should call onPress when pressed', () => {
    const onPressMock = jest.fn();
    const { getByText } = render(<PlayingCard card={mockCard} onPress={onPressMock} />);

    fireEvent.press(getByText('A'));

    expect(onPressMock).toHaveBeenCalledTimes(1);
  });

  it('should apply selected style', () => {
    const { getByTestId } = render(<PlayingCard card={mockCard} selected />);

    // Vérifier style...
  });
});
```

---

## Ordre de Migration Recommandé

### Phase 1: Foundation (Semaine 1)

1. **Setup projet React Native**
   - Créer projet Expo/RN CLI
   - Installer toutes les dépendances
   - Configurer TypeScript strict

2. **Migrer les types/modèles**
   - `types/card.types.ts` (PlayingCard, CardSuit, CardValue, SpecialEffect)
   - `types/player.types.ts` (Player)
   - `types/game.types.ts` (GameState, GamePhase)
   - `types/stats.types.ts` (PlayerStats, GameHistory)

3. **Migrer la logique métier (Pure functions)**
   - `utils/gameLogic/deckGenerator.ts`
   - `utils/gameLogic/ruleEngine.ts`
   - Tests unitaires pour ces fonctions

### Phase 2: Services & Storage (Semaine 2)

4. **Configurer Firebase**
   - Configuration Android/iOS
   - Initialisation dans App.tsx

5. **Migrer les services storage**
   - `services/storage/statsStorage.ts` (MMKV)
   - `services/storage/historyStorage.ts`

6. **Migrer les services Firebase**
   - `services/firebase/auth.service.ts`
   - `services/firebase/room.service.ts`
   - `services/firebase/gameMaster.service.ts`
   - `services/firebase/gameAction.service.ts`

### Phase 3: State Management (Semaine 3)

7. **Setup Redux Toolkit**
   - Configuration store
   - Hooks typés (useAppSelector, useAppDispatch)

8. **Migrer BLoC → Redux slices**
   - `store/slices/gameSlice.ts` (mode solo)
   - Actions: startGame, playCard, drawCard, endTurn
   - Tests Redux

9. **Multiplayer slice**
   - `store/slices/multiplayerSlice.ts`
   - Listeners Firebase

### Phase 4: UI Components (Semaine 4)

10. **Composants de base**
    - `components/PlayingCard.tsx`
    - `components/CardBack.tsx`
    - Tests composants

11. **Composants complexes**
    - `components/HandFan.tsx` (disposition éventail)
    - `components/TableWidgets.tsx` (pioche, défausse, infos joueur)

12. **Overlays & Sheets**
    - `components/SuitPickerSheet.tsx`
    - `components/GameOverSheet.tsx`
    - `components/ChecksOverlay.tsx`
    - `components/ErrorMessage.tsx`
    - `components/PauseMenu.tsx`

### Phase 5: Screens & Navigation (Semaine 5)

13. **Navigation**
    - `navigation/AppNavigator.tsx`
    - Configuration Stack Navigator

14. **Écrans**
    - `screens/MainMenuScreen.tsx`
    - `screens/AuthScreen.tsx`
    - `screens/GameScreen.tsx` (mode solo)
    - `screens/MultiplayerLobbyScreen.tsx`
    - `screens/WaitingRoomScreen.tsx`
    - `screens/MultiplayerGameScreen.tsx`

### Phase 6: Audio & Animations (Semaine 6)

15. **Audio Service**
    - `services/audio.service.ts`
    - Intégration dans App.tsx
    - Tests audio

16. **Animations**
    - `components/AnimatedCard.tsx` (cartes volantes)
    - Animations HandFan (react-native-reanimated)
    - Transitions écrans

### Phase 7: Testing & Polish (Semaine 7)

17. **Tests d'intégration**
    - Tests end-to-end (Detox)
    - Tests flows complets

18. **Polish UI**
    - Responsive design (useWindowDimensions)
    - Accessibilité
    - Dark mode (optionnel)

19. **Performance**
    - Optimisations re-renders (React.memo, useMemo)
    - Optimisations Firestore (indices)

### Phase 8: Release (Semaine 8)

20. **Build & Deploy**
    - Configuration app.json (Expo) ou build.gradle (RN CLI)
    - Icônes & splash screen
    - Build Android APK/AAB
    - Build iOS IPA
    - Publication Play Store / App Store

---

## Checklist de Migration

### Setup
- [ ] Projet React Native créé
- [ ] Dependencies installées
- [ ] TypeScript configuré
- [ ] Structure dossiers créée

### Types & Models
- [ ] Types cartes (CardSuit, CardValue, PlayingCard)
- [ ] Types joueur (Player)
- [ ] Types game state (GameState, GamePhase)
- [ ] Types stats (PlayerStats, GameHistory)

### Logique Métier
- [ ] DeckGenerator migré + tests
- [ ] RuleEngine migré + tests
- [ ] Bot IA logique migrée

### Storage
- [ ] MMKV configuré
- [ ] statsStorage migré
- [ ] historyStorage migré

### Firebase
- [ ] Firebase configuré Android
- [ ] Firebase configuré iOS
- [ ] auth.service migré
- [ ] room.service migré
- [ ] gameMaster.service migré
- [ ] gameAction.service migré
- [ ] Firestore rules déployées

### State Management
- [ ] Redux store configuré
- [ ] gameSlice créé + tests
- [ ] multiplayerSlice créé + tests
- [ ] Hooks typés (useAppSelector, useAppDispatch)

### Services
- [ ] Audio service migré
- [ ] Animation service migré

### Components
- [ ] PlayingCard
- [ ] CardBack
- [ ] HandFan
- [ ] TableWidgets
- [ ] SuitPickerSheet
- [ ] GameOverSheet
- [ ] ChecksOverlay
- [ ] ErrorMessage
- [ ] PauseMenu

### Screens
- [ ] MainMenuScreen
- [ ] AuthScreen
- [ ] GameScreen (solo)
- [ ] MultiplayerLobbyScreen
- [ ] WaitingRoomScreen
- [ ] MultiplayerGameScreen

### Navigation
- [ ] AppNavigator configuré
- [ ] Routes définies
- [ ] Deep linking (optionnel)

### Animations
- [ ] AnimatedCard composant
- [ ] HandFan animations
- [ ] Transitions écrans

### Tests
- [ ] Tests logique métier
- [ ] Tests Redux slices
- [ ] Tests composants
- [ ] Tests intégration

### Assets
- [ ] Audio files copiés
- [ ] Images copiées
- [ ] Fonts (si custom)

### Build & Deploy
- [ ] Icône app
- [ ] Splash screen
- [ ] Build Android
- [ ] Build iOS
- [ ] Publication stores

---

## Différences Clés Flutter vs React Native

### State Management
- **Flutter BLoC**: Streams, événements → émetteurs
- **React Native Redux**: Actions → reducers (fonctions pures)

### UI Construction
- **Flutter**: Widgets immuables, rebuild sur changement state
- **React**: Composants fonctionnels, re-render sur changement props/state

### Styling
- **Flutter**: Properties directes sur widgets
- **React Native**: StyleSheet (similaire à CSS)

### Animations
- **Flutter**: AnimationController, Tween
- **React Native**: react-native-reanimated (worklets), Animated API

### Navigation
- **Flutter**: Navigator.push, routes
- **React Native**: React Navigation (stack, tab, drawer navigators)

### Async
- **Flutter**: Future, async/await
- **React Native**: Promise, async/await (identique)

---

## Ressources Utiles

### Documentation
- [React Native Docs](https://reactnative.dev/docs/getting-started)
- [Redux Toolkit](https://redux-toolkit.js.org/)
- [React Navigation](https://reactnavigation.org/)
- [React Native Firebase](https://rnfirebase.io/)
- [React Native Reanimated](https://docs.swmansion.com/react-native-reanimated/)

### Outils
- [React Native Debugger](https://github.com/jhen0409/react-native-debugger)
- [Flipper](https://fbflipper.com/) - Debugging mobile apps
- [Reactotron](https://github.com/infinitered/reactotron) - Inspector

### Communauté
- [React Native Community](https://github.com/react-native-community)
- [Expo Forums](https://forums.expo.dev/)

---

## Conclusion

Cette migration représente environ **8 semaines de travail** pour un développeur expérimenté. La complexité réside principalement dans:

1. **Animations éventail** (HandFan) - Calculs géométriques
2. **Transactions Firebase** - Logique atomique multiplayer
3. **IA Bot** - Stratégie décisionnelle
4. **Tests** - Couverture complète

**Avantages React Native:**
- Ecosystem JavaScript plus large
- Hot reload plus rapide
- Communauté massive
- Intégration web possible (React Native Web)

**Points d'attention:**
- Performance animations (utiliser Reanimated v3)
- Gestion mémoire (release audio)
- Firestore costs (optimiser listeners)

Bon courage pour la migration!
