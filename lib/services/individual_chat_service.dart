import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class IndividualChatService {
  static final _db   = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static String _chatId(String uid1, String uid2) {
    final sorted = [uid1, uid2]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  // ── Resolve a user's profile from registration collection ──────────────
  static Future<Map<String, String>> _resolveProfile(String uid) async {
    try {
      final snap = await _db.collection('registration').doc(uid).get();
      if (snap.exists) {
        final d      = snap.data()!;
        final rawImg = (d['profile_img'] ?? '').toString();
        final nick   = (d['nickname']   ?? '').toString().trim();
        final first  = (d['firstName']  ?? '').toString().trim();
        final last   = (d['lastName']   ?? '').toString().trim();
        final name   = nick.isNotEmpty
            ? nick
            : (first.isNotEmpty && last.isNotEmpty)
            ? '$first $last'
            : first.isNotEmpty ? first : '';
        return {'name': name, 'avatar': rawImg};
      }
    } catch (_) {}
    return {'name': '', 'avatar': ''};
  }

  static Future<String> getOrCreateChat({
    required String otherUserId,
    required String otherUserName,
    required String otherUserAvatar,
  }) async {
    final me = _auth.currentUser;
    if (me == null) throw Exception('Not authenticated');

    // ── Always read both profiles from registration ──────────────────────
    final myProfile    = await _resolveProfile(me.uid);
    final otherProfile = await _resolveProfile(otherUserId);

    final myName    = myProfile['name']!.isNotEmpty
        ? myProfile['name']!
        : me.displayName ?? 'Unknown';
    final myAvatar  = myProfile['avatar']!;   // raw base64 or http or ''

    final resolvedOtherName   = otherProfile['name']!.isNotEmpty
        ? otherProfile['name']!
        : otherUserName;
    final resolvedOtherAvatar = otherProfile['avatar']!.isNotEmpty
        ? otherProfile['avatar']!
        : otherUserAvatar;

    final chatId  = _chatId(me.uid, otherUserId);
    final chatRef = _db.collection('individual_chats').doc(chatId);

    final existing = await chatRef.get();
    if (!existing.exists) {
      await chatRef.set({
        'participants': [me.uid, otherUserId],
        'participant_names': {
          me.uid:      myName,
          otherUserId: resolvedOtherName,
        },
        'participant_avatars': {
          me.uid:      myAvatar,
          otherUserId: resolvedOtherAvatar,
        },
        'created_at':      FieldValue.serverTimestamp(),
        'last_message':    '',
        'last_message_at': FieldValue.serverTimestamp(),
        'last_message_by': '',
        'last_read': {
          me.uid: FieldValue.serverTimestamp(),
        },
      });
    } else {
      // Always refresh both sides with latest registration data
      await chatRef.update({
        'participant_names.${me.uid}':       myName,
        'participant_avatars.${me.uid}':     myAvatar,
        'participant_names.$otherUserId':    resolvedOtherName,
        'participant_avatars.$otherUserId':  resolvedOtherAvatar,
      });
    }

    await markAsRead(chatId);
    return chatId;
  }

  static Future<void> markAsRead(String chatId) async {
    final me = _auth.currentUser;
    if (me == null) return;
    try {
      await _db.collection('individual_chats').doc(chatId).update({
        'last_read.${me.uid}': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  static Future<void> sendMessage(String chatId, String text) async {
    final me = _auth.currentUser;
    if (me == null || text.trim().isEmpty) return;

    // ── Use registration profile for sender info ─────────────────────────
    final myProfile = await _resolveProfile(me.uid);
    final myName    = myProfile['name']!.isNotEmpty
        ? myProfile['name']!
        : me.displayName ?? 'Anonymous';
    final myAvatar  = myProfile['avatar']!;

    final trimmed = text.trim();
    final chatRef = _db.collection('individual_chats').doc(chatId);

    await chatRef.collection('messages').add({
      'sender_id':     me.uid,
      'sender_name':   myName,
      'sender_avatar': myAvatar,
      'text':          trimmed,
      'sent_at':       FieldValue.serverTimestamp(),
    });

    await chatRef.update({
      'last_message':             trimmed,
      'last_message_at':          FieldValue.serverTimestamp(),
      'last_message_by':          me.uid,
      'last_read.${me.uid}':      FieldValue.serverTimestamp(),
    });
  }

  static Stream<QuerySnapshot> messagesStream(String chatId) {
    return _db
        .collection('individual_chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('sent_at', descending: false)
        .snapshots();
  }

  static Stream<QuerySnapshot> myChatsStream() {
    final me = _auth.currentUser;
    if (me == null) return const Stream.empty();
    return _db
        .collection('individual_chats')
        .where('participants', arrayContains: me.uid)
        .orderBy('last_message_at', descending: true)
        .snapshots();
  }
}