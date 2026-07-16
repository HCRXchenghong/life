enum NotificationPermissionStatus { authorized, denied, unsupported }

class NotificationSettingsState {
  const NotificationSettingsState({
    required this.remindersEnabled,
    required this.defaultLeadMinutes,
    required this.soundAndVibrationEnabled,
    required this.permissionStatus,
  });

  final bool remindersEnabled;
  final int defaultLeadMinutes;
  final bool soundAndVibrationEnabled;
  final NotificationPermissionStatus permissionStatus;
}

abstract interface class NotificationSettingsSource {
  Future<NotificationSettingsState> loadNotificationSettings();

  Future<NotificationSettingsState> setRemindersEnabled(bool enabled);

  Future<NotificationSettingsState> setDefaultLeadMinutes(int minutes);

  Future<NotificationSettingsState> setSoundAndVibrationEnabled(bool enabled);

  Future<NotificationSettingsState> requestNotificationPermission();

  Future<void> openSystemNotificationSettings();
}
