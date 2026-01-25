import 'package:flutter/material.dart';

/// Utilitaire de dimensionnement responsive pour le jeu de cartes
/// Conçu pour les téléphones en mode portrait avec largeur minimale 430px
class ResponsiveSizing {
  final BuildContext context;

  ResponsiveSizing(this.context);

  // Obtenir la largeur de l'écran
  double get screenWidth => MediaQuery.of(context).size.width;

  // Obtenir la hauteur de l'écran
  double get screenHeight => MediaQuery.of(context).size.height;

  // Largeur de référence de base (desktop/grand téléphone)
  // Ajusté pour un bon équilibre sur différentes tailles d'écran
  static const double baseWidth = 430.0;

  // Facteur d'échelle basé sur la largeur de l'écran
  // Clamp réduit pour éviter les overflows sur petits écrans
  double get scaleFactor => (screenWidth / baseWidth).clamp(0.65, 1.0);

  // --- DIMENSIONS DES CARTES ---

  /// Largeur de carte standard pour la main du joueur (défaut: 84px)
  /// Réduite pour mobile pour mieux voir le centre
  double get cardWidth => (60.0 * scaleFactor).clamp(50.0, 75.0);

  /// Largeur de carte pour la pioche/défausse (défaut: 84-90px)
  /// Réduite pour mobile
  double get tableCardWidth => 70.0 * scaleFactor;

  /// Largeur de carte pour les adversaires (défaut: 60px)
  /// Réduite pour mobile pour éviter overflow
  double get opponentCardWidth => (40.0 * scaleFactor).clamp(30.0, 50.0);

  /// Hauteur de carte basée sur la largeur (maintient le ratio 1.45)
  double cardHeight(double width) => width * 1.45;

  // --- DIMENSIONS DE L'ÉVENTAIL ---

  /// Rayon de l'éventail (défaut: 500px)
  /// Pour mobile, on réduit proportionnellement à la largeur d'écran
  double get fanRadius => screenWidth * 1.15; // ~494px à 430px de largeur

  /// Espacement des cartes dans l'éventail (défaut: 50px)
  double get fanCardSpacing {
    // Espacement dynamique basé sur le nombre de cartes et la largeur d'écran
    // Ceci sera ajusté par carte dans HandFanWidget
    return 50.0 * scaleFactor;
  }

  // --- ESPACEMENTS ---

  /// Grand espacement (défaut: 24px)
  double get spacingLarge => 24.0 * scaleFactor;

  /// Espacement moyen (défaut: 16px)
  double get spacingMedium => 16.0 * scaleFactor;

  /// Petit espacement (défaut: 12px)
  double get spacingSmall => 12.0 * scaleFactor;

  /// Très petit espacement (défaut: 8px)
  double get spacingXSmall => 8.0 * scaleFactor;

  /// Espacement pour les cartes des adversaires (défaut: 8px)
  double get opponentCardSpacing => 8.0 * scaleFactor;

  /// Padding horizontal pour les adversaires (défaut: 24px)
  /// Réduit pour éviter l'overflow sur petits écrans
  double get opponentHorizontalPadding => (18.0 * scaleFactor).clamp(10.0, 24.0);

  // --- TAILLES DE POLICE (si nécessaire) ---

  /// Mettre à l'échelle la taille de police proportionnellement
  double fontSize(double baseSize) => baseSize * scaleFactor;

  // --- MÉTHODES UTILITAIRES ---

  /// Obtenir un SizedBox responsive pour espacement vertical
  SizedBox verticalSpace(double height) => SizedBox(height: height * scaleFactor);

  /// Obtenir un SizedBox responsive pour espacement horizontal
  SizedBox horizontalSpace(double width) => SizedBox(width: width * scaleFactor);
}

/// Extension pour accéder facilement à ResponsiveSizing depuis BuildContext
extension ResponsiveSizingExtension on BuildContext {
  ResponsiveSizing get sizing => ResponsiveSizing(this);
}
