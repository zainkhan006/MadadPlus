import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class ProviderNotifier {
  static const _channelId = 'incoming_jobs';
  static const _notificationId = 1;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> start({required VoidCallback onTap}) async {
    if(_ready) {
      return;
    }
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_stat_incoming'),
        ),
        onDidReceiveNotificationResponse: (_) {
          onTap();
        },
      );
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
      _ready = true;
    }
    catch(_) {
      debugPrint('notifications could not be switched on for this phone');
    }
  }

  Future<void> showNewJobs() async {
    if(!_ready) {
      return;
    }
    try {
      await _plugin.show(
        id: _notificationId,
        title: 'You have new jobs',
        body: 'click to view',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            'Incoming jobs',
            channelDescription: 'Tells you when a new job request arrives.',
            importance: Importance.high,
            priority: Priority.high,
            largeIcon: DrawableResourceAndroidBitmap('banner_logo'),
          ),
        ),
      );
    }
    catch(_) {
      debugPrint('the new jobs banner could not be shown');
    }
  }
}
