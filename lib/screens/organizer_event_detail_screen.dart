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
  static const waitlist  = Color(0xFFB05A00);
  static const waitlistBg = Color(0xFFFFF3E0);
  static const capacityFull = Color(0xFFB0193A);
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

// ─────────────────────────────────────────────────────────────────────────────
// Registration counts — fetched via getCountFromServer (no doc reads)
// ─────────────────────────────────────────────────────────────────────────────
class _RegCounts {
  final int total, approved, pending, rejected, waitlist;
  const _RegCounts({
    this.total = 0,
    this.approved = 0,
    this.pending = 0,
    this.rejected = 0,
    this.waitlist = 0,
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
  // ── Counts ────────────────────────────────────────────────────────────────
  _RegCounts _counts = const _RegCounts();
  bool _loadingCounts = true;

  // ── Paginated registration list ───────────────────────────────────────────
  static const int _pageSize = 15;
  final List<Map<String, dynamic>> _regs = [];
  DocumentSnapshot? _lastDoc;
  bool _hasMore = false;
  bool _loadingPage = false;
  bool _loadingFirst = true;

  // ── Filter ────────────────────────────────────────────────────────────────
  // Values: 'all' | 'pending' | 'approved' | 'rejected' | 'waitlist'
  String _regFilter = 'all';

  // ── Optimistic update tracking ────────────────────────────────────────────
  String? _updatingId;

  // ── Capacity confirm dialog ───────────────────────────────────────────────
  // Holds {regId, approved, limit} when we need to show the over-capacity warning
  Map<String, dynamic>? _capacityConfirmTarget;

  // ─────────────────────────────────────────────────────────────────────────
  // Derived helpers
  // ─────────────────────────────────────────────────────────────────────────

  int get _eventLimit {
    final v = widget.data['event_limit'];
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  bool get _hasLimit => _eventLimit > 0;

  bool get _isFull => _hasLimit && _counts.approved >= _eventLimit;

  double get _fillPct =>
      (_hasLimit && _eventLimit > 0) ? (_counts.approved / _eventLimit).clamp(0.0, 1.0) : 0.0;

  Color get _fillColor {
    if (_fillPct >= 0.9) return _C.capacityFull;
    if (_fillPct >= 0.7) return const Color(0xFFB05A00);
    return _C.approved;
  }

  List<Map<String, dynamic>> get _filtered {
    if (_regFilter == 'all') return _regs;
    return _regs.where((r) => (r['status'] ?? 'pending') == _regFilter).toList();
  }

  // Main list = non-waitlist; shown first in "all" view
  List<Map<String, dynamic>> get _mainList =>
      _regs.where((r) => (r['status'] ?? 'pending') != 'waitlist').toList();

  List<Map<String, dynamic>> get _waitlistList =>
      _regs.where((r) => (r['status'] ?? 'pending') == 'waitlist').toList();

  // ─────────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _fetchCounts();
    _loadFirstPage();
  }

  // ── 1. Fetch counts with count() ──────────────────────────────────────────
  Future<void> _fetchCounts() async {
    try {
      final base = FirebaseFirestore.instance
          .collection('event_registrations')
          .where('event_id', isEqualTo: widget.eventId);

      final results = await Future.wait<AggregateQuerySnapshot>([
        base.count().get(),
        base.where('status', isEqualTo: 'approved').count().get(),
        base.where('status', isEqualTo: 'rejected').count().get(),
        base.where('status', isEqualTo: 'waitlist').count().get(),
      ]);

      final total    = results[0].count ?? 0;
      final approved = results[1].count ?? 0;
      final rejected = results[2].count ?? 0;
      final waitlist = results[3].count ?? 0;
      final pending  = total - approved - rejected - waitlist;

      if (mounted) {
        setState(() {
          _counts = _RegCounts(
            total:    total,
            approved: approved,
            pending:  pending < 0 ? 0 : pending,
            rejected: rejected,
            waitlist: waitlist,
          );
          _loadingCounts = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingCounts = false);
    }
  }

  // ── 2. Load first page ────────────────────────────────────────────────────
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
          _regs.addAll(snap.docs.map((d) => {'_id': d.id, ...d.data()}).toList());
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
          _regs.addAll(snap.docs.map((d) => {'_id': d.id, ...d.data()}).toList());
          _lastDoc = snap.docs.isNotEmpty ? snap.docs.last : null;
          _hasMore = snap.docs.length == _pageSize;
          _loadingPage = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingPage = false);
    }
  }

  // ── 4. Status update — mirrors web updateRegistrationStatus ───────────────
  Future<void> _updateStatus(String regId, String status, {bool bypassCapacityCheck = false}) async {
    // Capacity guard: if approving and at/over limit, show confirm dialog first
    if (status == 'approved' && _hasLimit && !bypassCapacityCheck) {
      final reg = _regs.firstWhere((r) => r['_id'] == regId, orElse: () => {});
      final prevStatus = (reg['status'] ?? 'pending') as String;
      if (prevStatus != 'approved' && _counts.approved >= _eventLimit) {
        setState(() {
          _capacityConfirmTarget = {
            'regId': regId,
            'approved': _counts.approved,
            'limit': _eventLimit,
          };
        });
        return;
      }
    }

    setState(() => _updatingId = regId);
    try {
      await FirebaseFirestore.instance
          .collection('event_registrations')
          .doc(regId)
          .update({
        'status':     status,
        'updated_at': FieldValue.serverTimestamp(),
      });

      // Auto-waitlist remaining pending if we just filled the last slot
      if (status == 'approved' && _hasLimit) {
        final newApproved = _counts.approved + 1;
        if (newApproved >= _eventLimit) {
          final pendingOthers = _regs
              .where((r) => r['_id'] != regId && (r['status'] ?? 'pending') == 'pending')
              .toList();
          for (final pending in pendingOthers) {
            await FirebaseFirestore.instance
                .collection('event_registrations')
                .doc(pending['_id'] as String)
                .update({'status': 'waitlist', 'updated_at': FieldValue.serverTimestamp()});
          }
        }
      }

      setState(() {
        final idx = _regs.indexWhere((r) => r['_id'] == regId);
        if (idx != -1) {
          final old = (_regs[idx]['status'] ?? 'pending') as String;
          _regs[idx] = {..._regs[idx], 'status': status};

          // Auto-waitlist locally
          if (status == 'approved' && _hasLimit) {
            final newApproved = _counts.approved + (old == 'approved' ? 0 : 1);
            if (newApproved >= _eventLimit) {
              for (int i = 0; i < _regs.length; i++) {
                if (_regs[i]['_id'] != regId && (_regs[i]['status'] ?? 'pending') == 'pending') {
                  _regs[i] = {..._regs[i], 'status': 'waitlist'};
                }
              }
            }
          }

          // Update counts optimistically
          int newApproved = _counts.approved;
          int newPending  = _counts.pending;
          int newRejected = _counts.rejected;
          int newWaitlist = _counts.waitlist;

          // Subtract from old bucket
          if (old == 'approved')  newApproved--;
          else if (old == 'pending')   newPending--;
          else if (old == 'rejected')  newRejected--;
          else if (old == 'waitlist')  newWaitlist--;

          // Add to new bucket
          if (status == 'approved')  newApproved++;
          else if (status == 'pending')   newPending++;
          else if (status == 'rejected')  newRejected++;
          else if (status == 'waitlist')  newWaitlist++;

          // Pending → waitlist for auto-promoted items
          if (status == 'approved' && _hasLimit && newApproved >= _eventLimit) {
            final pendingCount = _regs.where((r) => r['_id'] != regId && (r['status'] ?? '') == 'pending').length;
            // Already updated above in _regs loop, so recalculate from _regs
            newPending  = _regs.where((r) => (r['status'] ?? 'pending') == 'pending').length;
            newWaitlist = _regs.where((r) => (r['status'] ?? '') == 'waitlist').length;
          }

          _counts = _RegCounts(
            total:    _counts.total,
            approved: newApproved.clamp(0, _counts.total),
            pending:  newPending.clamp(0, _counts.total),
            rejected: newRejected.clamp(0, _counts.total),
            waitlist: newWaitlist.clamp(0, _counts.total),
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
    final limitVal   = _eventLimit;
    final limitStr   = limitVal > 0 ? '$limitVal' : _t('No limit', '制限なし');
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
                title:      _title,
                isApproved: isApproved,
                counts:     _counts,
                loading:    _loadingCounts,
                lang:       lang,
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
                mainList:      _mainList,
                waitlistList:  _waitlistList,
                filter:        _regFilter,
                loading:       _loadingFirst,
                loadingMore:   _loadingPage,
                hasMore:       _hasMore,
                updatingId:    _updatingId,
                counts:        _counts,
                countsLoading: _loadingCounts,
                lang:          lang,
                eventLimit:    _eventLimit,
                isFull:        _isFull,
                fillPct:       _fillPct,
                fillColor:     _fillColor,
                onFilter:      (f) => setState(() => _regFilter = f),
                onApprove:     (id) => _updateStatus(id, 'approved'),
                onReject:      (id) => _updateStatus(id, 'rejected'),
                onLoadMore:    _loadMorePage,
              );
            },
          ),

          // ── CAPACITY CONFIRM DIALOG ────────────────────────────────────
          if (_capacityConfirmTarget != null)
            _CapacityConfirmOverlay(
              approvedCount: _capacityConfirmTarget!['approved'] as int,
              limit:         _capacityConfirmTarget!['limit'] as int,
              lang:          lang,
              onCancel: () => setState(() => _capacityConfirmTarget = null),
              onConfirm: () {
                final regId = _capacityConfirmTarget!['regId'] as String;
                setState(() => _capacityConfirmTarget = null);
                _updateStatus(regId, 'approved', bypassCapacityCheck: true);
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
// _CapacityConfirmOverlay — shown when approving over the limit
// Mirrors the web app capacityConfirmTarget dialog
// ─────────────────────────────────────────────────────────────────────────────
class _CapacityConfirmOverlay extends StatelessWidget {
  final int approvedCount, limit;
  final String lang;
  final VoidCallback onCancel, onConfirm;

  const _CapacityConfirmOverlay({
    required this.approvedCount,
    required this.limit,
    required this.lang,
    required this.onCancel,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final isJa = lang == 'ja';
    return Material(
      color: Colors.black54,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBF0),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _C.waitlist.withOpacity(0.4)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 28, offset: const Offset(0, 8))],
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      color: _C.waitlist.withOpacity(0.12),
                      shape: BoxShape.circle,
                      border: Border.all(color: _C.waitlist.withOpacity(0.3)),
                    ),
                    child: const Icon(Icons.warning_amber_rounded, color: _C.waitlist, size: 26),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    isJa ? '定員超過の確認' : 'Capacity Warning',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _C.textPri),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.black.withOpacity(0.06)),
                    ),
                    child: Text(
                      isJa
                          ? 'イベントは満員 ($approvedCount/$limit) です。本当に承認しますか？（定員を超過します）'
                          : 'Event is at capacity ($approvedCount/$limit). Approve anyway? (will exceed limit)',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13, color: _C.textMuted, height: 1.5),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: onCancel,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.black.withOpacity(0.1)),
                          ),
                          child: Text(
                            isJa ? 'キャンセル' : 'Cancel',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _C.textMuted),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: onConfirm,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          decoration: BoxDecoration(
                            color: _C.waitlist,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            isJa ? '承認する' : 'Approve Anyway',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _RegSheet — draggable bottom sheet with capacity bar + waitlist section
// ─────────────────────────────────────────────────────────────────────────────
class _RegSheet extends StatelessWidget {
  final ScrollController scrollController;
  final List<Map<String, dynamic>> regs, filtered, mainList, waitlistList;
  final String filter, lang;
  final bool loading, loadingMore, hasMore, countsLoading;
  final String? updatingId;
  final _RegCounts counts;
  final int eventLimit;
  final bool isFull;
  final double fillPct;
  final Color fillColor;
  final ValueChanged<String> onFilter;
  final ValueChanged<String> onApprove;
  final ValueChanged<String> onReject;
  final VoidCallback onLoadMore;

  const _RegSheet({
    required this.scrollController,
    required this.regs,
    required this.filtered,
    required this.mainList,
    required this.waitlistList,
    required this.filter,
    required this.lang,
    required this.loading,
    required this.loadingMore,
    required this.hasMore,
    required this.countsLoading,
    required this.updatingId,
    required this.counts,
    required this.eventLimit,
    required this.isFull,
    required this.fillPct,
    required this.fillColor,
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
                      // Title + stat pills
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
                          if (counts.waitlist > 0) ...[
                            const SizedBox(width: 5),
                            _StatPill('${counts.waitlist} ⏳', _C.waitlist),
                          ],
                        ],
                      ]),

                      // ── Capacity bar (only when event has a limit) ───────
                      if (eventLimit > 0) ...[
                        const SizedBox(height: 10),
                        _CapacityBar(
                          approvedCount: counts.approved,
                          limit:         eventLimit,
                          waitlistCount: counts.waitlist,
                          isFull:        isFull,
                          fillPct:       fillPct,
                          fillColor:     fillColor,
                          lang:          lang,
                        ),
                      ],

                      const SizedBox(height: 10),
                      // ── Filter tabs ──────────────────────────────────────
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
                          // Waitlist tab — always shown, grayed when 0
                          const SizedBox(width: 6),
                          _FilterTab(
                            label: _t('Waitlist', 'ウェイティング'),
                            count: counts.waitlist,
                            selected: filter == 'waitlist',
                            onTap: () => onFilter('waitlist'),
                            accentColor: _C.waitlist,
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
          else if (filter == 'all' && regs.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Text(
                  _t('No registrations yet.', 'まだ登録者がいません。'),
                  style: TextStyle(fontSize: 13, color: _C.textMuted),
                ),
              ),
            )
          // ── "All" view: main list then waitlist section ──────────────────
          else if (filter == 'all')
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, i) {
                      // Total items = mainList + (divider row) + waitlistList + load-more
                      final mainCount = mainList.length;
                      final hasWaitlist = waitlistList.isNotEmpty;
                      final dividerIdx = hasWaitlist ? mainCount : -1;
                      final waitlistStart = hasWaitlist ? mainCount + 1 : -1;
                      final waitlistEnd   = hasWaitlist ? mainCount + 1 + waitlistList.length : -1;
                      final loadMoreIdx   = hasWaitlist ? waitlistEnd : mainCount;

                      if (i < mainCount) {
                        // Main registrant row
                        final r = mainList[i];
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
                      } else if (i == dividerIdx) {
                        // ── Waitlist section divider ─────────────────────────
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(children: [
                            Expanded(child: Divider(color: _C.waitlist.withOpacity(0.3), height: 1)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: _C.waitlistBg,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: _C.waitlist.withOpacity(0.35)),
                              ),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                const Text('⏳', style: TextStyle(fontSize: 10)),
                                const SizedBox(width: 4),
                                Text(
                                  '${_t('WAITING LIST', 'ウェイティングリスト')} (${waitlistList.length})',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: _C.waitlist, letterSpacing: 0.3),
                                ),
                              ]),
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Divider(color: _C.waitlist.withOpacity(0.3), height: 1)),
                          ]),
                        );
                      } else if (hasWaitlist && i >= waitlistStart && i < waitlistEnd) {
                        // Waitlist row
                        final r = waitlistList[i - waitlistStart];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _RegRow(
                            reg:        r,
                            lang:       lang,
                            isUpdating: updatingId == r['_id'],
                            onApprove:  () => onApprove(r['_id'] as String),
                            onReject:   () => onReject(r['_id'] as String),
                            isWaitlist: true,
                          ),
                        );
                      } else if (i == loadMoreIdx) {
                        // Load-more / end row
                        return _LoadMoreRow(
                          loading:  loadingMore,
                          hasMore:  hasMore,
                          total:    regs.length,
                          lang:     lang,
                          onTap:    onLoadMore,
                        );
                      }
                      return null;
                    },
                    childCount: mainList.length +
                        (waitlistList.isNotEmpty ? 1 + waitlistList.length : 0) +
                        1, // +1 for load-more/end row
                  ),
                ),
              )
            // ── Filtered view (pending / approved / rejected / waitlist) ─────
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
                          final isWL = (r['status'] ?? 'pending') == 'waitlist';
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _RegRow(
                              reg:        r,
                              lang:       lang,
                              isUpdating: updatingId == r['_id'],
                              onApprove:  () => onApprove(r['_id'] as String),
                              onReject:   () => onReject(r['_id'] as String),
                              isWaitlist: isWL,
                            ),
                          );
                        }
                        return _LoadMoreRow(
                          loading:  loadingMore,
                          hasMore:  hasMore,
                          total:    regs.length,
                          lang:     lang,
                          onTap:    onLoadMore,
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
// _CapacityBar — mirrors the web app capacity progress bar + "CAPACITY FULL"
// ─────────────────────────────────────────────────────────────────────────────
class _CapacityBar extends StatelessWidget {
  final int approvedCount, limit, waitlistCount;
  final bool isFull;
  final double fillPct;
  final Color fillColor;
  final String lang;

  const _CapacityBar({
    required this.approvedCount,
    required this.limit,
    required this.waitlistCount,
    required this.isFull,
    required this.fillPct,
    required this.fillColor,
    required this.lang,
  });

  @override
  Widget build(BuildContext context) {
    final isJa = lang == 'ja';
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: isFull ? _C.capacityFull.withOpacity(0.05) : _C.accent.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isFull ? _C.capacityFull.withOpacity(0.3) : _C.accent.withOpacity(0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Slots label row
          Row(
            children: [
              Text(
                isJa ? '$approvedCount / $limit 枠埋まり' : '$approvedCount / $limit slots filled',
                style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700,
                  color: isFull ? _C.capacityFull : _C.textMuted,
                ),
              ),
              const Spacer(),
              if (isFull)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: _C.capacityFull.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _C.capacityFull.withOpacity(0.4)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.lock_rounded, size: 11, color: _C.capacityFull),
                    const SizedBox(width: 4),
                    Text(
                      isJa ? '定員に達しました' : 'CAPACITY FULL',
                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: _C.capacityFull, letterSpacing: 0.4),
                    ),
                  ]),
                )
              else
                Text(
                  '${(fillPct * 100).round()}%',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: fillColor),
                ),
            ],
          ),
          const SizedBox(height: 6),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fillPct,
              minHeight: 5,
              backgroundColor: Colors.black.withOpacity(0.07),
              valueColor: AlwaysStoppedAnimation<Color>(
                isFull ? _C.capacityFull : fillColor,
              ),
            ),
          ),
          // Waitlist note
          if (waitlistCount > 0) ...[
            const SizedBox(height: 6),
            Row(children: [
              const Text('⏳', style: TextStyle(fontSize: 11)),
              const SizedBox(width: 4),
              Text(
                isJa ? '$waitlistCount 名がウェイティング中' : '$waitlistCount on waitlist',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _C.waitlist),
              ),
            ]),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _LoadMoreRow — reusable load-more / end of list widget
// ─────────────────────────────────────────────────────────────────────────────
class _LoadMoreRow extends StatelessWidget {
  final bool loading, hasMore;
  final int total;
  final String lang;
  final VoidCallback onTap;

  const _LoadMoreRow({
    required this.loading,
    required this.hasMore,
    required this.total,
    required this.lang,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: loading
          ? const Center(
          child: SizedBox(
              width: 22, height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: _C.accent)))
          : hasMore
          ? GestureDetector(
        onTap: onTap,
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
                lang == 'ja' ? 'もっと読み込む' : 'Load more',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _C.accent.withOpacity(0.85)),
              ),
              const SizedBox(width: 6),
              Icon(Icons.expand_more_rounded, size: 16, color: _C.accent.withOpacity(0.7)),
            ],
          ),
        ),
      )
          : Center(
        child: Text(
          lang == 'ja' ? '$total件 表示中' : 'Showing $total of $total',
          style: TextStyle(fontSize: 11, color: _C.textDim),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _TopBar
// ─────────────────────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final String title;
  final bool isApproved, loading;
  final _RegCounts counts;
  final String lang;
  const _TopBar({
    required this.title,
    required this.isApproved,
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
// _RegRow — single registrant card; waitlist variant has amber styling
// ─────────────────────────────────────────────────────────────────────────────
class _RegRow extends StatelessWidget {
  final Map<String, dynamic> reg;
  final String lang;
  final bool isUpdating;
  final bool isWaitlist;
  final VoidCallback onApprove, onReject;
  const _RegRow({
    required this.reg,
    required this.lang,
    required this.isUpdating,
    required this.onApprove,
    required this.onReject,
    this.isWaitlist = false,
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

    String dateStr = '';
    if (regTs is Timestamp) {
      final d = regTs.toDate();
      dateStr = _isJa ? '${d.month}月${d.day}日' : _shortMonth(d.month) + ' ${d.day}';
    }

    Color statusColor;
    String statusLabel;
    Color rowBg;
    Color rowBorder;

    if (status == 'waitlist') {
      statusColor = _C.waitlist;
      statusLabel = _t('Waitlist', 'ウェイティング');
      rowBg       = _C.waitlistBg.withOpacity(0.5);
      rowBorder   = _C.waitlist.withOpacity(0.18);
    } else if (status == 'approved') {
      statusColor = _C.approved;
      statusLabel = _t('Approved', '承認済み');
      rowBg       = _C.accent.withOpacity(0.03);
      rowBorder   = _C.accent.withOpacity(0.1);
    } else if (status == 'rejected') {
      statusColor = _C.rejected;
      statusLabel = _t('Rejected', '却下');
      rowBg       = _C.accent.withOpacity(0.03);
      rowBorder   = _C.accent.withOpacity(0.1);
    } else {
      statusColor = _C.pending;
      statusLabel = _t('Pending', '審査中');
      rowBg       = _C.accent.withOpacity(0.03);
      rowBorder   = _C.accent.withOpacity(0.1);
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: rowBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: rowBorder),
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

  String _shortMonth(int m) {
    const mo = ['Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'];
    return mo[m - 1];
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
  final Color? accentColor;

  const _FilterTab({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final selColor = accentColor ?? const Color(0xFF6366F1);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? selColor.withOpacity(0.15)
              : Colors.black.withOpacity(0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: selected
                  ? selColor.withOpacity(0.4)
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