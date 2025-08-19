import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../Bloc/checkgames_bloc.dart';
import '../Bloc/checkgames_event.dart';
import '../Bloc/checkgames_state.dart';
import '../models/playing_card.dart';
import '../models/card_suit.dart';
import '../models/card_value.dart';
import 'package:checkgame/view/widgets/playing_card_widget.dart';
import 'package:checkgame/view/widgets/suit_picker_sheet.dart';

class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  final Set<PlayingCard> _selected = {};

  @override
  Widget build(BuildContext context) {
    return BlocListener<CheckGameBloc, CheckgamesState>(
        listenWhen: (prev, curr) => !prev.isGameOver && curr.isGameOver,
        listener: (context, state) {
          final order = state.finishingOrder.map((id) {
            final p = state.players.firstWhere(
                  (pl) => pl.id == id,
              orElse: () => state.players.first, // fallback
            );
            return p.name;
          }).toList();
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Fin de partie'),
              content: Text('Ordre : ${order.join(' > ')}'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    context.read<CheckGameBloc>().add(RestartGame(keepPlayers: true));
                  },
                  child: const Text('Rejouer'),
                ),
              ],
            ),
          );
        },

    child:  Scaffold(
      appBar: AppBar(
        title: const Text('Table de jeu'),
        actions: [
          IconButton(
            tooltip: 'Recommencer',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<CheckGameBloc>().add(RestartGame(keepPlayers: true));
            },
          ),
        ],
      ),
      body: SafeArea(
        child: BlocBuilder<CheckGameBloc, CheckgamesState>(
          builder: (context, state) {
            final bloc = context.read<CheckGameBloc>();
            if (state.players.isEmpty) {
              return const Center(child: Text('Aucun joueur'));
            }

            final me = state.players.first; // on suppose que le joueur humain est index 0
            final isMyTurn = state.currentPlayerIndex == 0;

            return Column(
              children: [
                // Bandeau d’infos
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Chip(
                        label: Text('Tour: ${state.players[state.currentPlayerIndex].name}'),
                        avatar: const Icon(Icons.person),
                        color: WidgetStatePropertyAll(
                          isMyTurn ? Colors.green.withOpacity(.15) : Colors.grey.withOpacity(.15),
                        ),
                      ),
                      if (state.imposedSuit != null)
                        Chip(
                          avatar: const Icon(Icons.palette),
                          label: Text('Couleur imposée: ${_suitLabel(state.imposedSuit!)}'),
                        ),
                      if (state.cardsToDraw > 0)
                        Chip(
                          avatar: const Icon(Icons.add),
                          label: Text('+${state.cardsToDraw} à piocher'),
                        ),
                      Chip(
                        avatar: const Icon(Icons.layers),
                        label: Text('Défausse: ${state.discardPile.length}'),
                      ),
                      Chip(
                        avatar: const Icon(Icons.inventory_2),
                        label: Text('Pioche: ${state.drawPile.length}'),
                      ),
                    ],
                  ),
                ),

                // Centre de table : carte visible
                Expanded(
                  child: Center(
                    child: _DiscardPileView(top: state.discardPile.isNotEmpty ? state.discardPile.last : null),
                  ),
                ),

                const Divider(),

                // Main du joueur
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Votre main (${me.hand.length})',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
                _HandView(
                  cards: me.hand,
                  selected: _selected,
                  onTapCard: isMyTurn
                      ? (card) {
                    setState(() {
                      if (_selected.contains(card)) {
                        _selected.remove(card);
                      } else {
                        _selected.add(card);
                      }
                    });
                  }
                      : null,
                ),

                // Actions
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: FilledButton.tonal(
                          onPressed: isMyTurn
                              ? () {
                            // Piocher = 1 carte (hors pénalité)
                            context.read<CheckGameBloc>().add(
                              DrawCard(playerId: me.id, count: 1),
                            );
                          }
                              : null,
                          child: const Text('Piocher'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: FilledButton(
                          onPressed: isMyTurn ? () => _onPlayPressed(context, state) : null,
                          child: const Text('Jouer la sélection'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.tonal(
                          onPressed: isMyTurn
                              ? () {
                            context.read<CheckGameBloc>().add(EndTurn());
                            setState(() => _selected.clear());
                          }
                              : null,
                          child: const Text('Fin du tour'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ),
    );
  }

  Future<void> _onPlayPressed(BuildContext context, CheckgamesState state) async {
    final me = state.players.first;
    if (_selected.isEmpty) {
      _snack(context, 'Sélectionnez au moins une carte.');
      return;
    }

    // Double coup : toutes les cartes doivent avoir la même valeur
    final value = _selected.first.value;
    final sameValue = _selected.every((c) => c.value == value);
    if (!sameValue) {
      _snack(context, 'Double coup: toutes les cartes doivent avoir la même valeur.');
      return;
    }

    // Si Valet, demander une couleur si nécessaire
    CardSuit? imposed;
    if (value == CardValue.jack) {
      imposed = await showModalBottomSheet<CardSuit>(
        context: context,
        isScrollControlled: true,
        builder: (_) => const SuitPickerSheet(),
      );
      if (imposed == null) {
        _snack(context, 'Choisissez une couleur pour le Valet.');
        return;
      }
    }


    context.read<CheckGameBloc>().add(
      PlayCard(
        playerId: me.id,
        cards: _selected.toList(),
        imposedSuit: imposed, // null pour les autres cartes
      ),
    );

    setState(() => _selected.clear());
  }

  void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _suitLabel(CardSuit s) {
    switch (s) {
      case CardSuit.hearts:
        return '♥ Cœur';
      case CardSuit.diamonds:
        return '♦ Carreau';
      case CardSuit.clubs:
        return '♣ Trèfle';
      case CardSuit.spades:
        return '♠ Pique';
      case CardSuit.jokerRed:
        return '🃏 Rouge';
      case CardSuit.jokerBlack:
        return '🃏 Noir';
    }
  }
}


class _DiscardPileView extends StatelessWidget {
  final PlayingCard? top;
  const _DiscardPileView({required this.top});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AspectRatio(
      aspectRatio: 3 / 4,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.outlineVariant),
          color: theme.colorScheme.surfaceContainerHighest,
        ),
        child: Center(
          child: top == null
              ? const Text('Aucune carte')
              : PlayingCardWidget(card: top!, big: true),
        ),
      ),
    );
  }
}

class _HandView extends StatelessWidget {
  final List<PlayingCard> cards;
  final Set<PlayingCard> selected;
  final void Function(PlayingCard card)? onTapCard;

  const _HandView({
    required this.cards,
    required this.selected,
    required this.onTapCard,
  });

  @override
  Widget build(BuildContext context) {
    // Petite “main en éventail” simplifiée via Wrap
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: cards.map((c) {
          final isSelected = selected.contains(c);
          return GestureDetector(
            onTap: onTapCard == null ? null : () => onTapCard!(c),
            child: AnimatedScale(
              duration: const Duration(milliseconds: 120),
              scale: isSelected ? 1.06 : 1.0,
              child: Stack(
                children: [
                  PlayingCardWidget(card: c),
                  if (isSelected)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(width: 3, color: Theme.of(context).colorScheme.primary),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
