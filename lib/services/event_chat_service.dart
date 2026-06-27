import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// EventChatService
///
/// Mirrors the web app's event-chat helpers. Event chats live in the SAME
/// `group_chats` Firestore collection as regular group chats — they are
/// distinguished by:
///   - chatId convention: "event_<eventId>"
///   - chat_type: "event"
///   - notification_route: "/chats/event/<chatId>"
///
/// This service guarantees the event chat doc carries those tags so that
/// push-notification fan-out (Cloud Function) can route taps back to
/// EventChatScreen instead of GroupChatScreen.
class EventChatService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  /// Deterministic chatId for an event.
  static String chatIdForEvent(String eventId) => 'event_$eventId';

  /// Detect whether a `group_chats` doc represents an event chat.
  static bool isEventChat(String chatId, Map<String, dynamic>? data) {
    if ((data?['chat_type'] ?? '').toString() == 'event') return true;
    if (chatId.startsWith('event_')) return true;
    final route = (data?['notification_route'] ?? '').toString();
    if (route.startsWith('/chats/event/')) return true;
    return false;
  }

  /// Extract event_id from a chat doc / chatId, in that order of preference.
  static String resolveEventId(String chatId, Map<String, dynamic>? data) {
    final fromDoc = (data?['event_id'] ?? '').toString().trim();
    if (fromDoc.isNotEmpty) return fromDoc;
    if (chatId.startsWith('event_')) return chatId.substring('event_'.length);
    return '';
  }

  /// Create or update the event chat doc, stamping it with the routing tags.
  /// Safe to call repeatedly — uses merge:true.
  static Future<String> getOrCreateEventChat({
    required String eventId,
    String? eventName,
  }) async {
    final chatId = chatIdForEvent(eventId);
    final ref = _db.collection('group_chats').doc(chatId);
    final user = _auth.currentUser;

    final existing = await ref.get();
    final base = <String, dynamic>{
      'event_id': eventId,
      'chat_type': 'event',
      'notification_route': '/chats/event/$chatId',
      if (eventName != null && eventName.isNotEmpty) ...{
        'name': eventName,
        'event_name': eventName,
        // Used by FCM fan-out as the OS notification title so users see the
        // event chat name instead of a generic "Group Chat".
        'notification_title': eventName,
      },
    };

    if (!existing.exists) {
      await ref.set({
        ...base,
        'created_by': user?.uid ?? '',
        'created_at': FieldValue.serverTimestamp(),
      });
    } else {
      await ref.set(base, SetOptions(merge: true));
    }
    return chatId;
  }

  /// Join the event chat as a participant (chat presence only — NOT event
  /// registration). Mirrors web's joinChat behavior.
  static Future<void> joinEventChat(String chatId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final pRef = _db
        .collection('group_chats')
        .doc(chatId)
        .collection('participants')
        .doc(user.uid);

    final existing = await pRef.get();
    if (!existing.exists) {
      await pRef.set({
        'user_id': user.uid,
        'display_name': user.displayName ?? 'User',
        'avatar_url': user.photoURL ?? '',
        'joined_at': FieldValue.serverTimestamp(),
        'last_read_at': FieldValue.serverTimestamp(),
        'is_silenced': false,
      });
    } else {
      await pRef.set(
        {'last_read_at': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
    }
  }

  /// Fetch the event document for display (name / image / etc).
  static Future<Map<String, dynamic>> fetchEventData(String eventId) async {
    if (eventId.isEmpty) return {};
    try {
      final snap = await _db.collection('events').doc(eventId).get();
      if (!snap.exists) return {};
      return {
        ...?snap.data(),
        'event_id': eventId,
        '_doc_id': eventId,
      };
    } catch (_) {
      return {};
    }
  }
}
