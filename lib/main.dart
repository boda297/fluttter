import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'screens/splash_screen.dart';
import 'services/notification_service.dart';
import 'services/cache_service.dart';
import 'services/clip_service.dart';
import 'services/api/improved_clip_api.dart';
import 'services/api/project_api.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    if (kDebugMode) {
      FlutterError.presentError(details);
    }
    if (kReleaseMode) {
      FlutterError.dumpErrorToConsole(details);
    }
  };

  runZonedGuarded(() async {
    await _initializeApp();
    runApp(const OrientationApp());
  }, (error, stack) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('Zone error: $error\n$stack');
    }
  });
}

Future<void> _initializeApp() async {
  try {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );
  } catch (_) {}

  try {
    final cacheService = CacheService();
    await cacheService.clearReelsCache();
    if (kDebugMode) debugPrint('Video caches cleared on app start');
  } catch (e) {
    if (kDebugMode) debugPrint('Error clearing video caches: $e');
  }

  try {
    final notificationService = NotificationService();
    await notificationService.initialize();
    if (kDebugMode) debugPrint('Notification service initialized');
  } catch (e) {
    if (kDebugMode) debugPrint('Notification init error (non-fatal): $e');
  }

  try {
    Get.put(ImprovedClipApi(), permanent: true);
    Get.put(ProjectApi(), permanent: true);
    Get.put(
      ClipService(
        clipApi: Get.find<ImprovedClipApi>(),
        projectApi: Get.find<ProjectApi>(),
      ),
      permanent: true,
    );
  } catch (e) {
    if (kDebugMode) debugPrint('Get.put init error (non-fatal): $e');
  }
}

class OrientationApp extends StatefulWidget {
  const OrientationApp({super.key});

  @override
  State<OrientationApp> createState() => _OrientationAppState();
}

class _OrientationAppState extends State<OrientationApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      try {
        if (Get.isRegistered<ClipService>()) {
          Get.find<ClipService>().flush();
        }
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Orientation',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFFE50914),
          secondary: const Color(0xFFE50914),
          surface: Colors.black,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
