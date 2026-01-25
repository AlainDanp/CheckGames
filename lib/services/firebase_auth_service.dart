import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
      print('🔐 Tentative inscription: $email');
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      print('✅ Utilisateur créé: ${userCredential.user?.uid}');

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
        print('✅ Profil utilisateur créé dans Firestore');
      } catch (firestoreError) {
        print('⚠️ Erreur Firestore (profil non créé): $firestoreError');
        // Continue même si Firestore échoue - l'utilisateur est authentifié
      }

      return userCredential;
    } catch (e) {
      print('❌ Erreur inscription: $e');
      rethrow;
    }
  }

  // Connexion avec email/password
  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    try {
      print('🔐 Tentative connexion: $email');
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      print('✅ Connexion réussie: ${userCredential.user?.uid}');

      // Mettre à jour lastSeen (ne pas bloquer si ça échoue)
      try {
        await _firestore.collection('users').doc(userCredential.user!.uid).update({
          'lastSeen': FieldValue.serverTimestamp(),
        });
        print('✅ lastSeen mis à jour');
      } catch (firestoreError) {
        print('⚠️ Erreur mise à jour lastSeen: $firestoreError');
        // Continue même si la mise à jour échoue
      }

      return userCredential;
    } catch (e) {
      print('❌ Erreur connexion: $e');
      rethrow;
    }
  }

  // Connexion anonyme (pour tester rapidement)
  Future<UserCredential> signInAnonymously({String? username}) async {
    try {
      print('🔐 Tentative connexion anonyme');
      final userCredential = await _auth.signInAnonymously();
      print('✅ Connexion anonyme réussie: ${userCredential.user?.uid}');

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
        print('✅ Profil anonyme créé: $generatedUsername');
      } catch (firestoreError) {
        print('⚠️ Erreur Firestore (profil anonyme non créé): $firestoreError');
        // Continue même si Firestore échoue - l'utilisateur est authentifié
      }

      return userCredential;
    } catch (e) {
      print('❌ Erreur connexion anonyme: $e');
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
      print('📖 Lecture profil: $userId');
      final doc = await _firestore.collection('users').doc(userId).get();

      if (!doc.exists) {
        print('⚠️ Profil non trouvé, création d\'un profil par défaut');
        // Créer un profil par défaut si inexistant
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
      print('✅ Profil récupéré: ${data?['username']}');
      return data;
    } catch (e) {
      print('❌ Erreur lecture profil: $e');
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