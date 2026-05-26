import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pikuru/theme/material.dart';
import 'package:pikuru/providers/app_language_provider.dart';
import 'package:pikuru/screens/organizer_event_detail_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Localisation
// ─────────────────────────────────────────────────────────────────────────────
const _L = {
  kLangEn: {
    'title':           'Organizer Dashboard',
    'sub':             'Manage your events, groups and registrations.',
    'myEvents':        'My Events',
    'myGroups':        'My Groups',
    'registered':      'Registered',
    'auditLog':        'Audit Log',
    'noEvents':        'You have not created any events yet.',
    'noGroups':        'You have not created any groups yet.',
    'noRegistered':    'You have not registered for any events yet.',
    'noAudit':         'No actions recorded yet.',
    'pending':         'Pending',
    'approved':        'Approved',
    'rejected':        'Rejected',
    'active':          'Active',
    'inactive':        'Inactive',
    'public':          'Public',
    'private':         'Private',
    'free':            'Free',
    'edit':            'Edit',
    'viewDetails':     'View Details',
    'registrants':     'Registrants',
    'openChannel':     'Chat Channel',
    'regApproved':     'Approved',
    'regPending':      'Pending',
    'regRejected':     'Rejected',
    'views':           'Views',
    'noLimit':         'No limit',
    'date':            'Date',
    'fee':             'Fee',
    'limit':           'Limit',
    'type':            'Type',
    'loadMore':        'Load more',
  },
  kLangJa: {
    'title':           'オーガナイザーダッシュボード',
    'sub':             'イベント・グループ・登録を管理しましょう。',
    'myEvents':        'マイイベント',
    'myGroups':        'マイグループ',
    'registered':      '登録済み',
    'auditLog':        '監査ログ',
    'noEvents':        'まだイベントを作成していません。',
    'noGroups':        'まだグループを作成していません。',
    'noRegistered':    'まだイベントに登録していません。',
    'noAudit':         'まだ記録がありません。',
    'pending':         '承認待ち',
    'approved':        '承認済み',
    'rejected':        '却下',
    'active':          'アクティブ',
    'inactive':        '非アクティブ',
    'public':          '公開',
    'private':         '非公開',
    'free':            '無料',
    'edit':            '編集',
    'viewDetails':     '詳細を見る',
    'registrants':     '登録者',
    'openChannel':     'チャット',
    'regApproved':     '承認済み',
    'regPending':      '審査中',
    'regRejected':     '却下',
    'views':           '閲覧',
    'noLimit':         '制限なし',
    'date':            '日付',
    'fee':             '参加費',
    'limit':           '定員',
    'type':            'タイプ',
    'loadMore':        'もっと見る',
  },
};

String _t(String lang, String key) =>
    _L[lang]?[key] ?? _L[kLangEn]![key]!;

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────
String _fmtDate(dynamic ts, {bool compact = false}) {
  if (ts == null) return '—';
  DateTime d;
  if (ts is Timestamp) {
    d = ts.toDate();
  } else {
    return '—';
  }
  if (compact) {
    return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
  }
  const months = ['Jan','Feb','Mar','Apr','May','Jun',
    'Jul','Aug','Sep','Oct','Nov','Dec'];
  return '${months[d.month - 1]} ${d.day}, ${d.year}';
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
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
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
            color: Colors.white,
            child: TabBar(
              controller: _tabs,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              labelColor: AppColors.primary,
              unselectedLabelColor: Colors.grey.shade500,
              labelStyle: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700),
              unselectedLabelStyle: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w500),
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
  final String uid;
  final String lang;
  const _MyEventsTab({required this.uid, required this.lang});

  @override
  State<_MyEventsTab> createState() => _MyEventsTabState();
}

class _MyEventsTabState extends State<_MyEventsTab> {
  // Map<eventId, {views, regs, pending, approved}>
  final Map<String, Map<String, int>> _metrics = {};

  Future<void> _loadMetrics(List<QueryDocumentSnapshot> docs) async {
    for (final doc in docs) {
      final id = doc.id;
      if (_metrics.containsKey(id)) continue;
      final data = doc.data() as Map<String, dynamic>;
      final views = (data['event_view_count'] ?? 0) as int;
      try {
        final allSnap = await FirebaseFirestore.instance
            .collection('event_registrations')
            .where('event_id', isEqualTo: id)
            .count()
            .get();
        final pendingSnap = await FirebaseFirestore.instance
            .collection('event_registrations')
            .where('event_id', isEqualTo: id)
            .where('status', isEqualTo: 'pending')
            .count()
            .get();
        final approvedSnap = await FirebaseFirestore.instance
            .collection('event_registrations')
            .where('event_id', isEqualTo: id)
            .where('status', isEqualTo: 'approved')
            .count()
            .get();
        if (mounted) {
          setState(() {
            _metrics[id] = {
              'views':    views,
              'regs':     allSnap.count ?? 0,
              'pending':  pendingSnap.count ?? 0,
              'approved': approvedSnap.count ?? 0,
            };
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() => _metrics[id] = {
            'views': views, 'regs': 0, 'pending': 0, 'approved': 0
          });
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

        // Fire metric loading (non-blocking)
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
            final id   = docs[i].id;
            final m    = _metrics[id];
            return _EventCard(
                eventId: id, data: data, lang: widget.lang, metrics: m);
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
  final String eventId;
  final Map<String, dynamic> data;
  final String lang;
  final Map<String, int>? metrics;

  const _EventCard({
    required this.eventId,
    required this.data,
    required this.lang,
    this.metrics,
  });

  @override
  Widget build(BuildContext context) {
    final isPending  = data['event_pending_review'] == true &&
        data['event_checked'] != true;
    final isApproved = data['event_checked'] == true &&
        data['event_pending_review'] != true;
    final isRejected = data['rejected'] == true;

    final title = lang == 'ja'
        ? (data['event_title_jp'] ?? data['event_title'] ?? 'Untitled')
        .toString()
        : (data['event_title'] ?? 'Untitled').toString();

    final desc = lang == 'ja'
        ? (data['event_description_jp'] ??
        data['event_description_en'] ?? '')
        .toString()
        : (data['event_description_en'] ?? '').toString();

    final imgUrl = (data['event_pic'] ?? data['event_pic_thumbnail'] ?? '')
        .toString();

    final feeRaw = (data['event_fee'] ?? '').toString();
    final fee    = (feeRaw.isEmpty || feeRaw == '0')
        ? _t(lang, 'free')
        : '¥$feeRaw';

    final dateStr  = _fmtDate(data['event_date'], compact: true);
    final eventType = (data['event_type'] ?? '').toString();

    Color statusColor;
    Color statusBg;
    String statusLabel;
    IconData statusIcon;

    if (isApproved) {
      statusColor = const Color(0xFF2D7D46);
      statusBg    = const Color(0xFFEDF7EF);
      statusLabel = _t(lang, 'approved');
      statusIcon  = Icons.check_circle_rounded;
    } else if (isRejected) {
      statusColor = const Color(0xFFD32F2F);
      statusBg    = const Color(0xFFFFEBEE);
      statusLabel = _t(lang, 'rejected');
      statusIcon  = Icons.cancel_rounded;
    } else {
      statusColor = const Color(0xFFF57C00);
      statusBg    = const Color(0xFFFFF3E0);
      statusLabel = _t(lang, 'pending');
      statusIcon  = Icons.schedule_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Cover image ──────────────────────────────────────────────
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20)),
            child: Stack(
              children: [
                imgUrl.isNotEmpty
                    ? Image.network(
                  imgUrl,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _coverPlaceholder(),
                )
                    : _coverPlaceholder(),
                // Status badge
                Positioned(
                  top: 12, left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: statusBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: statusColor.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 12, color: statusColor),
                        const SizedBox(width: 4),
                        Text(statusLabel,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: statusColor)),
                      ],
                    ),
                  ),
                ),
                // Type badge
                if (eventType.isNotEmpty)
                  Positioned(
                    top: 12, right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(eventType,
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                    ),
                  ),
              ],
            ),
          ),

          // ── Body ────────────────────────────────────────────────────
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

                // Meta chips
                Wrap(
                  spacing: 8, runSpacing: 6,
                  children: [
                    _MetaChip(
                        icon: Icons.calendar_today_rounded,
                        label: dateStr),
                    _MetaChip(
                        icon: Icons.attach_money_rounded,
                        label: fee),
                    if ((data['event_limit'] ?? 0) > 0)
                      _MetaChip(
                          icon: Icons.people_rounded,
                          label: '${data['event_limit']}'),
                  ],
                ),

                // ── Metrics strip ────────────────────────────────────
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
                            color: const Color(0xFFF57C00)),
                      ],
                    ]),
                  ),
                ],

                const SizedBox(height: 14),

                // ── Action buttons ───────────────────────────────────
                if (isPending)
                  _ActionButton(
                      icon: Icons.edit_rounded,
                      label: _t(lang, 'edit'),
                      color: AppColors.primary,
                      onTap: () => _showEditDialog(
                          context, eventId, data, lang))
                else
                  Column(
                    children: [
                      _ActionButton(
                          icon: Icons.remove_red_eye_rounded,
                          label: _t(lang, 'viewDetails'),
                          color: AppColors.primary,
                          onTap: () => _showEventDetail(
                              context, eventId, data, lang)),
                      if (isApproved) ...[
                        const SizedBox(height: 8),
                        Row(children: [
                          Expanded(
                            child: _ActionButton(
                                icon: Icons.chat_bubble_rounded,
                                label: _t(lang, 'openChannel'),
                                color: const Color(0xFF5C6BC0),
                                outlined: true,
                                onTap: () {}),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _ActionButton(
                                icon: Icons.people_rounded,
                                label: _t(lang, 'registrants'),
                                color: AppColors.primary,
                                outlined: true,
                                onTap: () => _showRegistrants(
                                    context, eventId, data, lang)),
                          ),
                        ]),
                      ],
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
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
    width: 1, height: 28,
    margin: const EdgeInsets.symmetric(horizontal: 12),
    color: AppColors.primary.withOpacity(0.15),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Edit event dialog (pending only)
// ─────────────────────────────────────────────────────────────────────────────
void _showEditDialog(BuildContext context, String eventId,
    Map<String, dynamic> data, String lang) {
  final titleCtrl = TextEditingController(
      text: (data['event_title'] ?? '').toString());
  final descCtrl  = TextEditingController(
      text: (data['event_description_en'] ?? '').toString());
  final feeCtrl   = TextEditingController(
      text: (data['event_fee'] ?? '').toString());
  bool saving = false;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => StatefulBuilder(builder: (ctx, setS) {
      return Container(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
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
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
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
                    } catch (e) {
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
            ],
          ),
        ),
      );
    }),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Event detail bottom sheet (approved / rejected)
// ─────────────────────────────────────────────────────────────────────────────
void _showEventDetail(BuildContext context, String eventId,
    Map<String, dynamic> data, String lang) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => OrganizerEventDetailScreen(
        eventId: eventId,
        data:    data,
        lang:    lang,
      ),
    ),
  );
}
// ─────────────────────────────────────────────────────────────────────────────
// Registrants bottom sheet
// ─────────────────────────────────────────────────────────────────────────────
void _showRegistrants(BuildContext context, String eventId,
    Map<String, dynamic> data, String lang) {
  final title = lang == 'ja'
      ? (data['event_title_jp'] ?? data['event_title'] ?? '').toString()
      : (data['event_title'] ?? '').toString();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      builder: (ctx, scroll) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(children: [
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Text(title,
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w800),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                    Text(_t(lang, 'registrants'),
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary)),
                  ],
                ),
                const Divider(height: 20),
              ]),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('event_registrations')
                    .where('event_id', isEqualTo: eventId)
                    .orderBy('registered_at', descending: true)
                    .limit(30)
                    .snapshots(),
                builder: (_, snap) {
                  if (!snap.hasData) {
                    return const Center(
                        child: CircularProgressIndicator());
                  }
                  final regs = snap.data!.docs;
                  if (regs.isEmpty) {
                    return Center(
                        child: Text(_t(lang, 'noRegistered'),
                            style: TextStyle(
                                color: Colors.grey.shade500)));
                  }
                  return ListView.builder(
                    controller: scroll,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 8),
                    itemCount: regs.length,
                    itemBuilder: (_, i) {
                      final r =
                      regs[i].data() as Map<String, dynamic>;
                      final status =
                      (r['status'] ?? 'pending').toString();
                      final name =
                      (r['user_name'] ?? r['user_id'] ?? '?')
                          .toString();
                      final email =
                      (r['user_email'] ?? '').toString();
                      Color sc;
                      String sl;
                      if (status == 'approved') {
                        sc = const Color(0xFF2D7D46);
                        sl = _t(lang, 'regApproved');
                      } else if (status == 'rejected') {
                        sc = const Color(0xFFD32F2F);
                        sl = _t(lang, 'regRejected');
                      } else {
                        sc = const Color(0xFFF57C00);
                        sl = _t(lang, 'regPending');
                      }
                      return Container(
                        margin:
                        const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F8FA),
                          borderRadius:
                          BorderRadius.circular(14),
                        ),
                        child: Row(children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: AppColors.primary
                                .withOpacity(0.15),
                            child: Text(
                                name.isNotEmpty
                                    ? name[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight:
                                    FontWeight.w700)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Text(name,
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight:
                                        FontWeight.w700)),
                                if (email.isNotEmpty)
                                  Text(email,
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors
                                              .grey.shade500),
                                      maxLines: 1,
                                      overflow:
                                      TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                          // Status + actions
                          Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding:
                                const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3),
                                decoration: BoxDecoration(
                                  color: sc.withOpacity(0.1),
                                  borderRadius:
                                  BorderRadius.circular(8),
                                ),
                                child: Text(sl,
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: sc)),
                              ),
                              const SizedBox(height: 6),
                              // Approve / Reject
                              Row(children: [
                                if (status != 'approved')
                                  _MiniActionBtn(
                                    label: '✓',
                                    color: const Color(0xFF2D7D46),
                                    onTap: () async {
                                      await FirebaseFirestore
                                          .instance
                                          .collection(
                                          'event_registrations')
                                          .doc(regs[i].id)
                                          .update({
                                        'status': 'approved',
                                        'updated_at': FieldValue
                                            .serverTimestamp(),
                                      });
                                    },
                                  ),
                                if (status != 'rejected')
                                  _MiniActionBtn(
                                    label: '✕',
                                    color: const Color(0xFFD32F2F),
                                    onTap: () async {
                                      await FirebaseFirestore
                                          .instance
                                          .collection(
                                          'event_registrations')
                                          .doc(regs[i].id)
                                          .update({
                                        'status': 'rejected',
                                        'updated_at': FieldValue
                                            .serverTimestamp(),
                                      });
                                    },
                                  ),
                              ]),
                            ],
                          ),
                        ]),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// TAB 2 — MY GROUPS
// ═════════════════════════════════════════════════════════════════════════════
class _MyGroupsTab extends StatelessWidget {
  final String uid;
  final String lang;
  const _MyGroupsTab({required this.uid, required this.lang});

  @override
  Widget build(BuildContext context) {
    if (uid.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('organizations')
          .where('submittedBy', isEqualTo: uid)
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data!.docs;
        docs.sort((a, b) {
          final ta = (a.data() as Map)['org_added'];
          final tb = (b.data() as Map)['org_added'];
          final tA = ta is Timestamp ? ta.millisecondsSinceEpoch : 0;
          final tB = tb is Timestamp ? tb.millisecondsSinceEpoch : 0;
          return tB.compareTo(tA);
        });

        if (docs.isEmpty) {
          return _EmptyState(
              icon: Icons.group_rounded,
              message: _t(lang, 'noGroups'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final id   = docs[i].id;
            return _GroupCard(groupId: id, data: data, lang: lang);
          },
        );
      },
    );
  }
}

class _GroupCard extends StatelessWidget {
  final String groupId;
  final Map<String, dynamic> data;
  final String lang;
  const _GroupCard(
      {required this.groupId, required this.data, required this.lang});

  @override
  Widget build(BuildContext context) {
    final isApproved =
        data['org_checked'] == true && data['org_pending_review'] != true;
    final isRejected = data['rejected'] == true;
    final isPending  = !isApproved && !isRejected;
    final isActive   = data['org_active'] == true;
    final isPublic   = data['org_public'] != false;

    final name = lang == 'ja'
        ? (data['org_name_jp'] ?? data['org_name'] ?? 'Unnamed').toString()
        : (data['org_name'] ?? 'Unnamed').toString();
    final desc = lang == 'ja'
        ? (data['org_description_jp'] ?? data['org_description'] ?? '').toString()
        : (data['org_description'] ?? '').toString();
    final imgUrl = (data['org_image'] ?? '').toString();

    Color statusColor;
    Color statusBg;
    String statusLabel;
    IconData statusIcon;
    if (isApproved) {
      statusColor = const Color(0xFF2D7D46);
      statusBg    = const Color(0xFFEDF7EF);
      statusLabel = _t(lang, 'approved');
      statusIcon  = Icons.check_circle_rounded;
    } else if (isRejected) {
      statusColor = const Color(0xFFD32F2F);
      statusBg    = const Color(0xFFFFEBEE);
      statusLabel = _t(lang, 'rejected');
      statusIcon  = Icons.cancel_rounded;
    } else {
      statusColor = const Color(0xFFF57C00);
      statusBg    = const Color(0xFFFFF3E0);
      statusLabel = _t(lang, 'pending');
      statusIcon  = Icons.schedule_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cover
          ClipRRect(
            borderRadius:
            const BorderRadius.vertical(top: Radius.circular(20)),
            child: Stack(children: [
              imgUrl.isNotEmpty
                  ? Image.network(imgUrl,
                  height: 130,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      _groupPlaceholder())
                  : _groupPlaceholder(),
              Positioned(
                top: 12, left: 12,
                child: _Badge(
                    label: statusLabel,
                    icon: statusIcon,
                    color: statusColor,
                    bg: statusBg),
              ),
              if (isApproved)
                Positioned(
                  top: 12, right: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _Badge(
                          label: isActive
                              ? _t(lang, 'active')
                              : _t(lang, 'inactive'),
                          icon: isActive
                              ? Icons.check_rounded
                              : Icons.close_rounded,
                          color: isActive
                              ? const Color(0xFF2D7D46)
                              : const Color(0xFFD32F2F),
                          bg: isActive
                              ? const Color(0xFFEDF7EF)
                              : const Color(0xFFFFEBEE)),
                      const SizedBox(height: 4),
                      _Badge(
                          label: isPublic
                              ? _t(lang, 'public')
                              : _t(lang, 'private'),
                          icon: isPublic
                              ? Icons.public_rounded
                              : Icons.lock_rounded,
                          color: const Color(0xFF1565C0),
                          bg: const Color(0xFFE3F2FD)),
                    ],
                  ),
                ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                if (desc.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(desc,
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          height: 1.4),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
                if (isApproved) ...[
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(
                      child: _OutlineBtn(
                        label: isActive
                            ? (lang == 'ja'
                            ? '非アクティブにする'
                            : 'Deactivate')
                            : (lang == 'ja'
                            ? 'アクティブにする'
                            : 'Activate'),
                        color: isActive
                            ? const Color(0xFFD32F2F)
                            : const Color(0xFF2D7D46),
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
                            ? (lang == 'ja'
                            ? '非公開にする'
                            : 'Make Private')
                            : (lang == 'ja'
                            ? '公開する'
                            : 'Make Public'),
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

  Widget _groupPlaceholder() => Container(
    height: 130,
    width: double.infinity,
    color: Colors.grey.shade100,
    child: Icon(Icons.group_rounded,
        size: 48, color: Colors.grey.shade300),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// TAB 3 — REGISTERED EVENTS
// ═════════════════════════════════════════════════════════════════════════════
class _RegisteredTab extends StatefulWidget {
  final String uid;
  final String lang;
  const _RegisteredTab({required this.uid, required this.lang});

  @override
  State<_RegisteredTab> createState() => _RegisteredTabState();
}

class _RegisteredTabState extends State<_RegisteredTab> {
  List<Map<String, dynamic>> _events = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.uid.isEmpty) { setState(() => _loading = false); return; }
    try {
      final regSnap = await FirebaseFirestore.instance
          .collection('event_registrations')
          .where('user_id', isEqualTo: widget.uid)
          .limit(50)
          .get();
      if (regSnap.docs.isEmpty) {
        setState(() { _events = []; _loading = false; });
        return;
      }
      final results = await Future.wait(regSnap.docs.map((regDoc) async {
        final rd  = regDoc.data();
        final evId = (rd['event_id'] ?? '').toString();
        if (evId.isEmpty) return null;
        try {
          final evSnap = await FirebaseFirestore.instance
              .collection('events')
              .doc(evId)
              .get();
          if (!evSnap.exists) return null;
          return {
            ...evSnap.data()!,
            '_id':        evSnap.id,
            '_regStatus': (rd['status'] ?? 'pending').toString(),
            '_regDocId':  regDoc.id,
          };
        } catch (_) { return null; }
      }));
      setState(() {
        _events = results.whereType<Map<String, dynamic>>().toList();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_events.isEmpty) {
      return _EmptyState(
          icon: Icons.event_available_rounded,
          message: _t(widget.lang, 'noRegistered'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _events.length,
      itemBuilder: (_, i) {
        final ev     = _events[i];
        final status = (ev['_regStatus'] ?? 'pending').toString();
        final title  = widget.lang == 'ja'
            ? (ev['event_title_jp'] ?? ev['event_title'] ?? 'Untitled').toString()
            : (ev['event_title'] ?? 'Untitled').toString();
        final imgUrl = (ev['event_pic'] ?? '').toString();
        final date   = _fmtDate(ev['event_date'], compact: true);

        Color sc; String sl; IconData si;
        if (status == 'approved') {
          sc = const Color(0xFF2D7D46);
          sl = _t(widget.lang, 'regApproved');
          si = Icons.check_circle_rounded;
        } else if (status == 'rejected') {
          sc = const Color(0xFFD32F2F);
          sl = _t(widget.lang, 'regRejected');
          si = Icons.cancel_rounded;
        } else {
          sc = const Color(0xFFF57C00);
          sl = _t(widget.lang, 'regPending');
          si = Icons.schedule_rounded;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 14,
                  offset: const Offset(0, 3)),
            ],
          ),
          child: Row(children: [
            // Thumbnail
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(18)),
              child: imgUrl.isNotEmpty
                  ? Image.network(imgUrl,
                  width: 100, height: 90, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      _thumbPlaceholder())
                  : _thumbPlaceholder(),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Padding(
                padding:
                const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 5),
                    Row(children: [
                      Icon(Icons.calendar_today_rounded,
                          size: 12, color: Colors.grey.shade400),
                      const SizedBox(width: 4),
                      Text(date,
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500)),
                    ]),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: sc.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(si, size: 11, color: sc),
                          const SizedBox(width: 4),
                          Text(sl,
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: sc)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
          ]),
        );
      },
    );
  }

  Widget _thumbPlaceholder() => Container(
      width: 100, height: 90,
      color: Colors.grey.shade100,
      child: Icon(Icons.event_rounded,
          size: 32, color: Colors.grey.shade300));
}

// ═════════════════════════════════════════════════════════════════════════════
// TAB 4 — AUDIT LOG
// ═════════════════════════════════════════════════════════════════════════════
class _AuditLogTab extends StatelessWidget {
  final String uid;
  final String lang;
  const _AuditLogTab({required this.uid, required this.lang});

  @override
  Widget build(BuildContext context) {
    if (uid.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('audit_logs')
          .where('actor_id', isEqualTo: uid)
          .limit(100)
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return _EmptyState(
              icon: Icons.history_rounded,
              message: _t(lang, 'noAudit'));
        }
        // Sort newest first in memory
        docs.sort((a, b) {
          final ta = (a.data() as Map)['timestamp'];
          final tb = (b.data() as Map)['timestamp'];
          final tA = ta is Timestamp ? ta.millisecondsSinceEpoch : 0;
          final tB = tb is Timestamp ? tb.millisecondsSinceEpoch : 0;
          return tB.compareTo(tA);
        });

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final d      = docs[i].data() as Map<String, dynamic>;
            final action = (d['action'] ?? '').toString();
            final target = (d['target_name'] ?? '').toString();
            final detail = (d['details'] ?? '').toString();
            final ts     = d['timestamp'];
            final date   = ts is Timestamp
                ? _fmtDate(ts, compact: true)
                : '—';

            final meta = _auditMeta(action);

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 3)),
                ],
              ),
              child: Row(children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: meta['color'].withOpacity(0.1),
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
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: meta['color'] as Color,
                              letterSpacing: 0.3)),
                      Text(target,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      if (detail.isNotEmpty)
                        Text(detail,
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Text(date,
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade400)),
              ]),
            );
          },
        );
      },
    );
  }

  Map<String, dynamic> _auditMeta(String action) {
    switch (action) {
      case 'broadcast':
        return {
          'color': AppColors.primary,
          'icon': Icons.campaign_rounded,
          'label': lang == 'ja' ? '一斉送信' : 'Broadcast',
        };
      case 'replies_on':
        return {
          'color': AppColors.primary,
          'icon': Icons.chat_rounded,
          'label': lang == 'ja' ? '返信有効化' : 'Replies On',
        };
      case 'replies_off':
        return {
          'color': const Color(0xFFF57C00),
          'icon': Icons.do_not_disturb_rounded,
          'label': lang == 'ja' ? '返信無効化' : 'Replies Off',
        };
      case 'channel_created':
        return {
          'color': const Color(0xFF1565C0),
          'icon': Icons.add_comment_rounded,
          'label': lang == 'ja' ? 'チャンネル作成' : 'Channel Created',
        };
      case 'chat_cleared':
        return {
          'color': const Color(0xFFD32F2F),
          'icon': Icons.delete_sweep_rounded,
          'label': lang == 'ja' ? 'チャット消去' : 'Chat Cleared',
        };
      case 'event_edited':
        return {
          'color': const Color(0xFF7B1FA2),
          'icon': Icons.edit_rounded,
          'label': lang == 'ja' ? 'イベント編集' : 'Event Edited',
        };
      case 'participant_removed':
        return {
          'color': const Color(0xFFD32F2F),
          'icon': Icons.person_remove_rounded,
          'label': lang == 'ja' ? '参加者削除' : 'Participant Removed',
        };
      case 'reg_approved':
        return {
          'color': AppColors.primary,
          'icon': Icons.how_to_reg_rounded,
          'label': lang == 'ja' ? '登録承認' : 'Reg Approved',
        };
      case 'reg_rejected':
        return {
          'color': const Color(0xFFD32F2F),
          'icon': Icons.person_off_rounded,
          'label': lang == 'ja' ? '登録却下' : 'Reg Rejected',
        };
      default:
        return {
          'color': Colors.grey.shade600,
          'icon': Icons.history_rounded,
          'label': action,
        };
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle),
            child:
            Icon(icon, size: 36, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 16),
          Text(message,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade500),
              textAlign: TextAlign.center),
        ],
      ),
    ),
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
      color: const Color(0xFFF7F8FA),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.grey.shade200),
    ),
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
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: outlined ? Colors.transparent : color,
        borderRadius: BorderRadius.circular(12),
        border: outlined
            ? Border.all(color: color, width: 1.5)
            : null,
      ),
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16,
              color: outlined ? color : Colors.white),
          const SizedBox(width: 7),
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: outlined ? color : Colors.white)),
        ],
      ),
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
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Text(label,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color)),
    ),
  );
}

class _Badge extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color bg;
  const _Badge(
      {required this.label,
        required this.icon,
        required this.color,
        required this.bg});

  @override
  Widget build(BuildContext context) => Container(
    padding:
    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.25)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 11, color: color),
      const SizedBox(width: 4),
      Text(label,
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color)),
    ]),
  );
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(children: [
      Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 16, color: AppColors.primary),
      ),
      const SizedBox(width: 12),
      Text(label,
          style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500)),
      const Spacer(),
      Text(value,
          style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700)),
    ]),
  );
}

class _MiniActionBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _MiniActionBtn(
      {required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 28, height: 24,
      margin: const EdgeInsets.only(left: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      alignment: Alignment.center,
      child: Text(label,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: color)),
    ),
  );
}

class _SheetField extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final int maxLines;
  final TextInputType keyboardType;
  const _SheetField({
    required this.label,
    required this.ctrl,
    this.maxLines = 1,
    this.keyboardType = TextInputType.text,
  });

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
          fillColor: const Color(0xFFF7F8FA),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: AppColors.primary, width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 12),
        ),
      ),
    ],
  );
}