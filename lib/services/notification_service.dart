import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// ── Background message handler (must be top-level) ───────────────────────────
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM] Background message: ${message.messageId}');
}

// ── Background notification tap handler (must be top-level) ──────────────────
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  debugPrint('[FCM] Background tap: ${response.payload}');
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _fcm = FirebaseMessaging.instance;

  // Only used on Android for foreground heads-up notifications
  static final _plugin = FlutterLocalNotificationsPlugin();

  static const _channelId   = 'pikuru_notifications';
  static const _channelName = 'Pikuru Notifications';
  static const _channelDesc = 'Notifications from Pikuru pickleball app';

  bool _initialized = false;

  // ── Public init ──────────────────────────────────────────────────────────
  Future<void> init() async {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await _requestPermission();

    if (!_initialized) {
      await _setupLocalNotifications();
      _initialized = true;
    }

    await _saveToken();
    _fcm.onTokenRefresh.listen(_saveTokenToFirestore);
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_onTap);

    final initial = await _fcm.getInitialMessage();
    if (initial != null) _onTap(initial);

    // iOS foreground display
    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true, badge: true, sound: true,
    );
  }

  // ── Permission ───────────────────────────────────────────────────────────
  Future<void> _requestPermission() async {
    final s = await _fcm.requestPermission(
      alert: true, badge: true, sound: true,
    );
    debugPrint('[FCM] Auth status: ${s.authorizationStatus}');
  }

  // ── Android local notifications setup ────────────────────────────────────
  Future<void> _setupLocalNotifications() async {
    // Create channel first
    if (Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDesc,
        importance: Importance.high,
        playSound: true,
        enableLights: true,
        ledColor: Color(0xFF3A7D44),
      );

      await _plugin
          .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }

    // Init settings — Android uses the drawable, iOS we skip (FCM handles it)
    final initSettings = InitializationSettings(
      android: const AndroidInitializationSettings('@drawable/ic_notification'),
      iOS: Platform.isIOS
          ? const DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      )
          : null,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse r) {
        _handlePayload(r.payload);
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );
  }

  // ── Token management ──────────────────────────────────────────────────────
  Future<void> _saveToken() async {
    final token = await _fcm.getToken();
    if (token != null) await _saveTokenToFirestore(token);
  }

  Future<void> _saveTokenToFirestore(String token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'fcm_tokens'     : FieldValue.arrayUnion([token]),
        'fcm_token'      : token,
        'platform'       : Platform.isIOS ? 'ios' : 'android',
        'fcm_updated_at' : FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('[FCM] Token saved');
    } catch (e) {
      debugPrint('[FCM] Save error: $e');
    }
  }

  Future<void> removeToken() async {
    final uid   = FirebaseAuth.instance.currentUser?.uid;
    final token = await _fcm.getToken();
    if (uid == null || token == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'fcm_tokens' : FieldValue.arrayRemove([token]),
        'fcm_token'  : FieldValue.delete(),
      });
      await _fcm.deleteToken();
      debugPrint('[FCM] Token removed');
    } catch (e) {
      debugPrint('[FCM] Remove error: $e');
    }
  }

  // ── Foreground message → show heads-up on Android ────────────────────────
  void _onForegroundMessage(RemoteMessage message) {
    final n = message.notification;
    if (n == null) return;

    // iOS: FCM handles it via setForegroundNotificationPresentationOptions
    if (Platform.isIOS) return;

    _plugin.show(
      n.hashCode,
      n.title,
      n.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription : _channelDesc,
          importance         : Importance.high,
          priority           : Priority.high,
          color              : Color(0xFF3A7D44),
          icon               : '@drawable/ic_notification',
        ),
      ),
      payload: message.data['route'],
    );
  }

  // ── Tap handlers ─────────────────────────────────────────────────────────
  void _onTap(RemoteMessage message) => _handlePayload(message.data['route']);

  void _handlePayload(String? payload) {
    if (payload == null || payload.isEmpty) return;
    debugPrint('[FCM] Navigate to: $payload');
    // Wire up when you have a navigatorKey:
    // navigatorKey.currentState?.pushNamed(payload);
  }
}