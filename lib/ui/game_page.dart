import 'package:checkgame/utils/app_snackbar.dart';
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
import '../utils/app_logger.dart';

class GamePage extends StatefulWidget {
  final String? playerId;
  final String? roomId;
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
  bool _skipNextBotAnimation = false; // Pour éviter l'animation après que le joueur humain a joué
  bool _isShowingChecks = false; // Flag pour bloquer le jeu pendant l'affichage de CHECKS
  final GlobalKey _deckKey = GlobalKey(); // Key pour la position de la pioche
  final Set<OverlayEntry> _overlays = {}; // Overlays actifs, retirés au dispose

  /// Réinitialise toutes les variables de suivi pour une nouvelle partie
  void _resetTrackingVariables() {
    appLogger.d('Réinitialisation des variables de suivi pour nouvelle partie');
    _selected.clear();
    _skipNextBotAnimation = false;
    _isShowingChecks = false;
  }

  @override
  void initState() {
    super.initState();
    // Démarrer la musique de fond au lancement du jeu
    AudioService.instance.startBackgroundMusic();
  }

  @override
  void dispose() {
    // Retirer les overlays encore affichés (animations, menus) pour qu'ils
    // ne restent pas à l'écran sur la page suivante
    for (final entry in _overlays.toList()) {
      _removeOverlay(entry);
    }
    CardAnimationService.instance.cancelAll();
    // Arrêter la musique quand on quitte la page
    AudioService.instance.stopBackgroundMusic();
    super.dispose();
  }

  /// Les overlays sont insérés dans l'Overlay racine (au-dessus de toutes les
  /// pages) : on les suit pour pouvoir les retirer au dispose.
  void _insertOverlay(OverlayEntry entry) {
    _overlays.add(entry);
    Overlay.of(context).insert(entry);
  }

  void _removeOverlay(OverlayEntry entry) {
    if (_overlays.remove(entry) && entry.mounted) entry.remove();
  }

  void _showChecksOverlay(String playerName) {
    if (!mounted || _isShowingChecks) return;

    // Jouer le son CHECKS
    AudioService.instance.playChecks();
    final bloc = context.read<Bloc<CheckgamesEvent, CheckgamesState>>();

    // Bloquer le jeu pendant l'affichage
    setState(() { _isShowingChecks = true; });
    bloc.add(const SetPaused(true));

    late OverlayEntry overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (context) => Material(
        color: Colors.black.withOpacity(0.3),
        child: Center(
          child: ChecksOverlay(
            playerName: playerName,
            onComplete: () {
              _removeOverlay(overlayEntry);
              if (mounted) {
                setState(() { _isShowingChecks = false; });
                } else{
                _isShowingChecks = false;
              }
              if(!bloc.isClosed){
                bloc.add(const SetPaused(false));
              }
            },
          ),
        ),
      ),
    );

    if(!mounted){
      _isShowingChecks = false;
      if(!bloc.isClosed) bloc.add(const SetPaused(false));
      return;
    }

    _insertOverlay(overlayEntry);
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

    appLogger.d('GamePage - isMultiplayer: $isMultiplayer, isHost: $isHost');
    appLogger.d('GamePage - session identifiers initialised');

    // Capturer le ScaffoldMessenger AVANT de créer l'overlay
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final roomId = widget.roomId;

    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (overlayContext) => PauseMenu(
        onResume: () {
          if (mounted) {
            _removeOverlay(overlayEntry);
            bloc.add(const SetPaused(false));
          }
        },
        onQuit: () {
          if (mounted) {
            _removeOverlay(overlayEntry);
            bloc.add(RestartGame(keepPlayers: true));
          }
        },
        onRestart: isMultiplayer && isHost && roomId != null
            ? () async {
                appLogger.d('Callback onRestart appelé');
                if (mounted) {
                  // Fermer le menu pause d'abord
                  appLogger.d('Fermeture du menu pause');
                  try {
                    _removeOverlay(overlayEntry);
                  } catch (e) {
                    appLogger.e('Erreur lors de la suppression de l\'overlay', error: e);
                  }
                  bloc.add(const SetPaused(false));

                  // Réinitialiser les variables de suivi AVANT le restart
                  _resetTrackingVariables();

                  try {
                    // Afficher un indicateur de chargement
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(
                        content: Text('Relance de la partie...'),
                        duration: Duration(seconds: 2),
                      ),
                    );

                    // Relancer via GameMasterService
                    appLogger.d('Appel de GameMasterService.restartGame');
                    final gameMaster = GameMasterService();
                    await gameMaster.restartGame(roomId);

                    appLogger.d('Partie relancée avec succès');
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(
                        content: Text('✅ Partie relancée !'),
                        duration: Duration(seconds: 2),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } catch (e) {
                    appLogger.e('Erreur lors de la relance', error: e);
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: Text('Erreur lors de la relance: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } else {
                  appLogger.d('Widget non monté');
                }
              }
            : null,
        onLeaveGame: isMultiplayer && roomId != null && widget.playerId != null
            ? () async {
                appLogger.d('Demande de sortie de partie');
                _removeOverlay(overlayEntry);
                try {
                  // Appeler le service Firebase pour quitter la partie
                  final roomService = FirebaseRoomService();
                  await roomService.leaveActiveGame(roomId, widget.playerId!);

                  appLogger.d('Sortie de partie réussie');

                  // Retourner au menu principal
                  if (mounted) {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  }
                } catch (e) {
                  appLogger.e('Erreur lors de la sortie', error: e);
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
        onStopGame: !isMultiplayer
            ? () {
                appLogger.d('Arrêt de la partie solo');
                // Fermer l'overlay
                _removeOverlay(overlayEntry);
                bloc.add(const SetPaused(false));
                // Retourner au menu principal
                if (mounted) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
              }
            : null,
        isMultiplayer: isMultiplayer,
        isHost: isHost,
      ),
    );

    _insertOverlay(overlayEntry);
  }

  /// Affiche une popup de confirmation pour quitter la partie
  Future<bool> _showExitConfirmation() async {
    if (!mounted) return false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(Icons.exit_to_app, color: Colors.red.shade600, size: 28),
            const SizedBox(width: 12),
            const Text('Quitter la partie ?'),
          ],
        ),
        content: Text(
          widget.roomId != null
              ? 'Voulez-vous vraiment quitter cette partie en ligne ?\n\nVous abandonnerez la partie en cours.'
              : 'Voulez-vous vraiment quitter cette partie ?\n\nVotre progression sera perdue.',
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () {
              AudioService.instance.playButtonClick();
              Navigator.of(context).pop(false);
            },
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              AudioService.instance.playButtonClick();
              Navigator.of(context).pop(true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Quitter'),
          ),
        ],
      ),
    );

    return result ?? false;
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
            _removeOverlay(overlayEntry);
          }
        },
      ),
    );

    _insertOverlay(overlayEntry);
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        // 1. saveError — bug corrigé
        BlocListener<Bloc<CheckgamesEvent, CheckgamesState>, CheckgamesState>(
          listenWhen: (prev, curr) => curr.saveError && !prev.saveError,
          listener: (ctx, state) => AppSnackbar.warning(
            ctx,
            'Résultats non sauvegardés — vérifiez votre espace de stockage.',
          ),
        ),
        // 2. Fin de partie → GameOverSheet
        BlocListener<Bloc<CheckgamesEvent, CheckgamesState>, CheckgamesState>(
          listenWhen: (prev, curr) =>
              !prev.isGameOver && curr.isGameOver && curr.phase == GamePhase.finished,
          listener: (ctx, state) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              showModalBottomSheet(
                context: ctx,
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
                      Navigator.pop(ctx);
                      _resetTrackingVariables();
                      try {
                        final gameMaster = GameMasterService();
                        await gameMaster.restartGame(widget.roomId!);
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                            content: Text('✅ Partie relancée !'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            content: Text('❌ Erreur: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    } else if (widget.playerId != null) {
                      Navigator.of(ctx).popUntil((route) => route.isFirst);
                    } else {
                      Navigator.pop(ctx);
                      _resetTrackingVariables();
                      context.read<Bloc<CheckgamesEvent, CheckgamesState>>().add(RestartGame(keepPlayers: true));
                    }
                  },
                ),
              );
            });
          },
        ),
        // 3. Redémarrage de partie
        BlocListener<Bloc<CheckgamesEvent, CheckgamesState>, CheckgamesState>(
          listenWhen: (prev, curr) => prev.isGameOver && !curr.isGameOver,
          listener: (ctx, state) {
            _resetTrackingVariables();
            if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
          },
        ),
        // 4. Animation bot
        BlocListener<Bloc<CheckgamesEvent, CheckgamesState>, CheckgamesState>(
          listenWhen: (prev, curr) => curr.discardPile.length > prev.discardPile.length,
          listener: (ctx, state) {
            if (_skipNextBotAnimation) {
              _skipNextBotAnimation = false;
              return;
            }
            if (state.previousPlayerIndex != null && state.previousPlayerIndex! > 0) {
              final botId = state.players[state.previousPlayerIndex!].id;
              final topCard = state.discardPile.last;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                _animateBotCard(botId, topCard);
              });
            }
          },
        ),
        // 5. Animation pioche
        BlocListener<Bloc<CheckgamesEvent, CheckgamesState>, CheckgamesState>(
          listenWhen: (prev, curr) =>
          curr.lastDrawPlayerId != null &&
              curr.lastDrawPlayerId != prev.lastDrawPlayerId,
          listener: (ctx, state) {
            final drawPlayerId = state.lastDrawPlayerId!;
            final drawCount = state.lastDrawCount;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              _animateDrawCards(drawPlayerId, drawCount);
            });
          },
        ),
        // 6. Overlay CHECKS
        BlocListener<Bloc<CheckgamesEvent, CheckgamesState>, CheckgamesState>(
          listenWhen: (prev, curr) =>
              curr.lastChecksPlayerId != prev.lastChecksPlayerId &&
              curr.lastChecksPlayerId != null &&
              !curr.isGameOver,
          listener: (ctx, state) {
            final p = state.players.firstWhere(
              (p) => p.id == state.lastChecksPlayerId,
              orElse: () => state.players.first,
            );
            Future.microtask(() {
              if (mounted && !_isShowingChecks) _showChecksOverlay(p.name);
            });
          },
        ),
      ],
      child: BlocBuilder<Bloc<CheckgamesEvent, CheckgamesState>, CheckgamesState>(
        buildWhen: (prev, curr) =>
          prev.players != curr.players ||
          prev.currentPlayerIndex != curr.currentPlayerIndex ||
          prev.drawPile.length != curr.drawPile.length ||
          prev.discardPile != curr.discardPile ||
          prev.isGameOver != curr.isGameOver ||
          prev.imposedSuit != curr.imposedSuit ||
          prev.cardsToDraw != curr.cardsToDraw ||
          prev.phase != curr.phase ||
          prev.errorMessage != curr.errorMessage,
        builder: (context, state) {
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

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;

            final shouldExit = await _showExitConfirmation();
            if (shouldExit && mounted) {
              Navigator.of(context).pop();
            }
          },
          child: Scaffold(
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
    appLogger.d('Tentative d\'animation pour bot: $botId');
    appLogger.d('Cartes enregistrées dans _botCardKeys: ${_botCardKeys.keys.toList()}');

    final botKey = _botCardKeys[botId];
    if (botKey == null) {
      appLogger.d('Pas de GlobalKey pour ce bot');
      return;
    }

    if (botKey.currentContext == null) {
      appLogger.d('Pas de context pour la key du bot');
      return;
    }

    if (_discardKey.currentContext == null) {
      appLogger.d('Pas de context pour la défausse');
      return;
    }

    // Position de départ (bot)
    final botRenderBox = botKey.currentContext!.findRenderObject() as RenderBox?;
    if (botRenderBox == null) {
      appLogger.d('Pas de RenderBox pour le bot');
      return;
    }
    final botPosition = botRenderBox.localToGlobal(Offset.zero);

    // Position d'arrivée (défausse)
    final discardRenderBox = _discardKey.currentContext!.findRenderObject() as RenderBox?;
    if (discardRenderBox == null) {
      appLogger.d('Pas de RenderBox pour la défausse');
      return;
    }
    final discardPosition = discardRenderBox.localToGlobal(Offset.zero);

    appLogger.d('Animation bot: de $botPosition vers $discardPosition');

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
            _removeOverlay(overlayEntry);
          }
        },
      ),
    );

    _insertOverlay(overlayEntry);
  }

  void _animateDrawCards(String playerId, int count) {
    if (!mounted) return;
    if (_deckKey.currentContext == null) return;

    appLogger.d('Animation pioche: $count carte(s) pour joueur $playerId');

    // Position de départ (pioche)
    final deckRenderBox = _deckKey.currentContext!.findRenderObject() as RenderBox?;
    if (deckRenderBox == null) return;
    final deckPosition = deckRenderBox.localToGlobal(Offset.zero);

    // Position d'arrivée
    Offset? targetPosition;

    // Si c'est le joueur humain (id == '0')
    if (playerId == '0') {
      // Pas d'animation pour le joueur humain pour l'instant (trop complexe avec l'éventail)
      appLogger.d('Pas d\'animation pour le joueur humain');
      return;
    } else {
      // C'est un bot
      final botKey = _botCardKeys[playerId];
      if (botKey == null || botKey.currentContext == null) {
        appLogger.d('Pas de position pour le bot $playerId');
        return;
      }

      final botRenderBox = botKey.currentContext!.findRenderObject() as RenderBox?;
      if (botRenderBox == null) return;
      targetPosition = botRenderBox.localToGlobal(Offset.zero);
    }

    appLogger.d('Animation pioche: de $deckPosition vers $targetPosition');

    // Carte fictive : affichée face cachée, sa valeur n'est jamais visible
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
            faceDown: true,
            onComplete: () {
              if (mounted) {
                _removeOverlay(overlayEntry);
              }
            },
          ),
        );

        _insertOverlay(overlayEntry);
      });
    }
  }
}

class _TopBarData {
  const _TopBarData({
    required this.currentPlayerName,
    required this.discardCount,
    required this.drawCount,
    required this.phase,
    required this.cardsToDraw,
  });
  final String? currentPlayerName;
  final int discardCount;
  final int drawCount;
  final GamePhase phase;
  final int cardsToDraw;

  @override
  bool operator ==(Object other) =>
      other is _TopBarData &&
      other.currentPlayerName == currentPlayerName &&
      other.discardCount == discardCount &&
      other.drawCount == drawCount &&
      other.phase == phase &&
      other.cardsToDraw == cardsToDraw;

  @override
  int get hashCode =>
      Object.hash(currentPlayerName, discardCount, drawCount, phase, cardsToDraw);
}

class _TopInfoBar extends StatelessWidget {
  final VoidCallback? onPause;

  const _TopInfoBar({this.onPause});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<Bloc<CheckgamesEvent, CheckgamesState>, CheckgamesState, _TopBarData>(
      selector: (state) => _TopBarData(
        currentPlayerName: state.currentPlayer?.name,
        discardCount: state.discardPile.length,
        drawCount: state.drawPile.length,
        phase: state.phase,
        cardsToDraw: state.cardsToDraw,
      ),
      builder: (context, data) => _buildBar(context, data),
    );
  }

  Widget _buildBar(BuildContext context, _TopBarData data) {
    final chips = <Widget>[];

    if (data.currentPlayerName != null) {
      chips.add(_StatusBadge(
        icon: Icons.person,
        label: 'Tour',
        value: data.currentPlayerName!,
        color: Colors.white,
        animate: true,
      ));
    }

    chips.addAll([
      _StatusBadge(
        icon: Icons.layers,
        label: 'Défausse',
        value: '${data.discardCount}',
        color: Colors.amber,
      ),
      _StatusBadge(
        icon: Icons.casino,
        label: 'Pioche',
        value: '${data.drawCount}',
        color: Colors.cyan,
      ),
    ]);

    if (data.phase == GamePhase.duel) {
      chips.insert(0, _StatusBadge(
        icon: Icons.flash_on,
        label: 'Mode',
        value: 'DUEL !',
        color: Colors.red.shade400,
        animate: true,
      ));
    }

    if (data.cardsToDraw > 0) {
      chips.add(_StatusBadge(
        icon: Icons.add_circle_outline,
        label: 'Cumul',
        value: '+${data.cardsToDraw}',
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

