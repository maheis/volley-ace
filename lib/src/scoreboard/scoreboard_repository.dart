import 'package:sembast/sembast.dart';

import 'scoreboard_state.dart';

class ScoreboardRepository {
  ScoreboardRepository(Database database) : _database = database;

  static const String _recordKey = 'current';
  static final StoreRef<String, Map<String, dynamic>> _store =
      StoreRef<String, Map<String, dynamic>>('scoreboard');

  final Database _database;

  Future<ScoreboardState> load() async {
    final data = await _store.record(_recordKey).get(_database);
    return ScoreboardState.fromJson(data);
  }

  Future<void> save(ScoreboardState state) async {
    await _store.record(_recordKey).put(_database, state.toJson());
  }
}
