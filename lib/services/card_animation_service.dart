import 'dart:async';
import 'package:flutter/material.dart';
import '../models/playing_card.dart';
import '../view/widgets/animated_card_overlay.dart';
import 'audio_service.dart';

class CardAnimationService {
  CardAnimationService._();
  static final instance = CardAnimationService._();

  Future<void> animateCardsToDiscard({
    required BuildContext context,
    required List<PlayingCard> cards,
    required List<GlobalKey> cardKeys,
    required GlobalKey discardKey,
    Duration duration = const Duration(milliseconds: 500),
  }) async {
    // Jouer le son du mouvement de carte
    AudioService.instance.playCardMove();

    // Extraire positions
    final startPositions = <Offset>[];
    for (final key in cardKeys) {
      final pos = _getPosition(key);
      if (pos == null) return; // Fallback: skip animation
      startPositions.add(pos);
    }

    final endPosition = _getPosition(discardKey);
    if (endPosition == null) return;

    // Créer overlay (chaque animation gère son propre overlay)
    final completer = Completer<void>();
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => AnimatedCardOverlay(
        cards: cards,
        startPositions: startPositions,
        endPosition: endPosition,
        duration: duration,
        onComplete: () {
          overlayEntry.remove();
          completer.complete();
        },
      ),
    );

    Overlay.of(context).insert(overlayEntry);
    return completer.future;
  }

  Offset? _getPosition(GlobalKey key) {
    final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return null;
    return renderBox.localToGlobal(Offset.zero);
  }
}
