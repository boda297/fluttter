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
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // Clear video caches on app start (videos are not cached anymore)
  try {
    final cacheService = CacheService();
    await cacheService.clearReelsCache();
    print('🗑️ Video caches cleared on app start');
  } catch (e) {
    print('⚠️ Error clearing video caches: $e');
  }

  // Initialize notification service to start periodic checks
  final notificationService = NotificationService();
  await notificationService.initialize();

  // Note: Background tasks using workmanager are temporarily disabled
  // The periodic check will work when the app is open (every 5 minutes)
  // To enable background tasks, uncomment the workmanager code below
  // and ensure workmanager package is properly installed

  print('✅ Notification service initialized');

  // Register clip-related services for dependency injection
  Get.put(ImprovedClipApi(), permanent: true);
  Get.put(ProjectApi(), permanent: true);
  Get.put(
    ClipService(
      clipApi: Get.find<ImprovedClipApi>(),
      projectApi: Get.find<ProjectApi>(),
    ),
    permanent: true,
  );

  runApp(const OrientationApp());
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
      Get.find<ClipService>().flush();
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
