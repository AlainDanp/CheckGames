import 'package:flutter/material.dart';

enum NotificationType {success, warning, error, info, achievement }

class InAppNotification {
  final String title;
  final String? message;
  final NotificationType type;
  final Duration duration;
  final VoidCallback? onTap;
  final IconData? icon;

  const InAppNotification({
    required this.title,
    this.message,
    this.type = NotificationType.info,
    this.duration = const Duration(seconds: 3),
    this.onTap,
    this.icon,
  });
}

class InAppNotificationService {
  static final InAppNotificationService instance = InAppNotificationService._();
  InAppNotificationService._();

  /// Clé du navigator (doit être assignée depuis main.dart)
  GlobalKey<NavigatorState>? navigatorKey;
  OverlayEntry? _currentOverlay;

  BuildContext? get _context => navigatorKey?.currentContext;

  /// Afficher une notification en haut de l'écran
  void show(InAppNotification notification) {
    if (_context == null) return;

    // Fermer la notification précédente
    _dismiss();

    final overlay = Overlay.of(_context!);

    _currentOverlay = OverlayEntry(
      builder: (context) => _NotificationWidget(
        notification: notification,
        onDismiss: _dismiss,
      ),
    );

    overlay.insert(_currentOverlay!);

    // Auto-dismiss après la durée
    Future.delayed(notification.duration, _dismiss);
  }

  void _dismiss() {
    if (_currentOverlay != null) {
      _currentOverlay!.remove();
      _currentOverlay = null;
    }
  }

  /// Raccourcis
  void showSuccess(String title, {String? message}) {
    show(InAppNotification(
      title: title,
      message: message,
      type: NotificationType.success,
      icon: Icons.check_circle,
    ));
  }

  void showError(String title, {String? message}) {
    show(InAppNotification(
      title: title,
      message: message,
      type: NotificationType.error,
      icon: Icons.error,
    ));
  }

  void showAchievement(String title, {String? message}) {
    show(InAppNotification(
      title: title,
      message: message,
      type: NotificationType.achievement,
      icon: Icons.emoji_events,
      duration: const Duration(seconds: 4),
    ));
  }

  void showInfo(String title, {String? message}) {
    show(InAppNotification(
      title: title,
      message: message,
      type: NotificationType.info,
      icon: Icons.info,
    ));
  }
}

class _NotificationWidget extends StatefulWidget {
  final InAppNotification notification;
  final VoidCallback onDismiss;

  const _NotificationWidget({
    required this.notification,
    required this.onDismiss,
  });

  @override
  State<_NotificationWidget> createState() => _NotificationWidgetState();
}

class _NotificationWidgetState extends State<_NotificationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(_controller);

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _getColor() {
    switch (widget.notification.type) {
      case NotificationType.success:
        return Colors.green;
      case NotificationType.warning:
        return Colors.orange;
      case NotificationType.error:
        return Colors.red;
      case NotificationType.achievement:
        return Colors.amber;
      case NotificationType.info:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: () {
                widget.notification.onTap?.call();
                widget.onDismiss();
              },
              onHorizontalDragEnd: (_) => widget.onDismiss(),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _getColor(),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: _getColor().withOpacity(0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    if (widget.notification.icon != null) ...[
                      Icon(
                        widget.notification.icon,
                        color: Colors.white,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.notification.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          if (widget.notification.message != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              widget.notification.message!,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: widget.onDismiss,
                      icon: const Icon(Icons.close, color: Colors.white70),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}