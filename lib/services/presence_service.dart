import 'package:firebase_database/firebase_database.dart';
import '../utils/app_logger.dart';

class PresenceService {
  static final PresenceService instance = PresenceService._();
  PresenceService._();

  final _db = FirebaseDatabase.instance;
  DatabaseReference? _presenceRef;

  Future<void> setupPresence({
    required String roomId,
    required String playerId,
}) async {
    _presenceRef = _db.ref('presence/$roomId/$playerId');

    await _presenceRef!.onDisconnect().set({
      'online': false,
      'disconnectedAt': ServerValue.timestamp,
    });
    await _presenceRef!.set({
      'online': true,
      'connectedAt': ServerValue.timestamp,
    });
    appLogger.d('PresenceService: nœud RTDB initialisé pour $playerId');
  }

  Future<void> removePresence()async{
    if (_presenceRef == null) return;
    try{
      await _presenceRef!.onDisconnect().cancel();
      await _presenceRef!.set({
        'online': false,
        'disconnectedAt': ServerValue.timestamp,
      });
    } catch(e){
      appLogger.w('PresenceService: erreur removePresence', error: e);
    }
    _presenceRef = null;
  }
}