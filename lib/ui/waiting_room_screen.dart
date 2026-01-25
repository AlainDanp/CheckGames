import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../services/firebase_room_service.dart';
import '../services/firebase_auth_service.dart';
import '../services/sound_service.dart';
import '../theme/app_theme.dart';

class WaitingRoomScreen extends StatefulWidget {
  final String roomId;
  final String roomCode;
  final bool isHost;

  const WaitingRoomScreen({
    Key? key,
    required this.roomId,
    required this.roomCode,
    required this.isHost,
  }) : super(key: key);

  @override
  State<WaitingRoomScreen> createState() => _WaitingRoomScreenState();
}

class _WaitingRoomScreenState extends State<WaitingRoomScreen>
    with SingleTickerProviderStateMixin {
  final _roomService = FirebaseRoomService();
  final _authService = FirebaseAuthService();
  final _soundService = SoundService();
  final _chatController = TextEditingController();
  final _chatScrollController = ScrollController();

  bool _isReady = false;
  bool _isStarting = false;
  bool _showChat = false;
  String _currentPlayerName = '';

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();

    // Jouer son d'entree
    _soundService.playJoinSound();

    // Recuperer le nom du joueur courant
    _loadCurrentPlayerName();
  }

  Future<void> _loadCurrentPlayerName() async {
    final doc = await FirebaseFirestore.instance
        .collection('game_rooms')
        .doc(widget.roomId)
        .collection('players')
        .doc(currentUserId)
        .get();

    if (doc.exists && mounted) {
      setState(() {
        _currentPlayerName = doc.data()?['playerName'] ?? 'Joueur';
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _chatController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  String get currentUserId => FirebaseAuth.instance.currentUser?.uid ?? '';

  Future<void> _copyRoomCode() async {
    await Clipboard.setData(ClipboardData(text: widget.roomCode));
    _soundService.playCopySound();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              const Text('Code copie dans le presse-papier'),
            ],
          ),
          backgroundColor: AppTheme.successColor,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _toggleReady() async {
    setState(() => _isReady = !_isReady);
    _soundService.playReadySound();

    try {
      await _roomService.setPlayerReady(
        widget.roomId,
        currentUserId,
        _isReady,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isReady = !_isReady);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _startGame() async {
    setState(() => _isStarting = true);
    _soundService.playStartSound();

    try {
      await _roomService.startGame(widget.roomId);
      if (mounted) {
        Navigator.pushReplacementNamed(
          context,
          '/multiplayer-game',
          arguments: {'roomId': widget.roomId},
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isStarting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _sendMessage() async {
    final message = _chatController.text.trim();
    if (message.isEmpty) return;

    _chatController.clear();
    _soundService.playMessageSound();

    try {
      await _roomService.sendMessage(widget.roomId, currentUserId, _currentPlayerName, message);
      // Scroll vers le bas apres envoi
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_chatScrollController.hasClients) {
          _chatScrollController.animateTo(
            _chatScrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      // Ignorer les erreurs de chat
    }
  }

  Future<void> _leaveRoom() async {
    _soundService.playLeaveSound();
    await _roomService.leaveRoom(widget.roomId, currentUserId);
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _roomService.watchRoom(widget.roomId),
      builder: (context, roomSnapshot) {
        if (roomSnapshot.hasData && roomSnapshot.data!.exists) {
          final roomData = roomSnapshot.data!.data() as Map<String, dynamic>;
          final status = roomData['status'] as String?;

          if (status == 'playing') {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                Navigator.pushReplacementNamed(
                  context,
                  '/multiplayer-game',
                  arguments: {'roomId': widget.roomId},
                );
              }
            });
          }
        }

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {
            if (!didPop) {
              final shouldLeave = await _showLeaveConfirmDialog();
              if (shouldLeave && mounted) {
                await _leaveRoom();
              }
            }
          },
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Salle d\'attente'),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () async {
                  final shouldLeave = await _showLeaveConfirmDialog();
                  if (shouldLeave) {
                    await _leaveRoom();
                  }
                },
              ),
              actions: [
                // Bouton chat
                IconButton(
                  icon: Badge(
                    isLabelVisible: !_showChat,
                    child: Icon(_showChat ? Icons.chat : Icons.chat_outlined),
                  ),
                  onPressed: () {
                    setState(() => _showChat = !_showChat);
                  },
                  tooltip: 'Chat',
                ),
              ],
            ),
            body: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  // Banniere code (masquee quand chat actif)
                  if (!_showChat) _buildCodeBanner(),

                  // Message info (masque quand chat actif)
                  if (!_showChat) _buildInfoMessage(),

                  // Liste joueurs ou Chat
                  Expanded(
                    child: _showChat
                        ? _buildChatSection()
                        : _buildPlayersSection(),
                  ),

                  // Boutons d'action (masques quand chat actif)
                  if (!_showChat) _buildActionButtons(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCodeBanner() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.vpn_key,
                color: Colors.white70,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Code de la partie',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.roomCode,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 8,
                ),
              ),
              const SizedBox(width: 16),
              Material(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  onTap: _copyRoomCode,
                  borderRadius: BorderRadius.circular(8),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(
                      Icons.copy,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Partagez ce code avec vos amis',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoMessage() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: widget.isHost
            ? Colors.amber.shade50
            : AppTheme.primaryGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.isHost
              ? Colors.amber.shade200
              : AppTheme.primaryGreen.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            widget.isHost ? Icons.admin_panel_settings : Icons.info_outline,
            color: widget.isHost ? Colors.amber.shade700 : AppTheme.primaryGreen,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.isHost
                  ? 'Vous etes l\'hote. Lancez la partie quand tous les joueurs sont prets.'
                  : 'En attente que l\'hote lance la partie...',
              style: TextStyle(
                color: widget.isHost
                    ? Colors.amber.shade800
                    : AppTheme.primaryGreen,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayersSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: _roomService.watchRoomPlayers(widget.roomId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final players = snapshot.data!.docs;

        return AnimationLimiter(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: players.length,
            itemBuilder: (context, index) {
              final playerDoc = players[index];
              final player = playerDoc.data() as Map<String, dynamic>;
              final playerId = playerDoc.id;
              final isCurrentUser = playerId == currentUserId;
              final isHost = index == 0;
              final isOnline = player['isOnline'] ?? true;
              final isReady = player['isReady'] ?? false;

              return AnimationConfiguration.staggeredList(
                position: index,
                duration: const Duration(milliseconds: 375),
                child: SlideAnimation(
                  verticalOffset: 50.0,
                  child: FadeInAnimation(
                    child: _buildPlayerCard(
                      name: player['playerName'] ?? 'Joueur ${index + 1}',
                      isCurrentUser: isCurrentUser,
                      isHost: isHost,
                      isOnline: isOnline,
                      isReady: isReady,
                      index: index,
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildPlayerCard({
    required String name,
    required bool isCurrentUser,
    required bool isHost,
    required bool isOnline,
    required bool isReady,
    required int index,
  }) {
    final avatarColors = [
      Colors.blue,
      Colors.purple,
      Colors.orange,
      Colors.teal,
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCurrentUser ? AppTheme.primaryGreen.withOpacity(0.08) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isCurrentUser
            ? Border.all(color: AppTheme.primaryGreen.withOpacity(0.3), width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar avec indicateur online
          Stack(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: avatarColors[index % avatarColors.length],
                child: Text(
                  name[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: isOnline ? Colors.green : Colors.grey,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),

          // Nom et badges
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Badges
                    if (isHost)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.star,
                              size: 12,
                              color: Colors.amber.shade700,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'HOTE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (isCurrentUser) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'VOUS',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryGreen,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  isOnline ? 'En ligne' : 'Hors ligne',
                  style: TextStyle(
                    fontSize: 12,
                    color: isOnline ? Colors.green : Colors.grey,
                  ),
                ),
              ],
            ),
          ),

          // Statut pret
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isReady ? Colors.green.shade100 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isReady ? Icons.check_circle : Icons.hourglass_empty,
                  size: 16,
                  color: isReady ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 4),
                Text(
                  isReady ? 'Pret' : 'Attente',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isReady ? Colors.green.shade700 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatSection() {
    return Column(
      children: [
        // Messages
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _roomService.watchMessages(widget.roomId),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final messages = snapshot.data!.docs;

              if (messages.isEmpty) {
                return SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 48,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Aucun message',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.builder(
                controller: _chatScrollController,
                padding: const EdgeInsets.all(16),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[index].data() as Map<String, dynamic>;
                  final isMe = message['playerId'] == currentUserId;

                  return _buildChatBubble(
                    message: message['message'] ?? '',
                    playerName: message['playerName'] ?? 'Joueur',
                    isMe: isMe,
                  );
                },
              );
            },
          ),
        ),

        // Input
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chatController,
                  decoration: InputDecoration(
                    hintText: 'Votre message...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: const BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.send, color: Colors.white),
                  onPressed: _sendMessage,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChatBubble({
    required String message,
    required String playerName,
    required bool isMe,
  }) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 4),
                child: Text(
                  playerName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? AppTheme.primaryGreen : Colors.grey.shade200,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
              ),
              child: Text(
                message,
                style: TextStyle(
                  color: isMe ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return StreamBuilder<QuerySnapshot>(
      stream: _roomService.watchRoomPlayers(widget.roomId),
      builder: (context, snapshot) {
        final playerCount = snapshot.data?.docs.length ?? 0;
        final canStart = playerCount >= 2;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            child: Row(
              children: [
                if (widget.isHost)
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: ElevatedButton.icon(
                        icon: _isStarting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.play_arrow),
                        label: Text(
                          _isStarting ? 'Lancement...' : 'Lancer la partie',
                        ),
                        onPressed: canStart && !_isStarting ? _startGame : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGreen,
                          disabledBackgroundColor: Colors.grey.shade300,
                        ),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: ElevatedButton.icon(
                        icon: Icon(
                          _isReady ? Icons.check_circle : Icons.radio_button_unchecked,
                        ),
                        label: Text(_isReady ? 'Pret !' : 'Je suis pret'),
                        onPressed: _toggleReady,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              _isReady ? Colors.green : AppTheme.primaryGreen,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<bool> _showLeaveConfirmDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.exit_to_app,
                    color: Colors.red.shade400,
                  ),
                ),
                const SizedBox(width: 12),
                const Text('Quitter la salle ?'),
              ],
            ),
            content: const Text(
              'Etes-vous sur de vouloir quitter cette salle d\'attente ?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade400,
                ),
                child: const Text('Quitter'),
              ),
            ],
          ),
        ) ??
        false;
  }
}
