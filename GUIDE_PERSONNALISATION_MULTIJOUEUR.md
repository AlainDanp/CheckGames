# Guide de Personnalisation - Interface Multijoueur

Ce guide vous permettra de personnaliser et améliorer les pages d'authentification, de lobby et de salon d'attente de votre jeu CheckGames.

---

## 📋 Table des matières

1. [Page d'Authentification](#1-page-dauthentification)
2. [Page de Lobby Multijoueur](#2-page-de-lobby-multijoueur)
3. [Page de Salon d'Attente](#3-page-de-salon-dattente)
4. [Thèmes et Cohérence Visuelle](#4-thèmes-et-cohérence-visuelle)
5. [Animations et Transitions](#5-animations-et-transitions)
6. [Améliorations Avancées](#6-améliorations-avancées)

---

## 1. Page d'Authentification

### État Actuel
Fichier : `lib/ui/auth_screen.dart`

**Points forts :**
- ✅ Authentification email/password
- ✅ Connexion anonyme
- ✅ Basculement connexion/inscription

**Points à améliorer :**
- ❌ Design basique et peu attrayant
- ❌ Pas de validation des champs
- ❌ Pas d'animations
- ❌ Pas de logo ou branding

### Améliorations Recommandées

#### A. Ajouter un Logo et un Header Visuel

```dart
// En haut de la Column dans build()
Column(
  children: [
    SizedBox(height: 60),
    // Logo ou icône du jeu
    Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFF0E766E), Color(0xFF145A32)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Icon(
        Icons.playing_cards,
        size: 60,
        color: Colors.white,
      ),
    ),

    SizedBox(height: 20),

    // Titre du jeu
    Text(
      'CheckGames',
      style: TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.bold,
        color: Color(0xFF0E766E),
        letterSpacing: 2,
      ),
    ),

    SizedBox(height: 10),

    Text(
      _isLogin ? 'Bienvenue !' : 'Créer un compte',
      style: TextStyle(
        fontSize: 18,
        color: Colors.grey[600],
      ),
    ),

    SizedBox(height: 40),

    // ... reste des champs
  ],
)
```

#### B. Améliorer les Champs de Texte avec Validation

```dart
class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _emailError;
  String? _passwordError;

  // Méthode de validation email
  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email requis';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Email invalide';
    }
    return null;
  }

  // Méthode de validation mot de passe
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Mot de passe requis';
    }
    if (value.length < 6) {
      return 'Au moins 6 caractères';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24),
          child: Column(
            children: [
              // ... Logo et header

              // Champ Email amélioré
              TextFormField(
                controller: _emailController,
                validator: _validateEmail,
                decoration: InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                keyboardType: TextInputType.emailAddress,
              ),

              SizedBox(height: 16),

              // Champ Mot de passe amélioré
              TextFormField(
                controller: _passwordController,
                validator: _validatePassword,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Mot de passe',
                  prefixIcon: Icon(Icons.lock_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
              ),

              // ... reste
            ],
          ),
        ),
      ),
    );
  }
}
```

#### C. Boutons Stylisés avec État de Chargement

```dart
// Remplacer le ElevatedButton par :
SizedBox(
  width: double.infinity,
  height: 56,
  child: ElevatedButton(
    onPressed: _isLoading ? null : () async {
      if (_formKey.currentState!.validate()) {
        setState(() => _isLoading = true);

        try {
          if (_isLogin) {
            await _authService.signIn(
              email: _emailController.text.trim(),
              password: _passwordController.text,
            );
          } else {
            await _authService.signUp(
              email: _emailController.text.trim(),
              password: _passwordController.text,
              username: _usernameController.text.trim(),
            );
          }

          if (mounted) {
            Navigator.pushReplacementNamed(context, '/lobby');
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.white),
                    SizedBox(width: 12),
                    Expanded(child: Text(e.toString())),
                  ],
                ),
                backgroundColor: Colors.red.shade700,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          }
        } finally {
          if (mounted) setState(() => _isLoading = false);
        }
      }
    },
    style: ElevatedButton.styleFrom(
      backgroundColor: Color(0xFF0E766E),
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
    ),
    child: _isLoading
        ? SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          )
        : Text(
            _isLogin ? 'Se connecter' : 'S\'inscrire',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
  ),
),
```

#### D. Connexion Anonyme Améliorée

```dart
OutlinedButton.icon(
  onPressed: _isLoading ? null : () async {
    setState(() => _isLoading = true);
    try {
      await _authService.signInAnonymously();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/lobby');
      }
    } catch (e) {
      // Gestion erreur
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  },
  icon: Icon(Icons.person_outline, size: 22),
  label: Text(
    'Continuer en tant qu\'invité',
    style: TextStyle(fontSize: 15),
  ),
  style: OutlinedButton.styleFrom(
    foregroundColor: Color(0xFF0E766E),
    side: BorderSide(color: Color(0xFF0E766E), width: 2),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    padding: EdgeInsets.symmetric(vertical: 16),
    minimumSize: Size(double.infinity, 56),
  ),
),
```

---

## 2. Page de Lobby Multijoueur

### État Actuel
Fichier : `lib/ui/multiplayer_lobby_screen.dart`

**Points forts :**
- ✅ Création de parties
- ✅ Rejoindre avec code
- ✅ Liste des parties disponibles en temps réel

**Points à améliorer :**
- ❌ Design centré basique
- ❌ Pas de statistiques joueur
- ❌ Liste de parties peu attrayante
- ❌ Pas de filtres ou recherche

### Améliorations Recommandées

#### A. Header avec Profil Joueur

```dart
@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: Text('Multijoueur'),
      backgroundColor: Color(0xFF0E766E),
      elevation: 0,
      actions: [
        // Badge de notification (optionnel)
        IconButton(
          icon: Badge(
            child: Icon(Icons.notifications_outlined),
          ),
          onPressed: () {
            // Afficher notifications
          },
        ),

        // Profil
        Padding(
          padding: EdgeInsets.only(right: 8),
          child: FutureBuilder(
            future: _authService.getUserProfile(
              _authService.currentUser!.uid,
            ),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return SizedBox(width: 40);
              }

              final profile = snapshot.data as Map<String, dynamic>;

              return PopupMenuButton(
                child: CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Text(
                    profile['username']?[0]?.toUpperCase() ?? 'J',
                    style: TextStyle(
                      color: Color(0xFF0E766E),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    child: ListTile(
                      leading: Icon(Icons.person),
                      title: Text(profile['username'] ?? 'Joueur'),
                      subtitle: Text('Voir profil'),
                    ),
                    onTap: () {
                      // Navigation vers profil
                    },
                  ),
                  PopupMenuItem(
                    child: ListTile(
                      leading: Icon(Icons.bar_chart),
                      title: Text('Statistiques'),
                    ),
                    onTap: () {
                      // Afficher stats
                    },
                  ),
                  PopupMenuDivider(),
                  PopupMenuItem(
                    child: ListTile(
                      leading: Icon(Icons.logout, color: Colors.red),
                      title: Text(
                        'Déconnexion',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                    onTap: () async {
                      await _authService.signOut();
                      Navigator.pushReplacementNamed(context, '/auth');
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ],
    ),

    // ... reste du body
  );
}
```

#### B. Statistiques Rapides

```dart
// Ajouter en haut du body, avant les boutons
Container(
  margin: EdgeInsets.all(16),
  padding: EdgeInsets.all(20),
  decoration: BoxDecoration(
    gradient: LinearGradient(
      colors: [Color(0xFF0E766E), Color(0xFF145A32)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
        color: Colors.black12,
        blurRadius: 10,
        offset: Offset(0, 5),
      ),
    ],
  ),
  child: FutureBuilder(
    future: _getPlayerStats(),
    builder: (context, snapshot) {
      if (!snapshot.hasData) {
        return SizedBox(height: 80);
      }

      final stats = snapshot.data as Map<String, dynamic>;

      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            icon: Icons.emoji_events,
            label: 'Victoires',
            value: '${stats['wins'] ?? 0}',
          ),
          _buildStatItem(
            icon: Icons.gamepad,
            label: 'Parties',
            value: '${stats['gamesPlayed'] ?? 0}',
          ),
          _buildStatItem(
            icon: Icons.trending_up,
            label: 'Ratio',
            value: '${stats['winRate'] ?? 0}%',
          ),
        ],
      );
    },
  ),
),

// Widget helper
Widget _buildStatItem({
  required IconData icon,
  required String label,
  required String value,
}) {
  return Column(
    children: [
      Icon(icon, color: Colors.white, size: 28),
      SizedBox(height: 8),
      Text(
        value,
        style: TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
      Text(
        label,
        style: TextStyle(
          color: Colors.white70,
          fontSize: 12,
        ),
      ),
    ],
  );
}
```

#### C. Boutons d'Action Améliorés

```dart
Padding(
  padding: EdgeInsets.symmetric(horizontal: 16),
  child: Column(
    children: [
      // Bouton Créer une partie
      SizedBox(
        width: double.infinity,
        height: 60,
        child: ElevatedButton.icon(
          onPressed: () async {
            final user = _authService.currentUser!;
            final profile = await _authService.getUserProfile(user.uid);

            final roomRef = await _roomService.createRoom(
              hostId: user.uid,
              playerName: profile!['username'],
            );

            final roomDoc = await roomRef.get();
            final roomData = roomDoc.data() as Map<String, dynamic>?;
            final roomCode = roomData?['roomCode'] as String? ?? '';

            Navigator.pushNamed(
              context,
              '/waiting-room',
              arguments: {
                'roomId': roomRef.id,
                'roomCode': roomCode,
                'isHost': true,
              },
            );
          },
          icon: Icon(Icons.add_circle_outline, size: 28),
          label: Text(
            'Créer une partie',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF0E766E),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 4,
          ),
        ),
      ),

      SizedBox(height: 12),

      // Bouton Rejoindre avec code
      SizedBox(
        width: double.infinity,
        height: 60,
        child: OutlinedButton.icon(
          onPressed: () => _showJoinDialog(context),
          icon: Icon(Icons.vpn_key_outlined, size: 26),
          label: Text(
            'Rejoindre avec un code',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: Color(0xFF0E766E),
            side: BorderSide(color: Color(0xFF0E766E), width: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    ],
  ),
),
```

#### D. Liste de Parties Stylisée

```dart
// Remplacer le StreamBuilder des parties par :
Expanded(
  child: Column(
    children: [
      // Header de section
      Padding(
        padding: EdgeInsets.fromLTRB(16, 24, 16, 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Parties disponibles',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            IconButton(
              icon: Icon(Icons.refresh),
              onPressed: () {
                // Rafraîchir la liste
                setState(() {});
              },
            ),
          ],
        ),
      ),

      // Liste
      Expanded(
        child: StreamBuilder(
          stream: _roomService.getAvailableRooms(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      color: Color(0xFF0E766E),
                    ),
                    SizedBox(height: 16),
                    Text('Recherche de parties...'),
                  ],
                ),
              );
            }

            final rooms = snapshot.data!.docs;

            if (rooms.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.search_off,
                      size: 80,
                      color: Colors.grey[300],
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Aucune partie disponible',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey[600],
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Soyez le premier à créer une partie !',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: 16),
              itemCount: rooms.length,
              itemBuilder: (context, index) {
                final room = rooms[index];
                final data = room.data() as Map<String, dynamic>;
                final currentPlayers = data['currentPlayers'] as int;
                final maxPlayers = data['maxPlayers'] as int;
                final isFull = currentPlayers >= maxPlayers;

                return Container(
                  margin: EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.grey[200]!,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black05,
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),

                    // Icône de la partie
                    leading: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(0xFF0E766E),
                            Color(0xFF145A32),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.group,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),

                    // Informations
                    title: Text(
                      'Partie ${data['roomCode']}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          Icon(
                            Icons.people,
                            size: 16,
                            color: Colors.grey[600],
                          ),
                          SizedBox(width: 4),
                          Text(
                            '$currentPlayers/$maxPlayers joueurs',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(width: 12),
                          if (isFull)
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red[50],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'COMPLET',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Bouton rejoindre
                    trailing: ElevatedButton(
                      onPressed: isFull ? null : () async {
                        try {
                          final user = _authService.currentUser!;
                          final profile = await _authService
                              .getUserProfile(user.uid);

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
                              'roomCode': data['roomCode'],
                              'isHost': false,
                            },
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(e.toString()),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isFull
                            ? Colors.grey
                            : Color(0xFF0E766E),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      child: Text(
                        isFull ? 'Complet' : 'Rejoindre',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
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
```

---

## 3. Page de Salon d'Attente

### État Actuel
Fichier : `lib/ui/waiting_room_screen.dart`

**Points forts :**
- ✅ Liste des joueurs en temps réel
- ✅ Système de "prêt"
- ✅ Démarrage de partie (hôte)

**Points à améliorer :**
- ❌ Interface basique
- ❌ Pas de chat
- ❌ Code de partie peu visible
- ❌ Pas d'avatars ou personnalisation

### Améliorations Recommandées

#### A. Header avec Code de Partie Mis en Avant

```dart
@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: Text('Salon d\'attente'),
      backgroundColor: Color(0xFF0E766E),
      elevation: 0,
    ),
    body: Column(
      children: [
        // Bannière avec code de partie
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0E766E), Color(0xFF145A32)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            children: [
              Text(
                'CODE DE LA PARTIE',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 8),

              // Code en grand
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Text(
                  widget.roomCode,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 8,
                  ),
                ),
              ),

              SizedBox(height: 12),

              // Bouton copier
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(
                    ClipboardData(text: widget.roomCode),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Code copié !'),
                      duration: Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                icon: Icon(Icons.copy, color: Colors.white70, size: 18),
                label: Text(
                  'Copier le code',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
        ),

        // ... reste du contenu
      ],
    ),
  );
}
```

#### B. Liste de Joueurs Améliorée avec Avatars

```dart
// Remplacer le ListView.builder des joueurs par :
Expanded(
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 12),
        child: Row(
          children: [
            Icon(Icons.people, color: Colors.grey[700]),
            SizedBox(width: 8),
            Text(
              'Joueurs (${players.length}/${data['maxPlayers']})',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
          ],
        ),
      ),

      Expanded(
        child: ListView.builder(
          padding: EdgeInsets.symmetric(horizontal: 16),
          itemCount: players.length,
          itemBuilder: (context, index) {
            final player = players[index].data()
                as Map<String, dynamic>;
            final playerId = players[index].id;
            final isCurrentUser = playerId == currentUserId;
            final isHost = playerId == roomData['hostId'];
            final isReady = player['isReady'] == true;
            final isOnline = player['isOnline'] == true;

            return Container(
              margin: EdgeInsets.only(bottom: 12),
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isCurrentUser
                    ? Color(0xFF0E766E).withOpacity(0.1)
                    : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isCurrentUser
                      ? Color(0xFF0E766E)
                      : Colors.grey[200]!,
                  width: 2,
                ),
                boxShadow: [
                  if (!isCurrentUser)
                    BoxShadow(
                      color: Colors.black05,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                ],
              ),
              child: Row(
                children: [
                  // Avatar avec badge
                  Stack(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              Color(0xFF0E766E),
                              Color(0xFF145A32),
                            ],
                          ),
                        ),
                        child: Center(
                          child: Text(
                            player['playerName']?[0]
                                ?.toUpperCase() ?? '?',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                      // Badge position
                      if (index < 3)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Color(0xFF0E766E),
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0E766E),
                                ),
                              ),
                            ),
                          ),
                        ),

                      // Indicateur online/offline
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: isOnline ? Colors.green : Colors.grey,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(width: 16),

                  // Informations joueur
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              player['playerName'] ?? 'Joueur ${index + 1}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            if (isHost) ...[
                              SizedBox(width: 8),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.amber,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.star,
                                      size: 12,
                                      color: Colors.white,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'HÔTE',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            if (isCurrentUser) ...[
                              SizedBox(width: 8),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Color(0xFF0E766E),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'VOUS',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        SizedBox(height: 4),
                        Text(
                          isOnline ? 'En ligne' : 'Hors ligne',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Statut prêt
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isReady
                          ? Colors.green.withOpacity(0.1)
                          : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isReady ? Colors.green : Colors.grey,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isReady ? Icons.check_circle : Icons.pending,
                          color: isReady ? Colors.green : Colors.grey,
                          size: 18,
                        ),
                        SizedBox(width: 6),
                        Text(
                          isReady ? 'Prêt' : 'En attente',
                          style: TextStyle(
                            color: isReady ? Colors.green : Colors.grey,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    ],
  ),
),
```

#### C. Boutons d'Action Améliorés avec Conditions

```dart
// Remplacer la section des boutons par :
Container(
  padding: EdgeInsets.all(20),
  decoration: BoxDecoration(
    color: Colors.white,
    boxShadow: [
      BoxShadow(
        color: Colors.black12,
        blurRadius: 10,
        offset: Offset(0, -5),
      ),
    ],
  ),
  child: SafeArea(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.isHost) ...[
          // Message pour l'hôte
          Container(
            padding: EdgeInsets.all(12),
            margin: EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.blue.shade200,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.blue.shade700,
                  size: 20,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    players.length >= 2
                        ? 'Tous les joueurs sont-ils prêts ? Lancez la partie !'
                        : 'En attente d\'au moins 2 joueurs...',
                    style: TextStyle(
                      color: Colors.blue.shade900,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bouton démarrer (hôte)
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: players.length >= 2
                  ? () async {
                      try {
                        await roomService.startGame(widget.roomId);
                        if (!context.mounted) return;
                        Navigator.pushReplacementNamed(
                          context,
                          '/multiplayer-game',
                          arguments: {'roomId': widget.roomId},
                        );
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(e.toString()),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  : null,
              icon: Icon(Icons.play_arrow, size: 28),
              label: Text(
                'Démarrer la partie',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF0E766E),
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey[300],
                disabledForegroundColor: Colors.grey[500],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: players.length >= 2 ? 4 : 0,
              ),
            ),
          ),
        ] else ...[
          // Bouton prêt/pas prêt (invités)
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: () async {
                setState(() {
                  _isReady = !_isReady;
                });
                try {
                  await roomService.setPlayerReady(
                    widget.roomId,
                    currentUserId,
                    _isReady,
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString())),
                  );
                }
              },
              icon: Icon(
                _isReady ? Icons.check_circle : Icons.circle_outlined,
                size: 28,
              ),
              label: Text(
                _isReady ? 'Prêt ✓' : 'Marquer comme prêt',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isReady
                    ? Colors.green
                    : Color(0xFF0E766E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
              ),
            ),
          ),

          SizedBox(height: 12),

          // Message pour les invités
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.amber.shade200,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.hourglass_empty,
                  color: Colors.amber.shade700,
                  size: 20,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'En attente que l\'hôte démarre la partie...',
                    style: TextStyle(
                      color: Colors.amber.shade900,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    ),
  ),
),
```

---

## 4. Thèmes et Cohérence Visuelle

### Définir un Thème Global

Créer un fichier `lib/theme/app_theme.dart` :

```dart
import 'package:flutter/material.dart';

class AppTheme {
  // Couleurs principales
  static const Color primaryGreen = Color(0xFF0E766E);
  static const Color secondaryGreen = Color(0xFF145A32);
  static const Color accentOrange = Color(0xFFFF6B35);

  // Dégradés
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryGreen, secondaryGreen],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Thème clair
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryGreen,
      brightness: Brightness.light,
    ),

    // AppBar
    appBarTheme: AppBarTheme(
      backgroundColor: primaryGreen,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    ),

    // Boutons
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        elevation: 2,
        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryGreen,
        side: BorderSide(color: primaryGreen, width: 2),
        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),

    // Champs de texte
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.grey[50],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: primaryGreen, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.red, width: 2),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),

    // Cartes
    cardTheme: CardTheme(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      margin: EdgeInsets.all(8),
    ),

    // SnackBar
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  );
}
```

Puis dans `main.dart` :

```dart
import 'theme/app_theme.dart';

MaterialApp(
  theme: AppTheme.lightTheme,
  // ... reste
)
```

---

## 5. Animations et Transitions

### A. Transition de Page Personnalisée

Créer `lib/utils/page_transitions.dart` :

```dart
import 'package:flutter/material.dart';

class SlideRightRoute extends PageRouteBuilder {
  final Widget page;

  SlideRightRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;
            const curve = Curves.easeInOut;

            var tween = Tween(begin: begin, end: end)
                .chain(CurveTween(curve: curve));

            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
          transitionDuration: Duration(milliseconds: 300),
        );
}

class FadeRoute extends PageRouteBuilder {
  final Widget page;

  FadeRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          transitionDuration: Duration(milliseconds: 300),
        );
}

// Utilisation:
Navigator.of(context).push(
  SlideRightRoute(page: WaitingRoomScreen(...)),
);
```

### B. Animation d'Entrée pour les Cartes

```dart
// Dans waiting_room_screen.dart
import 'package:flutter_staggered_animations.dart';

// Envelopper le ListView.builder :
AnimationLimiter(
  child: ListView.builder(
    itemCount: players.length,
    itemBuilder: (context, index) {
      return AnimationConfiguration.staggeredList(
        position: index,
        duration: const Duration(milliseconds: 375),
        child: SlideAnimation(
          verticalOffset: 50.0,
          child: FadeInAnimation(
            child: _buildPlayerCard(players[index]),
          ),
        ),
      );
    },
  ),
),
```

### C. Shimmer Effect pour le Chargement

```dart
// Ajouter dans pubspec.yaml:
// shimmer: ^3.0.0

import 'package:shimmer/shimmer.dart';

// Placeholder pendant le chargement:
if (!snapshot.hasData)
  ListView.builder(
    itemCount: 3,
    itemBuilder: (context, index) {
      return Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Container(
          margin: EdgeInsets.all(16),
          height: 80,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
    },
  ),
```

---

## 6. Améliorations Avancées

### A. Système de Chat dans le Salon

Ajouter un chat simple dans `waiting_room_screen.dart` :

```dart
// État
List<Map<String, dynamic>> _messages = [];
final _messageController = TextEditingController();

// Widget Chat
Container(
  height: 200,
  margin: EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: Colors.grey[50],
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: Colors.grey[300]!),
  ),
  child: Column(
    children: [
      // Header
      Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Color(0xFF0E766E),
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(16),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.chat, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text(
              'Chat',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),

      // Messages
      Expanded(
        child: StreamBuilder<QuerySnapshot>(
          stream: roomService.watchMessages(widget.roomId),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return Center(child: Text('Aucun message'));
            }

            final messages = snapshot.data!.docs;

            return ListView.builder(
              reverse: true,
              padding: EdgeInsets.all(8),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final msg = messages[index].data()
                    as Map<String, dynamic>;
                final isMe = msg['playerId'] == currentUserId;

                return Align(
                  alignment: isMe
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: EdgeInsets.symmetric(vertical: 4),
                    padding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isMe
                          ? Color(0xFF0E766E)
                          : Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      msg['message'],
                      style: TextStyle(
                        color: isMe ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),

      // Input
      Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: Colors.grey[300]!),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: 'Votre message...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
              ),
            ),
            SizedBox(width: 8),
            IconButton(
              onPressed: () async {
                if (_messageController.text.trim().isNotEmpty) {
                  await roomService.sendMessage(
                    widget.roomId,
                    currentUserId,
                    _messageController.text.trim(),
                  );
                  _messageController.clear();
                }
              },
              icon: Icon(Icons.send),
              color: Color(0xFF0E766E),
            ),
          ],
        ),
      ),
    ],
  ),
),
```

### B. Système d'Avatars Personnalisés

```dart
// Ajouter dans le profil utilisateur
class AvatarPicker extends StatelessWidget {
  final List<IconData> avatarIcons = [
    Icons.face,
    Icons.emoji_emotions,
    Icons.sports_esports,
    Icons.star,
    Icons.favorite,
    Icons.pets,
    Icons.music_note,
    Icons.sports_soccer,
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      itemCount: avatarIcons.length,
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: () {
            // Sauvegarder l'avatar sélectionné
          },
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0E766E), Color(0xFF145A32)],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              avatarIcons[index],
              color: Colors.white,
              size: 32,
            ),
          ),
        );
      },
    );
  }
}
```

### C. Sons et Vibrations

```dart
// Ajouter dans pubspec.yaml:
// audioplayers: ^5.0.0
// vibration: ^1.8.0

import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';

class SoundService {
  static final AudioPlayer _player = AudioPlayer();

  static Future<void> playJoinSound() async {
    await _player.play(AssetSource('sounds/join.mp3'));
  }

  static Future<void> playReadySound() async {
    await _player.play(AssetSource('sounds/ready.mp3'));
  }

  static Future<void> vibrate() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 50);
    }
  }
}

// Utiliser dans waiting_room_screen:
// Quand un joueur rejoint
void _onPlayerJoined() {
  SoundService.playJoinSound();
  SoundService.vibrate();
}

// Quand un joueur est prêt
void _onPlayerReady() {
  SoundService.playReadySound();
}
```

---

## 📝 Checklist d'Implémentation

### Page d'Authentification
- [ ] Ajouter logo et branding
- [ ] Améliorer les champs de texte
- [ ] Ajouter validation
- [ ] Ajouter état de chargement
- [ ] Améliorer les messages d'erreur
- [ ] Ajouter animations de transition

### Page de Lobby
- [ ] Ajouter header avec profil
- [ ] Afficher statistiques joueur
- [ ] Styliser les boutons d'action
- [ ] Améliorer la liste des parties
- [ ] Ajouter filtres/recherche (optionnel)
- [ ] Ajouter animations d'entrée

### Page de Salon d'Attente
- [ ] Mettre en avant le code de partie
- [ ] Améliorer la liste des joueurs avec avatars
- [ ] Ajouter badges (hôte, prêt, etc.)
- [ ] Améliorer les boutons d'action
- [ ] Ajouter système de chat
- [ ] Ajouter sons et vibrations

### Général
- [ ] Définir thème global
- [ ] Créer transitions de pages personnalisées
- [ ] Ajouter animations de chargement
- [ ] Implémenter système d'avatars
- [ ] Tester sur différentes tailles d'écran
- [ ] Optimiser les performances

---

## 🎨 Ressources Utiles

**Packages Flutter recommandés :**
- `flutter_staggered_animations` - Animations d'entrée
- `shimmer` - Effets de chargement
- `cached_network_image` - Images optimisées
- `flutter_svg` - Support SVG pour les icônes
- `lottie` - Animations Lottie
- `audioplayers` - Sons
- `vibration` - Vibrations

**Sites de ressources :**
- [Material Design Icons](https://fonts.google.com/icons)
- [Coolors.co](https://coolors.co/) - Palettes de couleurs
- [LottieFiles](https://lottiefiles.com/) - Animations
- [Undraw](https://undraw.co/) - Illustrations SVG

---

## 🚀 Conseils de Performance

1. **Utiliser `const` partout où possible**
2. **Éviter les `setState()` inutiles**
3. **Mettre en cache les images et données**
4. **Utiliser `ListView.builder` au lieu de `ListView` pour de longues listes**
5. **Limiter les animations simultanées**
6. **Tester sur des appareils bas de gamme**

---

## 📖 Conclusion

Ce guide vous donne toutes les bases pour personnaliser et améliorer vos pages multijoueur. N'hésitez pas à :

✅ Adapter les couleurs à votre identité visuelle
✅ Ajouter vos propres fonctionnalités
✅ Tester auprès de vrais utilisateurs
✅ Itérer en fonction des retours

**Bon développement ! 🎮✨**
