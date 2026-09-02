import 'package:get/get.dart';

import '../../core/services/alert_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/esp32_ble_service.dart';
import '../../core/services/history_service.dart';
import '../../core/services/local_storage_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/simulation_service.dart';
import '../../modules/auth/auth_controller.dart';
import '../../modules/telemetry/telemetry_controller.dart';

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    final storage = LocalStorageService.instance;
    final simulation = SimulationService();
    final ble = Esp32BleService();
    final alerts = AlertService(storage);
    final auth = AuthService(storage);
    final history = HistoryService(storage);
    final notifications = NotificationService();

    Get.put(storage, permanent: true);
    Get.put(simulation, permanent: true);
    Get.put(ble, permanent: true);
    Get.put(alerts, permanent: true);
    Get.put(auth, permanent: true);
    Get.put(history, permanent: true);
    Get.put(notifications, permanent: true);
    Get.put(
      TelemetryController(
        storage,
        ble,
        simulation,
        alerts,
        auth,
        history,
        notifications,
      ),
      permanent: true,
    );
    Get.put(AuthController(auth, storage), permanent: true);
  }
}
