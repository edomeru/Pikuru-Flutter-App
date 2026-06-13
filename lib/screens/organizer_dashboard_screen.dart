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

  // Matching events_screen refresh colors
  static const refreshGreen = Color(0xFF3A7D44);
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
    'analytics':    'Analytics',
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
    'searchEvents': 'Search events…',
    'searchGroups': 'Search groups…',
    'searchRegistered': 'Search registered events…',
    'searchAudit':  'Search audit log…',
    'noResults':    'No events match your search.',
    'noGroupResults': 'No groups match your search.',
    'noRegisteredResults': 'No registered events match your search.',
    'noAuditResults': 'No audit entries match your search.',
    // Analytics
    'analyticsTitle':       'Performance Analytics',
    'analyticsSub':         'Track views, registrations, and conversions for your events.',
    'totalViews':           'Total Impressions',
    'totalRegistrations':   'Total Registrations',
    'avgViews':             'Avg. Event Views',
    'conversionRate':       'Conversion Rate',
    'searchEventsAnalytics':'Search events…',
    'sortBy':               'Sort By',
    'sortMostViewed':       'Most Viewed',
    'sortMostRegistered':   'Most Registered',
    'sortConversion':       'Conversion Rate',
    'sortNewest':           'Newest',
    'viewsLabel':           'views',
    'registrationsLabel':   'registrations',
    'conversionLabel':      'conversion',
    'noEventsAnalytics':    'No events found to analyze.',
    'viewEvent':            'View Details',
    'slotsFilled':          'slots filled',
    'page':                 'Page',
    'of':                   'of',
    'prev':                 'Prev',
    'next':                 'Next',
    'approved2':            'approved',
  },
  kLangJa: {
    'title':        'オーガナイザーダッシュボード',
    'sub':          'イベント・グループ・登録を管理しましょう。',
    'myEvents':     'マイイベント',
    'myGroups':     'マイグループ',
    'registered':   '登録済み',
    'auditLog':     '監査ログ',
    'analytics':    '分析・統計',
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
    'searchEvents': 'イベントを検索…',
    'searchGroups': 'グループを検索…',
    'searchRegistered': '登録済みイベントを検索…',
    'searchAudit':  '監査ログを検索…',
    'noResults':    '検索結果がありません。',
    'noGroupResults': '検索結果がありません。',
    'noRegisteredResults': '検索結果がありません。',
    'noAuditResults': '検索結果がありません。',
    // Analytics
    'analyticsTitle':       'パフォーマンス分析',
    'analyticsSub':         'イベントの閲覧数、登録者数、転換率を追跡します。',
    'totalViews':           '総インプレッション数',
    'totalRegistrations':   '総登録数',
    'avgViews':             '平均イベント閲覧数',
    'conversionRate':       '転換率',
    'searchEventsAnalytics':'イベントを検索…',
    'sortBy':               '並び替え',
    'sortMostViewed':       '閲覧数順',
    'sortMostRegistered':   '登録数順',
    'sortConversion':       '転換率順',
    'sortNewest':           '新着順',
    'viewsLabel':           '回閲覧',
    'registrationsLabel':   '登録数',
    'conversionLabel':      '転換率',
    'noEventsAnalytics':    '分析対象のイベントが見つかりません。',
    'viewEvent':            '詳細を見る',
    'slotsFilled':          '枠埋まり',
    'page':                 'ページ',
    'of':                   '/',
    'prev':                 '前へ',
    'next':                 '次へ',
    'approved2':            '承認済み',
  },
};

String _t(String lang, String key) =>
    _L[lang]?[key] ?? _L[kLangEn]![key]!;

// ─────────────────────────────────────────────────────────────────────────────
// Date helpers
// ─────────────────────────────────────────────────────────────────────────────
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
// Sort enum for analytics
// ─────────────────────────────────────────────────────────────────────────────
enum _AnalyticsSort { views, registrations, conversion, newest }

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

  // Shared refresh key — incrementing this triggers all tabs to re-init
  int _globalRefreshKey = 0;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
    _tabs.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  // Refresh all tabs by bumping the shared key
  Future<void> _refreshAll() async {
    setState(() => _globalRefreshKey++);
    await Future.delayed(const Duration(milliseconds: 600));
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
                Tab(text: _t(lang, 'analytics')),
                Tab(text: _t(lang, 'auditLog')),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _MyEventsTab(uid: uid, lang: lang, refreshKey: _globalRefreshKey, onRefreshAll: _refreshAll),
          _MyGroupsTab(uid: uid, lang: lang, refreshKey: _globalRefreshKey, onRefreshAll: _refreshAll),
          _RegisteredTab(uid: uid, lang: lang, refreshKey: _globalRefreshKey, onRefreshAll: _refreshAll),
          _AnalyticsTab(uid: uid, lang: lang, refreshKey: _globalRefreshKey, onRefreshAll: _refreshAll),
          _AuditLogTab(uid: uid, lang: lang, refreshKey: _globalRefreshKey, onRefreshAll: _refreshAll),
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
  final int refreshKey;
  final Future<void> Function() onRefreshAll;
  const _MyEventsTab({
    required this.uid,
    required this.lang,
    required this.refreshKey,
    required this.onRefreshAll,
  });

  @override
  State<_MyEventsTab> createState() => _MyEventsTabState();
}

class _MyEventsTabState extends State<_MyEventsTab> {
  final Map<String, Map<String, int>> _metrics = {};

  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  // Key to force StreamBuilder rebuild on refresh
  int _streamKey = 0;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() => _query = _searchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void didUpdateWidget(_MyEventsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshKey != widget.refreshKey) {
      setState(() {
        _streamKey++;
        _metrics.clear();
      });
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

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

  bool _matchesQuery(Map<String, dynamic> data) {
    if (_query.isEmpty) return true;
    final titleEn = (data['event_title']    ?? '').toString().toLowerCase();
    final titleJp = (data['event_title_jp'] ?? '').toString().toLowerCase();
    return titleEn.contains(_query) || titleJp.contains(_query);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.uid.isEmpty) return const SizedBox.shrink();
    return StreamBuilder<QuerySnapshot>(
      key: ValueKey(_streamKey),
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

        final filtered = docs.where((d) =>
            _matchesQuery(d.data() as Map<String, dynamic>)).toList();

        return Column(
          children: [
            // Search bar
            Container(
              color: _D.white,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                  color: _D.rowBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _D.border),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: _D.textPri),
                  decoration: InputDecoration(
                    hintText: _t(widget.lang, 'searchEvents'),
                    hintStyle: const TextStyle(
                        fontSize: 14,
                        color: _D.textDim,
                        fontWeight: FontWeight.w400),
                    prefixIcon: const Icon(
                        Icons.search_rounded,
                        size: 20,
                        color: _D.textMuted),
                    suffixIcon: _query.isNotEmpty
                        ? GestureDetector(
                      onTap: () => _searchCtrl.clear(),
                      child: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: _D.textMuted),
                    )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                ),
              ),
            ),

            Expanded(
              child: () {
                if (docs.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: widget.onRefreshAll,
                    color: _D.refreshGreen,
                    backgroundColor: Colors.white,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: SizedBox(
                        height: 400,
                        child: _EmptyState(
                            icon: Icons.event_note_rounded,
                            message: _t(widget.lang, 'noEvents')),
                      ),
                    ),
                  );
                }
                if (filtered.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: widget.onRefreshAll,
                    color: _D.refreshGreen,
                    backgroundColor: Colors.white,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: SizedBox(
                        height: 400,
                        child: _EmptyState(
                            icon: Icons.search_off_rounded,
                            message: _t(widget.lang, 'noResults')),
                      ),
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: widget.onRefreshAll,
                  color: _D.refreshGreen,
                  backgroundColor: Colors.white,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) {
                      final data = filtered[i].data() as Map<String, dynamic>;
                      return _EventCard(
                        eventId: filtered[i].id,
                        data:    data,
                        lang:    widget.lang,
                        metrics: _metrics[filtered[i].id],
                      );
                    },
                  ),
                );
              }(),
            ),
          ],
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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
// Registrants Modal
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
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),

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
                  width: 34, height: 34,
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

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _StatBadge(
                    '${_t('regTotal')}: $_total${_hasMore ? '+' : ''}',
                    _D.textMuted, _D.rowBg, _D.border),
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

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _FilterTab(label: _t('regAll'), value: 'all',
                    current: _filter, onTap: (v) => setState(() => _filter = v)),
                const SizedBox(width: 6),
                _FilterTab(label: '${_t('regPending')} ($_pendCnt)',
                    value: 'pending', current: _filter,
                    onTap: (v) => setState(() => _filter = v)),
                const SizedBox(width: 6),
                _FilterTab(label: '${_t('regApproved')} ($_appCnt)',
                    value: 'approved', current: _filter,
                    onTap: (v) => setState(() => _filter = v)),
                const SizedBox(width: 6),
                _FilterTab(label: '${_t('regRejected')} ($_rejCnt)',
                    value: 'rejected', current: _filter,
                    onTap: (v) => setState(() => _filter = v)),
              ]),
            ),
          ),

          const SizedBox(height: 4),
          const Divider(height: 1, color: _D.border),

          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: _D.accent))
                : _filtered.isEmpty
                ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 60, height: 60,
                  decoration: BoxDecoration(
                      color: _D.accentLt, shape: BoxShape.circle),
                  child: Icon(Icons.people_outline_rounded,
                      size: 28, color: _D.accent.withOpacity(0.5)),
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
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: _filtered.length +
                  (_hasMore && _filter == 'all' ? 1 : 0),
              itemBuilder: (_, i) {
                if (i == _filtered.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: GestureDetector(
                      onTap: () => _openFullList(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: _D.accentLt,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _D.accentBdr),
                        ),
                        alignment: Alignment.center,
                        child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.people_rounded,
                                  size: 15, color: _D.accent),
                              const SizedBox(width: 6),
                              Text(_t('seeMore'),
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: _D.accent)),
                              const SizedBox(width: 4),
                              Icon(Icons.arrow_forward_ios_rounded,
                                  size: 12, color: _D.accent),
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
                  onApprove:  () => _updateStatus(r['_id'] as String, 'approved'),
                  onReject:   () => _updateStatus(r['_id'] as String, 'rejected'),
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
// _RegRow
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
    final dateStr = _fmtRegDate(reg['registered_at'], lang);

    Color sc; Color sb; String sl;
    switch (status) {
      case 'approved':
        sc = _D.apprvClr; sb = _D.apprvBg; sl = _t('regApproved'); break;
      case 'rejected':
        sc = _D.rejClr; sb = _D.rejBg; sl = _t('regRejected'); break;
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
        CircleAvatar(
          radius: 22,
          backgroundColor: _D.accentLt,
          backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
          child: avatar.isEmpty
              ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(
                  color: _D.accent,
                  fontWeight: FontWeight.w800,
                  fontSize: 15))
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700, color: _D.textPri),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            if (email.isNotEmpty)
              Text(email,
                  style: const TextStyle(fontSize: 12, color: _D.textMuted),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 5),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: sb, borderRadius: BorderRadius.circular(20)),
                child: Text(sl,
                    style: TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w800, color: sc)),
              ),
              if (dateStr.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(dateStr,
                    style: const TextStyle(
                        fontSize: 11, color: _D.textDim, fontWeight: FontWeight.w500)),
              ],
            ]),
          ]),
        ),
        const SizedBox(width: 10),
        if (isUpdating)
          SizedBox(
              width: 22, height: 22,
              child: CircularProgressIndicator(color: _D.accent, strokeWidth: 2.5))
        else
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            if (status != 'approved')
              _ABtn(label: _t('approve'), color: _D.apprvClr, bg: _D.apprvBg, onTap: onApprove),
            if (status != 'rejected') ...[
              if (status != 'approved') const SizedBox(height: 6),
              _ABtn(label: _t('reject'), color: _D.rejClr, bg: _D.rejBg, onTap: onReject),
            ],
          ]),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Edit dialog
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
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                    child: Container(
                        width: 40, height: 4,
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
                          'event_title':          titleCtrl.text.trim(),
                          'event_description_en': descCtrl.text.trim(),
                          'event_fee':            feeCtrl.text.trim(),
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
// TAB 2 — MY GROUPS
// ═════════════════════════════════════════════════════════════════════════════
class _MyGroupsTab extends StatefulWidget {
  final String uid, lang;
  final int refreshKey;
  final Future<void> Function() onRefreshAll;
  const _MyGroupsTab({
    required this.uid,
    required this.lang,
    required this.refreshKey,
    required this.onRefreshAll,
  });

  @override
  State<_MyGroupsTab> createState() => _MyGroupsTabState();
}

class _MyGroupsTabState extends State<_MyGroupsTab> {
  static const int _pageSize = 10;

  List<Map<String, dynamic>> _groups = [];
  DocumentSnapshot? _lastDoc;

  bool _loading  = false;
  bool _hasMore  = true;
  bool _initDone = false;

  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _fetchNextPage();
    _searchCtrl.addListener(() {
      setState(() => _query = _searchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void didUpdateWidget(_MyGroupsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshKey != widget.refreshKey) {
      _resetAndFetch();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _resetAndFetch() async {
    setState(() {
      _groups   = [];
      _lastDoc  = null;
      _hasMore  = true;
      _initDone = false;
      _loading  = false;
    });
    await _fetchNextPage();
  }

  bool _matchesQuery(Map<String, dynamic> data) {
    if (_query.isEmpty) return true;
    final nameEn = (data['org_name']    ?? '').toString().toLowerCase();
    final nameJp = (data['org_name_jp'] ?? '').toString().toLowerCase();
    final descEn = (data['org_description']    ?? '').toString().toLowerCase();
    final descJp = (data['org_description_jp'] ?? '').toString().toLowerCase();
    return nameEn.contains(_query) || nameJp.contains(_query) ||
        descEn.contains(_query) || descJp.contains(_query);
  }

  Future<void> _fetchNextPage() async {
    if (_loading || !_hasMore || widget.uid.isEmpty) return;
    setState(() => _loading = true);

    try {
      Query<Map<String, dynamic>> query = FirebaseFirestore.instance
          .collection('organizations')
          .where('submittedBy', isEqualTo: widget.uid)
          .limit(_pageSize);

      if (_lastDoc != null) query = query.startAfterDocument(_lastDoc!);

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

  void _patchGroup(String docId, Map<String, dynamic> patch) {
    final i = _groups.indexWhere((g) => g['_docId'] == docId);
    if (i != -1) setState(() => _groups[i] = {..._groups[i], ...patch});
  }

  @override
  Widget build(BuildContext context) {
    if (!_initDone && _loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final filtered = _groups.where(_matchesQuery).toList();
    final showLoadMore = _hasMore || _loading;
    final itemCount = filtered.length + (showLoadMore && _query.isEmpty ? 1 : 0);

    if (_initDone && _groups.isEmpty) {
      return Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: widget.onRefreshAll,
              color: _D.refreshGreen,
              backgroundColor: Colors.white,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: 400,
                  child: _EmptyState(
                      icon: Icons.group_rounded,
                      message: _t(widget.lang, 'noGroups')),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        _buildSearchBar(),
        Expanded(
          child: () {
            if (filtered.isEmpty) {
              return RefreshIndicator(
                onRefresh: widget.onRefreshAll,
                color: _D.refreshGreen,
                backgroundColor: Colors.white,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: SizedBox(
                    height: 400,
                    child: _EmptyState(
                        icon: Icons.search_off_rounded,
                        message: _t(widget.lang, 'noGroupResults')),
                  ),
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: widget.onRefreshAll,
              color: _D.refreshGreen,
              backgroundColor: Colors.white,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: itemCount,
                itemBuilder: (_, i) {
                  if (i == filtered.length) {
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
                            color: _D.accentLt,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: _D.accentBdr),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.expand_more_rounded, size: 18, color: _D.accent),
                              const SizedBox(width: 6),
                              Text(_t(widget.lang, 'loadMore'),
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: _D.accent)),
                            ],
                          ),
                        ),
                      ),
                    );
                  }
                  final g = filtered[i];
                  return _GroupCard(
                    groupId:   g['_docId'] as String,
                    data:      g,
                    lang:      widget.lang,
                    onPatched: (patch) => _patchGroup(g['_docId'] as String, patch),
                  );
                },
              ),
            );
          }(),
        ),
      ],
    );
  }

  Widget _buildSearchBar() => Container(
    color: _D.white,
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
    child: Container(
      height: 42,
      decoration: BoxDecoration(
        color: _D.rowBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _D.border),
      ),
      child: TextField(
        controller: _searchCtrl,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: _D.textPri),
        decoration: InputDecoration(
          hintText: _t(widget.lang, 'searchGroups'),
          hintStyle: const TextStyle(fontSize: 14, color: _D.textDim, fontWeight: FontWeight.w400),
          prefixIcon: const Icon(Icons.search_rounded, size: 20, color: _D.textMuted),
          suffixIcon: _query.isNotEmpty
              ? GestureDetector(
              onTap: () => _searchCtrl.clear(),
              child: const Icon(Icons.close_rounded, size: 18, color: _D.textMuted))
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 11),
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Group Card
// ─────────────────────────────────────────────────────────────────────────────
class _GroupCard extends StatelessWidget {
  final String groupId, lang;
  final Map<String, dynamic> data;
  final void Function(Map<String, dynamic> patch) onPatched;

  const _GroupCard({
    required this.groupId,
    required this.data,
    required this.lang,
    required this.onPatched,
  });

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
          BoxShadow(color: Colors.black.withOpacity(0.06),
              blurRadius: 16, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: Stack(children: [
            imgUrl.isNotEmpty
                ? Image.network(imgUrl,
                height: 130, width: double.infinity, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _grpPlaceholder())
                : _grpPlaceholder(),
            Positioned(top: 12, left: 12,
                child: _Badge(label: sl, icon: si, color: sc, bg: sb)),
            if (isApproved)
              Positioned(
                top: 12, right: 12,
                child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
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
                ]),
              ),
          ]),
        ),

        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            if (desc.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(desc,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.4),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
            ],

            const SizedBox(height: 14),

            _ActionButton(
              icon:  Icons.edit_rounded,
              label: lang == 'ja' ? 'グループ設定を編集' : 'Edit Settings',
              color: AppColors.primary,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => OrganizerGroupSettingsScreen(
                      groupId: groupId, initialData: data),
                ),
              ),
            ),

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
                      final newVal = !isActive;
                      await FirebaseFirestore.instance
                          .collection('organizations').doc(groupId)
                          .update({'org_active': newVal});
                      onPatched({'org_active': newVal});
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
                      final newVal = !isPublic;
                      await FirebaseFirestore.instance
                          .collection('organizations').doc(groupId)
                          .update({'org_public': newVal});
                      onPatched({'org_public': newVal});
                    },
                  ),
                ),
              ]),
            ],
          ]),
        ),
      ]),
    );
  }

  Widget _grpPlaceholder() => Container(
    height: 130, width: double.infinity,
    color: Colors.grey.shade100,
    child: Icon(Icons.group_rounded, size: 48, color: Colors.grey.shade300),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// TAB 3 — REGISTERED EVENTS
// ═════════════════════════════════════════════════════════════════════════════
class _RegisteredTab extends StatefulWidget {
  final String uid, lang;
  final int refreshKey;
  final Future<void> Function() onRefreshAll;
  const _RegisteredTab({
    required this.uid,
    required this.lang,
    required this.refreshKey,
    required this.onRefreshAll,
  });

  @override
  State<_RegisteredTab> createState() => _RegisteredTabState();
}

class _RegisteredTabState extends State<_RegisteredTab> {
  static const int _pageSize = 10;

  List<Map<String, dynamic>> _events = [];
  DocumentSnapshot? _lastRegDoc;

  bool _loading  = false;
  bool _hasMore  = true;
  bool _initDone = false;

  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _fetchNextPage();
    _searchCtrl.addListener(() {
      setState(() => _query = _searchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void didUpdateWidget(_RegisteredTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshKey != widget.refreshKey) {
      _resetAndFetch();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _resetAndFetch() async {
    setState(() {
      _events     = [];
      _lastRegDoc = null;
      _hasMore    = true;
      _initDone   = false;
      _loading    = false;
    });
    await _fetchNextPage();
  }

  bool _matchesQuery(Map<String, dynamic> ev) {
    if (_query.isEmpty) return true;
    final titleEn = (ev['event_title']    ?? '').toString().toLowerCase();
    final titleJp = (ev['event_title_jp'] ?? '').toString().toLowerCase();
    return titleEn.contains(_query) || titleJp.contains(_query);
  }

  Future<void> _fetchNextPage() async {
    if (_loading || !_hasMore || widget.uid.isEmpty) return;
    setState(() => _loading = true);

    try {
      Query<Map<String, dynamic>> query = FirebaseFirestore.instance
          .collection('event_registrations')
          .where('user_id', isEqualTo: widget.uid)
          .limit(_pageSize);

      if (_lastRegDoc != null) query = query.startAfterDocument(_lastRegDoc!);

      final regSnap = await query.get();

      if (regSnap.docs.length < _pageSize) _hasMore = false;
      if (regSnap.docs.isNotEmpty) _lastRegDoc = regSnap.docs.last;

      final resolved = await Future.wait(
        regSnap.docs.map((regDoc) async {
          final rd   = regDoc.data();
          final evId = (rd['event_id'] ?? '').toString();
          if (evId.isEmpty) return null;
          try {
            final evSnap = await FirebaseFirestore.instance
                .collection('events').doc(evId).get();
            if (!evSnap.exists) return null;
            return <String, dynamic>{
              ...evSnap.data()!,
              '_id':           evSnap.id,
              '_regStatus':    (rd['status'] ?? 'pending').toString(),
              '_regDocId':     regDoc.id,
              '_registeredAt': rd['registered_at'],
            };
          } catch (_) { return null; }
        }),
      );

      if (mounted) {
        setState(() {
          _events.addAll(resolved.whereType<Map<String, dynamic>>());
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
      debugPrint('_RegisteredTab fetch error: $e');
      if (mounted) setState(() { _loading = false; _initDone = true; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initDone && _loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final filtered     = _events.where(_matchesQuery).toList();
    final showLoadMore = _hasMore || _loading;
    final itemCount    = filtered.length + (showLoadMore && _query.isEmpty ? 1 : 0);

    if (_initDone && _events.isEmpty) {
      return Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: widget.onRefreshAll,
              color: _D.refreshGreen,
              backgroundColor: Colors.white,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: 400,
                  child: _EmptyState(
                      icon: Icons.event_available_rounded,
                      message: _t(widget.lang, 'noRegistered')),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        _buildSearchBar(),
        Expanded(
          child: () {
            if (filtered.isEmpty) {
              return RefreshIndicator(
                onRefresh: widget.onRefreshAll,
                color: _D.refreshGreen,
                backgroundColor: Colors.white,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: SizedBox(
                    height: 400,
                    child: _EmptyState(
                        icon: Icons.search_off_rounded,
                        message: _t(widget.lang, 'noRegisteredResults')),
                  ),
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: widget.onRefreshAll,
              color: _D.refreshGreen,
              backgroundColor: Colors.white,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: itemCount,
                itemBuilder: (_, i) {
                  if (i == filtered.length) {
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
                            color: _D.accentLt,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: _D.accentBdr),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.expand_more_rounded, size: 18, color: _D.accent),
                              const SizedBox(width: 6),
                              Text(_t(widget.lang, 'loadMore'),
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: _D.accent)),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  final ev     = filtered[i];
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
                      color: _D.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.05),
                            blurRadius: 14, offset: const Offset(0, 3)),
                      ],
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Row(children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(18)),
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
                                      maxLines: 2, overflow: TextOverflow.ellipsis),
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
                                        color: sc.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8)),
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
                                ]),
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
                                  builder: (_) => EventDetailScreen(event: ev)),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _D.accent,
                              side: const BorderSide(color: _D.accentBdr),
                              backgroundColor: _D.accentLt,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.visibility_outlined, size: 16),
                            label: Text(_t(widget.lang, 'viewDetails'),
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ),
                    ]),
                  );
                },
              ),
            );
          }(),
        ),
      ],
    );
  }

  Widget _buildSearchBar() => Container(
    color: _D.white,
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
    child: Container(
      height: 42,
      decoration: BoxDecoration(
          color: _D.rowBg, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _D.border)),
      child: TextField(
        controller: _searchCtrl,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: _D.textPri),
        decoration: InputDecoration(
          hintText: _t(widget.lang, 'searchRegistered'),
          hintStyle: const TextStyle(fontSize: 14, color: _D.textDim, fontWeight: FontWeight.w400),
          prefixIcon: const Icon(Icons.search_rounded, size: 20, color: _D.textMuted),
          suffixIcon: _query.isNotEmpty
              ? GestureDetector(onTap: () => _searchCtrl.clear(),
              child: const Icon(Icons.close_rounded, size: 18, color: _D.textMuted))
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 11),
        ),
      ),
    ),
  );

  Widget _thumbPh() => Container(
    width: 100, height: 90, color: Colors.grey.shade100,
    child: Icon(Icons.event_rounded, size: 32, color: Colors.grey.shade300),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// TAB 4 — ANALYTICS
// ═════════════════════════════════════════════════════════════════════════════
class _AnalyticsTab extends StatefulWidget {
  final String uid, lang;
  final int refreshKey;
  final Future<void> Function() onRefreshAll;

  const _AnalyticsTab({
    required this.uid,
    required this.lang,
    required this.refreshKey,
    required this.onRefreshAll,
  });

  @override
  State<_AnalyticsTab> createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends State<_AnalyticsTab> {
  // All organizer events (raw, from Firestore)
  List<Map<String, dynamic>> _events = [];
  bool _eventsLoading = true;
  int _streamKey = 0;

  // Per-event registration metrics: eventId -> {regs, approved, pending}
  final Map<String, Map<String, int>> _metrics = {};

  // UI state
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  _AnalyticsSort _sort = _AnalyticsSort.views;
  int _page = 1;
  static const int _pageSize = 4;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() {
        _query = _searchCtrl.text.trim().toLowerCase();
        _page  = 1;
      });
    });
  }

  @override
  void didUpdateWidget(_AnalyticsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshKey != widget.refreshKey) {
      setState(() {
        _streamKey++;
        _metrics.clear();
        _page = 1;
      });
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // Load registration metrics for all events (matches web: views from
  // event_view_count field; regs/approved from event_registrations collection)
  Future<void> _loadMetrics(List<Map<String, dynamic>> events) async {
    for (final ev in events) {
      final id = ev['_docId'] as String;
      if (_metrics.containsKey(id)) continue;
      try {
        final allSnap  = await FirebaseFirestore.instance
            .collection('event_registrations')
            .where('event_id', isEqualTo: id)
            .count()
            .get();
        final apprSnap = await FirebaseFirestore.instance
            .collection('event_registrations')
            .where('event_id', isEqualTo: id)
            .where('status', isEqualTo: 'approved')
            .count()
            .get();
        final pendSnap = await FirebaseFirestore.instance
            .collection('event_registrations')
            .where('event_id', isEqualTo: id)
            .where('status', isEqualTo: 'pending')
            .count()
            .get();
        if (mounted) {
          setState(() {
            _metrics[id] = {
              'regs':     allSnap.count  ?? 0,
              'approved': apprSnap.count ?? 0,
              'pending':  pendSnap.count ?? 0,
            };
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() => _metrics[id] = {'regs': 0, 'approved': 0, 'pending': 0});
        }
      }
    }
  }

  // ── Computed aggregate stats (mirror web app exactly) ──────────────────────
  int get _totalViews =>
      _events.fold(0, (s, ev) => s + ((ev['event_view_count'] ?? 0) as int));

  int get _totalRegistrations =>
      _metrics.values.fold(0, (s, m) => s + (m['regs'] ?? 0));

  int get _totalApproved =>
      _metrics.values.fold(0, (s, m) => s + (m['approved'] ?? 0));

  int get _avgViews =>
      _events.isEmpty ? 0 : (_totalViews / _events.length).round();

  String get _conversionRate {
    if (_totalViews == 0) return '0.0';
    return ((_totalApproved / _totalViews) * 100).toStringAsFixed(1);
  }

  // ── Filtering & sorting (mirrors web app logic exactly) ───────────────────
  List<Map<String, dynamic>> get _filtered {
    if (_query.isEmpty) return List.from(_events);
    return _events.where((ev) {
      final titleEn = (ev['event_title']    ?? '').toString().toLowerCase();
      final titleJp = (ev['event_title_jp'] ?? '').toString().toLowerCase();
      return titleEn.contains(_query) || titleJp.contains(_query);
    }).toList();
  }

  List<Map<String, dynamic>> get _sorted {
    final list = _filtered;
    list.sort((a, b) {
      final idA = a['_docId'] as String;
      final idB = b['_docId'] as String;
      final mA  = _metrics[idA] ?? {'regs': 0, 'approved': 0};
      final mB  = _metrics[idB] ?? {'regs': 0, 'approved': 0};

      switch (_sort) {
        case _AnalyticsSort.views:
          return ((b['event_view_count'] ?? 0) as int)
              .compareTo((a['event_view_count'] ?? 0) as int);
        case _AnalyticsSort.registrations:
          return (mB['regs'] ?? 0).compareTo(mA['regs'] ?? 0);
        case _AnalyticsSort.conversion:
          final vA  = (a['event_view_count'] ?? 0) as int;
          final vB  = (b['event_view_count'] ?? 0) as int;
          final cA  = vA > 0 ? (mA['approved']! / vA) : 0.0;
          final cB  = vB > 0 ? (mB['approved']! / vB) : 0.0;
          return cB.compareTo(cA);
        case _AnalyticsSort.newest:
          final tA = a['event_added'];
          final tB = b['event_added'];
          final msA = tA is Timestamp ? tA.millisecondsSinceEpoch : 0;
          final msB = tB is Timestamp ? tB.millisecondsSinceEpoch : 0;
          return msB.compareTo(msA);
      }
    });
    return list;
  }

  // ── Rank badge color (gold / silver / bronze / grey) ──────────────────────
  Color _rankColor(int rank) {
    if (rank == 1) return const Color(0xFFFFD700);
    if (rank == 2) return const Color(0xFFB0C4DE);
    if (rank == 3) return const Color(0xFFCD7F32);
    return Colors.grey.shade400;
  }

  // ── Capacity bar color ────────────────────────────────────────────────────
  Color _fillColor(int pct) {
    if (pct >= 90) return _D.rejClr;
    if (pct >= 70) return _D.pendClr;
    return _D.apprvClr;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.uid.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      key: ValueKey(_streamKey),
      stream: FirebaseFirestore.instance
          .collection('events')
          .where('submittedBy', isEqualTo: widget.uid)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        // Rebuild events list from stream
        final docs = snap.data!.docs;
        final freshEvents = docs.map((d) {
          final data = d.data() as Map<String, dynamic>;
          return <String, dynamic>{'_docId': d.id, ...data};
        }).toList()
          ..sort((a, b) {
            final tA = a['event_added'] is Timestamp
                ? (a['event_added'] as Timestamp).millisecondsSinceEpoch
                : 0;
            final tB = b['event_added'] is Timestamp
                ? (b['event_added'] as Timestamp).millisecondsSinceEpoch
                : 0;
            return tB.compareTo(tA);
          });

        // Update _events & trigger metrics load once per stream emission
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final changed = freshEvents.length != _events.length ||
              (freshEvents.isNotEmpty &&
                  freshEvents.first['_docId'] != (_events.isNotEmpty ? _events.first['_docId'] : ''));
          if (changed || _events.isEmpty) {
            setState(() => _events = freshEvents);
            _loadMetrics(freshEvents);
          }
        });

        final sortedEvents = _sorted;
        final totalPages   = (sortedEvents.isEmpty ? 1 : (sortedEvents.length / _pageSize).ceil());
        final safePage     = _page.clamp(1, totalPages);
        final pageEvents   = sortedEvents.skip((safePage - 1) * _pageSize).take(_pageSize).toList();

        return RefreshIndicator(
          onRefresh: widget.onRefreshAll,
          color: _D.refreshGreen,
          backgroundColor: Colors.white,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              // ── Section header ──────────────────────────────────────────
              Row(children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.bar_chart_rounded,
                      size: 18, color: AppColors.primary),
                ),
                const SizedBox(width: 10),
                Text(_t(widget.lang, 'analyticsTitle'),
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: _D.textPri)),
              ]),
              const SizedBox(height: 4),
              Text(_t(widget.lang, 'analyticsSub'),
                  style: const TextStyle(
                      fontSize: 12,
                      color: _D.textMuted,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 20),

              // ── Overview stat cards ────────────────────────────────────
              GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.6,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _StatCard(
                    icon: Icons.visibility_rounded,
                    iconColor: AppColors.primary,
                    label: _t(widget.lang, 'totalViews'),
                    value: _totalViews.toString(),
                    valueColor: _D.textPri,
                  ),
                  _StatCard(
                    icon: Icons.how_to_reg_rounded,
                    iconColor: const Color(0xFF5C6BC0),
                    label: _t(widget.lang, 'totalRegistrations'),
                    value: _totalRegistrations.toString(),
                    valueColor: _D.textPri,
                  ),
                  _StatCard(
                    icon: Icons.show_chart_rounded,
                    iconColor: _D.pendClr,
                    label: _t(widget.lang, 'avgViews'),
                    value: _avgViews.toString(),
                    valueColor: _D.textPri,
                  ),
                  _StatCard(
                    icon: Icons.trending_up_rounded,
                    iconColor: AppColors.primary,
                    label: _t(widget.lang, 'conversionRate'),
                    value: '$_conversionRate%',
                    valueColor: AppColors.primary,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Search bar ─────────────────────────────────────────────
              Container(
                height: 42,
                decoration: BoxDecoration(
                  color: _D.rowBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _D.border),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: _D.textPri),
                  decoration: InputDecoration(
                    hintText: _t(widget.lang, 'searchEventsAnalytics'),
                    hintStyle: const TextStyle(
                        fontSize: 14,
                        color: _D.textDim,
                        fontWeight: FontWeight.w400),
                    prefixIcon: const Icon(
                        Icons.search_rounded,
                        size: 20,
                        color: _D.textMuted),
                    suffixIcon: _query.isNotEmpty
                        ? GestureDetector(
                      onTap: () => _searchCtrl.clear(),
                      child: const Icon(Icons.close_rounded,
                          size: 18, color: _D.textMuted),
                    )
                        : null,
                    border: InputBorder.none,
                    contentPadding:
                    const EdgeInsets.symmetric(vertical: 11),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ── Sort pills ─────────────────────────────────────────────
              Row(children: [
                Text(_t(widget.lang, 'sortBy'),
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _D.textMuted)),
                const SizedBox(width: 10),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: [
                      _SortPill(
                        label: _t(widget.lang, 'sortMostViewed'),
                        selected: _sort == _AnalyticsSort.views,
                        onTap: () => setState(() { _sort = _AnalyticsSort.views; _page = 1; }),
                      ),
                      const SizedBox(width: 6),
                      _SortPill(
                        label: _t(widget.lang, 'sortMostRegistered'),
                        selected: _sort == _AnalyticsSort.registrations,
                        onTap: () => setState(() { _sort = _AnalyticsSort.registrations; _page = 1; }),
                      ),
                      const SizedBox(width: 6),
                      _SortPill(
                        label: _t(widget.lang, 'sortConversion'),
                        selected: _sort == _AnalyticsSort.conversion,
                        onTap: () => setState(() { _sort = _AnalyticsSort.conversion; _page = 1; }),
                      ),
                      const SizedBox(width: 6),
                      _SortPill(
                        label: _t(widget.lang, 'sortNewest'),
                        selected: _sort == _AnalyticsSort.newest,
                        onTap: () => setState(() { _sort = _AnalyticsSort.newest; _page = 1; }),
                      ),
                    ]),
                  ),
                ),
              ]),
              const SizedBox(height: 16),

              // ── Event cards or empty state ────────────────────────────
              if (sortedEvents.isEmpty)
                _EmptyState(
                  icon: Icons.bar_chart_rounded,
                  message: _t(widget.lang, 'noEventsAnalytics'),
                )
              else
                ...pageEvents.asMap().entries.map((entry) {
                  final idx  = entry.key;
                  final ev   = entry.value;
                  final id   = ev['_docId'] as String;
                  final rank = (safePage - 1) * _pageSize + idx + 1;
                  final m    = _metrics[id] ?? {'regs': 0, 'approved': 0, 'pending': 0};

                  final views    = (ev['event_view_count'] ?? 0) as int;
                  final regs     = m['regs']    ?? 0;
                  final approved = m['approved'] ?? 0;
                  final convPct  = views > 0
                      ? ((approved / views) * 100).toStringAsFixed(1)
                      : '0.0';

                  final title = widget.lang == 'ja'
                      ? (ev['event_title_jp'] ?? ev['event_title'] ?? 'Untitled').toString()
                      : (ev['event_title'] ?? 'Untitled').toString();
                  final imgUrl   = (ev['event_pic'] ?? '').toString();
                  final dateStr  = _fmtDate(ev['event_date'], compact: true);
                  final evType   = (ev['event_type'] ?? '').toString();

                  final limit    = (ev['event_limit'] ?? 0) as int;
                  final fillPct  = (limit > 0)
                      ? (approved / limit * 100).round().clamp(0, 100)
                      : 0;

                  return _AnalyticsEventCard(
                    rank:      rank,
                    rankColor: _rankColor(rank),
                    title:     title,
                    imgUrl:    imgUrl,
                    dateStr:   dateStr,
                    evType:    evType,
                    views:     views,
                    regs:      regs,
                    approved:  approved,
                    convPct:   convPct,
                    limit:     limit,
                    fillPct:   fillPct,
                    fillColor: _fillColor(fillPct),
                    lang:      widget.lang,
                    onViewDetails: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OrganizerEventDetailScreen(
                          eventId: id,
                          data:    ev,
                          lang:    widget.lang,
                        ),
                      ),
                    ),
                  );
                }),

              // ── Pagination ─────────────────────────────────────────────
              if (totalPages > 1) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_t(widget.lang, 'page')} $safePage ${_t(widget.lang, 'of')} $totalPages',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _D.textMuted),
                    ),
                    Row(children: [
                      // Prev
                      _PaginationBtn(
                        label: '← ${_t(widget.lang, 'prev')}',
                        enabled: safePage > 1,
                        onTap: () => setState(() => _page = safePage - 1),
                      ),
                      const SizedBox(width: 6),
                      // Page numbers
                      ...List.generate(totalPages, (i) => i + 1).map((pg) => Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: GestureDetector(
                          onTap: () => setState(() => _page = pg),
                          child: Container(
                            width: 30, height: 30,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: pg == safePage
                                  ? AppColors.primary.withOpacity(0.15)
                                  : _D.rowBg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: pg == safePage
                                    ? AppColors.primary.withOpacity(0.4)
                                    : _D.border,
                              ),
                            ),
                            child: Text('$pg',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: pg == safePage
                                        ? AppColors.primary
                                        : _D.textMuted)),
                          ),
                        ),
                      )),
                      const SizedBox(width: 6),
                      // Next
                      _PaginationBtn(
                        label: '${_t(widget.lang, 'next')} →',
                        enabled: safePage < totalPages,
                        onTap: () => setState(() => _page = safePage + 1),
                      ),
                    ]),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Analytics stat card
// ─────────────────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final Color valueColor;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _D.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _D.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _D.textMuted),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ),
              Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, size: 16, color: iconColor),
              ),
            ],
          ),
          Text(value,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: valueColor)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Analytics sort pill
// ─────────────────────────────────────────────────────────────────────────────
class _SortPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SortPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : _D.rowBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : _D.border,
          ),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : _D.textMuted)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Analytics event card
// ─────────────────────────────────────────────────────────────────────────────
class _AnalyticsEventCard extends StatelessWidget {
  final int rank;
  final Color rankColor;
  final String title;
  final String imgUrl;
  final String dateStr;
  final String evType;
  final int views;
  final int regs;
  final int approved;
  final String convPct;
  final int limit;
  final int fillPct;
  final Color fillColor;
  final String lang;
  final VoidCallback onViewDetails;

  const _AnalyticsEventCard({
    required this.rank,
    required this.rankColor,
    required this.title,
    required this.imgUrl,
    required this.dateStr,
    required this.evType,
    required this.views,
    required this.regs,
    required this.approved,
    required this.convPct,
    required this.limit,
    required this.fillPct,
    required this.fillColor,
    required this.lang,
    required this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _D.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _D.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Cover image + rank badge ──────────────────────────────────
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Stack(children: [
              imgUrl.isNotEmpty
                  ? Image.network(
                imgUrl,
                height: 100,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _placeholder(),
              )
                  : _placeholder(),
              // Rank badge
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  width: 32, height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: rankColor,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Text('#$rank',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: Colors.white)),
                ),
              ),
              // Event type badge
              if (evType.isNotEmpty)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(evType,
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ),
                ),
            ]),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date + type label
                Text(
                  [if (evType.isNotEmpty) evType, dateStr]
                      .where((s) => s.isNotEmpty)
                      .join(' • '),
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: _D.textMuted),
                ),
                const SizedBox(height: 4),
                // Title
                Text(title,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: _D.textPri),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 12),

                // ── Metrics row ───────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.primary.withOpacity(0.12)),
                  ),
                  child: Row(children: [
                    // Views
                    _MetricCol(
                      icon: Icons.visibility_rounded,
                      iconColor: AppColors.primary,
                      value: views.toString(),
                      label: _t(lang, 'viewsLabel'),
                    ),
                    _vDivider(),
                    // Registrations
                    _MetricCol(
                      icon: Icons.how_to_reg_rounded,
                      iconColor: const Color(0xFF5C6BC0),
                      value: regs.toString(),
                      subLabel: '($approved ${_t(lang, 'approved2')})',
                      label: _t(lang, 'registrationsLabel'),
                    ),
                    _vDivider(),
                    // Conversion
                    _MetricCol(
                      icon: Icons.trending_up_rounded,
                      iconColor: AppColors.primary,
                      value: '$convPct%',
                      label: _t(lang, 'conversionLabel'),
                      valueColor: AppColors.primary,
                    ),
                  ]),
                ),

                // ── Capacity bar (only if event has a limit) ──────────
                if (limit > 0) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        lang == 'ja'
                            ? '$approved / $limit${_t(lang, 'slotsFilled')}'
                            : '$approved / $limit ${_t(lang, 'slotsFilled')}',
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _D.textMuted),
                      ),
                      Text('$fillPct%',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: fillColor)),
                    ],
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: fillPct / 100,
                      minHeight: 5,
                      backgroundColor: _D.border,
                      valueColor: AlwaysStoppedAnimation<Color>(fillColor),
                    ),
                  ),
                ],

                const SizedBox(height: 14),

                // ── View Details button ────────────────────────────────
                _ActionButton(
                  icon: Icons.remove_red_eye_rounded,
                  label: _t(lang, 'viewEvent'),
                  color: AppColors.primary,
                  onTap: onViewDetails,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() => Container(
    height: 100,
    width: double.infinity,
    color: AppColors.primary.withOpacity(0.08),
    child: Icon(Icons.event_rounded,
        size: 36, color: AppColors.primary.withOpacity(0.25)),
  );

  Widget _vDivider() => Container(
    width: 1,
    height: 32,
    margin: const EdgeInsets.symmetric(horizontal: 10),
    color: AppColors.primary.withOpacity(0.12),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// A single metric column inside the analytics card metrics row
// ─────────────────────────────────────────────────────────────────────────────
class _MetricCol extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final String? subLabel;
  final Color? valueColor;

  const _MetricCol({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    this.subLabel,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 12, color: iconColor),
            const SizedBox(width: 4),
            Text(value,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: valueColor ?? _D.textPri)),
          ]),
          if (subLabel != null)
            Text(subLabel!,
                style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                    color: _D.textMuted)),
          Text(label,
              style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: iconColor.withOpacity(0.7))),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pagination button
// ─────────────────────────────────────────────────────────────────────────────
class _PaginationBtn extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  const _PaginationBtn({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: _D.rowBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _D.border),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: enabled ? _D.textSec : _D.textDim)),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TAB 5 — AUDIT LOG
// ═════════════════════════════════════════════════════════════════════════════
class _AuditLogTab extends StatefulWidget {
  final String uid, lang;
  final int refreshKey;
  final Future<void> Function() onRefreshAll;
  const _AuditLogTab({
    required this.uid,
    required this.lang,
    required this.refreshKey,
    required this.onRefreshAll,
  });

  @override
  State<_AuditLogTab> createState() => _AuditLogTabState();
}

class _AuditLogTabState extends State<_AuditLogTab> {
  static const int _pageSize = 20;

  List<Map<String, dynamic>> _logs = [];
  DocumentSnapshot? _lastDoc;

  bool _loading  = false;
  bool _hasMore  = true;
  bool _initDone = false;

  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _fetchNextPage();
    _searchCtrl.addListener(() {
      setState(() => _query = _searchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void didUpdateWidget(_AuditLogTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshKey != widget.refreshKey) {
      _resetAndFetch();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _resetAndFetch() async {
    setState(() {
      _logs     = [];
      _lastDoc  = null;
      _hasMore  = true;
      _initDone = false;
      _loading  = false;
    });
    await _fetchNextPage();
  }

  bool _matchesQuery(Map<String, dynamic> log) {
    if (_query.isEmpty) return true;
    final targetName = (log['target_name'] ?? '').toString().toLowerCase();
    final action     = (log['action']      ?? '').toString().toLowerCase();
    final details    = (log['details']     ?? '').toString().toLowerCase();
    return targetName.contains(_query) || action.contains(_query) || details.contains(_query);
  }

  Future<void> _fetchNextPage() async {
    if (_loading || !_hasMore || widget.uid.isEmpty) return;
    setState(() => _loading = true);

    try {
      Query<Map<String, dynamic>> query = FirebaseFirestore.instance
          .collection('audit_logs')
          .where('actor_id', isEqualTo: widget.uid)
          .limit(_pageSize);

      if (_lastDoc != null) query = query.startAfterDocument(_lastDoc!);

      final snap = await query.get();

      if (snap.docs.length < _pageSize) _hasMore = false;
      if (snap.docs.isNotEmpty) _lastDoc = snap.docs.last;

      final newLogs = snap.docs
          .map((d) => <String, dynamic>{'_id': d.id, ...d.data()})
          .toList();

      if (mounted) {
        setState(() {
          _logs.addAll(newLogs);
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

    final filtered     = _logs.where(_matchesQuery).toList();
    final showLoadMore = _hasMore || _loading;
    final itemCount    = filtered.length + (showLoadMore && _query.isEmpty ? 1 : 0);

    if (_initDone && _logs.isEmpty) {
      return Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: widget.onRefreshAll,
              color: _D.refreshGreen,
              backgroundColor: Colors.white,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: 400,
                  child: _EmptyState(
                      icon: Icons.history_rounded,
                      message: _t(widget.lang, 'noAudit')),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        _buildSearchBar(),
        Expanded(
          child: () {
            if (filtered.isEmpty) {
              return RefreshIndicator(
                onRefresh: widget.onRefreshAll,
                color: _D.refreshGreen,
                backgroundColor: Colors.white,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: SizedBox(
                    height: 400,
                    child: _EmptyState(
                        icon: Icons.search_off_rounded,
                        message: _t(widget.lang, 'noAuditResults')),
                  ),
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: widget.onRefreshAll,
              color: _D.refreshGreen,
              backgroundColor: Colors.white,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: itemCount,
                itemBuilder: (_, i) {
                  if (i == filtered.length) {
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
                            color: _D.accentLt,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: _D.accentBdr),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.expand_more_rounded, size: 18, color: _D.accent),
                              const SizedBox(width: 6),
                              Text(_t(widget.lang, 'loadMore'),
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: _D.accent)),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  final d    = filtered[i];
                  final meta = _auditMeta((d['action'] ?? '').toString(), widget.lang);
                  final date = _fmtDate(d['timestamp'], compact: true);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _D.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.04),
                            blurRadius: 10, offset: const Offset(0, 3)),
                      ],
                    ),
                    child: Row(children: [
                      Container(
                        width: 38, height: 38,
                        decoration: BoxDecoration(
                          color: (meta['color'] as Color).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(meta['icon'] as IconData,
                            size: 18, color: meta['color'] as Color),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(meta['label'] as String,
                              style: TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.w700,
                                  color: meta['color'] as Color, letterSpacing: 0.3)),
                          Text((d['target_name'] ?? '').toString(),
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w700),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          if ((d['details'] ?? '').toString().isNotEmpty)
                            Text((d['details'] ?? '').toString(),
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                maxLines: 2, overflow: TextOverflow.ellipsis),
                        ]),
                      ),
                      const SizedBox(width: 8),
                      Text(date,
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                    ]),
                  );
                },
              ),
            );
          }(),
        ),
      ],
    );
  }

  Widget _buildSearchBar() => Container(
    color: _D.white,
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
    child: Container(
      height: 42,
      decoration: BoxDecoration(
          color: _D.rowBg, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _D.border)),
      child: TextField(
        controller: _searchCtrl,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: _D.textPri),
        decoration: InputDecoration(
          hintText: _t(widget.lang, 'searchAudit'),
          hintStyle: const TextStyle(fontSize: 14, color: _D.textDim, fontWeight: FontWeight.w400),
          prefixIcon: const Icon(Icons.search_rounded, size: 20, color: _D.textMuted),
          suffixIcon: _query.isNotEmpty
              ? GestureDetector(onTap: () => _searchCtrl.clear(),
              child: const Icon(Icons.close_rounded, size: 18, color: _D.textMuted))
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 11),
        ),
      ),
    ),
  );

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
            width: 72, height: 72,
            decoration: BoxDecoration(
                color: Colors.grey.shade100, shape: BoxShape.circle),
            child: Icon(icon, size: 36, color: Colors.grey.shade400)),
        const SizedBox(height: 16),
        Text(message,
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w600,
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
  const _Badge({required this.label, required this.icon,
    required this.color, required this.bg});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
        color: bg, borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 11, color: color),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(
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
        color: _D.rowBg, borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _D.border)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: Colors.grey.shade500),
      const SizedBox(width: 5),
      Text(label, style: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
    ]),
  );
}

class _MetricPill extends StatelessWidget {
  final IconData icon;
  final int value;
  final String label;
  final Color color;
  const _MetricPill({required this.icon, required this.value,
    required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Row(children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 6),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$value', style: TextStyle(
            fontSize: 15, fontWeight: FontWeight.w800, color: color)),
        Text(label, style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w600,
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
  const _ActionButton({required this.icon, required this.label,
    required this.color, required this.onTap, this.outlined = false});

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
        Text(label, style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w700,
            color: outlined ? color : Colors.white)),
      ]),
    ),
  );
}

class _OutlineBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _OutlineBtn({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
          border: Border.all(color: color, width: 1.5),
          borderRadius: BorderRadius.circular(10)),
      alignment: Alignment.center,
      child: Text(label, style: TextStyle(
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
        color: bg, borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border.withOpacity(0.4))),
    child: Text(label, style: TextStyle(
        fontSize: 11, fontWeight: FontWeight.w800, color: color)),
  );
}

class _FilterTab extends StatelessWidget {
  final String label, value, current;
  final ValueChanged<String> onTap;
  const _FilterTab({required this.label, required this.value,
    required this.current, required this.onTap});

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
          border: Border.all(
              color: selected ? _D.tabSelBdr : _D.tabUnselBdr),
        ),
        child: Text(label, style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700,
            color: selected ? _D.accent : _D.textMuted)),
      ),
    );
  }
}

class _ABtn extends StatelessWidget {
  final String label;
  final Color color, bg;
  final VoidCallback onTap;
  const _ABtn({required this.label, required this.color,
    required this.bg, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg, borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(label, style: TextStyle(
          fontSize: 11, fontWeight: FontWeight.w800, color: color)),
    ),
  );
}

class _SheetField extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final int maxLines;
  final TextInputType keyboardType;
  const _SheetField({required this.label, required this.ctrl,
    this.maxLines = 1, this.keyboardType = TextInputType.text});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w600,
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
              borderSide: BorderSide(color: AppColors.primary, width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 12),
        ),
      ),
    ],
  );
}