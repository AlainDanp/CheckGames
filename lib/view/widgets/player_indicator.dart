import 'package:flutter/material.dart';

class PlayerIndicator extends StatelessWidget {
  final String playerName;
  final bool isActive;
  final int cardCount;

  const PlayerIndicator({
    required this.playerName,
    required this.isActive,
    required this.cardCount,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isActive ? Colors.green.withOpacity(0.2) : Colors.grey.withOpacity(0.1),
        border: Border.all(
          color: isActive ? Colors.green : Colors.grey,
          width: isActive ? 3 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: isActive ? [
          BoxShadow(
            color: Colors.green.withOpacity(0.5),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ] : null,
      ),
      child: Column(
        children: [
          // Indicateur animé
          if (isActive)
            Icon(Icons.play_arrow, color: Colors.green, size: 32),

          Text(
            playerName,
            style: TextStyle(
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              fontSize: isActive ? 18 : 16,
            ),
          ),

          Text('$cardCount cartes', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
