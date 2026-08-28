import 'package:get/get.dart';

import '../modules/auth/login_page.dart';
import '../modules/shell/shell_page.dart';
import 'app_routes.dart';

class AppPages {
  AppPages._();

  static final routes = [
    GetPage(name: AppRoutes.login, page: () => const LoginPage()),
    GetPage(name: AppRoutes.shell, page: () => const ShellPage()),
  ];
}
