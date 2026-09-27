import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/app_logger.dart';

class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Utilisateur actuel
  User? get currentUser => _auth.currentUser;

  // Stream d'état d'authentification
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Inscription avec email/password
  Future<UserCredential> signUp({
    required String email,
    required String password,
    required String username,
  }) async {
    try {
      appLogger.d('Tentative inscription');
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      appLogger.i('Utilisateur créé');

      // Créer le profil utilisateur dans Firestore
      try {
        await _firestore.collection('users').doc(userCredential.user!.uid).set({
          'username': username,
          'email': email,
          'avatarUrl': '',
          'wins': 0,
          'losses': 0,
          'createdAt': FieldValue.serverTimestamp(),
          'lastSeen': FieldValue.serverTimestamp(),
        });
        appLogger.i('Profil Firestore créé');
      } catch (firestoreError) {
        appLogger.w('Profil Firestore non créé', error: firestoreError);
        // Continue même si Firestore échoue - l'utilisateur est authentifié
      }

      return userCredential;
    } catch (e) {
      appLogger.e('Erreur inscription', error: e);
      rethrow;
    }
  }

  // Connexion avec email/password
  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    try {
      appLogger.d('Tentative connexion');
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      appLogger.i('Connexion réussie');

      // Mettre à jour lastSeen (ne pas bloquer si ça échoue)
      try {
        await _firestore.collection('users').doc(userCredential.user!.uid).update({
          'lastSeen': FieldValue.serverTimestamp(),
        });
        appLogger.d('lastSeen mis à jour');
      } catch (firestoreError) {
        appLogger.w('Erreur lastSeen', error: firestoreError);
        // Continue même si la mise à jour échoue
      }

      return userCredential;
    } catch (e) {
      appLogger.e('Erreur connexion', error: e);
      rethrow;
    }
  }

  // Connexion anonyme (pour tester rapidement)
  Future<UserCredential> signInAnonymously({String? username}) async {
    try {
      appLogger.d('Tentative connexion anonyme');
      final userCredential = await _auth.signInAnonymously();
      appLogger.i('Connexion anonyme réussie');

      // Créer un profil anonyme (ne pas bloquer si ça échoue)
      try {
        final generatedUsername = username ?? 'Joueur${DateTime.now().millisecondsSinceEpoch % 10000}';
        await _firestore.collection('users').doc(userCredential.user!.uid).set({
          'username': generatedUsername,
          'email': '',
          'avatarUrl': '',
          'wins': 0,
          'losses': 0,
          'createdAt': FieldValue.serverTimestamp(),
          'lastSeen': FieldValue.serverTimestamp(),
        });
        appLogger.i('Profil anonyme créé');
      } catch (firestoreError) {
        appLogger.w('Profil Firestore anonyme non créé', error: firestoreError);
        // Continue même si Firestore échoue - l'utilisateur est authentifié
      }

      return userCredential;
    } catch (e) {
      appLogger.e('Erreur connexion anonyme', error: e);
      rethrow;
    }
  }

  // Déconnexion
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Récupérer les données du profil
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      appLogger.d('Lecture profil utilisateur');
      final doc = await _firestore.collection('users').doc(userId).get();

      if (!doc.exists) {
        appLogger.w('Profil non trouvé, création par défaut');
        final defaultProfile = {
          'username': 'Joueur${DateTime.now().millisecondsSinceEpoch % 10000}',
          'email': '',
          'avatarUrl': '',
          'wins': 0,
          'losses': 0,
          'createdAt': FieldValue.serverTimestamp(),
          'lastSeen': FieldValue.serverTimestamp(),
        };
        await _firestore.collection('users').doc(userId).set(defaultProfile);
        return defaultProfile;
      }

      final data = doc.data();
      appLogger.d('Profil récupéré');
      return data;
    } catch (e) {
      appLogger.e('Erreur lecture profil', error: e);
      // Retourner un profil par défaut en cas d'erreur
      return {
        'username': 'Joueur${DateTime.now().millisecondsSinceEpoch % 10000}',
        'email': '',
        'avatarUrl': '',
        'wins': 0,
        'losses': 0,
      };
    }
  }

  // Mettre à jour le profil
  Future<void> updateProfile(String userId, Map<String, dynamic> data) async {
    await _firestore.collection('users').doc(userId).update(data);
  }
}
