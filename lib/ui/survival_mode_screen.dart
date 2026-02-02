import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../Bloc/checkgames_bloc.dart';
import '../Bloc/checkgames_event.dart';
import '../Bloc/checkgames_state.dart';
import '../repository/checkgame_repository.dart';
import '../services/audio_service.dart';
import '../services/game_settings_service.dart';
import '../services/survival_leaderboard_service.dart';
import 'game_page.dart';

class SurvivalModeScreen extends StatefulWidget {
  final CheckgameRepository repository;

  const SurvivalModeScreen({super.key, required this.repository});

  @override
  State<SurvivalModeScreen> createState() => _SurvivalModeScreenState();
}

class _SurvivalModeScreenState extends State<SurvivalModeScreen> {
  int _currentRound = 0;
  bool _isPlaying = false;
  bool _showLeaderboard = true;

  @override
  void initState() {
    super.initState();
    SurvivalLeaderboardService.instance.init();
  }

  /// Retourne la difficulté en fonction de la manche
  String _getDifficulty(int round) {
    if (round <= 3) return 'Facile';
    if (round <= 6) return 'Moyen';
    if (round <= 10) return 'Difficile';
    return 'Expert';
  }

  /// Retourne le timer en secondes en fonction de la manche
  int _getTimerSeconds(int round) {
    if (round <= 3) return 12;
    if (round <= 6) return 10;
    if (round <= 10) return 8;
    return 6;
  }

  /// Retourne la couleur de difficulté
  Color _getDifficultyColor(String difficulty) {
    switch (difficulty) {
      case 'Facile':
        return Colors.green;
      case 'Moyen':
        return Colors.orange;
      case 'Difficile':
        return Colors.red;
      case 'Expert':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  void _startGame() {
    setState(() {
      _isPlaying = true;
      _showLeaderboard = false;
      if (_currentRound == 0) _currentRound = 1;
    });
  }

  void _onGameEnd(bool playerWon) {
    if (playerWon) {
      setState(() {
        _currentRound++;
        _isPlaying = false;
      });
      _showRoundCompleteDialog();
    } else {
      setState(() {
        _isPlaying = false;
      });
      _handleGameOver();
    }
  }

  void _showRoundCompleteDialog() {
    final nextDifficulty = _getDifficulty(_currentRound);
    final nextTimer = _getTimerSeconds(_currentRound);
    final difficultyChanged = _getDifficulty(_currentRound) != _getDifficulty(_currentRound - 1);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade800, Colors.blue.shade900],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.cyan, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: Colors.greenAccent, size: 50),
              const SizedBox(height: 12),
              Text(
                'MANCHE ${_currentRound - 1} RÉUSSIE !',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 20),

              // Info prochaine manche
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Text(
                      'PROCHAINE MANCHE',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Manche
                        Column(
                          children: [
                            Text(
                              '$_currentRound',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const Text(
                              'Manche',
                              style: TextStyle(color: Colors.white60, fontSize: 12),
                            ),
                          ],
                        ),
                        // Difficulté
                        Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: _getDifficultyColor(nextDifficulty),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                nextDifficulty,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Difficulté',
                              style: TextStyle(color: Colors.white60, fontSize: 12),
                            ),
                          ],
                        ),
                        // Timer
                        Column(
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.timer, color: Colors.amber, size: 20),
                                const SizedBox(width: 4),
                                Text(
                                  '${nextTimer}s',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber,
                                  ),
                                ),
                              ],
                            ),
                            const Text(
                              'Timer',
                              style: TextStyle(color: Colors.white60, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              if (difficultyChanged) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.withOpacity(0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.warning_amber, color: Colors.amber, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Difficulté augmentée !',
                        style: TextStyle(
                          color: Colors.amber.shade200,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),

              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _startGame();
                },
                icon: const Icon(Icons.play_arrow),
                label: const Text('CONTINUER'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
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
                  'Arrêter ici',
                  style: TextStyle(color: Colors.white60),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleGameOver() async {
    final rounds = _currentRound > 0 ? _currentRound - 1 : 0;

    if (rounds > 0) {
      final isHighScore = await SurvivalLeaderboardService.instance.isHighScore(rounds);

      if (isHighScore && mounted) {
        await _showHighScoreEntry(rounds);
      } else if (mounted) {
        _showGameOverDialog(rounds);
      }
    } else {
      setState(() {
        _currentRound = 0;
        _showLeaderboard = true;
      });
    }
  }

  Future<void> _showHighScoreEntry(int rounds) async {
    final difficulty = _getDifficulty(rounds);

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _SurvivalHighScoreDialog(
        rounds: rounds,
        difficulty: difficulty,
        onSubmit: (name) async {
          await SurvivalLeaderboardService.instance.addScore(name, rounds, difficulty);
        },
      ),
    );

    setState(() {
      _currentRound = 0;
      _showLeaderboard = true;
    });
  }

  void _showGameOverDialog(int rounds) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Column(
          children: [
            Icon(Icons.dangerous, color: Colors.red, size: 60),
            SizedBox(height: 12),
            Text(
              'ÉLIMINÉ !',
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
              'Vous avez survécu $rounds manche${rounds > 1 ? 's' : ''} !',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Difficulté atteinte : ${_getDifficulty(rounds)}',
              style: TextStyle(
                color: _getDifficultyColor(_getDifficulty(rounds)),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _currentRound = 0;
                _showLeaderboard = true;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
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
      return _SurvivalGameWrapper(
        key: ValueKey(_currentRound),
        repository: widget.repository,
        round: _currentRound,
        timerSeconds: _getTimerSeconds(_currentRound),
        difficulty: _getDifficulty(_currentRound),
        onGameEnd: _onGameEnd,
      );
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1a1a2e), Color(0xFF16213e), Color(0xFF0f3460)],
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
                        'MODE SURVIE',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.cyan,
                          letterSpacing: 3,
                          shadows: [
                            Shadow(color: Colors.cyan, blurRadius: 10),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),

              // Logo Survie
              _buildSurvivalLogo(),

              const SizedBox(height: 20),

              // Bouton Jouer
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: _SurvivalButton(
                  text: 'SURVIVRE',
                  icon: Icons.flash_on,
                  color: Colors.cyan,
                  onTap: () {
                    AudioService.instance.playButtonClick();
                    setState(() {
                      _currentRound = 1;
                    });
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

  Widget _buildSurvivalLogo() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.cyan, width: 2),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.cyan.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              children: [
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.timer, color: Colors.amber, size: 28),
                    SizedBox(width: 8),
                    Text(
                      'SURVIE',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.cyan,
                        letterSpacing: 2,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.timer, color: Colors.amber, size: 28),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Temps limité • Difficulté croissante',
                  style: TextStyle(
                    fontSize: 13,
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

  Widget _buildLeaderboard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.cyan.withOpacity(0.4), width: 2),
      ),
      child: Column(
        children: [
          // Header du classement
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.cyan.withOpacity(0.2),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.leaderboard, color: Colors.cyan, size: 24),
                SizedBox(width: 8),
                Text(
                  'SURVIVANTS',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.cyan,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),

          // Liste des scores
          Expanded(
            child: FutureBuilder<void>(
              future: SurvivalLeaderboardService.instance.init(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.cyan),
                  );
                }

                final leaderboard = SurvivalLeaderboardService.instance.getLeaderboard();

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
                          'Aucun survivant',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Serez-vous le premier ?',
                          style: TextStyle(
                            color: Colors.cyan.withOpacity(0.7),
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
                    return _SurvivalLeaderboardEntry(
                      rank: index + 1,
                      name: score.name,
                      rounds: score.rounds,
                      difficulty: score.maxDifficulty,
                      difficultyColor: _getDifficultyColor(score.maxDifficulty),
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

// Bouton style survie
class _SurvivalButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _SurvivalButton({
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
            border: Border.all(color: Colors.white, width: 2),
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
              Icon(icon, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              Text(
                text,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Entrée du classement
class _SurvivalLeaderboardEntry extends StatelessWidget {
  final int rank;
  final String name;
  final int rounds;
  final String difficulty;
  final Color difficultyColor;

  const _SurvivalLeaderboardEntry({
    required this.rank,
    required this.name,
    required this.rounds,
    required this.difficulty,
    required this.difficultyColor,
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: rank <= 3 ? rankColor.withOpacity(0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: rank <= 3 ? Border.all(color: rankColor.withOpacity(0.5)) : null,
      ),
      child: Row(
        children: [
          // Rang
          SizedBox(
            width: 35,
            child: rankIcon != null
                ? Icon(rankIcon, color: rankColor, size: 26)
                : Text(
                    '$rank.',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: rankColor,
                    ),
                  ),
          ),

          const SizedBox(width: 12),

          // Nom
          Text(
            name.padRight(3).substring(0, 3).toUpperCase(),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: rank <= 3 ? rankColor : Colors.white70,
              fontFamily: 'monospace',
              letterSpacing: 3,
            ),
          ),

          const Spacer(),

          // Difficulté
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: difficultyColor.withOpacity(0.3),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              difficulty,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: difficultyColor,
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Rounds
          Row(
            children: [
              const Icon(Icons.flag, color: Colors.greenAccent, size: 18),
              const SizedBox(width: 4),
              Text(
                '$rounds',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: rank <= 3 ? rankColor : Colors.white54,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Dialog High Score pour Survie
class _SurvivalHighScoreDialog extends StatefulWidget {
  final int rounds;
  final String difficulty;
  final Future<void> Function(String name) onSubmit;

  const _SurvivalHighScoreDialog({
    required this.rounds,
    required this.difficulty,
    required this.onSubmit,
  });

  @override
  State<_SurvivalHighScoreDialog> createState() => _SurvivalHighScoreDialogState();
}

class _SurvivalHighScoreDialogState extends State<_SurvivalHighScoreDialog> {
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

  Future<void> _submit() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    AudioService.instance.playButtonClick();
    await widget.onSubmit(_letters.join());

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1a1a2e), Color(0xFF0f3460)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.cyan, width: 3),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'NOUVEAU RECORD !',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.cyan,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 16),

            // Score
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.cyan.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.flag, color: Colors.greenAccent, size: 28),
                  const SizedBox(width: 8),
                  Text(
                    '${widget.rounds}',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'MANCHES',
                    style: TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              'ENTREZ VOS INITIALES',
              style: TextStyle(fontSize: 12, color: Colors.white60, letterSpacing: 2),
            ),

            const SizedBox(height: 16),

            // Sélecteur de lettres
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (index) {
                  final isSelected = index == _currentIndex;
                  return GestureDetector(
                    onTap: () => setState(() => _currentIndex = index),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isSelected)
                            IconButton(
                              onPressed: () => _changeLetter(1),
                              icon: const Icon(Icons.arrow_drop_up, color: Colors.cyan, size: 28),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            )
                          else
                            const SizedBox(height: 28),

                          Container(
                            width: 45,
                            height: 55,
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.cyan.withOpacity(0.3) : Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected ? Colors.cyan : Colors.white24,
                                width: isSelected ? 3 : 1,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                _letters[index],
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? Colors.cyan : Colors.white54,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                          ),

                          if (isSelected)
                            IconButton(
                              onPressed: () => _changeLetter(-1),
                              icon: const Icon(Icons.arrow_drop_down, color: Colors.cyan, size: 28),
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
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyan,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSubmitting
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('ENREGISTRER', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 2)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Wrapper du jeu avec timer
class _SurvivalGameWrapper extends StatefulWidget {
  final CheckgameRepository repository;
  final int round;
  final int timerSeconds;
  final String difficulty;
  final void Function(bool playerWon) onGameEnd;

  const _SurvivalGameWrapper({
    super.key,
    required this.repository,
    required this.round,
    required this.timerSeconds,
    required this.difficulty,
    required this.onGameEnd,
  });

  @override
  State<_SurvivalGameWrapper> createState() => _SurvivalGameWrapperState();
}

class _SurvivalGameWrapperState extends State<_SurvivalGameWrapper> {
  late CheckGameBloc _bloc;
  bool _gameEnded = false;
  Timer? _turnTimer;
  int _remainingSeconds = 0;
  bool _isPlayerTurn = false;
  int _lastPlayerIndex = -1;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.timerSeconds;

    // Configurer la difficulté du bot
    _setBotDifficulty();

    final playerNames = ['Vous', 'Bot'];
    _bloc = CheckGameBloc(repository: widget.repository)
      ..add(StartGame(playerNames));
  }

  void _setBotDifficulty() {
    // Configurer la difficulté via le service
    switch (widget.difficulty) {
      case 'Facile':
        GameSettingsService.instance.setDifficulty(BotDifficulty.easy);
        break;
      case 'Moyen':
        GameSettingsService.instance.setDifficulty(BotDifficulty.normal);
        break;
      case 'Difficile':
        GameSettingsService.instance.setDifficulty(BotDifficulty.hard);
        break;
      case 'Expert':
        GameSettingsService.instance.setDifficulty(BotDifficulty.hard); // Expert = Hard pour l'instant
        break;
    }
  }

  void _startTimer() {
    _turnTimer?.cancel();
    _remainingSeconds = widget.timerSeconds;

    _turnTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _remainingSeconds--;
      });

      if (_remainingSeconds <= 0) {
        timer.cancel();
        _onTimerExpired();
      }
    });
  }

  void _stopTimer() {
    _turnTimer?.cancel();
  }

  void _onTimerExpired() {
    if (!_isPlayerTurn || _gameEnded) return;

    // Temps écoulé : le joueur pioche et passe son tour
    AudioService.instance.playButtonClick();
    _bloc.add(DrawCard(playerId: '0', count: 1));
  }

  @override
  void dispose() {
    _turnTimer?.cancel();
    _bloc.close();
    super.dispose();
  }

  Color _getTimerColor() {
    if (_remainingSeconds <= 3) return Colors.red;
    if (_remainingSeconds <= 5) return Colors.orange;
    return Colors.greenAccent;
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<Bloc<CheckgamesEvent, CheckgamesState>>.value(
      value: _bloc,
      child: BlocListener<Bloc<CheckgamesEvent, CheckgamesState>, CheckgamesState>(
        listener: (context, state) {
          // Détecter le changement de tour
          if (state.currentPlayerIndex != _lastPlayerIndex) {
            _lastPlayerIndex = state.currentPlayerIndex;
            _isPlayerTurn = state.currentPlayerIndex == 0;

            if (_isPlayerTurn && !state.isGameOver && !state.isPaused) {
              _startTimer();
            } else {
              _stopTimer();
            }
          }

          // Pause/Resume
          if (state.isPaused) {
            _stopTimer();
          }

          // Fin de partie
          if (state.isGameOver && state.phase == GamePhase.finished && !_gameEnded) {
            _gameEnded = true;
            _stopTimer();

            final playerWon = state.finishingOrder.isNotEmpty &&
                state.finishingOrder.first == '0';

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

            // Indicateur survie discret à droite
            Positioned(
              top: 80,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.cyan.withOpacity(0.5)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Manche + Difficulté
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.flag, color: Colors.white70, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          '${widget.round}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getDifficultyColor(widget.difficulty).withOpacity(0.3),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            widget.difficulty,
                            style: TextStyle(
                              color: _getDifficultyColor(widget.difficulty),
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                    // Timer (seulement si c'est le tour du joueur)
                    if (_isPlayerTurn) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _getTimerColor().withOpacity(0.3),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: _getTimerColor(), width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.timer,
                              color: _getTimerColor(),
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$_remainingSeconds',
                              style: TextStyle(
                                color: _getTimerColor(),
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                fontFamily: 'monospace',
                                decoration: TextDecoration.none,
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

            // Alerte temps faible
            if (_isPlayerTurn && _remainingSeconds <= 3 && _remainingSeconds > 0)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.red.withOpacity(0.5),
                        width: 4,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty) {
      case 'Facile':
        return Colors.green;
      case 'Moyen':
        return Colors.orange;
      case 'Difficile':
        return Colors.red;
      case 'Expert':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}
