import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pikuru/theme/material.dart';
import 'package:pikuru/providers/app_language_provider.dart';
import 'package:pikuru/screens/group_chat_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Design tokens
// ─────────────────────────────────────────────────────────────────────────────
class _C {
  static const white             = Colors.white;
  static const titleColor        = Color(0xFF111827);
  static const subtitleColor     = Color(0xFF6B7280);
  static const cancelBg          = Color(0xFFF3F4F6);
  static const cancelText        = Color(0xFF374151);
  static const divider           = Color(0xFFE5E7EB);
  static const iconBg            = Color(0xFFEDF7EF);
  static const iconColor         = Color(0xFF3A7D44);
  static const joinBg            = Color(0xFF3A7D44);
  static const joinText          = Colors.white;
  static const successGreen      = Color(0xFF3A7D44);
  static const interestIconBg    = Color(0xFFFFF0F3);
  static const interestIconColor = Color(0xFFE0445A);
  static const interestBtnBg     = Color(0xFFE0445A);
  static const interestBtnText   = Colors.white;
  static const toastSuccess      = Color(0xFF0D2816);
  static const toastError        = Color(0xFF4A1111);
  static const toastAccent       = Color(0xFF6ABF7A);
  static const toastErrAcc       = Color(0xFFFF4D4D);
}

// ─────────────────────────────────────────────────────────────────────────────
// Localisation
// ─────────────────────────────────────────────────────────────────────────────
const _L = {
  kLangEn: {
    'joinTitle':          'Join the Group?',
    'joinSub':            'You will be able to see group events and communicate with members.',
    'cancel':             'Cancel',
    'join':               'Join',
    'successTitle':       'Joined the Group\nSuccessfully!',
    'successSub':         'Want to communicate with the members\nof the group?',
    'no':                 'No',
    'yes':                'Yes',
    'errJoin':            'Failed to join group. Please try again.',
    'signInNeeded':       'Please sign in to join groups',
    'alreadyJoined':      'You have already joined this group',
    'interestTitle':      'Add to Favorites?',
    'interestSub':        'Save this group to your favorites and stay updated on their events.',
    'interestMark':       'Favorite',
    'errInterest':        'Failed to add to favorites.',
    'errAlreadyInterest': 'You have already added this group to favorites.',
    'toastInterest':      'Group added to your favorites!',
    'unfavoriteTitle':    'Remove from Favorites?',
    'unfavoriteSub':      'This group will be removed from your favorites list.',
    'unfavoriteConfirm':  'Remove',
    'toastUnfavorite':    'Removed from favorites.',
    'errUnfavorite':      'Failed to remove from favorites.',
  },
  kLangJa: {
    'joinTitle':          'グループに参加しますか？',
    'joinSub':            'グループのイベントを見たり、メンバーと連絡を取ることができます。',
    'cancel':             'キャンセル',
    'join':               '参加',
    'successTitle':       'グループに\n参加しました！',
    'successSub':         'グループのメンバーと\n連絡を取りますか？',
    'no':                 'いいえ',
    'yes':                'はい',
    'errJoin':            'グループへの参加に失敗しました。もう一度お試しください。',
    'signInNeeded':       'グループに参加するにはログインしてください',
    'alreadyJoined':      'すでにこのグループに参加しています',
    'interestTitle':      'お気に入りに追加しますか？',
    'interestSub':        'このグループをお気に入りに登録して、イベントの最新情報を受け取りましょう。',
    'interestMark':       'お気に入り',
    'errInterest':        'お気に入りの追加に失敗しました。',
    'errAlreadyInterest': 'このグループはすでにお気に入りに登録されています。',
    'toastInterest':      'お気に入りグループに追加しました！',
  },
};

String _t(String lang, String key) =>
    _L[lang]?[key] ?? _L[kLangEn]![key]!;

// ─────────────────────────────────────────────────────────────────────────────
// GroupDetailModals — public API
// ─────────────────────────────────────────────────────────────────────────────
class GroupDetailModals {

  // ── Resolve group ID — must match web: org_id first, then _doc_id ─────────
  static String resolveGroupId(Map<String, dynamic> group) {
    final orgId = group['org_id']?.toString() ?? '';
    if (orgId.isNotEmpty) return orgId;
    final docId = group['_doc_id']?.toString() ?? '';
    if (docId.isNotEmpty) return docId;
    final altId = group['org_org_id']?.toString() ??
        group['id']?.toString() ?? '';
    if (altId.isNotEmpty) return altId;
    final orgName = group['org_name']?.toString() ?? 'unknown';
    return orgName
        .toLowerCase()
        .replaceAll(' ', '_')
        .replaceAll(RegExp(r'[^a-z0-9_]'), '');
  }

  // ── Read current status from Firestore ────────────────────────────────────
  static Future<String?> getMembershipStatus(
      String userId, Map<String, dynamic> group) async {
    try {
      final groupId = resolveGroupId(group);
      final snap = await FirebaseFirestore.instance
          .collection('user_groups')
          .doc('${userId}_$groupId')
          .get();
      if (!snap.exists) return null;
      return snap.data()?['status']?.toString();
    } catch (e) {
      debugPrint('getMembershipStatus error: $e');
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // JOIN flow
  // Writes status → 'active'. Returns 'active' on success, null otherwise.
  // ─────────────────────────────────────────────────────────────────────────
  static Future<String?> showJoin(
      BuildContext context,
      Map<String, dynamic> group, {
        String lang = kLangEn,
      }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showToast(context, _t(lang, 'signInNeeded'), isError: true);
      return null;
    }

    final groupId = resolveGroupId(group);
    final docRef  = FirebaseFirestore.instance
        .collection('user_groups')
        .doc('${user.uid}_$groupId');

    if (!context.mounted) return null;

    // Step 1: confirm dialog
    final shouldJoin = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (_) => _JoinConfirmDialog(lang: lang),
    );
    if (shouldJoin != true || !context.mounted) return null;

    // Step 2: write
    bool spinnerActive = false;
    final nav = Navigator.of(context, rootNavigator: false);

    void showSpinner() {
      spinnerActive = true;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black.withOpacity(0.4),
        builder: (_) => const Center(
          child: CircularProgressIndicator(color: _C.joinBg, strokeWidth: 3),
        ),
      );
    }

    void dismissSpinner() {
      if (spinnerActive) { spinnerActive = false; if (nav.canPop()) nav.pop(); }
    }

    showSpinner();
    bool writeOk = false;
    try {
      final snap = await docRef.get();
      final bool currentlyFavorite = snap.exists && (snap.data()?['status'] == 'interested' || snap.data()?['is_favorite'] == true);
      await docRef.set({
        'user_id':               user.uid,
        'group_id':              groupId,
        'group_name':            group['org_name'] ?? 'Unnamed Group',
        'group_image':           group['org_image'] ?? '',
        'joined_at':             FieldValue.serverTimestamp(),
        'status':                'active',
        'is_favorite':           currentlyFavorite,
        'notifications_enabled': true,
      }, SetOptions(merge: true));
      writeOk = true;
    } catch (e) {
      debugPrint('❌ showJoin error: $e');
    }
    dismissSpinner();

    if (!context.mounted) return writeOk ? 'active' : null;
    if (!writeOk) {
      _showToast(context, _t(lang, 'errJoin'), isError: true);
      return null;
    }

    // Step 3: success dialog
    bool goToChat = false;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (ctx) => _SuccessDialog(
        lang: lang,
        onGoToChat: () { goToChat = true; Navigator.of(ctx).pop(); },
        onNo: () => Navigator.of(ctx).pop(),
      ),
    );

    if (goToChat && context.mounted) {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => GroupChatScreen(group: group)));
    }
    return 'active';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // INTERESTED flow
  // Works as a TOGGLE with Join — can be called even when status is 'active'.
  // When active → downgrades to 'interested' (re-enables Join button).
  // When none   → sets 'interested'.
  // When already interested → shows UN-FAVORITE dialog to remove.
  // Mirrors web handleInterest() exactly.
  // Returns the new status string, or null on cancel/error.
  // ─────────────────────────────────────────────────────────────────────────
  static Future<String?> showInterested(
      BuildContext context,
      Map<String, dynamic> group, {
        String lang = kLangEn,
        required String currentStatus,
        required bool isFavorite,
      }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showToast(context, _t(lang, 'signInNeeded'), isError: true);
      return null;
    }

    // Already interested → show un-favorite dialog (toggle off)
    if (isFavorite) {
      return showUnfavorite(context, group, lang: lang, currentStatus: currentStatus);
    }

    // Show confirm dialog (works for both 'none' AND 'active')
    if (!context.mounted) return null;
    final shouldMark = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (_) => _InterestConfirmDialog(lang: lang),
    );
    if (shouldMark != true || !context.mounted) return null;

    // Write status → 'interested' or keep 'active' if already joined
    final groupId = resolveGroupId(group);
    final docRef  = FirebaseFirestore.instance
        .collection('user_groups')
        .doc('${user.uid}_$groupId');

    bool spinnerActive = false;
    final nav = Navigator.of(context, rootNavigator: false);

    void showSpinner() {
      spinnerActive = true;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black.withOpacity(0.4),
        builder: (_) => const Center(
          child: CircularProgressIndicator(
              color: _C.interestBtnBg, strokeWidth: 3),
        ),
      );
    }

    void dismissSpinner() {
      if (spinnerActive) { spinnerActive = false; if (nav.canPop()) nav.pop(); }
    }

    showSpinner();
    bool writeOk = false;
    final newStatus = currentStatus == 'active' ? 'active' : 'interested';
    try {
      await docRef.set({
        'user_id':    user.uid,
        'group_id':   groupId,
        'group_name': group['org_name'] ?? 'Unnamed Group',
        'group_image': group['org_image'] ?? '',
        'marked_at':  FieldValue.serverTimestamp(),
        'status':     newStatus,
        'is_favorite': true,
      }, SetOptions(merge: true));
      writeOk = true;
    } catch (e) {
      debugPrint('❌ showInterested error: $e');
    }
    dismissSpinner();

    if (context.mounted) {
      _showToast(
        context,
        writeOk ? _t(lang, 'toastInterest') : _t(lang, 'errInterest'),
        isError: !writeOk,
      );
    }
    return writeOk ? newStatus : null;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // UN-FAVORITE flow
  // Called when the user taps the Favorite button while already favorited.
  // Shows a confirm dialog, then deletes the user_groups doc (or clears favorite if active).
  // Returns the new status string on success, null on cancel/error.
  // ─────────────────────────────────────────────────────────────────────────
  static Future<String?> showUnfavorite(
      BuildContext context,
      Map<String, dynamic> group, {
        String lang = kLangEn,
        required String currentStatus,
      }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    if (!context.mounted) return null;
    final shouldRemove = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (_) => _UnfavoriteConfirmDialog(lang: lang),
    );
    if (shouldRemove != true || !context.mounted) return null;

    final groupId = resolveGroupId(group);
    final docRef  = FirebaseFirestore.instance
        .collection('user_groups')
        .doc('${user.uid}_$groupId');

    bool spinnerActive = false;
    final nav = Navigator.of(context, rootNavigator: false);

    void showSpinner() {
      spinnerActive = true;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black.withOpacity(0.4),
        builder: (_) => const Center(
          child: CircularProgressIndicator(
              color: Color(0xFFF58C46), strokeWidth: 3),
        ),
      );
    }

    void dismissSpinner() {
      if (spinnerActive) { spinnerActive = false; if (nav.canPop()) nav.pop(); }
    }

    showSpinner();
    bool deleteOk = false;
    try {
      if (currentStatus == 'active') {
        await docRef.set({
          'is_favorite': false,
        }, SetOptions(merge: true));
      } else {
        await docRef.delete();
      }
      deleteOk = true;
    } catch (e) {
      debugPrint('❌ showUnfavorite error: $e');
    }
    dismissSpinner();

    if (context.mounted) {
      _showToast(
        context,
        deleteOk ? _t(lang, 'toastUnfavorite') : _t(lang, 'errUnfavorite'),
        isError: !deleteOk,
      );
    }
    return deleteOk ? (currentStatus == 'active' ? 'active' : 'none') : null;
  }

  // ── Toast ─────────────────────────────────────────────────────────────────
  static void _showToast(BuildContext context, String message,
      {required bool isError}) {
    if (!context.mounted) return;
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
        builder: (_) => _Toast(message: message, isError: isError));
    overlay.insert(entry);
    Future.delayed(const Duration(milliseconds: 3200), () {
      if (entry.mounted) entry.remove();
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _JoinConfirmDialog
// ─────────────────────────────────────────────────────────────────────────────
class _JoinConfirmDialog extends StatelessWidget {
  final String lang;
  const _JoinConfirmDialog({required this.lang});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Container(
        padding: const EdgeInsets.fromLTRB(28, 36, 28, 28),
        decoration: BoxDecoration(
          color: _C.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.18),
                blurRadius: 40, offset: const Offset(0, 16)),
          ],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72, height: 72,
            decoration: const BoxDecoration(
                color: _C.iconBg, shape: BoxShape.circle),
            child: const Icon(Icons.group_add_rounded,
                color: _C.iconColor, size: 32),
          ),
          const SizedBox(height: 24),
          Text(_t(lang, 'joinTitle'),
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w800,
                  color: _C.titleColor, letterSpacing: -0.3, height: 1.2),
              textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Text(_t(lang, 'joinSub'),
              style: const TextStyle(
                  fontSize: 15, color: _C.subtitleColor, height: 1.55),
              textAlign: TextAlign.center),
          const SizedBox(height: 32),
          Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.pop(context, false),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                      color: _C.cancelBg,
                      borderRadius: BorderRadius.circular(50)),
                  alignment: Alignment.center,
                  child: Text(_t(lang, 'cancel'),
                      style: const TextStyle(fontSize: 16,
                          fontWeight: FontWeight.w700, color: _C.cancelText)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(context, true);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                      color: _C.joinBg,
                      borderRadius: BorderRadius.circular(50)),
                  alignment: Alignment.center,
                  child: Text(_t(lang, 'join'),
                      style: const TextStyle(fontSize: 16,
                          fontWeight: FontWeight.w700, color: _C.joinText)),
                ),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SuccessDialog
// ─────────────────────────────────────────────────────────────────────────────
class _SuccessDialog extends StatelessWidget {
  final String lang;
  final VoidCallback onGoToChat;
  final VoidCallback onNo;
  const _SuccessDialog(
      {required this.lang, required this.onGoToChat, required this.onNo});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Container(
        padding: const EdgeInsets.fromLTRB(28, 36, 28, 28),
        decoration: BoxDecoration(
          color: _C.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.18),
                blurRadius: 40, offset: const Offset(0, 16)),
          ],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 500),
            curve: Curves.elasticOut,
            builder: (_, v, child) => Transform.scale(scale: v, child: child),
            child: Container(
              width: 72, height: 72,
              decoration: const BoxDecoration(
                  color: _C.iconBg, shape: BoxShape.circle),
              child: const Icon(Icons.check_circle_rounded,
                  color: _C.successGreen, size: 38),
            ),
          ),
          const SizedBox(height: 24),
          Text(_t(lang, 'successTitle'),
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w800,
                  color: _C.titleColor, letterSpacing: -0.3, height: 1.25),
              textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Text(_t(lang, 'successSub'),
              style: const TextStyle(
                  fontSize: 15, color: _C.subtitleColor, height: 1.55),
              textAlign: TextAlign.center),
          const SizedBox(height: 32),
          Container(
            decoration: BoxDecoration(
                color: _C.cancelBg, borderRadius: BorderRadius.circular(50)),
            child: Row(children: [
              Expanded(
                child: GestureDetector(
                  onTap: onNo,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    alignment: Alignment.center,
                    child: Text(_t(lang, 'no'),
                        style: const TextStyle(fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: _C.cancelText)),
                  ),
                ),
              ),
              Container(width: 1, height: 28, color: _C.divider),
              Expanded(
                child: GestureDetector(
                  onTap: onGoToChat,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                        color: _C.joinBg,
                        borderRadius: BorderRadius.circular(50)),
                    alignment: Alignment.center,
                    child: Text(_t(lang, 'yes'),
                        style: const TextStyle(fontSize: 16,
                            fontWeight: FontWeight.w700, color: _C.joinText)),
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _InterestConfirmDialog
// ─────────────────────────────────────────────────────────────────────────────
class _InterestConfirmDialog extends StatelessWidget {
  final String lang;
  const _InterestConfirmDialog({required this.lang});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Container(
        padding: const EdgeInsets.fromLTRB(28, 36, 28, 28),
        decoration: BoxDecoration(
          color: _C.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.18),
                blurRadius: 40, offset: const Offset(0, 16)),
          ],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72, height: 72,
            decoration: const BoxDecoration(
                color: _C.interestIconBg, shape: BoxShape.circle),
            child: const Icon(Icons.favorite_rounded,
                color: _C.interestIconColor, size: 32),
          ),
          const SizedBox(height: 24),
          Text(_t(lang, 'interestTitle'),
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w800,
                  color: _C.titleColor, letterSpacing: -0.3, height: 1.2),
              textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Text(_t(lang, 'interestSub'),
              style: const TextStyle(
                  fontSize: 15, color: _C.subtitleColor, height: 1.55),
              textAlign: TextAlign.center),
          const SizedBox(height: 32),
          Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.pop(context, false),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                      color: _C.cancelBg,
                      borderRadius: BorderRadius.circular(50)),
                  alignment: Alignment.center,
                  child: Text(_t(lang, 'cancel'),
                      style: const TextStyle(fontSize: 16,
                          fontWeight: FontWeight.w700, color: _C.cancelText)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(context, true);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                      color: _C.interestBtnBg,
                      borderRadius: BorderRadius.circular(50)),
                  alignment: Alignment.center,
                  child: Text(_t(lang, 'interestMark'),
                      style: const TextStyle(fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: _C.interestBtnText)),
                ),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _UnfavoriteConfirmDialog
// ─────────────────────────────────────────────────────────────────────────────
class _UnfavoriteConfirmDialog extends StatelessWidget {
  final String lang;
  const _UnfavoriteConfirmDialog({required this.lang});

  static const _orange = Color(0xFFF58C46);
  static const _orangeBg = Color(0xFFFFF4EC);
  static const _orangeBtn = Color(0xFFC0440A);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Container(
        padding: const EdgeInsets.fromLTRB(28, 36, 28, 28),
        decoration: BoxDecoration(
          color: _C.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.18),
                blurRadius: 40, offset: const Offset(0, 16)),
          ],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72, height: 72,
            decoration: const BoxDecoration(
                color: _orangeBg, shape: BoxShape.circle),
            child: const Icon(Icons.favorite_border_rounded,
                color: _orange, size: 32),
          ),
          const SizedBox(height: 24),
          Text(_t(lang, 'unfavoriteTitle'),
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w800,
                  color: _C.titleColor, letterSpacing: -0.3, height: 1.2),
              textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Text(_t(lang, 'unfavoriteSub'),
              style: const TextStyle(
                  fontSize: 15, color: _C.subtitleColor, height: 1.55),
              textAlign: TextAlign.center),
          const SizedBox(height: 32),
          Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.pop(context, false),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                      color: _C.cancelBg,
                      borderRadius: BorderRadius.circular(50)),
                  alignment: Alignment.center,
                  child: Text(_t(lang, 'cancel'),
                      style: const TextStyle(fontSize: 16,
                          fontWeight: FontWeight.w700, color: _C.cancelText)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(context, true);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                      color: _orangeBtn,
                      borderRadius: BorderRadius.circular(50)),
                  alignment: Alignment.center,
                  child: Text(_t(lang, 'unfavoriteConfirm'),
                      style: const TextStyle(fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Toast overlay
// ─────────────────────────────────────────────────────────────────────────────
class _Toast extends StatefulWidget {
  final String message;
  final bool isError;
  const _Toast({required this.message, required this.isError});

  @override
  State<_Toast> createState() => _ToastState();
}

class _ToastState extends State<_Toast> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _opacity;
  late final Animation<Offset>   _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 280));
    _opacity =
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, -0.6), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) _ctrl.reverse();
    });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final bg     = widget.isError ? _C.toastError  : _C.toastSuccess;
    final accent = widget.isError ? _C.toastErrAcc : _C.toastAccent;
    final icon   = widget.isError
        ? Icons.error_rounded
        : Icons.check_circle_rounded;
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 20, right: 20,
      child: FadeTransition(
        opacity: _opacity,
        child: SlideTransition(
          position: _slide,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: accent, width: 1),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.35),
                      blurRadius: 18, offset: const Offset(0, 6)),
                ],
              ),
              child: Row(children: [
                Icon(icon, color: accent, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(widget.message,
                      style: const TextStyle(fontSize: 14,
                          fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}