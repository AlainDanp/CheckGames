import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:shimmer/shimmer.dart';
import '../services/firebase_room_service.dart';
import '../services/firebase_auth_service.dart';
import '../services/sound_service.dart';
import '../theme/app_theme.dart';

class MultiplayerLobbyScreen extends StatefulWidget {
  const MultiplayerLobbyScreen({super.key});

  @override
  State<MultiplayerLobbyScreen> createState() => _MultiplayerLobbyScreenState();
}

class _MultiplayerLobbyScreenState extends State<MultiplayerLobbyScreen>
    with SingleTickerProviderStateMixin {
  final _roomService = FirebaseRoomService();
  final _authService = FirebaseAuthService();
  final _soundService = SoundService();

  late AnimationController _animationController;
  bool _isCreatingRoom = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _animationController.forward();

    // Nettoyer les salles vides au chargement
    _roomService.cleanupEmptyRooms();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _getPlayerStats() async {
    try {
      final user = _authService.currentUser;
      if (user == null) {
        return {'wins': 0, 'gamesPlayed': 0, 'winRate': 0};
      }

      final profile = await _authService.getUserProfile(user.uid);
      if (profile == null) {
        return {'wins': 0, 'gamesPlayed': 0, 'winRate': 0};
      }

      final wins = profile['wins'] as int? ?? 0;
      final losses = profile['losses'] as int? ?? 0;
      final gamesPlayed = wins + losses;
      final winRate = gamesPlayed > 0 ? ((wins / gamesPlayed) * 100).round() : 0;

      return {
        'wins': wins,
        'gamesPlayed': gamesPlayed,
        'winRate': winRate,
      };
    } catch (e) {
      return {'wins': 0, 'gamesPlayed': 0, 'winRate': 0};
    }
  }

  Future<void> _createRoom() async {
    if (_isCreatingRoom) return;
    setState(() => _isCreatingRoom = true);

    try {
      _soundService.playButtonClick();
      final user = _authService.currentUser!;
      final profile = await _authService.getUserProfile(user.uid);

      final roomRef = await _roomService.createRoom(
        hostId: user.uid,
        playerName: profile!['username'],
      );

      final roomDoc = await roomRef.get();
      final roomData = roomDoc.data() as Map<String, dynamic>?;
      final roomCode = roomData?['roomCode'] as String? ?? '';

      if (mounted) {
        Navigator.pushNamed(
          context,
          '/waiting-room',
          arguments: {
            'roomId': roomRef.id,
            'roomCode': roomCode,
            'isHost': true,
          },
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreatingRoom = false);
    }
  }

  void _showJoinDialog() {
    final codeController = TextEditingController();
    bool isJoining = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.login,
                  color: AppTheme.primaryGreen,
                ),
              ),
              const SizedBox(width: 12),
              const Text('Rejoindre une partie'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: codeController,
                decoration: InputDecoration(
                  labelText: 'Code de la partie',
                  hintText: 'Ex: ABC123',
                  prefixIcon: const Icon(Icons.vpn_key),
                  counterText: '',
                ),
                textCapitalization: TextCapitalization.characters,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Demandez le code a l\'hote de la partie',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('Annuler'),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton(
              onPressed: isJoining
                  ? null
                  : () async {
                      if (codeController.text.length < 6) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Le code doit contenir 6 caracteres'),
                          ),
                        );
                        return;
                      }

                      setDialogState(() => isJoining = true);

                      try {
                        _soundService.playButtonClick();
                        final user = _authService.currentUser!;
                        final profile =
                            await _authService.getUserProfile(user.uid);
                        final roomCode = codeController.text.toUpperCase();
                        final roomId = await _roomService.joinRoomByCode(
                          roomCode: roomCode,
                          playerId: user.uid,
                          playerName: profile!['username'],
                        );

                        Navigator.pop(context);
                        Navigator.pushNamed(
                          context,
                          '/waiting-room',
                          arguments: {
                            'roomId': roomId,
                            'roomCode': roomCode,
                            'isHost': false,
                          },
                        );
                      } catch (e) {
                        setDialogState(() => isJoining = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(e.toString()),
                            backgroundColor: AppTheme.errorColor,
                          ),
                        );
                      }
                    },
              child: isJoining
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Rejoindre'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Multijoueur'),
        actions: [
          // Avatar et menu profil
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FutureBuilder(
              future: _authService.getUserProfile(
                _authService.currentUser!.uid,
              ),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox(width: 40);
                }
                final profile = snapshot.data as Map<String, dynamic>;

                return PopupMenuButton(
                  offset: const Offset(0, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: CircleAvatar(
                    backgroundColor: Colors.white,
                    child: Text(
                      profile['username']?[0]?.toUpperCase() ?? 'J',
                      style: const TextStyle(
                        color: AppTheme.primaryGreen,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  itemBuilder: (context) => <PopupMenuEntry>[
                    PopupMenuItem(
                      enabled: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile['username'] ?? 'Joueur',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          Text(
                            profile['email'] ?? '',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      child: const ListTile(
                        leading: Icon(Icons.person_outline),
                        title: Text('Mon Profil'),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                      onTap: () {
                        Future.delayed(const Duration(milliseconds: 100), () {
                          Navigator.pushNamed(context, '/profile');
                        });
                      },
                    ),
                    PopupMenuItem(
                      child: const ListTile(
                        leading: Icon(Icons.bar_chart),
                        title: Text('Statistiques'),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                      onTap: () {
                        // Délai nécessaire pour laisser le menu se fermer avant d'ouvrir le dialog
                        Future.delayed(const Duration(milliseconds: 100), () {
                          _showStatsDialog();
                        });
                      },
                    ),
                    PopupMenuItem(
                      child: ListTile(
                        leading: Icon(Icons.logout, color: Colors.red.shade400),
                        title: Text(
                          'Déconnexion',
                          style: TextStyle(color: Colors.red.shade400),
                        ),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                      onTap: () async {
                        await _authService.signOut();
                        if (mounted) {
                          Navigator.pushReplacementNamed(context, '/auth');
                        }
                      },
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      body: AnimationLimiter(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: AnimationConfiguration.toStaggeredList(
              duration: const Duration(milliseconds: 375),
              childAnimationBuilder: (widget) => SlideAnimation(
                verticalOffset: 50.0,
                child: FadeInAnimation(child: widget),
              ),
              children: [
                // Section Stats
                _buildStatsSection(),
                const SizedBox(height: 24),

                // Boutons d'action
                _buildActionButtons(),
                const SizedBox(height: 32),

                // Section Parties disponibles
                _buildAvailableRoomsSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration,
      child: FutureBuilder<Map<String, dynamic>>(
        future: _getPlayerStats(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Shimmer.fromColors(
              baseColor: Colors.white24,
              highlightColor: Colors.white54,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(
                  3,
                  (index) => Column(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 40,
                        height: 24,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 60,
                        height: 12,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          final stats = snapshot.data!;

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                icon: Icons.emoji_events,
                label: 'Victoires',
                value: '${stats['wins']}',
              ),
              Container(
                width: 1,
                height: 50,
                color: Colors.white24,
              ),
              _buildStatItem(
                icon: Icons.gamepad,
                label: 'Parties',
                value: '${stats['gamesPlayed']}',
              ),
              Container(
                width: 1,
                height: 50,
                color: Colors.white24,
              ),
              _buildStatItem(
                icon: Icons.trending_up,
                label: 'Ratio',
                value: '${stats['winRate']}%',
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // Bouton Creer une partie
        SizedBox(
          height: 60,
          child: ElevatedButton.icon(
            icon: _isCreatingRoom
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.add_circle_outline, size: 24),
            label: Text(
              _isCreatingRoom ? 'Creation...' : 'Creer une partie',
              style: const TextStyle(fontSize: 16),
            ),
            onPressed: _isCreatingRoom ? null : _createRoom,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Bouton Rejoindre avec code
        SizedBox(
          height: 60,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.login, size: 24),
            label: const Text(
              'Rejoindre avec code',
              style: TextStyle(fontSize: 16),
            ),
            onPressed: _showJoinDialog,
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAvailableRoomsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.public,
                    color: AppTheme.primaryGreen,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Parties disponibles',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                setState(() {});
              },
              tooltip: 'Actualiser',
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Liste des parties
        StreamBuilder(
          stream: _roomService.getAvailableRooms(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingShimmer();
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return _buildEmptyState();
            }

            final rooms = snapshot.data!.docs;

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: rooms.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final room = rooms[index];
                final data = room.data() as Map<String, dynamic>;

                return _buildRoomCard(
                  roomId: room.id,
                  roomCode: data['roomCode'] ?? '',
                  currentPlayers: data['currentPlayers'] ?? 1,
                  maxPlayers: data['maxPlayers'] ?? 4,
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildRoomCard({
    required String roomId,
    required String roomCode,
    required int currentPlayers,
    required int maxPlayers,
  }) {
    final isFull = currentPlayers >= maxPlayers;
    final isAlmostFull = currentPlayers >= maxPlayers - 1;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: isFull ? null : () => _joinRoom(roomId, roomCode),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icone avec gradient
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: isFull
                        ? LinearGradient(
                            colors: [Colors.grey.shade400, Colors.grey.shade500],
                          )
                        : AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.gamepad,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),

                // Infos
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Partie $roomCode',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (isFull) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'COMPLET',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red.shade700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.people,
                            size: 16,
                            color: isAlmostFull
                                ? Colors.orange.shade600
                                : Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$currentPlayers/$maxPlayers joueurs',
                            style: TextStyle(
                              fontSize: 14,
                              color: isAlmostFull
                                  ? Colors.orange.shade600
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Bouton rejoindre
                if (!isFull)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Rejoindre',
                      style: TextStyle(
                        color: AppTheme.primaryGreen,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _joinRoom(String roomId, String roomCode) async {
    try {
      _soundService.playButtonClick();
      final user = _authService.currentUser!;
      final profile = await _authService.getUserProfile(user.uid);

      await _roomService.joinRoomByCode(
        roomCode: roomCode,
        playerId: user.uid,
        playerName: profile!['username'],
      );

      if (mounted) {
        Navigator.pushNamed(
          context,
          '/waiting-room',
          arguments: {
            'roomId': roomId,
            'roomCode': roomCode,
            'isHost': false,
          },
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Widget _buildLoadingShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Column(
        children: List.generate(
          3,
          (index) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(
            Icons.sports_esports_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'Aucune partie disponible',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Creez une partie ou rejoignez avec un code',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showStatsDialog() {
    showDialog(
      context: context,
      builder: (context) => FutureBuilder<Map<String, dynamic>>(
        future: _getPlayerStats(),
        builder: (context, snapshot) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.bar_chart,
                    color: AppTheme.primaryGreen,
                  ),
                ),
                const SizedBox(width: 12),
                const Text('Mes statistiques'),
              ],
            ),
            content: snapshot.hasData
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildStatRow(
                        'Victoires',
                        '${snapshot.data!['wins']}',
                        Icons.emoji_events,
                        Colors.amber,
                      ),
                      const Divider(),
                      _buildStatRow(
                        'Parties jouees',
                        '${snapshot.data!['gamesPlayed']}',
                        Icons.gamepad,
                        AppTheme.primaryGreen,
                      ),
                      const Divider(),
                      _buildStatRow(
                        'Taux de victoire',
                        '${snapshot.data!['winRate']}%',
                        Icons.trending_up,
                        Colors.blue,
                      ),
                    ],
                  )
                : const Center(child: CircularProgressIndicator()),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fermer'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatRow(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 16),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
