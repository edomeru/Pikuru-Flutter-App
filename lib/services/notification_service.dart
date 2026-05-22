import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:pikuru/screens/individual_chat_screen.dart';
import 'package:pikuru/screens/group_chat_screen.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM] Background message: ${message.messageId}');
  if (message.notification == null && message.data['silenced'] == 'true') {
    await NotificationService.instance._showSilentLocalNotification(message);
  }
}

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  debugPrint('[FCM] Background tap: ${response.payload}');
}

bool get _isIosSimulator => Platform.isIOS && kDebugMode && _checkSimulator();

bool _checkSimulator() {
  try {
    return Platform.environment['SIMULATOR_DEVICE_NAME'] != null ||
        Platform.environment['SIMULATOR_UDID'] != null;
  } catch (_) {
    return false;
  }
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static final navigatorKey = GlobalKey<NavigatorState>();

  final _fcm = FirebaseMessaging.instance;
  static final _plugin = FlutterLocalNotificationsPlugin();

  static const _channelId = 'pikuru_notifications';
  static const _channelName = 'Pikuru Notifications';
  static const _channelDesc = 'Notifications from Pikuru pickleball app';

  static const _silentChannelId = 'pikuru_silent';
  static const _silentChannelName = 'Pikuru Silent Notifications';
  static const _silentChannelDesc = 'Silent notifications for muted chats';

  bool _initialized = false;
  StreamSubscription<User?>? _authSub;

  Future<void> init() async {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await _requestPermission();
    if (!_initialized) {
      await _setupLocalNotifications();
      _initialized = true;
    }
    await _authSub?.cancel();
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user != null && !_isIosSimulator) {
        debugPrint('[FCM] Auth resolved for uid=${user.uid}, saving token...');
        await _saveToken();
      }
    });
    if (!_isIosSimulator) {
      _fcm.onTokenRefresh.listen(_saveTokenToFirestore);
    } else {
      debugPrint('[FCM] iOS Simulator — skipping token fetch');
    }
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_onTap);
    final initial = await _fcm.getInitialMessage();
    if (initial != null) _onTap(initial);
    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true, badge: true, sound: true,
    );
  }

  Future<void> _requestPermission() async {
    final s = await _fcm.requestPermission(alert: true, badge: true, sound: true);
    debugPrint('[FCM] Auth status: ${s.authorizationStatus}');
  }

  Future<void> _setupLocalNotifications() async {
    if (Platform.isAndroid) {
      // ── ONE LINE — do not split the generic across lines ─────────────────
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDesc,
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
          enableLights: true,
          ledColor: Color(0xFF3A7D44),
        ),
      );

      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          _silentChannelId,
          _silentChannelName,
          description: _silentChannelDesc,
          importance: Importance.low,
          playSound: false,
          enableVibration: false,
          enableLights: false,
        ),
      );
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

  Future<void> _saveToken() async {
    if (_isIosSimulator) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final token = await _fcm
          .getToken()
          .timeout(const Duration(seconds: 10), onTimeout: () => null);
      if (token != null) await _saveTokenToFirestore(token);
    } catch (e) {
      debugPrint('[FCM] getToken error: $e');
    }
  }

  Future<void> _saveTokenToFirestore(String token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance.collection('registration').doc(uid).set({
        'fcm_token': token,
        'fcm_tokens': FieldValue.arrayUnion([token]),
        'platform': Platform.isIOS ? 'ios' : 'android',
        'fcm_updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('[FCM] Token saved for uid=$uid');
    } catch (e) {
      debugPrint('[FCM] Save error: $e');
    }
  }

  Future<void> removeToken() async {
    if (_isIosSimulator) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final token = await _fcm.getToken().catchError((_) => null);
    if (uid == null || token == null) return;
    try {
      await FirebaseFirestore.instance.collection('registration').doc(uid).update({
        'fcm_tokens': FieldValue.arrayRemove([token]),
        'fcm_token': FieldValue.delete(),
      });
      await _fcm.deleteToken();
      await _authSub?.cancel();
    } catch (e) {
      debugPrint('[FCM] Remove error: $e');
    }
  }

  void _onForegroundMessage(RemoteMessage message) {
    final isSilenced = message.data['silenced'] == 'true';

    if (message.notification == null) {
      if (isSilenced) {
        _showSilentLocalNotification(message);
      }
      return;
    }

    if (Platform.isIOS) return;

    final n = message.notification!;
    _plugin.show(
      n.hashCode,
      n.title,
      n.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          isSilenced ? _silentChannelId : _channelId,
          isSilenced ? _silentChannelName : _channelName,
          channelDescription: isSilenced ? _silentChannelDesc : _channelDesc,
          importance: isSilenced ? Importance.low : Importance.high,
          priority: isSilenced ? Priority.low : Priority.high,
          playSound: !isSilenced,
          enableVibration: !isSilenced,
          color: const Color(0xFF3A7D44),
          icon: '@drawable/ic_notification',
        ),
      ),
      payload: message.data['route'],
    );
  }

  Future<void> _showSilentLocalNotification(RemoteMessage message) async {
    final title = message.data['title'] ?? 'New message';
    final body = message.data['body'] ?? '';
    final route = message.data['route'] ?? '';

    if (Platform.isAndroid) {
      await _plugin.show(
        message.hashCode,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _silentChannelId,
            _silentChannelName,
            channelDescription: _silentChannelDesc,
            importance: Importance.low,
            priority: Priority.low,
            playSound: false,
            enableVibration: false,
            enableLights: false,
            color: Color(0xFF3A7D44),
            icon: '@drawable/ic_notification',
          ),
        ),
        payload: route,
      );
    } else if (Platform.isIOS) {
      await _plugin.show(
        message.hashCode,
        title,
        body,
        const NotificationDetails(
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: false,
          ),
        ),
        payload: route,
      );
    }
  }

  void _onTap(RemoteMessage message) => _handlePayload(message.data['route']);

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
      final parts = chatId.split('_');
      final otherUid = parts.firstWhere((p) => p != currentUid, orElse: () => '');
      if (otherUid.isEmpty) return;

      final doc = await FirebaseFirestore.instance.collection('registration').doc(otherUid).get();
      final data = doc.data() ?? {};
      final nickname = (data['nickname'] ?? '').toString().trim();
      final firstName = (data['firstName'] ?? '').toString().trim();
      final lastName = (data['lastName'] ?? '').toString().trim();
      final name = nickname.isNotEmpty
          ? nickname
          : [firstName, lastName].where((s) => s.isNotEmpty).join(' ');
      final avatar = (data['profile_img'] ?? '').toString();

      if (!context.mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => IndividualChatScreen(
            otherUserId: otherUid,
            otherUserName: name.isNotEmpty ? name : 'User',
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
      final doc = await FirebaseFirestore.instance.collection('group_chats').doc(chatId).get();
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