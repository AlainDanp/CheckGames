import 'package:flutter/material.dart';

/// Widget représentant le dos d'une carte (carte retournée)
class CardBackWidget extends StatelessWidget {
  final double width;
  final bool showShadow;

  const CardBackWidget({
    super.key,
    this.width = 60,
    this.showShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    final h = width * 1.45;

    return Container(
      width: width,
      height: h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: showShadow
            ? [
                const BoxShadow(
                  blurRadius: 4,
                  color: Colors.black26,
                  offset: Offset(0, 2),
                ),
              ]
            : null,
        gradient: const LinearGradient(
          colors: [
            Color(0xFF6B2C91), // Violet foncé
            Color(0xFF4A1A6B), // Violet plus foncé
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // Motif de losanges au centre
          Center(
            child: Container(
              width: width * 0.7,
              height: h * 0.8,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Center(
                child: Container(
                  width: width * 0.5,
                  height: h * 0.6,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
          // Petits points décoratifs aux coins
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.4),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.4),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: 8,
            left: 8,
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.4),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: 8,
            right: 8,
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.4),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
