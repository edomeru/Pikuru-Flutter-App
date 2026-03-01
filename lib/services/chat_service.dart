import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ChatService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  // ── Get or create a chat room for an org ──────────────────────────────
  static Future<String> getOrCreateChatId(String orgId) async {
    // Check if a chat already exists for this org
    final existing = await _db
        .collection('group_chats')
        .where('org_id', isEqualTo: orgId)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      return existing.docs.first.id;
    }

    // Create a new chat room
    final newChat = await _db.collection('group_chats').add({
      'org_id': orgId,
      'created_at': FieldValue.serverTimestamp(),
      'last_message': '',
      'last_message_at': FieldValue.serverTimestamp(),
      'last_message_by': '',
    });

    return newChat.id;
  }

  // ── Join chat (add user to members subcollection) ─────────────────────
  static Future<void> joinChat(String chatId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final memberRef = _db
        .collection('group_chats')
        .doc(chatId)
        .collection('members')
        .doc(user.uid);

    final existing = await memberRef.get();
    if (!existing.exists) {
      await memberRef.set({
        'user_id': user.uid,
        'display_name': user.displayName ?? 'Anonymous',
        'avatar_url': user.photoURL ?? '',
        'joined_at': FieldValue.serverTimestamp(),
        'role': 'member',
        'last_read_at': FieldValue.serverTimestamp(),
      });
    }
  }

  // ── Send a message ────────────────────────────────────────────────────
  static Future<void> sendMessage(String chatId, String text) async {
    final user = _auth.currentUser;
    if (user == null || text.trim().isEmpty) return;

    final trimmed = text.trim();

    // Add message to subcollection
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

    // Update last message on parent doc
    await _db.collection('group_chats').doc(chatId).update({
      'last_message': trimmed,
      'last_message_at': FieldValue.serverTimestamp(),
      'last_message_by': user.uid,
    });

    // Update this user's last_read_at
    await _db
        .collection('group_chats')
        .doc(chatId)
        .collection('members')
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

  // ── Stream member count ───────────────────────────────────────────────
  static Stream<int> memberCountStream(String chatId) {
    return _db
        .collection('group_chats')
        .doc(chatId)
        .collection('members')
        .snapshots()
        .map((snap) => snap.size);
  }

  // ── Update last_read_at when user opens chat ──────────────────────────
  static Future<void> markAsRead(String chatId) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _db
        .collection('group_chats')
        .doc(chatId)
        .collection('members')
        .doc(user.uid)
        .set({'last_read_at': FieldValue.serverTimestamp()},
        SetOptions(merge: true));
  }
}