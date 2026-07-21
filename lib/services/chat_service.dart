import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// KEY FIX:
/// The `members` subcollection under group_chats was being written to by
/// joinChat() for EVERY user who opened the chat screen. JoinGroupModal
/// (or any join-check logic) was then reading `members` and incorrectly
/// concluding every user had already "officially joined the group."
///
/// Solution: joinChat() now writes to a `participants` subcollection
/// (chat-only presence), while `members` is reserved exclusively for users
/// who explicitly click the Join button via JoinGroupModal.
///
/// Firestore structure:
/// group_chats/{chatId}
///   ├── participants/   ← anyone who opened the chat (chat presence only)
///   └── messages/       ← chat messages

class ChatService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  // ── Get or create a chat room for an org ──────────────────────────────
  static Future<String> getOrCreateChatId(String orgId) async {
    final existing = await _db
        .collection('group_chats')
        .where('org_id', isEqualTo: orgId)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      return existing.docs.first.id;
    }

    final user = _auth.currentUser;

    final newChat = await _db.collection('group_chats').add({
      'org_id': orgId,
      'created_by': user?.uid ?? '',
      'created_at': FieldValue.serverTimestamp(),
      'last_message': '',
      'last_message_at': FieldValue.serverTimestamp(),
      'last_message_by': '',
    });

    return newChat.id;
  }

  // ── Join chat as a PARTICIPANT (chat presence only) ───────────────────
  // ✅ Writes to `participants` subcollection — NOT `members`
  // This does NOT mean the user has officially joined the group.
  static Future<void> joinChat(String chatId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final participantRef = _db
        .collection('group_chats')
        .doc(chatId)
        .collection('participants')
        .doc(user.uid);

    final existing = await participantRef.get();
    if (!existing.exists) {
      await participantRef.set({
        'user_id': user.uid,
        'display_name': user.displayName ?? 'Anonymous',
        'avatar_url': user.photoURL ?? '',
        'joined_at': FieldValue.serverTimestamp(),
        'last_read_at': FieldValue.serverTimestamp(),
      });
    }

    // Backfill created_by for old docs missing the field
    final chatDoc = await _db.collection('group_chats').doc(chatId).get();
    final data = chatDoc.data();
    if (data != null && (data['created_by'] ?? '').toString().isEmpty) {
      final earliest = await _db
          .collection('group_chats')
          .doc(chatId)
          .collection('participants')
          .orderBy('joined_at')
          .limit(1)
          .get();
      if (earliest.docs.isNotEmpty) {
        await _db.collection('group_chats').doc(chatId).update({
          'created_by': earliest.docs.first.id,
        });
      }
    }
  }

  // ── Send a message ────────────────────────────────────────────────────
  static Future<void> sendMessage(String chatId, String text) async {
    final user = _auth.currentUser;
    if (user == null || text.trim().isEmpty) return;

    final trimmed = text.trim();

    await _db
        .collection('group_chats')
        .doc(chatId)
        .collection('messages')
        .add({
      'sender_id': user.uid,
      'sender_name': user.displayName ?? 'Anonymous',
      'sender_avatar': user.photoURL ?? '',
      'text': trimmed,
      'sent_at': FieldValue.serverTimestamp(),
    });

    await _db.collection('group_chats').doc(chatId).update({
      'last_message': trimmed,
      'last_message_at': FieldValue.serverTimestamp(),
      'last_message_by': user.uid,
    });

    await _db
        .collection('group_chats')
        .doc(chatId)
        .collection('participants')
        .doc(user.uid)
        .set({'last_read_at': FieldValue.serverTimestamp()},
        SetOptions(merge: true));
  }

  // ── Stream messages in real time ──────────────────────────────────────
  static Stream<QuerySnapshot> messagesStream(String chatId) {
    return _db
        .collection('group_chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('sent_at', descending: false)
        .snapshots();
  }

  // ── Stream participant count (people in the chat) ─────────────────────
  static Stream<int> memberCountStream(String chatId) {
    return _db
        .collection('group_chats')
        .doc(chatId)
        .collection('participants')
        .snapshots()
        .map((snap) => snap.size);
  }

  // ── Stream participants for ChatMembersScreen ─────────────────────────
  // NOTE: do NOT orderBy('joined_at') — Firestore excludes docs missing that
  // field, which would hide members added via approval / "Open Chat".
  // The screen sorts client-side (creator first), so ordering here isn't needed.
  static Stream<QuerySnapshot> membersStream(String chatId) {
    return _db
        .collection('group_chats')
        .doc(chatId)
        .collection('participants')
        .snapshots();
  }

  // ── Get creator uid for a chat ────────────────────────────────────────
  static Stream<String> creatorIdStream(String chatId) {
    return _db
        .collection('group_chats')
        .doc(chatId)
        .snapshots()
        .asyncMap((snap) async {
      final createdBy = (snap.data()?['created_by'] ?? '').toString();
      if (createdBy.isNotEmpty) return createdBy;

      try {
        final q = await _db
            .collection('group_chats')
            .doc(chatId)
            .collection('participants')
            .orderBy('joined_at')
            .limit(1)
            .get();
        if (q.docs.isNotEmpty) return q.docs.first.id;
      } catch (_) {}

      return '';
    });
  }

  // ── Update last_read_at when user opens chat ──────────────────────────
  static Future<void> markAsRead(String chatId) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _db
        .collection('group_chats')
        .doc(chatId)
        .collection('participants')
        .doc(user.uid)
        .set({'last_read_at': FieldValue.serverTimestamp()},
        SetOptions(merge: true));
  }
}