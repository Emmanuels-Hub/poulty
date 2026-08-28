import 'package:get/get.dart';

import '../../core/constants/enums.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/local_storage_service.dart';
import '../../data/models/user_model.dart';
import '../../modules/telemetry/telemetry_controller.dart';
import '../../routes/app_routes.dart';

class AuthController extends GetxController {
  AuthController(this._auth, this._storage);

  final AuthService _auth;
  final LocalStorageService _storage;

  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;
  final Rxn<UserModel> user = Rxn<UserModel>();

  bool get isAdmin => user.value?.isAdmin ?? false;

  @override
  void onInit() {
    super.onInit();
    _restore();
  }

  Future<void> _restore() async {
    await _auth.restoreSession();
    user.value = _auth.currentUser;
    if (user.value != null) {
      Get.offAllNamed(AppRoutes.shell);
      await Get.find<TelemetryController>().startMonitoring();
    }
  }

  Future<void> login(String username, String password) async {
    isLoading.value = true;
    errorMessage.value = '';

    final result = await _auth.login(username, password);
    if (result == null) {
      errorMessage.value = 'Invalid username or password';
      isLoading.value = false;
      return;
    }

    user.value = result;
    isLoading.value = false;
    Get.offAllNamed(AppRoutes.shell);
    await Get.find<TelemetryController>().startMonitoring();
  }

  Future<void> logout() async {
    Get.find<TelemetryController>().stopMonitoring();
    await _auth.logout();
    user.value = null;
    Get.offAllNamed(AppRoutes.login);
  }

  List<UserModel> get users => _storage.getUsers();

  Future<String?> createUser({
    required String username,
    required String displayName,
    required String password,
    required String roleName,
  }) {
    return _auth.createUser(
      username: username,
      displayName: displayName,
      password: password,
      role: roleName == 'admin' ? UserRole.admin : UserRole.viewer,
    );
  }

  Future<String?> updateUser(UserModel model, {String? newPassword}) {
    return _auth.updateUser(model, newPassword: newPassword);
  }

  Future<String?> deleteUser(String id) => _auth.deleteUser(id);
}
