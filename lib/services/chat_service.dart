import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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

    // ✅ Store created_by so ChatMembersScreen can identify the creator
    final newChat = await _db.collection('group_chats').add({
      'org_id': orgId,
      'created_by': user?.uid ?? '',        // ← NEW
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

    // Backfill created_by on existing docs that are missing it
    // (safe to run every time — only writes if field is absent)
    final chatDoc = await _db.collection('group_chats').doc(chatId).get();
    final data = chatDoc.data();
    if (data != null && (data['created_by'] ?? '').toString().isEmpty) {
      // Find the earliest member to use as creator
      final earliest = await _db
          .collection('group_chats')
          .doc(chatId)
          .collection('members')
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

  // ── Stream members subcollection ──────────────────────────────────────
  // Returns full member docs so ChatMembersScreen can render them directly
  static Stream<QuerySnapshot> membersStream(String chatId) {
    return _db
        .collection('group_chats')
        .doc(chatId)
        .collection('members')
        .orderBy('joined_at')
        .snapshots();
  }

  // ── Get creator uid for a chat ────────────────────────────────────────
  // Tries created_by field first; falls back to earliest joined_at member
  static Stream<String> creatorIdStream(String chatId) {
    return _db
        .collection('group_chats')
        .doc(chatId)
        .snapshots()
        .asyncMap((snap) async {
      // 1. Use created_by if it exists
      final createdBy = (snap.data()?['created_by'] ?? '').toString();
      if (createdBy.isNotEmpty) return createdBy;

      // 2. Fallback: first member by joined_at (oldest = creator)
      try {
        final q = await _db
            .collection('group_chats')
            .doc(chatId)
            .collection('members')
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
        .collection('members')
        .doc(user.uid)
        .set({'last_read_at': FieldValue.serverTimestamp()},
        SetOptions(merge: true));
  }
}