import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService{
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  Future<void> logGameStared({
    required String gameMode,
    required String difficulty,
    required int numberOfPlayers,
}) async {
    await _analytics.logEvent(
        name: 'game_started',
    parameters: {
          'game_mode': gameMode,
          'difficulty': difficulty,
           'player_count': numberOfPlayers,
           'timestamp': DateTime.now().microsecondsSinceEpoch,
      },
    );
  }

  Future<void> logGameCompleted({
    required String gameMode,
    required bool isWinner,
    required int finalScore,
    required int gameDuration,
    required int cardsPlayed,
    required int specialCardsUsed,
}) async {
   await _analytics.logEvent(
       name: 'game_completed',
       parameters: {
         'game_mode': gameMode,
         'winner': isWinner ? 'win' : 'loss',
         'score': finalScore,
         'duration_seconds': gameDuration,
         'cards_played': cardsPlayed,
         'special_cards': specialCardsUsed,
       },
   );
  }
  Future<void> logSpecialCardPlayed({
    required String cardType,
    required String gameMode,
  }) async {
    await _analytics.logEvent(
      name: 'special_card_played',
      parameters: {
        'card_type': cardType,
        'game_mode': gameMode,
      },
    );
  }
  Future<void> logChecksTriggered({
    required String gameMode,
    required int remainingCards,
  }) async {
    await _analytics.logEvent(
      name: 'checks_triggered',
      parameters: {
        'game_mode': gameMode,
        'remaining_cards': remainingCards,
      },
    );
  }
  Future<void> logRoomCreated({
    required String roomType,
    required int maxPlayers,
  }) async {
    await _analytics.logEvent(
      name: 'room_created',
      parameters: {
        'room_type': roomType,
        'max_players': maxPlayers,
      },
    );
  }
  Future<void> logRoomJoined({
    required String roomId,
    required int currentPlayers,
  }) async {
    await _analytics.logEvent(
      name: 'room_joined',
      parameters: {
        'room_id': roomId,
        'player_count': currentPlayers,
      },
    );
  }
  Future<void> logTutorialCompleted() async {
    await _analytics.logTutorialComplete();
  }

  Future<void> logSettingChanged({
    required String settingName,
    required dynamic value,
  }) async {
    await _analytics.logEvent(
      name: 'setting_changed',
      parameters: {
        'setting': settingName,
        'value': value.toString(),
      },
    );
  }
  Future<void> logScreenView(String screenName) async {
    await _analytics.logScreenView(screenName: screenName);
  }
  Future<void> setUserLevel(int level) async {
    await _analytics.setUserProperty(
      name: 'player_level',
      value: level.toString(),
    );
  }
  Future<void> setFavoriteGameMode(String mode) async {
    await _analytics.setUserProperty(
      name: 'favorite_mode',
      value: mode,
    );
  }
  Future<void> setTotalGamesPlayed(int count) async {
    await _analytics.setUserProperty(
      name: 'total_games',
      value: count.toString(),
    );
  }
  Future<void> setWinRate(double rate) async {
    await _analytics.setUserProperty(
      name: 'win_rate',
      value: rate.toStringAsFixed(2),
    );
  }


}