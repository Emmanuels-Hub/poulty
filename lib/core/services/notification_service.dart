import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../data/models/event_model.dart';
import '../constants/app_constants.dart';
import '../constants/enums.dart';

/// Raises OS-level notifications so alerts reach the farmer while the app is
/// backgrounded — an in-app list is no use if nobody is looking at the phone.
class NotificationService {
  // A singleton, because the underlying plugin is one too: main() initialises
  // the channel before runApp, while the binding hands the service to the
  // controller afterwards. Two instances would mean the second never sees
  // _ready and would silently drop every alert.
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  factory NotificationService() => instance;

  final _plugin = FlutterLocalNotificationsPlugin();

  bool _ready = false;
  bool _permissionGranted = false;

  bool get isReady => _ready;
  bool get hasPermission => _permissionGranted;

  Future<void> init() async {
    if (_ready) return;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings(
      // Asked for explicitly below so the prompt can be tied to a user action.
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: darwin),
    );

    final android_ = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    // Creating the channel up front means severity and sound are already set
    // the first time an alert fires.
    await android_?.createNotificationChannel(
      const AndroidNotificationChannel(
        AppConstants.notificationChannelId,
        AppConstants.notificationChannelName,
        description: AppConstants.notificationChannelDescription,
        importance: Importance.high,
      ),
    );

    _ready = true;
  }

  /// Asks for notification permission. Android 13+ and iOS both require this;
  /// older Android grants it at install time.
  Future<bool> requestPermission() async {
    if (!_ready) await init();

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      _permissionGranted = await android.requestNotificationsPermission() ??
          // A null result means the platform has no runtime prompt, which on
          // Android below 13 means it is already granted.
          true;
      return _permissionGranted;
    }

    final darwin = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (darwin != null) {
      _permissionGranted = await darwin.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
      return _permissionGranted;
    }

    _permissionGranted = true;
    return true;
  }

  Future<void> show(AppNotification alert) async {
    if (!_ready) return;

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        AppConstants.notificationChannelId,
        AppConstants.notificationChannelName,
        channelDescription: AppConstants.notificationChannelDescription,
        importance: _importanceFor(alert.severity),
        priority: _priorityFor(alert.severity),
        // Critical alerts stay put until acted on; warnings can be swiped away.
        ongoing: false,
        autoCancel: true,
        styleInformation: BigTextStyleInformation(alert.message),
      ),
      iOS: DarwinNotificationDetails(
        interruptionLevel: alert.severity == AlertSeverity.critical
            ? InterruptionLevel.timeSensitive
            : InterruptionLevel.active,
      ),
    );

    await _plugin.show(
      // One slot per alert type, so a repeating condition replaces its own
      // notification instead of stacking dozens of them.
      alert.type.index,
      alert.title,
      alert.message,
      details,
    );
  }

  /// Clears the notification for [type] once the condition has cleared.
  Future<void> cancel(AlertType type) async {
    if (!_ready) return;
    await _plugin.cancel(type.index);
  }

  Future<void> cancelAll() async {
    if (!_ready) return;
    await _plugin.cancelAll();
  }

  Importance _importanceFor(AlertSeverity severity) {
    switch (severity) {
      case AlertSeverity.critical:
        return Importance.max;
      case AlertSeverity.warning:
        return Importance.high;
      case AlertSeverity.info:
        return Importance.defaultImportance;
    }
  }

  Priority _priorityFor(AlertSeverity severity) {
    switch (severity) {
      case AlertSeverity.critical:
        return Priority.max;
      case AlertSeverity.warning:
        return Priority.high;
      case AlertSeverity.info:
        return Priority.defaultPriority;
    }
  }
}
