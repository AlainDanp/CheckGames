import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../Bloc/checkgames_bloc.dart';
import '../Bloc/checkgames_event.dart';
import '../Bloc/checkgames_state.dart';
import '../repository/checkgame_repository.dart';
import '../services/audio_service.dart';
import '../services/game_settings_service.dart';
import '../services/arcade_leaderboard_service.dart';
import 'game_page.dart';

class ArcadeModeScreen extends StatefulWidget {
  final CheckgameRepository repository;

  const ArcadeModeScreen({super.key, required this.repository});

  @override
  State<ArcadeModeScreen> createState() => _ArcadeModeScreenState();
}

class _ArcadeModeScreenState extends State<ArcadeModeScreen> {
  int _winStreak = 0;
  bool _isPlaying = false;
  bool _showLeaderboard = true;

  @override
  void initState() {
    super.initState();
    ArcadeLeaderboardService.instance.init();
  }

  void _startGame() {
    setState(() {
      _isPlaying = true;
      _showLeaderboard = false;
    });
  }

  void _onGameEnd(bool playerWon) {
    if (playerWon) {
      setState(() {
        _winStreak++;
        _isPlaying = false;
      });
      // Continuer automatiquement après une victoire
      _showQuickVictoryAndContinue();
    } else {
      // Défaite - vérifier si c'est un high score
      setState((){
        _isPlaying = false;
      });
      _handleGameOver();
    }
  }
  void _showQuickVictoryAndContinue() {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green.shade700, Colors.green.shade900],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.amber, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.emoji_events, color: Colors.amber, size: 50),
              const SizedBox(height: 12),
              const Text(
                'VICTOIRE !',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.amber,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.local_fire_department, color: Colors.deepOrange, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'Série : $_winStreak',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _startGame();
                },
                icon: const Icon(Icons.play_arrow),
                label: const Text('PARTIE SUIVANTE'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.green.shade800,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _handleGameOver();
                },
                child: const Text(
                  'Arrêter la série',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Future<void> _handleGameOver() async {
    // Note: _isPlaying est déjà false (défini dans _onGameEnd)

    if (_winStreak > 0) {
      final isHighScore = await ArcadeLeaderboardService.instance.isHighScore(_winStreak);

      if (isHighScore && mounted) {
        await _showHighScoreEntry();
      } else if (mounted) {
        _showGameOverDialog();
      }
    } else {
      setState(() {
        _showLeaderboard = true;
      });
    }
  }

  Future<void> _showHighScoreEntry() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _HighScoreEntryDialog(
        score: _winStreak,
        onSubmit: (enteredName) async {
          await ArcadeLeaderboardService.instance.addScore(enteredName, _winStreak);
        },
      ),
    );

    setState(() {
      _winStreak = 0;
      _showLeaderboard = true;
    });
  }

  void _showGameOverDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Column(
          children: [
            Icon(Icons.sentiment_dissatisfied, color: Colors.red, size: 60),
            SizedBox(height: 12),
            Text(
              'GAME OVER',
              style: TextStyle(
                color: Colors.red,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Série finale : $_winStreak victoire(s)',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Pas de high score cette fois...\nRéessayez !',
              style: TextStyle(color: Colors.white60),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _winStreak = 0;
                _showLeaderboard = true;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isPlaying) {
      return _ArcadeGameWrapper(
        key: ValueKey(_winStreak),
        repository: widget.repository,
        winStreak: _winStreak,
        onGameEnd: _onGameEnd,
      );
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        AudioService.instance.playButtonClick();
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                    ),
                    const Expanded(
                      child: Text(
                        'MODE ARCADE',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber,
                          letterSpacing: 3,
                          shadows: [
                            Shadow(
                              color: Colors.amber,
                              blurRadius: 10,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),

              // Logo Arcade
              _buildArcadeLogo(),

              const SizedBox(height: 20),


              // Bouton Jouer
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: _ArcadeButton(
                  text: 'JOUER',
                  icon: Icons.play_arrow,
                  color: Colors.green,
                  onTap: () {
                    AudioService.instance.playButtonClick();
                    _startGame();
                  },
                ),
              ),

              const SizedBox(height: 30),

              // Classement
              Expanded(
                child: _showLeaderboard
                    ? _buildLeaderboard()
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildArcadeLogo() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.amber, width: 3),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              children: [
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.local_fire_department, color: Colors.orange, size: 30),
                    SizedBox(width: 8),
                    Text(
                      'SÉRIE',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.amber,
                        letterSpacing: 2,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.local_fire_department, color: Colors.orange, size: 30),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Enchaînez les victoires !',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<List<ArcadeScore>> _loadLeaderboard() async {
    await ArcadeLeaderboardService.instance.init();
    return ArcadeLeaderboardService.instance.getLeaderboard();
  }

  Widget _buildLeaderboard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withOpacity(0.5), width: 2),
      ),
      child: Column(
        children: [
          // Header du classement
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.2),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.emoji_events, color: Colors.amber, size: 24),
                SizedBox(width: 8),
                Text(
                  'HIGH SCORES',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber,
                    letterSpacing: 2,
                  ),
                ),
                SizedBox(width: 8),
                Icon(Icons.emoji_events, color: Colors.amber, size: 24),
              ],
            ),
          ),

          // Liste des scores
          Expanded(
            child: FutureBuilder<List<ArcadeScore>>(
              future: _loadLeaderboard(),
              builder: (context, snapshot) {
                // Afficher un loader pendant le chargement
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.amber),
                  );
                }

                // Gérer les erreurs
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Erreur de chargement',
                      style: TextStyle(color: Colors.red.shade300),
                    ),
                  );
                }

                final leaderboard = snapshot.data ?? [];

                if (leaderboard.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.hourglass_empty,
                          size: 48,
                          color: Colors.white.withOpacity(0.3),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Aucun score enregistré',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Soyez le premier !',
                          style: TextStyle(
                            color: Colors.amber.withOpacity(0.7),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: leaderboard.length,
                  itemBuilder: (context, index) {
                    final score = leaderboard[index];
                    return _LeaderboardEntry(
                      rank: index + 1,
                      name: score.name,
                      score: score.score,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ArcadeButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ArcadeButton({
    required this.text,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.5),
                blurRadius: 15,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 30),
              const SizedBox(width: 12),
              Text(
                text,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LeaderboardEntry extends StatelessWidget {
  final int rank;
  final String name;
  final int score;

  const _LeaderboardEntry({
    required this.rank,
    required this.name,
    required this.score,
  });

  @override
  Widget build(BuildContext context) {
    Color rankColor;
    IconData? rankIcon;

    switch (rank) {
      case 1:
        rankColor = Colors.amber;
        rankIcon = Icons.looks_one;
        break;
      case 2:
        rankColor = Colors.grey.shade400;
        rankIcon = Icons.looks_two;
        break;
      case 3:
        rankColor = Colors.orange.shade700;
        rankIcon = Icons.looks_3;
        break;
      default:
        rankColor = Colors.white54;
        rankIcon = null;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: rank <= 3 ? rankColor.withOpacity(0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: rank <= 3 ? Border.all(color: rankColor.withOpacity(0.5)) : null,
      ),
      child: Row(
        children: [
          // Rang
          SizedBox(
            width: 40,
            child: rankIcon != null
                ? Icon(rankIcon, color: rankColor, size: 28)
                : Text(
                    '$rank.',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: rankColor,
                      fontFamily: 'monospace',
                    ),
                  ),
          ),

          const SizedBox(width: 16),

          // Nom (style arcade 3 lettres)
          Text(
            name.padRight(3).substring(0, 3).toUpperCase(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: rank <= 3 ? rankColor : Colors.white70,
              fontFamily: 'monospace',
              letterSpacing: 4,
            ),
          ),

          const Spacer(),

          // Score
          Row(
            children: [
              Icon(
                Icons.local_fire_department,
                color: rank <= 3 ? Colors.orange : Colors.orange.withOpacity(0.5),
                size: 20,
              ),
              const SizedBox(width: 4),
              Text(
                '$score',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: rank <= 3 ? rankColor : Colors.white54,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HighScoreEntryDialog extends StatefulWidget {
  final int score;
  final Future<void> Function(String name) onSubmit;

  const _HighScoreEntryDialog({
    required this.score,
    required this.onSubmit,
  });

  @override
  State<_HighScoreEntryDialog> createState() => _HighScoreEntryDialogState();
}

class _HighScoreEntryDialogState extends State<_HighScoreEntryDialog> {
  final List<String> _letters = ['A', 'A', 'A'];
  int _currentIndex = 0;
  bool _isSubmitting = false;

  void _changeLetter(int delta) {
    AudioService.instance.playButtonClick();
    setState(() {
      int charCode = _letters[_currentIndex].codeUnitAt(0) + delta;
      if (charCode > 'Z'.codeUnitAt(0)) charCode = 'A'.codeUnitAt(0);
      if (charCode < 'A'.codeUnitAt(0)) charCode = 'Z'.codeUnitAt(0);
      _letters[_currentIndex] = String.fromCharCode(charCode);
    });
  }

  void _selectNextLetter() {
    AudioService.instance.playButtonClick();
    setState(() {
      if (_currentIndex < 2) {
        _currentIndex++;
      }
    });
  }

  void _selectPreviousLetter() {
    AudioService.instance.playButtonClick();
    setState(() {
      if (_currentIndex > 0) {
        _currentIndex--;
      }
    });
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    AudioService.instance.playButtonClick();
    final name = _letters.join();
    await widget.onSubmit(name);

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.amber, width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.amber.withOpacity(0.3),
              blurRadius: 30,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Titre
            const Text(
              '🎉 HIGH SCORE ! 🎉',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.amber,
                letterSpacing: 2,
              ),
            ),

            const SizedBox(height: 16),

            // Score
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.local_fire_department, color: Colors.orange, size: 30),
                  const SizedBox(width: 8),
                  Text(
                    '${widget.score}',
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'VICTOIRES',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.amber,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              'ENTREZ VOS INITIALES',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white70,
                letterSpacing: 2,
              ),
            ),

            const SizedBox(height: 16),

            // Sélecteur de lettres
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Flèche gauche
                  IconButton(
                    onPressed: _selectPreviousLetter,
                    icon: Icon(
                      Icons.arrow_left,
                      color: _currentIndex > 0 ? Colors.white : Colors.white24,
                      size: 28,
                    ),
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                  ),

                  // Lettres
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(3, (index) {
                      final isSelected = index == _currentIndex;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _currentIndex = index;
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Flèche haut
                              if (isSelected)
                                IconButton(
                                  onPressed: () => _changeLetter(1),
                                  icon: const Icon(Icons.arrow_drop_up, color: Colors.amber, size: 28),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                )
                              else
                                const SizedBox(height: 28),

                              // Lettre
                              Container(
                                width: 45,
                                height: 55,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.amber.withOpacity(0.3)
                                      : Colors.white.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSelected ? Colors.amber : Colors.white24,
                                    width: isSelected ? 3 : 1,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    _letters[index],
                                    style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? Colors.amber : Colors.white54,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ),
                              ),

                              // Flèche bas
                              if (isSelected)
                                IconButton(
                                  onPressed: () => _changeLetter(-1),
                                  icon: const Icon(Icons.arrow_drop_down, color: Colors.amber, size: 28),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                )
                              else
                                const SizedBox(height: 28),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),

                  // Flèche droite
                  IconButton(
                    onPressed: _selectNextLetter,
                    icon: Icon(
                      Icons.arrow_right,
                      color: _currentIndex < 2 ? Colors.white : Colors.white24,
                      size: 28,
                    ),
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Bouton OK
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'ENREGISTRER',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Wrapper pour le jeu arcade avec détection de fin de partie
class _ArcadeGameWrapper extends StatefulWidget {
  final CheckgameRepository repository;
  final int winStreak;
  final void Function(bool playerWon) onGameEnd;

  const _ArcadeGameWrapper({
    super.key,
    required this.repository,
    required this.winStreak,
    required this.onGameEnd,
  });

  @override
  State<_ArcadeGameWrapper> createState() => _ArcadeGameWrapperState();
}

class _ArcadeGameWrapperState extends State<_ArcadeGameWrapper> {
  late CheckGameBloc _bloc;
  bool _gameEnded = false;

  @override
  void initState() {
    super.initState();
    final playerNames = GameSettingsService.instance.generatePlayerNames();
    _bloc = CheckGameBloc(repository: widget.repository)
      ..add(StartGame(playerNames));
  }

  @override
  void dispose() {
    _bloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<Bloc<CheckgamesEvent, CheckgamesState>>.value(
      value: _bloc,
      child: BlocListener<Bloc<CheckgamesEvent, CheckgamesState>, CheckgamesState>(
        listener: (context, state) {
          if (state.isGameOver && state.phase == GamePhase.finished && !_gameEnded) {
            _gameEnded = true;

            final playerWon = state.finishingOrder.isNotEmpty &&
                state.finishingOrder.first == '0';

            // Délai pour laisser l'animation de fin se jouer
            Future.delayed(const Duration(milliseconds: 800), () {
              if (mounted) {
                widget.onGameEnd(playerWon);
              }
            });
          }
        },
        child: Stack(
          children: [
            const GamePage(),

            // Indicateur de série discret à droite
            Positioned(
              top: 80,
              right: 7,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: widget.winStreak > 0 ? Colors.orange.withOpacity(0.6) : Colors.white24,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.local_fire_department,
                      color: widget.winStreak > 0 ? Colors.orange : Colors.grey,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${widget.winStreak}',
                      style: TextStyle(
                        color: widget.winStreak > 0 ? Colors.white : Colors.white70,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
