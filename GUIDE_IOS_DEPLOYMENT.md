# 📱 Guide de Déploiement iOS - CheckGames

Guide complet pour créer, configurer et déployer la version iPhone de CheckGames.

---

## 📋 Table des matières

1. [Prérequis](#-prérequis)
2. [Configuration initiale](#-configuration-initiale)
3. [Configuration Firebase iOS](#-configuration-firebase-ios)
4. [Permissions et capacités](#-permissions-et-capacités)
5. [Tests et débogage](#-tests-et-débogage)
6. [Build de production](#-build-de-production)
7. [Publication sur l'App Store](#-publication-sur-lapp-store)
8. [Troubleshooting](#-troubleshooting)

---

## 🛠 Prérequis

### Matériel et logiciels requis

- ✅ **Un Mac** (macOS 12.0 ou supérieur recommandé)
- ✅ **Xcode 14+** (téléchargeable depuis le Mac App Store)
- ✅ **Flutter SDK** installé et configuré
- ✅ **CocoaPods** (gestionnaire de dépendances iOS)
- ✅ **Un iPhone** (optionnel, pour tests physiques)

### Comptes nécessaires

- 🆓 **Compte Apple ID** (gratuit) - pour tests en développement
- 💰 **Apple Developer Program** (99€/an) - obligatoire pour publier sur l'App Store

### Vérifier votre installation

```bash
# Vérifier Flutter
flutter doctor

# Vérifier que iOS est disponible
flutter doctor -v

# Installer CocoaPods si nécessaire
sudo gem install cocoapods
```

---

## ⚙️ Configuration initiale

### Étape 1 : Cloner et préparer le projet

```bash
# Cloner le projet (si ce n'est pas déjà fait)
git clone https://github.com/AlainDanp/CheckGames.git
cd CheckGames

# Installer les dépendances Flutter
flutter pub get

# Nettoyer et récupérer les dépendances
flutter clean
flutter pub get
```

### Étape 2 : Installer les dépendances iOS

```bash
# Naviguer vers le dossier iOS
cd ios

# Installer les pods (dépendances iOS)
pod install

# Si erreur, essayer de mettre à jour le repo
pod repo update
pod install

# Retourner à la racine
cd ..
```

### Étape 3 : Ouvrir le projet dans Xcode

```bash
# Ouvrir le workspace (IMPORTANT : pas le .xcodeproj)
open ios/Runner.xcworkspace
```

### Étape 4 : Configurer l'identité de l'application

Dans Xcode :

1. Sélectionner **Runner** dans le navigateur de projet (panneau gauche)
2. Aller dans l'onglet **Signing & Capabilities**
3. Cocher **Automatically manage signing**
4. Sélectionner votre **Team** (compte Apple Developer)
5. Modifier le **Bundle Identifier** si nécessaire :
   - Format recommandé : `com.votreNom.checkgame`
   - Exemple : `com.alaindanp.checkgame`

> ⚠️ **Important** : Le Bundle Identifier doit être unique et correspondre à celui configuré dans Firebase.

---

## 🔥 Configuration Firebase iOS

### Étape 1 : Créer l'application iOS dans Firebase Console

1. Aller sur [Firebase Console](https://console.firebase.google.com/)
2. Sélectionner votre projet CheckGames
3. Cliquer sur **⚙️ Paramètres du projet**
4. Défiler jusqu'à **Vos applications**
5. Cliquer sur **Ajouter une application** → **iOS**
6. Entrer votre **Bundle Identifier** (celui configuré dans Xcode)
7. Donner un surnom (ex: "CheckGames iOS")
8. **Télécharger `GoogleService-Info.plist`**

### Étape 2 : Ajouter le fichier de configuration

```bash
# Copier GoogleService-Info.plist dans le dossier ios/Runner/
# Depuis le Finder ou en ligne de commande :
cp ~/Downloads/GoogleService-Info.plist ios/Runner/
```

Dans Xcode :

1. Faire un clic droit sur **Runner** (dossier jaune)
2. Sélectionner **Add Files to "Runner"...**
3. Choisir `GoogleService-Info.plist`
4. ✅ Cocher **Copy items if needed**
5. ✅ Vérifier que **Runner** est sélectionné dans **Add to targets**

### Étape 3 : Vérifier l'intégration Firebase

Ouvrir `ios/Runner/AppDelegate.swift` et vérifier que Firebase est initialisé :

```swift
import UIKit
import Flutter
import Firebase  // ← Doit être présent

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    FirebaseApp.configure()  // ← Doit être présent
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

---

## 🔐 Permissions et capacités

### Étape 1 : Configurer les permissions dans Info.plist

Ouvrir `ios/Runner/Info.plist` et ajouter les permissions nécessaires :

```xml
<dict>
    <!-- ... autres clés ... -->

    <!-- Permission pour la caméra (image_picker) -->
    <key>NSCameraUsageDescription</key>
    <string>CheckGames a besoin d'accéder à votre caméra pour prendre des photos de profil</string>

    <!-- Permission pour la galerie photos -->
    <key>NSPhotoLibraryUsageDescription</key>
    <string>CheckGames a besoin d'accéder à vos photos pour choisir une image de profil</string>

    <!-- Permission pour sauvegarder des photos -->
    <key>NSPhotoLibraryAddUsageDescription</key>
    <string>CheckGames souhaite sauvegarder des images dans votre galerie</string>

    <!-- Permission pour les notifications -->
    <key>UIBackgroundModes</key>
    <array>
        <string>remote-notification</string>
    </array>
</dict>
```

### Étape 2 : Activer les capacités (Capabilities)

Dans Xcode, onglet **Signing & Capabilities** :

1. Cliquer sur **+ Capability**
2. Ajouter :
   - ✅ **Push Notifications** (pour Firebase Messaging)
   - ✅ **Background Modes** → cocher **Remote notifications**

### Étape 3 : Configurer les notifications push (APNs)

Pour Firebase Cloud Messaging :

1. Aller dans [Apple Developer Center](https://developer.apple.com/account/)
2. Naviguer vers **Certificates, Identifiers & Profiles**
3. Créer une **APNs Key** :
   - Cliquer sur **Keys** → **+**
   - Cocher **Apple Push Notifications service (APNs)**
   - Télécharger le fichier `.p8`
4. Dans Firebase Console :
   - Aller dans **Paramètres du projet** → **Cloud Messaging**
   - Uploader la clé APNs dans la section iOS
   - Entrer le **Key ID** et le **Team ID**

---

## 🧪 Tests et débogage

### Option 1 : Tester sur le simulateur iOS

```bash
# Lister les simulateurs disponibles
flutter devices

# Lancer le simulateur iPhone
open -a Simulator

# Ou choisir un modèle spécifique
xcrun simctl boot "iPhone 15 Pro"

# Lancer l'application
flutter run
```

### Option 2 : Tester sur un iPhone physique

#### 2.1 Activer le mode développeur sur l'iPhone

1. Brancher l'iPhone au Mac via USB
2. Sur l'iPhone : **Réglages** → **Confidentialité et sécurité** → **Mode développeur**
3. Activer et redémarrer l'iPhone
4. Confirmer l'activation

#### 2.2 Faire confiance à l'ordinateur

- Sur l'iPhone, accepter **Faire confiance à cet ordinateur**
- Entrer le code de l'iPhone si demandé

#### 2.3 Déployer l'application

```bash
# Lister les appareils connectés
flutter devices

# Lancer sur l'appareil
flutter run -d <device-id>

# Exemple :
flutter run -d 00008030-001234567890001E
```

#### 2.4 Faire confiance au développeur (première installation)

Sur l'iPhone :
1. **Réglages** → **Général** → **Gestion des appareils**
2. Sélectionner votre compte développeur
3. Cliquer sur **Faire confiance à "Votre Nom"**

### Option 3 : Mode debug avec rechargement à chaud

```bash
# Lancer en mode debug avec hot reload
flutter run --debug

# Rechargement à chaud : appuyer sur 'r'
# Rechargement complet : appuyer sur 'R'
# Quitter : appuyer sur 'q'
```

---

## 📦 Build de production

### Étape 1 : Préparer l'icône de l'application

Votre projet utilise déjà `flutter_launcher_icons`. Vérifier `pubspec.yaml` :

```yaml
flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/icone/carte.png"
  remove_alpha_ios: true
```

Générer les icônes :

```bash
flutter pub run flutter_launcher_icons
```

### Étape 2 : Configurer le splash screen iOS

Le projet utilise `flutter_native_splash`. Vérifier la configuration :

```yaml
flutter_native_splash:
  color: "#000000"
  image: assets/icone/carte.png
  color_dark: "#000000"
  image_dark: assets/icone/carte.png
```

Générer les splash screens :

```bash
flutter pub run flutter_native_splash:create
```

### Étape 3 : Configurer la version de l'application

Ouvrir `pubspec.yaml` et mettre à jour :

```yaml
version: 1.0.0+1  # Format: version_name+build_number
```

### Étape 4 : Build de production

```bash
# Build en mode release
flutter build ios --release

# Ou avec des optimisations supplémentaires
flutter build ios --release --obfuscate --split-debug-info=./debug-info
```

### Étape 5 : Créer une archive Xcode

Dans Xcode :

1. Sélectionner **Any iOS Device (arm64)** comme destination (pas un simulateur)
2. Menu **Product** → **Scheme** → **Edit Scheme**
3. Dans **Run** → **Build Configuration** → sélectionner **Release**
4. Menu **Product** → **Archive**
5. Attendre la fin de l'archivage (peut prendre plusieurs minutes)

---

## 🚀 Publication sur l'App Store

### Prérequis

- ✅ Compte **Apple Developer Program** actif (99€/an)
- ✅ Application archivée avec succès
- ✅ Captures d'écran de l'app (différentes tailles d'iPhone)
- ✅ Icône de l'app (1024x1024px)
- ✅ Description, mots-clés, catégorie préparés

### Étape 1 : Créer l'application dans App Store Connect

1. Aller sur [App Store Connect](https://appstoreconnect.apple.com/)
2. Cliquer sur **Mes Apps** → **+** → **Nouvelle app**
3. Remplir les informations :
   - **Plateformes** : iOS
   - **Nom** : CheckGames
   - **Langue principale** : Français
   - **Bundle ID** : sélectionner celui configuré précédemment
   - **SKU** : identifiant unique (ex: `checkgames-001`)
   - **Accès utilisateur** : Accès complet ou limité

### Étape 2 : Préparer les métadonnées

Dans App Store Connect → votre app :

#### Informations de l'app
- **Nom** : CheckGames
- **Sous-titre** : (optionnel, max 30 caractères)
- **Catégorie principale** : Jeux → Cartes
- **Catégorie secondaire** : (optionnel)

#### Description
Rédiger une description attrayante :

```
CheckGames - Le jeu de cartes stratégique et addictif !

Affrontez des adversaires dans des parties endiablées où stratégie et rapidité font la différence. 

🎮 MODES DE JEU
• Mode Solo : affrontez des bots intelligents
• Mode Arcade : défis chronométrés
• Mode Survie : jusqu'où irez-vous ?
• Mode Multijoueur : jouez avec vos amis en temps réel

🌟 FONCTIONNALITÉS
• Animations fluides et interface intuitive
• Effets sonores immersifs
• Notifications de jeu
• Sauvegarde automatique
• Tutoriel interactif pour les débutants

Téléchargez maintenant et devenez le maître du jeu !
```

#### Captures d'écran
Préparer des captures pour :
- **iPhone 6.7"** (iPhone 15 Pro Max, obligatoire)
- **iPhone 6.5"** (iPhone 11 Pro Max, obligatoire)
- 3 à 10 captures par taille

Utiliser le simulateur ou un appareil :
```bash
# Sur simulateur : Cmd + S pour capturer
# Les screenshots sont sauvegardés sur le Bureau
```

#### Icône de l'application
- Taille : **1024x1024 pixels**
- Format : PNG, sans transparence
- Pas de coins arrondis (Apple les ajoute automatiquement)

### Étape 3 : Uploader le build

Dans Xcode Organizer (s'ouvre après l'archivage) :

1. Sélectionner l'archive créée
2. Cliquer sur **Distribute App**
3. Sélectionner **App Store Connect**
4. Choisir **Upload**
5. Suivre les étapes :
   - ✅ Include bitcode (si disponible)
   - ✅ Upload your app's symbols
   - ✅ Automatically manage signing
6. Cliquer sur **Upload**
7. Attendre la fin de l'upload (peut prendre 10-30 minutes)

### Étape 4 : Associer le build à la version

Retourner dans App Store Connect :

1. Aller dans **Informations sur la version**
2. Descendre jusqu'à **Build**
3. Cliquer sur **+ version** ou **Sélectionner un build**
4. Choisir le build uploadé (peut prendre 15-60 minutes pour apparaître)
5. Sauvegarder

### Étape 5 : Informations sur la confidentialité

Répondre aux questions sur la collecte de données :

Pour CheckGames (basé sur Firebase) :
- **Identifiants** : Oui (Firebase Auth)
- **Données d'utilisation** : Oui (Analytics optionnel)
- **Coordonnées** : Selon implémentation

### Étape 6 : Classification du contenu

Répondre au questionnaire sur le contenu :
- Violence : Aucune
- Contenu sexuel : Aucun
- Langage grossier : Aucun
- Classification : 4+ (tout public)

### Étape 7 : Soumettre pour révision

1. Vérifier que toutes les sections sont complètes (✅ verts)
2. Cliquer sur **Ajouter pour révision**
3. Répondre aux questions de conformité à l'export
4. Cliquer sur **Soumettre pour révision**

### Étape 8 : Attendre la révision d'Apple

- ⏱ **Délai moyen** : 24-48 heures
- 📧 Vous recevrez des emails sur l'avancement
- 📊 Statuts possibles :
  - **En attente de révision** : dans la file
  - **En cours de révision** : examen en cours
  - **Prêt pour la vente** : approuvé ! 🎉
  - **Rejeté** : corrections nécessaires

---

## 🔧 Troubleshooting

### Problème : Pod install échoue

```bash
# Solution 1 : Mettre à jour CocoaPods
sudo gem install cocoapods

# Solution 2 : Nettoyer et réinstaller
cd ios
rm -rf Pods Podfile.lock
pod repo update
pod install
cd ..
```

### Problème : "No valid code signing certificate found"

**Solution :**
1. Dans Xcode, aller dans **Preferences** → **Accounts**
2. Vérifier que votre Apple ID est connecté
3. Cliquer sur **Manage Certificates**
4. S'assurer qu'un certificat de développement existe

### Problème : Firebase ne se connecte pas

**Vérifier :**
- ✅ `GoogleService-Info.plist` est dans `ios/Runner/`
- ✅ Le Bundle ID correspond entre Xcode et Firebase Console
- ✅ `FirebaseApp.configure()` est appelé dans `AppDelegate.swift`

### Problème : Notifications push ne fonctionnent pas

**Vérifier :**
- ✅ Capability **Push Notifications** activée dans Xcode
- ✅ Clé APNs uploadée dans Firebase Console
- ✅ Tester sur un appareil physique (pas simulateur)
- ✅ Permissions notifications acceptées par l'utilisateur

### Problème : "Building for iOS, but the linked and embedded framework was built for iOS Simulator"

```bash
# Solution : Exclure l'architecture arm64 du simulateur
# Dans Xcode → Target Runner → Build Settings
# Chercher "Excluded Architectures"
# Ajouter "arm64" pour "Any iOS Simulator SDK"
```

### Problème : App rejetée par Apple

**Raisons courantes :**
- Crash au lancement
- Fonctionnalités non documentées
- Vie privée : permissions non justifiées
- Contenu inapproprié
- Liens vers stores externes

**Actions :**
1. Lire attentivement le message de rejet
2. Corriger les problèmes mentionnés
3. Tester exhaustivement
4. Soumettre à nouveau avec une note expliquant les corrections

---

## 📞 Ressources utiles

### Documentation officielle
- [Flutter iOS Deployment](https://docs.flutter.dev/deployment/ios)
- [Apple Developer Documentation](https://developer.apple.com/documentation/)
- [Firebase iOS Setup](https://firebase.google.com/docs/ios/setup)
- [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)

### Outils
- [App Store Connect](https://appstoreconnect.apple.com/)
- [Apple Developer Center](https://developer.apple.com/account/)
- [Firebase Console](https://console.firebase.google.com/)

### Support
- [Stack Overflow - Flutter iOS](https://stackoverflow.com/questions/tagged/flutter+ios)
- [Flutter Discord](https://discord.gg/flutter)
- [Apple Developer Forums](https://developer.apple.com/forums/)

---

## ✅ Checklist finale avant publication

### Configuration
- [ ] Bundle Identifier configuré et unique
- [ ] GoogleService-Info.plist ajouté
- [ ] Permissions Info.plist configurées
- [ ] Capacités (Push, Background) activées
- [ ] Icônes et splash screen générés
- [ ] Version et build number mis à jour

### Tests
- [ ] Tests sur simulateur iOS réussis
- [ ] Tests sur iPhone physique réussis
- [ ] Notifications push testées et fonctionnelles
- [ ] Firebase Auth et Firestore fonctionnent
- [ ] Audio et vibrations fonctionnent
- [ ] Image picker fonctionne

### App Store Connect
- [ ] Application créée dans App Store Connect
- [ ] Description et mots-clés rédigés
- [ ] Captures d'écran uploadées (toutes tailles)
- [ ] Icône 1024x1024 uploadée
- [ ] Build uploadé et traité
- [ ] Build associé à la version
- [ ] Informations de confidentialité remplies
- [ ] Classification du contenu complétée

### Juridique
- [ ] Politique de confidentialité rédigée (si collecte de données)
- [ ] Conditions d'utilisation rédigées
- [ ] Conformité RGPD vérifiée (utilisateurs européens)

---

## 🎉 Félicitations !

Une fois votre application approuvée, elle sera disponible sur l'App Store pour des millions d'utilisateurs iOS !

**Prochaines étapes :**
- Surveiller les avis utilisateurs
- Répondre aux feedbacks
- Planifier les mises à jour
- Analyser les métriques dans App Store Connect

**Bonne chance avec CheckGames sur iOS ! 🚀📱**

---

*Guide créé le 17 février 2026*  
*Version : 1.0*  
*Projet : CheckGames par Alain DATOUO*
