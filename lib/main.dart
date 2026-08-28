import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'app/bindings/initial_binding.dart';
import 'core/constants/app_constants.dart';
import 'core/services/local_storage_service.dart';
import 'core/theme/app_theme.dart';
import 'routes/app_pages.dart'; 
import 'routes/app_routes.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storage = LocalStorageService.instance;
  await storage.init();
  await storage.seedDefaultUsersIfEmpty();
  await storage.seedDefaultDeviceIfEmpty();

  runApp(const PoultyApp());
}

class PoultyApp extends StatelessWidget {
  const PoultyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(390, 844),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (_, child) {
        return GetMaterialApp(
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          initialBinding: InitialBinding(),
          initialRoute: AppRoutes.login,
          getPages: AppPages.routes,
        );
      },
    );
  }
}
