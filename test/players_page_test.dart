import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:volleyace/src/app.dart';
import 'package:volleyace/src/settings/settings_controller.dart';
import 'package:volleyace/src/settings/settings_repository.dart';
import 'package:volleyace/src/teams/players_page.dart';
import 'package:volleyace/src/teams/teams_page.dart';

void main() {
  testWidgets('main menu opens the player directory', (tester) async {
    final database = await databaseFactoryMemory.openDatabase('players-menu');
    addTearDown(database.close);
    final settings = SettingsController(SettingsRepository(database));
    await tester.runAsync(settings.load);
    await tester.pumpWidget(VolleyAceApp(
      settingsController: settings,
      database: database,
    ));
    await tester.pumpAndSettle();
    final entry = find.byKey(const ValueKey('main-menu-players'));
    await tester.scrollUntilVisible(entry, 300);
    expect(
        find.text('Personen und Teamzugehörigkeit verwalten.'), findsOneWidget);
    final teamsEntry = find.widgetWithText(ListTile, 'Teams');
    expect(tester.getTopLeft(entry).dy,
        lessThan(tester.getTopLeft(teamsEntry).dy));
    await tester.tap(entry);
    await tester.pumpAndSettle();
    expect(find.text('Spieler / Trainer'), findsOneWidget);
    expect(find.byKey(const ValueKey('players-filter')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  Team team(int id, {String name = 'Ada', int? personId}) => Team(
        id: id,
        name: 'Team $id',
        players: [
          TeamPlayer(
            id: id + 10,
            name: name,
            number: id + 3,
            birthDate: DateTime(2000, 5, 6),
            position: 'Position $id',
            profile: 'Profil $id',
            personId: personId,
          ),
        ],
        coaches: const [],
      );

  test('directory migrates existing players and retains team-specific fields',
      () async {
    final database = await databaseFactoryMemory.openDatabase('directory');
    addTearDown(database.close);
    await TeamsRepository(database).save([team(1), team(2)]);
    final repository = PeopleRepository(database);
    final directory = await repository.loadDirectory();
    expect(directory.people, hasLength(1));
    final person = directory.people.single;
    expect(person.isPlayer, isTrue);
    expect(person.birthDate, DateTime(2000, 5, 6));
    for (final linked in directory.teams) {
      expect(linked.players.single.personId, person.id);
      expect(linked.players.single.number, linked.id + 3);
      expect(linked.players.single.position, 'Position ${linked.id}');
    }
    expect((await repository.loadDirectory()).people, hasLength(1));
  });

  test('central edits update all teams without changing membership details',
      () async {
    final database = await databaseFactoryMemory.openDatabase('player-edits');
    addTearDown(database.close);
    await TeamsRepository(database).save([team(1), team(2)]);
    final repository = PeopleRepository(database);
    final directory = await repository.loadDirectory();
    await repository.savePlayer(directory.people.single.copyWith(
      name: 'Ada Neu',
      birthDate: DateTime(2001, 2, 3),
    ));
    for (final linked in await TeamsRepository(database).load()) {
      final player = linked.players.single;
      expect(player.name, 'Ada Neu');
      expect(player.birthDate, DateTime(2001, 2, 3));
      expect(player.number, linked.id + 3);
      expect(player.position, 'Position ${linked.id}');
      expect(player.profile, 'Profil ${linked.id}');
    }
    await repository.savePlayer((await repository.load()).single.copyWith(
          clearBirthDate: true,
        ));
    expect(
        (await TeamsRepository(database).load()).first.players.single.birthDate,
        isNull);
  });

  test('unlinked players remain in the directory and receive unique IDs',
      () async {
    final database = await databaseFactoryMemory.openDatabase('unlinked');
    addTearDown(database.close);
    final repository = PeopleRepository(database);
    for (final name in ['Ada', 'Berta']) {
      await repository.savePlayer(
        LocalPerson(id: 0, memberNumber: 0, name: name),
      );
    }
    final directory = await repository.loadDirectory();
    expect(directory.teams, isEmpty);
    expect(directory.people.map((person) => person.id), [1, 2]);
    expect(directory.people.every((person) => person.isPlayer), isTrue);
  });

  test('legacy team coaches migrate into the central directory', () async {
    final database =
        await databaseFactoryMemory.openDatabase('coach-migration');
    addTearDown(database.close);
    await TeamsRepository(database).save([
      Team(
        id: 1,
        name: 'U18 Nord',
        players: const [],
        coaches: const [
          TeamCoach(
            id: 1,
            name: 'Coach Mara',
            profile: 'Mannschaftstraining',
            birthDate: null,
            position: 'Cheftrainerin',
          ),
        ],
      ),
    ]);
    final directory = await PeopleRepository(database).loadDirectory();
    expect(directory.people, hasLength(1));
    expect(directory.people.single.isCoach, isTrue);
    expect(directory.people.single.isPlayer, isFalse);
    expect(directory.teams.single.coaches.single.personId,
        directory.people.single.id);
  });

  testWidgets('players are ordered by ID and filtered by name and team',
      (tester) async {
    final database = await databaseFactoryMemory.openDatabase('players-filter');
    addTearDown(database.close);
    await tester.runAsync(() async {
      await PeopleRepository(database).save(const [
        LocalPerson(id: 8, memberNumber: 8, name: 'Ada', isPlayer: true),
        LocalPerson(id: 2, memberNumber: 2, name: 'Berta', isPlayer: true),
      ]);
      await TeamsRepository(database).save([
        team(1, name: 'Ada', personId: 8).copyWith(name: 'U18 Nord'),
        team(2, name: 'Berta', personId: 2).copyWith(name: 'Damen Sued'),
      ]);
    });
    await tester.pumpWidget(MaterialApp(home: PlayersPage(database: database)));
    await tester.pumpAndSettle();
    final ada = find.byKey(const ValueKey('player-row-8'));
    final berta = find.byKey(const ValueKey('player-row-2'));
    expect(tester.getTopLeft(berta).dy, lessThan(tester.getTopLeft(ada).dy));
    final filter = find.byKey(const ValueKey('players-filter'));
    await tester.enterText(filter, 'ADA nord');
    await tester.pumpAndSettle();
    expect(ada, findsOneWidget);
    expect(berta, findsNothing);
    await tester.enterText(filter, 'sued');
    await tester.pumpAndSettle();
    expect(berta, findsOneWidget);
    expect(ada, findsNothing);
    await tester.enterText(filter, 'Ada Sued');
    await tester.pumpAndSettle();
    expect(find.text('Keine Spieler oder Trainer gefunden.'), findsOneWidget);
    await tester.tap(find.byTooltip('Filter löschen'));
    await tester.pumpAndSettle();
    expect(ada, findsOneWidget);
    expect(berta, findsOneWidget);
  });

  testWidgets('standalone players can be created with general information',
      (tester) async {
    final database = await databaseFactoryMemory.openDatabase('player-create');
    addTearDown(database.close);
    await tester.pumpWidget(MaterialApp(home: PlayersPage(database: database)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('new-player-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Spieler hinzufügen').last);
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('player-name-input')), 'Cara');
    expect(
        find.byKey(const ValueKey('player-birthdate-input')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('team-player-number-input')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('player-save-button')));
    await tester.pumpAndSettle();
    final people =
        await tester.runAsync(() => PeopleRepository(database).load());
    expect(people!.single.name, 'Cara');
    expect(people.single.isPlayer, isTrue);
    expect(find.text('ID ${people.single.id}'), findsOneWidget);
  });

  testWidgets('standalone coaches can be created and linked to a team',
      (tester) async {
    final database = await databaseFactoryMemory.openDatabase('coach-create');
    addTearDown(database.close);
    final teamId = await tester.runAsync(() async {
      await TeamsRepository(database).save([
        const Team(id: 1, name: 'U18 Nord', players: [], coaches: []),
      ]);
      return 1;
    });
    await tester.pumpWidget(MaterialApp(home: PlayersPage(database: database)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('new-player-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trainer hinzufügen').last);
    await tester.pumpAndSettle();
    expect(find.text('Neuer Trainer'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('player-name-input')),
      'Coach Mara',
    );
    await tester.tap(find.byKey(const ValueKey('player-save-button')));
    await tester.pumpAndSettle();
    final coach =
        (await tester.runAsync(() => PeopleRepository(database).load()))!
            .single;
    expect(coach.isCoach, isTrue);
    expect(coach.isPlayer, isFalse);
    await tester.tap(find.byTooltip('Zurück zu Spielern'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('player-row-${coach.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('link-player-team')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('U18 Nord'));
    await tester.pumpAndSettle();
    final team =
        (await tester.runAsync(() => TeamsRepository(database).load()))!
            .singleWhere((entry) => entry.id == teamId);
    expect(team.coaches.single.name, 'Coach Mara');
    expect(team.coaches.single.personId, coach.id);
    expect(team.players, isEmpty);
    await tester.tap(find.byKey(const ValueKey('player-team-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('team-coach-name-input')), findsOneWidget);
    expect(find.byKey(const ValueKey('team-player-name-input')), findsNothing);
  });

  testWidgets('team-created coaches are registered as central people',
      (tester) async {
    final database =
        await databaseFactoryMemory.openDatabase('coach-from-team');
    addTearDown(database.close);
    await tester.runAsync(() => TeamsRepository(database).save([
          const Team(id: 1, name: 'U18 Nord', players: [], coaches: []),
        ]));
    await tester.pumpWidget(MaterialApp(
      home: TeamsPage(
        database: database,
        initialTeamId: 1,
        initialSection: 'coaches',
      ),
    ));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('team-coach-name-input')),
      'Coach Mara',
    );
    await tester.tap(find.byKey(const ValueKey('add-team-coach-button')));
    await tester.pumpAndSettle();
    final people =
        (await tester.runAsync(() => PeopleRepository(database).load()))!;
    expect(people.single.name, 'Coach Mara');
    expect(people.single.isCoach, isTrue);
    expect(people.single.isPlayer, isFalse);
  });

  testWidgets(
      'player form edits update linked teams without changing membership',
      (tester) async {
    final database =
        await databaseFactoryMemory.openDatabase('player-form-edit');
    addTearDown(database.close);
    final personId = await tester.runAsync(() async {
      await TeamsRepository(database).save([team(1), team(2)]);
      return (await PeopleRepository(database).loadDirectory())
          .people
          .single
          .id;
    });
    await tester.pumpWidget(MaterialApp(
      home: PlayersPage(database: database, initialPersonId: personId),
    ));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('player-name-input')),
      'Ada Neu',
    );
    await tester.tap(find.byKey(const ValueKey('player-birthdate-clear')));
    await tester.tap(find.byKey(const ValueKey('player-save-button')));
    await tester.pumpAndSettle();
    final savedTeams =
        await tester.runAsync(() => TeamsRepository(database).load());
    for (final linked in savedTeams!) {
      expect(linked.players.single.name, 'Ada Neu');
      expect(linked.players.single.birthDate, isNull);
      expect(linked.players.single.number, linked.id + 3);
      expect(linked.players.single.position, 'Position ${linked.id}');
      expect(linked.players.single.profile, 'Profil ${linked.id}');
    }
  });

  testWidgets('unlinked player can be linked to an existing team',
      (tester) async {
    final database = await databaseFactoryMemory.openDatabase('player-link');
    addTearDown(database.close);
    final personId = await tester.runAsync(() async {
      await TeamsRepository(database).save([
        const Team(id: 1, name: 'U18 Nord', players: [], coaches: []),
      ]);
      return (await PeopleRepository(database).savePlayer(
        const LocalPerson(id: 0, memberNumber: 0, name: 'Ada'),
      ))
          .id;
    });
    await tester.pumpWidget(MaterialApp(
      home: PlayersPage(database: database, initialPersonId: personId),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('link-player-team')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('U18 Nord'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('player-team-1')), findsOneWidget);
    final savedTeams =
        await tester.runAsync(() => TeamsRepository(database).load());
    expect(savedTeams!.single.players.single.personId, personId);
  });

  testWidgets('player team links open and save only membership information',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = await databaseFactoryMemory.openDatabase('player-team');
    addTearDown(database.close);
    final personId = await tester.runAsync(() async {
      await TeamsRepository(database).save([team(1), team(2)]);
      return (await PeopleRepository(database).loadDirectory())
          .people
          .single
          .id;
    });
    await tester.pumpWidget(MaterialApp(
      home: PlayersPage(database: database, initialPersonId: personId),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('player-team-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('player-team-2')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('player-team-1')));
    await tester.pumpAndSettle();
    expect(
        find.byKey(const ValueKey('team-player-number-input')), findsOneWidget);
    await tester.tap(find.byTooltip('Spieler bearbeiten'));
    await tester.pumpAndSettle();
    final name = tester.widget<TextField>(
      find.byKey(const ValueKey('team-player-name-input')),
    );
    expect(name.readOnly, isTrue);
    expect(
        find.byKey(const ValueKey('edit-player-general-info')), findsOneWidget);
    await tester.enterText(
        find.byKey(const ValueKey('team-player-number-input')), '17');
    await tester.enterText(
        find.byKey(const ValueKey('team-player-position-input')), 'Zuspiel');
    await tester.tap(find.byKey(const ValueKey('add-team-player-button')));
    await tester.pumpAndSettle();
    final savedTeams =
        await tester.runAsync(() => TeamsRepository(database).load());
    final first =
        savedTeams!.singleWhere((team) => team.id == 1).players.single;
    final second =
        savedTeams.singleWhere((team) => team.id == 2).players.single;
    expect(first.number, 17);
    expect(first.position, 'Zuspiel');
    expect(first.birthDate, DateTime(2000, 5, 6));
    expect(second.number, 5);
    expect(second.position, 'Position 2');
  });
}
