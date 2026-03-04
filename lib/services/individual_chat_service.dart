import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class IndividualChatService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static String _chatId(String uid1, String uid2) {
    final sorted = [uid1, uid2]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  static Future<String> getOrCreateChat({
    required String otherUserId,
    required String otherUserName,
    required String otherUserAvatar,
  }) async {
    final me = _auth.currentUser;
    if (me == null) throw Exception('Not authenticated');

    final chatId = _chatId(me.uid, otherUserId);
    final chatRef = _db.collection('individual_chats').doc(chatId);

    final existing = await chatRef.get();
    if (!existing.exists) {
      await chatRef.set({
        'participants': [me.uid, otherUserId],
        'participant_names': {
          me.uid: me.displayName ?? 'Unknown',
          otherUserId: otherUserName,
        },
        'participant_avatars': {
          me.uid: me.photoURL ?? '',
          otherUserId: otherUserAvatar,
        },
        'created_at': FieldValue.serverTimestamp(),
        'last_message': '',
        'last_message_at': FieldValue.serverTimestamp(),
        'last_message_by': '',
      });
    } else {
      await chatRef.update({
        'participant_names.${me.uid}': me.displayName ?? 'Unknown',
        'participant_avatars.${me.uid}': me.photoURL ?? '',
        'participant_names.$otherUserId': otherUserName,
        'participant_avatars.$otherUserId': otherUserAvatar,
      });
    }

    return chatId;
  }

  static Future<void> sendMessage(String chatId, String text) async {
    final me = _auth.currentUser;
    if (me == null || text.trim().isEmpty) return;

    final trimmed = text.trim();
    final chatRef = _db.collection('individual_chats').doc(chatId);

    await chatRef.collection('messages').add({
      'sender_id': me.uid,
      'sender_name': me.displayName ?? 'Anonymous',
      'sender_avatar': me.photoURL ?? '',
      'text': trimmed,
      'sent_at': FieldValue.serverTimestamp(),
    });

    await chatRef.update({
      'last_message': trimmed,
      'last_message_at': FieldValue.serverTimestamp(),
      'last_message_by': me.uid,
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