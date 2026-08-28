import 'package:get/get.dart';

import '../../core/services/alert_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/esp32_api_service.dart';
import '../../core/services/local_storage_service.dart';
import '../../core/services/simulation_service.dart';
import '../../modules/auth/auth_controller.dart';
import '../../modules/diagnostics/diagnostics_controller.dart';
import '../../modules/telemetry/telemetry_controller.dart';

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    final storage = LocalStorageService.instance;
    final simulation = SimulationService();
    final api = Esp32ApiService(storage, simulation);
    final alerts = AlertService(storage);
    final auth = AuthService(storage);

    Get.put(storage, permanent: true);
    Get.put(simulation, permanent: true);
    Get.put(api, permanent: true);
    Get.put(alerts, permanent: true);
    Get.put(auth, permanent: true);
    Get.put(TelemetryController(storage, api, alerts, auth), permanent: true);
    Get.put(AuthController(auth, storage), permanent: true);
    Get.put(
      DiagnosticsController(api, Get.find<TelemetryController>(), simulation),
      permanent: true,
    );
  }
}
