import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pikuru/theme/material.dart';
import 'package:pikuru/providers/app_language_provider.dart';
import 'package:pikuru/screens/organizer_event_detail_screen.dart';
import 'package:pikuru/screens/event_chat_screen.dart';
import 'package:pikuru/screens/organizer_group_settings_screen.dart';
import 'package:pikuru/screens/event_detail_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Design tokens — light mode with green accent
// ─────────────────────────────────────────────────────────────────────────────
class _D {
  static const pageBg      = Color(0xFFF7F8FA);
  static const white       = Colors.white;
  static const accent      = Color(0xFF2D7D46);
  static const accentLt    = Color(0xFFEDF7EF);
  static const accentBdr   = Color(0xFFB7DFC2);
  static const textPri     = Color(0xFF0D0D0D);
  static const textSec     = Color(0xFF374151);
  static const textMuted   = Color(0xFF6B7280);
  static const textDim     = Color(0xFF9CA3AF);
  static const border      = Color(0xFFE5E7EB);
  static const rowBg       = Color(0xFFF9FAFB);
  static const apprvClr    = Color(0xFF2D7D46);
  static const apprvBg     = Color(0xFFEDF7EF);
  static const pendClr     = Color(0xFFF57C00);
  static const pendBg      = Color(0xFFFFF3E0);
  static const rejClr      = Color(0xFFD32F2F);
  static const rejBg       = Color(0xFFFFEBEE);
  static const tabSelBg    = Color(0xFFEDF7EF);
  static const tabSelBdr   = Color(0xFFB7DFC2);
  static const tabUnselBg  = Color(0xFFF3F4F6);
  static const tabUnselBdr = Color(0xFFE5E7EB);
}

// ─────────────────────────────────────────────────────────────────────────────
// Localisation
// ─────────────────────────────────────────────────────────────────────────────
const _L = {
  kLangEn: {
    'title':        'Organizer Dashboard',
    'sub':          'Manage your events, groups and registrations.',
    'myEvents':     'My Events',
    'myGroups':     'My Groups',
    'registered':   'Registered',
    'auditLog':     'Audit Log',
    'noEvents':     'You have not created any events yet.',
    'noGroups':     'You have not created any groups yet.',
    'noRegistered': 'You have not registered for any events yet.',
    'noAudit':      'No actions recorded yet.',
    'pending':      'Pending',
    'approved':     'Approved',
    'rejected':     'Rejected',
    'active':       'Active',
    'inactive':     'Inactive',
    'public':       'Public',
    'private':      'Private',
    'free':         'Free',
    'edit':         'Edit',
    'viewDetails':  'View Details',
    'registrants':  'Registrants',
    'openChannel':  'Chat Channel',
    'regApproved':  'Approved',
    'regPending':   'Pending',
    'regRejected':  'Rejected',
    'views':        'Views',
    'noLimit':      'No limit',
    'date':         'Date',
    'fee':          'Fee',
    'limit':        'Limit',
    'type':         'Type',
    'loadMore':     'Load more',
    'regTitle':     'Event Registrations',
    'regTotal':     'Total registrations',
    'regAll':       'All',
    'noRegs':       'No registrations yet.',
    'approve':      'Approve',
    'reject':       'Reject',
    'seeMore':      'See more',
  },
  kLangJa: {
    'title':        'オーガナイザーダッシュボード',
    'sub':          'イベント・グループ・登録を管理しましょう。',
    'myEvents':     'マイイベント',
    'myGroups':     'マイグループ',
    'registered':   '登録済み',
    'auditLog':     '監査ログ',
    'noEvents':     'まだイベントを作成していません。',
    'noGroups':     'まだグループを作成していません。',
    'noRegistered': 'まだイベントに登録していません。',
    'noAudit':      'まだ記録がありません。',
    'pending':      '承認待ち',
    'approved':     '承認済み',
    'rejected':     '却下',
    'active':       'アクティブ',
    'inactive':     '非アクティブ',
    'public':       '公開',
    'private':      '非公開',
    'free':         '無料',
    'edit':         '編集',
    'viewDetails':  '詳細を見る',
    'registrants':  '登録者',
    'openChannel':  'チャット',
    'regApproved':  '承認済み',
    'regPending':   '審査中',
    'regRejected':  '却下',
    'views':        '閲覧',
    'noLimit':      '制限なし',
    'date':         '日付',
    'fee':          '参加費',
    'limit':        '定員',
    'type':         'タイプ',
    'loadMore':     'もっと見る',
    'regTitle':     'イベント登録管理',
    'regTotal':     '登録者合計',
    'regAll':       'すべて',
    'noRegs':       'まだ登録者がいません。',
    'approve':      '承認',
    'reject':       '却下',
    'seeMore':      'すべて見る',
  },
};

String _t(String lang, String key) =>
    _L[lang]?[key] ?? _L[kLangEn]![key]!;

// ─────────────────────────────────────────────────────────────────────────────
// Date helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Format a Firestore Timestamp for card chips (compact: yyyy/MM/dd)
String _fmtDate(dynamic ts, {bool compact = false}) {
  if (ts == null || ts is! Timestamp) return '—';
  final d = ts.toDate();
  if (compact) {
    return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
  }
  const mo = ['Jan','Feb','Mar','Apr','May','Jun',
    'Jul','Aug','Sep','Oct','Nov','Dec'];
  return '${mo[d.month - 1]} ${d.day}, ${d.year}';
}

/// Format a registration date with full locale awareness.
/// EN → "May 27, 2026"   JA → "2026年5月27日"
String _fmtRegDate(dynamic ts, String lang) {
  if (ts == null || ts is! Timestamp) return '';
  final d = ts.toDate();
  if (lang == 'ja') {
    return '${d.year}年${d.month}月${d.day}日';
  }
  const mo = ['Jan','Feb','Mar','Apr','May','Jun',
    'Jul','Aug','Sep','Oct','Nov','Dec'];
  return '${mo[d.month - 1]} ${d.day}, ${d.year}';
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────
class OrganizerDashboardScreen extends ConsumerStatefulWidget {
  const OrganizerDashboardScreen({super.key});

  @override
  ConsumerState<OrganizerDashboardScreen> createState() =>
      _OrganizerDashboardScreenState();
}

class _OrganizerDashboardScreenState
    extends ConsumerState<OrganizerDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _tabs.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appLangProvider);
    final uid  = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: _D.pageBg,
      appBar: AppBar(
        backgroundColor: _D.white,
        elevation: 0,
        surfaceTintColor: _D.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: Colors.black87,
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_t(lang, 'title'),
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87)),
            Text(_t(lang, 'sub'),
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade500)),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: _D.white,
            child: TabBar(
              controller: _tabs,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              labelColor: AppColors.primary,
              unselectedLabelColor: Colors.grey.shade500,
              labelStyle:
              const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              unselectedLabelStyle:
              const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              tabs: [
                Tab(text: _t(lang, 'myEvents')),
                Tab(text: _t(lang, 'myGroups')),
                Tab(text: _t(lang, 'registered')),
                Tab(text: _t(lang, 'auditLog')),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _MyEventsTab(uid: uid, lang: lang),
          _MyGroupsTab(uid: uid, lang: lang),
          _RegisteredTab(uid: uid, lang: lang),
          _AuditLogTab(uid: uid, lang: lang),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TAB 1 — MY EVENTS
// ═════════════════════════════════════════════════════════════════════════════
class _MyEventsTab extends StatefulWidget {
  final String uid, lang;
  const _MyEventsTab({required this.uid, required this.lang});

  @override
  State<_MyEventsTab> createState() => _MyEventsTabState();
}

class _MyEventsTabState extends State<_MyEventsTab> {
  final Map<String, Map<String, int>> _metrics = {};

  Future<void> _loadMetrics(List<QueryDocumentSnapshot> docs) async {
    for (final doc in docs) {
      final id = doc.id;
      if (_metrics.containsKey(id)) continue;
      final data  = doc.data() as Map<String, dynamic>;
      final views = (data['event_view_count'] ?? 0) as int;
      try {
        final all  = await FirebaseFirestore.instance
            .collection('event_registrations')
            .where('event_id', isEqualTo: id)
            .count()
            .get();
        final pend = await FirebaseFirestore.instance
            .collection('event_registrations')
            .where('event_id', isEqualTo: id)
            .where('status', isEqualTo: 'pending')
            .count()
            .get();
        final appr = await FirebaseFirestore.instance
            .collection('event_registrations')
            .where('event_id', isEqualTo: id)
            .where('status', isEqualTo: 'approved')
            .count()
            .get();
        if (mounted) {
          setState(() => _metrics[id] = {
            'views':    views,
            'regs':     all.count  ?? 0,
            'pending':  pend.count ?? 0,
            'approved': appr.count ?? 0,
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() => _metrics[id] =
          {'views': views, 'regs': 0, 'pending': 0, 'approved': 0});
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.uid.isEmpty) return const SizedBox.shrink();
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('events')
          .where('submittedBy', isEqualTo: widget.uid)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data!.docs;
        docs.sort((a, b) {
          final ta = (a.data() as Map)['event_added'];
          final tb = (b.data() as Map)['event_added'];
          final tA = ta is Timestamp ? ta.millisecondsSinceEpoch : 0;
          final tB = tb is Timestamp ? tb.millisecondsSinceEpoch : 0;
          return tB.compareTo(tA);
        });
        Future.microtask(() => _loadMetrics(docs));
        if (docs.isEmpty) {
          return _EmptyState(
              icon: Icons.event_note_rounded,
              message: _t(widget.lang, 'noEvents'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (ctx, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            return _EventCard(
              eventId: docs[i].id,
              data:    data,
              lang:    widget.lang,
              metrics: _metrics[docs[i].id],
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Event Card
// ─────────────────────────────────────────────────────────────────────────────
class _EventCard extends StatelessWidget {
  final String eventId, lang;
  final Map<String, dynamic> data;
  final Map<String, int>? metrics;

  const _EventCard({
    required this.eventId,
    required this.data,
    required this.lang,
    this.metrics,
  });

  void _openChat(BuildContext context) {
    final chatId = 'event_$eventId';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EventChatScreen(
          chatId:    chatId,
          eventData: {...data, '_doc_id': eventId},
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPending  = data['event_pending_review'] == true &&
        data['event_checked'] != true;
    final isApproved = data['event_checked'] == true &&
        data['event_pending_review'] != true;
    final isRejected = data['rejected'] == true;

    final title = lang == 'ja'
        ? (data['event_title_jp'] ?? data['event_title'] ?? 'Untitled').toString()
        : (data['event_title'] ?? 'Untitled').toString();
    final desc  = lang == 'ja'
        ? (data['event_description_jp'] ?? data['event_description_en'] ?? '').toString()
        : (data['event_description_en'] ?? '').toString();
    final imgUrl    = (data['event_pic'] ?? data['event_pic_thumbnail'] ?? '').toString();
    final feeRaw    = (data['event_fee'] ?? '').toString();
    final fee       = (feeRaw.isEmpty || feeRaw == '0') ? _t(lang, 'free') : '¥$feeRaw';
    final dateStr   = _fmtDate(data['event_date'], compact: true);
    final eventType = (data['event_type'] ?? '').toString();

    Color sc; Color sb; String sl; IconData si;
    if (isApproved) {
      sc = _D.apprvClr; sb = _D.apprvBg;
      sl = _t(lang, 'approved'); si = Icons.check_circle_rounded;
    } else if (isRejected) {
      sc = _D.rejClr; sb = _D.rejBg;
      sl = _t(lang, 'rejected'); si = Icons.cancel_rounded;
    } else {
      sc = _D.pendClr; sb = _D.pendBg;
      sl = _t(lang, 'pending'); si = Icons.schedule_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _D.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Cover image
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: Stack(children: [
            imgUrl.isNotEmpty
                ? Image.network(imgUrl,
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _coverPlaceholder())
                : _coverPlaceholder(),
            Positioned(
                top: 12,
                left: 12,
                child: _Badge(label: sl, icon: si, color: sc, bg: sb)),
            if (eventType.isNotEmpty)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.55),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text(eventType,
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ),
              ),
          ]),
        ),

        // Body
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.black87),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                if (desc.isNotEmpty)
                  Text(desc,
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          height: 1.4),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 6, children: [
                  _MetaChip(icon: Icons.calendar_today_rounded, label: dateStr),
                  _MetaChip(icon: Icons.attach_money_rounded, label: fee),
                  if ((data['event_limit'] ?? 0) > 0)
                    _MetaChip(
                        icon: Icons.people_rounded,
                        label: '${data['event_limit']}'),
                ]),

                // Metrics strip
                if (metrics != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.primary.withOpacity(0.12)),
                    ),
                    child: Row(children: [
                      _MetricPill(
                          icon: Icons.visibility_rounded,
                          value: metrics!['views']!,
                          label: _t(lang, 'views'),
                          color: AppColors.primary),
                      _vDivider(),
                      _MetricPill(
                          icon: Icons.how_to_reg_rounded,
                          value: metrics!['regs']!,
                          label: _t(lang, 'registrants'),
                          color: const Color(0xFF5C6BC0)),
                      if ((metrics!['pending'] ?? 0) > 0) ...[
                        _vDivider(),
                        _MetricPill(
                            icon: Icons.schedule_rounded,
                            value: metrics!['pending']!,
                            label: _t(lang, 'regPending'),
                            color: _D.pendClr),
                      ],
                    ]),
                  ),
                ],

                const SizedBox(height: 14),

                // Action buttons
                if (isPending)
                  _ActionButton(
                      icon: Icons.edit_rounded,
                      label: _t(lang, 'edit'),
                      color: AppColors.primary,
                      onTap: () => _showEditDialog(context, eventId, data, lang))
                else
                  Column(children: [
                    _ActionButton(
                        icon: Icons.remove_red_eye_rounded,
                        label: _t(lang, 'viewDetails'),
                        color: AppColors.primary,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => OrganizerEventDetailScreen(
                                eventId: eventId, data: data, lang: lang),
                          ),
                        )),
                    if (isApproved) ...[
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(
                            child: _ActionButton(
                                icon: Icons.chat_bubble_rounded,
                                label: _t(lang, 'openChannel'),
                                color: const Color(0xFF5C6BC0),
                                outlined: true,
                                onTap: () => _openChat(context))),
                        const SizedBox(width: 8),
                        Expanded(
                            child: _ActionButton(
                                icon: Icons.people_rounded,
                                label: _t(lang, 'registrants'),
                                color: AppColors.primary,
                                outlined: true,
                                onTap: () => _showRegistrantsModal(
                                    context, eventId, data, lang))),
                      ]),
                    ],
                  ]),
              ]),
        ),
      ]),
    );
  }

  Widget _coverPlaceholder() => Container(
    height: 160,
    width: double.infinity,
    color: AppColors.primary.withOpacity(0.08),
    child: Icon(Icons.event_rounded,
        size: 48, color: AppColors.primary.withOpacity(0.3)),
  );

  Widget _vDivider() => Container(
    width: 1,
    height: 28,
    margin: const EdgeInsets.symmetric(horizontal: 12),
    color: AppColors.primary.withOpacity(0.15),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Registrants Modal — shows max 5 rows, "See more" opens detail screen
// ─────────────────────────────────────────────────────────────────────────────
void _showRegistrantsModal(BuildContext context, String eventId,
    Map<String, dynamic> eventData, String lang) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _RegistrantsSheet(
        eventId: eventId, eventData: eventData, lang: lang),
  );
}

class _RegistrantsSheet extends StatefulWidget {
  final String eventId, lang;
  final Map<String, dynamic> eventData;

  const _RegistrantsSheet(
      {required this.eventId,
        required this.eventData,
        required this.lang});

  @override
  State<_RegistrantsSheet> createState() => _RegistrantsSheetState();
}

class _RegistrantsSheetState extends State<_RegistrantsSheet> {
  List<Map<String, dynamic>> _regs = [];
  bool    _loading    = true;
  bool    _hasMore    = false;
  String  _filter     = 'all';
  String? _updatingId;

  static const _previewLimit = 5;

  int get _total   => _regs.length;
  int get _appCnt  => _regs.where((r) => r['status'] == 'approved').length;
  int get _pendCnt => _regs.where((r) => (r['status'] ?? 'pending') == 'pending').length;
  int get _rejCnt  => _regs.where((r) => r['status'] == 'rejected').length;

  List<Map<String, dynamic>> get _filtered {
    if (_filter == 'all') return _regs;
    return _regs.where((r) => (r['status'] ?? 'pending') == _filter).toList();
  }

  String _t(String k) => _L[widget.lang]?[k] ?? _L[kLangEn]![k]!;

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('event_registrations')
          .where('event_id', isEqualTo: widget.eventId)
          .orderBy('registered_at', descending: true)
          .limit(_previewLimit + 1)
          .get();

      final hasMore = snap.docs.length > _previewLimit;
      final docs    = hasMore ? snap.docs.take(_previewLimit).toList() : snap.docs;

      setState(() {
        _regs    = docs.map((d) => {'_id': d.id, ...d.data()}).toList();
        _hasMore = hasMore;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _updateStatus(String regId, String status) async {
    setState(() => _updatingId = regId);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      await FirebaseFirestore.instance
          .collection('event_registrations')
          .doc(regId)
          .update({
        'status':     status,
        'updated_at': FieldValue.serverTimestamp(),
        if (uid != null) 'updated_by': uid,
      });
      setState(() {
        final i = _regs.indexWhere((r) => r['_id'] == regId);
        if (i != -1) _regs[i] = {..._regs[i], 'status': status};
      });
    } catch (_) {}
    if (mounted) setState(() => _updatingId = null);
  }

  void _openFullList(BuildContext context) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrganizerEventDetailScreen(
          eventId: widget.eventId,
          data:    widget.eventData,
          lang:    widget.lang,
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.lang == 'ja'
        ? (widget.eventData['event_title_jp'] ??
        widget.eventData['event_title'] ??
        '')
        .toString()
        : (widget.eventData['event_title'] ?? '').toString();

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      maxChildSize:     0.95,
      minChildSize:     0.50,
      builder: (ctx, scroll) => Container(
        decoration: const BoxDecoration(
          color: _D.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 16, 0),
            child: Row(children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_t('regTitle'),
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: _D.textPri)),
                      const SizedBox(height: 2),
                      Text(title,
                          style: const TextStyle(
                              fontSize: 13,
                              color: _D.textMuted,
                              fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ]),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                      color: _D.rowBg,
                      shape: BoxShape.circle,
                      border: Border.all(color: _D.border)),
                  child: const Icon(Icons.close_rounded,
                      size: 17, color: _D.textMuted),
                ),
              ),
            ]),
          ),

          const SizedBox(height: 14),

          // Stat pills
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _StatBadge(
                    '${_t('regTotal')}: $_total${_hasMore ? '+' : ''}',
                    _D.textMuted,
                    _D.rowBg,
                    _D.border),
                const SizedBox(width: 8),
                if (_appCnt > 0) ...[
                  _StatBadge('$_appCnt ${_t('regApproved')}',
                      _D.apprvClr, _D.apprvBg, _D.apprvBg),
                  const SizedBox(width: 8),
                ],
                if (_pendCnt > 0) ...[
                  _StatBadge('$_pendCnt ${_t('regPending')}',
                      _D.pendClr, _D.pendBg, _D.pendBg),
                  const SizedBox(width: 8),
                ],
                if (_rejCnt > 0)
                  _StatBadge('$_rejCnt ${_t('regRejected')}',
                      _D.rejClr, _D.rejBg, _D.rejBg),
              ]),
            ),
          ),

          const SizedBox(height: 12),

          // Filter tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _FilterTab(
                    label: _t('regAll'),
                    value: 'all',
                    current: _filter,
                    onTap: (v) => setState(() => _filter = v)),
                const SizedBox(width: 6),
                _FilterTab(
                    label: '${_t('regPending')} ($_pendCnt)',
                    value: 'pending',
                    current: _filter,
                    onTap: (v) => setState(() => _filter = v)),
                const SizedBox(width: 6),
                _FilterTab(
                    label: '${_t('regApproved')} ($_appCnt)',
                    value: 'approved',
                    current: _filter,
                    onTap: (v) => setState(() => _filter = v)),
                const SizedBox(width: 6),
                _FilterTab(
                    label: '${_t('regRejected')} ($_rejCnt)',
                    value: 'rejected',
                    current: _filter,
                    onTap: (v) => setState(() => _filter = v)),
              ]),
            ),
          ),

          const SizedBox(height: 4),
          const Divider(height: 1, color: _D.border),

          // List
          Expanded(
            child: _loading
                ? Center(
                child:
                CircularProgressIndicator(color: _D.accent))
                : _filtered.isEmpty
                ? Center(
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                          color: _D.accentLt,
                          shape: BoxShape.circle),
                      child: Icon(Icons.people_outline_rounded,
                          size: 28,
                          color: _D.accent.withOpacity(0.5)),
                    ),
                    const SizedBox(height: 12),
                    Text(_t('noRegs'),
                        style: const TextStyle(
                            fontSize: 13,
                            color: _D.textMuted,
                            fontWeight: FontWeight.w500)),
                  ]),
            )
                : ListView.builder(
              controller: scroll,
              padding:
              const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: _filtered.length +
                  (_hasMore && _filter == 'all' ? 1 : 0),
              itemBuilder: (_, i) {
                // "See more" button
                if (i == _filtered.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: GestureDetector(
                      onTap: () => _openFullList(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 14),
                        decoration: BoxDecoration(
                          color: _D.accentLt,
                          borderRadius:
                          BorderRadius.circular(14),
                          border:
                          Border.all(color: _D.accentBdr),
                        ),
                        alignment: Alignment.center,
                        child: Row(
                            mainAxisAlignment:
                            MainAxisAlignment.center,
                            children: [
                              Icon(Icons.people_rounded,
                                  size: 15, color: _D.accent),
                              const SizedBox(width: 6),
                              Text(
                                _t('seeMore'),
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: _D.accent),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                  Icons
                                      .arrow_forward_ios_rounded,
                                  size: 12,
                                  color: _D.accent),
                            ]),
                      ),
                    ),
                  );
                }

                final r = _filtered[i];
                return _RegRow(
                  reg:        r,
                  lang:       widget.lang,
                  isUpdating: _updatingId == r['_id'],
                  onApprove:  () => _updateStatus(
                      r['_id'] as String, 'approved'),
                  onReject:   () => _updateStatus(
                      r['_id'] as String, 'rejected'),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _RegRow — single registrant row with locale-aware date
// ─────────────────────────────────────────────────────────────────────────────
class _RegRow extends StatelessWidget {
  final Map<String, dynamic> reg;
  final String lang;
  final bool isUpdating;
  final VoidCallback onApprove, onReject;

  const _RegRow({
    required this.reg,
    required this.lang,
    required this.isUpdating,
    required this.onApprove,
    required this.onReject,
  });

  String _t(String k) => _L[lang]?[k] ?? _L[kLangEn]![k]!;

  @override
  Widget build(BuildContext context) {
    final status  = (reg['status'] ?? 'pending').toString();
    final name    = (reg['user_name'] ?? reg['user_id'] ?? '?').toString();
    final email   = (reg['user_email'] ?? '').toString();
    final avatar  = (reg['user_avatar'] ?? '').toString();

    // ── Locale-aware registration date ───────────────────────────────────
    final dateStr = _fmtRegDate(reg['registered_at'], lang);

    Color sc; Color sb; String sl;
    switch (status) {
      case 'approved':
        sc = _D.apprvClr; sb = _D.apprvBg; sl = _t('regApproved');
        break;
      case 'rejected':
        sc = _D.rejClr; sb = _D.rejBg; sl = _t('regRejected');
        break;
      default:
        sc = _D.pendClr; sb = _D.pendBg; sl = _t('regPending');
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _D.rowBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _D.border),
      ),
      child: Row(children: [
        // Avatar
        CircleAvatar(
          radius: 22,
          backgroundColor: _D.accentLt,
          backgroundImage:
          avatar.isNotEmpty ? NetworkImage(avatar) : null,
          child: avatar.isEmpty
              ? Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(
                  color: _D.accent,
                  fontWeight: FontWeight.w800,
                  fontSize: 15))
              : null,
        ),
        const SizedBox(width: 12),

        // Info
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _D.textPri),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                if (email.isNotEmpty)
                  Text(email,
                      style: const TextStyle(
                          fontSize: 12, color: _D.textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                const SizedBox(height: 5),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: sb,
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(sl,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: sc)),
                  ),
                  if (dateStr.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text(dateStr,
                        style: const TextStyle(
                            fontSize: 11,
                            color: _D.textDim,
                            fontWeight: FontWeight.w500)),
                  ],
                ]),
              ]),
        ),

        const SizedBox(width: 10),

        // Approve / Reject buttons
        if (isUpdating)
          SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                  color: _D.accent, strokeWidth: 2.5))
        else
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            if (status != 'approved')
              _ABtn(
                  label: _t('approve'),
                  color: _D.apprvClr,
                  bg: _D.apprvBg,
                  onTap: onApprove),
            if (status != 'rejected') ...[
              if (status != 'approved') const SizedBox(height: 6),
              _ABtn(
                  label: _t('reject'),
                  color: _D.rejClr,
                  bg: _D.rejBg,
                  onTap: onReject),
            ],
          ]),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Edit dialog (pending events only)
// ─────────────────────────────────────────────────────────────────────────────
void _showEditDialog(BuildContext context, String eventId,
    Map<String, dynamic> data, String lang) {
  final titleCtrl =
  TextEditingController(text: (data['event_title'] ?? '').toString());
  final descCtrl = TextEditingController(
      text: (data['event_description_en'] ?? '').toString());
  final feeCtrl =
  TextEditingController(text: (data['event_fee'] ?? '').toString());
  bool saving = false;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => StatefulBuilder(builder: (ctx, setS) {
      return Container(
        padding:
        EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius:
            BorderRadius.vertical(top: Radius.circular(28))),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                    child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 20),
                Text(_t(lang, 'edit'),
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 20),
                _SheetField(label: 'Title (EN)', ctrl: titleCtrl),
                const SizedBox(height: 12),
                _SheetField(
                    label: 'Description (EN)',
                    ctrl: descCtrl,
                    maxLines: 4),
                const SizedBox(height: 12),
                _SheetField(
                    label: 'Fee (¥)',
                    ctrl: feeCtrl,
                    keyboardType: TextInputType.number),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    onPressed: saving
                        ? null
                        : () async {
                      setS(() => saving = true);
                      try {
                        await FirebaseFirestore.instance
                            .collection('events')
                            .doc(eventId)
                            .update({
                          'event_title':
                          titleCtrl.text.trim(),
                          'event_description_en':
                          descCtrl.text.trim(),
                          'event_fee': feeCtrl.text.trim(),
                        });
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (_) {
                        setS(() => saving = false);
                      }
                    },
                    child: saving
                        ? const CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2)
                        : const Text('Save Changes',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ),
                ),
              ]),
        ),
      );
    }),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// TAB 2 — MY GROUPS  (cursor-based pagination, 10 per page)
// ═════════════════════════════════════════════════════════════════════════════
class _MyGroupsTab extends StatefulWidget {
  final String uid, lang;
  const _MyGroupsTab({required this.uid, required this.lang});

  @override
  State<_MyGroupsTab> createState() => _MyGroupsTabState();
}

class _MyGroupsTabState extends State<_MyGroupsTab> {
  static const int _pageSize = 10;

  final List<Map<String, dynamic>> _groups = [];
  DocumentSnapshot? _lastDoc;

  bool _loading  = false;
  bool _hasMore  = true;
  bool _initDone = false;

  @override
  void initState() {
    super.initState();
    _fetchNextPage();
  }

  Future<void> _fetchNextPage() async {
    if (_loading || !_hasMore || widget.uid.isEmpty) return;
    setState(() => _loading = true);

    try {
      Query<Map<String, dynamic>> query = FirebaseFirestore.instance
          .collection('organizations')
          .where('submittedBy', isEqualTo: widget.uid)
          .limit(_pageSize);

      if (_lastDoc != null) {
        query = query.startAfterDocument(_lastDoc!);
      }

      final snap = await query.get();

      if (snap.docs.length < _pageSize) _hasMore = false;
      if (snap.docs.isNotEmpty) _lastDoc = snap.docs.last;

      final newGroups = snap.docs
          .map((d) => <String, dynamic>{'_docId': d.id, ...d.data()})
          .toList();

      if (mounted) {
        setState(() {
          _groups.addAll(newGroups);
          _groups.sort((a, b) {
            final ta = a['org_added'];
            final tb = b['org_added'];
            final tA = ta is Timestamp ? ta.millisecondsSinceEpoch : 0;
            final tB = tb is Timestamp ? tb.millisecondsSinceEpoch : 0;
            return tB.compareTo(tA);
          });
          _loading  = false;
          _initDone = true;
        });
      }
    } catch (e) {
      debugPrint('_MyGroupsTab fetch error: $e');
      if (mounted) setState(() { _loading = false; _initDone = true; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initDone && _loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_initDone && _groups.isEmpty) {
      return _EmptyState(
        icon:    Icons.group_rounded,
        message: _t(widget.lang, 'noGroups'),
      );
    }

    final itemCount = _groups.length + (_hasMore || _loading ? 1 : 0);

    return ListView.builder(
      padding:   const EdgeInsets.all(16),
      itemCount: itemCount,
      itemBuilder: (_, i) {
        // ── Footer: spinner or load-more button ─────────────────────────
        if (i == _groups.length) {
          if (_loading) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: GestureDetector(
              onTap: _fetchNextPage,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color:        _D.accentLt,
                  borderRadius: BorderRadius.circular(14),
                  border:       Border.all(color: _D.accentBdr),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.expand_more_rounded, size: 18, color: _D.accent),
                    const SizedBox(width: 6),
                    Text(
                      _t(widget.lang, 'loadMore'),
                      style: TextStyle(
                        fontSize:   13,
                        fontWeight: FontWeight.w700,
                        color:      _D.accent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // ── Group card ──────────────────────────────────────────────────
        final g = _groups[i];
        return _GroupCard(
          groupId: g['_docId'] as String,
          data:    g,
          lang:    widget.lang,
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Group Card
// ─────────────────────────────────────────────────────────────────────────────
class _GroupCard extends StatelessWidget {
  final String groupId, lang;
  final Map<String, dynamic> data;
  const _GroupCard(
      {required this.groupId, required this.data, required this.lang});

  @override
  Widget build(BuildContext context) {
    final isApproved =
        data['org_checked'] == true && data['org_pending_review'] != true;
    final isRejected = data['rejected'] == true;
    final isActive   = data['org_active'] == true;
    final isPublic   = data['org_public'] != false;

    final name = lang == 'ja'
        ? (data['org_name_jp'] ?? data['org_name'] ?? 'Unnamed').toString()
        : (data['org_name'] ?? 'Unnamed').toString();
    final desc = lang == 'ja'
        ? (data['org_description_jp'] ?? data['org_description'] ?? '').toString()
        : (data['org_description'] ?? '').toString();
    final imgUrl = (data['org_image'] ?? '').toString();

    Color sc; Color sb; String sl; IconData si;
    if (isApproved) {
      sc = _D.apprvClr; sb = _D.apprvBg;
      sl = _t(lang, 'approved'); si = Icons.check_circle_rounded;
    } else if (isRejected) {
      sc = _D.rejClr; sb = _D.rejBg;
      sl = _t(lang, 'rejected'); si = Icons.cancel_rounded;
    } else {
      sc = _D.pendClr; sb = _D.pendBg;
      sl = _t(lang, 'pending'); si = Icons.schedule_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _D.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color:      Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset:     const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Cover image with status badges ───────────────────────────
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Stack(children: [
              imgUrl.isNotEmpty
                  ? Image.network(
                imgUrl,
                height: 130,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _grpPlaceholder(),
              )
                  : _grpPlaceholder(),

              // Approval status badge — top-left
              Positioned(
                top:  12,
                left: 12,
                child: _Badge(label: sl, icon: si, color: sc, bg: sb),
              ),

              // Active + Public badges — top-right (approved only)
              if (isApproved)
                Positioned(
                  top:   12,
                  right: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _Badge(
                        label: isActive ? _t(lang, 'active') : _t(lang, 'inactive'),
                        icon:  isActive ? Icons.check_rounded : Icons.close_rounded,
                        color: isActive ? _D.apprvClr : _D.rejClr,
                        bg:    isActive ? _D.apprvBg  : _D.rejBg,
                      ),
                      const SizedBox(height: 4),
                      _Badge(
                        label: isPublic ? _t(lang, 'public') : _t(lang, 'private'),
                        icon:  isPublic ? Icons.public_rounded : Icons.lock_rounded,
                        color: const Color(0xFF1565C0),
                        bg:    const Color(0xFFE3F2FD),
                      ),
                    ],
                  ),
                ),
            ]),
          ),

          // ── Body ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (desc.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    desc,
                    style: TextStyle(
                        fontSize: 13,
                        color:    Colors.grey.shade600,
                        height:   1.4),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                const SizedBox(height: 14),

                // Edit Settings button — always visible
                _ActionButton(
                  icon:  Icons.edit_rounded,
                  label: lang == 'ja' ? 'グループ設定を編集' : 'Edit Settings',
                  color: AppColors.primary,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OrganizerGroupSettingsScreen(
                        groupId:     groupId,
                        initialData: data,
                      ),
                    ),
                  ),
                ),

                // Deactivate / Make Private toggles — approved only
                if (isApproved) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: _OutlineBtn(
                        label: isActive
                            ? (lang == 'ja' ? '非アクティブにする' : 'Deactivate')
                            : (lang == 'ja' ? 'アクティブにする'   : 'Activate'),
                        color: isActive ? _D.rejClr : _D.apprvClr,
                        onTap: () async {
                          await FirebaseFirestore.instance
                              .collection('organizations')
                              .doc(groupId)
                              .update({'org_active': !isActive});
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _OutlineBtn(
                        label: isPublic
                            ? (lang == 'ja' ? '非公開にする' : 'Make Private')
                            : (lang == 'ja' ? '公開する'    : 'Make Public'),
                        color: const Color(0xFF1565C0),
                        onTap: () async {
                          await FirebaseFirestore.instance
                              .collection('organizations')
                              .doc(groupId)
                              .update({'org_public': !isPublic});
                        },
                      ),
                    ),
                  ]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _grpPlaceholder() => Container(
    height: 130,
    width:  double.infinity,
    color:  Colors.grey.shade100,
    child:  Icon(Icons.group_rounded,
        size: 48, color: Colors.grey.shade300),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// TAB 3 — REGISTERED EVENTS  (cursor-based pagination, 10 per page)
// ═════════════════════════════════════════════════════════════════════════════
class _RegisteredTab extends StatefulWidget {
  final String uid, lang;
  const _RegisteredTab({required this.uid, required this.lang});

  @override
  State<_RegisteredTab> createState() => _RegisteredTabState();
}

class _RegisteredTabState extends State<_RegisteredTab> {
  static const int _pageSize = 10;

  // Accumulated pages of resolved {event + reg status} maps
  final List<Map<String, dynamic>> _events = [];

  // Cursor: the last registration doc from the previous page
  DocumentSnapshot? _lastRegDoc;

  bool _loading    = false; // true only while a fetch is in flight
  bool _hasMore    = true;  // false once Firestore returns < _pageSize docs
  bool _initDone   = false; // prevents double-fetch on first build

  @override
  void initState() {
    super.initState();
    _fetchNextPage();
  }

  /// Fetches the next page of registrations then resolves their event docs.
  Future<void> _fetchNextPage() async {
    if (_loading || !_hasMore || widget.uid.isEmpty) return;
    setState(() => _loading = true);

    try {
      // ── 1. Build the registrations query ──────────────────────────────
      // NOTE: No orderBy here — avoids requiring a composite Firestore index.
      // We sort client-side after each page fetch instead.
      Query<Map<String, dynamic>> query = FirebaseFirestore.instance
          .collection('event_registrations')
          .where('user_id', isEqualTo: widget.uid)
          .limit(_pageSize);

      if (_lastRegDoc != null) {
        query = query.startAfterDocument(_lastRegDoc!);
      }

      final regSnap = await query.get();

      // ── 2. Update cursor & hasMore flag ───────────────────────────────
      if (regSnap.docs.length < _pageSize) {
        _hasMore = false;
      }
      if (regSnap.docs.isNotEmpty) {
        _lastRegDoc = regSnap.docs.last;
      }

      // ── 3. Batch-resolve event documents ──────────────────────────────
      final resolved = await Future.wait(
        regSnap.docs.map((regDoc) async {
          final rd   = regDoc.data();
          final evId = (rd['event_id'] ?? '').toString();
          if (evId.isEmpty) return null;
          try {
            final evSnap = await FirebaseFirestore.instance
                .collection('events')
                .doc(evId)
                .get();
            if (!evSnap.exists) return null;
            return <String, dynamic>{
              ...evSnap.data()!,
              '_id':           evSnap.id,
              '_regStatus':    (rd['status'] ?? 'pending').toString(),
              '_regDocId':     regDoc.id,
              '_registeredAt': rd['registered_at'], // keep for sorting
            };
          } catch (_) {
            return null;
          }
        }),
      );

      // ── 4. Append + sort the full accumulated list by date ────────────
      if (mounted) {
        setState(() {
          _events.addAll(resolved.whereType<Map<String, dynamic>>());
          // Sort newest-first across all accumulated pages
          _events.sort((a, b) {
            final ta = a['_registeredAt'];
            final tb = b['_registeredAt'];
            final tA = ta is Timestamp ? ta.millisecondsSinceEpoch : 0;
            final tB = tb is Timestamp ? tb.millisecondsSinceEpoch : 0;
            return tB.compareTo(tA);
          });
          _loading  = false;
          _initDone = true;
        });
      }
    } catch (e) {
      debugPrint('_RegisteredTab fetch error: $e'); // add this temporarily
      if (mounted) setState(() { _loading = false; _initDone = true; });
    }
  }

  @override
  Widget build(BuildContext context) {
    // First load — show a centered spinner
    if (!_initDone && _loading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Empty state (first page came back with nothing)
    if (_initDone && _events.isEmpty) {
      return _EmptyState(
        icon:    Icons.event_available_rounded,
        message: _t(widget.lang, 'noRegistered'),
      );
    }

    // Item count:  all event cards  +  optional footer row
    final itemCount = _events.length + (_hasMore || _loading ? 1 : 0);

    return ListView.builder(
      padding:   const EdgeInsets.all(16),
      itemCount: itemCount,
      itemBuilder: (_, i) {
        // ── Footer: load-more button or in-page spinner ──────────────────
        if (i == _events.length) {
          if (_loading) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          // "Load more" button
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: GestureDetector(
              onTap: _fetchNextPage,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color:        _D.accentLt,
                  borderRadius: BorderRadius.circular(14),
                  border:       Border.all(color: _D.accentBdr),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.expand_more_rounded,
                        size: 18, color: _D.accent),
                    const SizedBox(width: 6),
                    Text(
                      _t(widget.lang, 'loadMore'),
                      style: TextStyle(
                        fontSize:   13,
                        fontWeight: FontWeight.w700,
                        color:      _D.accent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // ── Event card (unchanged visual) ────────────────────────────────
        final ev     = _events[i];
        final status = (ev['_regStatus'] ?? 'pending').toString();
        final title  = widget.lang == 'ja'
            ? (ev['event_title_jp'] ?? ev['event_title'] ?? 'Untitled').toString()
            : (ev['event_title'] ?? 'Untitled').toString();
        final imgUrl = (ev['event_pic'] ?? '').toString();
        final date   = _fmtDate(ev['event_date'], compact: true);

        Color sc; String sl; IconData si;
        if (status == 'approved') {
          sc = _D.apprvClr; sl = _t(widget.lang, 'regApproved'); si = Icons.check_circle_rounded;
        } else if (status == 'rejected') {
          sc = _D.rejClr;   sl = _t(widget.lang, 'regRejected'); si = Icons.cancel_rounded;
        } else {
          sc = _D.pendClr;  sl = _t(widget.lang, 'regPending');  si = Icons.schedule_rounded;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color:        _D.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color:      Colors.black.withOpacity(0.05),
                blurRadius: 14,
                offset:     const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                  ),
                  child: imgUrl.isNotEmpty
                      ? Image.network(imgUrl,
                      width: 100, height: 90, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _thumbPh())
                      : _thumbPh(),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w700),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 5),
                        Row(children: [
                          Icon(Icons.calendar_today_rounded,
                              size: 12, color: Colors.grey.shade400),
                          const SizedBox(width: 4),
                          Text(date,
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade500)),
                        ]),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color:        sc.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(si, size: 11, color: sc),
                            const SizedBox(width: 4),
                            Text(sl,
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: sc)),
                          ]),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ]),

              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => EventDetailScreen(event: ev),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _D.accent,
                      side:            const BorderSide(color: _D.accentBdr),
                      backgroundColor: _D.accentLt,
                      padding:         const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon:  const Icon(Icons.visibility_outlined, size: 16),
                    label: Text(
                      _t(widget.lang, 'viewDetails'),
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _thumbPh() => Container(
    width:  100,
    height: 90,
    color:  Colors.grey.shade100,
    child:  Icon(Icons.event_rounded,
        size: 32, color: Colors.grey.shade300),
  );
}
// ═════════════════════════════════════════════════════════════════════════════
// TAB 4 — AUDIT LOG  (cursor-based pagination, 20 per page)
// ═════════════════════════════════════════════════════════════════════════════
class _AuditLogTab extends StatefulWidget {
  final String uid, lang;
  const _AuditLogTab({required this.uid, required this.lang});

  @override
  State<_AuditLogTab> createState() => _AuditLogTabState();
}

class _AuditLogTabState extends State<_AuditLogTab> {
  static const int _pageSize = 20;

  final List<Map<String, dynamic>> _logs = [];
  DocumentSnapshot? _lastDoc;

  bool _loading  = false;
  bool _hasMore  = true;
  bool _initDone = false;

  @override
  void initState() {
    super.initState();
    _fetchNextPage();
  }

  Future<void> _fetchNextPage() async {
    if (_loading || !_hasMore || widget.uid.isEmpty) return;
    setState(() => _loading = true);

    try {
      // No orderBy → no composite index required; we sort client-side.
      Query<Map<String, dynamic>> query = FirebaseFirestore.instance
          .collection('audit_logs')
          .where('actor_id', isEqualTo: widget.uid)
          .limit(_pageSize);

      if (_lastDoc != null) {
        query = query.startAfterDocument(_lastDoc!);
      }

      final snap = await query.get();

      if (snap.docs.length < _pageSize) _hasMore = false;
      if (snap.docs.isNotEmpty) _lastDoc = snap.docs.last;

      final newLogs = snap.docs
          .map((d) => <String, dynamic>{'_id': d.id, ...d.data()})
          .toList();

      if (mounted) {
        setState(() {
          _logs.addAll(newLogs);
          // Sort newest-first across all accumulated pages
          _logs.sort((a, b) {
            final ta = a['timestamp'];
            final tb = b['timestamp'];
            final tA = ta is Timestamp ? ta.millisecondsSinceEpoch : 0;
            final tB = tb is Timestamp ? tb.millisecondsSinceEpoch : 0;
            return tB.compareTo(tA);
          });
          _loading  = false;
          _initDone = true;
        });
      }
    } catch (e) {
      debugPrint('_AuditLogTab fetch error: $e');
      if (mounted) setState(() { _loading = false; _initDone = true; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initDone && _loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_initDone && _logs.isEmpty) {
      return _EmptyState(
        icon:    Icons.history_rounded,
        message: _t(widget.lang, 'noAudit'),
      );
    }

    final itemCount = _logs.length + (_hasMore || _loading ? 1 : 0);

    return ListView.builder(
      padding:   const EdgeInsets.all(16),
      itemCount: itemCount,
      itemBuilder: (_, i) {
        // ── Footer ──────────────────────────────────────────────────────
        if (i == _logs.length) {
          if (_loading) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: GestureDetector(
              onTap: _fetchNextPage,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color:        _D.accentLt,
                  borderRadius: BorderRadius.circular(14),
                  border:       Border.all(color: _D.accentBdr),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.expand_more_rounded, size: 18, color: _D.accent),
                    const SizedBox(width: 6),
                    Text(
                      _t(widget.lang, 'loadMore'),
                      style: TextStyle(
                        fontSize:   13,
                        fontWeight: FontWeight.w700,
                        color:      _D.accent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // ── Log row ─────────────────────────────────────────────────────
        final d    = _logs[i];
        final meta = _auditMeta((d['action'] ?? '').toString(), widget.lang);
        final date = _fmtDate(d['timestamp'], compact: true);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _D.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color:      Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset:     const Offset(0, 3),
              ),
            ],
          ),
          child: Row(children: [
            Container(
              width:  38,
              height: 38,
              decoration: BoxDecoration(
                color:        (meta['color'] as Color).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(meta['icon'] as IconData,
                  size: 18, color: meta['color'] as Color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(meta['label'] as String,
                      style: TextStyle(
                          fontSize:      11,
                          fontWeight:    FontWeight.w700,
                          color:         meta['color'] as Color,
                          letterSpacing: 0.3)),
                  Text((d['target_name'] ?? '').toString(),
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  if ((d['details'] ?? '').toString().isNotEmpty)
                    Text((d['details'] ?? '').toString(),
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade500),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(date,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
          ]),
        );
      },
    );
  }

  Map<String, dynamic> _auditMeta(String action, String lang) {
    switch (action) {
      case 'broadcast':
        return {'color': AppColors.primary, 'icon': Icons.campaign_rounded,
          'label': lang == 'ja' ? '一斉送信' : 'Broadcast'};
      case 'replies_on':
        return {'color': AppColors.primary, 'icon': Icons.chat_rounded,
          'label': lang == 'ja' ? '返信有効化' : 'Replies On'};
      case 'replies_off':
        return {'color': _D.pendClr, 'icon': Icons.do_not_disturb_rounded,
          'label': lang == 'ja' ? '返信無効化' : 'Replies Off'};
      case 'channel_created':
        return {'color': const Color(0xFF1565C0), 'icon': Icons.add_comment_rounded,
          'label': lang == 'ja' ? 'チャンネル作成' : 'Channel Created'};
      case 'chat_cleared':
        return {'color': _D.rejClr, 'icon': Icons.delete_sweep_rounded,
          'label': lang == 'ja' ? 'チャット消去' : 'Chat Cleared'};
      case 'event_edited':
        return {'color': const Color(0xFF7B1FA2), 'icon': Icons.edit_rounded,
          'label': lang == 'ja' ? 'イベント編集' : 'Event Edited'};
      case 'participant_removed':
        return {'color': _D.rejClr, 'icon': Icons.person_remove_rounded,
          'label': lang == 'ja' ? '参加者削除' : 'Participant Removed'};
      case 'reg_approved':
        return {'color': AppColors.primary, 'icon': Icons.how_to_reg_rounded,
          'label': lang == 'ja' ? '登録承認' : 'Reg Approved'};
      case 'reg_rejected':
        return {'color': _D.rejClr, 'icon': Icons.person_off_rounded,
          'label': lang == 'ja' ? '登録却下' : 'Reg Rejected'};
      default:
        return {'color': Colors.grey.shade600, 'icon': Icons.history_rounded,
          'label': action};
    }
  }
}
// ═════════════════════════════════════════════════════════════════════════════
// Shared small widgets
// ═════════════════════════════════════════════════════════════════════════════

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
                color: Colors.grey.shade100, shape: BoxShape.circle),
            child: Icon(icon, size: 36, color: Colors.grey.shade400)),
        const SizedBox(height: 16),
        Text(message,
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade500),
            textAlign: TextAlign.center),
      ]),
    ),
  );
}

class _Badge extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color, bg;
  const _Badge(
      {required this.label,
        required this.icon,
        required this.color,
        required this.bg});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 11, color: color),
      const SizedBox(width: 4),
      Text(label,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w700, color: color)),
    ]),
  );
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
        color: _D.rowBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _D.border)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: Colors.grey.shade500),
      const SizedBox(width: 5),
      Text(label,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700)),
    ]),
  );
}

class _MetricPill extends StatelessWidget {
  final IconData icon;
  final int value;
  final String label;
  final Color color;
  const _MetricPill(
      {required this.icon,
        required this.value,
        required this.label,
        required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Row(children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 6),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$value',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: color)),
        Text(label,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color.withOpacity(0.7))),
      ]),
    ]),
  );
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool outlined;
  final VoidCallback onTap;
  const _ActionButton(
      {required this.icon,
        required this.label,
        required this.color,
        required this.onTap,
        this.outlined = false});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: outlined ? Colors.transparent : color,
        borderRadius: BorderRadius.circular(12),
        border: outlined ? Border.all(color: color, width: 1.5) : null,
      ),
      alignment: Alignment.center,
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 16, color: outlined ? color : Colors.white),
        const SizedBox(width: 7),
        Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: outlined ? color : Colors.white)),
      ]),
    ),
  );
}

class _OutlineBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _OutlineBtn(
      {required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
          border: Border.all(color: color, width: 1.5),
          borderRadius: BorderRadius.circular(10)),
      alignment: Alignment.center,
      child: Text(label,
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700, color: color)),
    ),
  );
}

class _StatBadge extends StatelessWidget {
  final String label;
  final Color color, bg, border;
  const _StatBadge(this.label, this.color, this.bg, this.border);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border.withOpacity(0.4))),
    child: Text(label,
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w800, color: color)),
  );
}

class _FilterTab extends StatelessWidget {
  final String label, value, current;
  final ValueChanged<String> onTap;
  const _FilterTab(
      {required this.label,
        required this.value,
        required this.current,
        required this.onTap});

  @override
  Widget build(BuildContext context) {
    final selected = value == current;
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? _D.tabSelBg : _D.tabUnselBg,
          borderRadius: BorderRadius.circular(10),
          border:
          Border.all(color: selected ? _D.tabSelBdr : _D.tabUnselBdr),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: selected ? _D.accent : _D.textMuted)),
      ),
    );
  }
}

class _ABtn extends StatelessWidget {
  final String label;
  final Color color, bg;
  final VoidCallback onTap;
  const _ABtn(
      {required this.label,
        required this.color,
        required this.bg,
        required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w800, color: color)),
    ),
  );
}

class _SheetField extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final int maxLines;
  final TextInputType keyboardType;
  const _SheetField(
      {required this.label,
        required this.ctrl,
        this.maxLines = 1,
        this.keyboardType = TextInputType.text});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600)),
      const SizedBox(height: 6),
      TextField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          filled: true,
          fillColor: _D.rowBg,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
              BorderSide(color: AppColors.primary, width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 12),
        ),
      ),
    ],
  );
}
