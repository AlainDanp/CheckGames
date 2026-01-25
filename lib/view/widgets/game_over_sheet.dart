import 'package:flutter/material.dart';
import '../../models/player_card.dart';

class GameOverSheet extends StatelessWidget {
  final List<String> finishingOrder;
  final List<Player> allPlayers;
  final VoidCallback onRestart;
  final bool isMultiplayer;
  final bool isHost; // Nouveau : indique si le joueur est l'hôte
  final String? roomId; // Nouveau : ID de la room pour la relance

  const GameOverSheet({
    super.key,
    required this.finishingOrder,
    required this.allPlayers,
    required this.onRestart,
    this.isMultiplayer = false,
    this.isHost = false,
    this.roomId,
  });

  @override
  Widget build(BuildContext context) {
    // Calculer le classement
    final ranking = finishingOrder.map((id) {
      return allPlayers.firstWhere((p) => p.id == id);
    }).toList();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Partie terminée !',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 20),

            // Classement
            ...ranking.asMap().entries.map((entry) {
              final position = entry.key + 1;
              final player = entry.value;
              // Générer médaille dynamiquement pour supporter n'importe quel nombre de joueurs
              final medal = _getMedalForPosition(position);

              return ListTile(
                leading: Text(medal, style: const TextStyle(fontSize: 24)),
                title: Text('$position. ${player.name}'),
                trailing: position == 1
                    ? const Icon(Icons.emoji_events, color: Colors.amber)
                    : null,
              );
            }),

            const SizedBox(height: 20),

            // Boutons
            if (isMultiplayer && !isHost) ...[
              // En multijoueur, si vous n'êtes PAS l'hôte
              const Text(
                '⏳ En attente de l\'hôte...',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.orange,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Seul le créateur de la partie peut la relancer',
                style: TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: onRestart,
                icon: const Icon(Icons.home),
                label: const Text('Retour au menu'),
              ),
            ] else ...[
              // En solo OU en multi si vous êtes l'hôte
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  FilledButton.icon(
                    onPressed: onRestart,
                    icon: Icon(isMultiplayer
                        ? Icons.refresh
                        : Icons.refresh),
                    label: Text(isMultiplayer
                        ? 'Relancer la partie'
                        : 'Rejouer'),
                  ),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Fermer'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getMedalForPosition(int position) {
    switch (position) {
      case 1:
        return '🥇';
      case 2:
        return '🥈';
      case 3:
        return '🥉';
      case 4:
        return '4️⃣';
      case 5:
        return '5️⃣';
      case 6:
        return '6️⃣';
      case 7:
        return '7️⃣';
      case 8:
        return '8️⃣';
      case 9:
        return '9️⃣';
      default:
        return '🔟'; // Pour 10+
    }
  }
}
