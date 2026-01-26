import 'package:flutter/material.dart';
import '../../utils/responsive_sizing.dart';
import '../../services/audio_service.dart';

class PauseMenu extends StatefulWidget {
  final VoidCallback onResume;
  final VoidCallback onQuit;
  final VoidCallback? onRestart; // Callback pour relancer
  final VoidCallback? onLeaveGame; // Callback pour quitter la partie (multi)
  final VoidCallback? onStopGame; // Callback pour arrêter la partie (solo) et retourner au menu
  final bool isMultiplayer; // Indique si c'est une partie multi
  final bool isHost; // Indique si le joueur est l'hôte

  const PauseMenu({
    super.key,
    required this.onResume,
    required this.onQuit,
    this.onRestart,
    this.onLeaveGame,
    this.onStopGame,
    this.isMultiplayer = false,
    this.isHost = false,
  });

  @override
  State<PauseMenu> createState() => _PauseMenuState();
}

class _PauseMenuState extends State<PauseMenu> {
  bool _soundEnabled = true;
  bool _musicEnabled = true;

  @override
  void initState() {
    super.initState();
    _soundEnabled = AudioService.instance.soundEnabled;
    _musicEnabled = AudioService.instance.musicEnabled;
  }

  void _showRestartConfirmation(BuildContext context) {
    print('🔍 Affichage du dialogue de confirmation de relance');
    _showConfirmationDialog(
      context: context,
      title: 'Relancer la partie ?',
      message: 'Voulez-vous vraiment relancer la partie ?\n\n'
          'Cela réinitialisera le jeu pour tous les joueurs.',
      icon: Icons.refresh,
      iconColor: Colors.orange,
      confirmText: 'Relancer',
      confirmColor: Colors.orange.shade700,
      onConfirm: () async {
        print('🔍 Confirmation de la relance');
        await Future.delayed(const Duration(milliseconds: 50));
        widget.onRestart?.call();
      },
    );
  }

  void _showLeaveGameConfirmation(BuildContext context) {
    print('🔍 Affichage du dialogue de confirmation de sortie');
    _showConfirmationDialog(
      context: context,
      title: 'Quitter la partie ?',
      message: 'Voulez-vous vraiment quitter la partie ?\n\n'
          'Vous abandonnerez et les autres joueurs continueront sans vous.',
      icon: Icons.exit_to_app,
      iconColor: Colors.red,
      confirmText: 'Quitter',
      confirmColor: Colors.red.shade700,
      onConfirm: () async {
        print('🔍 Confirmation de sortie');
        await Future.delayed(const Duration(milliseconds: 50));
        widget.onLeaveGame?.call();
      },
    );
  }

  void _showStopGameConfirmation(BuildContext context) {
    print('🔍 Affichage du dialogue de confirmation d\'arrêt');
    _showConfirmationDialog(
      context: context,
      title: 'Arrêter la partie ?',
      message: 'Voulez-vous vraiment arrêter la partie ?\n\n'
          'Vous retournerez au menu principal.',
      icon: Icons.stop_circle_outlined,
      iconColor: Colors.red,
      confirmText: 'Arrêter',
      confirmColor: Colors.red.shade700,
      onConfirm: () async {
        print('🔍 Confirmation d\'arrêt de partie');
        await Future.delayed(const Duration(milliseconds: 50));
        widget.onStopGame?.call();
      },
    );
  }

  void _showConfirmationDialog({
    required BuildContext context,
    required String title,
    required String message,
    required IconData icon,
    required Color iconColor,
    required String confirmText,
    required Color confirmColor,
    required VoidCallback onConfirm,
  }) {
    final sizing = context.sizing;
    late OverlayEntry confirmationOverlay;

    confirmationOverlay = OverlayEntry(
      builder: (context) => Material(
        color: Colors.black.withOpacity(0.6),
        child: Center(
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 40 * sizing.scaleFactor),
            padding: EdgeInsets.all(24 * sizing.scaleFactor),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: iconColor, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 30,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: iconColor, size: 36),
                    SizedBox(width: 12 * sizing.scaleFactor),
                    Flexible(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: sizing.fontSize(24).clamp(20.0, 28.0),
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 24 * sizing.scaleFactor),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: sizing.fontSize(16).clamp(14.0, 18.0),
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 28 * sizing.scaleFactor),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          print('🔍 Annulation');
                          AudioService.instance.playButtonClick();
                          confirmationOverlay.remove();
                        },
                        icon: const Icon(Icons.close),
                        label: Text(
                          'Annuler',
                          style: TextStyle(
                            fontSize: sizing.fontSize(16).clamp(14.0, 18.0),
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black87,
                          padding: EdgeInsets.symmetric(vertical: 16 * sizing.scaleFactor),
                          side: const BorderSide(color: Colors.grey, width: 2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 16 * sizing.scaleFactor),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          AudioService.instance.playButtonClick();
                          confirmationOverlay.remove();
                          onConfirm();
                        },
                        icon: Icon(icon, color: Colors.white),
                        label: Text(
                          confirmText,
                          style: TextStyle(
                            fontSize: sizing.fontSize(16).clamp(14.0, 18.0),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: confirmColor,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 16 * sizing.scaleFactor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(confirmationOverlay);
  }

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    // Debug: vérifier les conditions pour afficher le bouton
    print('🔍 PauseMenu - isMultiplayer: ${widget.isMultiplayer}, isHost: ${widget.isHost}, onRestart != null: ${widget.onRestart != null}');

    return Material(
      color: Colors.black.withOpacity(0.7),
      child: Center(
        child: Container(
          padding: EdgeInsets.all(30 * sizing.scaleFactor),
          margin: EdgeInsets.symmetric(horizontal: 40 * sizing.scaleFactor),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF145A32), Color(0xFF0B3D2E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'PAUSE',
                style: TextStyle(
                  fontSize: sizing.fontSize(36).clamp(28.0, 48.0),
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 3,
                ),
              ),
              SizedBox(height: 30 * sizing.scaleFactor),

              // Option Effets sonores
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 20 * sizing.scaleFactor,
                  vertical: 12 * sizing.scaleFactor,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _soundEnabled ? Icons.volume_up : Icons.volume_off,
                          color: Colors.white,
                          size: 24 * sizing.scaleFactor,
                        ),
                        SizedBox(width: 12 * sizing.scaleFactor),
                        Text(
                          'Effets sonores',
                          style: TextStyle(
                            fontSize: sizing.fontSize(16).clamp(14.0, 18.0),
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Switch(
                      value: _soundEnabled,
                      onChanged: (value) {
                        setState(() {
                          _soundEnabled = value;
                          AudioService.instance.setSoundEnabled(value);
                        });
                      },
                      activeColor: const Color(0xFF0E766E),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 12 * sizing.scaleFactor),

              // Option Musique de fond
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 20 * sizing.scaleFactor,
                  vertical: 12 * sizing.scaleFactor,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _musicEnabled ? Icons.music_note : Icons.music_off,
                          color: Colors.white,
                          size: 24 * sizing.scaleFactor,
                        ),
                        SizedBox(width: 12 * sizing.scaleFactor),
                        Text(
                          'Musique',
                          style: TextStyle(
                            fontSize: sizing.fontSize(16).clamp(14.0, 18.0),
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Switch(
                      value: _musicEnabled,
                      onChanged: (value) {
                        setState(() {
                          _musicEnabled = value;
                          AudioService.instance.setMusicEnabled(value, autoStart: true);
                        });
                      },
                      activeColor: const Color(0xFF0E766E),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 30 * sizing.scaleFactor),

              // Bouton Reprendre
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    AudioService.instance.playButtonClick();
                    widget.onResume();
                  },
                  icon: const Icon(Icons.play_arrow, color: Colors.white),
                  label: Text(
                    'Reprendre',
                    style: TextStyle(
                      fontSize: sizing.fontSize(18).clamp(16.0, 20.0),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0E766E),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16 * sizing.scaleFactor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

              SizedBox(height: 12 * sizing.scaleFactor),

              // Bouton Relancer (uniquement pour l'hôte en multi)
              if (widget.isMultiplayer && widget.isHost && widget.onRestart != null)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      print('🔍 Clic sur bouton Relancer la partie');
                      AudioService.instance.playButtonClick();
                      _showRestartConfirmation(context);
                    },
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    label: Text(
                      'Relancer la partie',
                      style: TextStyle(
                        fontSize: sizing.fontSize(18).clamp(16.0, 20.0),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade700,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 16 * sizing.scaleFactor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),

              // Message pour les non-hôtes en multijoueur
              if (widget.isMultiplayer && !widget.isHost)
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    horizontal: 20 * sizing.scaleFactor,
                    vertical: 12 * sizing.scaleFactor,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white30, width: 1),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.white70, size: 20),
                      SizedBox(width: 12 * sizing.scaleFactor),
                      Expanded(
                        child: Text(
                          'Seul l\'hôte peut relancer la partie',
                          style: TextStyle(
                            fontSize: sizing.fontSize(14).clamp(12.0, 16.0),
                            color: Colors.white70,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              SizedBox(height: 12 * sizing.scaleFactor),

              // Bouton Quitter / Nouvelle Partie
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    AudioService.instance.playButtonClick();
                    if (widget.isMultiplayer && widget.onLeaveGame != null) {
                      // En multijoueur: afficher confirmation de sortie
                      _showLeaveGameConfirmation(context);
                    } else {
                      // En solo: nouvelle partie directement
                      widget.onQuit();
                    }
                  },
                  icon: Icon(
                    widget.isMultiplayer ? Icons.exit_to_app : Icons.refresh,
                    color: widget.isMultiplayer ? Colors.red.shade300 : Colors.white70,
                  ),
                  label: Text(
                    widget.isMultiplayer ? 'Quitter la partie' : 'Nouvelle Partie',
                    style: TextStyle(
                      fontSize: sizing.fontSize(18).clamp(16.0, 20.0),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: widget.isMultiplayer ? Colors.red.shade300 : Colors.white70,
                    padding: EdgeInsets.symmetric(vertical: 16 * sizing.scaleFactor),
                    side: BorderSide(
                      color: widget.isMultiplayer ? Colors.red.shade300 : Colors.white70,
                      width: 2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

              // Bouton Arrêter la partie (solo uniquement)
              if (!widget.isMultiplayer && widget.onStopGame != null) ...[
                SizedBox(height: 12 * sizing.scaleFactor),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      AudioService.instance.playButtonClick();
                      _showStopGameConfirmation(context);
                    },
                    icon: Icon(
                      Icons.stop_circle_outlined,
                      color: Colors.red.shade300,
                    ),
                    label: Text(
                      'Arrêter la partie',
                      style: TextStyle(
                        fontSize: sizing.fontSize(18).clamp(16.0, 20.0),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade300,
                      padding: EdgeInsets.symmetric(vertical: 16 * sizing.scaleFactor),
                      side: BorderSide(
                        color: Colors.red.shade300,
                        width: 2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
