import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../Bloc/checkgames_state.dart';
import '../Bloc/checkgames_event.dart';
import '../models/playing_card.dart';
import '../models/player_card.dart';
import '../models/card_value.dart';
import '../models/card_suit.dart';
import '../utils/responsive_sizing.dart';
import '../view/widgets/table_widgets.dart';
import '../view/widgets/playing_card_widget.dart';
import '../view/widgets/suit_picker_sheet.dart';
import '../view/widgets/game_over_sheet.dart';
import '../view/widgets/checks_overlay.dart';
import '../view/widgets/hand_fan_widget.dart';
import '../view/widgets/animated_card_overlay.dart';
import '../view/widgets/error_message_overlay.dart';
import '../view/widgets/pause_menu.dart';
import '../services/card_animation_service.dart';
import '../services/audio_service.dart';
import '../services/game_master_service.dart';
import '../services/firebase_room_service.dart';
import '../services/game_settings_service.dart';

class GamePage extends StatefulWidget {
  /// ID du joueur actuel (utilisé en mode multijoueur pour identifier le joueur)
  /// Si null, on assume le mode solo où le joueur humain est toujours à l'index 0
  final String? playerId;

  /// ID de la room (multijoueur uniquement)
  final String? roomId;

  /// ID de l'hôte (multijoueur uniquement)
  final String? hostId;

  const GamePage({
    super.key,
    this.playerId,
    this.roomId,
    this.hostId,
  });

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  final Set<PlayingCard> _selected = {};
  final GlobalKey _discardKey = GlobalKey();
  final Map<PlayingCard, GlobalKey> _cardKeys = {};
  final Map<String, GlobalKey> _botCardKeys = {}; // Keys pour les positions des bots
  bool _gameOverSheetShown = false;
  String? _lastChecksPlayerIdShown; // Pour ne pas afficher "CHECKS" plusieurs fois pour le même joueur
  int? _lastDiscardPileLength; // Pour détecter quand une carte est jouée
  int? _previousPlayerIndex; // Index du joueur précédent
  bool _skipNextBotAnimation = false; // Pour éviter l'animation après que le joueur humain a joué
  bool _isShowingChecks = false; // Flag pour bloquer le jeu pendant l'affichage de CHECKS
  final GlobalKey _deckKey = GlobalKey(); // Key pour la position de la pioche
  Map<String, int> _playerHandSizes = {}; // Pour détecter quand un joueur pioche

  @override
  void initState() {
    super.initState();
    // Démarrer la musique de fond au lancement du jeu
    AudioService.instance.startBackgroundMusic();
  }

  @override
  void dispose() {
    // Arrêter la musique quand on quitte la page
    AudioService.instance.stopBackgroundMusic();
    super.dispose();
  }

  void _showChecksOverlay(String playerName) {
    if (!mounted) return;

    // Jouer le son CHECKS
    AudioService.instance.playChecks();

    // Capturer le BLoC avant de créer l'overlay
    final bloc = context.read<Bloc<CheckgamesEvent, CheckgamesState>>();

    // Bloquer le jeu pendant l'affichage
    setState(() {
      _isShowingChecks = true;
    });
    bloc.add(const SetPaused(true));

    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => Material(
        color: Colors.black.withOpacity(0.3),
        child: Center(
          child: ChecksOverlay(
            playerName: playerName,
            onComplete: () {
              if (mounted) {
                overlayEntry.remove();
                // Débloquer le jeu après l'animation
                setState(() {
                  _isShowingChecks = false;
                });
                bloc.add(const SetPaused(false));
              }
            },
          ),
        ),
      ),
    );

    Overlay.of(context).insert(overlayEntry);
  }

  void _showPauseMenu() {
    if (!mounted) return;

    // Capturer le BLoC avant de créer l'overlay
    final bloc = context.read<Bloc<CheckgamesEvent, CheckgamesState>>();

    // Mettre le jeu en pause
    bloc.add(const SetPaused(true));

    // Déterminer si c'est une partie multijoueur et si on est l'hôte
    final isMultiplayer = widget.roomId != null;
    final isHost = widget.playerId != null && widget.playerId == widget.hostId;

    print('🔍 GamePage - isMultiplayer: $isMultiplayer, isHost: $isHost');
    print('🔍 GamePage - roomId: ${widget.roomId}, playerId: ${widget.playerId}, hostId: ${widget.hostId}');

    // Capturer le ScaffoldMessenger AVANT de créer l'overlay
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final roomId = widget.roomId;

    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (overlayContext) => PauseMenu(
        onResume: () {
          if (mounted) {
            overlayEntry.remove();
            bloc.add(const SetPaused(false));
          }
        },
        onQuit: () {
          if (mounted) {
            overlayEntry.remove();
            bloc.add(RestartGame(keepPlayers: true));
          }
        },
        onRestart: isMultiplayer && isHost && roomId != null
            ? () async {
                print('🔍 Callback onRestart appelé');
                if (mounted) {
                  // Fermer le menu pause d'abord
                  print('🔍 Fermeture du menu pause');
                  try {
                    overlayEntry.remove();
                  } catch (e) {
                    print('⚠️ Erreur lors de la suppression de l\'overlay: $e');
                  }
                  bloc.add(const SetPaused(false));

                  try {
                    // Afficher un indicateur de chargement
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(
                        content: Text('Relance de la partie...'),
                        duration: Duration(seconds: 2),
                      ),
                    );

                    // Relancer via GameMasterService
                    print('🔍 Appel de GameMasterService.restartGame pour roomId: $roomId');
                    final gameMaster = GameMasterService();
                    await gameMaster.restartGame(roomId);

                    print('✅ Partie relancée avec succès');
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(
                        content: Text('✅ Partie relancée !'),
                        duration: Duration(seconds: 2),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } catch (e) {
                    print('❌ Erreur lors de la relance: $e');
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: Text('Erreur lors de la relance: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } else {
                  print('⚠️ Widget non monté');
                }
              }
            : null,
        onLeaveGame: isMultiplayer && roomId != null && widget.playerId != null
            ? () async {
                print('🚪 Demande de sortie de partie');
                try {
                  // Appeler le service Firebase pour quitter la partie
                  final roomService = FirebaseRoomService();
                  await roomService.leaveActiveGame(roomId, widget.playerId!);

                  print('✅ Sortie de partie réussie');

                  // Retourner au menu principal
                  if (mounted) {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  }
                } catch (e) {
                  print('❌ Erreur lors de la sortie: $e');
                  if (mounted) {
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: Text('Erreur lors de la sortie: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              }
            : null,
        isMultiplayer: isMultiplayer,
        isHost: isHost,
      ),
    );

    Overlay.of(context).insert(overlayEntry);
  }

  void _showErrorMessage(String message) {
    if (!mounted) return;

    // Vibration légère pour signaler l'erreur (si activée dans les paramètres)
    if (GameSettingsService.instance.vibrationEnabled) {
      HapticFeedback.mediumImpact();
    }

    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => ErrorMessageOverlay(
        message: message,
        onComplete: () {
          if (mounted) {
            overlayEntry.remove();
          }
        },
      ),
    );

    Overlay.of(context).insert(overlayEntry);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<Bloc<CheckgamesEvent, CheckgamesState>, CheckgamesState>(
      listener: (context, state) {
        // Détecter quand une carte est jouée
        if (state.players.isNotEmpty && state.discardPile.isNotEmpty) {
          final currentDiscardLength = state.discardPile.length;

          // Si la défausse a augmenté, quelqu'un a joué
          if (_lastDiscardPileLength != null && currentDiscardLength > _lastDiscardPileLength!) {

            // Si on doit skip (le joueur humain vient de jouer avec son animation)
            if (_skipNextBotAnimation) {
              _skipNextBotAnimation = false;
            } else {
              // Calculer qui a joué : c'est le joueur PRÉCÉDENT (avant le changement de tour)
              // On utilise _previousPlayerIndex qui a été sauvegardé avant le changement
              if (_previousPlayerIndex != null && _previousPlayerIndex! > 0) {
                final playerId = state.players[_previousPlayerIndex!].id;
                final cardPlayed = state.discardPile.last;

                // Délai pour laisser le state se stabiliser
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _animateBotCard(playerId, cardPlayed);
                });
              }
            }
          }

          _lastDiscardPileLength = currentDiscardLength;
          _previousPlayerIndex = state.currentPlayerIndex;
        }

        // Détecter quand un joueur pioche des cartes
        for (final player in state.players) {
          final previousSize = _playerHandSizes[player.id] ?? 0;
          final currentSize = player.hand.length;

          if (currentSize > previousSize) {
            // Le joueur a pioché des cartes
            final cardsDraw = currentSize - previousSize;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _animateDrawCards(player.id, cardsDraw);
            });
          }

          _playerHandSizes[player.id] = currentSize;
        }
      },
      child: BlocBuilder<Bloc<CheckgamesEvent, CheckgamesState>, CheckgamesState>(
        builder: (context, state) {
        // Déclencher GameOverSheet quand partie terminée (une seule fois)
        if (state.isGameOver && state.phase == GamePhase.finished && !_gameOverSheetShown) {
          _gameOverSheetShown = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            showModalBottomSheet(
              context: context,
              isDismissible: false,
              enableDrag: false,
              builder: (_) => GameOverSheet(
                finishingOrder: state.finishingOrder,
                allPlayers: state.players,
                isMultiplayer: widget.playerId != null,
                isHost: widget.playerId == widget.hostId,
                roomId: widget.roomId,
                onRestart: () async {
                  if (widget.playerId != null && widget.playerId == widget.hostId && widget.roomId != null) {
                    // Multijoueur + Hôte : Relancer la partie
                    Navigator.pop(context); // Fermer le sheet
                    try {
                      final gameMaster = GameMasterService();
                      await gameMaster.restartGame(widget.roomId!);
                      _gameOverSheetShown = false; // Reset pour pouvoir afficher à nouveau
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('✅ Partie relancée !')),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('❌ Erreur: $e')),
                      );
                    }
                  } else if (widget.playerId != null) {
                    // Multijoueur + Non-hôte : Retour au menu
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  } else {
                    // Solo : redémarrer la partie
                    Navigator.pop(context);
                    _gameOverSheetShown = false;
                    context.read<Bloc<CheckgamesEvent, CheckgamesState>>().add(RestartGame(keepPlayers: true));
                  }
                },
              ),
            );
          });
        }

        // Réinitialiser le flag si la partie redémarre
        if (!state.isGameOver && _gameOverSheetShown) {
          _gameOverSheetShown = false;
        }

        // Afficher "CHECKS!" quand un joueur n'a plus qu'une carte
        if (state.lastChecksPlayerId != null &&
            state.lastChecksPlayerId != _lastChecksPlayerIdShown &&
            !state.isGameOver) {
          _lastChecksPlayerIdShown = state.lastChecksPlayerId;

          final checksPlayer = state.players.firstWhere(
            (p) => p.id == state.lastChecksPlayerId,
            orElse: () => state.players.first,
          );

          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showChecksOverlay(checksPlayer.name);
          });
        }

        // Réinitialiser le tracker si le joueur a pioché (plus de 2 cartes)
        if (state.lastChecksPlayerId != null && _lastChecksPlayerIdShown != null) {
          final player = state.players.firstWhere(
            (p) => p.id == _lastChecksPlayerIdShown,
            orElse: () => state.players.first,
          );
          if (player.hand.length > 2) {
            _lastChecksPlayerIdShown = null;
          }
        }

        // Afficher le message d'erreur si présent
        if (state.errorMessage != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showErrorMessage(state.errorMessage!);
          });
        }

        if (state.players.isEmpty) {
          return Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => context.read<Bloc<CheckgamesEvent, CheckgamesState>>().add(StartGame(['Vous','Bot 1','Bot 2'])),
                child: const Text('Démarrer'),
              ),
            ),
          );
        }

        // Calculer l'index du joueur actuel
        // - En mode solo (playerId == null): le joueur humain est toujours à l'index 0
        // - En mode multijoueur (playerId != null): trouver l'index du joueur par son ID
        final meIndex = widget.playerId == null
            ? 0
            : state.players.indexWhere((p) => p.id == widget.playerId);

        // Vérifier que le joueur existe dans la liste
        if (meIndex == -1) {
          return const Scaffold(
            body: Center(
              child: Text('Erreur: Joueur introuvable'),
            ),
          );
        }

        final me = state.players[meIndex];
        final isMyTurn = state.currentPlayerIndex == meIndex && !_isShowingChecks; // Bloqué pendant CHECKS

        // Nettoyer les keys des cartes qui ne sont plus dans la main
        _cardKeys.removeWhere((card, key) => !me.hand.contains(card));

        // Créer des GlobalKeys pour chaque bot
        for (final player in state.players) {
          if (player.id != me.id && !_botCardKeys.containsKey(player.id)) {
            _botCardKeys[player.id] = GlobalKey();
          }
        }

        Future<void> onPlay() async {
          if (!isMyTurn || _selected.isEmpty) return;
          final cards = _selected.toList();
          final first = cards.first;

          // 1. Gestion Valet (inchangé)
          CardSuit? imposed;
          if (first.value == CardValue.jack) {
            imposed = await showModalBottomSheet<CardSuit>(
              context: context,
              builder: (_) => const SuitPickerSheet(),
            );
            if (imposed == null) return;
          }

          // 2. Collecter les GlobalKeys des cartes sélectionnées
          final cardKeys = cards
              .map((card) => _cardKeys[card])
              .whereType<GlobalKey>()
              .toList();

          // 3. Vérifier que toutes les keys sont disponibles
          final canAnimate = cardKeys.length == cards.length &&
                             _discardKey.currentContext != null;

          // 4. ANIMATION (si possible)
          if (canAnimate && mounted) {
            await CardAnimationService.instance.animateCardsToDiscard(
              context: context,
              cards: cards,
              cardKeys: cardKeys,
              discardKey: _discardKey,
            );
          }

          // 5. APRES animation → Mise à jour BLoC
          if (!mounted) return; // Safety check

          // Marquer qu'on doit skip la prochaine animation de bot car le joueur humain a joué
          _skipNextBotAnimation = true;

          context.read<Bloc<CheckgamesEvent, CheckgamesState>>().add(
            PlayCard(playerId: me.id, cards: cards, imposedSuit: imposed),
          );
          setState(_selected.clear);
        }

        void onDeckTapOrDraw() {
          if (!isMyTurn) return;
          final bloc = context.read<Bloc<CheckgamesEvent, CheckgamesState>>();
          if (state.cardsToDraw > 0) {
            bloc.add(EndTurn(playerId: ''));                 // prend le cumul et passe
          } else {
            // Jouer le son de pioche
            AudioService.instance.playCardMove();
            bloc.add(DrawCard(playerId: me.id, count: 1)); // pioche 1 et fin de tour (géré côté BLoC)
          }
        }

        return Scaffold(
          body: SafeArea(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF145A32), Color(0xFF0B3D2E)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
              ),
              child: OrientationBuilder(
                builder: (context, orientation) {
                  return orientation == Orientation.portrait
                      ? _buildPortraitLayout(context, state, meIndex, me, isMyTurn, onPlay, onDeckTapOrDraw)
                      : _buildLandscapeLayout(context, state, meIndex, me, isMyTurn, onPlay, onDeckTapOrDraw);
                },
              ),
            ),
          ),
        );
        },
      ),
    );
  }

  // Layout pour mode portrait
  Widget _buildPortraitLayout(
    BuildContext context,
    CheckgamesState state,
    int meIndex,
    Player me,
    bool isMyTurn,
    Future<void> Function() onPlay,
    void Function() onDeckTapOrDraw,
  ) {
    // Obtenir les adversaires
    final opponents = <Player>[];
    for (var i = 0; i < state.players.length; i++) {
      if (i != meIndex) opponents.add(state.players[i]);
    }

    return Column(
      children: [
        SizedBox(height: context.sizing.spacingSmall),
        // Info bar en haut
        _TopInfoBar(onPause: _showPauseMenu),
        SizedBox(height: context.sizing.spacingXSmall),

        // Adversaires en haut à gauche et droite
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Adversaire 1 à gauche
            if (opponents.isNotEmpty)
              _buildTopOpponent(
                context,
                opponents[0],
                state.players[state.currentPlayerIndex].id == opponents[0].id,
              ),
            // Adversaire 2 à droite
            if (opponents.length > 1)
              _buildTopOpponent(
                context,
                opponents[1],
                state.players[state.currentPlayerIndex].id == opponents[1].id,
              ),
          ],
        ),
        // Zone de jeu centrale (pioche et défausse)
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Défausse avec zone de réception (DragTarget)
                    if (state.discardPile.isNotEmpty)
                      DiscardWidget(
                        key: _discardKey,
                        top: state.discardPile.last,
                        previousCards: state.discardPile.length > 1
                            ? state.discardPile.sublist(0, state.discardPile.length - 1)
                            : null,
                        onCardsDropped: (cards) {
                          if (isMyTurn) {
                            // On définit les cartes glissées comme sélection et on joue
                            setState(() {
                              _selected.clear();
                              _selected.addAll(cards);
                            });
                            onPlay();
                          }
                        },
                      ),

                    SizedBox(width: 30 * context.sizing.scaleFactor),
                    // Pioche
                    DeckWidget(
                      key: _deckKey,
                      count: state.drawPile.length,
                      enabled: isMyTurn,
                      onTap: onDeckTapOrDraw,
                    ),
                  ],
                ),
                // Indicateur couleur imposée sous les cartes
                if (state.imposedSuit != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: _ImposedSuitIndicator(suit: state.imposedSuit!),
                  ),
              ],
            ),
          ),
        ),

        // Main du joueur en éventail
        Center(
          child: HandFanWidget(
            cards: me.hand,
            selectedCards: _selected,
            onCardTap: (card) {
              if (isMyTurn) {
                setState(() {
                  if (_selected.contains(card)) {
                    _selected.remove(card);
                  } else {
                    _selected.add(card);
                  }
                });
              }
            },
            enabled: isMyTurn,
            cardKeys: me.hand.fold<Map<PlayingCard, GlobalKey>>({}, (map, card) {
              if (!_cardKeys.containsKey(card)) {
                _cardKeys[card] = GlobalKey();
              }
              map[card] = _cardKeys[card]!;
              return map;
            }),
          ),
        ),

        // Boutons d'action
        Padding(
          padding: EdgeInsets.fromLTRB(
            context.sizing.spacingSmall,
            context.sizing.spacingXSmall,
            context.sizing.spacingSmall,
            context.sizing.spacingSmall,
          ),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: isMyTurn ? onDeckTapOrDraw : null,
                  child: Text(state.cardsToDraw > 0 ? 'Cumul' : 'Piocher'),
                ),
              ),
              SizedBox(width: context.sizing.spacingSmall),
              Expanded(
                child: ElevatedButton(
                  onPressed: isMyTurn && _selected.isNotEmpty ? onPlay : null,
                  child: const Text('Jouer'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Layout pour mode paysage
  Widget _buildLandscapeLayout(
    BuildContext context,
    CheckgamesState state,
    int meIndex,
    Player me,
    bool isMyTurn,
    Future<void> Function() onPlay,
    void Function() onDeckTapOrDraw,
  ) {
    // Obtenir les adversaires
    final opponents = <Player>[];
    for (var i = 0; i < state.players.length; i++) {
      if (i != meIndex) opponents.add(state.players[i]);
    }

    return Row(
      children: [
        // Adversaires sur le côté gauche
        if (opponents.isNotEmpty)
          _buildSideOpponent(context, opponents[0], isLeft: true),

        // Colonne centrale
        Expanded(
          child: Column(
            children: [
              SizedBox(height: context.sizing.spacingXSmall),
              // Info bar en haut
              _TopInfoBar(onPause: _showPauseMenu),

              // Zone de jeu centrale (pioche et défausse)
              Expanded(
                flex: 2,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Défausse avec zone de réception (DragTarget)
                          if (state.discardPile.isNotEmpty)
                            DiscardWidget(
                              key: _discardKey,
                              top: state.discardPile.last,
                              previousCards: state.discardPile.length > 1
                                  ? state.discardPile.sublist(0, state.discardPile.length - 1)
                                  : null,
                              onCardsDropped: (cards) {
                                if (isMyTurn) {
                                  setState(() {
                                    _selected.clear();
                                    _selected.addAll(cards);
                                  });
                                  onPlay();
                                }
                              },
                            ),

                          SizedBox(width: 40 * context.sizing.scaleFactor),
                          // Pioche
                          DeckWidget(
                            key: _deckKey,
                            count: state.drawPile.length,
                            enabled: isMyTurn,
                            onTap: onDeckTapOrDraw,
                          ),
                        ],
                      ),
                      // Indicateur couleur imposée sous les cartes
                      if (state.imposedSuit != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: _ImposedSuitIndicator(suit: state.imposedSuit!),
                        ),
                    ],
                  ),
                ),
              ),
              // Main du joueur
              Expanded(
                flex: 1,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: EdgeInsets.only(top: context.sizing.spacingSmall),
                    child: HandFanWidget(
                  cards: me.hand,
                  selectedCards: _selected,
                  onCardTap: (card) {
                    if (isMyTurn) {
                      setState(() {
                        if (_selected.contains(card)) {
                          _selected.remove(card);
                        } else {
                          _selected.add(card);
                        }
                      });
                    }
                  },
                  enabled: isMyTurn,
                  cardKeys: me.hand.fold<Map<PlayingCard, GlobalKey>>({}, (map, card) {
                    if (!_cardKeys.containsKey(card)) {
                      _cardKeys[card] = GlobalKey();
                    }
                    map[card] = _cardKeys[card]!;
                    return map;
                  }),
                    ),
                  ),
                ),
              ),

              // Boutons d'action
              Padding(
                padding: EdgeInsets.all(context.sizing.spacingSmall),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isMyTurn ? onDeckTapOrDraw : null,
                        child: Text(state.cardsToDraw > 0 ? 'Cumul' : 'Piocher'),
                      ),
                    ),
                    SizedBox(width: context.sizing.spacingSmall),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isMyTurn && _selected.isNotEmpty ? onPlay : null,
                        child: const Text('Jouer'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Adversaire sur le côté droit
        if (opponents.length > 1)
          _buildSideOpponent(context, opponents[1], isLeft: false),
      ],
    );
  }

  // Widget pour un adversaire en haut (mode portrait)
  Widget _buildTopOpponent(BuildContext context, Player player, bool isCurrentTurn) {
    final sizing = context.sizing;
    final backW = sizing.opponentCardWidth;
    final n = player.hand.length;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: sizing.spacingSmall),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Nom du joueur avec indicateur de tour
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isCurrentTurn
                  ? Colors.orange.shade700.withOpacity(0.9)
                  : Colors.black.withOpacity(0.4),
              borderRadius: BorderRadius.circular(8),
              boxShadow: isCurrentTurn ? [
                BoxShadow(
                  color: Colors.orange.shade400,
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ] : null,
              border: isCurrentTurn ? Border.all(
                color: Colors.yellow.shade300,
                width: 2,
              ) : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isCurrentTurn) ...[
                  const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                ],
                Text(
                  player.name,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: isCurrentTurn ? FontWeight.w900 : FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: sizing.spacingXSmall),

          // Cartes en ligne horizontale (max 3 pour éviter overflow)
          Row(
            key: _botCardKeys[player.id],
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < n.clamp(1, 3); i++)
                Padding(
                  padding: EdgeInsets.only(left: i > 0 ? 3 : 0),
                  child: CardBack(width: backW),
                ),
            ],
          ),
          SizedBox(height: sizing.spacingXSmall),

          // Badge nombre de cartes
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.orange.shade700, Colors.orange.shade900],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Text(
              '$n',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget pour un adversaire sur le côté (mode paysage)
  Widget _buildSideOpponent(BuildContext context, Player player, {required bool isLeft}) {
    final sizing = context.sizing;
    final backW = sizing.opponentCardWidth * 0.8; // Plus petit en paysage
    final n = player.hand.length;

    return Container(
      width: 80,
      padding: EdgeInsets.symmetric(vertical: sizing.spacingMedium),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Nom du joueur (vertical)
          RotatedBox(
            quarterTurns: isLeft ? 3 : 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                player.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          ),
          SizedBox(height: sizing.spacingSmall),

          // Cartes empilées verticalement
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (int i = 0; i < n.clamp(1, 4); i++)
                  Padding(
                    padding: EdgeInsets.only(top: i > 0 ? 4 : 0),
                    child: CardBack(width: backW),
                  ),
              ],
            ),
          ),

          SizedBox(height: sizing.spacingSmall),
          // Badge nombre de cartes
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.orange.shade700, Colors.orange.shade900],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Text(
              '$n',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _animateBotCard(String botId, PlayingCard card) {
    if (!mounted) return;

    // Debug
    print('🎴 Tentative d\'animation pour bot: $botId');
    print('   Cartes dans _botCardKeys: ${_botCardKeys.keys.toList()}');

    final botKey = _botCardKeys[botId];
    if (botKey == null) {
      print('   ❌ Pas de GlobalKey pour ce bot');
      return;
    }

    if (botKey.currentContext == null) {
      print('   ❌ Pas de context pour la key du bot');
      return;
    }

    if (_discardKey.currentContext == null) {
      print('   ❌ Pas de context pour la défausse');
      return;
    }

    // Position de départ (bot)
    final botRenderBox = botKey.currentContext!.findRenderObject() as RenderBox?;
    if (botRenderBox == null) {
      print('   ❌ Pas de RenderBox pour le bot');
      return;
    }
    final botPosition = botRenderBox.localToGlobal(Offset.zero);

    // Position d'arrivée (défausse)
    final discardRenderBox = _discardKey.currentContext!.findRenderObject() as RenderBox?;
    if (discardRenderBox == null) {
      print('   ❌ Pas de RenderBox pour la défausse');
      return;
    }
    final discardPosition = discardRenderBox.localToGlobal(Offset.zero);

    print('   ✅ Animation: de ${botPosition} vers ${discardPosition}');

    // Jouer le son du mouvement de carte
    AudioService.instance.playCardMove();

    // Créer l'animation
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => AnimatedCardOverlay(
        cards: [card],
        startPositions: [botPosition],
        endPosition: discardPosition,
        duration: const Duration(milliseconds: 600),
        onComplete: () {
          if (mounted) {
            overlayEntry.remove();
          }
        },
      ),
    );

    Overlay.of(context).insert(overlayEntry);
  }

  void _animateDrawCards(String playerId, int count) {
    if (!mounted) return;
    if (_deckKey.currentContext == null) return;

    print('🎴 Animation pioche: $count carte(s) pour joueur $playerId');

    // Position de départ (pioche)
    final deckRenderBox = _deckKey.currentContext!.findRenderObject() as RenderBox?;
    if (deckRenderBox == null) return;
    final deckPosition = deckRenderBox.localToGlobal(Offset.zero);

    // Position d'arrivée
    Offset? targetPosition;

    // Si c'est le joueur humain (id == '0')
    if (playerId == '0') {
      // Pas d'animation pour le joueur humain pour l'instant (trop complexe avec l'éventail)
      print('   Pas d\'animation pour le joueur humain');
      return;
    } else {
      // C'est un bot
      final botKey = _botCardKeys[playerId];
      if (botKey == null || botKey.currentContext == null) {
        print('   Pas de position pour le bot $playerId');
        return;
      }

      final botRenderBox = botKey.currentContext!.findRenderObject() as RenderBox?;
      if (botRenderBox == null) return;
      targetPosition = botRenderBox.localToGlobal(Offset.zero);
    }

    print('   Animation: de $deckPosition vers $targetPosition');

    // Créer des cartes fictives pour l'animation (dos de carte)
    final dummyCard = const PlayingCard(suit: CardSuit.hearts, value: CardValue.ace);

    // Animer chaque carte avec un léger décalage
    for (int i = 0; i < count.clamp(0, 5); i++) {
      Future.delayed(Duration(milliseconds: i * 100), () {
        if (!mounted) return;

        // Jouer le son du mouvement de carte
        AudioService.instance.playCardMove();

        late OverlayEntry overlayEntry;

        overlayEntry = OverlayEntry(
          builder: (context) => AnimatedCardOverlay(
            cards: [dummyCard],
            startPositions: [deckPosition],
            endPosition: targetPosition!,
            duration: const Duration(milliseconds: 400),
            onComplete: () {
              if (mounted) {
                overlayEntry.remove();
              }
            },
          ),
        );

        Overlay.of(context).insert(overlayEntry);
      });
    }
  }
}

class _TopInfoBar extends StatelessWidget {
  final VoidCallback? onPause;

  const _TopInfoBar({this.onPause});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<Bloc<CheckgamesEvent, CheckgamesState>>().state;
    String suitSymbol(CardSuit s) {
      switch (s) {
        case CardSuit.hearts: return '♥';
        case CardSuit.diamonds: return '♦';
        case CardSuit.clubs: return '♣';
        case CardSuit.spades: return '♠';
        case CardSuit.jokerRed: return '🃏';
        case CardSuit.jokerBlack: return '🃏';
      }
    }
    Color suitColor(CardSuit s) =>
        (s == CardSuit.hearts || s == CardSuit.diamonds) ? Colors.red.shade700 : Colors.black87;

    final chips = <Widget>[];

    // Vérifier que le joueur courant existe
    final currentPlayer = state.currentPlayer;
    if (currentPlayer != null) {
      chips.add(_StatusBadge(
        icon: Icons.person,
        label: 'Tour',
        value: currentPlayer.name,
        color: Colors.white,
        animate: true,
      ));
    }

    chips.addAll([
      _StatusBadge(
        icon: Icons.layers,
        label: 'Défausse',
        value: '${state.discardPile.length}',
        color: Colors.amber,
      ),
      _StatusBadge(
        icon: Icons.casino,
        label: 'Pioche',
        value: '${state.drawPile.length}',
        color: Colors.cyan,
      ),
    ]);

    // Indicateur DUEL
    if (state.phase == GamePhase.duel) {
      chips.insert(0, _StatusBadge(
        icon: Icons.flash_on,
        label: 'Mode',
        value: 'DUEL !',
        color: Colors.red.shade400,
        animate: true,
      ));
    }

    if (state.cardsToDraw > 0) {
      chips.add(_StatusBadge(
        icon: Icons.add_circle_outline,
        label: 'Cumul',
        value: '+${state.cardsToDraw}',
        color: Colors.orange.shade400,
        animate: true,
      ));
    }
    // L'indicateur "Imposé" est affiché sous les cartes centrales pour une meilleure visibilité

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Bouton pause à gauche
        if (onPause != null) ...[
          IconButton(
            icon: const Icon(Icons.pause_circle_outline, color: Colors.white70, size: 24),
            onPressed: () {
              AudioService.instance.playButtonClick();
              onPause!();
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Center(
            child: Wrap(spacing: 8, runSpacing: 8, children: chips),
          ),
        ),
        // Petit bouton rejouer à droite
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white70, size: 20),
          onPressed: () {
            AudioService.instance.playButtonClick();
            context.read<Bloc<CheckgamesEvent, CheckgamesState>>().add(RestartGame(keepPlayers: true));
          },
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.animate = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 500),
      tween: Tween(begin: 1.0, end: animate ? 1.08 : 1.0),
      curve: Curves.easeInOut,
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: animate ? color.withOpacity(0.25) : color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: animate ? color : color.withOpacity(0.3),
                width: animate ? 2.0 : 1.2,
              ),
              boxShadow: [
                if (animate)
                  BoxShadow(
                    color: color.withOpacity(0.4),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: animate ? 20 : 18, color: color),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label.toUpperCase(),
                      style: TextStyle(
                        fontSize: 9,
                        letterSpacing: 1.1,
                        color: color.withOpacity(0.8),
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 14,
                        color: color,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          if (animate)
                            Shadow(color: color.withOpacity(0.5), blurRadius: 2)
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ImposedSuitIndicator extends StatelessWidget {
  final CardSuit suit;

  const _ImposedSuitIndicator({required this.suit});

  @override
  Widget build(BuildContext context) {
    String suitSymbol;
    Color suitColor;

    switch (suit) {
      case CardSuit.hearts:
        suitSymbol = '♥';
        suitColor = Colors.red.shade600;
        break;
      case CardSuit.diamonds:
        suitSymbol = '♦';
        suitColor = Colors.red.shade600;
        break;
      case CardSuit.clubs:
        suitSymbol = '♣';
        suitColor = Colors.grey.shade900;
        break;
      case CardSuit.spades:
        suitSymbol = '♠';
        suitColor = Colors.grey.shade900;
        break;
      default:
        suitSymbol = '🃏';
        suitColor = Colors.purple;
    }

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 800),
      tween: Tween(begin: 0.9, end: 1.05),
      curve: Curves.easeInOut,
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: suitColor, width: 3),
              boxShadow: [
                BoxShadow(
                  color: suitColor.withOpacity(0.5),
                  blurRadius: 16,
                  spreadRadius: 4,
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.gavel, size: 22, color: suitColor),
                const SizedBox(width: 10),
                Text(
                  'IMPOSÉ',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: suitColor,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  suitSymbol,
                  style: TextStyle(
                    fontSize: 32,
                    color: suitColor,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        color: suitColor.withOpacity(0.4),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

