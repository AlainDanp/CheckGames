import 'package:flutter/material.dart';
import '../../models/card_suit.dart';

class SuitPickerSheet extends StatelessWidget {
  const SuitPickerSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      (CardSuit.hearts,  '♥ Cœur'),
      (CardSuit.diamonds,'♦ Carreau'),
      (CardSuit.clubs,   '♣ Trèfle'),
      (CardSuit.spades,  '♠ Pique'),
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Choisir une couleur', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: items.map((e) {
                return ChoiceChip(
                  label: Text(e.$2),
                  selected: false,
                  onSelected: (_) => Navigator.of(context).pop(e.$1),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
