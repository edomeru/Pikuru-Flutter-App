import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:pikuru/screens/individual_chat_screen.dart';
import 'package:pikuru/screens/group_chat_screen.dart';

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

  // ── Global navigator key — pass this to MaterialApp in main.dart ──────────
  static final navigatorKey = GlobalKey<NavigatorState>();

  final _fcm = FirebaseMessaging.instance;

  static final _plugin = FlutterLocalNotificationsPlugin();

  static const _channelId   = 'pikuru_notifications';
  static const _channelName = 'Pikuru Notifications';
  static const _channelDesc = 'Notifications from Pikuru pickleball app';

  bool _initialized = false;
  StreamSubscription<User?>? _authSub;

  // ── Public init ──────────────────────────────────────────────────────────
  Future<void> init() async {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await _requestPermission();

    if (!_initialized) {
      await _setupLocalNotifications();
      _initialized = true;
    }

    await _authSub?.cancel();

    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user != null) {
        await _saveToken();
      }
    });

    await _saveToken();

    _fcm.onTokenRefresh.listen(_saveTokenToFirestore);
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_onTap);

    final initial = await _fcm.getInitialMessage();
    if (initial != null) _onTap(initial);

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

      await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(channel);
    }

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
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      debugPrint('[FCM] Skipping token save — no user logged in');
      return;
    }
    final token = await _fcm.getToken();
    if (token != null) {
      await _saveTokenToFirestore(token);
    }
  }

  Future<void> _saveTokenToFirestore(String token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      debugPrint('[FCM] Skipping token save — no user logged in');
      return;
    }
    try {
      await FirebaseFirestore.instance.collection('registration').doc(uid).set({
        'fcm_token'      : token,
        'fcm_tokens'     : FieldValue.arrayUnion([token]),
        'platform'       : Platform.isIOS ? 'ios' : 'android',
        'fcm_updated_at' : FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('[FCM] Token saved to registration for uid=$uid');
    } catch (e) {
      debugPrint('[FCM] Save error: $e');
    }
  }

  Future<void> removeToken() async {
    final uid   = FirebaseAuth.instance.currentUser?.uid;
    final token = await _fcm.getToken();
    if (uid == null || token == null) return;
    try {
      await FirebaseFirestore.instance.collection('registration').doc(uid).update({
        'fcm_tokens' : FieldValue.arrayRemove([token]),
        'fcm_token'  : FieldValue.delete(),
      });
      await _fcm.deleteToken();
      await _authSub?.cancel();
      debugPrint('[FCM] Token removed');
    } catch (e) {
      debugPrint('[FCM] Remove error: $e');
    }
  }

  // ── Foreground message → show heads-up on Android ────────────────────────
  void _onForegroundMessage(RemoteMessage message) {
    final n = message.notification;
    if (n == null) return;

    if (Platform.isIOS) return;

    _plugin.show(
      n.hashCode,
      n.title,
      n.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance:         Importance.high,
          priority:           Priority.high,
          color:              Color(0xFF3A7D44),
          icon:               '@drawable/ic_notification',
        ),
      ),
      payload: message.data['route'],
    );
  }

  // ── Tap handlers ─────────────────────────────────────────────────────────
  void _onTap(RemoteMessage message) => _handlePayload(message.data['route']);

  // ── Navigate based on route payload ──────────────────────────────────────
  // Routes from Cloud Functions:
  //   /chats/individual/{chatId}  e.g. uid1_uid2
  //   /chats/group/{chatId}
  //   /events/{eventId}
  void _handlePayload(String? payload) {
    if (payload == null || payload.isEmpty) return;
    debugPrint('[FCM] Handling payload: $payload');

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final context = navigatorKey.currentContext;
      if (context == null) {
        debugPrint('[FCM] Navigator context not ready');
        return;
      }

      if (payload.startsWith('/chats/individual/')) {
        final chatId = payload.replaceFirst('/chats/individual/', '');
        await _openIndividualChat(context, chatId);
      } else if (payload.startsWith('/chats/group/')) {
        final chatId = payload.replaceFirst('/chats/group/', '');
        await _openGroupChat(context, chatId);
      }
    });
  }

  Future<void> _openIndividualChat(BuildContext context, String chatId) async {
    try {
      final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

      // chatId is formatted as uid1_uid2 — find the other uid
      final parts = chatId.split('_');
      final otherUid = parts.firstWhere(
            (p) => p != currentUid,
        orElse: () => '',
      );
      if (otherUid.isEmpty) return;

      // Look up other user's info from registration
      final doc = await FirebaseFirestore.instance
          .collection('registration')
          .doc(otherUid)
          .get();
      final data    = doc.data() ?? {};
      final nickname  = (data['nickname']  ?? '').toString().trim();
      final firstName = (data['firstName'] ?? '').toString().trim();
      final lastName  = (data['lastName']  ?? '').toString().trim();
      final name = nickname.isNotEmpty
          ? nickname
          : [firstName, lastName].where((s) => s.isNotEmpty).join(' ');
      final avatar = (data['profile_img'] ?? '').toString();

      if (!context.mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => IndividualChatScreen(
            otherUserId:     otherUid,
            otherUserName:   name.isNotEmpty ? name : 'User',
            otherUserAvatar: avatar,
          ),
        ),
      );
    } catch (e) {
      debugPrint('[FCM] _openIndividualChat error: $e');
    }
  }

  Future<void> _openGroupChat(BuildContext context, String chatId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('group_chats')
          .doc(chatId)
          .get();
      if (!doc.exists) return;
      final data = doc.data() ?? {};

      if (!context.mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => GroupChatScreen(group: {
            ...data,
            '_doc_id': chatId,
          }),
        ),
      );
    } catch (e) {
      debugPrint('[FCM] _openGroupChat error: $e');
    }
  }
}