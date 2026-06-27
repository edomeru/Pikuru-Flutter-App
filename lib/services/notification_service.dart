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
import 'package:pikuru/screens/event_chat_screen.dart';
import 'package:pikuru/services/event_chat_service.dart';

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

  // ── Routing helpers ──────────────────────────────────────────────────────
  String _routeFromData(Map<String, dynamic> data) {
    final route = (data['route'] ?? data['notification_route'] ?? '').toString();
    if (route.isNotEmpty) return route;
    final chatId = (data['chat_id'] ?? '').toString();
    final chatType = (data['chat_type'] ?? '').toString();
    if (chatId.isNotEmpty) {
      if (chatType == 'event' || chatId.startsWith('event_')) {
        return '/chats/event/$chatId';
      }
      return '/chats/group/$chatId';
    }
    return '';
  }

  /// Build a payload string with optional tab info appended as a query so the
  /// local-notification tap handler (which only receives a string) can still
  /// know which tab to open.
  ///
  /// For event chats, if the backend didn't already set `notification_tab`/`tab`,
  /// we infer it from the message's broadcast flags:
  ///   - is_broadcast == true  OR  type == 'broadcast'  → 'announcements'
  ///   - otherwise                                       → 'general'
  String _buildPayload(RemoteMessage message) {
    final data = message.data;
    var route = _routeFromData(data);
    if (route.isEmpty) return '';

    String upsertQueryParam(String value, String key, String paramValue) {
      final qIdx = value.indexOf('?');
      final base = qIdx >= 0 ? value.substring(0, qIdx) : value;
      final query = qIdx >= 0 ? value.substring(qIdx + 1) : '';
      final params = <String, String>{};

      if (query.isNotEmpty) {
        for (final pair in query.split('&')) {
          if (pair.isEmpty) continue;
          final eq = pair.indexOf('=');
          if (eq < 0) {
            params[pair] = '';
          } else {
            params[pair.substring(0, eq)] = pair.substring(eq + 1);
          }
        }
      }

      params[key] = Uri.encodeQueryComponent(paramValue);
      final nextQuery = params.entries
          .map((e) => e.value.isEmpty ? e.key : '${e.key}=${e.value}')
          .join('&');
      return nextQuery.isEmpty ? base : '$base?$nextQuery';
    }

    var tab = (data['notification_tab'] ?? data['tab'] ?? '').toString();

    final chatType = (data['chat_type'] ?? '').toString();
    final chatId = (data['chat_id'] ?? '').toString();
    final isEventChat = route.startsWith('/chats/event/') ||
        chatType == 'event' ||
        chatId.startsWith('event_');

    if (isEventChat) {
      // Message fields are more reliable than a generic/stale tab value.
      // Broadcast messages must open Announcements; every explicit
      // non-broadcast event message must open General Chat.
      if (_isBroadcastFromData(data)) {
        tab = 'announcements';
      } else if (_isGeneralFromData(data)) {
        tab = 'general';
      }
    }

    if (tab.isNotEmpty) {
      route = upsertQueryParam(route, 'tab', tab);
    }

    // Carry the message_id through the payload so the tap handler can fetch
    // the exact Firestore message document and infer the correct tab even
    // when the FCM data payload didn't include broadcast flags.
    final msgId = (data['message_id'] ??
        data['messageId'] ??
        data['msg_id'] ??
        data['id'] ??
        '')
        .toString();
    if (msgId.isNotEmpty) {
      route = upsertQueryParam(route, 'msg', msgId);
    }
    return route;
  }

  /// True if FCM data carries any signal that the message is a broadcast.
  bool _isBroadcastFromData(Map<String, dynamic> data) {
    bool truthy(dynamic v) {
      if (v == true) return true;
      if (v is String) {
        final s = v.toLowerCase().trim();
        return s == 'true' || s == '1' || s == 'yes';
      }
      if (v is num) return v != 0;
      return false;
    }
    if (truthy(data['is_broadcast'])) return true;
    if (truthy(data['isBroadcast'])) return true;
    if (truthy(data['broadcast'])) return true;
    final t = (data['type'] ?? '').toString().toLowerCase();
    final mt = (data['message_type'] ?? '').toString().toLowerCase();
    final nt = (data['notification_type'] ?? '').toString().toLowerCase();
    if (t == 'broadcast' || t == 'announcement') return true;
    if (mt == 'broadcast' || mt == 'announcement') return true;
    if (nt == 'broadcast' || nt == 'announcement') return true;
    return false;
  }

  /// True if FCM data explicitly says this is a normal event-chat message.
  bool _isGeneralFromData(Map<String, dynamic> data) {
    bool falsey(dynamic v) {
      if (v == false) return true;
      if (v is String) {
        final s = v.toLowerCase().trim();
        return s == 'false' || s == '0' || s == 'no';
      }
      if (v is num) return v == 0;
      return false;
    }

    if (falsey(data['is_broadcast'])) return true;
    if (falsey(data['isBroadcast'])) return true;
    if (falsey(data['broadcast'])) return true;

    bool generalType(dynamic v) {
      final s = (v ?? '').toString().toLowerCase().trim();
      if (s.isEmpty) return false;
      return s == 'text' ||
          s == 'message' ||
          s == 'image' ||
          s == 'photo' ||
          s == 'audio' ||
          s == 'voice' ||
          s == 'file' ||
          s == 'general' ||
          s == 'chat' ||
          s == 'chat_message' ||
          s == 'group_message';
    }

    if (generalType(data['type'])) return true;
    if (generalType(data['message_type'])) return true;
    if (generalType(data['notification_type'])) return true;
    return false;
  }

  // ── Title resolution (overrides backend "Group Chat" for event chats) ──
  //
  // Backend currently sends notification.title = "Group Chat" for any
  // group_chats doc — including event chats. We try to override it here:
  //   1. If FCM data contains notification_title / event_name / chat_title, use it.
  //   2. Else if this is an event chat (by chat_type OR chatId convention OR route),
  //      look up the group_chats doc (notification_title / name / event_name) and
  //      then fall back to events/{eventId}.event_name.
  //   3. Else fall back to the original notification.title.
  //
  // NOTE: This only affects FOREGROUND notifications and silenced (data-only)
  // notifications. When the app is in the BACKGROUND and the FCM message
  // includes a `notification` payload, Android renders the OS notification
  // using `notification.title` directly — Flutter code does not run before
  // the banner appears, and we cannot rewrite it. The only complete fix for
  // background is server-side (Cloud Function should set notification.title
  // from group_chats.notification_title / event_name).
  Future<String?> _resolveDisplayTitle(RemoteMessage message) async {
    final data = message.data;
    final explicit = (data['notification_title'] ??
        data['event_name'] ??
        data['chat_title'] ??
        '')
        .toString();
    if (explicit.isNotEmpty) return explicit;

    final chatType = (data['chat_type'] ?? '').toString();
    final route = _routeFromData(data);

    // Resolve chatId from payload
    String chatId = (data['chat_id'] ?? '').toString();
    if (chatId.isEmpty && route.startsWith('/chats/event/')) {
      chatId = route.substring('/chats/event/'.length).split('?').first;
    }
    if (chatId.isEmpty && route.startsWith('/chats/group/')) {
      chatId = route.substring('/chats/group/'.length).split('?').first;
    }

    final isEvent = chatType == 'event' ||
        route.startsWith('/chats/event/') ||
        chatId.startsWith('event_');
    if (!isEvent) return message.notification?.title;

    // Try the group_chats doc first — it carries the most up-to-date title.
    if (chatId.isNotEmpty) {
      try {
        final snap = await FirebaseFirestore.instance
            .collection('group_chats')
            .doc(chatId)
            .get();
        final d = snap.data();
        if (d != null) {
          final t = (d['notification_title'] ??
              d['name'] ??
              d['event_name'] ??
              '')
              .toString()
              .trim();
          if (t.isNotEmpty) return t;
        }
      } catch (e) {
        debugPrint('[FCM] _resolveDisplayTitle group_chats fetch failed: $e');
      }
    }

    // Fall back to the events doc.
    String eventId = (data['event_id'] ?? '').toString();
    if (eventId.isEmpty && chatId.startsWith('event_')) {
      eventId = chatId.substring('event_'.length);
    }
    if (eventId.isEmpty) return message.notification?.title;

    try {
      final snap = await FirebaseFirestore.instance
          .collection('events').doc(eventId).get();
      final d = snap.data() ?? {};
      final name = (d['event_name'] ?? d['event_title'] ?? '')
          .toString()
          .trim();
      if (name.isNotEmpty) return name;
    } catch (e) {
      debugPrint('[FCM] _resolveDisplayTitle events fetch failed: $e');
    }
    return message.notification?.title;
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
    final payload = _buildPayload(message);
    // Override title async without blocking the show — show fallback first,
    // then if a better title resolves quickly, re-show with the same id.
    _resolveDisplayTitle(message).then((title) {
      _plugin.show(
        n.hashCode,
        title ?? n.title,
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
        payload: payload,
      );
    });
  }

  Future<void> _showSilentLocalNotification(RemoteMessage message) async {
    final resolved = await _resolveDisplayTitle(message);
    final title = resolved ?? (message.data['title'] ?? 'New message').toString();
    final body = (message.data['body'] ?? '').toString();
    final payload = _buildPayload(message);

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
        payload: payload,
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
        payload: payload,
      );
    }
  }

  void _onTap(RemoteMessage message) => _handlePayload(_buildPayload(message));

  void _handlePayload(String? payload) {
    if (payload == null || payload.isEmpty) return;
    debugPrint('[FCM] Handling payload: $payload');

    // Split route and query (tab=..., msg=...)
    String route = payload;
    String? tab;
    String? messageId;
    final qIdx = payload.indexOf('?');
    if (qIdx >= 0) {
      route = payload.substring(0, qIdx);
      final qs = payload.substring(qIdx + 1);
      for (final pair in qs.split('&')) {
        final eq = pair.indexOf('=');
        if (eq < 0) continue;
        final k = pair.substring(0, eq);
        final v = pair.substring(eq + 1);
        if (k == 'tab') tab = v;
        if (k == 'msg') messageId = v;
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final context = navigatorKey.currentContext;
      if (context == null) {
        debugPrint('[FCM] Navigator context not ready');
        return;
      }
      if (route.startsWith('/chats/individual/')) {
        final chatId = route.replaceFirst('/chats/individual/', '');
        await _openIndividualChat(context, chatId);
      } else if (route.startsWith('/chats/event/')) {
        final chatId = route.replaceFirst('/chats/event/', '');
        final resolvedTab =
        await _resolveEventTab(chatId, tab, messageId: messageId);
        await _openEventChat(context, chatId, initialTab: resolvedTab);
      } else if (route.startsWith('/chats/group/')) {
        final chatId = route.replaceFirst('/chats/group/', '');
        // IMPORTANT: backend sends /chats/group/<id> for event chats too,
        // because they live in the same `group_chats` collection. Detect
        // and redirect before falling back to GroupChatScreen.
        final resolvedTab =
        await _resolveEventTab(chatId, tab, messageId: messageId);
        await _openGroupOrEventChat(context, chatId, initialTab: resolvedTab);
      }
    });
  }

  /// Resolve which event-chat tab a notification tap should land on.
  ///
  /// Priority:
  ///   1. The exact message doc (`messages/{messageId}`) referenced by the
  ///      notification — most accurate, and prevents stale tab values from
  ///      opening General Chat messages in Announcements.
  ///   2. Explicit `tab` from the FCM payload.
  ///   3. Fallback: the newest message in the chat.
  ///   4. Default to 'general' if everything fails.
  Future<String?> _resolveEventTab(String chatId, String? tab,
      {String? messageId}) async {
    // 1. Try the exact message document first.
    if (messageId != null && messageId.isNotEmpty) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('group_chats')
            .doc(chatId)
            .collection('messages')
            .doc(messageId)
            .get();
        if (doc.exists) {
          final d = doc.data() ?? {};
          final isBroadcast = d['is_broadcast'] == true ||
              (d['type'] ?? '').toString() == 'broadcast';
          return isBroadcast ? 'announcements' : 'general';
        }
      } catch (e) {
        debugPrint('[FCM] _resolveEventTab message fetch error: $e');
      }
    }

    // 2. Use the explicit tab only after the exact message doc check, because
    // backend payloads can occasionally carry a stale/default tab value.
    if (tab != null && tab.isNotEmpty) return tab;

    // 3. Fallback: inspect only the newest message. Do not scan several recent
    // messages, because an older broadcast would incorrectly force a new
    // General Chat notification to open Announcements.
    try {
      final snap = await FirebaseFirestore.instance
          .collection('group_chats')
          .doc(chatId)
          .collection('messages')
          .orderBy('sent_at', descending: true)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return 'general';

      final d = snap.docs.first.data();
      final isBroadcast = d['is_broadcast'] == true ||
          (d['type'] ?? '').toString() == 'broadcast';
      return isBroadcast ? 'announcements' : 'general';
    } catch (e) {
      debugPrint('[FCM] _resolveEventTab error: $e');
      return tab ?? 'general';
    }
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

  /// Decides between EventChatScreen and GroupChatScreen for a `group_chats`
  /// doc. Event chats are identified by `chat_type == 'event'` or the
  /// "event_" chatId convention.
  Future<void> _openGroupOrEventChat(BuildContext context, String chatId,
      {String? initialTab}) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('group_chats').doc(chatId).get();
      if (!doc.exists) return;
      final data = doc.data() ?? {};

      if (EventChatService.isEventChat(chatId, data)) {
        final eventId = EventChatService.resolveEventId(chatId, data);
        final eventData = await EventChatService.fetchEventData(eventId);
        if (!context.mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => EventChatScreen(
              chatId: chatId,
              eventData: eventData,
              initialTab: initialTab,
            ),
          ),
        );
        return;
      }

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
      debugPrint('[FCM] _openGroupOrEventChat error: $e');
    }
  }

  Future<void> _openEventChat(BuildContext context, String chatId,
      {String? initialTab}) async {
    try {
      final chatDoc = await FirebaseFirestore.instance
          .collection('group_chats').doc(chatId).get();
      final chatData = chatDoc.data() ?? {};

      final eventId = EventChatService.resolveEventId(chatId, chatData);
      final eventData = await EventChatService.fetchEventData(eventId);

      if (!context.mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => EventChatScreen(
            chatId: chatId,
            eventData: eventData,
            initialTab: initialTab,
          ),
        ),
      );
    } catch (e) {
      debugPrint('[FCM] _openEventChat error: $e');
    }
  }
}
