import 'package:drift/drift.dart';

import 'app_database.dart';

class NotificationPreferencesModel {
  const NotificationPreferencesModel({
    this.remindersEnabled = true,
    this.defaultLeadMinutes = 10,
    this.soundAndVibrationEnabled = true,
  });

  final bool remindersEnabled;
  final int defaultLeadMinutes;
  final bool soundAndVibrationEnabled;

  NotificationPreferencesModel copyWith({
    bool? remindersEnabled,
    int? defaultLeadMinutes,
    bool? soundAndVibrationEnabled,
  }) => NotificationPreferencesModel(
    remindersEnabled: remindersEnabled ?? this.remindersEnabled,
    defaultLeadMinutes: defaultLeadMinutes ?? this.defaultLeadMinutes,
    soundAndVibrationEnabled:
        soundAndVibrationEnabled ?? this.soundAndVibrationEnabled,
  );
}

class NotificationPreferencesRepository {
  NotificationPreferencesRepository(this._db);

  static const _rowId = 1;
  static const supportedLeadMinutes = <int>[5, 10, 15, 30, 60];

  final AppDatabase _db;

  Future<NotificationPreferencesModel> load() async {
    final row = await (_db.select(
      _db.notificationPreferences,
    )..where((table) => table.id.equals(_rowId))).getSingleOrNull();
    if (row == null) return const NotificationPreferencesModel();
    return NotificationPreferencesModel(
      remindersEnabled: row.remindersEnabled,
      defaultLeadMinutes: row.defaultLeadMinutes,
      soundAndVibrationEnabled: row.soundAndVibrationEnabled,
    );
  }

  Future<void> save(NotificationPreferencesModel preferences) async {
    if (!supportedLeadMinutes.contains(preferences.defaultLeadMinutes)) {
      throw ArgumentError.value(
        preferences.defaultLeadMinutes,
        'defaultLeadMinutes',
        'Unsupported notification lead time',
      );
    }
    await _db
        .into(_db.notificationPreferences)
        .insertOnConflictUpdate(
          NotificationPreferencesCompanion.insert(
            id: const Value(_rowId),
            remindersEnabled: Value(preferences.remindersEnabled),
            defaultLeadMinutes: Value(preferences.defaultLeadMinutes),
            soundAndVibrationEnabled: Value(
              preferences.soundAndVibrationEnabled,
            ),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );
  }
}
