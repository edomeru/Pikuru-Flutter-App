import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pikuru/theme/material.dart';
import 'package:pikuru/providers/app_language_provider.dart';
import 'package:pikuru/screens/add_event_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Design tokens — light
// ─────────────────────────────────────────────────────────────────────────────
class _D {
  static const pageBg    = Color(0xFFF7F8FA);
  static const white     = Colors.white;
  static const accent    = Color(0xFF2D7D46);
  static const accentLt  = Color(0xFFEDF7EF);
  static const accentBdr = Color(0xFFB7DFC2);
  static const textPri   = Color(0xFF0D0D0D);
  static const textSec   = Color(0xFF374151);
  static const textMuted = Color(0xFF6B7280);
  static const textDim   = Color(0xFF9CA3AF);
  static const border    = Color(0xFFE5E7EB);
  static const rowBg     = Color(0xFFF9FAFB);
  static const inputBg   = Color(0xFFF3F4F6);
  static const apprvClr  = Color(0xFF2D7D46);
  static const apprvBg   = Color(0xFFEDF7EF);
  static const pendClr   = Color(0xFFF57C00);
  static const pendBg    = Color(0xFFFFF3E0);
  static const rejClr    = Color(0xFFD32F2F);
  static const rejBg     = Color(0xFFFFEBEE);
  static const infoBg    = Color(0xFFF0F7F2);
  static const infoBdr   = Color(0xFFD1EAD8);
  static const infoLabel = Color(0xFF2D7D46);
  static const modalBg      = Color(0xFFF7F8FA);
  static const modalBorder  = Color(0xFFE5E7EB);
  static const modalGreen   = Color(0xFF2D7D46);
  static const modalGreenLt = Color(0xFFEDF7EF);
  static const modalGreenBdr = Color(0xFFB7DFC2);
  static const modalText    = Color(0xFF0D0D0D);
  static const modalMuted   = Color(0xFF6B7280);
  static const modalDivider = Color(0xFFE5E7EB);
  static const modalRed     = Color(0xFFD32F2F);
  static const modalRedBg   = Color(0xFFFFEBEE);
  static const modalRedBdr  = Color(0xFFFFCDD2);
  static const modalRedText = Color(0xFFD32F2F);
}

// ─────────────────────────────────────────────────────────────────────────────
// i18n
// ─────────────────────────────────────────────────────────────────────────────
const _L = {
  kLangEn: {
    'title':           'Group Settings',
    'sub':             'Edit your group details',
    'coverImage':      'Cover Image',
    'groupNameEn':     'Group Name (EN)',
    'groupNameJp':     'Group Name (JP)',
    'descEn':          'Description (EN)',
    'descJp':          'Description (JP)',
    'groupMembers':    'Group Members',
    'manageAll':       'Manage All Members',
    'eventsByGroup':   'Events by this Group',
    'noEvents':        'No events found for this group.',
    'saveChanges':     'Save Changes',
    'cancel':          'Cancel',
    'saving':          'Saving…',
    'saved':           'Changes saved!',
    'saveError':       'Failed to save. Please try again.',
    'creator':         'CREATOR',
    'active':          'Active',
    'inactive':        'Inactive',
    'public':          'Public',
    'private':         'Private',
    'deactivate':      'Deactivate',
    'activate':        'Activate',
    'makePrivate':     'Make Private',
    'makePublic':      'Make Public',
    'approved':        'Approved',
    'pending':         'Pending',
    'rejected':        'Rejected',
    'addEvent':        '+ Add an event for this group',
    'namePh':          'Enter group name…',
    'descPh':          'Enter description…',
    'addedBy':         'ADDED BY',
    'createdStatus':   'CREATED & STATUS',
    'noMembers':       'No members yet.',
    'membersTitle':    'Group Members',
    'people':          'people',
    'all':             'All',
    'groupCreator':    'Group Creator',
    'you':             'You',
    'remove':          'Remove',
    'removing':        'Removing…',
    'removeConfirm':   'Remove member?',
    'removeBody':      'Remove {name} from this group? They will lose access as a member.',
    'removeConfirmCta':'Remove from group',
    'removeFailed':    'Failed to remove member. Please try again.',
    'close':           'Close',
    'back':            'Back',
    'viewAllEvents':   'View all {count} events for this group',
    'eventsModalTitle':'Events by this Group',
    'eventsCount':     '{count} events',
    'upcomingTitle':       'Upcoming Events from this Group',
    'pastTitle':           'Past Events from this Group',
    'noUpcoming':          'No upcoming events for this group.',
    'noPast':              'No past events for this group.',
    'viewAllUpcoming':     'View all {count} upcoming events',
    'viewAllPast':         'View all {count} past events',
    'upcomingModalTitle':  'Upcoming Events from this Group',
    'pastModalTitle':      'Past Events from this Group',
  },
  kLangJa: {
    'title':           'グループ設定',
    'sub':             'グループ情報を編集',
    'coverImage':      'カバー画像',
    'groupNameEn':     'グループ名（英語）',
    'groupNameJp':     'グループ名（日本語）',
    'descEn':          '説明（英語）',
    'descJp':          '説明（日本語）',
    'groupMembers':    'グループメンバー',
    'manageAll':       'メンバーを管理',
    'eventsByGroup':   'このグループのイベント',
    'noEvents':        'このグループのイベントはまだありません。',
    'saveChanges':     '変更を保存',
    'cancel':          'キャンセル',
    'saving':          '保存中…',
    'saved':           '変更を保存しました！',
    'saveError':       '保存に失敗しました。もう一度お試しください。',
    'creator':         '作成者',
    'active':          'アクティブ',
    'inactive':        '非アクティブ',
    'public':          '公開',
    'private':         '非公開',
    'deactivate':      '非アクティブにする',
    'activate':        'アクティブにする',
    'makePrivate':     '非公開にする',
    'makePublic':      '公開する',
    'approved':        '承認済み',
    'pending':         '審査中',
    'rejected':        '却下',
    'addEvent':        '+ このグループにイベントを追加',
    'namePh':          'グループ名を入力…',
    'descPh':          '説明を入力…',
    'addedBy':         '追加者',
    'createdStatus':   '作成日・ステータス',
    'noMembers':       'まだメンバーがいません。',
    'membersTitle':    'メンバー',
    'people':          '人',
    'all':             'すべて',
    'groupCreator':    'グループ作成者',
    'you':             'あなた',
    'remove':          '削除',
    'removing':        '削除中…',
    'removeConfirm':   'メンバーを削除しますか？',
    'removeBody':      '{name} をこのグループから削除しますか？メンバーとしてのアクセスがなくなります。',
    'removeConfirmCta':'グループから削除',
    'removeFailed':    'メンバーの削除に失敗しました。もう一度お試しください。',
    'close':           '閉じる',
    'back':            '戻る',
    'viewAllEvents':   'このグループの全{count}イベントを見る',
    'eventsModalTitle':'このグループのイベント',
    'eventsCount':     '{count}件のイベント',
    'upcomingTitle':       'このグループの今後のイベント',
    'pastTitle':           'このグループの過去のイベント',
    'noUpcoming':          '今後のイベントはありません。',
    'noPast':              '過去のイベントはありません。',
    'viewAllUpcoming':     '今後の{count}件のイベントをすべて見る',
    'viewAllPast':         '過去の{count}件のイベントをすべて見る',
    'upcomingModalTitle':  'このグループの今後のイベント',
    'pastModalTitle':      'このグループの過去のイベント',
  },
};

String _t(String lang, String key) =>
    _L[lang]?[key] ?? _L[kLangEn]![key]!;

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────
String _fmtDate(dynamic ts, String lang) {
  if (ts == null || ts is! Timestamp) return '—';
  final d = ts.toDate();
  if (lang == kLangJa) {
    return '${d.year}年${d.month}月${d.day}日 ${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
  }
  const mo = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  return '${mo[d.month-1]} ${d.day}, ${d.year}  ${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
}

String _fmtDateShort(dynamic ts, {String lang = kLangEn}) {
  if (ts == null || ts is! Timestamp) return '—';
  final d = ts.toDate();
  if (lang == kLangJa) {
    return '${d.year}/${d.month.toString().padLeft(2,'0')}/${d.day.toString().padLeft(2,'0')}';
  }
  return '${d.month}/${d.day}/${d.year}';
}

// Mirrors web logic: prefer event_date_end, fall back to event_date.
// Events without any date count as upcoming.
bool _isPastEvent(Map<String, dynamic> ev) {
  final end = ev['event_date_end'];
  final start = ev['event_date'];
  final ts = end is Timestamp ? end : (start is Timestamp ? start : null);
  if (ts == null) return false;
  return ts.millisecondsSinceEpoch < DateTime.now().millisecondsSinceEpoch;
}


List<Map<String, dynamic>> _upcomingOf(List<Map<String, dynamic>> all) =>
    all.where((e) => !_isPastEvent(e)).toList();

List<Map<String, dynamic>> _pastOf(List<Map<String, dynamic>> all) =>
    all.where(_isPastEvent).toList();


// ─────────────────────────────────────────────────────────────────────────────
// Avatar helpers
// ─────────────────────────────────────────────────────────────────────────────
String _toImgSrc(String? raw) {
  if (raw == null || raw.trim().isEmpty) return '';
  if (raw.startsWith('data:')) return raw;
  if (raw.startsWith('http'))  return raw;
  return 'data:image/jpeg;base64,$raw';
}

String _memberAvatarSrc(Map<String, dynamic> m) {
  for (final key in ['profile_img', 'photoURL', 'avatar', 'photo_url', 'avatarUrl']) {
    final v = (m[key] ?? '').toString().trim();
    if (v.isNotEmpty) return _toImgSrc(v);
  }
  return '';
}

ImageProvider? _buildImageProvider(String src) {
  if (src.isEmpty) return null;
  try {
    if (src.startsWith('http://') || src.startsWith('https://')) {
      return NetworkImage(src);
    }
    if (src.startsWith('data:')) {
      final comma = src.indexOf(',');
      if (comma != -1) {
        final bytes = base64Decode(src.substring(comma + 1));
        return MemoryImage(bytes);
      }
    }
  } catch (_) {}
  return null;
}

String _memberDisplayName(Map<String, dynamic> m) {
  final precomputed = (m['name'] ?? '').toString().trim();
  if (precomputed.isNotEmpty && precomputed != (m['uid'] ?? '')) return precomputed;
  final nick  = (m['nickname']  ?? '').toString().trim();
  final first = (m['firstName'] ?? '').toString().trim();
  final last  = (m['lastName']  ?? '').toString().trim();
  if (nick.isNotEmpty)  return nick;
  if (first.isNotEmpty && last.isNotEmpty) return '$first $last';
  if (first.isNotEmpty) return first;
  final uid = (m['uid'] ?? '').toString();
  return uid.isNotEmpty ? uid : 'Unknown';
}

// ─────────────────────────────────────────────────────────────────────────────
// Event query helper — only shows events submitted by the current user,
// further filtered to this group via the multi-strategy approach:
//   Primary:     submittedBy == currentUserUid AND event_org_id == groupDocId/orgId
//   Fallback:    submittedBy == currentUserUid AND org_id == effectiveOrgId
//   Last resort: submittedBy == currentUserUid AND event_org_name == orgName
//
// After fetching by submittedBy+org, we deduplicate by doc ID so the same
// event never appears twice even if it matches multiple strategies.
// ─────────────────────────────────────────────────────────────────────────────
Future<List<Map<String, dynamic>>> _fetchEventsForGroup({
  required String groupDocId,    // Firestore document ID of the organization
  required String orgId,         // org_id field value (may differ from doc ID)
  required String orgName,       // org_name fallback
  required String currentUserUid, // only show events this user submitted
}) async {
  final db = FirebaseFirestore.instance;

  // Collect matching docs; deduplicate by Firestore doc ID
  final Map<String, Map<String, dynamic>> seen = {};

  Future<void> runQuery(Query q) async {
    try {
      final snap = await q.get();
      for (final d in snap.docs) {
        seen[d.id] ??= <String, dynamic>{'_id': d.id, ...d.data() as Map<String, dynamic>};
      }
    } catch (_) {}
  }

  // Base query always scoped to current user's submissions
  final base = db.collection('events').where('submittedBy', isEqualTo: currentUserUid);

  // 1. Primary: event_org_id == groupDocId (admin-set, most reliable)
  await runQuery(base.where('event_org_id', isEqualTo: groupDocId));

  // 2. If org_id field value differs from doc ID, also match on that
  if (orgId.isNotEmpty && orgId != groupDocId) {
    await runQuery(base.where('event_org_id', isEqualTo: orgId));
  }

  // 3. Fallback: org_id field on the event document (older events)
  final effectiveOrgId = orgId.isNotEmpty ? orgId : groupDocId;
  await runQuery(base.where('org_id', isEqualTo: effectiveOrgId));

  // 4. Last resort: match by org name string (only if nothing found yet)
  if (seen.isEmpty && orgName.isNotEmpty) {
    await runQuery(base.where('event_org_name', isEqualTo: orgName));
  }

  final results = seen.values.toList();

  // Sort newest event_date first (mirrors web)
  results.sort((a, b) {
    final ta = a['event_date'];
    final tb = b['event_date'];
    final tA = ta is Timestamp ? ta.millisecondsSinceEpoch : 0;
    final tB = tb is Timestamp ? tb.millisecondsSinceEpoch : 0;
    return tB.compareTo(tA);
  });

  return results;
}

// ─────────────────────────────────────────────────────────────────────────────
// ALL EVENTS MODAL — light modern design, 2-column grid
// ─────────────────────────────────────────────────────────────────────────────
void _showAllEventsModal(
    BuildContext context, String groupDocId, String orgId, String orgName,
    String lang, String currentUserUid, List<Map<String, dynamic>> preloaded,
    {String filter = 'all'}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AllEventsSheet(
      groupDocId: groupDocId, orgId: orgId, orgName: orgName,
      lang: lang, currentUserUid: currentUserUid, preloaded: preloaded,
      filter: filter,
    ),
  );
}

class _AllEventsSheet extends StatefulWidget {
  final String groupDocId, orgId, orgName, lang, currentUserUid;
  final List<Map<String, dynamic>> preloaded;
  final String filter; // 'all' | 'upcoming' | 'past'
  const _AllEventsSheet({
    required this.groupDocId, required this.orgId, required this.orgName,
    required this.lang, required this.currentUserUid, required this.preloaded,
    this.filter = 'all',
  });

  @override
  State<_AllEventsSheet> createState() => _AllEventsSheetState();
}

class _AllEventsSheetState extends State<_AllEventsSheet> {
  List<Map<String, dynamic>> _events = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _events  = List.from(widget.preloaded);
    _loading = false;
    _fetchAll();
  }

  Future<void> _fetchAll() async {
    final all = await _fetchEventsForGroup(
      groupDocId:     widget.groupDocId,
      orgId:          widget.orgId,
      orgName:        widget.orgName,
      currentUserUid: widget.currentUserUid,
    );
    if (mounted) setState(() => _events = all);
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.lang;
    final List<Map<String, dynamic>> filtered = widget.filter == 'upcoming'
        ? _upcomingOf(_events)
        : widget.filter == 'past'
        ? _pastOf(_events)
        : _events;
    final String titleKey = widget.filter == 'upcoming'
        ? 'upcomingModalTitle'
        : widget.filter == 'past'
        ? 'pastModalTitle'
        : 'eventsModalTitle';
    final String emptyKey = widget.filter == 'upcoming'
        ? 'noUpcoming'
        : widget.filter == 'past'
        ? 'noPast'
        : 'noEvents';
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      maxChildSize:     0.96,
      minChildSize:     0.50,
      builder: (ctx, scroll) => Container(
        decoration: const BoxDecoration(
          color: _D.pageBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 16, 0),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_t(lang, titleKey),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900,
                          color: _D.textPri, letterSpacing: -0.3)),
                  const SizedBox(height: 2),
                  Text(_t(lang, 'eventsCount').replaceAll('{count}', '${filtered.length}'),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _D.accent)),
                ]),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(color: _D.rowBg, borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _D.border)),
                  child: Icon(Icons.close_rounded, size: 19, color: Colors.grey.shade600),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: _D.border),
          // Grid
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: _D.accent, strokeWidth: 2.5))
                : filtered.isEmpty
                ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 60, height: 60,
                    decoration: const BoxDecoration(color: _D.accentLt, shape: BoxShape.circle),
                    child: Icon(Icons.event_rounded, size: 28, color: _D.accent.withOpacity(0.5))),
                const SizedBox(height: 12),
                Text(_t(lang, emptyKey),
                    style: const TextStyle(fontSize: 13, color: _D.textMuted, fontWeight: FontWeight.w500)),
              ]),
            )
                : GridView.builder(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.72,
              ),
              itemCount: filtered.length,
              itemBuilder: (_, i) => _EventGridCard(ev: filtered[i], lang: lang),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Event Grid Card — used in the "All Events" modal (2-column)
// ─────────────────────────────────────────────────────────────────────────────
class _EventGridCard extends StatelessWidget {
  final Map<String, dynamic> ev;
  final String lang;
  const _EventGridCard({required this.ev, required this.lang});

  @override
  Widget build(BuildContext context) {
    final title  = lang == kLangJa
        ? (ev['event_title_jp'] ?? ev['event_title'] ?? 'Untitled').toString()
        : (ev['event_title'] ?? 'Untitled').toString();
    final desc   = lang == kLangJa
        ? (ev['event_description_jp'] ?? ev['event_description_en'] ?? '').toString()
        : (ev['event_description_en'] ?? '').toString();
    final imgUrl = (ev['event_pic'] ?? ev['event_pic_thumbnail'] ?? '').toString();
    final dateStr = _fmtDateShort(ev['event_date'], lang: lang);
    final evType = (ev['event_type'] ?? '').toString();
    final isAppr = ev['event_checked'] == true && ev['event_pending_review'] != true;
    final isRej  = ev['rejected'] == true;

    Color sc; String sl;
    if (isAppr)     { sc = _D.apprvClr; sl = _t(lang, 'approved'); }
    else if (isRej) { sc = _D.rejClr;   sl = _t(lang, 'rejected'); }
    else            { sc = _D.pendClr;  sl = _t(lang, 'pending'); }

    return Container(
      decoration: BoxDecoration(
        color: _D.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Cover
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: Stack(children: [
            imgUrl.isNotEmpty
                ? Image.network(imgUrl, height: 110, width: double.infinity, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _gridPlaceholder())
                : _gridPlaceholder(),
            if (evType.isNotEmpty)
              Positioned(
                bottom: 8, right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.60),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(evType, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
          ]),
        ),
        // Body
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _D.textPri),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              if (desc.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(desc, style: const TextStyle(fontSize: 10, color: _D.textMuted, height: 1.3),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
              const Spacer(),
              Row(children: [
                Icon(Icons.calendar_today_rounded, size: 10, color: _D.accent),
                const SizedBox(width: 4),
                Expanded(child: Text(dateStr, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _D.accent), overflow: TextOverflow.ellipsis)),
              ]),
              const SizedBox(height: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(color: sc.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Text(sl, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: sc)),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _gridPlaceholder() => Container(height: 110, width: double.infinity,
      color: _D.accentLt,
      child: Icon(Icons.event_rounded, size: 30, color: _D.accent.withOpacity(0.3)));
}

// ─────────────────────────────────────────────────────────────────────────────
// GROUP MEMBERS MODAL
// ─────────────────────────────────────────────────────────────────────────────
void _showGroupMembersModal(BuildContext context, String groupId, String lang,
    String currentUserUid, String creatorUid) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _GroupMembersSheet(
      groupId: groupId, lang: lang,
      currentUserUid: currentUserUid, creatorUid: creatorUid,
    ),
  );
}

class _GroupMembersSheet extends StatefulWidget {
  final String groupId, lang, currentUserUid, creatorUid;
  const _GroupMembersSheet({required this.groupId, required this.lang,
    required this.currentUserUid, required this.creatorUid});

  @override
  State<_GroupMembersSheet> createState() => _GroupMembersSheetState();
}

class _GroupMembersSheetState extends State<_GroupMembersSheet> {
  List<Map<String, dynamic>> _members = [];
  bool   _loading   = true;
  String _filter    = 'all';
  String _listError = '';
  Map<String, dynamic>? _removeTarget;
  bool _removing = false;

  String _t(String k) => _L[widget.lang]?[k] ?? _L[kLangEn]![k]!;

  Future<void> _load() async {
    setState(() { _loading = true; _listError = ''; });
    try {
      final ugSnap = await FirebaseFirestore.instance
          .collection('user_groups')
          .where('group_id', isEqualTo: widget.groupId)
          .where('status', isEqualTo: 'active')
          .get();

      final uids = ugSnap.docs
          .map((d) => (d.data()['user_id'] ?? d.id).toString().trim())
          .where((uid) => uid.isNotEmpty).toList();

      if (widget.creatorUid.isNotEmpty && !uids.contains(widget.creatorUid)) {
        uids.add(widget.creatorUid);
      }

      final profiles = await Future.wait(uids.toSet().toList().map((uid) async {
        try {
          final snap = await FirebaseFirestore.instance.collection('registration').doc(uid).get();
          if (snap.exists && snap.data() != null) {
            return <String, dynamic>{'uid': uid, ...snap.data()!, 'isCreator': uid == widget.creatorUid};
          }
        } catch (_) {}
        return <String, dynamic>{'uid': uid, 'isCreator': uid == widget.creatorUid};
      }));

      profiles.sort((a, b) {
        if (a['isCreator'] == true) return -1;
        if (b['isCreator'] == true) return 1;
        return 0;
      });
      if (mounted) setState(() { _members = profiles; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _listError = _t('removeFailed'); _loading = false; });
    }
  }

  Future<void> _removeMember(Map<String, dynamic> target) async {
    setState(() => _removing = true);
    try {
      final uid   = target['uid'].toString();
      final docId = '${uid}_${widget.groupId}';
      await FirebaseFirestore.instance.collection('user_groups').doc(docId).set({
        'user_id':    uid,
        'group_id':   widget.groupId,
        'status':     'removed',
        'removed_at': FieldValue.serverTimestamp(),
        'removed_by': widget.currentUserUid,
      }, SetOptions(merge: true));
      setState(() {
        _members.removeWhere((m) => m['uid'] == uid);
        _removeTarget = null; _removing = false;
      });
    } catch (_) {
      setState(() { _removing = false; _listError = _t('removeFailed'); });
    }
  }

  @override
  void initState() { super.initState(); _load(); }

  List<Map<String, dynamic>> get _filtered {
    if (_filter == 'creator') return _members.where((m) => m['isCreator'] == true).toList();
    return _members;
  }

  bool get _canManage => widget.currentUserUid == widget.creatorUid;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92, maxChildSize: 0.96, minChildSize: 0.50,
      builder: (ctx, scroll) => _removeTarget != null
          ? _buildRemoveConfirm()
          : _buildMain(scroll),
    );
  }

  Widget _buildMain(ScrollController scroll) {
    return Container(
      decoration: const BoxDecoration(color: _D.modalBg, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(children: [
        Container(margin: const EdgeInsets.only(top: 12, bottom: 4), width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 16, 0),
          child: Row(children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(width: 38, height: 38,
                  decoration: BoxDecoration(color: _D.rowBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: _D.border)),
                  child: Icon(Icons.close_rounded, size: 19, color: Colors.grey.shade600)),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_t('membersTitle'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _D.modalText, letterSpacing: -0.3)),
              Text('${_members.length} ${_t('people')}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _D.modalGreen)),
            ])),
          ]),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            _LightFilterTab(label: _t('all'), selected: _filter == 'all', onTap: () => setState(() => _filter = 'all')),
            const SizedBox(width: 10),
            _LightFilterTab(label: _t('groupCreator'), selected: _filter == 'creator', onTap: () => setState(() => _filter = 'creator')),
          ]),
        ),
        const SizedBox(height: 12),
        const Divider(height: 1, color: _D.border),
        if (_listError.isNotEmpty)
          Container(margin: const EdgeInsets.fromLTRB(16, 10, 16, 0), padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: _D.modalRedBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: _D.modalRedBdr)),
              child: Text(_listError, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _D.modalRed))),
        Expanded(
          child: _loading
              ? Center(child: CircularProgressIndicator(color: _D.modalGreen, strokeWidth: 2.5))
              : _filtered.isEmpty
              ? Center(child: Text(_t('noMembers'), style: const TextStyle(fontSize: 15, color: _D.modalMuted)))
              : ListView.separated(
            controller: scroll,
            padding: const EdgeInsets.only(top: 4, bottom: 32),
            itemCount: _filtered.length,
            separatorBuilder: (_, __) => const Divider(height: 1, indent: 88, endIndent: 0, color: _D.modalDivider),
            itemBuilder: (_, i) => _LightMemberRow(
              member: _filtered[i], lang: widget.lang,
              isMe: _filtered[i]['uid'] == widget.currentUserUid,
              canManage: _canManage,
              onRemove: () => setState(() => _removeTarget = _filtered[i]),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildRemoveConfirm() {
    final name = _removeTarget != null ? _memberDisplayName(_removeTarget!) : '';
    return Container(
      decoration: const BoxDecoration(color: _D.modalBg, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(margin: const EdgeInsets.only(top: 12, bottom: 4), width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
        Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Text(_t('removeConfirm'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _D.modalText))),
        const Divider(height: 24, color: _D.border),
        Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Text(_t('removeBody').replaceAll('{name}', name),
                style: const TextStyle(fontSize: 14, color: _D.textSec, height: 1.5))),
        const Divider(height: 1, color: _D.border),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
          child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            GestureDetector(
              onTap: _removing ? null : () => setState(() => _removeTarget = null),
              child: Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                  decoration: BoxDecoration(color: _D.rowBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: _D.border)),
                  child: Text(_t('cancel'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _D.textMuted))),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _removing ? null : () => _removeMember(_removeTarget!),
              child: Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                  decoration: BoxDecoration(color: _D.modalRed, borderRadius: BorderRadius.circular(12)),
                  child: _removing
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(_t('removeConfirmCta'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white))),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _LightMemberRow extends StatelessWidget {
  final Map<String, dynamic> member;
  final String lang;
  final bool isMe, canManage;
  final VoidCallback onRemove;

  const _LightMemberRow({required this.member, required this.lang,
    required this.isMe, required this.canManage, required this.onRemove});

  String _t(String k) => _L[lang]?[k] ?? _L[kLangEn]![k]!;

  @override
  Widget build(BuildContext context) {
    final isCreator   = member['isCreator'] == true;
    final name        = _memberDisplayName(member);
    final displayName = isMe ? '$name (${_t('you')})' : name;
    final avatarSrc   = _memberAvatarSrc(member);
    final imgProvider = _buildImageProvider(avatarSrc);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
      child: Row(children: [
        Stack(clipBehavior: Clip.none, children: [
          CircleAvatar(radius: 26, backgroundColor: _D.accentLt, backgroundImage: imgProvider,
              child: imgProvider == null
                  ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _D.accent))
                  : null),
          if (isCreator)
            Positioned(bottom: -2, right: -2,
                child: Container(width: 18, height: 18,
                    decoration: BoxDecoration(color: _D.accent, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                    child: const Icon(Icons.star_rounded, size: 10, color: Colors.white))),
        ]),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(displayName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _D.modalText),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          if (isCreator) ...[
            const SizedBox(height: 2),
            Text(_t('groupCreator'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _D.modalGreen)),
          ],
        ])),
        const SizedBox(width: 8),
        if (isCreator)
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: _D.accentLt, borderRadius: BorderRadius.circular(20), border: Border.all(color: _D.accentBdr)),
              child: Text(_t('creator'), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: _D.accent, letterSpacing: 0.5)))
        else if (canManage && !isMe)
          GestureDetector(onTap: onRemove,
              child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(color: _D.modalRedBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: _D.modalRedBdr)),
                  child: Text(_t('remove'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: _D.modalRedText))))
        else
          Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey.shade400),
      ]),
    );
  }
}

class _LightFilterTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _LightFilterTab({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? _D.accentLt : _D.rowBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: selected ? _D.accent : _D.border, width: selected ? 1.5 : 1.0),
      ),
      child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: selected ? _D.accent : _D.textMuted)),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────
class OrganizerGroupSettingsScreen extends ConsumerStatefulWidget {
  final String groupId;
  final Map<String, dynamic> initialData;

  const OrganizerGroupSettingsScreen({super.key, required this.groupId, required this.initialData});

  @override
  ConsumerState<OrganizerGroupSettingsScreen> createState() =>
      _OrganizerGroupSettingsScreenState();
}

class _OrganizerGroupSettingsScreenState extends ConsumerState<OrganizerGroupSettingsScreen> {

  late final TextEditingController _nameEnCtrl;
  late final TextEditingController _nameJpCtrl;
  late final TextEditingController _descEnCtrl;
  late final TextEditingController _descJpCtrl;

  bool _saving = false;
  bool _dirty  = false;

  File? _pickedImageFile;
  bool  _uploadingImage = false;

  Map<String, dynamic> _groupData = {};
  StreamSubscription? _groupSub;

  Map<String, dynamic>? _creatorProfile;
  bool _creatorLoading = true;

  List<Map<String, dynamic>> _members = [];
  bool _membersLoading = true;
  static const _maxMembersPreview = 4;

  List<Map<String, dynamic>> _events = [];
  bool _eventsLoading = true;
  // Show up to 3 full-width event cards then "View all N events" link
  static const _maxEventsPreview = 3;

  @override
  void initState() {
    super.initState();
    _groupData = Map<String, dynamic>.from(widget.initialData);
    _nameEnCtrl = TextEditingController(text: (widget.initialData['org_name'] ?? '').toString());
    _nameJpCtrl = TextEditingController(text: (widget.initialData['org_name_jp'] ?? '').toString());
    _descEnCtrl = TextEditingController(text: (widget.initialData['org_description'] ?? '').toString());
    _descJpCtrl = TextEditingController(text: (widget.initialData['org_description_jp'] ?? '').toString());
    for (final ctrl in [_nameEnCtrl, _nameJpCtrl, _descEnCtrl, _descJpCtrl]) {
      ctrl.addListener(() => setState(() => _dirty = true));
    }
    _subscribeGroupDoc();
    _loadCreatorProfile();
    _loadMembers();
    _loadEvents();
  }

  @override
  void dispose() {
    _groupSub?.cancel();
    _nameEnCtrl.dispose(); _nameJpCtrl.dispose();
    _descEnCtrl.dispose(); _descJpCtrl.dispose();
    super.dispose();
  }

  void _subscribeGroupDoc() {
    _groupSub = FirebaseFirestore.instance
        .collection('organizations')
        .doc(widget.groupId)
        .snapshots()
        .listen((snap) {
      if (!snap.exists || !mounted) return;
      setState(() => _groupData = snap.data()!);
    });
  }

  Future<void> _loadCreatorProfile() async {
    setState(() => _creatorLoading = true);
    try {
      final uid = (_groupData['submittedBy'] ?? _groupData['org_creator'] ?? '').toString();
      if (uid.isEmpty) { if (mounted) setState(() => _creatorLoading = false); return; }
      final snap = await FirebaseFirestore.instance.collection('registration').doc(uid).get();
      if (snap.exists && mounted) {
        setState(() { _creatorProfile = {'uid': uid, ...snap.data()!}; _creatorLoading = false; });
      } else {
        if (mounted) setState(() => _creatorLoading = false);
      }
    } catch (_) { if (mounted) setState(() => _creatorLoading = false); }
  }

  Future<void> _loadMembers() async {
    setState(() => _membersLoading = true);
    try {
      final creatorUid = (_groupData['submittedBy'] ?? _groupData['org_creator'] ?? '').toString();
      final ugSnap = await FirebaseFirestore.instance
          .collection('user_groups')
          .where('group_id', isEqualTo: widget.groupId)
          .where('status', isEqualTo: 'active')
          .limit(20)
          .get();

      if (ugSnap.docs.isNotEmpty) {
        final uids = ugSnap.docs.map((d) => (d.data()['user_id'] ?? d.id).toString().trim())
            .where((uid) => uid.isNotEmpty).toList();
        if (creatorUid.isNotEmpty && !uids.contains(creatorUid)) uids.add(creatorUid);
        final results = await Future.wait(uids.toSet().toList().map((uid) async {
          try {
            final reg = await FirebaseFirestore.instance.collection('registration').doc(uid).get();
            if (reg.exists && reg.data() != null) {
              final rd = reg.data()!;
              final nick  = (rd['nickname']  ?? '').toString().trim();
              final first = (rd['firstName'] ?? '').toString().trim();
              final last  = (rd['lastName']  ?? '').toString().trim();
              final name  = nick.isNotEmpty ? nick : (first.isNotEmpty && last.isNotEmpty) ? '$first $last' : first.isNotEmpty ? first : uid;
              final rawAvatar = (rd['profile_img'] ?? rd['photoURL'] ?? rd['photo_url'] ?? '').toString().trim();
              return <String, dynamic>{'uid': uid, 'name': name, 'avatar': _toImgSrc(rawAvatar), 'isCreator': uid == creatorUid};
            }
          } catch (_) {}
          return <String, dynamic>{'uid': uid, 'name': uid, 'avatar': '', 'isCreator': uid == creatorUid};
        }));
        results.sort((a, b) { if (a['isCreator'] == true) return -1; if (b['isCreator'] == true) return 1; return 0; });
        if (mounted) setState(() { _members = results; _membersLoading = false; });
        return;
      }

      // Fallback: org_members array
      final orgSnap = await FirebaseFirestore.instance.collection('organizations').doc(widget.groupId).get();
      final arr = List<String>.from(orgSnap.data()?['org_members'] ?? []);
      final results = await Future.wait(arr.map((uid) async {
        try {
          final reg = await FirebaseFirestore.instance.collection('registration').doc(uid).get();
          if (reg.exists && reg.data() != null) {
            final rd = reg.data()!;
            final nick  = (rd['nickname']  ?? '').toString().trim();
            final first = (rd['firstName'] ?? '').toString().trim();
            final last  = (rd['lastName']  ?? '').toString().trim();
            final name  = nick.isNotEmpty ? nick : (first.isNotEmpty && last.isNotEmpty) ? '$first $last' : first.isNotEmpty ? first : uid;
            final rawAvatar = (rd['profile_img'] ?? rd['photoURL'] ?? '').toString().trim();
            return <String, dynamic>{'uid': uid, 'name': name, 'avatar': _toImgSrc(rawAvatar), 'isCreator': uid == creatorUid};
          }
        } catch (_) {}
        return <String, dynamic>{'uid': uid, 'name': uid, 'avatar': '', 'isCreator': uid == creatorUid};
      }));
      results.sort((a, b) { if (a['isCreator'] == true) return -1; if (b['isCreator'] == true) return 1; return 0; });
      if (mounted) setState(() { _members = results; _membersLoading = false; });
    } catch (_) { if (mounted) setState(() => _membersLoading = false); }
  }

  // ★ _loadEvents — only shows events submitted by the logged-in user,
  //   filtered to this group via multi-strategy query (event_org_id primary,
  //   org_id fallback, org name last resort). Mirrors the web app fix.
  Future<void> _loadEvents() async {
    setState(() => _eventsLoading = true);
    try {
      final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final orgId      = (_groupData['org_id'] ?? '').toString().trim();
      final orgName    = (_groupData['org_name'] ?? '').toString().trim();

      final results = await _fetchEventsForGroup(
        groupDocId:     widget.groupId,
        orgId:          orgId,
        orgName:        orgName,
        currentUserUid: currentUid,
      );

      if (mounted) setState(() { _events = results; _eventsLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _eventsLoading = false);
    }
  }

  Future<void> _toggleActive() async {
    final newVal = !(_groupData['org_active'] == true);
    await FirebaseFirestore.instance.collection('organizations').doc(widget.groupId).update({'org_active': newVal});
  }

  Future<void> _togglePublic() async {
    final newVal = !(_groupData['org_public'] != false);
    await FirebaseFirestore.instance.collection('organizations').doc(widget.groupId).update({'org_public': newVal});
  }

  Future<void> _pickCoverImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context, backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(color: _D.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            leading: Container(width: 40, height: 40, decoration: BoxDecoration(color: _D.accentLt, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.photo_library_rounded, color: _D.accent, size: 20)),
            title: const Text('Photo Library', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
          const SizedBox(height: 4),
          ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            leading: Container(width: 40, height: 40, decoration: BoxDecoration(color: _D.accentLt, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.camera_alt_rounded, color: _D.accent, size: 20)),
            title: const Text('Camera', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
        ]),
      ),
    );
    if (source == null) return;
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 85, maxWidth: 1200);
    if (picked == null) return;
    setState(() { _pickedImageFile = File(picked.path); _uploadingImage = true; _dirty = true; });
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
      final ext = picked.path.split('.').last;
      final ref = FirebaseStorage.instance
          .ref('organization_images/${widget.groupId}_${DateTime.now().millisecondsSinceEpoch}.$ext');
      await ref.putFile(_pickedImageFile!);
      final downloadUrl = await ref.getDownloadURL();
      await FirebaseFirestore.instance.collection('organizations').doc(widget.groupId).update({
        'org_image': downloadUrl, 'updated_at': FieldValue.serverTimestamp(), 'updated_by': uid,
      });
      if (mounted) {
        setState(() { _groupData['org_image'] = downloadUrl; _uploadingImage = false; _dirty = false; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Cover image updated!'), backgroundColor: _D.accent,
          behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16), duration: const Duration(seconds: 2),
        ));
      }
    } catch (_) {
      if (mounted) {
        setState(() { _uploadingImage = false; _pickedImageFile = null; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Failed to upload image.'), backgroundColor: _D.rejClr,
          behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ));
      }
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final lang = ref.read(appLangProvider);
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('organizations').doc(widget.groupId).update({
        'org_name':           _nameEnCtrl.text.trim(),
        'org_name_jp':        _nameJpCtrl.text.trim(),
        'org_description':    _descEnCtrl.text.trim(),
        'org_description_jp': _descJpCtrl.text.trim(),
        'updated_at':         FieldValue.serverTimestamp(),
        if (FirebaseAuth.instance.currentUser?.uid != null)
          'updated_by': FirebaseAuth.instance.currentUser!.uid,
      });
      if (mounted) {
        setState(() { _saving = false; _dirty = false; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_t(lang, 'saved')), backgroundColor: _D.accent,
          behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16), duration: const Duration(seconds: 2),
        ));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_t(ref.read(appLangProvider), 'saveError')), backgroundColor: _D.rejClr,
          behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ));
      }
    }
  }

  void _navigateToAddEvent(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => AddEventScreen(
        initialOrgName:      (_groupData['org_name']           ?? '').toString(),
        initialVenueName:    (_groupData['org_venue_loc_name'] ?? '').toString(),
        initialCity:         (_groupData['org_city']           ?? '').toString(),
        initialPrefecture:   (_groupData['org_prefecture']     ?? '').toString(),
        initialCountry:      (_groupData['org_country']        ?? '').toString(),
        initialContactEmail: (_groupData['org_contact_email']  ?? '').toString(),
        initialLink:         (_groupData['org_website']        ?? '').toString(),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final lang       = ref.watch(appLangProvider);
    final isActive   = _groupData['org_active'] == true;
    final isPublic   = _groupData['org_public'] != false;
    final isApproved = _groupData['org_checked'] == true && _groupData['org_pending_review'] != true;
    final isRejected = _groupData['rejected'] == true;
    final imgUrl     = (_groupData['org_image'] ?? '').toString();

    return Scaffold(
      backgroundColor: _D.pageBg,
      appBar: AppBar(
        backgroundColor: _D.white, elevation: 0, surfaceTintColor: _D.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: Colors.black87, onPressed: () => Navigator.pop(context),
        ),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_t(lang, 'title'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.black87)),
          Text(_t(lang, 'sub'), style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
        ]),
        actions: [
          if (_dirty)
            TextButton(
              onPressed: _saving ? null : _save,
              child: Text(_t(lang, 'saveChanges'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _D.accent)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildCoverImage(imgUrl, lang),
          const SizedBox(height: 16),
          if (isApproved) ...[_buildStatusToggles(lang, isActive, isPublic), const SizedBox(height: 16)],
          _buildInfoCard(lang, isApproved, isRejected),
          const SizedBox(height: 16),
          _buildCard(child: Column(children: [
            _buildField(label: _t(lang, 'groupNameEn'), ctrl: _nameEnCtrl, hint: _t(lang, 'namePh')),
            const _Divider(),
            _buildField(label: _t(lang, 'groupNameJp'), ctrl: _nameJpCtrl, hint: '日本語のグループ名…'),
            const _Divider(),
            _buildField(label: _t(lang, 'descEn'), ctrl: _descEnCtrl, hint: _t(lang, 'descPh'), maxLines: 4),
            const _Divider(),
            _buildField(label: _t(lang, 'descJp'), ctrl: _descJpCtrl, hint: '説明を入力…', maxLines: 4),
          ])),
          const SizedBox(height: 16),
          _buildSectionHeader(_t(lang, 'groupMembers'), Icons.people_alt_rounded,
              badge: _members.isNotEmpty ? '${_members.length}' : null),
          const SizedBox(height: 8),
          _buildMembersCard(lang),
          const SizedBox(height: 16),
          _buildSectionHeader(_t(lang, 'upcomingTitle'), Icons.event_rounded,
              badge: _upcomingOf(_events).isNotEmpty ? '${_upcomingOf(_events).length}' : null),
          const SizedBox(height: 8),
          _buildEventsCard(lang, isPast: false),
          const SizedBox(height: 20),
          _buildSectionHeader(_t(lang, 'pastTitle'), Icons.history_rounded,
              badge: _pastOf(_events).isNotEmpty ? '${_pastOf(_events).length}' : null),
          const SizedBox(height: 8),
          _buildEventsCard(lang, isPast: true),
          const SizedBox(height: 24),
          _buildSaveButton(lang),
          const SizedBox(height: 32),
        ]),
      ),
    );
  }

  Widget _buildCoverImage(String imgUrl, String lang) {
    return GestureDetector(
      onTap: _uploadingImage ? null : _pickCoverImage,
      child: Container(
        height: 200, width: double.infinity,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: _D.accentLt),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(children: [
            if (_pickedImageFile != null)
              Image.file(_pickedImageFile!, width: double.infinity, height: 200, fit: BoxFit.cover)
            else if (imgUrl.isNotEmpty)
              Image.network(imgUrl, width: double.infinity, height: 200, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _imgPlaceholder())
            else
              _imgPlaceholder(),
            Positioned.fill(child: Container(decoration: BoxDecoration(gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withOpacity(0.25)])))),
            Positioned(bottom: 12, left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.45), borderRadius: BorderRadius.circular(20)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.image_rounded, size: 12, color: Colors.white),
                    const SizedBox(width: 5),
                    Text(_t(lang, 'coverImage'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                  ]),
                )),
            Positioned(top: 12, right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.50), borderRadius: BorderRadius.circular(20)),
                  child: _uploadingImage
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.edit_rounded, size: 12, color: Colors.white),
                    SizedBox(width: 4),
                    Text('Edit', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                  ]),
                )),
          ]),
        ),
      ),
    );
  }

  Widget _imgPlaceholder() => Container(width: double.infinity, height: 200, color: _D.accentLt,
      child: Icon(Icons.group_rounded, size: 56, color: _D.accent.withOpacity(0.3)));

  Widget _buildStatusToggles(String lang, bool isActive, bool isPublic) {
    return Row(children: [
      Expanded(child: _ToggleBtn(
          label: isActive ? _t(lang, 'deactivate') : _t(lang, 'activate'),
          icon: isActive ? Icons.toggle_on_rounded : Icons.toggle_off_rounded,
          color: isActive ? _D.rejClr : _D.apprvClr, bg: isActive ? _D.rejBg : _D.apprvBg, onTap: _toggleActive)),
      const SizedBox(width: 10),
      Expanded(child: _ToggleBtn(
          label: isPublic ? _t(lang, 'makePrivate') : _t(lang, 'makePublic'),
          icon: isPublic ? Icons.lock_outline_rounded : Icons.public_rounded,
          color: const Color(0xFF1565C0), bg: const Color(0xFFE3F2FD), onTap: _togglePublic)),
    ]);
  }

  Widget _buildInfoCard(String lang, bool isApproved, bool isRejected) {
    String creatorName = '—';
    String creatorAvatarSrc = '';
    if (_creatorProfile != null) {
      creatorName = _memberDisplayName(_creatorProfile!);
      creatorAvatarSrc = _memberAvatarSrc(_creatorProfile!);
    }
    final dateString = _fmtDate(_groupData['org_added'] ?? _groupData['org_created_at'], lang);
    Color statusClr; Color statusBg; String statusLabel;
    if (isApproved)      { statusClr = _D.apprvClr; statusBg = _D.apprvBg; statusLabel = _t(lang, 'approved').toUpperCase(); }
    else if (isRejected) { statusClr = _D.rejClr;   statusBg = _D.rejBg;   statusLabel = _t(lang, 'rejected').toUpperCase(); }
    else                 { statusClr = _D.pendClr;  statusBg = _D.pendBg;  statusLabel = _t(lang, 'pending').toUpperCase(); }

    final avatarImg = _buildImageProvider(creatorAvatarSrc);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(color: _D.infoBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: _D.infoBdr)),
      child: Padding(padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Text(_t(lang, 'addedBy'), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: _D.infoLabel, letterSpacing: 1.2)),
          const SizedBox(height: 10),
          _creatorLoading
              ? const SizedBox(height: 44, child: Center(child: CircularProgressIndicator(color: _D.accent, strokeWidth: 2)))
              : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            CircleAvatar(radius: 20, backgroundColor: _D.accentLt, backgroundImage: avatarImg,
                child: avatarImg == null
                    ? Text(creatorName.isNotEmpty ? creatorName[0].toUpperCase() : '?',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _D.accent))
                    : null),
            const SizedBox(width: 10),
            Flexible(child: Text(creatorName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _D.textPri), overflow: TextOverflow.ellipsis)),
          ]),
          const SizedBox(height: 16),
          const Divider(height: 1, color: _D.infoBdr),
          const SizedBox(height: 16),
          Text(_t(lang, 'createdStatus'), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: _D.infoLabel, letterSpacing: 1.2)),
          const SizedBox(height: 10),
          Text(dateString, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _D.textSec), textAlign: TextAlign.center),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: statusClr.withOpacity(0.3))),
            child: Text(statusLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: statusClr, letterSpacing: 0.8)),
          ),
        ]),
      ),
    );
  }

  Widget _buildCard({required Widget child}) => Container(
    decoration: BoxDecoration(color: _D.white, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 3))]),
    child: child,
  );

  Widget _buildField({required String label, required TextEditingController ctrl, String hint = '', int maxLines = 1}) {
    return Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _D.textMuted, letterSpacing: 0.2)),
          const SizedBox(height: 6),
          TextField(controller: ctrl, maxLines: maxLines,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: _D.textPri),
              decoration: InputDecoration(
                hintText: hint, hintStyle: const TextStyle(fontSize: 14, color: _D.textDim),
                filled: true, fillColor: _D.inputBg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _D.accent, width: 1.5)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              )),
        ]));
  }

  Widget _buildSectionHeader(String label, IconData icon, {String? badge}) {
    return Row(children: [
      Container(width: 32, height: 32, decoration: BoxDecoration(color: _D.accentLt, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 16, color: _D.accent)),
      const SizedBox(width: 10),
      Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _D.textPri)),
      if (badge != null) ...[
        const SizedBox(width: 8),
        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: _D.accentLt, borderRadius: BorderRadius.circular(20), border: Border.all(color: _D.accentBdr)),
            child: Text(badge, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _D.accent))),
      ],
    ]);
  }

  Widget _buildMembersCard(String lang) {
    if (_membersLoading) return _buildCard(child: const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(color: _D.accent, strokeWidth: 2.5))));
    if (_members.isEmpty) return _buildCard(child: Padding(padding: const EdgeInsets.all(20), child: Center(child: Text(_t(lang, 'noMembers'), style: const TextStyle(fontSize: 13, color: _D.textMuted)))));

    final preview    = _members.take(_maxMembersPreview).toList();
    final extra      = _members.length - _maxMembersPreview;
    final creatorUid = (_groupData['submittedBy'] ?? _groupData['org_creator'] ?? '').toString();
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return _buildCard(child: Column(children: [
      ...List.generate(preview.length, (i) {
        final m         = preview[i];
        final isCreator = m['isCreator'] == true;
        final name      = (m['name'] ?? '').toString();
        final imgProvider = _buildImageProvider((m['avatar'] ?? '').toString());

        return Column(children: [
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(children: [
                Stack(clipBehavior: Clip.none, children: [
                  CircleAvatar(radius: 22, backgroundColor: _D.accentLt, backgroundImage: imgProvider,
                      child: imgProvider == null ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _D.accent)) : null),
                  if (isCreator) Positioned(bottom: -2, right: -2,
                      child: Container(width: 16, height: 16,
                          decoration: BoxDecoration(color: _D.accent, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)),
                          child: const Icon(Icons.star_rounded, size: 9, color: Colors.white))),
                ]),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _D.textPri), maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (isCreator) ...[const SizedBox(height: 2), Text('Group Creator', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _D.accent.withOpacity(0.8)))],
                ])),
                if (isCreator)
                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: _D.accentLt, borderRadius: BorderRadius.circular(20), border: Border.all(color: _D.accentBdr)),
                      child: Text(_t(lang, 'creator'), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: _D.accent, letterSpacing: 0.5)))
                else
                  const Icon(Icons.chevron_right_rounded, size: 18, color: _D.textDim),
              ])),
          if (i < preview.length - 1) const Divider(height: 1, indent: 60, endIndent: 0, color: _D.border),
        ]);
      }),
      Container(
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: _D.border))),
        child: InkWell(
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
          onTap: () => _showGroupMembersModal(context, widget.groupId, lang, currentUid, creatorUid),
          child: Padding(padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(_t(lang, 'manageAll'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _D.accent)),
                if (extra > 0) ...[const SizedBox(width: 6), Text('(+$extra more)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _D.textMuted))],
                const SizedBox(width: 4),
                const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: _D.accent),
              ])),
        ),
      ),
    ]));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ★ Events Card — mirrors web app:
  //   • Up to 3 full-width event cards (cover image + details)
  //   • If more than 3 → "View all N events for this group" tap opens modal
  //   • Always shows "+ Add an event" footer
  //   • Uses the fixed multi-strategy query (event_org_id primary, org_id fallback, name last resort)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildEventsCard(String lang, {required bool isPast}) {
    if (_eventsLoading) {
      return _buildCard(child: const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator(color: _D.accent, strokeWidth: 2.5))));
    }

    final scopedAll = isPast ? _pastOf(_events) : _upcomingOf(_events);
    final preview   = scopedAll.take(_maxEventsPreview).toList();
    final hasMore   = scopedAll.length > _maxEventsPreview;
    final allCount  = scopedAll.length;

    final orgId      = (_groupData['org_id'] ?? '').toString().trim();
    final orgName    = (_groupData['org_name'] ?? '').toString().trim();
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final emptyKey   = isPast ? 'noPast' : 'noUpcoming';
    final viewAllKey = isPast ? 'viewAllPast' : 'viewAllUpcoming';
    final modalFilter = isPast ? 'past' : 'upcoming';

    return _buildCard(child: Column(children: [
      // ── Empty state ──────────────────────────────────────────────────────
      if (scopedAll.isEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 60, height: 60,
                decoration: const BoxDecoration(color: _D.accentLt, shape: BoxShape.circle),
                child: Icon(isPast ? Icons.history_rounded : Icons.event_rounded,
                    size: 28, color: _D.accent.withOpacity(0.5))),
            const SizedBox(height: 12),
            Text(_t(lang, emptyKey),
                style: const TextStyle(fontSize: 13, color: _D.textMuted, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center),
          ]),
        )
      else
      // ── Event list (full-width cards) ───────────────────────────────────
        Column(children: List.generate(preview.length, (i) {
          final ev     = preview[i];
          final title  = lang == kLangJa
              ? (ev['event_title_jp'] ?? ev['event_title'] ?? 'Untitled').toString()
              : (ev['event_title'] ?? 'Untitled').toString();
          final desc   = lang == kLangJa
              ? (ev['event_description_jp'] ?? ev['event_description_en'] ?? '').toString()
              : (ev['event_description_en'] ?? '').toString();
          final imgUrl = (ev['event_pic'] ?? ev['event_pic_thumbnail'] ?? '').toString();
          final dateStr = _fmtDateShort(ev['event_date'], lang: lang);
          final evType = (ev['event_type'] ?? '').toString();
          final isAppr = ev['event_checked'] == true && ev['event_pending_review'] != true;
          final isRej  = ev['rejected'] == true;

          Color sc; String sl;
          if (isAppr)     { sc = _D.apprvClr; sl = _t(lang, 'approved'); }
          else if (isRej) { sc = _D.rejClr;   sl = _t(lang, 'rejected'); }
          else            { sc = _D.pendClr;  sl = _t(lang, 'pending'); }

          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Cover image — full width, 160px tall
            ClipRRect(
              borderRadius: i == 0
                  ? const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16))
                  : BorderRadius.zero,
              child: Stack(children: [
                imgUrl.isNotEmpty
                    ? Image.network(imgUrl, height: 160, width: double.infinity, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _eventImgPh())
                    : _eventImgPh(),
                // Subtle gradient overlay
                Positioned.fill(child: Container(decoration: BoxDecoration(
                    gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withOpacity(0.15)])))),
                // Status badge — top left
                Positioned(top: 10, left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(color: sc.withOpacity(0.92), borderRadius: BorderRadius.circular(20)),
                      child: Text(sl.toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.4)),
                    )),
                // Event type pill — bottom right
                if (evType.isNotEmpty)
                  Positioned(bottom: 10, right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: Colors.black.withOpacity(0.60), borderRadius: BorderRadius.circular(20)),
                        child: Text(evType, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
                      )),
              ]),
            ),
            // Text body
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _D.textPri), maxLines: 2, overflow: TextOverflow.ellipsis),
                if (desc.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(desc, style: const TextStyle(fontSize: 12, color: _D.textMuted, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: 10),
                Row(children: [
                  Icon(Icons.calendar_today_rounded, size: 12, color: _D.accent),
                  const SizedBox(width: 5),
                  Text(dateStr, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _D.accent)),
                ]),
              ]),
            ),
            // Divider between cards (not after last)
            if (i < preview.length - 1) const Divider(height: 1, color: _D.border),
          ]);
        })),

      // ── Footer ─────────────────────────────────────────────────────────
      Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: scopedAll.isEmpty ? Colors.transparent : _D.border)),
        ),
        child: Column(children: [
          // "View all N events" — only shown when there are more than preview limit
          if (hasMore)
            InkWell(
              onTap: () => _showAllEventsModal(
                context, widget.groupId, orgId, orgName, lang, currentUid, _events,
                filter: modalFilter,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(width: 26, height: 26,
                      decoration: BoxDecoration(color: _D.accentLt, borderRadius: BorderRadius.circular(8)),
                      child: Icon(isPast ? Icons.history_rounded : Icons.event_rounded, size: 14, color: _D.accent)),
                  const SizedBox(width: 8),
                  Text(
                    _t(lang, viewAllKey).replaceAll('{count}', '$allCount'),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _D.accent),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: _D.accent),
                ]),
              ),
            ),
          // Divider between "view all" and "add event" (only for upcoming section)
          if (hasMore && !isPast) const Divider(height: 1, color: _D.border),
          // "+ Add an event" — only in upcoming section
          if (!isPast)
            InkWell(
              borderRadius: BorderRadius.vertical(
                bottom: const Radius.circular(16),
                top: (!hasMore && scopedAll.isEmpty) ? const Radius.circular(16) : Radius.zero,
              ),
              onTap: () => _navigateToAddEvent(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.add_circle_outline_rounded, size: 16, color: _D.accent),
                  const SizedBox(width: 6),
                  Text(_t(lang, 'addEvent'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _D.accent)),
                ]),
              ),
            ),
        ]),
      ),
    ]));
  }


  Widget _eventImgPh() => Container(height: 160, width: double.infinity, color: _D.accentLt,
      child: Icon(Icons.event_rounded, size: 36, color: _D.accent.withOpacity(0.3)));

  Widget _buildSaveButton(String lang) => SizedBox(
    width: double.infinity, height: 52,
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: _dirty ? _D.accent : Colors.grey.shade300,
        foregroundColor: Colors.white, elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      onPressed: (_dirty && !_saving) ? _save : null,
      child: _saving
          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
          : Text(_t(lang, 'saveChanges'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared small widgets
// ─────────────────────────────────────────────────────────────────────────────
class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, color: _D.border, indent: 16, endIndent: 16);
}

class _ToggleBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color, bg;
  final VoidCallback onTap;
  const _ToggleBtn({required this.label, required this.icon, required this.color, required this.bg, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3), width: 1.2)),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
      ]),
    ),
  );
}
