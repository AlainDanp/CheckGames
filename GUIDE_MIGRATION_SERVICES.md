# Guide Complet: Migration des Services Flutter → React Native

## Table des Matières

1. [Vue d'ensemble des Services](#vue-densemble-des-services)
2. [AudioService](#1-audioservice)
3. [FirebaseAuthService](#2-firebaseauthservice)
4. [FirebaseRoomService](#3-firebaseroomservice)
5. [GameMasterService](#4-gamemasterservice)
6. [GameActionService](#5-gameactionservice)
7. [FirebaseGameSyncService](#6-firebasegamesyncservice)
8. [CardAnimationService](#7-cardanimationservice)
9. [Architecture des Services](#architecture-des-services)
10. [Checklist de Migration](#checklist-de-migration)

---

## Vue d'ensemble des Services

Votre application Flutter CheckGames contient **7 services critiques** :

| Flutter Service | React Native Service | Complexité | Dépendances |
|-----------------|---------------------|------------|-------------|
| `audio_service.dart` | `audio.service.ts` | ⭐⭐ Moyen | react-native-sound |
| `firebase_auth_service.dart` | `firebaseAuth.service.ts` | ⭐⭐ Moyen | @react-native-firebase/auth |
| `firebase_room_service.dart` | `firebaseRoom.service.ts` | ⭐⭐⭐⭐ Très complexe | @react-native-firebase/firestore |
| `game_master_service.dart` | `gameMaster.service.ts` | ⭐⭐⭐⭐⭐ Très complexe | Firestore transactions |
| `game_action_service.dart` | `gameAction.service.ts` | ⭐⭐⭐⭐⭐ Très complexe | Firestore transactions |
| `firebase_game_sync_service.dart` | `gameSync.service.ts` | ⭐⭐⭐ Complexe | Redux, Firestore |
| `card_animation_service.dart` | `cardAnimation.service.ts` | ⭐⭐⭐ Complexe | Reanimated |

---

## 1. AudioService

### Flutter (Avant)

```dart
// lib/services/audio_service.dart
class AudioService {
  static final AudioService instance = AudioService._internal();
  factory AudioService() => instance;
  AudioService._internal();

  final AudioPlayer _sfxPlayer = AudioPlayer();
  final AudioPlayer _musicPlayer = AudioPlayer();

  bool _soundEnabled = true;
  bool _musicEnabled = true;

  Future<void> startBackgroundMusic() async {
    await _musicPlayer.setReleaseMode(ReleaseMode.loop);
    await _musicPlayer.setVolume(0.3);
    await _musicPlayer.play(AssetSource('sounds/background_music.mp3'));
  }

  Future<void> playCardMove() async {
    if (!_soundEnabled) return;
    await _sfxPlayer.play(AssetSource('sounds/card_move.mp3'));
  }

  Future<void> playChecks() async {
    if (!_soundEnabled) return;
    await _sfxPlayer.play(AssetSource('sounds/checks.mp3'));
  }

  Future<void> playButtonClick() async {
    if (!_soundEnabled) return;
    await _sfxPlayer.play(AssetSource('sounds/button_click.mp3'));
  }
}
```

### React Native (Après)

```typescript
// src/services/audio.service.ts
import Sound from 'react-native-sound';
import AsyncStorage from '@react-native-async-storage/async-storage';

class AudioService {
  private static instance: AudioService;

  private backgroundMusic: Sound | null = null;
  private sfxPlayer: Sound | null = null;

  private soundEnabled: boolean = true;
  private musicEnabled: boolean = true;
  private musicPlaying: boolean = false;

  private constructor() {
    this.loadSettings();
  }

  public static getInstance(): AudioService {
    if (!AudioService.instance) {
      AudioService.instance = new AudioService();
    }
    return AudioService.instance;
  }

  // Charger les paramètres depuis AsyncStorage
  private async loadSettings() {
    try {
      const soundSetting = await AsyncStorage.getItem('soundEnabled');
      const musicSetting = await AsyncStorage.getItem('musicEnabled');

      if (soundSetting !== null) {
        this.soundEnabled = soundSetting === 'true';
      }
      if (musicSetting !== null) {
        this.musicEnabled = musicSetting === 'true';
      }
    } catch (error) {
      console.error('Error loading audio settings:', error);
    }
  }

  // Getters
  public isSoundEnabled(): boolean {
    return this.soundEnabled;
  }

  public isMusicEnabled(): boolean {
    return this.musicEnabled;
  }

  public isMusicPlaying(): boolean {
    return this.musicPlaying;
  }

  // Toggle sound
  public async enableSound() {
    this.soundEnabled = true;
    await AsyncStorage.setItem('soundEnabled', 'true');
  }

  public async disableSound() {
    this.soundEnabled = false;
    await AsyncStorage.setItem('soundEnabled', 'false');
  }

  // Background music
  public playMusic() {
    if (!this.musicEnabled || this.musicPlaying) return;

    if (!this.backgroundMusic) {
      this.backgroundMusic = new Sound('background_music.mp3', Sound.MAIN_BUNDLE, (error) => {
        if (error) {
          console.error('Failed to load background music:', error);
          return;
        }

        this.backgroundMusic?.setVolume(0.3);
        this.backgroundMusic?.setNumberOfLoops(-1); // Loop infiniment
        this.backgroundMusic?.play((success) => {
          if (success) {
            this.musicPlaying = true;
          }
        });
      });
    } else {
      this.backgroundMusic.play((success) => {
        if (success) {
          this.musicPlaying = true;
        }
      });
    }
  }

  public pauseMusic() {
    if (this.backgroundMusic) {
      this.backgroundMusic.pause();
      this.musicPlaying = false;
    }
  }

  public stopMusic() {
    if (this.backgroundMusic) {
      this.backgroundMusic.stop();
      this.musicPlaying = false;
    }
  }

  public async setMusicEnabled(enabled: boolean) {
    this.musicEnabled = enabled;
    await AsyncStorage.setItem('musicEnabled', enabled.toString());

    if (enabled) {
      this.playMusic();
    } else {
      this.stopMusic();
    }
  }

  // Sound effects
  public playSound(soundName: 'cardMove' | 'checks' | 'buttonClick') {
    if (!this.soundEnabled) return;

    const soundFiles: Record<string, string> = {
      cardMove: 'card_move.mp3',
      checks: 'checks.mp3',
      buttonClick: 'button_click.mp3',
    };

    const fileName = soundFiles[soundName];
    if (!fileName) return;

    const sound = new Sound(fileName, Sound.MAIN_BUNDLE, (error) => {
      if (error) {
        console.error(`Failed to load sound ${soundName}:`, error);
        return;
      }

      sound.play((success) => {
        if (!success) {
          console.error(`Failed to play sound ${soundName}`);
        }
        // Libérer la mémoire après lecture
        sound.release();
      });
    });
  }

  // Cleanup
  public dispose() {
    if (this.backgroundMusic) {
      this.backgroundMusic.release();
      this.backgroundMusic = null;
    }
    if (this.sfxPlayer) {
      this.sfxPlayer.release();
      this.sfxPlayer = null;
    }
  }
}

export default AudioService.getInstance();
```

### Dépendances

```bash
npm install react-native-sound
npm install @react-native-async-storage/async-storage

# iOS
cd ios && pod install

# Android - Ajouter dans android/app/src/main/AndroidManifest.xml
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
```

### Utilisation

```typescript
import audioService from './services/audio.service';

// Démarrer la musique
audioService.playMusic();

// Jouer un son
audioService.playSound('cardMove');
audioService.playSound('checks');
audioService.playSound('buttonClick');

// Activer/désactiver
audioService.enableSound();
audioService.disableSound();
audioService.setMusicEnabled(true);
```

---

## 2. FirebaseAuthService

### React Native

```typescript
// src/services/firebase/firebaseAuth.service.ts
import auth, { FirebaseAuthTypes } from '@react-native-firebase/auth';
import firestore from '@react-native-firebase/firestore';

interface UserProfile {
  username: string;
  email: string;
  avatarUrl: string;
  wins: number;
  losses: number;
  createdAt?: FirebaseAuthTypes.Timestamp;
  lastSeen?: FirebaseAuthTypes.Timestamp;
}

class FirebaseAuthService {
  private static instance: FirebaseAuthService;

  private constructor() {}

  public static getInstance(): FirebaseAuthService {
    if (!FirebaseAuthService.instance) {
      FirebaseAuthService.instance = new FirebaseAuthService();
    }
    return FirebaseAuthService.instance;
  }

  // Utilisateur actuel
  public getCurrentUser(): FirebaseAuthTypes.User | null {
    return auth().currentUser;
  }

  // Stream d'état d'authentification
  public onAuthStateChanged(
    callback: (user: FirebaseAuthTypes.User | null) => void
  ): () => void {
    return auth().onAuthStateChanged(callback);
  }

  // Inscription
  public async signUp(
    email: string,
    password: string,
    username: string
  ): Promise<FirebaseAuthTypes.UserCredential> {
    try {
      console.log('🔐 Tentative inscription:', email);
      const userCredential = await auth().createUserWithEmailAndPassword(email, password);
      console.log('✅ Utilisateur créé:', userCredential.user.uid);

      // Créer le profil Firestore
      try {
        await firestore().collection('users').doc(userCredential.user.uid).set({
          username,
          email,
          avatarUrl: '',
          wins: 0,
          losses: 0,
          createdAt: firestore.FieldValue.serverTimestamp(),
          lastSeen: firestore.FieldValue.serverTimestamp(),
        });
        console.log('✅ Profil utilisateur créé dans Firestore');
      } catch (firestoreError) {
        console.warn('⚠️ Erreur Firestore (profil non créé):', firestoreError);
      }

      return userCredential;
    } catch (error) {
      console.error('❌ Erreur inscription:', error);
      throw this.handleAuthError(error);
    }
  }

  // Connexion
  public async signIn(
    email: string,
    password: string
  ): Promise<FirebaseAuthTypes.UserCredential> {
    try {
      console.log('🔐 Tentative connexion:', email);
      const userCredential = await auth().signInWithEmailAndPassword(email, password);
      console.log('✅ Connexion réussie:', userCredential.user.uid);

      // Mettre à jour lastSeen
      try {
        await firestore().collection('users').doc(userCredential.user.uid).update({
          lastSeen: firestore.FieldValue.serverTimestamp(),
        });
        console.log('✅ lastSeen mis à jour');
      } catch (firestoreError) {
        console.warn('⚠️ Erreur mise à jour lastSeen:', firestoreError);
      }

      return userCredential;
    } catch (error) {
      console.error('❌ Erreur connexion:', error);
      throw this.handleAuthError(error);
    }
  }

  // Connexion anonyme
  public async signInAnonymously(username?: string): Promise<FirebaseAuthTypes.UserCredential> {
    try {
      console.log('🔐 Tentative connexion anonyme');
      const userCredential = await auth().signInAnonymously();
      console.log('✅ Connexion anonyme réussie:', userCredential.user.uid);

      // Créer un profil anonyme
      try {
        const generatedUsername =
          username || `Joueur${Date.now() % 10000}`;
        await firestore().collection('users').doc(userCredential.user.uid).set({
          username: generatedUsername,
          email: '',
          avatarUrl: '',
          wins: 0,
          losses: 0,
          createdAt: firestore.FieldValue.serverTimestamp(),
          lastSeen: firestore.FieldValue.serverTimestamp(),
        });
        console.log('✅ Profil anonyme créé:', generatedUsername);
      } catch (firestoreError) {
        console.warn('⚠️ Erreur Firestore (profil anonyme non créé):', firestoreError);
      }

      return userCredential;
    } catch (error) {
      console.error('❌ Erreur connexion anonyme:', error);
      throw this.handleAuthError(error);
    }
  }

  // Déconnexion
  public async signOut(): Promise<void> {
    await auth().signOut();
  }

  // Récupérer le profil utilisateur
  public async getUserProfile(userId: string): Promise<UserProfile | null> {
    try {
      console.log('📖 Lecture profil:', userId);
      const doc = await firestore().collection('users').doc(userId).get();

      if (!doc.exists) {
        console.warn('⚠️ Profil non trouvé, création d\'un profil par défaut');
        const defaultProfile: UserProfile = {
          username: `Joueur${Date.now() % 10000}`,
          email: '',
          avatarUrl: '',
          wins: 0,
          losses: 0,
        };

        await firestore().collection('users').doc(userId).set({
          ...defaultProfile,
          createdAt: firestore.FieldValue.serverTimestamp(),
          lastSeen: firestore.FieldValue.serverTimestamp(),
        });

        return defaultProfile;
      }

      const data = doc.data() as UserProfile;
      console.log('✅ Profil récupéré:', data.username);
      return data;
    } catch (error) {
      console.error('❌ Erreur lecture profil:', error);
      // Retourner un profil par défaut en cas d'erreur
      return {
        username: `Joueur${Date.now() % 10000}`,
        email: '',
        avatarUrl: '',
        wins: 0,
        losses: 0,
      };
    }
  }

  // Mettre à jour le profil
  public async updateProfile(
    userId: string,
    data: Partial<UserProfile>
  ): Promise<void> {
    await firestore().collection('users').doc(userId).update(data);
  }

  // Gestion des erreurs
  private handleAuthError(error: any): Error {
    const errorCode = error.code;
    let message = 'Une erreur est survenue';

    switch (errorCode) {
      case 'auth/email-already-in-use':
        message = 'Cet email est déjà utilisé';
        break;
      case 'auth/invalid-email':
        message = 'Email invalide';
        break;
      case 'auth/weak-password':
        message = 'Mot de passe trop faible (min 6 caractères)';
        break;
      case 'auth/user-not-found':
        message = 'Utilisateur introuvable';
        break;
      case 'auth/wrong-password':
        message = 'Mot de passe incorrect';
        break;
      case 'auth/network-request-failed':
        message = 'Erreur réseau, vérifiez votre connexion';
        break;
      default:
        message = error.message || 'Erreur d\'authentification';
    }

    return new Error(message);
  }
}

export default FirebaseAuthService.getInstance();
```

---

## 3. FirebaseRoomService

### React Native (Partie 1/2)

```typescript
// src/services/firebase/firebaseRoom.service.ts
import firestore, { FirebaseFirestoreTypes } from '@react-native-firebase/firestore';

export interface GameRoom {
  id: string;
  hostId: string;
  roomCode: string;
  maxPlayers: number;
  currentPlayers: number;
  status: 'waiting' | 'playing' | 'finished';
  createdAt: FirebaseFirestoreTypes.Timestamp;
  updatedAt: FirebaseFirestoreTypes.Timestamp;
}

export interface RoomPlayer {
  id: string;
  playerName: string;
  position: number;
  isReady: boolean;
  isOnline: boolean;
  handSize?: number;
  joinedAt: FirebaseFirestoreTypes.Timestamp;
}

class FirebaseRoomService {
  private static instance: FirebaseRoomService;

  private constructor() {}

  public static getInstance(): FirebaseRoomService {
    if (!FirebaseRoomService.instance) {
      FirebaseRoomService.instance = new FirebaseRoomService();
    }
    return FirebaseRoomService.instance;
  }

  // Générer un code de salle unique
  private generateRoomCode(): string {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return Array.from({ length: 6 }, () =>
      chars.charAt(Math.floor(Math.random() * chars.length))
    ).join('');
  }

  // Créer une salle
  public async createRoom(
    hostId: string,
    playerName: string,
    maxPlayers: number = 4
  ): Promise<GameRoom> {
    const roomCode = this.generateRoomCode();

    // Créer la salle
    const roomRef = await firestore().collection('game_rooms').add({
      hostId,
      roomCode,
      maxPlayers,
      currentPlayers: 1,
      status: 'waiting',
      createdAt: firestore.FieldValue.serverTimestamp(),
      updatedAt: firestore.FieldValue.serverTimestamp(),
    });

    // Ajouter l'hôte comme premier joueur
    await roomRef.collection('players').doc(hostId).set({
      playerName,
      position: 0,
      isReady: true,
      isOnline: true,
      joinedAt: firestore.FieldValue.serverTimestamp(),
    });

    // Récupérer les données complètes
    const roomDoc = await roomRef.get();
    return {
      id: roomRef.id,
      ...(roomDoc.data() as Omit<GameRoom, 'id'>),
    };
  }

  // Rejoindre une salle par code
  public async joinRoom(roomCode: string, playerId: string, playerName: string): Promise<GameRoom> {
    // Rechercher la salle
    const querySnapshot = await firestore()
      .collection('game_rooms')
      .where('roomCode', '==', roomCode)
      .where('status', '==', 'waiting')
      .limit(1)
      .get();

    if (querySnapshot.empty) {
      throw new Error('Salle non trouvée ou partie déjà commencée');
    }

    const roomDoc = querySnapshot.docs[0];
    const roomData = roomDoc.data();
    const roomId = roomDoc.id;

    // Vérifier si la salle est pleine
    if (roomData.currentPlayers >= roomData.maxPlayers) {
      throw new Error('La salle est pleine');
    }

    // Vérifier si le joueur n'est pas déjà dans la salle
    const playerDoc = await roomDoc.ref.collection('players').doc(playerId).get();

    if (playerDoc.exists) {
      return {
        id: roomId,
        ...roomData,
      } as GameRoom;
    }

    // Trouver la première position libre
    const playersSnapshot = await roomDoc.ref
      .collection('players')
      .orderBy('position')
      .get();

    let position = 0;
    playersSnapshot.docs.forEach((doc) => {
      if (doc.data().position === position) {
        position++;
      }
    });

    // Ajouter le joueur avec transaction
    await firestore().runTransaction(async (transaction) => {
      const roomSnapshot = await transaction.get(roomDoc.ref);
      const currentPlayers = roomSnapshot.data()!.currentPlayers as number;

      if (currentPlayers >= roomData.maxPlayers) {
        throw new Error('La salle est pleine');
      }

      // Ajouter le joueur
      transaction.set(roomDoc.ref.collection('players').doc(playerId), {
        playerName,
        position,
        isReady: false,
        isOnline: true,
        joinedAt: firestore.FieldValue.serverTimestamp(),
      });

      // Incrémenter le compteur
      transaction.update(roomDoc.ref, {
        currentPlayers: currentPlayers + 1,
        updatedAt: firestore.FieldValue.serverTimestamp(),
      });
    });

    return {
      id: roomId,
      ...roomData,
    } as GameRoom;
  }

  // Quitter une salle
  public async leaveRoom(roomId: string, playerId: string): Promise<void> {
    const roomRef = firestore().collection('game_rooms').doc(roomId);

    await firestore().runTransaction(async (transaction) => {
      const roomSnapshot = await transaction.get(roomRef);

      if (!roomSnapshot.exists) return;

      const roomData = roomSnapshot.data()!;
      const currentPlayers = roomData.currentPlayers as number;

      // Supprimer le joueur
      transaction.delete(roomRef.collection('players').doc(playerId));

      // Si c'était le dernier joueur, supprimer la salle
      if (currentPlayers <= 1) {
        transaction.delete(roomRef);
      } else {
        // Sinon, décrémenter le compteur
        transaction.update(roomRef, {
          currentPlayers: currentPlayers - 1,
          updatedAt: firestore.FieldValue.serverTimestamp(),
        });

        // Si c'était l'hôte, transférer à un autre joueur
        if (roomData.hostId === playerId) {
          const playersSnapshot = await roomRef.collection('players').limit(2).get();
          const newHost = playersSnapshot.docs.find((doc) => doc.id !== playerId);

          if (newHost) {
            transaction.update(roomRef, {
              hostId: newHost.id,
            });
          }
        }
      }
    });
  }

  // Marquer un joueur comme prêt
  public async setReady(roomId: string, playerId: string, ready: boolean): Promise<void> {
    await firestore()
      .collection('game_rooms')
      .doc(roomId)
      .collection('players')
      .doc(playerId)
      .update({ isReady: ready });
  }

  // Démarrer la partie
  public async startGame(roomId: string): Promise<void> {
    // Vérifier que tous les joueurs sont prêts
    const playersSnapshot = await firestore()
      .collection('game_rooms')
      .doc(roomId)
      .collection('players')
      .get();

    const allReady = playersSnapshot.docs.every((doc) => doc.data().isReady === true);

    if (!allReady) {
      throw new Error('Tous les joueurs ne sont pas prêts');
    }

    // Mettre à jour le statut de la salle
    await firestore().collection('game_rooms').doc(roomId).update({
      status: 'playing',
      updatedAt: firestore.FieldValue.serverTimestamp(),
    });
  }

  // Stream de la salle
  public streamRoom(
    roomId: string,
    callback: (room: GameRoom) => void
  ): () => void {
    return firestore()
      .collection('game_rooms')
      .doc(roomId)
      .onSnapshot((snapshot) => {
        if (snapshot.exists) {
          callback({
            id: snapshot.id,
            ...(snapshot.data() as Omit<GameRoom, 'id'>),
          });
        }
      });
  }

  // Stream des joueurs
  public streamRoomPlayers(
    roomId: string,
    callback: (players: RoomPlayer[]) => void
  ): () => void {
    return firestore()
      .collection('game_rooms')
      .doc(roomId)
      .collection('players')
      .orderBy('position')
      .onSnapshot((snapshot) => {
        const players = snapshot.docs.map((doc) => ({
          id: doc.id,
          ...(doc.data() as Omit<RoomPlayer, 'id'>),
        }));
        callback(players);
      });
  }

  // Stream des salles disponibles
  public streamAvailableRooms(
    callback: (rooms: GameRoom[]) => void
  ): () => void {
    return firestore()
      .collection('game_rooms')
      .where('status', '==', 'waiting')
      .orderBy('createdAt', 'desc')
      .limit(20)
      .onSnapshot((snapshot) => {
        const rooms = snapshot.docs.map((doc) => ({
          id: doc.id,
          ...(doc.data() as Omit<GameRoom, 'id'>),
        }));
        callback(rooms);
      });
  }

  // Système de présence
  public async setupPresence(roomId: string, playerId: string): Promise<void> {
    await firestore()
      .collection('game_rooms')
      .doc(roomId)
      .collection('players')
      .doc(playerId)
      .update({
        isOnline: true,
        lastSeen: firestore.FieldValue.serverTimestamp(),
      });
  }

  public async markPlayerOffline(roomId: string, playerId: string): Promise<void> {
    try {
      await firestore()
        .collection('game_rooms')
        .doc(roomId)
        .collection('players')
        .doc(playerId)
        .update({
          isOnline: false,
          lastSeen: firestore.FieldValue.serverTimestamp(),
        });
    } catch (error) {
      console.error('Error marking player offline:', error);
    }
  }
}

export default FirebaseRoomService.getInstance();
```

---

## 4. GameMasterService

**Service critique** - Initialise le jeu côté serveur avec transaction atomique.

### React Native

```typescript
// src/services/firebase/gameMaster.service.ts
import firestore from '@react-native-firebase/firestore';
import { PlayingCard, CardSuit, CardValue } from '../types/card.types';
import { DeckGenerator } from '../utils/deckGenerator';

class GameMasterService {
  private static instance: GameMasterService;

  private constructor() {}

  public static getInstance(): GameMasterService {
    if (!GameMasterService.instance) {
      GameMasterService.instance = new GameMasterService();
    }
    return GameMasterService.instance;
  }

  // Initialiser une nouvelle partie
  public async initializeGame(roomId: string): Promise<void> {
    console.log('🎮 GameMasterService: Début d\'initialisation de la partie', roomId);

    try {
      await firestore().runTransaction(async (transaction) => {
        // 1. Générer et mélanger le deck
        const deck = DeckGenerator.shuffledDeck(true); // includeJokers = true
        console.log('🎮 Deck généré:', deck.length, 'cartes');

        // 2. Récupérer les joueurs
        const playersSnapshot = await firestore()
          .collection('game_rooms')
          .doc(roomId)
          .collection('players')
          .orderBy('position')
          .get();

        if (playersSnapshot.empty) {
          throw new Error('Aucun joueur trouvé dans la room');
        }

        const playerUids = playersSnapshot.docs.map((doc) => doc.id);

        console.log('🎮 ========== ORDRE DE JEU (playerOrder) ==========');
        playersSnapshot.docs.forEach((doc, i) => {
          console.log(`🎮   Position ${i}: ${doc.data().playerName} (${doc.id})`);
        });
        console.log('🎮 =================================================');

        // 3. Distribuer 5 cartes à chaque joueur
        const hands: Record<string, any[]> = {};
        let cardIndex = 0;

        for (const uid of playerUids) {
          const playerHand: any[] = [];
          for (let i = 0; i < 5; i++) {
            if (cardIndex >= deck.length) {
              throw new Error('Pas assez de cartes dans le deck');
            }
            playerHand.push(this.cardToJson(deck[cardIndex]));
            cardIndex++;
          }
          hands[uid] = playerHand;
          console.log(`🎮 Main distribuée au joueur ${uid}: ${playerHand.length} cartes`);
        }

        // 4. Première carte non-spéciale pour la défausse
        const firstCard = this.drawNonSpecialCard(deck, cardIndex);
        const discardPile = [this.cardToJson(firstCard.card)];
        cardIndex = firstCard.newIndex;
        console.log('🎮 Première carte de la défausse:', firstCard.card);

        // 5. Le reste du deck devient la pioche
        const remainingDeck = deck.slice(cardIndex);
        console.log('🎮 Cartes restantes dans la pioche:', remainingDeck.length);

        // 6. Mettre à jour le document principal de la room
        transaction.update(firestore().collection('game_rooms').doc(roomId), {
          status: 'playing',
          currentPlayerId: playerUids[0],
          direction: 1,
          skipCount: 0,
          cardsToDraw: 0,
          imposedSuit: null,
          phase: 'normal',
          isGameOver: false,
          updatedAt: firestore.FieldValue.serverTimestamp(),
        });

        // 7. Créer le document game_state/current
        transaction.set(
          firestore()
            .collection('game_rooms')
            .doc(roomId)
            .collection('game_state')
            .doc('current'),
          {
            deckSize: remainingDeck.length,
            discardPile,
            playerOrder: playerUids,
            finishingOrder: [],
            lastAction: {
              playerId: 'system',
              type: 'init_game',
              timestamp: firestore.FieldValue.serverTimestamp(),
            },
          }
        );

        // 8. Sauvegarder les mains privées
        for (const [uid, hand] of Object.entries(hands)) {
          transaction.set(
            firestore()
              .collection('game_rooms')
              .doc(roomId)
              .collection('player_hands')
              .doc(uid),
            { cards: hand }
          );

          transaction.set(
            firestore()
              .collection('game_rooms')
              .doc(roomId)
              .collection('players')
              .doc(uid),
            { handSize: hand.length },
            { merge: true }
          );
        }

        // 9. Sauvegarder le deck restant
        transaction.set(
          firestore()
            .collection('game_rooms')
            .doc(roomId)
            .collection('game_state')
            .doc('deck'),
          {
            cards: remainingDeck.map(this.cardToJson),
          }
        );

        // 10. Logger l'action
        transaction.set(
          firestore().collection('game_rooms').doc(roomId).collection('actions').doc(),
          {
            playerId: 'system',
            type: 'init_game',
            data: {
              playerCount: playerUids.length,
              initialDeckSize: deck.length,
              remainingDeckSize: remainingDeck.length,
            },
            timestamp: firestore.FieldValue.serverTimestamp(),
          }
        );

        console.log('🎮 GameMasterService: Transaction réussie');
      });

      console.log('✅ GameMasterService: Partie initialisée avec succès');
    } catch (error) {
      console.error('❌ GameMasterService: Erreur lors de l\'initialisation:', error);
      throw error;
    }
  }

  // Relancer une partie
  public async restartGame(roomId: string): Promise<void> {
    console.log('🔄 GameMasterService: Relance de la partie', roomId);

    try {
      const roomDoc = await firestore().collection('game_rooms').doc(roomId).get();
      if (!roomDoc.exists) {
        throw new Error('Room introuvable');
      }

      await this.initializeGame(roomId);
      console.log('✅ GameMasterService: Partie relancée avec succès');
    } catch (error) {
      console.error('❌ GameMasterService: Erreur lors de la relance:', error);
      throw error;
    }
  }

  // Convertir une carte en JSON
  private cardToJson(card: PlayingCard): { suit: number; value: number } {
    return {
      suit: card.suit,
      value: card.value,
    };
  }

  // Tirer la première carte non-spéciale
  private drawNonSpecialCard(
    deck: PlayingCard[],
    startIndex: number
  ): { card: PlayingCard; newIndex: number } {
    for (let i = startIndex; i < deck.length; i++) {
      const card = deck[i];
      if (
        ![
          CardValue.Ace,
          CardValue.Seven,
          CardValue.Joker,
          CardValue.Jack,
          CardValue.Two,
        ].includes(card.value)
      ) {
        return { card, newIndex: i + 1 };
      }
    }

    if (startIndex < deck.length) {
      return { card: deck[startIndex], newIndex: startIndex + 1 };
    }

    throw new Error('Plus de cartes disponibles dans le deck');
  }
}

export default GameMasterService.getInstance();
```

---

## 5. GameActionService

**Service le plus complexe** - Gère toutes les actions de jeu avec transactions atomiques.

### React Native (Simplifié - Voir fichier complet)

```typescript
// src/services/firebase/gameAction.service.ts
import firestore from '@react-native-firebase/firestore';
import { PlayingCard, CardSuit, CardValue } from '../types/card.types';
import { RuleEngine } from '../utils/ruleEngine';

class GameActionService {
  private static instance: GameActionService;

  private constructor() {}

  public static getInstance(): GameActionService {
    if (!GameActionService.instance) {
      GameActionService.instance = new GameActionService();
    }
    return GameActionService.instance;
  }

  // Jouer une carte
  public async playCard(
    roomId: string,
    playerId: string,
    cards: PlayingCard[],
    imposedSuit?: CardSuit
  ): Promise<void> {
    console.log(`🎮 GameActionService: Joueur ${playerId} joue ${cards.length} carte(s)`);

    try {
      await firestore().runTransaction(async (transaction) => {
        // 1. Lire l'état actuel
        const roomDoc = await transaction.get(
          firestore().collection('game_rooms').doc(roomId)
        );
        const gameStateDoc = await transaction.get(
          firestore()
            .collection('game_rooms')
            .doc(roomId)
            .collection('game_state')
            .doc('current')
        );
        const handDoc = await transaction.get(
          firestore()
            .collection('game_rooms')
            .doc(roomId)
            .collection('player_hands')
            .doc(playerId)
        );

        if (!roomDoc.exists || !gameStateDoc.exists || !handDoc.exists) {
          throw new Error('Données de jeu introuvables');
        }

        const roomData = roomDoc.data()!;
        const gameStateData = gameStateDoc.data()!;
        const handData = handDoc.data()!;

        // 2. Vérifier que c'est le tour du joueur
        if (roomData.currentPlayerId !== playerId) {
          throw new Error('Ce n\'est pas votre tour !');
        }

        // 3. Vérifier que le joueur possède les cartes
        const hand = handData.cards.map(this.jsonToCard);

        for (const card of cards) {
          if (!hand.some((c) => c.suit === card.suit && c.value === card.value)) {
            throw new Error(`Vous ne possédez pas cette carte`);
          }
        }

        // 4. Valider que la carte peut être jouée
        const discardPile = gameStateData.discardPile.map(this.jsonToCard);
        const topCard = discardPile[discardPile.length - 1];

        for (const card of cards) {
          if (
            !RuleEngine.canPlayCard(
              card,
              topCard,
              roomData.imposedSuit,
              roomData.cardsToDraw
            )
          ) {
            throw new Error('Cette carte ne peut pas être jouée');
          }
        }

        // 5. Retirer les cartes de la main
        const newHand = hand.filter(
          (c) => !cards.some((card) => card.suit === c.suit && card.value === c.value)
        );

        // 6. Ajouter à la défausse
        const newDiscardPile = [...discardPile, ...cards];

        // 7. Calculer les effets
        const effects = this.calculateEffects(cards, imposedSuit);

        // 8. Calculer le prochain joueur
        const playerOrder = gameStateData.playerOrder as string[];
        const nextPlayerInfo = this.getNextPlayer(
          playerOrder,
          playerId,
          roomData.direction,
          effects.skipCount
        );

        // 9. Vérifier si le joueur a gagné
        const hasWon = newHand.length === 0;
        const finishingOrder = [...(gameStateData.finishingOrder || [])];
        if (hasWon && !finishingOrder.includes(playerId)) {
          finishingOrder.push(playerId);
        }

        const activePlayers = playerOrder.filter(
          (id) => !finishingOrder.includes(id)
        ).length;

        let isGameOver = false;
        let gamePhase = roomData.phase;

        if (activePlayers <= 1) {
          // Game over
          if (activePlayers === 1) {
            const lastPlayer = playerOrder.find((id) => !finishingOrder.includes(id));
            if (lastPlayer) {
              finishingOrder.push(lastPlayer);
            }
          }
          isGameOver = true;
          gamePhase = 'finished';
        } else if (activePlayers === 2 && gamePhase !== 'duel') {
          gamePhase = 'duel';
        }

        // 10. Mettre à jour Firestore
        transaction.update(firestore().collection('game_rooms').doc(roomId), {
          currentPlayerId: nextPlayerInfo.playerId,
          direction: effects.direction || roomData.direction,
          skipCount: roomData.skipCount + effects.skipCount,
          cardsToDraw: roomData.cardsToDraw + effects.cardsToDraw,
          imposedSuit: effects.imposedSuit !== undefined ? effects.imposedSuit : null,
          isGameOver,
          phase: gamePhase,
          updatedAt: firestore.FieldValue.serverTimestamp(),
        });

        transaction.update(
          firestore()
            .collection('game_rooms')
            .doc(roomId)
            .collection('game_state')
            .doc('current'),
          {
            discardPile: newDiscardPile.map(this.cardToJson),
            finishingOrder,
            lastAction: {
              playerId,
              type: 'play_card',
              timestamp: firestore.FieldValue.serverTimestamp(),
            },
          }
        );

        transaction.update(
          firestore()
            .collection('game_rooms')
            .doc(roomId)
            .collection('player_hands')
            .doc(playerId),
          {
            cards: newHand.map(this.cardToJson),
          }
        );

        transaction.update(
          firestore()
            .collection('game_rooms')
            .doc(roomId)
            .collection('players')
            .doc(playerId),
          {
            handSize: newHand.length,
          }
        );

        // Logger l'action
        transaction.set(
          firestore().collection('game_rooms').doc(roomId).collection('actions').doc(),
          {
            playerId,
            type: 'play_card',
            data: {
              cards: cards.map(this.cardToJson),
              imposedSuit,
            },
            timestamp: firestore.FieldValue.serverTimestamp(),
          }
        );

        console.log('✅ GameActionService: Carte(s) jouée(s) avec succès');
      });
    } catch (error) {
      console.error('❌ GameActionService: Erreur:', error);
      throw error;
    }
  }

  // Piocher des cartes
  public async drawCard(roomId: string, playerId: string, count: number = 1): Promise<void> {
    console.log(`🎮 GameActionService: Joueur ${playerId} pioche ${count} carte(s)`);
    // ... (similaire à playCard, voir fichier complet)
  }

  // Calculer les effets des cartes
  private calculateEffects(
    cards: PlayingCard[],
    imposedSuit?: CardSuit
  ): {
    skipCount: number;
    cardsToDraw: number;
    direction?: number;
    imposedSuit?: CardSuit | null;
  } {
    let skipCount = 0;
    let cardsToDraw = 0;
    let direction: number | undefined;
    let imposedSuitResult: CardSuit | null | undefined;

    for (const card of cards) {
      switch (card.value) {
        case CardValue.Ace:
          skipCount += 1;
          break;
        case CardValue.Seven:
          cardsToDraw += 2;
          break;
        case CardValue.Joker:
          cardsToDraw += 4;
          break;
        case CardValue.Jack:
          if (imposedSuit !== undefined) {
            imposedSuitResult = imposedSuit;
          }
          break;
        default:
          break;
      }
    }

    return {
      skipCount,
      cardsToDraw,
      direction,
      imposedSuit: imposedSuitResult,
    };
  }

  // Calculer le prochain joueur
  private getNextPlayer(
    playerOrder: string[],
    currentPlayerId: string,
    direction: number,
    additionalSkips: number = 0
  ): { playerId: string; index: number } {
    const currentIndex = playerOrder.indexOf(currentPlayerId);
    if (currentIndex === -1) {
      throw new Error('Joueur actuel introuvable');
    }

    const totalSteps = 1 + additionalSkips;
    let newIndex = (currentIndex + direction * totalSteps) % playerOrder.length;

    if (newIndex < 0) {
      newIndex += playerOrder.length;
    }

    return {
      playerId: playerOrder[newIndex],
      index: newIndex,
    };
  }

  // Helpers de conversion
  private cardToJson(card: PlayingCard): { suit: number; value: number } {
    return {
      suit: card.suit,
      value: card.value,
    };
  }

  private jsonToCard(json: { suit: number; value: number }): PlayingCard {
    return {
      suit: json.suit as CardSuit,
      value: json.value as CardValue,
    };
  }
}

export default GameActionService.getInstance();
```

---

## 6. FirebaseGameSyncService

### React Native

```typescript
// src/services/firebase/gameSync.service.ts
import firestore, { FirebaseFirestoreTypes } from '@react-native-firebase/firestore';
import { GameState } from '../store/slices/gameSlice';

class FirebaseGameSyncService {
  private static instance: FirebaseGameSyncService;

  private constructor() {}

  public static getInstance(): FirebaseGameSyncService {
    if (!FirebaseGameSyncService.instance) {
      FirebaseGameSyncService.instance = new FirebaseGameSyncService();
    }
    return FirebaseGameSyncService.instance;
  }

  // Stream de l'état du jeu
  public streamGameState(
    roomId: string,
    callback: (data: any) => void
  ): () => void {
    return firestore()
      .collection('game_rooms')
      .doc(roomId)
      .collection('game_state')
      .doc('current')
      .onSnapshot((snapshot) => {
        if (snapshot.exists) {
          callback(snapshot.data());
        }
      });
  }

  // Stream de la room principale
  public streamRoom(
    roomId: string,
    callback: (data: any) => void
  ): () => void {
    return firestore()
      .collection('game_rooms')
      .doc(roomId)
      .onSnapshot((snapshot) => {
        if (snapshot.exists) {
          callback(snapshot.data());
        }
      });
  }

  // Stream de la main du joueur
  public streamPlayerHand(
    roomId: string,
    playerId: string,
    callback: (cards: any[]) => void
  ): () => void {
    return firestore()
      .collection('game_rooms')
      .doc(roomId)
      .collection('player_hands')
      .doc(playerId)
      .onSnapshot((snapshot) => {
        if (snapshot.exists) {
          callback(snapshot.data()?.cards || []);
        }
      });
  }

  // Stream des actions
  public streamActions(
    roomId: string,
    callback: (actions: any[]) => void
  ): () => void {
    return firestore()
      .collection('game_rooms')
      .doc(roomId)
      .collection('actions')
      .orderBy('timestamp')
      .onSnapshot((snapshot) => {
        const actions = snapshot.docs.map((doc) => ({
          id: doc.id,
          ...doc.data(),
        }));
        callback(actions);
      });
  }
}

export default FirebaseGameSyncService.getInstance();
```

---

## 7. CardAnimationService

### React Native

```typescript
// src/services/cardAnimation.service.ts
import { View } from 'react-native';

interface CardPosition {
  x: number;
  y: number;
}

class CardAnimationService {
  private static instance: CardAnimationService;

  private constructor() {}

  public static getInstance(): CardAnimationService {
    if (!CardAnimationService.instance) {
      CardAnimationService.instance = new CardAnimationService();
    }
    return CardAnimationService.instance;
  }

  // Obtenir la position d'un élément via ref
  public getPosition(ref: React.RefObject<View>): Promise<CardPosition | null> {
    return new Promise((resolve) => {
      if (!ref.current) {
        resolve(null);
        return;
      }

      ref.current.measure((x, y, width, height, pageX, pageY) => {
        resolve({ x: pageX, y: pageY });
      });
    });
  }

  // Animer des cartes vers la défausse
  public async animateCardsToDiscard(
    cardRefs: React.RefObject<View>[],
    discardRef: React.RefObject<View>,
    onComplete: () => void
  ): Promise<void> {
    const startPositions: CardPosition[] = [];

    for (const ref of cardRefs) {
      const pos = await this.getPosition(ref);
      if (pos) {
        startPositions.push(pos);
      }
    }

    const endPosition = await this.getPosition(discardRef);

    if (!endPosition || startPositions.length === 0) {
      onComplete();
      return;
    }

    // Déclencher l'overlay d'animation (voir AnimatedCardOverlay component)
    // Cette partie sera gérée par le composant AnimatedCardOverlay
    onComplete();
  }
}

export default CardAnimationService.getInstance();
```

---

## Architecture des Services

### Structure des dossiers

```
src/
├── services/
│   ├── audio.service.ts
│   ├── cardAnimation.service.ts
│   └── firebase/
│       ├── firebaseAuth.service.ts
│       ├── firebaseRoom.service.ts
│       ├── gameMaster.service.ts
│       ├── gameAction.service.ts
│       └── gameSync.service.ts
```

### Pattern Singleton

Tous les services utilisent le pattern Singleton:

```typescript
class MyService {
  private static instance: MyService;

  private constructor() {}

  public static getInstance(): MyService {
    if (!MyService.instance) {
      MyService.instance = new MyService();
    }
    return MyService.instance;
  }
}

export default MyService.getInstance();
```

### Utilisation

```typescript
// Import direct
import audioService from './services/audio.service';
import authService from './services/firebase/firebaseAuth.service';
import roomService from './services/firebase/firebaseRoom.service';

// Utilisation
audioService.playSound('cardMove');
const user = authService.getCurrentUser();
await roomService.createRoom(userId, username);
```

---

## Checklist de Migration

### AudioService
- [ ] Installer `react-native-sound`
- [ ] Créer `audio.service.ts`
- [ ] Ajouter fichiers audio dans `android/app/src/main/res/raw/`
- [ ] Ajouter fichiers audio dans `ios/[ProjectName]/`
- [ ] Tester lecture de musique
- [ ] Tester effets sonores
- [ ] Tester activation/désactivation
- [ ] Intégrer AsyncStorage pour persistance

### FirebaseAuthService
- [ ] Installer `@react-native-firebase/auth`
- [ ] Installer `@react-native-firebase/firestore`
- [ ] Configurer Firebase (iOS + Android)
- [ ] Créer `firebaseAuth.service.ts`
- [ ] Implémenter signUp
- [ ] Implémenter signIn
- [ ] Implémenter signInAnonymously
- [ ] Implémenter getUserProfile
- [ ] Tester toutes les méthodes
- [ ] Gérer les erreurs

### FirebaseRoomService
- [ ] Créer `firebaseRoom.service.ts`
- [ ] Implémenter createRoom
- [ ] Implémenter joinRoom
- [ ] Implémenter leaveRoom
- [ ] Implémenter streamRoom
- [ ] Implémenter streamRoomPlayers
- [ ] Implémenter streamAvailableRooms
- [ ] Tester création de salle
- [ ] Tester rejoindre salle
- [ ] Tester présence en temps réel

### GameMasterService
- [ ] Créer `gameMaster.service.ts`
- [ ] Implémenter initializeGame
- [ ] Implémenter restartGame
- [ ] Tester génération de deck
- [ ] Tester distribution des cartes
- [ ] Tester transaction atomique
- [ ] Tester avec 2-4 joueurs

### GameActionService
- [ ] Créer `gameAction.service.ts`
- [ ] Implémenter playCard
- [ ] Implémenter drawCard
- [ ] Implémenter endTurn
- [ ] Implémenter calculateEffects
- [ ] Implémenter getNextPlayer
- [ ] Tester toutes les cartes spéciales
- [ ] Tester cumulus
- [ ] Tester fin de partie

### FirebaseGameSyncService
- [ ] Créer `gameSync.service.ts`
- [ ] Implémenter streamGameState
- [ ] Implémenter streamRoom
- [ ] Implémenter streamPlayerHand
- [ ] Intégrer avec Redux
- [ ] Tester synchronisation

### CardAnimationService
- [ ] Créer `cardAnimation.service.ts`
- [ ] Implémenter getPosition
- [ ] Implémenter animateCardsToDiscard
- [ ] Intégrer avec AnimatedCardOverlay
- [ ] Tester animations

---

## Dépendances npm complètes

```bash
# Audio
npm install react-native-sound

# Firebase
npm install @react-native-firebase/app
npm install @react-native-firebase/auth
npm install @react-native-firebase/firestore

# Storage
npm install @react-native-async-storage/async-storage

# iOS
cd ios && pod install
```

---

## Configuration Firebase

### Android (`android/build.gradle`)

```gradle
buildscript {
  dependencies {
    classpath 'com.google.gms:google-services:4.3.15'
  }
}
```

### Android (`android/app/build.gradle`)

```gradle
apply plugin: 'com.google.gms.google-services'

dependencies {
  implementation platform('com.google.firebase:firebase-bom:31.5.0')
}
```

### iOS (`ios/Podfile`)

```ruby
use_frameworks! :linkage => :static

pod 'Firebase', :modular_headers => true
pod 'FirebaseCore', :modular_headers => true
pod 'GoogleUtilities', :modular_headers => true
```

---

## Conseils de Migration

### 1. Ordre recommandé

Migrez dans cet ordre :
1. **AudioService** (le plus simple)
2. **FirebaseAuthService** (authentification d'abord)
3. **FirebaseRoomService** (salles de jeu)
4. **FirebaseGameSyncService** (synchronisation)
5. **GameMasterService** (initialisation du jeu)
6. **GameActionService** (actions du jeu - LE PLUS COMPLEXE)
7. **CardAnimationService** (animations)

### 2. Tests unitaires

Pour chaque service, créez des tests :

```typescript
// __tests__/services/audio.service.test.ts
import audioService from '../services/audio.service';

describe('AudioService', () => {
  it('should enable sound', async () => {
    await audioService.enableSound();
    expect(audioService.isSoundEnabled()).toBe(true);
  });

  it('should play sound when enabled', () => {
    audioService.enableSound();
    // Mock Sound et tester
  });
});
```

### 3. Gestion des erreurs

Tous les services Firebase doivent gérer les erreurs réseau :

```typescript
try {
  await gameActionService.playCard(roomId, playerId, cards);
} catch (error) {
  if (error.message.includes('network')) {
    Alert.alert('Erreur réseau', 'Vérifiez votre connexion');
  } else {
    Alert.alert('Erreur', error.message);
  }
}
```

### 4. Performance

- Utilisez `runTransaction` pour toutes les opérations critiques
- Limitez les listeners Firestore (unsubscribe dans `useEffect` cleanup)
- Utilisez `AsyncStorage` pour cacher les settings
- Debounce les appels API si nécessaire

### 5. Debugging

Pour debug Firebase :

```typescript
// Enable Firebase logging
firestore().settings({
  persistence: true,
  cacheSizeBytes: firestore.CACHE_SIZE_UNLIMITED,
});

// Log all Firestore operations
firestore.setLogLevel('debug');
```

---

## Ressources

- [React Native Firebase Docs](https://rnfirebase.io/)
- [React Native Sound](https://github.com/zmxv/react-native-sound)
- [AsyncStorage](https://react-native-async-storage.github.io/async-storage/)
- [Firestore Transactions](https://firebase.google.com/docs/firestore/manage-data/transactions)

Bon courage pour la migration des services ! Les **GameMasterService** et **GameActionService** sont les plus critiques et complexes. Prenez votre temps pour bien tester les transactions atomiques. 🔥🚀
