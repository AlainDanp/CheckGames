# Guide Complet: Migration des Screens Flutter → React Native

## Table des Matières

1. [Vue d'ensemble des Screens](#vue-densemble-des-screens)
2. [MainMenuScreen](#1-mainmenuscreen)
3. [AuthScreen](#2-authscreen)
4. [MultiplayerLobbyScreen](#3-multiplayerlobbyscreen)
5. [WaitingRoomScreen](#4-waitingroomscreen)
6. [GameScreen](#5-gamescreen)
7. [MultiplayerGameScreen](#6-multiplayergamescreen)
8. [Navigation et Routing](#navigation-et-routing)
9. [Hooks React Personnalisés](#hooks-react-personnalisés)
10. [Checklist de Migration](#checklist-de-migration)

---

## Vue d'ensemble des Screens

Votre application Flutter CheckGames contient **6 écrans principaux** :

| Flutter | React Native | Complexité | Dépendances |
|---------|--------------|------------|-------------|
| `main_menu_screen.dart` | `MainMenuScreen.tsx` | ⭐ Simple | Audio, Navigation |
| `auth_screen.dart` | `AuthScreen.tsx` | ⭐⭐ Moyen | Firebase Auth, Validation |
| `multiplayer_lobby_screen.dart` | `MultiplayerLobbyScreen.tsx` | ⭐⭐⭐ Complexe | Firestore Stream, Firebase Auth |
| `waiting_room_screen.dart` | `WaitingRoomScreen.tsx` | ⭐⭐ Moyen | Firestore Stream, Navigation |
| `game_page.dart` | `GameScreen.tsx` | ⭐⭐⭐⭐⭐ Très complexe | Redux, Animations, BLoC |
| `multiplayer_game_page.dart` | `MultiplayerGameScreen.tsx` | ⭐⭐⭐⭐ Complexe | Firestore, Redux, Wrapper |

---

## 1. MainMenuScreen

### Flutter (Avant)

```dart
// lib/ui/main_menu_screen.dart
class MainMenuScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF145A32), Color(0xFF0B3D2E)],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.casino, size: 80, color: Colors.white),
            Text('CHECKGAMES', style: TextStyle(fontSize: 48)),
            _MenuButton(
              icon: Icons.person,
              label: 'JOUER SOLO',
              onPressed: () => Navigator.push(...),
            ),
            _MenuButton(
              icon: Icons.public,
              label: 'JOUER EN LIGNE',
              onPressed: () => Navigator.push(...),
            ),
          ],
        ),
      ),
    );
  }
}
```

### React Native (Après)

```tsx
// src/screens/MainMenuScreen.tsx
import React from 'react';
import { View, Text, StyleSheet, TouchableOpacity } from 'react-native';
import { StackNavigationProp } from '@react-navigation/stack';
import { RootStackParamList } from '../navigation/AppNavigator';
import Icon from 'react-native-vector-icons/MaterialIcons';
import LinearGradient from 'react-native-linear-gradient';
import audioService from '../services/audio.service';

type MainMenuScreenNavigationProp = StackNavigationProp<RootStackParamList, 'MainMenu'>;

interface Props {
  navigation: MainMenuScreenNavigationProp;
}

export default function MainMenuScreen({ navigation }: Props) {
  React.useEffect(() => {
    // Démarrer la musique de fond au montage
    audioService.playMusic();

    return () => {
      // Arrêter la musique au démontage (optionnel)
      // audioService.pauseMusic();
    };
  }, []);

  const handleSoloPress = () => {
    audioService.playSound('buttonClick');
    navigation.navigate('Game', { playerNames: ['Vous', 'Bot 1', 'Bot 2', 'Bot 3'] });
  };

  const handleMultiplayerPress = () => {
    audioService.playSound('buttonClick');
    navigation.navigate('Auth');
  };

  const handleSettingsPress = () => {
    audioService.playSound('buttonClick');
    // TODO: Navigation vers Settings
  };

  return (
    <LinearGradient
      colors={['#145A32', '#0B3D2E']}
      style={styles.container}
    >
      <View style={styles.content}>
        {/* Logo/Titre */}
        <Icon name="casino" size={80} color="#FFFFFF" />
        <Text style={styles.title}>CHECKGAMES</Text>
        <Text style={styles.subtitle}>Le jeu de cartes</Text>

        {/* Boutons principaux */}
        <View style={styles.buttonContainer}>
          <MenuButton
            icon="person"
            label="JOUER SOLO"
            subtitle="Affronter le CPU"
            onPress={handleSoloPress}
            gradientColors={['#27AE60', '#1E8449']}
          />

          <MenuButton
            icon="public"
            label="JOUER EN LIGNE"
            subtitle="Affronter des joueurs"
            onPress={handleMultiplayerPress}
            gradientColors={['#E67E22', '#CA6F1E']}
          />
        </View>

        {/* Bouton Paramètres */}
        <TouchableOpacity style={styles.settingsButton} onPress={handleSettingsPress}>
          <Icon name="settings" size={20} color="#FFFFFF80" />
          <Text style={styles.settingsText}>Paramètres</Text>
        </TouchableOpacity>
      </View>
    </LinearGradient>
  );
}

// Composant MenuButton
interface MenuButtonProps {
  icon: string;
  label: string;
  subtitle: string;
  onPress: () => void;
  gradientColors: string[];
}

function MenuButton({ icon, label, subtitle, onPress, gradientColors }: MenuButtonProps) {
  return (
    <TouchableOpacity style={styles.menuButton} onPress={onPress} activeOpacity={0.8}>
      <LinearGradient
        colors={gradientColors}
        style={styles.menuButtonGradient}
        start={{ x: 0, y: 0 }}
        end={{ x: 1, y: 1 }}
      >
        <Icon name={icon} size={48} color="#FFFFFF" />
        <View style={styles.menuButtonTextContainer}>
          <Text style={styles.menuButtonLabel}>{label}</Text>
          <Text style={styles.menuButtonSubtitle}>{subtitle}</Text>
        </View>
        <Icon name="arrow-forward-ios" size={24} color="#FFFFFF80" />
      </LinearGradient>
    </TouchableOpacity>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  content: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 24,
  },
  title: {
    fontSize: 48,
    fontWeight: 'bold',
    color: '#FFFFFF',
    letterSpacing: 2,
    marginTop: 16,
    textShadowColor: 'rgba(0, 0, 0, 0.45)',
    textShadowOffset: { width: 2, height: 2 },
    textShadowRadius: 10,
  },
  subtitle: {
    fontSize: 18,
    color: '#FFFFFF80',
    fontStyle: 'italic',
    marginTop: 8,
    marginBottom: 60,
  },
  buttonContainer: {
    width: '100%',
    gap: 20,
  },
  menuButton: {
    width: '100%',
    height: 100,
    borderRadius: 16,
    overflow: 'hidden',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.3,
    shadowRadius: 8,
    elevation: 8,
  },
  menuButtonGradient: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 16,
    gap: 20,
  },
  menuButtonTextContainer: {
    flex: 1,
  },
  menuButtonLabel: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#FFFFFF',
    letterSpacing: 1,
  },
  menuButtonSubtitle: {
    fontSize: 14,
    color: '#FFFFFF80',
    marginTop: 4,
  },
  settingsButton: {
    flexDirection: 'row',
    alignItems: 'center',
    marginTop: 40,
    gap: 8,
  },
  settingsText: {
    fontSize: 16,
    color: '#FFFFFF80',
  },
});
```

### Différences clés

| Flutter | React Native |
|---------|--------------|
| `Container` avec `BoxDecoration` | `LinearGradient` component |
| `StatelessWidget` | Functional Component |
| `Navigator.push()` | `navigation.navigate()` |
| `Icon(Icons.casino)` | `<Icon name="casino" />` (react-native-vector-icons) |
| `TextStyle(shadows)` | `textShadow*` props |

### Dépendances nécessaires

```bash
npm install react-native-linear-gradient
npm install react-native-vector-icons
```

---

## 2. AuthScreen

### Flutter (Avant)

```dart
class AuthScreen extends StatefulWidget {
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLogin = true;

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      try {
        if (_isLogin) {
          await _authService.signIn(...);
        } else {
          await _authService.signUp(...);
        }
        Navigator.pushReplacementNamed(context, '/lobby');
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(...);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              controller: _emailController,
              validator: _validateEmail,
            ),
            TextFormField(
              controller: _passwordController,
              validator: _validatePassword,
              obscureText: true,
            ),
            ElevatedButton(onPressed: _submit),
          ],
        ),
      ),
    );
  }
}
```

### React Native (Après)

```tsx
// src/screens/AuthScreen.tsx
import React, { useState } from 'react';
import {
  View,
  Text,
  TextInput,
  TouchableOpacity,
  StyleSheet,
  KeyboardAvoidingView,
  Platform,
  ActivityIndicator,
  ScrollView,
} from 'react-native';
import { StackNavigationProp } from '@react-navigation/stack';
import { RootStackParamList } from '../navigation/AppNavigator';
import Icon from 'react-native-vector-icons/MaterialIcons';
import LinearGradient from 'react-native-linear-gradient';
import authService from '../services/firebase/auth.service';

type AuthScreenNavigationProp = StackNavigationProp<RootStackParamList, 'Auth'>;

interface Props {
  navigation: AuthScreenNavigationProp;
}

export default function AuthScreen({ navigation }: Props) {
  const [isLogin, setIsLogin] = useState(true);
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [username, setUsername] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [emailError, setEmailError] = useState('');
  const [passwordError, setPasswordError] = useState('');

  const validateEmail = (value: string): boolean => {
    if (!value) {
      setEmailError('Email requis');
      return false;
    }
    const emailRegex = /^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$/;
    if (!emailRegex.test(value)) {
      setEmailError('Email invalide');
      return false;
    }
    setEmailError('');
    return true;
  };

  const validatePassword = (value: string): boolean => {
    if (!value) {
      setPasswordError('Mot de passe requis');
      return false;
    }
    if (value.length < 6) {
      setPasswordError('Au moins 6 caractères');
      return false;
    }
    setPasswordError('');
    return true;
  };

  const handleSubmit = async () => {
    const isEmailValid = validateEmail(email);
    const isPasswordValid = validatePassword(password);

    if (!isEmailValid || !isPasswordValid) return;

    setIsLoading(true);

    try {
      if (isLogin) {
        await authService.signInWithEmail(email.trim(), password);
      } else {
        await authService.signUpWithEmail(email.trim(), password, username.trim());
      }

      // Navigation vers le lobby
      navigation.replace('MultiplayerLobby');
    } catch (error: any) {
      // Afficher l'erreur
      Alert.alert('Erreur', error.message || 'Une erreur est survenue');
    } finally {
      setIsLoading(false);
    }
  };

  const handleAnonymousSignIn = async () => {
    try {
      await authService.signInAnonymously(username || 'Invité');
      navigation.replace('MultiplayerLobby');
    } catch (error: any) {
      Alert.alert('Erreur', error.message || 'Une erreur est survenue');
    }
  };

  return (
    <KeyboardAvoidingView
      style={styles.container}
      behavior={Platform.OS === 'ios' ? 'padding' : undefined}
    >
      <ScrollView contentContainerStyle={styles.scrollContent}>
        {/* Logo */}
        <View style={styles.logoContainer}>
          <LinearGradient
            colors={['#0E766E', '#145A32']}
            style={styles.logoGradient}
          >
            <Icon name="casino" size={60} color="#FFFFFF" />
          </LinearGradient>
          <Text style={styles.appName}>CheckGames</Text>
        </View>

        {/* Formulaire */}
        <View style={styles.formContainer}>
          {/* Champ Username (uniquement en mode inscription) */}
          {!isLogin && (
            <View style={styles.inputContainer}>
              <Icon name="person" size={20} color="#666" style={styles.inputIcon} />
              <TextInput
                style={styles.input}
                placeholder="Nom d'utilisateur"
                value={username}
                onChangeText={setUsername}
                autoCapitalize="words"
              />
            </View>
          )}

          {/* Champ Email */}
          <View style={styles.inputContainer}>
            <Icon name="email" size={20} color="#666" style={styles.inputIcon} />
            <TextInput
              style={styles.input}
              placeholder="Email"
              value={email}
              onChangeText={setEmail}
              keyboardType="email-address"
              autoCapitalize="none"
              autoCorrect={false}
            />
          </View>
          {emailError ? <Text style={styles.errorText}>{emailError}</Text> : null}

          {/* Champ Password */}
          <View style={styles.inputContainer}>
            <Icon name="lock" size={20} color="#666" style={styles.inputIcon} />
            <TextInput
              style={styles.input}
              placeholder="Mot de passe"
              value={password}
              onChangeText={setPassword}
              secureTextEntry
              autoCapitalize="none"
            />
          </View>
          {passwordError ? <Text style={styles.errorText}>{passwordError}</Text> : null}

          {/* Bouton Submit */}
          <TouchableOpacity
            style={styles.submitButton}
            onPress={handleSubmit}
            disabled={isLoading}
          >
            <LinearGradient
              colors={['#0E766E', '#145A32']}
              style={styles.submitGradient}
            >
              {isLoading ? (
                <ActivityIndicator color="#FFFFFF" />
              ) : (
                <Text style={styles.submitText}>
                  {isLogin ? 'Se connecter' : "S'inscrire"}
                </Text>
              )}
            </LinearGradient>
          </TouchableOpacity>

          {/* Toggle Login/Register */}
          <TouchableOpacity onPress={() => setIsLogin(!isLogin)}>
            <Text style={styles.toggleText}>
              {isLogin ? "Pas de compte ? Inscription" : "Déjà un compte ? Connexion"}
            </Text>
          </TouchableOpacity>

          {/* Divider */}
          <View style={styles.divider}>
            <View style={styles.dividerLine} />
            <Text style={styles.dividerText}>OU</Text>
            <View style={styles.dividerLine} />
          </View>

          {/* Bouton Anonyme */}
          <TouchableOpacity
            style={styles.anonymousButton}
            onPress={handleAnonymousSignIn}
          >
            <Icon name="person-outline" size={22} color="#0E766E" />
            <Text style={styles.anonymousText}>Continuer en tant qu'invité</Text>
          </TouchableOpacity>
        </View>
      </ScrollView>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#FFFFFF',
  },
  scrollContent: {
    flexGrow: 1,
    padding: 24,
    justifyContent: 'center',
  },
  logoContainer: {
    alignItems: 'center',
    marginBottom: 40,
  },
  logoGradient: {
    width: 120,
    height: 120,
    borderRadius: 60,
    justifyContent: 'center',
    alignItems: 'center',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 10 },
    shadowOpacity: 0.25,
    shadowRadius: 20,
    elevation: 10,
  },
  appName: {
    fontSize: 22,
    fontWeight: 'bold',
    color: '#333',
    marginTop: 20,
  },
  formContainer: {
    gap: 16,
  },
  inputContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#F5F5F5',
    borderRadius: 12,
    paddingHorizontal: 16,
    borderWidth: 1,
    borderColor: '#E0E0E0',
  },
  inputIcon: {
    marginRight: 12,
  },
  input: {
    flex: 1,
    height: 56,
    fontSize: 16,
    color: '#333',
  },
  errorText: {
    color: '#E74C3C',
    fontSize: 12,
    marginTop: -8,
    marginLeft: 16,
  },
  submitButton: {
    height: 56,
    borderRadius: 12,
    overflow: 'hidden',
    marginTop: 8,
  },
  submitGradient: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  submitText: {
    color: '#FFFFFF',
    fontSize: 16,
    fontWeight: 'bold',
  },
  toggleText: {
    textAlign: 'center',
    color: '#0E766E',
    fontSize: 14,
  },
  divider: {
    flexDirection: 'row',
    alignItems: 'center',
    marginVertical: 10,
  },
  dividerLine: {
    flex: 1,
    height: 1,
    backgroundColor: '#E0E0E0',
  },
  dividerText: {
    marginHorizontal: 10,
    color: '#999',
    fontSize: 12,
  },
  anonymousButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    height: 56,
    borderRadius: 12,
    borderWidth: 2,
    borderColor: '#0E766E',
    gap: 8,
  },
  anonymousText: {
    color: '#0E766E',
    fontSize: 16,
    fontWeight: '600',
  },
});
```

### Différences clés

| Flutter | React Native |
|---------|--------------|
| `TextEditingController` | `useState` hook |
| `Form` + `GlobalKey<FormState>` | Validation manuelle avec state |
| `validator` prop | Fonctions `validate*()` personnalisées |
| `ScaffoldMessenger.showSnackBar` | `Alert.alert()` |
| `Navigator.pushReplacementNamed` | `navigation.replace()` |
| Auto-scroll keyboard | `KeyboardAvoidingView` + `ScrollView` |

### Hooks personnalisés (optionnel)

```tsx
// src/hooks/useFormValidation.ts
import { useState } from 'react';

interface FormValidation {
  value: string;
  error: string;
  setValue: (value: string) => void;
  validate: () => boolean;
}

export function useEmailValidation(): FormValidation {
  const [value, setValue] = useState('');
  const [error, setError] = useState('');

  const validate = () => {
    if (!value) {
      setError('Email requis');
      return false;
    }
    const emailRegex = /^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$/;
    if (!emailRegex.test(value)) {
      setError('Email invalide');
      return false;
    }
    setError('');
    return true;
  };

  return { value, error, setValue, validate };
}

export function usePasswordValidation(minLength: number = 6): FormValidation {
  const [value, setValue] = useState('');
  const [error, setError] = useState('');

  const validate = () => {
    if (!value) {
      setError('Mot de passe requis');
      return false;
    }
    if (value.length < minLength) {
      setError(`Au moins ${minLength} caractères`);
      return false;
    }
    setError('');
    return true;
  };

  return { value, error, setValue, validate };
}
```

**Usage:**

```tsx
const email = useEmailValidation();
const password = usePasswordValidation(6);

<TextInput
  value={email.value}
  onChangeText={email.setValue}
/>
{email.error ? <Text>{email.error}</Text> : null}

const handleSubmit = () => {
  if (!email.validate() || !password.validate()) return;
  // ...
};
```

---

## 3. MultiplayerLobbyScreen

### Flutter (Avant)

```dart
class MultiplayerLobbyScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Multijoueur'),
        actions: [
          // Avatar + PopupMenu
        ],
      ),
      body: Column(
        children: [
          // Stats du joueur
          FutureBuilder(
            future: _getPlayerStats(),
            builder: (context, snapshot) {
              return Row(
                children: [
                  _buildStatItem(icon: Icons.emoji_events, label: 'Victoires'),
                ],
              );
            },
          ),
          // Boutons Créer/Rejoindre
          ElevatedButton(onPressed: () => _createRoom()),
          // Liste des parties disponibles
          Expanded(
            child: StreamBuilder(
              stream: _roomService.getAvailableRooms(),
              builder: (context, snapshot) {
                return ListView.builder(...);
              },
            ),
          ),
        ],
      ),
    );
  }
}
```

### React Native (Après)

```tsx
// src/screens/MultiplayerLobbyScreen.tsx
import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  FlatList,
  TouchableOpacity,
  StyleSheet,
  ActivityIndicator,
  Alert,
  Modal,
  TextInput,
} from 'react-native';
import { StackNavigationProp } from '@react-navigation/stack';
import { RootStackParamList } from '../navigation/AppNavigator';
import Icon from 'react-native-vector-icons/MaterialIcons';
import LinearGradient from 'react-native-linear-gradient';
import authService from '../services/firebase/auth.service';
import roomService from '../services/firebase/room.service';
import { GameRoom } from '../types/multiplayer.types';

type MultiplayerLobbyScreenNavigationProp = StackNavigationProp<
  RootStackParamList,
  'MultiplayerLobby'
>;

interface Props {
  navigation: MultiplayerLobbyScreenNavigationProp;
}

export default function MultiplayerLobbyScreen({ navigation }: Props) {
  const [rooms, setRooms] = useState<GameRoom[]>([]);
  const [userProfile, setUserProfile] = useState<any>(null);
  const [playerStats, setPlayerStats] = useState<any>(null);
  const [showJoinDialog, setShowJoinDialog] = useState(false);
  const [roomCode, setRoomCode] = useState('');
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    loadUserData();
    subscribeToRooms();
  }, []);

  const loadUserData = async () => {
    try {
      const currentUser = authService.getCurrentUser();
      if (!currentUser) {
        navigation.replace('Auth');
        return;
      }

      const profile = await authService.getUserProfile(currentUser.uid);
      setUserProfile(profile);

      // Charger les stats (si disponible)
      // const stats = await statsService.getPlayerStats(profile.username);
      // setPlayerStats(stats);
    } catch (error) {
      console.error('Error loading user data:', error);
    } finally {
      setIsLoading(false);
    }
  };

  const subscribeToRooms = () => {
    // Écouter les rooms disponibles
    const unsubscribe = roomService.streamAvailableRooms((availableRooms) => {
      setRooms(availableRooms);
    });

    return () => unsubscribe();
  };

  const handleCreateRoom = async () => {
    try {
      const currentUser = authService.getCurrentUser();
      if (!currentUser || !userProfile) return;

      const room = await roomService.createRoom(userProfile.username, 4);

      navigation.navigate('WaitingRoom', {
        roomId: room.id,
        roomCode: room.code,
        isHost: true,
      });
    } catch (error: any) {
      Alert.alert('Erreur', error.message);
    }
  };

  const handleJoinByCode = async () => {
    if (roomCode.length !== 6) {
      Alert.alert('Erreur', 'Le code doit contenir 6 caractères');
      return;
    }

    try {
      const currentUser = authService.getCurrentUser();
      if (!currentUser || !userProfile) return;

      const room = await roomService.joinRoom(roomCode.toUpperCase(), userProfile.username);

      setShowJoinDialog(false);
      setRoomCode('');

      navigation.navigate('WaitingRoom', {
        roomId: room.id,
        roomCode: room.code,
        isHost: false,
      });
    } catch (error: any) {
      Alert.alert('Erreur', error.message);
    }
  };

  const handleJoinRoom = async (room: GameRoom) => {
    try {
      const currentUser = authService.getCurrentUser();
      if (!currentUser || !userProfile) return;

      await roomService.joinRoom(room.code, userProfile.username);

      navigation.navigate('WaitingRoom', {
        roomId: room.id,
        roomCode: room.code,
        isHost: false,
      });
    } catch (error: any) {
      Alert.alert('Erreur', error.message);
    }
  };

  const handleLogout = async () => {
    try {
      await authService.signOut();
      navigation.replace('Auth');
    } catch (error: any) {
      Alert.alert('Erreur', error.message);
    }
  };

  const renderRoomItem = ({ item }: { item: GameRoom }) => (
    <View style={styles.roomCard}>
      <View style={styles.roomHeader}>
        <Text style={styles.roomTitle}>Partie {item.code}</Text>
        <View style={styles.roomBadge}>
          <Icon name="people" size={16} color="#666" />
          <Text style={styles.roomBadgeText}>
            {item.currentPlayers}/{item.maxPlayers}
          </Text>
        </View>
      </View>

      <View style={styles.roomInfo}>
        <Text style={styles.roomHost}>Hôte: {item.hostName}</Text>
        <Text style={styles.roomStatus}>{item.status}</Text>
      </View>

      <TouchableOpacity
        style={styles.joinButton}
        onPress={() => handleJoinRoom(item)}
        disabled={item.currentPlayers >= item.maxPlayers}
      >
        <Text style={styles.joinButtonText}>Rejoindre</Text>
      </TouchableOpacity>
    </View>
  );

  if (isLoading) {
    return (
      <View style={styles.loadingContainer}>
        <ActivityIndicator size="large" color="#0E766E" />
      </View>
    );
  }

  return (
    <View style={styles.container}>
      {/* Header */}
      <LinearGradient colors={['#0E766E', '#145A32']} style={styles.header}>
        <Text style={styles.headerTitle}>Multijoueur</Text>
        <TouchableOpacity onPress={handleLogout}>
          <Icon name="logout" size={24} color="#FFFFFF" />
        </TouchableOpacity>
      </LinearGradient>

      {/* Stats du joueur */}
      <LinearGradient
        colors={['#0E766E', '#145A32']}
        style={styles.statsContainer}
        start={{ x: 0, y: 0 }}
        end={{ x: 1, y: 1 }}
      >
        <StatItem icon="emoji-events" label="Victoires" value={playerStats?.wins || 0} />
        <StatItem icon="gamepad" label="Parties" value={playerStats?.gamesPlayed || 0} />
        <StatItem icon="trending-up" label="Ratio" value={`${playerStats?.winRate || 0}%`} />
      </LinearGradient>

      {/* Boutons d'action */}
      <View style={styles.actionButtons}>
        <TouchableOpacity style={styles.createButton} onPress={handleCreateRoom}>
          <Icon name="add" size={24} color="#FFFFFF" />
          <Text style={styles.createButtonText}>Créer une partie</Text>
        </TouchableOpacity>

        <TouchableOpacity
          style={styles.joinCodeButton}
          onPress={() => setShowJoinDialog(true)}
        >
          <Icon name="login" size={24} color="#0E766E" />
          <Text style={styles.joinCodeButtonText}>Rejoindre avec code</Text>
        </TouchableOpacity>
      </View>

      {/* Liste des parties */}
      <View style={styles.roomsSection}>
        <Text style={styles.sectionTitle}>Parties disponibles</Text>

        {rooms.length === 0 ? (
          <View style={styles.emptyState}>
            <Icon name="inbox" size={64} color="#CCC" />
            <Text style={styles.emptyText}>Aucune partie disponible</Text>
          </View>
        ) : (
          <FlatList
            data={rooms}
            renderItem={renderRoomItem}
            keyExtractor={(item) => item.id}
            contentContainerStyle={styles.roomsList}
          />
        )}
      </View>

      {/* Modal Rejoindre avec code */}
      <Modal visible={showJoinDialog} transparent animationType="slide">
        <View style={styles.modalOverlay}>
          <View style={styles.modalContent}>
            <Text style={styles.modalTitle}>Rejoindre une partie</Text>

            <TextInput
              style={styles.codeInput}
              placeholder="Code à 6 caractères"
              value={roomCode}
              onChangeText={(text) => setRoomCode(text.toUpperCase())}
              maxLength={6}
              autoCapitalize="characters"
            />

            <View style={styles.modalButtons}>
              <TouchableOpacity
                style={styles.modalCancelButton}
                onPress={() => {
                  setShowJoinDialog(false);
                  setRoomCode('');
                }}
              >
                <Text style={styles.modalCancelText}>Annuler</Text>
              </TouchableOpacity>

              <TouchableOpacity style={styles.modalJoinButton} onPress={handleJoinByCode}>
                <Text style={styles.modalJoinText}>Rejoindre</Text>
              </TouchableOpacity>
            </View>
          </View>
        </View>
      </Modal>
    </View>
  );
}

// Composant StatItem
interface StatItemProps {
  icon: string;
  label: string;
  value: string | number;
}

function StatItem({ icon, label, value }: StatItemProps) {
  return (
    <View style={styles.statItem}>
      <Icon name={icon} size={28} color="#FFFFFF" />
      <Text style={styles.statValue}>{value}</Text>
      <Text style={styles.statLabel}>{label}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#F5F5F5',
  },
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: 20,
    paddingVertical: 16,
    paddingTop: 50,
  },
  headerTitle: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#FFFFFF',
  },
  statsContainer: {
    flexDirection: 'row',
    justifyContent: 'space-around',
    padding: 20,
    margin: 16,
    borderRadius: 16,
  },
  statItem: {
    alignItems: 'center',
    gap: 8,
  },
  statValue: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#FFFFFF',
  },
  statLabel: {
    fontSize: 12,
    color: '#FFFFFF80',
  },
  actionButtons: {
    paddingHorizontal: 16,
    gap: 12,
  },
  createButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#0E766E',
    paddingVertical: 16,
    borderRadius: 12,
    gap: 8,
  },
  createButtonText: {
    color: '#FFFFFF',
    fontSize: 16,
    fontWeight: '600',
  },
  joinCodeButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#FFFFFF',
    paddingVertical: 16,
    borderRadius: 12,
    borderWidth: 2,
    borderColor: '#0E766E',
    gap: 8,
  },
  joinCodeButtonText: {
    color: '#0E766E',
    fontSize: 16,
    fontWeight: '600',
  },
  roomsSection: {
    flex: 1,
    paddingHorizontal: 16,
    paddingTop: 20,
  },
  sectionTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    marginBottom: 12,
    color: '#333',
  },
  roomsList: {
    gap: 12,
  },
  roomCard: {
    backgroundColor: '#FFFFFF',
    padding: 16,
    borderRadius: 12,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  roomHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 8,
  },
  roomTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#333',
  },
  roomBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    backgroundColor: '#F0F0F0',
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 12,
  },
  roomBadgeText: {
    fontSize: 12,
    color: '#666',
  },
  roomInfo: {
    marginBottom: 12,
  },
  roomHost: {
    fontSize: 14,
    color: '#666',
  },
  roomStatus: {
    fontSize: 12,
    color: '#999',
    marginTop: 4,
  },
  joinButton: {
    backgroundColor: '#27AE60',
    paddingVertical: 12,
    borderRadius: 8,
    alignItems: 'center',
  },
  joinButtonText: {
    color: '#FFFFFF',
    fontSize: 16,
    fontWeight: '600',
  },
  emptyState: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    paddingVertical: 40,
  },
  emptyText: {
    fontSize: 16,
    color: '#999',
    marginTop: 16,
  },
  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.5)',
    justifyContent: 'center',
    alignItems: 'center',
  },
  modalContent: {
    backgroundColor: '#FFFFFF',
    padding: 24,
    borderRadius: 16,
    width: '80%',
    maxWidth: 400,
  },
  modalTitle: {
    fontSize: 20,
    fontWeight: 'bold',
    marginBottom: 20,
    textAlign: 'center',
  },
  codeInput: {
    borderWidth: 1,
    borderColor: '#DDD',
    borderRadius: 8,
    padding: 12,
    fontSize: 18,
    textAlign: 'center',
    letterSpacing: 4,
    marginBottom: 20,
  },
  modalButtons: {
    flexDirection: 'row',
    gap: 12,
  },
  modalCancelButton: {
    flex: 1,
    paddingVertical: 12,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: '#DDD',
    alignItems: 'center',
  },
  modalCancelText: {
    color: '#666',
    fontSize: 16,
  },
  modalJoinButton: {
    flex: 1,
    paddingVertical: 12,
    borderRadius: 8,
    backgroundColor: '#0E766E',
    alignItems: 'center',
  },
  modalJoinText: {
    color: '#FFFFFF',
    fontSize: 16,
    fontWeight: '600',
  },
});
```

### Différences clés

| Flutter | React Native |
|---------|--------------|
| `StreamBuilder` | `useEffect` + `streamAvailableRooms(callback)` |
| `FutureBuilder` | `useEffect` + `async/await` + `useState` |
| `showDialog` | `Modal` component + state |
| `ListView.builder` | `FlatList` |
| `PopupMenuButton` | Custom dropdown ou `react-native-paper` Menu |

---

## 4. WaitingRoomScreen

### React Native

```tsx
// src/screens/WaitingRoomScreen.tsx
import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  FlatList,
  TouchableOpacity,
  StyleSheet,
  ActivityIndicator,
  Alert,
} from 'react-native';
import { StackNavigationProp } from '@react-navigation/stack';
import { RouteProp } from '@react-navigation/native';
import { RootStackParamList } from '../navigation/AppNavigator';
import Icon from 'react-native-vector-icons/MaterialIcons';
import LinearGradient from 'react-native-linear-gradient';
import roomService from '../services/firebase/room.service';
import authService from '../services/firebase/auth.service';
import { RoomPlayer } from '../types/multiplayer.types';

type WaitingRoomScreenNavigationProp = StackNavigationProp<RootStackParamList, 'WaitingRoom'>;
type WaitingRoomScreenRouteProp = RouteProp<RootStackParamList, 'WaitingRoom'>;

interface Props {
  navigation: WaitingRoomScreenNavigationProp;
  route: WaitingRoomScreenRouteProp;
}

export default function WaitingRoomScreen({ navigation, route }: Props) {
  const { roomId, roomCode, isHost } = route.params;
  const [players, setPlayers] = useState<RoomPlayer[]>([]);
  const [roomStatus, setRoomStatus] = useState<string>('waiting');
  const [isReady, setIsReady] = useState(false);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    subscribeToRoom();
    subscribeToPlayers();

    // Cleanup à la sortie
    return () => {
      handleLeaveRoom();
    };
  }, []);

  const subscribeToRoom = () => {
    const unsubscribe = roomService.streamRoom(roomId, (room) => {
      if (room.status === 'playing') {
        // Naviguer automatiquement vers le jeu
        navigation.replace('MultiplayerGame', { roomId });
      }
      setRoomStatus(room.status);
    });

    return () => unsubscribe();
  };

  const subscribeToPlayers = () => {
    const unsubscribe = roomService.streamRoomPlayers(roomId, (roomPlayers) => {
      setPlayers(roomPlayers);
      setIsLoading(false);
    });

    return () => unsubscribe();
  };

  const handleStartGame = async () => {
    if (players.length < 2) {
      Alert.alert('Erreur', 'Au moins 2 joueurs sont requis');
      return;
    }

    try {
      await roomService.startGame(roomId);
      // La navigation se fera automatiquement via le listener
    } catch (error: any) {
      Alert.alert('Erreur', error.message);
    }
  };

  const handleToggleReady = async () => {
    const currentUser = authService.getCurrentUser();
    if (!currentUser) return;

    try {
      const newReadyState = !isReady;
      await roomService.setReady(roomId, newReadyState);
      setIsReady(newReadyState);
    } catch (error: any) {
      Alert.alert('Erreur', error.message);
    }
  };

  const handleLeaveRoom = async () => {
    const currentUser = authService.getCurrentUser();
    if (!currentUser) return;

    try {
      await roomService.leaveRoom(roomId);
    } catch (error) {
      console.error('Error leaving room:', error);
    }
  };

  const handleShowCode = () => {
    Alert.alert(
      'Code de la salle',
      roomCode,
      [{ text: 'OK' }],
      { cancelable: true }
    );
  };

  const renderPlayer = ({ item, index }: { item: RoomPlayer; index: number }) => (
    <View style={styles.playerCard}>
      <View style={styles.playerAvatar}>
        <Text style={styles.playerNumber}>{index + 1}</Text>
      </View>

      <View style={styles.playerInfo}>
        <Text style={styles.playerName}>{item.playerName}</Text>
        {item.isOnline ? (
          <Text style={styles.playerOnline}>En ligne</Text>
        ) : (
          <Text style={styles.playerOffline}>Hors ligne</Text>
        )}
      </View>

      <Icon
        name={item.isReady ? 'check-circle' : 'pending'}
        size={24}
        color={item.isReady ? '#27AE60' : '#999'}
      />
    </View>
  );

  if (isLoading) {
    return (
      <View style={styles.loadingContainer}>
        <ActivityIndicator size="large" color="#0E766E" />
      </View>
    );
  }

  return (
    <View style={styles.container}>
      {/* Header */}
      <LinearGradient colors={['#0E766E', '#145A32']} style={styles.header}>
        <TouchableOpacity
          onPress={() => navigation.goBack()}
          style={styles.backButton}
        >
          <Icon name="arrow-back" size={24} color="#FFFFFF" />
        </TouchableOpacity>

        <View style={styles.headerCenter}>
          <Text style={styles.headerTitle}>Salle : {roomCode}</Text>
          <Text style={styles.headerSubtitle}>
            {players.length} joueur{players.length > 1 ? 's' : ''}
          </Text>
        </View>

        <TouchableOpacity onPress={handleShowCode}>
          <Icon name="info-outline" size={24} color="#FFFFFF" />
        </TouchableOpacity>
      </LinearGradient>

      {/* Liste des joueurs */}
      <FlatList
        data={players}
        renderItem={renderPlayer}
        keyExtractor={(item) => item.id}
        contentContainerStyle={styles.playersList}
      />

      {/* Bouton d'action */}
      <View style={styles.footer}>
        {isHost ? (
          <TouchableOpacity
            style={[styles.startButton, players.length < 2 && styles.startButtonDisabled]}
            onPress={handleStartGame}
            disabled={players.length < 2}
          >
            <LinearGradient
              colors={players.length >= 2 ? ['#27AE60', '#1E8449'] : ['#999', '#666']}
              style={styles.startGradient}
            >
              <Text style={styles.startButtonText}>Démarrer la partie</Text>
            </LinearGradient>
          </TouchableOpacity>
        ) : (
          <TouchableOpacity
            style={[styles.readyButton, isReady && styles.readyButtonActive]}
            onPress={handleToggleReady}
          >
            <Text style={[styles.readyButtonText, isReady && styles.readyButtonTextActive]}>
              {isReady ? 'Prêt ✓' : 'Pas prêt'}
            </Text>
          </TouchableOpacity>
        )}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#F5F5F5',
  },
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingVertical: 16,
    paddingTop: 50,
  },
  backButton: {
    marginRight: 12,
  },
  headerCenter: {
    flex: 1,
  },
  headerTitle: {
    fontSize: 20,
    fontWeight: 'bold',
    color: '#FFFFFF',
  },
  headerSubtitle: {
    fontSize: 14,
    color: '#FFFFFF80',
    marginTop: 2,
  },
  playersList: {
    padding: 16,
    gap: 12,
  },
  playerCard: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#FFFFFF',
    padding: 16,
    borderRadius: 12,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  playerAvatar: {
    width: 48,
    height: 48,
    borderRadius: 24,
    backgroundColor: '#0E766E',
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: 12,
  },
  playerNumber: {
    color: '#FFFFFF',
    fontSize: 20,
    fontWeight: 'bold',
  },
  playerInfo: {
    flex: 1,
  },
  playerName: {
    fontSize: 16,
    fontWeight: '600',
    color: '#333',
  },
  playerOnline: {
    fontSize: 12,
    color: '#27AE60',
    marginTop: 2,
  },
  playerOffline: {
    fontSize: 12,
    color: '#999',
    marginTop: 2,
  },
  footer: {
    padding: 16,
    paddingBottom: 32,
  },
  startButton: {
    height: 56,
    borderRadius: 12,
    overflow: 'hidden',
  },
  startButtonDisabled: {
    opacity: 0.5,
  },
  startGradient: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  startButtonText: {
    color: '#FFFFFF',
    fontSize: 18,
    fontWeight: 'bold',
  },
  readyButton: {
    height: 56,
    borderRadius: 12,
    backgroundColor: '#FFFFFF',
    borderWidth: 2,
    borderColor: '#0E766E',
    justifyContent: 'center',
    alignItems: 'center',
  },
  readyButtonActive: {
    backgroundColor: '#27AE60',
    borderColor: '#27AE60',
  },
  readyButtonText: {
    color: '#0E766E',
    fontSize: 18,
    fontWeight: 'bold',
  },
  readyButtonTextActive: {
    color: '#FFFFFF',
  },
});
```

---

## 5. GameScreen

**Note:** Cette page est LA PLUS COMPLEXE à migrer. Elle contient:
- Gestion du state avec BLoC → Redux
- Animations de cartes volantes
- Layout responsive (portrait/paysage)
- Overlays (Checks, Game Over, Pause Menu, etc.)
- GlobalKeys pour positions → useRef
- Mode solo ET multijoueur

### Structure recommandée

```tsx
// src/screens/GameScreen.tsx
import React, { useState, useRef, useEffect } from 'react';
import {
  View,
  Text,
  StyleSheet,
  Dimensions,
  TouchableOpacity,
} from 'react-native';
import { StackNavigationProp } from '@react-navigation/stack';
import { RootStackParamList } from '../navigation/AppNavigator';
import { useAppSelector, useAppDispatch } from '../store';
import { playCard, drawCard, endTurn } from '../store/slices/gameSlice';
import HandFan from '../components/HandFan';
import DiscardPile from '../components/DiscardPile';
import DeckWidget from '../components/DeckWidget';
import SuitPickerSheet from '../components/SuitPickerSheet';
import GameOverSheet from '../components/GameOverSheet';
import ChecksOverlay from '../components/ChecksOverlay';
import PauseMenu from '../components/PauseMenu';
import ErrorMessage from '../components/ErrorMessage';
import AnimatedCardOverlay from '../components/AnimatedCardOverlay';
import { PlayingCard, CardSuit, CardValue } from '../types/card.types';
import audioService from '../services/audio.service';

type GameScreenNavigationProp = StackNavigationProp<RootStackParamList, 'Game'>;

interface Props {
  navigation: GameScreenNavigationProp;
  route: { params: { playerNames: string[] } };
}

export default function GameScreen({ navigation, route }: Props) {
  const dispatch = useAppDispatch();
  const gameState = useAppSelector((state) => state.game);

  const [selectedCards, setSelectedCards] = useState<PlayingCard[]>([]);
  const [showSuitPicker, setShowSuitPicker] = useState(false);
  const [showPauseMenu, setShowPauseMenu] = useState(false);
  const [showChecksOverlay, setShowChecksOverlay] = useState(false);
  const [checksPlayerName, setChecksPlayerName] = useState('');

  // Refs pour les positions (équivalent de GlobalKeys)
  const discardPileRef = useRef<View>(null);
  const deckRef = useRef<View>(null);
  const cardRefs = useRef<Map<string, View>>(new Map());

  // Initialiser le jeu au montage
  useEffect(() => {
    dispatch(startGame({ playerNames: route.params.playerNames }));
    audioService.startBackgroundMusic();

    return () => {
      audioService.stopBackgroundMusic();
    };
  }, []);

  // Détecter les événements CHECKS
  useEffect(() => {
    if (gameState.lastChecksPlayerId) {
      const player = gameState.players.find((p) => p.id === gameState.lastChecksPlayerId);
      if (player) {
        setChecksPlayerName(player.name);
        setShowChecksOverlay(true);
        audioService.playChecks();
      }
    }
  }, [gameState.lastChecksPlayerId]);

  const handleCardPress = (card: PlayingCard) => {
    if (!isMyTurn) return;

    setSelectedCards((prev) => {
      const isSelected = prev.some((c) => c.suit === card.suit && c.value === card.value);
      if (isSelected) {
        return prev.filter((c) => !(c.suit === card.suit && c.value === card.value));
      }
      return [...prev, card];
    });
  };

  const handlePlayCard = async () => {
    if (selectedCards.length === 0) return;

    const firstCard = selectedCards[0];

    // Si c'est un Valet, demander la couleur
    if (firstCard.value === CardValue.Jack) {
      setShowSuitPicker(true);
      return;
    }

    // Jouer la carte
    await playCardWithAnimation(selectedCards, null);
  };

  const handleSuitSelected = async (suit: CardSuit) => {
    setShowSuitPicker(false);
    await playCardWithAnimation(selectedCards, suit);
  };

  const playCardWithAnimation = async (cards: PlayingCard[], imposedSuit: CardSuit | null) => {
    // TODO: Animer les cartes vers la défausse
    // Voir section Animations ci-dessous

    // Dispatch Redux
    dispatch(playCard({
      playerId: currentPlayer.id,
      cardIndex: 0, // Adapter selon votre logique
      chosenSuit: imposedSuit,
    }));

    setSelectedCards([]);
  };

  const handleDraw = () => {
    if (!isMyTurn) return;

    audioService.playCardMove();

    if (gameState.cardsToDraw > 0) {
      // Prendre le cumul
      dispatch(endTurn());
    } else {
      // Piocher 1 carte
      dispatch(drawCard());
    }
  };

  const currentPlayer = gameState.players[gameState.currentPlayerIndex];
  const isMyTurn = gameState.currentPlayerIndex === 0; // Pour le mode solo

  return (
    <View style={styles.container}>
      {/* Info bar */}
      <TopInfoBar
        currentPlayer={currentPlayer}
        drawPileCount={gameState.drawPile.length}
        discardPileCount={gameState.discardPile.length}
        cardsToDraw={gameState.cardsToDraw}
        imposedSuit={gameState.imposedSuit}
        phase={gameState.phase}
        onPause={() => setShowPauseMenu(true)}
      />

      {/* Adversaires */}
      <View style={styles.opponents}>
        {/* Afficher les autres joueurs */}
      </View>

      {/* Zone de jeu centrale */}
      <View style={styles.centralArea}>
        {/* Défausse */}
        <View ref={discardPileRef}>
          <DiscardPile topCard={gameState.discardPile[gameState.discardPile.length - 1]} />
        </View>

        {/* Pioche */}
        <View ref={deckRef}>
          <DeckWidget count={gameState.drawPile.length} onPress={handleDraw} enabled={isMyTurn} />
        </View>
      </View>

      {/* Main du joueur */}
      <HandFan
        cards={currentPlayer.hand}
        selectedCards={selectedCards}
        onCardPress={handleCardPress}
        enabled={isMyTurn}
      />

      {/* Boutons d'action */}
      <View style={styles.actionButtons}>
        <TouchableOpacity
          style={styles.drawButton}
          onPress={handleDraw}
          disabled={!isMyTurn}
        >
          <Text style={styles.buttonText}>
            {gameState.cardsToDraw > 0 ? 'Cumul' : 'Piocher'}
          </Text>
        </TouchableOpacity>

        <TouchableOpacity
          style={styles.playButton}
          onPress={handlePlayCard}
          disabled={!isMyTurn || selectedCards.length === 0}
        >
          <Text style={styles.buttonText}>Jouer</Text>
        </TouchableOpacity>
      </View>

      {/* Overlays */}
      <SuitPickerSheet
        visible={showSuitPicker}
        onSuitSelect={handleSuitSelected}
        onDismiss={() => setShowSuitPicker(false)}
      />

      <PauseMenu
        visible={showPauseMenu}
        onResume={() => setShowPauseMenu(false)}
        onQuit={() => navigation.goBack()}
      />

      <ChecksOverlay
        visible={showChecksOverlay}
        playerName={checksPlayerName}
        onComplete={() => setShowChecksOverlay(false)}
      />

      {gameState.isGameOver && (
        <GameOverSheet
          visible={gameState.isGameOver}
          finishingOrder={gameState.finishingOrder}
          players={gameState.players}
          onRestart={() => {
            dispatch(startGame({ playerNames: route.params.playerNames }));
          }}
        />
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#145A32',
  },
  opponents: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    padding: 16,
  },
  centralArea: {
    flex: 1,
    flexDirection: 'row',
    justifyContent: 'center',
    alignItems: 'center',
    gap: 30,
  },
  actionButtons: {
    flexDirection: 'row',
    padding: 16,
    gap: 12,
  },
  drawButton: {
    flex: 1,
    backgroundColor: '#E67E22',
    padding: 16,
    borderRadius: 12,
    alignItems: 'center',
  },
  playButton: {
    flex: 1,
    backgroundColor: '#27AE60',
    padding: 16,
    borderRadius: 12,
    alignItems: 'center',
  },
  buttonText: {
    color: '#FFFFFF',
    fontSize: 16,
    fontWeight: 'bold',
  },
});
```

**Note:** Le GameScreen est trop complexe pour être montré entièrement ici. Voir la section "Animations" ci-dessous pour les détails sur l'animation des cartes.

---

## 6. MultiplayerGameScreen

Wrapper pour initialiser le jeu multijoueur avec le bon Bloc/Slice.

```tsx
// src/screens/MultiplayerGameScreen.tsx
import React, { useEffect, useState } from 'react';
import { View, Text, ActivityIndicator, StyleSheet } from 'react-native';
import { StackNavigationProp } from '@react-navigation/stack';
import { RouteProp } from '@react-navigation/native';
import { RootStackParamList } from '../navigation/AppNavigator';
import { Provider } from 'react-redux';
import { createMultiplayerStore } from '../store/multiplayerStore';
import GameScreen from './GameScreen';
import gameMasterService from '../services/firebase/gameMaster.service';
import authService from '../services/firebase/auth.service';

type MultiplayerGameScreenNavigationProp = StackNavigationProp<
  RootStackParamList,
  'MultiplayerGame'
>;
type MultiplayerGameScreenRouteProp = RouteProp<RootStackParamList, 'MultiplayerGame'>;

interface Props {
  navigation: MultiplayerGameScreenNavigationProp;
  route: MultiplayerGameScreenRouteProp;
}

export default function MultiplayerGameScreen({ navigation, route }: Props) {
  const { roomId } = route.params;
  const [store, setStore] = useState<any>(null);
  const [isHost, setIsHost] = useState(false);
  const [isReady, setIsReady] = useState(false);

  useEffect(() => {
    initializeGame();
  }, []);

  const initializeGame = async () => {
    try {
      const currentUser = authService.getCurrentUser();
      if (!currentUser) {
        navigation.replace('Auth');
        return;
      }

      // Créer un store spécifique pour cette partie multijoueur
      const multiplayerStore = createMultiplayerStore(roomId, currentUser.uid);
      setStore(multiplayerStore);

      // Vérifier si on est l'hôte
      const roomData = await gameMasterService.getRoomData(roomId);
      const isCurrentUserHost = roomData.hostId === currentUser.uid;
      setIsHost(isCurrentUserHost);

      // Si on est l'hôte, initialiser le jeu
      if (isCurrentUserHost) {
        await gameMasterService.initializeGame(roomId);
      }

      setIsReady(true);
    } catch (error) {
      console.error('Error initializing multiplayer game:', error);
      Alert.alert('Erreur', 'Impossible d\'initialiser la partie');
      navigation.goBack();
    }
  };

  if (!isReady || !store) {
    return (
      <View style={styles.loadingContainer}>
        <ActivityIndicator size="large" color="#0E766E" />
        <Text style={styles.loadingText}>
          {isHost ? 'Initialisation de la partie...' : 'Synchronisation avec l\'hôte...'}
        </Text>
      </View>
    );
  }

  return (
    <Provider store={store}>
      <GameScreen navigation={navigation} route={{ params: { playerNames: [] } }} />
    </Provider>
  );
}

const styles = StyleSheet.create({
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#F5F5F5',
  },
  loadingText: {
    marginTop: 16,
    fontSize: 16,
    color: '#666',
  },
});
```

---

## Navigation et Routing

### Configuration React Navigation

```tsx
// src/navigation/AppNavigator.tsx
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
  WaitingRoom: { roomId: string; roomCode: string; isHost: boolean };
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
          headerStyle: { backgroundColor: '#0E766E' },
          headerTintColor: '#FFFFFF',
          headerTitleStyle: { fontWeight: 'bold' },
        }}
      >
        <Stack.Screen
          name="MainMenu"
          component={MainMenuScreen}
          options={{ headerShown: false }}
        />
        <Stack.Screen
          name="Auth"
          component={AuthScreen}
          options={{ title: 'Connexion' }}
        />
        <Stack.Screen
          name="MultiplayerLobby"
          component={MultiplayerLobbyScreen}
          options={{ headerShown: false }}
        />
        <Stack.Screen
          name="WaitingRoom"
          component={WaitingRoomScreen}
          options={{ headerShown: false }}
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

### Mapping Navigation

| Flutter | React Native |
|---------|--------------|
| `Navigator.push(context, route)` | `navigation.navigate('ScreenName', params)` |
| `Navigator.pushReplacement(context, route)` | `navigation.replace('ScreenName', params)` |
| `Navigator.pop(context)` | `navigation.goBack()` |
| `Navigator.popUntil(context, predicate)` | `navigation.popToTop()` |
| `Navigator.pushNamed(context, '/route')` | `navigation.navigate('RouteName')` |
| `arguments` de route | `route.params` |

---

## Hooks React Personnalisés

### useFirestoreCollection

```tsx
// src/hooks/useFirestoreCollection.ts
import { useState, useEffect } from 'react';
import firestore, { FirebaseFirestoreTypes } from '@react-native-firebase/firestore';

export function useFirestoreCollection<T>(
  collectionPath: string,
  queryConstraints?: (ref: FirebaseFirestoreTypes.CollectionReference) => FirebaseFirestoreTypes.Query
) {
  const [data, setData] = useState<T[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<Error | null>(null);

  useEffect(() => {
    let query: FirebaseFirestoreTypes.Query = firestore().collection(collectionPath);

    if (queryConstraints) {
      query = queryConstraints(firestore().collection(collectionPath));
    }

    const unsubscribe = query.onSnapshot(
      (snapshot) => {
        const documents = snapshot.docs.map((doc) => ({
          id: doc.id,
          ...doc.data(),
        })) as T[];

        setData(documents);
        setLoading(false);
      },
      (err) => {
        setError(err);
        setLoading(false);
      }
    );

    return () => unsubscribe();
  }, [collectionPath]);

  return { data, loading, error };
}
```

**Usage:**

```tsx
const { data: rooms, loading, error } = useFirestoreCollection<GameRoom>(
  'game_rooms',
  (ref) => ref.where('status', '==', 'waiting').orderBy('createdAt', 'desc')
);
```

### useFirestoreDocument

```tsx
// src/hooks/useFirestoreDocument.ts
import { useState, useEffect } from 'react';
import firestore from '@react-native-firebase/firestore';

export function useFirestoreDocument<T>(documentPath: string) {
  const [data, setData] = useState<T | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<Error | null>(null);

  useEffect(() => {
    const unsubscribe = firestore()
      .doc(documentPath)
      .onSnapshot(
        (doc) => {
          if (doc.exists) {
            setData({ id: doc.id, ...doc.data() } as T);
          } else {
            setData(null);
          }
          setLoading(false);
        },
        (err) => {
          setError(err);
          setLoading(false);
        }
      );

    return () => unsubscribe();
  }, [documentPath]);

  return { data, loading, error };
}
```

**Usage:**

```tsx
const { data: room, loading } = useFirestoreDocument<GameRoom>(`game_rooms/${roomId}`);
```

---

## Checklist de Migration

### MainMenuScreen
- [ ] Créer `MainMenuScreen.tsx`
- [ ] Installer `react-native-linear-gradient`
- [ ] Installer `react-native-vector-icons`
- [ ] Configurer navigation vers Auth et Game
- [ ] Intégrer audio service
- [ ] Tester layout responsive

### AuthScreen
- [ ] Créer `AuthScreen.tsx`
- [ ] Implémenter validation email/password
- [ ] Intégrer Firebase Auth service
- [ ] Gérer états loading/error
- [ ] Tester mode Login et Register
- [ ] Tester connexion anonyme
- [ ] Configurer `KeyboardAvoidingView`

### MultiplayerLobbyScreen
- [ ] Créer `MultiplayerLobbyScreen.tsx`
- [ ] Implémenter hook Firestore stream
- [ ] Afficher stats du joueur
- [ ] Créer Modal "Rejoindre avec code"
- [ ] Tester création de room
- [ ] Tester rejoindre room par code
- [ ] Tester liste des parties disponibles
- [ ] Gérer déconnexion

### WaitingRoomScreen
- [ ] Créer `WaitingRoomScreen.tsx`
- [ ] Stream players de Firestore
- [ ] Stream room status pour auto-navigation
- [ ] Implémenter bouton "Prêt" (non-hôte)
- [ ] Implémenter bouton "Démarrer" (hôte)
- [ ] Gérer cleanup (leave room) au unmount
- [ ] Tester transition vers MultiplayerGameScreen

### GameScreen
- [ ] Créer `GameScreen.tsx`
- [ ] Migrer layout responsive (portrait/paysage)
- [ ] Intégrer Redux gameSlice
- [ ] Créer composants enfants (HandFan, DiscardPile, etc.)
- [ ] Implémenter sélection de cartes
- [ ] Implémenter animations de cartes
- [ ] Créer Overlays (Checks, GameOver, Pause, Error)
- [ ] Gérer mode solo ET multijoueur
- [ ] Tester tous les effets spéciaux (7, Valet, Joker, etc.)
- [ ] Tester animations bot → défausse
- [ ] Tester animations pioche → joueur
- [ ] Optimiser performances (React.memo, useMemo)

### MultiplayerGameScreen
- [ ] Créer `MultiplayerGameScreen.tsx`
- [ ] Créer store Redux séparé pour multiplayer
- [ ] Intégrer GameMasterService
- [ ] Implémenter initialisation hôte
- [ ] Implémenter synchronisation invités
- [ ] Afficher écran de chargement
- [ ] Tester navigation depuis WaitingRoom

### Navigation
- [ ] Configurer `AppNavigator.tsx`
- [ ] Définir types `RootStackParamList`
- [ ] Tester toutes les transitions
- [ ] Tester deep linking (optionnel)

### Hooks personnalisés
- [ ] Créer `useFirestoreCollection`
- [ ] Créer `useFirestoreDocument`
- [ ] Créer `useFormValidation`
- [ ] Créer `useResponsive` (optionnel)

---

## Conseils de Migration

### 1. Commencez par les écrans simples

Migrez dans cet ordre:
1. **MainMenuScreen** (le plus simple)
2. **AuthScreen** (validation de formulaire)
3. **MultiplayerLobbyScreen** (Firestore streams)
4. **WaitingRoomScreen** (streams + navigation conditionnelle)
5. **MultiplayerGameScreen** (wrapper Redux)
6. **GameScreen** (LE PLUS COMPLEXE - gardez pour la fin)

### 2. Testez chaque écran indépendamment

Créez des stories ou des tests de navigation pour chaque écran avant de passer au suivant.

### 3. Utilisez les DevTools

- **React Native Debugger** pour inspecter Redux
- **Flipper** pour voir les logs Firestore
- **React DevTools** pour debug les composants

### 4. Gérez les erreurs réseau

Firestore peut échouer, assurez-vous de gérer tous les cas:
- Connexion perdue
- Permission denied
- Document inexistant

### 5. Performance

- Utilisez `React.memo` pour les composants qui re-render souvent
- Utilisez `useMemo` pour les calculs coûteux
- Évitez les `console.log` en production
- Optimisez les images avec `react-native-fast-image`

### 6. Animations

Pour les animations de cartes volantes:
- Utilisez `react-native-reanimated` v3
- Mesurez les positions avec `useRef` + `measure()`
- Créez des Overlays pour les cartes animées

### 7. GlobalKeys → useRef

Flutter utilise `GlobalKey` pour obtenir les positions. En React Native:

```tsx
const cardRef = useRef<View>(null);

// Obtenir position
cardRef.current?.measure((x, y, width, height, pageX, pageY) => {
  console.log('Position:', pageX, pageY);
});
```

---

## Ressources

- [React Navigation Docs](https://reactnavigation.org/)
- [React Native Firebase Docs](https://rnfirebase.io/)
- [Redux Toolkit Docs](https://redux-toolkit.js.org/)
- [React Native Reanimated](https://docs.swmansion.com/react-native-reanimated/)

Bon courage pour la migration ! 🚀
