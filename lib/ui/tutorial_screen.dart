import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../models/card_suit.dart';
import '../models/card_value.dart';
import '../models/playing_card.dart';
import '../view/widgets/playing_card_widget.dart';

class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<TutorialPage> _pages = [
    // Page 1: Bienvenue
    TutorialPage(
      title: 'Bienvenue !',
      subtitle: 'Apprenez à jouer à Checkgames',
      description: 'Un jeu de cartes stratégique où l\'objectif est de vous débarrasser de toutes vos cartes avant vos adversaires.\n\nCe tutoriel vous guidera à travers toutes les règles du jeu.',
      icon: Icons.waving_hand,
      iconColor: Colors.amber,
      backgroundColor: const Color(0xFF1565C0),
    ),
    // Page 2: Objectif
    TutorialPage(
      title: 'Objectif',
      subtitle: 'Soyez le premier !',
      description: 'Le but est simple : être le premier joueur à poser toutes ses cartes.\n\n• Chaque joueur commence avec 5 cartes\n• Le jeu se joue dans le sens horaire\n• Le premier à vider sa main gagne !',
      icon: Icons.emoji_events,
      iconColor: Colors.amber,
      backgroundColor: const Color(0xFF2E7D32),
    ),
    // Page 3: Règle de base - Couleur
    TutorialPage(
      title: 'Règle de base',
      subtitle: 'Jouer par couleur',
      description: 'Vous pouvez jouer une carte de la MÊME COULEUR (même symbole) que la carte sur la défausse.\n\nExemple : Sur un 5 de ♥, vous pouvez jouer n\'importe quel ♥ (cœur).',
      icon: Icons.favorite,
      iconColor: Colors.red,
      backgroundColor: const Color(0xFF6A1B9A),
      showColorExample: true,
    ),
    // Page 4: Règle de base - Valeur
    TutorialPage(
      title: 'Règle de base',
      subtitle: 'Jouer par valeur',
      description: 'Vous pouvez aussi jouer une carte de la MÊME VALEUR (même numéro) que la carte sur la défausse.\n\nExemple : Sur un 5 de ♥, vous pouvez jouer un 5 de n\'importe quelle couleur.',
      icon: Icons.looks_5,
      iconColor: Colors.blue,
      backgroundColor: const Color(0xFF1976D2),
      showValueExample: true,
    ),
    // Page 5: Piocher
    TutorialPage(
      title: 'Piocher',
      subtitle: 'Quand vous ne pouvez pas jouer',
      description: 'Si vous n\'avez aucune carte jouable :\n\n• Appuyez sur la pioche pour prendre une carte\n• Votre tour se termine automatiquement\n• Le joueur suivant joue\n\nAstuce : Parfois il vaut mieux piocher que jouer une carte spéciale !',
      icon: Icons.add_card,
      iconColor: Colors.white,
      backgroundColor: const Color(0xFF455A64),
    ),
    // Page 6: Le 2 - Passe-partout
    TutorialPage(
      title: 'Carte Spéciale',
      subtitle: 'Le 2 - Passe-partout',
      description: 'Le 2 est une carte magique !\n\n• Il peut être joué sur N\'IMPORTE QUELLE carte\n• Peu importe la couleur ou la valeur\n• Très utile pour se débloquer\n• Gardez-le pour les moments difficiles !',
      icon: Icons.all_inclusive,
      iconColor: Colors.cyan,
      backgroundColor: const Color(0xFF00796B),
      specialCard: const PlayingCard(suit: CardSuit.clubs, value: CardValue.two),
      specialCardEffect: '→ Se joue sur tout !',
    ),
    // Page 7: Cartes spéciales - As
    TutorialPage(
      title: 'Carte Spéciale',
      subtitle: 'L\'As - Passer le tour',
      description: 'Jouez un As pour faire passer le tour du joueur suivant.\n\n• Le joueur suivant ne joue pas\n• Il devra attendre le prochain tour\n• Utile pour bloquer un adversaire proche de gagner !',
      icon: Icons.skip_next,
      iconColor: Colors.red,
      backgroundColor: const Color(0xFFD84315),
      specialCard: const PlayingCard(suit: CardSuit.spades, value: CardValue.ace),
      specialCardEffect: '→ Le suivant passe son tour',
    ),
    // Page 8: Cartes spéciales - 7
    TutorialPage(
      title: 'Carte Spéciale',
      subtitle: 'Le 7 - Pioche +2',
      description: 'Le 7 oblige le joueur suivant à piocher 2 cartes !\n\n• Le joueur suivant doit prendre 2 cartes\n• Il ne peut pas jouer ce tour\n• Sauf s\'il a aussi un 7... (voir page suivante)',
      icon: Icons.add_circle,
      iconColor: Colors.blue,
      backgroundColor: const Color(0xFF00838F),
      specialCard: const PlayingCard(suit: CardSuit.hearts, value: CardValue.seven),
      specialCardEffect: '→ +2 cartes pour le suivant',
    ),
    // Page 9: Cumul des 7
    TutorialPage(
      title: 'Le Cumul',
      subtitle: 'Enchaîner les 7 !',
      description: 'Si on vous oblige à piocher avec un 7, vous pouvez vous défendre en jouant aussi un 7 !\n\n• Le cumul passe au joueur suivant\n• Les cartes s\'additionnent : 2+2 = 4\n• Exemple : 7 → 7 → 7 = +6 cartes !\n\nLe dernier qui ne peut pas jouer de 7 pioche TOUT le cumul.',
      icon: Icons.stacked_line_chart,
      iconColor: Colors.orange,
      backgroundColor: const Color(0xFFEF6C00),
      showCumulExample: true,
    ),
    // Page 10: Cartes spéciales - Valet
    TutorialPage(
      title: 'Carte Spéciale',
      subtitle: 'Le Valet - Changement de couleur',
      description: 'Le Valet est très puissant !\n\n• Se joue sur N\'IMPORTE QUELLE carte\n• Vous choisissez la nouvelle couleur\n• Le joueur suivant DOIT jouer cette couleur\n• Parfait pour bloquer vos adversaires !',
      icon: Icons.palette,
      iconColor: Colors.purple,
      backgroundColor: const Color(0xFF4527A0),
      specialCard: const PlayingCard(suit: CardSuit.diamonds, value: CardValue.jack),
      specialCardEffect: '→ Choisissez la couleur',
    ),
    // Page 11: Cartes spéciales - Joker
    TutorialPage(
      title: 'Carte Spéciale',
      subtitle: 'Le Joker - Carte ultime',
      description: 'Le Joker est la carte la plus puissante !\n\n• Se joue à TOUT moment\n• Force le suivant à piocher 4 cartes\n• Peut se cumuler avec les 7 !\n• Seulement 2 Jokers dans le jeu\n\nUtilisez-le stratégiquement !',
      icon: Icons.auto_awesome,
      iconColor: Colors.amber,
      backgroundColor: const Color(0xFFC62828),
      specialCard: const PlayingCard(suit: CardSuit.jokerRed, value: CardValue.joker),
      specialCardEffect: '→ +4 cartes (cumulable)',
    ),
    // Page 12: Cumul Joker + 7
    TutorialPage(
      title: 'Cumul Avancé',
      subtitle: 'Joker + 7 = Combo !',
      description: 'Les Jokers et les 7 peuvent se cumuler ensemble !\n\n• Joker (+4) → 7 (+2) = +6 cartes\n• 7 (+2) → Joker (+4) = +6 cartes\n• Joker → 7 → 7 → Joker = +12 !\n\nLe dernier joueur sans défense pioche tout.',
      icon: Icons.bolt,
      iconColor: Colors.yellow,
      backgroundColor: const Color(0xFF8E24AA),
      showAdvancedCumulExample: true,
    ),
    // Page 13: Jouer plusieurs cartes
    TutorialPage(
      title: 'Astuce',
      subtitle: 'Jouer plusieurs cartes',
      description: 'Vous pouvez jouer PLUSIEURS cartes identiques en même temps !\n\n• Sélectionnez toutes les cartes de même valeur\n• Jouez-les en un seul coup\n• Exemple : trois 5 d\'un coup !\n\nCela vous permet de vous débarrasser de vos cartes plus vite.',
      icon: Icons.layers,
      iconColor: Colors.green,
      backgroundColor: const Color(0xFF388E3C),
      showMultipleCardsExample: true,
    ),
    // Page 14: CHECKS
    TutorialPage(
      title: 'CHECKS !',
      subtitle: 'Dernière carte',
      description: 'Quand il ne vous reste qu\'UNE SEULE carte :\n\n• "CHECKS" s\'affiche automatiquement\n• Vos adversaires sont avertis\n• Ils vont essayer de vous bloquer !\n\nPréparez bien votre dernière carte pour gagner.',
      icon: Icons.notifications_active,
      iconColor: Colors.amber,
      backgroundColor: const Color(0xFFE65100),
      showChecksAnimation: true,
    ),
    // Page 15: Conseils
    TutorialPage(
      title: 'Conseils',
      subtitle: 'Stratégies gagnantes',
      description: '• Gardez vos cartes spéciales pour les moments critiques\n\n• Observez les cartes jouées par vos adversaires\n\n• Comptez les 7 et Jokers déjà joués\n\n• Bloquez les joueurs proches de gagner\n\n• Le 2 peut vous sauver !',
      icon: Icons.lightbulb,
      iconColor: Colors.amber,
      backgroundColor: const Color(0xFF558B2F),
    ),
    // Page 16: Récapitulatif
    TutorialPage(
      title: 'Récapitulatif',
      subtitle: 'Les cartes spéciales',
      description: '• 2 → Se joue sur tout\n• 7 → +2 cartes (cumulable)\n• Valet → Change la couleur\n• As → Passe le tour suivant\n• Joker → +4 cartes (cumulable)\n\nLes 7 et Jokers se cumulent entre eux !',
      icon: Icons.list_alt,
      iconColor: Colors.white,
      backgroundColor: const Color(0xFF37474F),
    ),
    // Page 17: Prêt
    TutorialPage(
      title: 'Prêt à jouer !',
      subtitle: 'Bonne chance !',
      description: 'Vous connaissez maintenant toutes les règles de Checkgames !\n\nLancez une partie solo pour vous entraîner, ou affrontez des joueurs en ligne.\n\nQue le meilleur gagne !',
      icon: Icons.rocket_launch,
      iconColor: Colors.white,
      backgroundColor: const Color(0xFF00695C),
      isLastPage: true,
    ),
  ];

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      AudioService.instance.playButtonClick();
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _finishTutorial();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      AudioService.instance.playButtonClick();
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  void _finishTutorial() {
    AudioService.instance.playButtonClick();
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Pages
          PageView.builder(
            controller: _pageController,
            itemCount: _pages.length,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemBuilder: (context, index) {
              return _buildPage(_pages[index]);
            },
          ),

          // Header avec bouton passer
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Bouton retour
                  if (_currentPage > 0)
                    IconButton(
                      onPressed: _previousPage,
                      icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                    )
                  else
                    const SizedBox(width: 48),

                  // Indicateur de page
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_currentPage + 1} / ${_pages.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  // Bouton passer
                  TextButton(
                    onPressed: _finishTutorial,
                    child: const Text(
                      'Passer',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Footer avec navigation
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Indicateurs de page (dots)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _pages.length,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: _currentPage == index ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _currentPage == index
                                ? Colors.white
                                : Colors.white38,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Bouton suivant / commencer
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _nextPage,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: _pages[_currentPage].backgroundColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 4,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _pages[_currentPage].isLastPage
                                  ? 'Commencer à jouer'
                                  : 'Suivant',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              _pages[_currentPage].isLastPage
                                  ? Icons.play_arrow
                                  : Icons.arrow_forward,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(TutorialPage page) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            page.backgroundColor,
            page.backgroundColor.withOpacity(0.7),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 80, 24, 140),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icône principale avec animation
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.8, end: 1.0),
                duration: const Duration(milliseconds: 600),
                curve: Curves.elasticOut,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: page.iconColor.withOpacity(0.3),
                            blurRadius: 30,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                      child: Icon(
                        page.icon,
                        size: 60,
                        color: page.iconColor,
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 32),

              // Titre
              Text(
                page.title,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              // Sous-titre
              Text(
                page.subtitle,
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.white.withOpacity(0.8),
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              // Carte spéciale si présente
              if (page.specialCard != null) ...[
                _buildSpecialCardDisplay(page),
                const SizedBox(height: 24),
              ],

              // Exemple de base si présent
              if (page.showBasicExample) ...[
                _buildBasicExample(),
                const SizedBox(height: 24),
              ],

              // Exemple couleur si présent
              if (page.showColorExample) ...[
                _buildColorExample(),
                const SizedBox(height: 24),
              ],

              // Exemple valeur si présent
              if (page.showValueExample) ...[
                _buildValueExample(),
                const SizedBox(height: 24),
              ],

              // Exemple cumul si présent
              if (page.showCumulExample) ...[
                _buildCumulExample(),
                const SizedBox(height: 24),
              ],

              // Exemple cumul avancé si présent
              if (page.showAdvancedCumulExample) ...[
                _buildAdvancedCumulExample(),
                const SizedBox(height: 24),
              ],

              // Exemple cartes multiples si présent
              if (page.showMultipleCardsExample) ...[
                _buildMultipleCardsExample(),
                const SizedBox(height: 24),
              ],

              // Animation CHECKS si présente
              if (page.showChecksAnimation) ...[
                _buildChecksAnimation(),
                const SizedBox(height: 24),
              ],

              // Description
              Expanded(
                child: SingleChildScrollView(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      page.description,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        height: 1.6,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpecialCardDisplay(TutorialPage page) {
    return Column(
      children: [
        // Carte
        SizedBox(
          width: 80,
          height: 112,
          child: PlayingCardWidget(
            card: page.specialCard!,
            onTap: () {},
          ),
        ),
        const SizedBox(height: 12),
        // Effet
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            page.specialCardEffect!,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBasicExample() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Carte sur la défausse
        Column(
          children: [
            const Text(
              'Défausse',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: 60,
              height: 84,
              child: PlayingCardWidget(
                card: const PlayingCard(suit: CardSuit.hearts, value: CardValue.five),
                onTap: () {},
              ),
            ),
          ],
        ),
        const SizedBox(width: 16),
        const Icon(Icons.arrow_forward, color: Colors.white54),
        const SizedBox(width: 16),
        // Cartes jouables
        Column(
          children: [
            const Text(
              'Vous pouvez jouer',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                SizedBox(
                  width: 50,
                  height: 70,
                  child: PlayingCardWidget(
                    card: const PlayingCard(suit: CardSuit.hearts, value: CardValue.king),
                    onTap: () {},
                  ),
                ),
                const SizedBox(width: 4),
                SizedBox(
                  width: 50,
                  height: 70,
                  child: PlayingCardWidget(
                    card: const PlayingCard(suit: CardSuit.spades, value: CardValue.five),
                    onTap: () {},
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildColorExample() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Carte sur la défausse
        Column(
          children: [
            const Text(
              'Sur la défausse',
              style: TextStyle(color: Colors.white70, fontSize: 11),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: 55,
              height: 77,
              child: PlayingCardWidget(
                card: const PlayingCard(suit: CardSuit.hearts, value: CardValue.five),
                onTap: () {},
              ),
            ),
          ],
        ),
        const SizedBox(width: 12),
        const Icon(Icons.arrow_forward, color: Colors.white54, size: 20),
        const SizedBox(width: 12),
        // Cartes de même couleur
        Column(
          children: [
            const Text(
              'Même couleur ♥',
              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                SizedBox(
                  width: 45,
                  height: 63,
                  child: PlayingCardWidget(
                    card: const PlayingCard(suit: CardSuit.hearts, value: CardValue.king),
                    onTap: () {},
                  ),
                ),
                const SizedBox(width: 3),
                SizedBox(
                  width: 45,
                  height: 63,
                  child: PlayingCardWidget(
                    card: const PlayingCard(suit: CardSuit.hearts, value: CardValue.three),
                    onTap: () {},
                  ),
                ),
                const SizedBox(width: 3),
                SizedBox(
                  width: 45,
                  height: 63,
                  child: PlayingCardWidget(
                    card: const PlayingCard(suit: CardSuit.hearts, value: CardValue.nine),
                    onTap: () {},
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildValueExample() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Carte sur la défausse
        Column(
          children: [
            const Text(
              'Sur la défausse',
              style: TextStyle(color: Colors.white70, fontSize: 11),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: 55,
              height: 77,
              child: PlayingCardWidget(
                card: const PlayingCard(suit: CardSuit.hearts, value: CardValue.five),
                onTap: () {},
              ),
            ),
          ],
        ),
        const SizedBox(width: 12),
        const Icon(Icons.arrow_forward, color: Colors.white54, size: 20),
        const SizedBox(width: 12),
        // Cartes de même valeur
        Column(
          children: [
            const Text(
              'Même valeur (5)',
              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                SizedBox(
                  width: 45,
                  height: 63,
                  child: PlayingCardWidget(
                    card: const PlayingCard(suit: CardSuit.spades, value: CardValue.five),
                    onTap: () {},
                  ),
                ),
                const SizedBox(width: 3),
                SizedBox(
                  width: 45,
                  height: 63,
                  child: PlayingCardWidget(
                    card: const PlayingCard(suit: CardSuit.diamonds, value: CardValue.five),
                    onTap: () {},
                  ),
                ),
                const SizedBox(width: 3),
                SizedBox(
                  width: 45,
                  height: 63,
                  child: PlayingCardWidget(
                    card: const PlayingCard(suit: CardSuit.clubs, value: CardValue.five),
                    onTap: () {},
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCumulExample() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Premier 7
            Column(
              children: [
                const Text('Joueur 1', style: TextStyle(color: Colors.white70, fontSize: 10)),
                const SizedBox(height: 2),
                SizedBox(
                  width: 45,
                  height: 63,
                  child: PlayingCardWidget(
                    card: const PlayingCard(suit: CardSuit.hearts, value: CardValue.seven),
                    onTap: () {},
                  ),
                ),
                const Text('+2', style: TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.arrow_forward, color: Colors.white54, size: 16),
            ),
            // Deuxième 7
            Column(
              children: [
                const Text('Joueur 2', style: TextStyle(color: Colors.white70, fontSize: 10)),
                const SizedBox(height: 2),
                SizedBox(
                  width: 45,
                  height: 63,
                  child: PlayingCardWidget(
                    card: const PlayingCard(suit: CardSuit.spades, value: CardValue.seven),
                    onTap: () {},
                  ),
                ),
                const Text('+2', style: TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.arrow_forward, color: Colors.white54, size: 16),
            ),
            // Troisième 7
            Column(
              children: [
                const Text('Joueur 3', style: TextStyle(color: Colors.white70, fontSize: 10)),
                const SizedBox(height: 2),
                SizedBox(
                  width: 45,
                  height: 63,
                  child: PlayingCardWidget(
                    card: const PlayingCard(suit: CardSuit.diamonds, value: CardValue.seven),
                    onTap: () {},
                  ),
                ),
                const Text('+2', style: TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.arrow_forward, color: Colors.red, size: 16),
            ),
            // Résultat
            Column(
              children: [
                const Text('Joueur 4', style: TextStyle(color: Colors.white70, fontSize: 10)),
                const SizedBox(height: 2),
                Container(
                  width: 45,
                  height: 63,
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red, width: 2),
                  ),
                  child: const Center(
                    child: Icon(Icons.download, color: Colors.white, size: 24),
                  ),
                ),
                const Text('+6 !', style: TextStyle(color: Colors.red, fontSize: 14, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAdvancedCumulExample() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Joker
            Column(
              children: [
                SizedBox(
                  width: 42,
                  height: 59,
                  child: PlayingCardWidget(
                    card: const PlayingCard(suit: CardSuit.jokerRed, value: CardValue.joker),
                    onTap: () {},
                  ),
                ),
                const Text('+4', style: TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Icon(Icons.add, color: Colors.white54, size: 14),
            ),
            // 7
            Column(
              children: [
                SizedBox(
                  width: 42,
                  height: 59,
                  child: PlayingCardWidget(
                    card: const PlayingCard(suit: CardSuit.hearts, value: CardValue.seven),
                    onTap: () {},
                  ),
                ),
                const Text('+2', style: TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Icon(Icons.add, color: Colors.white54, size: 14),
            ),
            // 7
            Column(
              children: [
                SizedBox(
                  width: 42,
                  height: 59,
                  child: PlayingCardWidget(
                    card: const PlayingCard(suit: CardSuit.spades, value: CardValue.seven),
                    onTap: () {},
                  ),
                ),
                const Text('+2', style: TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Icon(Icons.add, color: Colors.white54, size: 14),
            ),
            // Joker
            Column(
              children: [
                SizedBox(
                  width: 42,
                  height: 59,
                  child: PlayingCardWidget(
                    card: const PlayingCard(suit: CardSuit.jokerBlack, value: CardValue.joker),
                    onTap: () {},
                  ),
                ),
                const Text('+4', style: TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Text('=', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            ),
            // Total
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.5),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Text(
                '+12 !',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMultipleCardsExample() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Cartes identiques
        Column(
          children: [
            const Text(
              'Sélectionnez plusieurs 5',
              style: TextStyle(color: Colors.white70, fontSize: 11),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                SizedBox(
                  width: 45,
                  height: 63,
                  child: PlayingCardWidget(
                    card: const PlayingCard(suit: CardSuit.hearts, value: CardValue.five),
                    selected: true,
                    onTap: () {},
                  ),
                ),
                const SizedBox(width: 3),
                SizedBox(
                  width: 45,
                  height: 63,
                  child: PlayingCardWidget(
                    card: const PlayingCard(suit: CardSuit.spades, value: CardValue.five),
                    selected: true,
                    onTap: () {},
                  ),
                ),
                const SizedBox(width: 3),
                SizedBox(
                  width: 45,
                  height: 63,
                  child: PlayingCardWidget(
                    card: const PlayingCard(suit: CardSuit.diamonds, value: CardValue.five),
                    selected: true,
                    onTap: () {},
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(width: 12),
        const Icon(Icons.arrow_forward, color: Colors.white54, size: 20),
        const SizedBox(width: 12),
        // Résultat
        Column(
          children: [
            const Text(
              'Jouez-les d\'un coup !',
              style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green, width: 2),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.flash_on, color: Colors.green, size: 20),
                  SizedBox(width: 4),
                  Text(
                    '-3 cartes',
                    style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildChecksAnimation() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.9, end: 1.1),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.amber.shade600, Colors.orange.shade700],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withOpacity(0.5),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const Text(
              'CHECKS !',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 4,
                shadows: [
                  Shadow(
                    blurRadius: 10,
                    color: Colors.black38,
                    offset: Offset(2, 2),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class TutorialPage {
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final PlayingCard? specialCard;
  final String? specialCardEffect;
  final bool showBasicExample;
  final bool showColorExample;
  final bool showValueExample;
  final bool showCumulExample;
  final bool showAdvancedCumulExample;
  final bool showMultipleCardsExample;
  final bool showChecksAnimation;
  final bool isLastPage;

  const TutorialPage({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    this.specialCard,
    this.specialCardEffect,
    this.showBasicExample = false,
    this.showColorExample = false,
    this.showValueExample = false,
    this.showCumulExample = false,
    this.showAdvancedCumulExample = false,
    this.showMultipleCardsExample = false,
    this.showChecksAnimation = false,
    this.isLastPage = false,
  });
}
