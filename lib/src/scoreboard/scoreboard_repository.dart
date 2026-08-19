import 'package:sembast/sembast.dart';

import 'scoreboard_state.dart';

class ScoreboardRepository {
  ScoreboardRepository(Database database) : _database = database;

  static const String _recordKey = 'current';
  static const String _snapshotsRecordKey = 'snapshots';
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

  Future<List<ScoreboardSnapshot>> loadSnapshots() async {
    final data = await _store.record(_snapshotsRecordKey).get(_database);
    if (data == null) return <ScoreboardSnapshot>[];

    final rawSnapshots = data['items'];
    if (rawSnapshots is! List) return <ScoreboardSnapshot>[];

    return rawSnapshots
        .map(ScoreboardSnapshot.fromJson)
        .whereType<ScoreboardSnapshot>()
        .toList();
  }

  Future<void> saveSnapshot(ScoreboardSnapshot snapshot) async {
    final snapshots = await loadSnapshots();
    final updated = <ScoreboardSnapshot>[
      ...snapshots.where((entry) => entry.id != snapshot.id),
      snapshot,
    ]..sort((a, b) => b.savedAt.compareTo(a.savedAt));

    await _store.record(_snapshotsRecordKey).put(
      _database,
      <String, dynamic>{
        'items': updated.map((entry) => entry.toJson()).toList(),
      },
    );
  }

  Future<void> deleteSnapshot(String id) async {
    final snapshots = await loadSnapshots();
    final updated = snapshots.where((entry) => entry.id != id).toList();
    await _store.record(_snapshotsRecordKey).put(
      _database,
      <String, dynamic>{
        'items': updated.map((entry) => entry.toJson()).toList(),
      },
    );
  }
}
