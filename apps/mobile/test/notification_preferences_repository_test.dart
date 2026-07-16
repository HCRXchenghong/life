import 'package:daylink_mobile/src/data/app_database.dart';
import 'package:daylink_mobile/src/data/notification_preferences_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late NotificationPreferencesRepository repository;

  setUp(() {
    database = AppDatabase.inMemory();
    repository = NotificationPreferencesRepository(database);
  });

  tearDown(() => database.close());

  test(
    'notification preferences use safe defaults and persist changes',
    () async {
      final defaults = await repository.load();
      expect(defaults.remindersEnabled, isTrue);
      expect(defaults.defaultLeadMinutes, 10);
      expect(defaults.soundAndVibrationEnabled, isTrue);

      await repository.save(
        const NotificationPreferencesModel(
          remindersEnabled: false,
          defaultLeadMinutes: 30,
          soundAndVibrationEnabled: false,
        ),
      );

      final stored = await repository.load();
      expect(stored.remindersEnabled, isFalse);
      expect(stored.defaultLeadMinutes, 30);
      expect(stored.soundAndVibrationEnabled, isFalse);
    },
  );

  test('unsupported lead times are rejected', () async {
    expect(
      () => repository.save(
        const NotificationPreferencesModel(defaultLeadMinutes: 17),
      ),
      throwsArgumentError,
    );
  });
}
