import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../models/playing_card.dart';
import '../models/card_suit.dart';
import '../models/card_value.dart';
import '../view/widgets/playing_card_widget.dart';

class TutorialInteractiveScreen extends StatefulWidget {
  const TutorialInteractiveScreen({super.key});

  @override
  State<TutorialInteractiveScreen> createState() => _TutorialInteractiveScreenState();
}

class _TutorialInteractiveScreenState extends State<TutorialInteractiveScreen>
    with TickerProviderStateMixin {
  int _currentLesson = 0;
  int _currentStep = 0;
  PlayingCard? _selectedCard;
  bool _showSuccess = false;
  bool _showHint = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final List<InteractiveLesson> _lessons = [
    // Leçon 1: Jouer par couleur
    InteractiveLesson(
      title: 'Jouer par couleur',
      description: 'Apprenez à jouer une carte de même couleur',
      steps: [
        InteractiveStep(
          instruction: 'Sur la défausse, il y a un 5 de ♥ (cœur).\n\nTrouvez et sélectionnez une carte ♥ dans votre main.',
          discardCard: PlayingCard(suit: CardSuit.hearts, value: CardValue.five),
          playerHand: [
            PlayingCard(suit: CardSuit.spades, value: CardValue.king),
            PlayingCard(suit: CardSuit.hearts, value: CardValue.nine),
            PlayingCard(suit: CardSuit.clubs, value: CardValue.three),
            PlayingCard(suit: CardSuit.diamonds, value: CardValue.seven),
          ],
          validCards: [PlayingCard(suit: CardSuit.hearts, value: CardValue.nine)],
          hint: 'Cherchez une carte avec le symbole ♥ (cœur rouge)',
        ),
      ],
    ),

    // Leçon 2: Jouer par valeur
    InteractiveLesson(
      title: 'Jouer par valeur',
      description: 'Apprenez à jouer une carte de même valeur',
      steps: [
        InteractiveStep(
          instruction: 'Sur la défausse, il y a un 7 de ♠ (pique).\n\nTrouvez et sélectionnez une carte de valeur 7 dans votre main.',
          discardCard: PlayingCard(suit: CardSuit.spades, value: CardValue.seven),
          playerHand: [
            PlayingCard(suit: CardSuit.hearts, value: CardValue.king),
            PlayingCard(suit: CardSuit.diamonds, value: CardValue.seven),
            PlayingCard(suit: CardSuit.clubs, value: CardValue.five),
            PlayingCard(suit: CardSuit.spades, value: CardValue.three),
          ],
          validCards: [PlayingCard(suit: CardSuit.diamonds, value: CardValue.seven)],
          hint: 'Cherchez une carte avec le chiffre 7',
        ),
      ],
    ),

    // Leçon 3: Le 2 passe-partout
    InteractiveLesson(
      title: 'Le 2 - Passe-partout',
      description: 'Le 2 peut être joué sur n\'importe quelle carte !',
      steps: [
        InteractiveStep(
          instruction: 'Vous n\'avez aucune carte ♦ ni aucun Roi...\n\nMais vous avez un 2 ! Jouez-le pour vous débloquer.',
          discardCard: PlayingCard(suit: CardSuit.diamonds, value: CardValue.king),
          playerHand: [
            PlayingCard(suit: CardSuit.hearts, value: CardValue.five),
            PlayingCard(suit: CardSuit.clubs, value: CardValue.two),
            PlayingCard(suit: CardSuit.spades, value: CardValue.nine),
            PlayingCard(suit: CardSuit.hearts, value: CardValue.three),
          ],
          validCards: [PlayingCard(suit: CardSuit.clubs, value: CardValue.two)],
          hint: 'Le 2 peut être joué sur N\'IMPORTE quelle carte !',
        ),
      ],
    ),

    // Leçon 4: L'As fait passer
    InteractiveLesson(
      title: 'L\'As - Passer le tour',
      description: 'L\'As fait passer le tour du joueur suivant',
      steps: [
        InteractiveStep(
          instruction: 'L\'adversaire n\'a plus qu\'une carte !\n\nJouez un As pour lui faire passer son tour.',
          discardCard: PlayingCard(suit: CardSuit.clubs, value: CardValue.six),
          playerHand: [
            PlayingCard(suit: CardSuit.hearts, value: CardValue.ace),
            PlayingCard(suit: CardSuit.clubs, value: CardValue.king),
            PlayingCard(suit: CardSuit.diamonds, value: CardValue.four),
            PlayingCard(suit: CardSuit.spades, value: CardValue.eight),
          ],
          validCards: [
            PlayingCard(suit: CardSuit.hearts, value: CardValue.ace),
            PlayingCard(suit: CardSuit.clubs, value: CardValue.king),
          ],
          targetCards: [PlayingCard(suit: CardSuit.hearts, value: CardValue.ace)],
          hint: 'L\'As fait passer le tour ! Cherchez un As.',
          successMessage: 'Parfait ! L\'adversaire passe son tour.',
        ),
      ],
    ),

    // Leçon 5: Le 7 - Pioche forcée
    InteractiveLesson(
      title: 'Le 7 - Pioche +2',
      description: 'Le 7 force le suivant à piocher 2 cartes',
      steps: [
        InteractiveStep(
          instruction: 'Faites piocher 2 cartes à votre adversaire !\n\nJouez un 7.',
          discardCard: PlayingCard(suit: CardSuit.hearts, value: CardValue.three),
          playerHand: [
            PlayingCard(suit: CardSuit.hearts, value: CardValue.seven),
            PlayingCard(suit: CardSuit.clubs, value: CardValue.five),
            PlayingCard(suit: CardSuit.diamonds, value: CardValue.jack),
            PlayingCard(suit: CardSuit.spades, value: CardValue.king),
          ],
          validCards: [PlayingCard(suit: CardSuit.hearts, value: CardValue.seven)],
          hint: 'Le 7 inflige +2 cartes au joueur suivant !',
          successMessage: '+2 cartes pour l\'adversaire !',
        ),
      ],
    ),

    // Leçon 6: Se défendre avec un 7
    InteractiveLesson(
      title: 'Défense avec le 7',
      description: 'Contrez un 7 avec un autre 7 !',
      steps: [
        InteractiveStep(
          instruction: 'L\'adversaire vous a joué un 7 ! Vous devez piocher 2 cartes...\n\nSAUF si vous avez un 7 ! Jouez-le pour renvoyer le cumul.',
          discardCard: PlayingCard(suit: CardSuit.spades, value: CardValue.seven),
          playerHand: [
            PlayingCard(suit: CardSuit.hearts, value: CardValue.five),
            PlayingCard(suit: CardSuit.diamonds, value: CardValue.seven),
            PlayingCard(suit: CardSuit.clubs, value: CardValue.king),
            PlayingCard(suit: CardSuit.hearts, value: CardValue.three),
          ],
          validCards: [PlayingCard(suit: CardSuit.diamonds, value: CardValue.seven)],
          hint: 'Contrez avec un 7 ! Le cumul passe à +4.',
          successMessage: 'Bien joué ! Le cumul passe au joueur suivant (+4) !',
          showCumul: 2,
        ),
      ],
    ),

    // Leçon 7: Le Valet
    InteractiveLesson(
      title: 'Le Valet - Changer la couleur',
      description: 'Le Valet impose une nouvelle couleur',
      steps: [
        InteractiveStep(
          instruction: 'Vous n\'avez que des ♥ mais la défausse est ♠...\n\nJouez le Valet pour changer la couleur !',
          discardCard: PlayingCard(suit: CardSuit.spades, value: CardValue.nine),
          playerHand: [
            PlayingCard(suit: CardSuit.hearts, value: CardValue.five),
            PlayingCard(suit: CardSuit.hearts, value: CardValue.king),
            PlayingCard(suit: CardSuit.clubs, value: CardValue.jack),
            PlayingCard(suit: CardSuit.hearts, value: CardValue.three),
          ],
          validCards: [PlayingCard(suit: CardSuit.clubs, value: CardValue.jack)],
          hint: 'Le Valet se joue sur tout et vous permet de choisir la couleur !',
          successMessage: 'Vous pouvez maintenant choisir ♥ comme nouvelle couleur !',
        ),
      ],
    ),

    // Leçon 8: Le Joker
    InteractiveLesson(
      title: 'Le Joker - Carte ultime',
      description: 'Le Joker inflige +4 cartes',
      steps: [
        InteractiveStep(
          instruction: 'L\'adversaire n\'a plus que 2 cartes !\n\nUtilisez le Joker pour lui en faire piocher 4 !',
          discardCard: PlayingCard(suit: CardSuit.diamonds, value: CardValue.king),
          playerHand: [
            PlayingCard(suit: CardSuit.hearts, value: CardValue.five),
            PlayingCard(suit: CardSuit.jokerRed, value: CardValue.joker),
            PlayingCard(suit: CardSuit.clubs, value: CardValue.three),
            PlayingCard(suit: CardSuit.spades, value: CardValue.eight),
          ],
          validCards: [PlayingCard(suit: CardSuit.jokerRed, value: CardValue.joker)],
          hint: 'Le Joker se joue à tout moment et inflige +4 !',
          successMessage: '+4 cartes pour l\'adversaire ! Il a maintenant 6 cartes.',
        ),
      ],
    ),

    // Leçon finale
    InteractiveLesson(
      title: 'Félicitations !',
      description: 'Vous maîtrisez les bases de Checkgames !',
      steps: [
        InteractiveStep(
          instruction: 'Bravo ! Vous avez terminé le tutoriel interactif.\n\n'
              'Vous connaissez maintenant :\n'
              '• Jouer par couleur ou valeur\n'
              '• Le 2 passe-partout\n'
              '• L\'As (passer le tour)\n'
              '• Le 7 (+2, cumulable)\n'
              '• Le Valet (changer couleur)\n'
              '• Le Joker (+4)\n\n'
              'Lancez une vraie partie !',
          discardCard: PlayingCard(suit: CardSuit.hearts, value: CardValue.ace),
          playerHand: [],
          validCards: [],
          isFinalStep: true,
        ),
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  InteractiveLesson get _currentLessonData => _lessons[_currentLesson];
  InteractiveStep get _currentStepData => _currentLessonData.steps[_currentStep];

  void _selectCard(PlayingCard card) {
    if (_showSuccess) return;

    setState(() {
      _selectedCard = card;
      _showHint = false;
    });

    // Vérifier si la carte est correcte
    final isValid = _currentStepData.validCards.any(
      (c) => c.suit == card.suit && c.value == card.value,
    );

    // Si targetCards est défini, vérifier si c'est la carte cible
    final isTarget = _currentStepData.targetCards?.any(
          (c) => c.suit == card.suit && c.value == card.value,
        ) ??
        isValid;

    if (isTarget) {
      AudioService.instance.playCardMove();
      setState(() {
        _showSuccess = true;
      });

      // Passer à l'étape suivante après un délai
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          _nextStep();
        }
      });
    } else if (isValid) {
      // Carte jouable mais pas optimale
      AudioService.instance.playCardMove();
      setState(() {
        _showSuccess = true;
      });
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          _nextStep();
        }
      });
    } else {
      // Mauvaise carte
      AudioService.instance.playButtonClick();
      _showWrongCardFeedback();
    }
  }

  void _showWrongCardFeedback() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.close, color: Colors.white),
            SizedBox(width: 8),
            Text('Cette carte ne peut pas être jouée ici'),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _nextStep() {
    setState(() {
      _showSuccess = false;
      _selectedCard = null;

      if (_currentStep < _currentLessonData.steps.length - 1) {
        _currentStep++;
      } else if (_currentLesson < _lessons.length - 1) {
        _currentLesson++;
        _currentStep = 0;
      } else {
        // Tutoriel terminé
        Navigator.of(context).pop();
      }
    });
  }

  void _showHintDialog() {
    setState(() {
      _showHint = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final step = _currentStepData;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFF6F00), Color(0xFFE65100)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              _buildHeader(),

              // Progression
              _buildProgressBar(),

              const SizedBox(height: 16),

              // Zone de jeu
              Expanded(
                child: step.isFinalStep
                    ? _buildFinalScreen()
                    : _buildGameArea(step),
              ),

              // Instructions
              _buildInstructionPanel(step),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              AudioService.instance.playButtonClick();
              _showExitConfirmation();
            },
            icon: const Icon(Icons.close, color: Colors.white),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  'Leçon ${_currentLesson + 1}/${_lessons.length}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
                Text(
                  _currentLessonData.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _showHintDialog,
            icon: const Icon(Icons.lightbulb_outline, color: Colors.amber),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    final totalSteps = _lessons.fold<int>(0, (sum, l) => sum + l.steps.length);
    final completedSteps = _lessons
            .take(_currentLesson)
            .fold<int>(0, (sum, l) => sum + l.steps.length) +
        _currentStep;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: completedSteps / totalSteps,
              backgroundColor: Colors.white.withOpacity(0.3),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${((completedSteps / totalSteps) * 100).round()}% complété',
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameArea(InteractiveStep step) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Zone adversaire (simplifié)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.person, color: Colors.white54, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Adversaire',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '3 cartes',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          // Défausse et cumul
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Défausse
              Column(
                children: [
                  const Text(
                    'Défausse',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _showSuccess ? 1.0 : _pulseAnimation.value,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withOpacity(0.3),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: SizedBox(
                            width: 70,
                            height: 98,
                            child: PlayingCardWidget(
                              card: step.discardCard,
                              onTap: () {},
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),

              // Indicateur de cumul si présent
              if (step.showCumul != null) ...[
                const SizedBox(width: 24),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.5),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'CUMUL',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '+${step.showCumul}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),

          const Spacer(),

          // Message de succès
          if (_showSuccess)
            Container(
              margin: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      step.successMessage ?? 'Correct !',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),

          // Indice
          if (_showHint && step.hint != null)
            Container(
              margin: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lightbulb, color: Colors.black87, size: 20),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      step.hint!,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Main du joueur
          const Text(
            'Votre main',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: step.playerHand.map((card) {
                final isSelected = _selectedCard != null &&
                    _selectedCard!.suit == card.suit &&
                    _selectedCard!.value == card.value;

                final isValidChoice = step.validCards.any(
                  (c) => c.suit == card.suit && c.value == card.value,
                );

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: GestureDetector(
                    onTap: () => _selectCard(card),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      transform: Matrix4.translationValues(
                        0,
                        isSelected ? -20 : 0,
                        0,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: Colors.green.withOpacity(0.8),
                                    blurRadius: 15,
                                    spreadRadius: 3,
                                  ),
                                ]
                              : null,
                        ),
                        child: SizedBox(
                          width: 55,
                          height: 77,
                          child: PlayingCardWidget(
                            card: card,
                            selected: isSelected,
                            onTap: () => _selectCard(card),
                          ),
                        ),
                      ),
                  ),
                ),
              );
              }).toList(),
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildInstructionPanel(InteractiveStep step) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Indicateur
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Instruction
          Text(
            step.instruction,
            style: const TextStyle(
              fontSize: 15,
              color: Colors.black87,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),

          if (!step.isFinalStep) ...[
            const SizedBox(height: 16),
            Text(
              'Sélectionnez la bonne carte',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],

          if (step.isFinalStep) ...[
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                AudioService.instance.playButtonClick();
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Jouer maintenant'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFinalScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.emoji_events,
              size: 60,
              color: Colors.amber,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Tutoriel terminé !',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _showExitConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Quitter le tutoriel ?'),
        content: const Text('Votre progression sera perdue.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Continuer'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Quitter'),
          ),
        ],
      ),
    );
  }
}

class InteractiveLesson {
  final String title;
  final String description;
  final List<InteractiveStep> steps;

  const InteractiveLesson({
    required this.title,
    required this.description,
    required this.steps,
  });
}

class InteractiveStep {
  final String instruction;
  final PlayingCard discardCard;
  final List<PlayingCard> playerHand;
  final List<PlayingCard> validCards;
  final List<PlayingCard>? targetCards; // Cartes idéales (optionnel)
  final String? hint;
  final String? successMessage;
  final int? showCumul;
  final bool isFinalStep;

  const InteractiveStep({
    required this.instruction,
    required this.discardCard,
    required this.playerHand,
    required this.validCards,
    this.targetCards,
    this.hint,
    this.successMessage,
    this.showCumul,
    this.isFinalStep = false,
  });
}
