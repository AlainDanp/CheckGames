import 'package:flutter/material.dart';
import '../../utils/responsive_sizing.dart';

class ErrorMessageOverlay extends StatefulWidget {
  final String message;
  final VoidCallback onComplete;

  const ErrorMessageOverlay({
    super.key,
    required this.message,
    required this.onComplete,
  });

  @override
  State<ErrorMessageOverlay> createState() => _ErrorMessageOverlayState();
}

class _ErrorMessageOverlayState extends State<ErrorMessageOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    // Animation de slide (descend depuis le haut)
    _slideAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: -100.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(0.0),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: -100.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 20,
      ),
    ]).animate(_controller);

    // Animation de fade
    _fadeAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0),
        weight: 20,
      ),
    ]).animate(_controller);

    // Démarrer l'animation
    _controller.forward().then((_) => widget.onComplete());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned(
          top: _slideAnimation.value,
          left: 0,
          right: 0,
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 20 * sizing.scaleFactor,
                vertical: 10 * sizing.scaleFactor,
              ),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 20 * sizing.scaleFactor,
                    vertical: 15 * sizing.scaleFactor,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.shade600,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: Colors.white,
                        size: 24 * sizing.scaleFactor,
                      ),
                      SizedBox(width: 12 * sizing.scaleFactor),
                      Expanded(
                        child: Text(
                          widget.message,
                          style: TextStyle(
                            fontSize: sizing.fontSize(16).clamp(14.0, 18.0),
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
