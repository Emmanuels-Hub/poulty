class AppConstants {
  AppConstants._();

  static const String appName = 'Smart Poultry';
  static const int maxAdmins = 3;
  static const Duration telemetryPollInterval = Duration(seconds: 5);
  static const Duration manualActuatorTimeout = Duration(minutes: 15);
  static const Duration offlineSyncRetryInterval = Duration(seconds: 30);

  static const int maxHistoryPoints = 288;
  static const int maxEventLogs = 500;
  static const int maxNotifications = 200;

  static const String hiveBoxSettings = 'settings';
  static const String hiveBoxTelemetry = 'telemetry';
  static const String hiveBoxEvents = 'events';
  static const String hiveBoxNotifications = 'notifications';
  static const String hiveBoxCommandQueue = 'command_queue';
  static const String hiveBoxUsers = 'users';
  static const String hiveBoxDevices = 'devices';

  static const String secureKeySession = 'session_user_id';
  static const String secureKeyToken = 'session_token';
}
