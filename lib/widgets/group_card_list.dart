import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pikuru/theme/material.dart';
import 'package:pikuru/providers/providers.dart';
import 'package:pikuru/providers/app_language_provider.dart';
import 'package:pikuru/screens/group_detail_screen.dart';
import 'package:pikuru/screens/group_chat_screen.dart';
import 'package:pikuru/modal/group_detail_modal.dart';

// ── Localised strings ─────────────────────────────────────────────────────────
const _L = {
  kLangEn: {
    'joinTitle':    'Join the Group?',
    'joinSub':      'You will be able to see group events and communicate with members.',
    'cancel':       'Cancel',
    'join':         'Join',
    'successTitle': 'Joined the Group\nSuccessfully!',
    'successSub':   'Want to communicate with the members\nof the group?',
    'no':           'No',
    'yes':          'Yes',
    'errJoin':      'Failed to join group. Please try again.',
    'joined':       'Joined ✓',
    'joinBtn':      'JOIN',
    'interested':   'Interested',
    'organizer':    'Organizer',
  },
  kLangJa: {
    'joinTitle':    'グループに参加しますか？',
    'joinSub':      'グループのイベントを見たり、メンバーと連絡を取ることができます。',
    'cancel':       'キャンセル',
    'join':         '参加',
    'successTitle': 'グループに\n参加しました！',
    'successSub':   'グループのメンバーと\n連絡を取りますか？',
    'no':           'いいえ',
    'yes':          'はい',
    'errJoin':      'グループへの参加に失敗しました。',
    'joined':       '参加済み ✓',
    'joinBtn':      '参加',
    'interested':   '興味あり',
    'organizer':    'オーガナイザー',
  },
};

String _t(String lang, String key) =>
    _L[lang]?[key] ?? _L[kLangEn]![key]!;

// ── GroupCardList ─────────────────────────────────────────────────────────────
class GroupCardList extends ConsumerStatefulWidget {
  final Map<String, dynamic> group;
  const GroupCardList({super.key, required this.group});

  @override
  ConsumerState<GroupCardList> createState() => _GroupCardListState();
}

class _GroupCardListState extends ConsumerState<GroupCardList> {
  // 'none' | 'interested' | 'active'
  String  _membershipStatus = 'none';
  bool    _checkingStatus   = true;

  @override
  void initState() {
    super.initState();
    _checkMembership();
  }

  // ── Resolve group ID — same priority as GroupDetailModals ─────────────────
  String get _orgId {
    final orgId = widget.group['org_id']?.toString() ?? '';
    if (orgId.isNotEmpty) return orgId;
    return (widget.group['_doc_id'] ?? '').toString();
  }

  // ── Is current user the creator/organizer of this group? ──────────────────
  // Mirrors web app: g.submittedBy === uid || g.org_addedby === uid
  bool get _isCreator {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return false;
    final uid = me.uid;
    final submittedBy = (widget.group['submittedBy'] ?? '').toString();
    final orgAddedBy  = (widget.group['org_addedby'] ?? '').toString();
    return (submittedBy.isNotEmpty && submittedBy == uid) ||
        (orgAddedBy.isNotEmpty && orgAddedBy  == uid);
  }

  // ── Read status from Firestore ────────────────────────────────────────────
  Future<void> _checkMembership() async {
    if (!mounted) return;
    setState(() => _checkingStatus = true);

    final me = FirebaseAuth.instance.currentUser;
    if (me == null || _orgId.isEmpty) {
      if (mounted) setState(() { _membershipStatus = 'none'; _checkingStatus = false; });
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('user_groups')
          .doc('${me.uid}_$_orgId')
          .get();
      if (mounted) {
        setState(() {
          _membershipStatus = doc.exists
              ? (doc.data()?['status']?.toString() ?? 'none')
              : 'none';
          _checkingStatus = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() { _membershipStatus = 'none'; _checkingStatus = false; });
    }
  }

  // ── Navigate to detail screen, then re-check status on return ────────────
  Future<void> _openDetail() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GroupDetailScreen(group: widget.group)),
    );
    _checkMembership();
  }

  // ── Show Join confirm modal then Success modal ────────────────────────────
  Future<void> _showJoinModal(String lang) async {
    HapticFeedback.lightImpact();
    final joined = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _JoinModal(group: widget.group, lang: lang,
          onJoined: () => setState(() => _membershipStatus = 'active')),
    );
    if (joined == true && mounted) {
      setState(() => _membershipStatus = 'active');
      _showSuccessModal(lang);
    }
  }

  Future<void> _showSuccessModal(String lang) async {
    final goToChat = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SuccessModal(group: widget.group, lang: lang),
    );
    if (goToChat == true && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => GroupChatScreen(group: widget.group)),
      );
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  bool _isTruthy(dynamic v) {
    if (v == null) return false;
    if (v is bool) return v;
    if (v is num)  return v != 0;
    final s = v.toString().toLowerCase().trim();
    return s == 'true' || s == '1' || s == 't' || s == 'yes';
  }

  bool   get _isJa => (widget.group['_lang'] ?? 'en').toString() == 'ja';
  String _tr(String en, String ja) => _isJa ? ja : en;

  String _getSkillLevels(Map<String, dynamic> g) {
    final existing = (g['org_skill_level'] ?? '').toString().trim();
    if (existing.isNotEmpty && existing != 'null') {
      return _isJa
          ? existing
          .replaceAll('Beginner',     '初級')
          .replaceAll('Intermediate', '中級')
          .replaceAll('Advanced',     '上級')
          : existing;
    }
    final levels = <String>[];
    if (_isTruthy(g['org_skill_beginner']))     levels.add(_tr('Beginner',     '初級'));
    if (_isTruthy(g['org_skill_intermediate'])) levels.add(_tr('Intermediate', '中級'));
    if (_isTruthy(g['org_skill_advance']))      levels.add(_tr('Advanced',     '上級'));
    if (levels.isNotEmpty) return levels.join(' | ');
    final type = (g['org_type'] ?? '').toString();
    return type == 'Professional'
        ? _tr('Pro | Amateur', 'プロ | アマチュア')
        : _tr('All levels', '全レベル');
  }

  String _getSchedule(Map<String, dynamic> g) {
    final existing =
    (g['org_schedule'] ?? g['org_meetup_time'] ?? '').toString().trim();
    if (existing.isNotEmpty && existing != 'null') {
      return _isJa
          ? existing
          .replaceAll('Sun', '日').replaceAll('Mon', '月')
          .replaceAll('Tue', '火').replaceAll('Wed', '水')
          .replaceAll('Thu', '木').replaceAll('Fri', '金')
          .replaceAll('Sat', '土')
          .replaceAll('Mornings',   '午前')
          .replaceAll('Afternoons', '午後')
          .replaceAll('Evenings',   '夜間')
          : existing;
    }
    final dayMap = _isJa
        ? {'org_meetup_sun':'日','org_meetup_mon':'月','org_meetup_tues':'火',
      'org_meetup_weds':'水','org_meetup_thurs':'木','org_meetup_fri':'金','org_meetup_sat':'土'}
        : {'org_meetup_sun':'Sun','org_meetup_mon':'Mon','org_meetup_tues':'Tue',
      'org_meetup_weds':'Wed','org_meetup_thurs':'Thu','org_meetup_fri':'Fri','org_meetup_sat':'Sat'};
    final days  = dayMap.entries.where((e) => _isTruthy(g[e.key])).map((e) => e.value).toList();
    final times = <String>[
      if (_isTruthy(g['org_meetup_time_mornings']))   _tr('Mornings',   '午前'),
      if (_isTruthy(g['org_meetup_time_afternoons'])) _tr('Afternoons', '午後'),
      if (_isTruthy(g['org_meetup_time_evenings']))   _tr('Evenings',   '夜間'),
    ];
    if (days.isNotEmpty && times.isNotEmpty)
      return '${days.join(' | ')}  ·  ${times.join(' | ')}';
    if (days.isNotEmpty)  return days.join(' | ');
    if (times.isNotEmpty) return times.join(' | ');
    return _tr('Flexible schedule', '柔軟なスケジュール');
  }

  String _getAgeGroups(Map<String, dynamic> g) {
    final existing = (g['org_age_groups'] ?? '').toString().trim();
    if (existing.isNotEmpty && existing != 'null') {
      return _isJa
          ? existing
          .replaceAll('Juniors',  'ジュニア').replaceAll('Students', '学生')
          .replaceAll('Adults',   '大人').replaceAll('Seniors',  'シニア')
          : existing;
    }
    final ages = <String>[];
    if (_isTruthy(g['org_age_juniors']))  ages.add(_tr('Juniors',  'ジュニア'));
    if (_isTruthy(g['org_age_students'])) ages.add(_tr('Students', '学生'));
    if (_isTruthy(g['org_age_adult']))    ages.add(_tr('Adults',   '大人'));
    if (_isTruthy(g['org_age_seniors']))  ages.add(_tr('Seniors',  'シニア'));
    return ages.isEmpty ? _tr('All ages', '全年齢') : ages.join(' | ');
  }

  // ── Small pill widgets ────────────────────────────────────────────────────
  Widget _interestedBadge(String lang) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.primary, width: 1.5),
    ),
    child: Text(
      _t(lang, 'interested'),
      style: TextStyle(
        color: AppColors.primary,
        fontSize: 11,
        fontWeight: FontWeight.bold,
      ),
    ),
  );

  Widget _organizerBadge(String lang) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: AppColors.primary.withOpacity(0.10),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.primary.withOpacity(0.35), width: 1),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star_rounded, size: 14, color: AppColors.primary),
        const SizedBox(width: 4),
        Text(
          _t(lang, 'organizer'),
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );

  Widget _joinButton(String lang) => GestureDetector(
    onTap: () {
      HapticFeedback.lightImpact();
      _showJoinModal(lang);
    },
    behavior: HitTestBehavior.opaque,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _t(lang, 'joinBtn'),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    ),
  );

  Widget _joinedPill(String lang) => GestureDetector(
    onTap: null,
    behavior: HitTestBehavior.opaque,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _t(lang, 'joined'),
        style: TextStyle(
          color: Colors.grey.shade600,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appLangProvider);

    final resolvedName     = (widget.group['_resolved_name']     ?? '').toString();
    final resolvedLocation = (widget.group['_resolved_location'] ?? '').toString();
    final displayName      = resolvedName.isNotEmpty
        ? resolvedName
        : (widget.group['org_name'] ?? 'Unnamed Group').toString();
    final imageUrl         =
    (widget.group['org_image'] ?? widget.group['org_pic'] ?? '').toString();

    final bool hasResolvedLocation = resolvedLocation.isNotEmpty;
    final orgLocId      = (widget.group['org_loc_id'] ?? '').toString();
    final locationAsync = hasResolvedLocation
        ? null
        : ref.watch(locationResolverProvider(orgLocId));

    Widget locationWidget;
    if (hasResolvedLocation) {
      locationWidget = _infoRow(Icons.location_on, resolvedLocation);
    } else {
      locationWidget = locationAsync!.when(
        data: (location) {
          final label = location.isNotEmpty
              ? location
              : (widget.group['org_country'] ?? '').toString();
          return label.isNotEmpty
              ? _infoRow(Icons.location_on, label)
              : const SizedBox.shrink();
        },
        loading: () => _infoRow(Icons.location_on, '...'),
        error: (_, __) {
          final country = (widget.group['org_country'] ?? '').toString();
          return country.isNotEmpty
              ? _infoRow(Icons.location_on, country)
              : const SizedBox.shrink();
        },
      );
    }

    final isActive     = _membershipStatus == 'active';
    final isInterested = _membershipStatus == 'interested';
    final isCreator    = _isCreator;

    // Build the trailing action widget for the bottom-right of the card.
    Widget actionWidget;
    if (_checkingStatus) {
      actionWidget = SizedBox(
        width: 16, height: 16,
        child: CircularProgressIndicator(
            color: AppColors.primary, strokeWidth: 2),
      );
    } else if (isCreator) {
      // Creator/organizer — show Organizer label, no join button.
      // If also "interested", show the Interested badge alongside.
      actionWidget = isInterested
          ? Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _interestedBadge(lang),
          const SizedBox(width: 6),
          _organizerBadge(lang),
        ],
      )
          : _organizerBadge(lang);
    } else if (isActive) {
      actionWidget = _joinedPill(lang);
    } else if (isInterested) {
      // Show "Interested" badge AND still keep the JOIN button.
      actionWidget = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _interestedBadge(lang),
          const SizedBox(width: 6),
          _joinButton(lang),
        ],
      );
    } else {
      actionWidget = _joinButton(lang);
    }

    return GestureDetector(
      onTap: _openDetail,
      child: Container(
        margin:     const EdgeInsets.only(bottom: 16),
        padding:    const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.circular(16),
          border:       Border.all(color: Colors.grey.shade200, width: 1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: imageUrl.isNotEmpty
                  ? Image.network(imageUrl, width: 90, height: 90,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _placeholder())
                  : _placeholder(),
            ),

            const SizedBox(width: 16),

            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(displayName,
                            style: const TextStyle(fontSize: 17,
                                fontWeight: FontWeight.bold, color: Colors.black),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      const Icon(Icons.arrow_forward_ios,
                          color: Colors.black54, size: 20),
                    ],
                  ),
                  const SizedBox(height: 6),

                  locationWidget,
                  const SizedBox(height: 4),
                  _infoRow(Icons.sports_tennis_rounded,
                      _getSkillLevels(widget.group)),
                  const SizedBox(height: 4),
                  _infoRow(Icons.calendar_today_rounded,
                      _getSchedule(widget.group)),
                  const SizedBox(height: 4),

                  // Age groups (full width) — action moves below so long
                  // text isn't truncated by the badge/button.
                  _infoRow(Icons.people_alt_rounded,
                      _getAgeGroups(widget.group)),
                  const SizedBox(height: 8),
                  // Action row (JOIN / Interested+JOIN / Joined / Organizer)
                  Align(
                    alignment: Alignment.centerRight,
                    child: actionWidget,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 14, color: Colors.black54),
      const SizedBox(width: 4),
      Expanded(
        child: Text(text,
            style: const TextStyle(fontSize: 13, color: Colors.black87),
            maxLines: 2,
            overflow: TextOverflow.ellipsis),
      ),
    ],
  );

  Widget _placeholder() => Container(
    width: 90, height: 90,
    decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12)),
    child: Icon(Icons.group,
        size: 40, color: AppColors.primary.withOpacity(0.4)),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// _JoinModal
// ═════════════════════════════════════════════════════════════════════════════
class _JoinModal extends ConsumerStatefulWidget {
  final Map<String, dynamic> group;
  final String lang;
  final VoidCallback onJoined;
  const _JoinModal(
      {required this.group, required this.lang, required this.onJoined});

  @override
  ConsumerState<_JoinModal> createState() => _JoinModalState();
}

class _JoinModalState extends ConsumerState<_JoinModal> {
  bool    _loading = false;
  String? _error;

  String get _orgId {
    final orgId = widget.group['org_id']?.toString() ?? '';
    if (orgId.isNotEmpty) return orgId;
    return (widget.group['_doc_id'] ?? '').toString();
  }

  Future<void> _handleJoin() async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) return;
    setState(() { _loading = true; _error = null; });
    try {
      final orgId = _orgId;
      await FirebaseFirestore.instance
          .collection('user_groups')
          .doc('${me.uid}_$orgId')
          .set({
        'user_id':               me.uid,
        'group_id':              orgId,
        'group_name':            (widget.group['org_name']  ?? '').toString(),
        'group_image':           (widget.group['org_image'] ?? '').toString(),
        'joined_at':             FieldValue.serverTimestamp(),
        'status':                'active',
        'notifications_enabled': true,
      }, SetOptions(merge: true));
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _loading = false;
        _error   = _t(widget.lang, 'errJoin');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.lang;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle),
            child: Icon(Icons.group_add_rounded,
                color: AppColors.primary, size: 28),
          ),
          const SizedBox(height: 16),
          Text(_t(lang, 'joinTitle'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
                  color: Color(0xFF0D0D0D), letterSpacing: -0.3),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(_t(lang, 'joinSub'),
              style: TextStyle(fontSize: 13.5,
                  color: Colors.black.withOpacity(0.5), height: 1.5),
              textAlign: TextAlign.center),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color:  Colors.red.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.withOpacity(0.25)),
              ),
              child: Text(_error!,
                  style: const TextStyle(fontSize: 12.5, color: Colors.red),
                  textAlign: TextAlign.center),
            ),
          ],
          const SizedBox(height: 24),
          Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: _loading ? null : () => Navigator.of(context).pop(false),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                      color: const Color(0xFFF2F3F5),
                      borderRadius: BorderRadius.circular(12)),
                  alignment: Alignment.center,
                  child: Text(_t(lang, 'cancel'),
                      style: const TextStyle(fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF555760))),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: _loading ? null : _handleJoin,
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(color: AppColors.primary.withOpacity(0.35),
                          blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: _loading
                      ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5))
                      : Text(_t(lang, 'join'),
                      style: const TextStyle(fontSize: 14,
                          fontWeight: FontWeight.w800, color: Colors.white)),
                ),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// _SuccessModal
// ═════════════════════════════════════════════════════════════════════════════
class _SuccessModal extends StatelessWidget {
  final Map<String, dynamic> group;
  final String lang;
  const _SuccessModal({required this.group, required this.lang});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Stack(alignment: Alignment.center, children: [
            Container(width: 72, height: 72,
                decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    shape: BoxShape.circle)),
            Container(width: 56, height: 56,
                decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.15),
                    shape: BoxShape.circle)),
            Container(width: 42, height: 42,
                decoration: const BoxDecoration(
                    color: AppColors.primary, shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded,
                    color: Colors.white, size: 24)),
          ]),
          const SizedBox(height: 18),
          Text(_t(lang, 'successTitle'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                  color: Color(0xFF0D0D0D), height: 1.25, letterSpacing: -0.4),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(_t(lang, 'successSub'),
              style: TextStyle(fontSize: 13.5,
                  color: Colors.black.withOpacity(0.5), height: 1.5),
              textAlign: TextAlign.center),
          const SizedBox(height: 26),
          Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(false),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                      color: const Color(0xFFF2F3F5),
                      borderRadius: BorderRadius.circular(12)),
                  alignment: Alignment.center,
                  child: Text(_t(lang, 'no'),
                      style: const TextStyle(fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF555760))),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(true),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(color: AppColors.primary.withOpacity(0.35),
                          blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.chat_bubble_rounded,
                          color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                      Text(_t(lang, 'yes'),
                          style: const TextStyle(fontSize: 14,
                              fontWeight: FontWeight.w800, color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}
