import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pikuru/theme/material.dart';
import 'package:pikuru/providers/app_language_provider.dart';
import 'package:pikuru/screens/group_chat_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Design tokens — light / white modal design (matches screenshot)
// ─────────────────────────────────────────────────────────────────────────────
class _C {
  static const white        = Colors.white;
  static const iconBg       = Color(0xFFEDF7EF);   // very light green circle
  static const iconColor    = Color(0xFF3A7D44);   // dark green icon
  static const titleColor   = Color(0xFF111827);   // near-black
  static const subtitleColor= Color(0xFF6B7280);   // grey
  static const cancelBg     = Color(0xFFF3F4F6);   // light grey pill
  static const cancelText   = Color(0xFF374151);   // dark grey text
  static const joinBg       = Color(0xFF3A7D44);   // solid dark green
  static const joinText     = Colors.white;
  static const successGreen = Color(0xFF3A7D44);
  static const divider      = Color(0xFFE5E7EB);
  // Toast
  static const toastSuccess = Color(0xFF0D2816);
  static const toastError   = Color(0xFF4A1111);
  static const toastAccent  = Color(0xFF6ABF7A);
  static const toastErrAcc  = Color(0xFFFF4D4D);
}

// ─────────────────────────────────────────────────────────────────────────────
// Localization — mirrors web app T.modal exactly
// ─────────────────────────────────────────────────────────────────────────────
const _L = {
  kLangEn: {
    'joinTitle':     'Join the Group?',
    'joinSub':       'You will be able to see group events and communicate with members.',
    'cancel':        'Cancel',
    'join':          'Join',
    'successTitle':  'Joined the Group\nSuccessfully!',
    'successSub':    'Want to communicate with the members\nof the group?',
    'no':            'No',
    'yes':           'Yes',
    'errJoin':       'Failed to join group. Please try again.',
    'signInNeeded':  'Please sign in to join groups',
    'alreadyJoined': 'You have already joined this group',
  },
  kLangJa: {
    'joinTitle':     'グループに参加しますか？',
    'joinSub':       'グループのイベントを見たり、メンバーと連絡を取ることができます。',
    'cancel':        'キャンセル',
    'join':          '参加',
    'successTitle':  'グループに\n参加しました！',
    'successSub':    'グループのメンバーと\n連絡を取りますか？',
    'no':            'いいえ',
    'yes':           'はい',
    'errJoin':       'グループへの参加に失敗しました。もう一度お試しください。',
    'signInNeeded':  'グループに参加するにはサインインしてください',
    'alreadyJoined': 'すでにこのグループに参加しています',
  },
};

String _t(String lang, String key) =>
    _L[lang]?[key] ?? _L[kLangEn]![key]!;

// ─────────────────────────────────────────────────────────────────────────────
// JoinGroupModal — public API identical to original
// ─────────────────────────────────────────────────────────────────────────────
class JoinGroupModal {

  // ── Resolve group ID ──────────────────────────────────────────────────────
  static String _resolveGroupId(Map<String, dynamic> group) {
    final docId = group['_doc_id']?.toString() ?? '';
    if (docId.isNotEmpty) return docId;

    final orgId = group['org_id']?.toString() ?? '';
    if (orgId.isNotEmpty) return orgId;

    final altId = group['org_org_id']?.toString() ??
        group['id']?.toString() ??
        '';
    if (altId.isNotEmpty) return altId;

    final orgName = group['org_name']?.toString() ?? 'unknown';
    return orgName
        .toLowerCase()
        .replaceAll(' ', '_')
        .replaceAll(RegExp(r'[^a-z0-9_]'), '');
  }

  // ── Entry point ───────────────────────────────────────────────────────────
  static Future<void> show(
      BuildContext context,
      Map<String, dynamic> group, {
        String lang = kLangEn,
      }) async {
    final resolvedLang  = await loadSavedLang();
    final effectiveLang = lang != kLangEn ? lang : resolvedLang;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (context.mounted) {
        _showToast(context, _t(effectiveLang, 'signInNeeded'), isError: true);
      }
      return;
    }

    final groupId = _resolveGroupId(group);
    final docId   = '${user.uid}_$groupId';

    // ── Already joined? ───────────────────────────────────────────────────
    final existingDoc = await FirebaseFirestore.instance
        .collection('user_groups')
        .doc(docId)
        .get();

    if (!context.mounted) return;

    if (existingDoc.exists && existingDoc.data()?['status'] == 'active') {
      _showToast(context, _t(effectiveLang, 'alreadyJoined'), isError: false);
      return;
    }

    // ── Step 1: confirm dialog ────────────────────────────────────────────
    final shouldJoin = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (_) => _JoinConfirmDialog(lang: effectiveLang),
    );

    if (shouldJoin != true || !context.mounted) return;

    // ── Step 2: write to Firestore + show spinner ─────────────────────────
    // Use a ValueNotifier so the spinner dialog can be dismissed from outside
    bool spinnerShowing = false;

    void showSpinner() {
      spinnerShowing = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black.withOpacity(0.45),
        builder: (_) => const Center(
          child: CircularProgressIndicator(
            color: Color(0xFF3A7D44),
            strokeWidth: 3,
          ),
        ),
      );
    }

    void dismissSpinner() {
      if (spinnerShowing && context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        spinnerShowing = false;
      }
    }

    showSpinner();

    bool writeOk = false;
    try {
      // ── FIRESTORE WRITE — same fields as web app handleJoin ──────────
      await FirebaseFirestore.instance
          .collection('user_groups')
          .doc(docId)
          .set({
        'user_id':               user.uid,
        'group_id':              groupId,
        'group_name':            group['org_name'] ?? 'Unnamed Group',
        'group_image':           group['org_image'] ?? '',
        'joined_at':             FieldValue.serverTimestamp(),
        'status':                'active',
        'notifications_enabled': true,
      }, SetOptions(merge: true));

      writeOk = true;
    } catch (e) {
      debugPrint('❌ JoinGroupModal._writeJoin error: $e');
    }

    dismissSpinner();
    if (!context.mounted) return;

    if (!writeOk) {
      _showToast(context, _t(effectiveLang, 'errJoin'), isError: true);
      return;
    }

    // ── Step 3: success dialog ────────────────────────────────────────────
    await showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (ctx) => _SuccessDialog(
        lang: effectiveLang,
        onGoToChat: () {
          Navigator.of(ctx).pop();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => GroupChatScreen(group: group),
            ),
          );
        },
      ),
    );
  }

  // ── Public helper ─────────────────────────────────────────────────────────
  static Future<bool> isAlreadyJoined(
      String userId, Map<String, dynamic> group) async {
    final groupId = _resolveGroupId(group);
    final docId   = '${userId}_$groupId';
    final doc     = await FirebaseFirestore.instance
        .collection('user_groups')
        .doc(docId)
        .get();
    return doc.exists && doc.data()?['status'] == 'active';
  }

  // ── Toast (slide-in from top) ─────────────────────────────────────────────
  static void _showToast(
      BuildContext context, String message, {required bool isError}) {
    if (!context.mounted) return;
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _Toast(message: message, isError: isError),
    );
    overlay.insert(entry);
    Future.delayed(const Duration(milliseconds: 3200), () {
      if (entry.mounted) entry.remove();
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Join Confirm Dialog — white card, light green icon, grey subtitle
// Matches the screenshot exactly
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
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 40,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Light green icon circle ──────────────────────────────────
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: _C.iconBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.group_add_rounded,
                color: _C.iconColor,
                size: 32,
              ),
            ),
            const SizedBox(height: 24),

            // ── Title ────────────────────────────────────────────────────
            Text(
              _t(lang, 'joinTitle'),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: _C.titleColor,
                letterSpacing: -0.3,
                height: 1.2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // ── Subtitle ─────────────────────────────────────────────────
            Text(
              _t(lang, 'joinSub'),
              style: const TextStyle(
                fontSize: 15,
                color: _C.subtitleColor,
                height: 1.55,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // ── Buttons ──────────────────────────────────────────────────
            Row(children: [
              // Cancel — light grey pill
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context, false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: _C.cancelBg,
                      borderRadius: BorderRadius.circular(50),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _t(lang, 'cancel'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _C.cancelText,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Join — solid dark green pill
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context, true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: _C.joinBg,
                      borderRadius: BorderRadius.circular(50),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _t(lang, 'join'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _C.joinText,
                      ),
                    ),
                  ),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Success Dialog — same white card style
// ─────────────────────────────────────────────────────────────────────────────
class _SuccessDialog extends StatelessWidget {
  final String lang;
  final VoidCallback onGoToChat;
  const _SuccessDialog({required this.lang, required this.onGoToChat});

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
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 40,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Animated checkmark ───────────────────────────────────────
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 500),
              curve: Curves.elasticOut,
              builder: (_, v, child) =>
                  Transform.scale(scale: v, child: child),
              child: Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: _C.iconBg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: _C.successGreen,
                  size: 38,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Title ────────────────────────────────────────────────────
            Text(
              _t(lang, 'successTitle'),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: _C.titleColor,
                letterSpacing: -0.3,
                height: 1.25,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // ── Subtitle ─────────────────────────────────────────────────
            Text(
              _t(lang, 'successSub'),
              style: const TextStyle(
                fontSize: 15,
                color: _C.subtitleColor,
                height: 1.55,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // ── No | Yes row with divider ─────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: _C.cancelBg,
                borderRadius: BorderRadius.circular(50),
              ),
              child: Row(children: [
                // No
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      alignment: Alignment.center,
                      child: Text(
                        _t(lang, 'no'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: _C.cancelText,
                        ),
                      ),
                    ),
                  ),
                ),
                // Divider
                Container(width: 1, height: 28, color: _C.divider),
                // Yes
                Expanded(
                  child: GestureDetector(
                    onTap: onGoToChat,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: _C.joinBg,
                        borderRadius: BorderRadius.circular(50),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _t(lang, 'yes'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: _C.joinText,
                        ),
                      ),
                    ),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Toast overlay — slide in from top, dark green / dark red
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
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide   = Tween<Offset>(
        begin: const Offset(0, -0.6), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) _ctrl.reverse();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg      = widget.isError ? _C.toastError   : _C.toastSuccess;
    final accent  = widget.isError ? _C.toastErrAcc  : _C.toastAccent;
    final icon    = widget.isError ? Icons.error_rounded : Icons.check_circle_rounded;

    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 20,
      right: 20,
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
                  BoxShadow(
                    color: Colors.black.withOpacity(0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(children: [
                Icon(icon, color: accent, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.message,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}