import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:poulty/core/constants/app_constants.dart';
import 'package:poulty/core/services/auth_service.dart';
import 'package:poulty/core/services/local_storage_service.dart';
import 'package:poulty/data/models/user_model.dart';
import 'package:poulty/modules/auth/auth_controller.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  @override
  Future<String?> getApplicationDocumentsPath() async {
    return Directory.systemTemp.path;
  }

  @override
  Future<String?> getTemporaryPath() async {
    return Directory.systemTemp.path;
  }

  @override
  Future<String?> getApplicationSupportPath() async {
    return Directory.systemTemp.path;
  }

  @override
  Future<String?> getLibraryPath() async {
    return Directory.systemTemp.path;
  }
}

void main() {
  test('AppConstants defines app name', () {
    expect(AppConstants.appName, 'Smart Poultry');
  });

  test('Password hashing is deterministic', () {
    String hash(String input) {
      return sha256.convert(utf8.encode(input)).toString();
    }

    expect(hash('test123'), hash('test123'));
    expect(hash('test123'), isNot(equals('test123')));
  });

  test('AuthController exposes a reactive user list for the users page', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    PathProviderPlatform.instance = _FakePathProviderPlatform();

    final storage = LocalStorageService.instance;
    await storage.init();
    await storage.seedDefaultUsersIfEmpty();

    final controller = AuthController(AuthService(storage), storage);
    controller.onInit();

    expect(controller.users, isA<RxList<UserModel>>());
    expect(controller.users.length, greaterThan(0));
  });
}
