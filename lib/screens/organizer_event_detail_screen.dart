import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pikuru/theme/material.dart';
import 'package:pikuru/providers/app_language_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Design tokens — light theme
// ─────────────────────────────────────────────────────────────────────────────
class _C {
  static const bg        = Color(0xFFF5FAF6);
  static const surface   = Color(0xFFE8F3EB);
  static const card      = Color(0xFFEDF6EF);
  static const border    = Color(0x1A2D7A3F);
  static const accent    = Color(0xFF1F7A35);
  static const accentDim = Color(0xFF8ABFA0);
  static const textPri   = Color(0xFF0D1F14);
  static const textMuted = Color(0x80000000);
  static const textDim   = Color(0x40000000);
  static const approved  = Color(0xFF1F7A35);
  static const pending   = Color(0xFFB07D00);
  static const rejected  = Color(0xFFB0193A);
  static const regClosed = Color(0xFFD97706);
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────
String _fmt(dynamic ts, String lang, {bool long = false}) {
  if (ts == null) return '—';
  final d = ts is Timestamp ? ts.toDate() : null;
  if (d == null) return '—';
  if (lang == 'ja') {
    if (long) {
      const wd = ['月', '火', '水', '木', '金', '土', '日'];
      return '${d.year}年${d.month}月${d.day}日（${wd[d.weekday - 1]}）';
    }
    return '${d.year}年${d.month}月${d.day}日';
  }
  if (long) {
    const wdEn = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const moEn = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${wdEn[d.weekday - 1]}, ${moEn[d.month - 1]} ${d.day}, ${d.year}';
  }
  const mo = ['Jan','Feb','Mar','Apr','May','Jun',
    'Jul','Aug','Sep','Oct','Nov','Dec'];
  return '${mo[d.month - 1]} ${d.day}, ${d.year}';
}

String _fmtTime(dynamic ts) {
  if (ts == null) return '—';
  final d = ts is Timestamp ? ts.toDate() : null;
  if (d == null) return '—';
  final h = d.hour;
  final m = d.minute.toString().padLeft(2, '0');
  final period = h >= 12 ? 'PM' : 'AM';
  final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
  return '$h12:$m $period';
}

bool _isRegClosed(dynamic dl) {
  if (dl == null) return false;
  final d = dl is Timestamp ? dl.toDate() : null;
  if (d == null) return false;
  return d.isBefore(DateTime.now());
}

// ─────────────────────────────────────────────────────────────────────────────
// Registration counts — fetched via getCountFromServer (no doc reads)
// ─────────────────────────────────────────────────────────────────────────────
class _RegCounts {
  final int total, approved, pending, rejected;
  const _RegCounts({
    this.total = 0,
    this.approved = 0,
    this.pending = 0,
    this.rejected = 0,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Public entry point
// ─────────────────────────────────────────────────────────────────────────────
class OrganizerEventDetailScreen extends StatefulWidget {
  final String eventId;
  final Map<String, dynamic> data;
  final String lang;

  const OrganizerEventDetailScreen({
    super.key,
    required this.eventId,
    required this.data,
    required this.lang,
  });

  @override
  State<OrganizerEventDetailScreen> createState() =>
      _OrganizerEventDetailScreenState();
}

class _OrganizerEventDetailScreenState
    extends State<OrganizerEventDetailScreen> {
  // ── Counts (cheap — getCountFromServer, no document reads) ────────────────
  _RegCounts _counts = const _RegCounts();
  bool _loadingCounts = true;

  // ── Paginated registration list ───────────────────────────────────────────
  static const int _pageSize = 15; // mirrors web REG_PAGE_SIZE
  final List<Map<String, dynamic>> _regs = [];
  DocumentSnapshot? _lastDoc;
  bool _hasMore = false;
  bool _loadingPage = false;
  bool _loadingFirst = true;

  // ── Filter ────────────────────────────────────────────────────────────────
  String _regFilter = 'all'; // all | pending | approved | rejected

  // ── Optimistic update tracking ────────────────────────────────────────────
  String? _updatingId;

  List<Map<String, dynamic>> get _filtered {
    if (_regFilter == 'all') return _regs;
    return _regs
        .where((r) => (r['status'] ?? 'pending') == _regFilter)
        .toList();
  }

  // ─────────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _fetchCounts();
    _loadFirstPage();
  }

  // ── 1. Fetch counts with count() — no document reads ─────────────────────
  Future<void> _fetchCounts() async {
    try {
      final base = FirebaseFirestore.instance
          .collection('event_registrations')
          .where('event_id', isEqualTo: widget.eventId);

      final results = await Future.wait<AggregateQuerySnapshot>([
        base.count().get(),
        base.where('status', isEqualTo: 'approved').count().get(),
        base.where('status', isEqualTo: 'rejected').count().get(),
      ]);

      final total    = results[0].count ?? 0;
      final approved = results[1].count ?? 0;
      final rejected = results[2].count ?? 0;
      final pending  = total - approved - rejected;

      if (mounted) {
        setState(() {
          _counts = _RegCounts(
            total:    total,
            approved: approved,
            pending:  pending,
            rejected: rejected,
          );
          _loadingCounts = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingCounts = false);
    }
  }

  // ── 2. Load first page (15 docs) ──────────────────────────────────────────
  Future<void> _loadFirstPage() async {
    setState(() {
      _loadingFirst = true;
      _regs.clear();
      _lastDoc = null;
      _hasMore = false;
    });
    try {
      final snap = await FirebaseFirestore.instance
          .collection('event_registrations')
          .where('event_id', isEqualTo: widget.eventId)
          .orderBy('registered_at', descending: true)
          .limit(_pageSize)
          .get();

      if (mounted) {
        setState(() {
          _regs.addAll(
              snap.docs.map((d) => {'_id': d.id, ...d.data()}).toList());
          _lastDoc = snap.docs.isNotEmpty ? snap.docs.last : null;
          _hasMore = snap.docs.length == _pageSize;
          _loadingFirst = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingFirst = false);
    }
  }

  // ── 3. Load next page ─────────────────────────────────────────────────────
  Future<void> _loadMorePage() async {
    if (_loadingPage || !_hasMore || _lastDoc == null) return;
    setState(() => _loadingPage = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('event_registrations')
          .where('event_id', isEqualTo: widget.eventId)
          .orderBy('registered_at', descending: true)
          .startAfterDocument(_lastDoc!)
          .limit(_pageSize)
          .get();

      if (mounted) {
        setState(() {
          _regs.addAll(
              snap.docs.map((d) => {'_id': d.id, ...d.data()}).toList());
          _lastDoc = snap.docs.isNotEmpty ? snap.docs.last : null;
          _hasMore = snap.docs.length == _pageSize;
          _loadingPage = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingPage = false);
    }
  }

  // ── 4. Status update ──────────────────────────────────────────────────────
  Future<void> _updateStatus(String regId, String status) async {
    setState(() => _updatingId = regId);
    try {
      await FirebaseFirestore.instance
          .collection('event_registrations')
          .doc(regId)
          .update({
        'status':     status,
        'updated_at': FieldValue.serverTimestamp(),
      });
      setState(() {
        final idx = _regs.indexWhere((r) => r['_id'] == regId);
        if (idx != -1) {
          final old = (_regs[idx]['status'] ?? 'pending') as String;
          _regs[idx] = {..._regs[idx], 'status': status};
          _counts = _RegCounts(
            total:    _counts.total,
            approved: _counts.approved + (status == 'approved' ? 1 : 0) - (old == 'approved' ? 1 : 0),
            pending:  _counts.pending  + (status == 'pending'  ? 1 : 0) - (old == 'pending'  ? 1 : 0),
            rejected: _counts.rejected + (status == 'rejected' ? 1 : 0) - (old == 'rejected' ? 1 : 0),
          );
        }
      });
    } catch (_) {}
    if (mounted) setState(() => _updatingId = null);
  }

  // ── Data helpers ──────────────────────────────────────────────────────────
  String get _title => widget.lang == 'ja'
      ? ((widget.data['event_title_jp'] ?? widget.data['event_title'] ?? 'Untitled').toString())
      : ((widget.data['event_title'] ?? 'Untitled').toString());

  String get _desc => widget.lang == 'ja'
      ? ((widget.data['event_description_jp'] ??
      widget.data['event_description_en'] ?? '').toString())
      : ((widget.data['event_description_en'] ?? '').toString());

  String get _imgUrl =>
      (widget.data['event_pic'] ?? widget.data['event_pic_thumbnail'] ?? '').toString();

  String get _feeStr {
    final f = (widget.data['event_fee'] ?? '').toString();
    return (f.isEmpty || f == '0')
        ? (widget.lang == 'ja' ? '無料' : 'Free')
        : '¥$f';
  }

  bool _truthy(String key) {
    final v = widget.data[key];
    if (v == null) return false;
    if (v is bool) return v;
    if (v is num) return v != 0;
    final s = v.toString().toLowerCase().trim();
    return s == 'true' || s == '1' || s == 'yes';
  }

  List<String> get _categories {
    final isJa = widget.lang == 'ja';
    return [
      if (_truthy('event_category_menssingle'))   isJa ? '男子シングルス' : "Men's Singles",
      if (_truthy('event_category_womenssingle'))  isJa ? '女子シングルス' : "Women's Singles",
      if (_truthy('event_category_mensdoubles'))   isJa ? '男子ダブルス'  : "Men's Doubles",
      if (_truthy('event_category_womensdoubles')) isJa ? '女子ダブルス'  : "Women's Doubles",
      if (_truthy('event_category_mixeddoubles'))  isJa ? '混合ダブルス'  : 'Mixed Doubles',
      if (_truthy('event_category_seniors'))       isJa ? 'シニア'        : 'Seniors',
      if (_truthy('event_category_juniors'))       isJa ? 'ジュニア'      : 'Juniors',
      if (_truthy('event_category_collegiate'))    isJa ? '大学生'        : 'Collegiate',
    ];
  }

  List<String> get _skills {
    final isJa = widget.lang == 'ja';
    return [
      if (_truthy('event_skill_level_beginner')) isJa ? '初心者'    : 'Beginner',
      if (_truthy('event_skill_level_amateur'))  isJa ? 'アマチュア' : 'Amateur',
      if (_truthy('event_skill_level_pro'))      isJa ? 'プロ'       : 'Pro',
    ];
  }

  String _t(String en, String ja) => widget.lang == 'ja' ? ja : en;

  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final d    = widget.data;
    final lang = widget.lang;

    final isApproved = d['event_checked'] == true && d['event_pending_review'] != true;
    final eventType  = (d['event_type'] ?? '').toString();
    final limitVal   = (d['event_limit'] ?? 0);
    final limitStr   = (limitVal != null && limitVal != 0)
        ? '$limitVal'
        : _t('No limit', '制限なし');
    final contact = (d['event_contact']    ?? '').toString();
    final venue   = (d['event_venue_name'] ?? '').toString();
    final link    = (d['event_link']       ?? '').toString();
    final endDate = _fmt(d['event_date_end'], lang, long: true);
    final hasEnd  = d['event_date_end'] != null;

    return Scaffold(
      backgroundColor: _C.bg,
      body: Stack(
        children: [
          // ── MAIN SCROLLABLE CONTENT ────────────────────────────────────
          Column(
            children: [
              _TopBar(
                title:       _title,
                isApproved:  isApproved,
                isRegClosed: _isRegClosed(d['registration_deadline']),
                counts:      _counts,
                loading:     _loadingCounts,
                lang:        lang,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 200),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _HeroImage(imgUrl: _imgUrl, eventType: eventType),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_title,
                                style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900,
                                    color: _C.textPri,
                                    height: 1.2,
                                    letterSpacing: -0.5)),
                            if (lang == 'ja' &&
                                (d['event_title'] ?? '').toString().isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text((d['event_title'] ?? '').toString(),
                                  style: const TextStyle(fontSize: 13, color: _C.textDim)),
                            ],
                            const SizedBox(height: 20),
                            _MetaGrid(
                              date:  _fmt(d['event_date'], lang, long: true),
                              time:  _fmtTime(d['event_time'] ?? d['event_date']),
                              fee:   _feeStr,
                              limit: limitStr,
                              lang:  lang,
                            ),
                            if (hasEnd) ...[
                              const SizedBox(height: 12),
                              _EndDateRow(date: endDate, lang: lang),
                            ],
                            if (_desc.isNotEmpty) ...[
                              const SizedBox(height: 20),
                              _Section(
                                icon: Icons.format_list_bulleted_rounded,
                                label: _t('DESCRIPTION', '説明'),
                                child: Text(_desc,
                                    style: const TextStyle(
                                        fontSize: 14, color: _C.textMuted, height: 1.6)),
                              ),
                            ],
                            if (_categories.isNotEmpty || _skills.isNotEmpty) ...[
                              const SizedBox(height: 20),
                              _Section(
                                icon: Icons.label_rounded,
                                label: _t('CATEGORIES & SKILLS', 'カテゴリとスキルレベル'),
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    ..._categories.map((c) => _Tag(label: c, color: _C.accent)),
                                    ..._skills.map((s) => _Tag(label: s, color: _C.textMuted)),
                                  ],
                                ),
                              ),
                            ],
                            ..._buildDetails(d, lang, contact, venue, link),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // ── DRAGGABLE REGISTRATION SHEET ───────────────────────────────
          DraggableScrollableSheet(
            initialChildSize: 0.28,
            minChildSize:     0.14,
            maxChildSize:     0.88,
            snap: true,
            snapSizes: const [0.14, 0.28, 0.60, 0.88],
            builder: (context, scrollController) {
              return _RegSheet(
                scrollController: scrollController,
                regs:          _regs,
                filtered:      _filtered,
                filter:        _regFilter,
                loading:       _loadingFirst,
                loadingMore:   _loadingPage,
                hasMore:       _hasMore,
                updatingId:    _updatingId,
                counts:        _counts,
                countsLoading: _loadingCounts,
                lang:          lang,
                onFilter:      (f) => setState(() => _regFilter = f),
                onApprove:     (id) => _updateStatus(id, 'approved'),
                onReject:      (id) => _updateStatus(id, 'rejected'),
                onLoadMore:    _loadMorePage,
              );
            },
          ),
        ],
      ),
    );
  }

  List<Widget> _buildDetails(Map<String, dynamic> d, String lang,
      String contact, String venue, String link) {
    final rows = <_DetailEntry>[];
    if (contact.isNotEmpty)
      rows.add(_DetailEntry(_t('Contact', '連絡先'), contact, Icons.contact_mail_rounded));
    if (venue.isNotEmpty)
      rows.add(_DetailEntry(_t('Venue Name', '会場名'), venue, Icons.location_on_rounded));
    if (link.isNotEmpty)
      rows.add(_DetailEntry(_t('Link', 'リンク'), link, Icons.link_rounded));
    final tourist = d['event_touristfriendly'];
    if (tourist != null) {
      rows.add(_DetailEntry(
          _t('Tourist Friendly', '観光客歓迎'),
          tourist == true ? '✓ Yes' : '✗ No',
          Icons.flag_rounded));
    }
    final added = d['event_added'];
    if (added != null) {
      rows.add(_DetailEntry(
          _t('Submission Date', '提出日'), _fmt(added, lang), Icons.calendar_today_rounded));
    }
    final regDl = d['registration_deadline'];
    if (regDl != null) {
      final closed = _isRegClosed(regDl);
      final base = _fmt(regDl, lang, long: true);
      final suffix = closed ? (lang == 'ja' ? '  ・ 終了' : '  ・ Closed') : '';
      rows.add(_DetailEntry(
          _t('Reg. Deadline', '登録締切'),
          '$base$suffix',
          Icons.lock_clock_rounded));
    }
    if (rows.isEmpty) return [];
    return [
      const SizedBox(height: 20),
      _Section(
        icon: Icons.info_outline_rounded,
        label: _t('DETAILS', '詳細'),
        child: Column(
          children: rows
              .map((r) => _DetailRowW(icon: r.icon, label: r.label, value: r.value))
              .toList(),
        ),
      ),
    ];
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _RegSheet — draggable bottom sheet with paginated list
// ─────────────────────────────────────────────────────────────────────────────
class _RegSheet extends StatelessWidget {
  final ScrollController scrollController;
  final List<Map<String, dynamic>> regs, filtered;
  final String filter, lang;
  final bool loading, loadingMore, hasMore, countsLoading;
  final String? updatingId;
  final _RegCounts counts;
  final ValueChanged<String> onFilter;
  final ValueChanged<String> onApprove;
  final ValueChanged<String> onReject;
  final VoidCallback onLoadMore;

  const _RegSheet({
    required this.scrollController,
    required this.regs,
    required this.filtered,
    required this.filter,
    required this.lang,
    required this.loading,
    required this.loadingMore,
    required this.hasMore,
    required this.countsLoading,
    required this.updatingId,
    required this.counts,
    required this.onFilter,
    required this.onApprove,
    required this.onReject,
    required this.onLoadMore,
  });

  bool get _isJa => lang == 'ja';
  String _t(String en, String ja) => _isJa ? ja : en;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
        border: Border.all(color: _C.accent.withOpacity(0.15)),
      ),
      child: CustomScrollView(
        controller: scrollController,
        slivers: [
          // ── Drag handle + header ─────────────────────────────────────────
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 6),
                    width: 36, height: 4,
                    decoration: BoxDecoration(
                      color: _C.accent.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text(
                          _t('Event Registrations', 'イベント登録管理'),
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w900, color: _C.textPri),
                        ),
                        const Spacer(),
                        if (countsLoading)
                          SizedBox(
                            width: 14, height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: _C.accent),
                          )
                        else ...[
                          if (counts.total > 0)
                            _StatPill(
                                _t('Total: ${counts.total}', '合計: ${counts.total}'),
                                Colors.black.withOpacity(0.45)),
                          if (counts.approved > 0) ...[
                            const SizedBox(width: 5),
                            _StatPill('${counts.approved} ✓', _C.approved),
                          ],
                          if (counts.rejected > 0) ...[
                            const SizedBox(width: 5),
                            _StatPill('${counts.rejected} ✗', _C.rejected),
                          ],
                        ],
                      ]),
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(children: [
                          _FilterTab(
                            label: _t('All', 'すべて'),
                            count: counts.total,
                            selected: filter == 'all',
                            onTap: () => onFilter('all'),
                          ),
                          const SizedBox(width: 6),
                          _FilterTab(
                            label: _t('Pending', '保留'),
                            count: counts.pending,
                            selected: filter == 'pending',
                            onTap: () => onFilter('pending'),
                          ),
                          const SizedBox(width: 6),
                          _FilterTab(
                            label: _t('Approved', '承認済み'),
                            count: counts.approved,
                            selected: filter == 'approved',
                            onTap: () => onFilter('approved'),
                          ),
                          const SizedBox(width: 6),
                          _FilterTab(
                            label: _t('Rejected', '却下'),
                            count: counts.rejected,
                            selected: filter == 'rejected',
                            onTap: () => onFilter('rejected'),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
                Divider(height: 1, color: _C.accent.withOpacity(0.12)),
              ],
            ),
          ),

          // ── Registration rows ────────────────────────────────────────────
          if (loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(color: _C.accent)),
            )
          else if (filtered.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Text(
                  _t('No registrations yet.', 'まだ登録者がいません。'),
                  style: TextStyle(fontSize: 13, color: _C.textMuted),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                      (context, i) {
                    if (i < filtered.length) {
                      final r = filtered[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _RegRow(
                          reg:        r,
                          lang:       lang,
                          isUpdating: updatingId == r['_id'],
                          onApprove:  () => onApprove(r['_id'] as String),
                          onReject:   () => onReject(r['_id'] as String),
                        ),
                      );
                    }
                    // ── Load-more / end row ──────────────────────────────
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: loadingMore
                          ? const Center(
                          child: SizedBox(
                              width: 22, height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5, color: _C.accent)))
                          : hasMore
                          ? GestureDetector(
                        onTap: onLoadMore,
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 20),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _C.accent.withOpacity(0.07),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: _C.accent.withOpacity(0.25)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _t('Load more', 'もっと読み込む'),
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: _C.accent.withOpacity(0.85)),
                              ),
                              const SizedBox(width: 6),
                              Icon(Icons.expand_more_rounded,
                                  size: 16, color: _C.accent.withOpacity(0.7)),
                            ],
                          ),
                        ),
                      )
                          : Center(
                        child: Text(
                          _t('Showing ${regs.length} of ${regs.length}',
                              '${regs.length}件 表示中'),
                          style: TextStyle(fontSize: 11, color: _C.textDim),
                        ),
                      ),
                    );
                  },
                  childCount: filtered.length + 1,
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _TopBar
// ─────────────────────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final String title;
  final bool isApproved, loading, isRegClosed;
  final _RegCounts counts;
  final String lang;
  const _TopBar({
    required this.title,
    required this.isApproved,
    required this.isRegClosed,
    required this.counts,
    required this.loading,
    required this.lang,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _C.bg,
      padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top, left: 4, right: 12),
      child: Row(children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: _C.textMuted),
          onPressed: () => Navigator.pop(context),
        ),
        Expanded(
          child: Text(title,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w800, color: _C.textPri)),
        ),
        const SizedBox(width: 8),
        if (isRegClosed) ...[
          _Pill(
            label: lang == 'ja' ? '🔒 受付終了' : '🔒 Registration Closed',
            color: _C.regClosed,
          ),
          const SizedBox(width: 6),
        ],
        if (isApproved)
          _Pill(
            label: lang == 'ja' ? '✓ 承認済み' : '✓ Approved',
            color: _C.approved,
          ),
        const SizedBox(width: 6),
        if (!loading && counts.total > 0)
          _Pill(
            label: lang == 'ja'
                ? '${counts.total} 登録者'
                : '${counts.total} Registrant${counts.total == 1 ? '' : 's'}',
            color: const Color(0xFF6366F1),
          ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _HeroImage
// ─────────────────────────────────────────────────────────────────────────────
class _HeroImage extends StatelessWidget {
  final String imgUrl, eventType;
  const _HeroImage({required this.imgUrl, required this.eventType});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 240,
      width: double.infinity,
      child: Stack(fit: StackFit.expand, children: [
        imgUrl.isNotEmpty
            ? Image.network(imgUrl, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _placeholder())
            : _placeholder(),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, _C.bg],
              stops: const [0.4, 1.0],
            ),
          ),
        ),
        if (eventType.isNotEmpty)
          Positioned(
            bottom: 16, left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _C.accent.withOpacity(0.9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(eventType,
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w900,
                      color: Color(0xFFF5FAF6), letterSpacing: 0.5)),
            ),
          ),
      ]),
    );
  }

  Widget _placeholder() => Container(
    color: _C.surface,
    child: Icon(Icons.event_rounded, size: 48, color: _C.accent.withOpacity(0.2)),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// _MetaGrid
// ─────────────────────────────────────────────────────────────────────────────
class _MetaGrid extends StatelessWidget {
  final String date, time, fee, limit, lang;
  const _MetaGrid({
    required this.date,
    required this.time,
    required this.fee,
    required this.limit,
    required this.lang,
  });

  @override
  Widget build(BuildContext context) {
    final isJa = lang == 'ja';
    final items = [
      _MetaItem(Icons.calendar_today_rounded, isJa ? '日付' : 'DATE', date),
      _MetaItem(Icons.access_time_rounded,    isJa ? '時間' : 'TIME', time),
      _MetaItem(Icons.attach_money_rounded,   isJa ? '参加費' : 'FEE', fee),
      _MetaItem(Icons.people_rounded,         isJa ? '定員' : 'LIMIT', limit),
    ];
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.9,
      children: items.map((m) => _MetaCard(item: m)).toList(),
    );
  }
}

class _MetaItem {
  final IconData icon;
  final String label, value;
  const _MetaItem(this.icon, this.label, this.value);
}

class _MetaCard extends StatelessWidget {
  final _MetaItem item;
  const _MetaCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _C.accent.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.accent.withOpacity(0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              color: _C.accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(item.icon, size: 15, color: _C.accent),
          ),
          Text(item.label,
              style: TextStyle(
                  fontSize: 9, fontWeight: FontWeight.w800,
                  letterSpacing: 0.8, color: _C.accent.withOpacity(0.7))),
          Text(item.value,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w900, color: _C.textPri),
              maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _EndDateRow
// ─────────────────────────────────────────────────────────────────────────────
class _EndDateRow extends StatelessWidget {
  final String date, lang;
  const _EndDateRow({required this.date, required this.lang});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _C.accent.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.accent.withOpacity(0.14)),
      ),
      child: Row(children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
              color: _C.accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.calendar_month_rounded, size: 14, color: _C.accent),
        ),
        const SizedBox(width: 10),
        Text(lang == 'ja' ? '終了日: ' : 'End Date: ',
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700,
                color: _C.accent.withOpacity(0.7))),
        Expanded(
          child: Text(date,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w800, color: _C.textPri)),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _Section
// ─────────────────────────────────────────────────────────────────────────────
class _Section extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget child;
  const _Section({required this.icon, required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.accent.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.accent.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 13, color: _C.accent.withOpacity(0.7)),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w800,
                    letterSpacing: 0.8, color: _C.accent.withOpacity(0.7))),
          ]),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _Tag
// ─────────────────────────────────────────────────────────────────────────────
class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  const _Tag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _DetailEntry + _DetailRowW
// ─────────────────────────────────────────────────────────────────────────────
class _DetailEntry {
  final String label, value;
  final IconData icon;
  const _DetailEntry(this.label, this.value, this.icon);
}

class _DetailRowW extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _DetailRowW({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
              color: _C.accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 13, color: _C.accent),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 100,
          child: Text(label,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600,
                  color: _C.accent.withOpacity(0.65))),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: _C.textPri),
              textAlign: TextAlign.end,
              maxLines: 2, overflow: TextOverflow.ellipsis),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _RegRow — single registrant card
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

  bool get _isJa => lang == 'ja';
  String _t(String en, String ja) => _isJa ? ja : en;

  @override
  Widget build(BuildContext context) {
    final status = (reg['status'] ?? 'pending').toString();
    final name   = (reg['user_name'] ?? reg['user_id'] ?? '?').toString();
    final email  = (reg['user_email'] ?? '').toString();
    final avatar = (reg['user_avatar'] ?? '').toString();
    final regTs  = reg['registered_at'];

    // ── Date formatted according to language ─────────────────────────────
    String dateStr = '';
    if (regTs is Timestamp) {
      final d = regTs.toDate();
      if (_isJa) {
        dateStr = '${d.month}月${d.day}日';
      } else {
        const mo = ['Jan','Feb','Mar','Apr','May','Jun',
          'Jul','Aug','Sep','Oct','Nov','Dec'];
        dateStr = '${mo[d.month - 1]} ${d.day}';
      }
    }

    Color statusColor;
    String statusLabel;
    if (status == 'approved') {
      statusColor = _C.approved;
      statusLabel = _t('Approved', '承認済み');
    } else if (status == 'rejected') {
      statusColor = _C.rejected;
      statusLabel = _t('Rejected', '却下');
    } else {
      statusColor = _C.pending;
      statusLabel = _t('Pending', '審査中');
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _C.accent.withOpacity(0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.accent.withOpacity(0.1)),
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: Colors.black.withOpacity(0.08),
          backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
          child: avatar.isEmpty
              ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(color: _C.accent, fontWeight: FontWeight.w800))
              : null,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700, color: _C.textPri),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              if (email.isNotEmpty)
                Text(email,
                    style: TextStyle(fontSize: 11, color: _C.textMuted),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              Row(children: [
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(statusLabel,
                      style: TextStyle(
                          fontSize: 9, fontWeight: FontWeight.w900, color: statusColor)),
                ),
                if (dateStr.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Text(dateStr,
                      style: TextStyle(
                          fontSize: 9, color: _C.textDim, fontWeight: FontWeight.w600)),
                ],
              ]),
            ],
          ),
        ),
        const SizedBox(width: 8),
        if (isUpdating)
          const SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(
                  color: Color(0xFF6366F1), strokeWidth: 2))
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (status != 'approved')
                _ActionBtn(
                    label: _t('Approve', '承認'), color: _C.approved, onTap: onApprove),
              if (status != 'rejected') ...[
                if (status != 'approved') const SizedBox(height: 4),
                _ActionBtn(
                    label: _t('Reject', '却下'), color: _C.rejected, onTap: onReject),
              ],
            ],
          ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small shared widgets
// ─────────────────────────────────────────────────────────────────────────────
class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  const _Pill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withOpacity(0.15),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.35)),
    ),
    child: Text(label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
  );
}

class _StatPill extends StatelessWidget {
  final String label;
  final Color color;
  const _StatPill(this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color)),
  );
}

class _FilterTab extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  const _FilterTab({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: selected
            ? const Color(0xFF6366F1).withOpacity(0.15)
            : Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: selected
                ? const Color(0xFF6366F1).withOpacity(0.4)
                : Colors.black.withOpacity(0.07)),
      ),
      child: Text(
        '$label ($count)',
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700,
            color: selected
                ? Colors.black.withOpacity(0.85)
                : Colors.black.withOpacity(0.4)),
      ),
    ),
  );
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color)),
    ),
  );
}