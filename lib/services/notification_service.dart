import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/news_model.dart';
import '../services/api/news_api.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  final NewsApi _newsApi = NewsApi();
  bool _isInitialized = false;
  bool _isChecking = false; // Guard flag to prevent concurrent execution
  Timer? _periodicCheckTimer;

  /// Initialize notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      final initialized = await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      if (initialized != true) {
        print('❌ Failed to initialize notifications');
        return;
      }

      // Create notification channel for Android 8.0+
      final androidImplementation = _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      
      if (androidImplementation != null) {
        // Request permissions for Android 13+
        try {
          await androidImplementation.requestNotificationsPermission();
        } catch (e) {
          print('⚠️ Permission request error: $e');
        }
        
        // Create notification channel
        try {
          await androidImplementation.createNotificationChannel(
            const AndroidNotificationChannel(
              'news_channel',
              'News Notifications',
              description: 'Notifications for new news updates',
              importance: Importance.high,
              playSound: true,
              enableVibration: true,
            ),
          );
        } catch (e) {
          print('⚠️ Channel creation error: $e');
        }
      }

      _isInitialized = true;
      print('✅ Notification service initialized');
      
      // Start periodic check for new news
      startPeriodicNewsCheck();
    } catch (e) {
      print('❌ Error initializing notifications: $e');
      // Don't throw - allow app to continue even if notifications fail
    }
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    // Handle notification tap - can navigate to news screen or specific news item
    print('Notification tapped: ${response.payload}');
  }

  /// Show notification for new news
  Future<void> showNewsNotification(NewsModel news) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      const androidDetails = AndroidNotificationDetails(
        'news_channel', // Must match channel ID created in initialize()
        'News Notifications',
        channelDescription: 'Notifications for new news updates',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.show(
        news.id.hashCode, // Use news ID hash as notification ID
        news.title,
        news.description.isNotEmpty ? news.description : news.subtitle,
        notificationDetails,
        payload: news.id, // Pass news ID as payload
      );
      
      print('✅ Notification sent: ${news.title}');
    } catch (e) {
      print('❌ Error showing notification: $e');
    }
  }

  /// Check if news was already notified
  Future<bool> isNewsNotified(String newsId) async {
    final prefs = await SharedPreferences.getInstance();
    final notifiedIds = prefs.getStringList('notified_news_ids') ?? [];
    return notifiedIds.contains(newsId);
  }

  /// Mark news as notified
  Future<void> markNewsAsNotified(String newsId) async {
    final prefs = await SharedPreferences.getInstance();
    final notifiedIds = prefs.getStringList('notified_news_ids') ?? [];
    if (!notifiedIds.contains(newsId)) {
      notifiedIds.add(newsId);
      await prefs.setStringList('notified_news_ids', notifiedIds);
    }
  }

  /// Check for new news and send notifications
  Future<void> checkAndNotifyNewNews(List<NewsModel> allNews) async {
    for (final news in allNews) {
      final isNotified = await isNewsNotified(news.id);
      if (!isNotified) {
        // This is a new news item - send notification
        await showNewsNotification(news);
        await markNewsAsNotified(news.id);
      }
    }
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  /// Cancel specific notification
  Future<void> cancelNotification(int notificationId) async {
    await _notifications.cancel(notificationId);
  }

  /// Start periodic check for new news (every 5 minutes)
  void startPeriodicNewsCheck() {
    // Cancel existing timer if any
    _periodicCheckTimer?.cancel();
    
    // Check immediately on start
    _checkForNewNews();
    
    // Then check every 5 minutes
    _periodicCheckTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _checkForNewNews(),
    );
    
    print('✅ Started periodic news check (every 5 minutes)');
  }

  /// Stop periodic check
  void stopPeriodicNewsCheck() {
    _periodicCheckTimer?.cancel();
    _periodicCheckTimer = null;
    _isChecking = false; // Reset checking flag when stopping
    print('⏹️ Stopped periodic news check');
  }

  /// Check for new news from API
  Future<void> _checkForNewNews() async {
    // Prevent concurrent execution - if a check is already in progress, skip this one
    if (_isChecking) {
      print('⏭️ News check already in progress, skipping this call');
      return;
    }

    // Set flag to prevent concurrent execution
    _isChecking = true;
    
    try {
      if (!_isInitialized) {
        await initialize();
      }
      
      // Fetch all news from API
      final allNews = await _newsApi.getAllNews();
      
      // Check and notify new news
      await checkAndNotifyNewNews(allNews);
      
      print('✅ Periodic news check completed (${allNews.length} news items checked)');
    } catch (e) {
      print('❌ Error in periodic news check: $e');
      // Don't throw - allow periodic check to continue
    } finally {
      // Always reset the flag, even if an error occurred
      _isChecking = false;
    }
  }

  /// Check for new news (can be called from background task)
  static Future<void> checkForNewNewsInBackground() async {
    final service = NotificationService();
    await service._checkForNewNews();
  }
}

