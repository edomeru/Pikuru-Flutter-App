import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BlockService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static Future<void> blockUser(String otherUserId) async {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) return;
    final docId = '${myUid}_$otherUserId';
    await _db.collection('blocks').doc(docId).set({
      'blocker_id': myUid,
      'blocked_id': otherUserId,
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> unblockUser(String otherUserId) async {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) return;
    final docId = '${myUid}_$otherUserId';
    await _db.collection('blocks').doc(docId).delete();
  }

  static Stream<bool> streamIsBlocked(String otherUserId) {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) return Stream.value(false);
    final docId = '${myUid}_$otherUserId';
    return _db
        .collection('blocks')
        .doc(docId)
        .snapshots()
        .map((snap) => snap.exists);
  }

  static Stream<bool> streamIsBlockedBy(String otherUserId) {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) return Stream.value(false);
    final docId = '${otherUserId}_$myUid';
    return _db
        .collection('blocks')
        .doc(docId)
        .snapshots()
        .map((snap) => snap.exists);
  }

  static Stream<List<String>> streamBlockedUsers() {
    final myUid = _auth.currentUser?.uid;
    if (myUid == null) return Stream.value([]);
    return _db
        .collection('blocks')
        .where('blocker_id', isEqualTo: myUid)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => (doc.data()['blocked_id'] ?? '').toString())
            .where((id) => id.isNotEmpty)
            .toList());
  }
}
