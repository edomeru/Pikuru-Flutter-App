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
  static const pageBg = Color(0xFFF7F8FA);
  static const white = Colors.white;
  static const accent = Color(0xFF2D7D46);
  static const accentLt = Color(0xFFEDF7EF);
  static const accentBdr = Color(0xFFB7DFC2);
  static const textPri = Color(0xFF0D0D0D);
  static const textSec = Color(0xFF374151);
  static const textMuted = Color(0xFF6B7280);
  static const textDim = Color(0xFF9CA3AF);
  static const border = Color(0xFFE5E7EB);
  static const rowBg = Color(0xFFF9FAFB);
  static const apprvClr = Color(0xFF2D7D46);
  static const apprvBg = Color(0xFFEDF7EF);
  static const pendClr = Color(0xFFF57C00);
  static const pendBg = Color(0xFFFFF3E0);
  static const rejClr = Color(0xFFD32F2F);
  static const rejBg = Color(0xFFFFEBEE);
  static const tabSelBg = Color(0xFFEDF7EF);
  static const tabSelBdr = Color(0xFFB7DFC2);
  static const tabUnselBg = Color(0xFFF3F4F6);
  static const tabUnselBdr = Color(0xFFE5E7EB);

  // Matching events_screen refresh colors
  static const refreshGreen = Color(0xFF3A7D44);
}

// ─────────────────────────────────────────────────────────────────────────────
// Localisation
// ─────────────────────────────────────────────────────────────────────────────
const _L = {
  kLangEn: {
    'title': 'Organizer Dashboard',
    'sub': 'Manage your events, groups and registrations.',
    'myEvents': 'My Events',
    'myGroups': 'My Groups',
    'registered': 'Registered',
    'stripeOnboarding': 'Stripe Onboarding',
    'noEvents': 'You have not created any events yet.',
    'noGroups': 'You have not created any groups yet.',
    'noRegistered': 'You have not registered for any events yet.',
    'pending': 'Pending',
    'approved': 'Approved',
    'rejected': 'Rejected',
    'active': 'Active',
    'inactive': 'Inactive',
    'public': 'Public',
    'private': 'Private',
    'free': 'Free',
    'edit': 'Edit',
    'viewDetails': 'View Details',
    'registrants': 'Registrants',
    'openChannel': 'Chat Channel',
    'regApproved': 'Approved',
    'regPending': 'Pending',
    'regRejected': 'Rejected',
    'views': 'Views',
    'noLimit': 'No limit',
    'date': 'Date',
    'fee': 'Fee',
    'limit': 'Limit',
    'type': 'Type',
    'loadMore': 'Load more',
    'regTitle': 'Event Registrations',
    'regTotal': 'Total registrations',
    'regAll': 'All',
    'noRegs': 'No registrations yet.',
    'approve': 'Approve',
    'reject': 'Reject',
    'seeMore': 'See more',
    'searchEvents': 'Search events…',
    'searchGroups': 'Search groups…',
    'searchRegistered': 'Search registered events…',
    'noResults': 'No events match your search.',
    'noGroupResults': 'No groups match your search.',
    'noRegisteredResults': 'No registered events match your search.',
    // Stripe onboarding
    'stripeTitle': 'Stripe Connect Sandbox',
    'stripeSub': 'Register a mock connected account for event fee payouts.',
    'stripeSimulation': 'Temporary Development Sandbox',
    'stripeSimulationBody':
    'The live Stripe account is not available yet. This mock flow writes the same Firestore fields as the web app so paid event testing can continue.',
    'stripeConnected': 'Payments Connected',
    'stripeConnectedBody':
    'Your mock Stripe account is active and ready for event fees.',
    'stripeIncomplete': 'Setup Incomplete',
    'stripeIncompleteBody':
    'Complete the sandbox onboarding to enable mock Stripe payments.',
    'stripeStepConnect': 'Connect',
    'stripeStepDetails': 'Details',
    'stripeStepPayouts': 'Payouts',
    'stripeAccountType': 'Select Account Type',
    'stripeIndividual': 'Individual',
    'stripeIndividualSub': 'For independent organizers.',
    'stripeCompany': 'Company',
    'stripeCompanySub': 'For clubs, leagues, or businesses.',
    'stripeGetStarted': 'Get Started',
    'stripeBack': 'Back',
    'stripeContinue': 'Continue',
    'stripeComplete': 'Complete Setup & Connect',
    'stripeCompleting': 'Completing...',
    'stripeSuccess': 'Setup Simulated Successfully!',
    'stripeSuccessBody': 'Updating Firestore with mock Stripe status.',
    'stripeError': 'Unable to complete setup. Please try again.',
    'stripeRetry': 'Run Setup Again',
    'stripeFirstName': 'First Name',
    'stripeLastName': 'Last Name',
    'stripeEmail': 'Email Address',
    'stripeDob': 'Date of Birth',
    'stripeBusinessName': 'Legal Business Name',
    'stripeBankName': 'Bank Name',
    'stripeBranchCode': 'Branch Code',
    'stripeAccountNumber': 'Account Number',
    'stripeAccountHolder': 'Account Holder Name',
  },
  kLangJa: {
    'title': 'オーガナイザーダッシュボード',
    'sub': 'イベント・グループ・登録を管理しましょう。',
    'myEvents': 'マイイベント',
    'myGroups': 'マイグループ',
    'registered': '登録済み',
    'stripeOnboarding': 'Stripe設定',
    'noEvents': 'まだイベントを作成していません。',
    'noGroups': 'まだグループを作成していません。',
    'noRegistered': 'まだイベントに登録していません。',
    'pending': '承認待ち',
    'approved': '承認済み',
    'rejected': '却下',
    'active': 'アクティブ',
    'inactive': '非アクティブ',
    'public': '公開',
    'private': '非公開',
    'free': '無料',
    'edit': '編集',
    'viewDetails': '詳細を見る',
    'registrants': '登録者',
    'openChannel': 'チャット',
    'regApproved': '承認済み',
    'regPending': '審査中',
    'regRejected': '却下',
    'views': '閲覧',
    'noLimit': '制限なし',
    'date': '日付',
    'fee': '参加費',
    'limit': '定員',
    'type': 'タイプ',
    'loadMore': 'もっと見る',
    'regTitle': 'イベント登録管理',
    'regTotal': '登録者合計',
    'regAll': 'すべて',
    'noRegs': 'まだ登録者がいません。',
    'approve': '承認',
    'reject': '却下',
    'seeMore': 'すべて見る',
    'searchEvents': 'イベントを検索…',
    'searchGroups': 'グループを検索…',
    'searchRegistered': '登録済みイベントを検索…',
    'noResults': '検索結果がありません。',
    'noGroupResults': '検索結果がありません。',
    'noRegisteredResults': '検索結果がありません。',
    // Stripe onboarding
    'stripeTitle': 'Stripe Connect サンドボックス',
    'stripeSub': 'イベント参加費の入金用にモック接続アカウントを登録します。',
    'stripeSimulation': '一時的な開発サンドボックス',
    'stripeSimulationBody':
    '本番Stripeアカウントはまだ利用できません。Webアプリと同じFirestore項目を書き込み、有料イベントのテストを続けられます。',
    'stripeConnected': '支払い連携済み',
    'stripeConnectedBody': 'モックStripeアカウントが有効で、イベント参加費を受け取る準備ができています。',
    'stripeIncomplete': '設定未完了',
    'stripeIncompleteBody': 'モックStripe支払いを有効にするには、サンドボックス設定を完了してください。',
    'stripeStepConnect': '接続',
    'stripeStepDetails': '詳細',
    'stripeStepPayouts': '入金',
    'stripeAccountType': 'アカウント種別を選択',
    'stripeIndividual': '個人',
    'stripeIndividualSub': '個人主催者向け。',
    'stripeCompany': '法人',
    'stripeCompanySub': 'クラブ、リーグ、事業者向け。',
    'stripeGetStarted': '開始',
    'stripeBack': '戻る',
    'stripeContinue': '次へ',
    'stripeComplete': '設定を完了して接続',
    'stripeCompleting': '処理中...',
    'stripeSuccess': '設定シミュレーション完了',
    'stripeSuccessBody': 'FirestoreへモックStripeステータスを書き込んでいます。',
    'stripeError': '設定を完了できませんでした。もう一度お試しください。',
    'stripeRetry': 'もう一度設定する',
    'stripeFirstName': '名',
    'stripeLastName': '姓',
    'stripeEmail': 'メールアドレス',
    'stripeDob': '生年月日',
    'stripeBusinessName': '正式な事業名',
    'stripeBankName': '銀行名',
    'stripeBranchCode': '支店コード',
    'stripeAccountNumber': '口座番号',
    'stripeAccountHolder': '口座名義',
  },
};

String _t(String lang, String key) => _L[lang]?[key] ?? _L[kLangEn]![key]!;

// ─────────────────────────────────────────────────────────────────────────────
// Date helpers
// ─────────────────────────────────────────────────────────────────────────────
String _fmtDate(dynamic ts, {bool compact = false}) {
  if (ts == null || ts is! Timestamp) return '—';
  final d = ts.toDate();
  if (compact) {
    return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
  }
  const mo = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${mo[d.month - 1]} ${d.day}, ${d.year}';
}

String _fmtRegDate(dynamic ts, String lang) {
  if (ts == null || ts is! Timestamp) return '';
  final d = ts.toDate();
  if (lang == 'ja') {
    return '${d.year}年${d.month}月${d.day}日';
  }
  const mo = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
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

  // Shared refresh key — incrementing this triggers all tabs to re-init
  int _globalRefreshKey = 0;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
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
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

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
            Text(
              _t(lang, 'title'),
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
              ),
            ),
            Text(
              _t(lang, 'sub'),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade500,
              ),
            ),
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
              labelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              tabs: [
                Tab(text: _t(lang, 'myEvents')),
                Tab(text: _t(lang, 'myGroups')),
                Tab(text: _t(lang, 'stripeOnboarding')),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _MyEventsTab(
            uid: uid,
            lang: lang,
            refreshKey: _globalRefreshKey,
            onRefreshAll: _refreshAll,
          ),
          _MyGroupsTab(
            uid: uid,
            lang: lang,
            refreshKey: _globalRefreshKey,
            onRefreshAll: _refreshAll,
          ),
          _StripeOnboardingTab(
            uid: uid,
            lang: lang,
            refreshKey: _globalRefreshKey,
            onRefreshAll: _refreshAll,
          ),
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
      final data = doc.data() as Map<String, dynamic>;
      final views = (data['event_view_count'] ?? 0) as int;
      try {
        final all = await FirebaseFirestore.instance
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
          setState(
                () => _metrics[id] = {
              'views': views,
              'regs': all.count ?? 0,
              'pending': pend.count ?? 0,
              'approved': appr.count ?? 0,
            },
          );
        }
      } catch (_) {
        if (mounted) {
          setState(
                () => _metrics[id] = {
              'views': views,
              'regs': 0,
              'pending': 0,
              'approved': 0,
            },
          );
        }
      }
    }
  }

  bool _matchesQuery(Map<String, dynamic> data) {
    if (_query.isEmpty) return true;
    final titleEn = (data['event_title'] ?? '').toString().toLowerCase();
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

        final filtered = docs
            .where((d) => _matchesQuery(d.data() as Map<String, dynamic>))
            .toList();

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
                    color: _D.textPri,
                  ),
                  decoration: InputDecoration(
                    hintText: _t(widget.lang, 'searchEvents'),
                    hintStyle: const TextStyle(
                      fontSize: 14,
                      color: _D.textDim,
                      fontWeight: FontWeight.w400,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: _D.textMuted,
                    ),
                    suffixIcon: _query.isNotEmpty
                        ? GestureDetector(
                      onTap: () => _searchCtrl.clear(),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: _D.textMuted,
                      ),
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
                          message: _t(widget.lang, 'noEvents'),
                        ),
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
                          message: _t(widget.lang, 'noResults'),
                        ),
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
                        data: data,
                        lang: widget.lang,
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
          chatId: chatId,
          eventData: {...data, '_doc_id': eventId},
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPending =
        data['event_pending_review'] == true && data['event_checked'] != true;
    final isApproved =
        data['event_checked'] == true && data['event_pending_review'] != true;
    final isRejected = data['rejected'] == true;

    final title = lang == 'ja'
        ? (data['event_title_jp'] ?? data['event_title'] ?? 'Untitled')
        .toString()
        : (data['event_title'] ?? 'Untitled').toString();
    final desc = lang == 'ja'
        ? (data['event_description_jp'] ?? data['event_description_en'] ?? '')
        .toString()
        : (data['event_description_en'] ?? '').toString();
    final imgUrl = (data['event_pic'] ?? data['event_pic_thumbnail'] ?? '')
        .toString();
    final feeRaw = (data['event_fee'] ?? '').toString();
    final fee = (feeRaw.isEmpty || feeRaw == '0')
        ? _t(lang, 'free')
        : '¥$feeRaw';
    final dateStr = _fmtDate(data['event_date'], compact: true);
    final eventType = (data['event_type'] ?? '').toString();

    Color sc;
    Color sb;
    String sl;
    IconData si;
    if (isApproved) {
      sc = _D.apprvClr;
      sb = _D.apprvBg;
      sl = _t(lang, 'approved');
      si = Icons.check_circle_rounded;
    } else if (isRejected) {
      sc = _D.rejClr;
      sb = _D.rejBg;
      sl = _t(lang, 'rejected');
      si = Icons.cancel_rounded;
    } else {
      sc = _D.pendClr;
      sb = _D.pendBg;
      sl = _t(lang, 'pending');
      si = Icons.schedule_rounded;
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
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
                Positioned(
                  top: 12,
                  left: 12,
                  child: _Badge(label: sl, icon: si, color: sc, bg: sb),
                ),
                if (eventType.isNotEmpty)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        eventType,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                if (desc.isNotEmpty)
                  Text(
                    desc,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _MetaChip(
                      icon: Icons.calendar_today_rounded,
                      label: dateStr,
                    ),
                    _MetaChip(icon: Icons.attach_money_rounded, label: fee),
                    if ((data['event_limit'] ?? 0) > 0)
                      _MetaChip(
                        icon: Icons.people_rounded,
                        label: '${data['event_limit']}',
                      ),
                  ],
                ),

                if (metrics != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.12),
                      ),
                    ),
                    child: Row(
                      children: [
                        _MetricPill(
                          icon: Icons.visibility_rounded,
                          value: metrics!['views']!,
                          label: _t(lang, 'views'),
                          color: AppColors.primary,
                        ),
                        _vDivider(),
                        _MetricPill(
                          icon: Icons.how_to_reg_rounded,
                          value: metrics!['regs']!,
                          label: _t(lang, 'registrants'),
                          color: const Color(0xFF5C6BC0),
                        ),
                        if ((metrics!['pending'] ?? 0) > 0) ...[
                          _vDivider(),
                          _MetricPill(
                            icon: Icons.schedule_rounded,
                            value: metrics!['pending']!,
                            label: _t(lang, 'regPending'),
                            color: _D.pendClr,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 14),

                if (isPending)
                  _ActionButton(
                    icon: Icons.edit_rounded,
                    label: _t(lang, 'edit'),
                    color: AppColors.primary,
                    onTap: () => _showEditDialog(context, eventId, data, lang),
                  )
                else
                  Column(
                    children: [
                      _ActionButton(
                        icon: Icons.remove_red_eye_rounded,
                        label: _t(lang, 'viewDetails'),
                        color: AppColors.primary,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => OrganizerEventDetailScreen(
                              eventId: eventId,
                              data: data,
                              lang: lang,
                            ),
                          ),
                        ),
                      ),
                      if (isApproved) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _ActionButton(
                                icon: Icons.chat_bubble_rounded,
                                label: _t(lang, 'openChannel'),
                                color: const Color(0xFF5C6BC0),
                                outlined: true,
                                onTap: () => _openChat(context),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _ActionButton(
                                icon: Icons.people_rounded,
                                label: _t(lang, 'registrants'),
                                color: AppColors.primary,
                                outlined: true,
                                onTap: () => _showRegistrantsModal(
                                  context,
                                  eventId,
                                  data,
                                  lang,
                                ),
                              ),
                            ),
                          ],
                        ),
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
    child: Icon(
      Icons.event_rounded,
      size: 48,
      color: AppColors.primary.withOpacity(0.3),
    ),
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
void _showRegistrantsModal(
    BuildContext context,
    String eventId,
    Map<String, dynamic> eventData,
    String lang,
    ) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) =>
        _RegistrantsSheet(eventId: eventId, eventData: eventData, lang: lang),
  );
}

class _RegistrantsSheet extends StatefulWidget {
  final String eventId, lang;
  final Map<String, dynamic> eventData;

  const _RegistrantsSheet({
    required this.eventId,
    required this.eventData,
    required this.lang,
  });

  @override
  State<_RegistrantsSheet> createState() => _RegistrantsSheetState();
}

class _RegistrantsSheetState extends State<_RegistrantsSheet> {
  List<Map<String, dynamic>> _regs = [];
  bool _loading = true;
  bool _hasMore = false;
  String _filter = 'all';
  String? _updatingId;

  static const _previewLimit = 5;

  int get _total => _regs.length;
  int get _appCnt => _regs.where((r) => r['status'] == 'approved').length;
  int get _pendCnt =>
      _regs.where((r) => (r['status'] ?? 'pending') == 'pending').length;
  int get _rejCnt => _regs.where((r) => r['status'] == 'rejected').length;

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
      final docs = hasMore ? snap.docs.take(_previewLimit).toList() : snap.docs;

      setState(() {
        _regs = docs.map((d) => {'_id': d.id, ...d.data()}).toList();
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
        'status': status,
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
          data: widget.eventData,
          lang: widget.lang,
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
      maxChildSize: 0.95,
      minChildSize: 0.50,
      builder: (ctx, scroll) => Container(
        decoration: const BoxDecoration(
          color: _D.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _t('regTitle'),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: _D.textPri,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 13,
                            color: _D.textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
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
                        border: Border.all(color: _D.border),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 17,
                        color: _D.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _StatBadge(
                      '${_t('regTotal')}: $_total${_hasMore ? '+' : ''}',
                      _D.textMuted,
                      _D.rowBg,
                      _D.border,
                    ),
                    const SizedBox(width: 8),
                    if (_appCnt > 0) ...[
                      _StatBadge(
                        '$_appCnt ${_t('regApproved')}',
                        _D.apprvClr,
                        _D.apprvBg,
                        _D.apprvBg,
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (_pendCnt > 0) ...[
                      _StatBadge(
                        '$_pendCnt ${_t('regPending')}',
                        _D.pendClr,
                        _D.pendBg,
                        _D.pendBg,
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (_rejCnt > 0)
                      _StatBadge(
                        '$_rejCnt ${_t('regRejected')}',
                        _D.rejClr,
                        _D.rejBg,
                        _D.rejBg,
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterTab(
                      label: _t('regAll'),
                      value: 'all',
                      current: _filter,
                      onTap: (v) => setState(() => _filter = v),
                    ),
                    const SizedBox(width: 6),
                    _FilterTab(
                      label: '${_t('regPending')} ($_pendCnt)',
                      value: 'pending',
                      current: _filter,
                      onTap: (v) => setState(() => _filter = v),
                    ),
                    const SizedBox(width: 6),
                    _FilterTab(
                      label: '${_t('regApproved')} ($_appCnt)',
                      value: 'approved',
                      current: _filter,
                      onTap: (v) => setState(() => _filter = v),
                    ),
                    const SizedBox(width: 6),
                    _FilterTab(
                      label: '${_t('regRejected')} ($_rejCnt)',
                      value: 'rejected',
                      current: _filter,
                      onTap: (v) => setState(() => _filter = v),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 4),
            const Divider(height: 1, color: _D.border),

            Expanded(
              child: _loading
                  ? Center(child: CircularProgressIndicator(color: _D.accent))
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
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.people_outline_rounded,
                        size: 28,
                        color: _D.accent.withOpacity(0.5),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _t('noRegs'),
                      style: const TextStyle(
                        fontSize: 13,
                        color: _D.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              )
                  : ListView.builder(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                itemCount:
                _filtered.length +
                    (_hasMore && _filter == 'all' ? 1 : 0),
                itemBuilder: (_, i) {
                  if (i == _filtered.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: GestureDetector(
                        onTap: () => _openFullList(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: _D.accentLt,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: _D.accentBdr),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.people_rounded,
                                size: 15,
                                color: _D.accent,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _t('seeMore'),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: _D.accent,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 12,
                                color: _D.accent,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }
                  final r = _filtered[i];
                  return _RegRow(
                    reg: r,
                    lang: widget.lang,
                    isUpdating: _updatingId == r['_id'],
                    onApprove: () =>
                        _updateStatus(r['_id'] as String, 'approved'),
                    onReject: () =>
                        _updateStatus(r['_id'] as String, 'rejected'),
                  );
                },
              ),
            ),
          ],
        ),
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
    final status = (reg['status'] ?? 'pending').toString();
    final name = (reg['user_name'] ?? reg['user_id'] ?? '?').toString();
    final email = (reg['user_email'] ?? '').toString();
    final avatar = (reg['user_avatar'] ?? '').toString();
    final dateStr = _fmtRegDate(reg['registered_at'], lang);

    Color sc;
    Color sb;
    String sl;
    switch (status) {
      case 'approved':
        sc = _D.apprvClr;
        sb = _D.apprvBg;
        sl = _t('regApproved');
        break;
      case 'rejected':
        sc = _D.rejClr;
        sb = _D.rejBg;
        sl = _t('regRejected');
        break;
      default:
        sc = _D.pendClr;
        sb = _D.pendBg;
        sl = _t('regPending');
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _D.rowBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _D.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: _D.accentLt,
            backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
            child: avatar.isEmpty
                ? Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(
                color: _D.accent,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _D.textPri,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (email.isNotEmpty)
                  Text(
                    email,
                    style: const TextStyle(fontSize: 12, color: _D.textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: sb,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        sl,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: sc,
                        ),
                      ),
                    ),
                    if (dateStr.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        dateStr,
                        style: const TextStyle(
                          fontSize: 11,
                          color: _D.textDim,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (isUpdating)
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                color: _D.accent,
                strokeWidth: 2.5,
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (status != 'approved')
                  _ABtn(
                    label: _t('approve'),
                    color: _D.apprvClr,
                    bg: _D.apprvBg,
                    onTap: onApprove,
                  ),
                if (status != 'rejected') ...[
                  if (status != 'approved') const SizedBox(height: 6),
                  _ABtn(
                    label: _t('reject'),
                    color: _D.rejClr,
                    bg: _D.rejBg,
                    onTap: onReject,
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Edit dialog
// ─────────────────────────────────────────────────────────────────────────────
void _showEditDialog(
    BuildContext context,
    String eventId,
    Map<String, dynamic> data,
    String lang,
    ) {
  final titleCtrl = TextEditingController(
    text: (data['event_title'] ?? '').toString(),
  );
  final descCtrl = TextEditingController(
    text: (data['event_description_en'] ?? '').toString(),
  );
  final feeCtrl = TextEditingController(
    text: (data['event_fee'] ?? '').toString(),
  );
  bool saving = false;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => StatefulBuilder(
      builder: (ctx, setS) {
        return Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
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
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  _t(lang, 'edit'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 20),
                _SheetField(label: 'Title (EN)', ctrl: titleCtrl),
                const SizedBox(height: 12),
                _SheetField(
                  label: 'Description (EN)',
                  ctrl: descCtrl,
                  maxLines: 4,
                ),
                const SizedBox(height: 12),
                _SheetField(
                  label: 'Fee (¥)',
                  ctrl: feeCtrl,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
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
                          'event_title': titleCtrl.text.trim(),
                          'event_description_en': descCtrl.text
                              .trim(),
                          'event_fee': feeCtrl.text.trim(),
                        });
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (_) {
                        setS(() => saving = false);
                      }
                    },
                    child: saving
                        ? const CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    )
                        : const Text(
                      'Save Changes',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
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

  bool _loading = false;
  bool _hasMore = true;
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
      _groups = [];
      _lastDoc = null;
      _hasMore = true;
      _initDone = false;
      _loading = false;
    });
    await _fetchNextPage();
  }

  bool _matchesQuery(Map<String, dynamic> data) {
    if (_query.isEmpty) return true;
    final nameEn = (data['org_name'] ?? '').toString().toLowerCase();
    final nameJp = (data['org_name_jp'] ?? '').toString().toLowerCase();
    final descEn = (data['org_description'] ?? '').toString().toLowerCase();
    final descJp = (data['org_description_jp'] ?? '').toString().toLowerCase();
    return nameEn.contains(_query) ||
        nameJp.contains(_query) ||
        descEn.contains(_query) ||
        descJp.contains(_query);
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
          _loading = false;
          _initDone = true;
        });
      }
    } catch (e) {
      debugPrint('_MyGroupsTab fetch error: $e');
      if (mounted)
        setState(() {
          _loading = false;
          _initDone = true;
        });
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
    final itemCount =
        filtered.length + (showLoadMore && _query.isEmpty ? 1 : 0);

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
                    message: _t(widget.lang, 'noGroups'),
                  ),
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
                      message: _t(widget.lang, 'noGroupResults'),
                    ),
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
                              Icon(
                                Icons.expand_more_rounded,
                                size: 18,
                                color: _D.accent,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _t(widget.lang, 'loadMore'),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: _D.accent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }
                  final g = filtered[i];
                  return _GroupCard(
                    groupId: g['_docId'] as String,
                    data: g,
                    lang: widget.lang,
                    onPatched: (patch) =>
                        _patchGroup(g['_docId'] as String, patch),
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
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: _D.textPri,
        ),
        decoration: InputDecoration(
          hintText: _t(widget.lang, 'searchGroups'),
          hintStyle: const TextStyle(
            fontSize: 14,
            color: _D.textDim,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 20,
            color: _D.textMuted,
          ),
          suffixIcon: _query.isNotEmpty
              ? GestureDetector(
            onTap: () => _searchCtrl.clear(),
            child: const Icon(
              Icons.close_rounded,
              size: 18,
              color: _D.textMuted,
            ),
          )
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
    final isActive = data['org_active'] == true;
    final isPublic = data['org_public'] != false;

    final name = lang == 'ja'
        ? (data['org_name_jp'] ?? data['org_name'] ?? 'Unnamed').toString()
        : (data['org_name'] ?? 'Unnamed').toString();
    final desc = lang == 'ja'
        ? (data['org_description_jp'] ?? data['org_description'] ?? '')
        .toString()
        : (data['org_description'] ?? '').toString();
    final imgUrl = (data['org_image'] ?? '').toString();

    Color sc;
    Color sb;
    String sl;
    IconData si;
    if (isApproved) {
      sc = _D.apprvClr;
      sb = _D.apprvBg;
      sl = _t(lang, 'approved');
      si = Icons.check_circle_rounded;
    } else if (isRejected) {
      sc = _D.rejClr;
      sb = _D.rejBg;
      sl = _t(lang, 'rejected');
      si = Icons.cancel_rounded;
    } else {
      sc = _D.pendClr;
      sb = _D.pendBg;
      sl = _t(lang, 'pending');
      si = Icons.schedule_rounded;
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
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Stack(
              children: [
                imgUrl.isNotEmpty
                    ? Image.network(
                  imgUrl,
                  height: 130,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _grpPlaceholder(),
                )
                    : _grpPlaceholder(),
                if (!isApproved)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: _Badge(label: sl, icon: si, color: sc, bg: sb),
                  ),
                if (isApproved)
                  Positioned(
                    top: 12,
                    right: 12,
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
                          color: isActive ? _D.apprvClr : _D.rejClr,
                          bg: isActive ? _D.apprvBg : _D.rejBg,
                        ),
                        const SizedBox(height: 4),
                        _Badge(
                          label: isPublic
                              ? _t(lang, 'public')
                              : _t(lang, 'private'),
                          icon: isPublic
                              ? Icons.public_rounded
                              : Icons.lock_rounded,
                          color: const Color(0xFF1565C0),
                          bg: const Color(0xFFE3F2FD),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (desc.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    desc,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                const SizedBox(height: 14),

                _ActionButton(
                  icon: Icons.edit_rounded,
                  label: lang == 'ja' ? 'グループ設定を編集' : 'Edit Settings',
                  color: AppColors.primary,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OrganizerGroupSettingsScreen(
                        groupId: groupId,
                        initialData: data,
                      ),
                    ),
                  ),
                ),

                if (isApproved) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _OutlineBtn(
                          label: isActive
                              ? (lang == 'ja' ? '非アクティブにする' : 'Deactivate')
                              : (lang == 'ja' ? 'アクティブにする' : 'Activate'),
                          color: isActive ? _D.rejClr : _D.apprvClr,
                          onTap: () async {
                            final newVal = !isActive;
                            await FirebaseFirestore.instance
                                .collection('organizations')
                                .doc(groupId)
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
                              : (lang == 'ja' ? '公開する' : 'Make Public'),
                          color: const Color(0xFF1565C0),
                          onTap: () async {
                            final newVal = !isPublic;
                            await FirebaseFirestore.instance
                                .collection('organizations')
                                .doc(groupId)
                                .update({'org_public': newVal});
                            onPatched({'org_public': newVal});
                          },
                        ),
                      ),
                    ],
                  ),
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
    width: double.infinity,
    color: Colors.grey.shade100,
    child: Icon(Icons.group_rounded, size: 48, color: Colors.grey.shade300),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// TAB 4 — STRIPE ONBOARDING
// ═════════════════════════════════════════════════════════════════════════════
class _StripeOnboardingTab extends StatefulWidget {
  final String uid, lang;
  final int refreshKey;
  final Future<void> Function() onRefreshAll;

  const _StripeOnboardingTab({
    required this.uid,
    required this.lang,
    required this.refreshKey,
    required this.onRefreshAll,
  });

  @override
  State<_StripeOnboardingTab> createState() => _StripeOnboardingTabState();
}

class _StripeOnboardingTabState extends State<_StripeOnboardingTab> {
  int _step = 1;
  bool _submitting = false;
  bool _success = false;
  bool _forceSetup = false;
  String _businessType = 'individual';

  final _businessNameCtrl = TextEditingController();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _bankNameCtrl = TextEditingController();
  final _branchCodeCtrl = TextEditingController();
  final _accountNumberCtrl = TextEditingController();
  final _accountHolderCtrl = TextEditingController();

  String _t(String k) => _L[widget.lang]?[k] ?? _L[kLangEn]![k]!;

  @override
  void didUpdateWidget(_StripeOnboardingTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshKey != widget.refreshKey) {
      setState(() {
        _step = 1;
        _success = false;
        _forceSetup = false;
      });
    }
  }

  @override
  void dispose() {
    _businessNameCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _dobCtrl.dispose();
    _bankNameCtrl.dispose();
    _branchCodeCtrl.dispose();
    _accountNumberCtrl.dispose();
    _accountHolderCtrl.dispose();
    super.dispose();
  }

  bool get _canContinueDetails =>
      _firstNameCtrl.text.trim().isNotEmpty &&
          _emailCtrl.text.trim().isNotEmpty;

  bool get _canComplete =>
      _bankNameCtrl.text.trim().isNotEmpty &&
          _accountNumberCtrl.text.trim().isNotEmpty &&
          _accountHolderCtrl.text.trim().isNotEmpty;

  Future<void> _completeMockOnboarding() async {
    if (widget.uid.isEmpty || _submitting || !_canComplete) return;
    setState(() => _submitting = true);

    try {
      final mockId =
          'mock_acct_${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';

      await FirebaseFirestore.instance
          .collection('registration')
          .doc(widget.uid)
          .set({
        'stripe_account_id': mockId,
        'stripe_charges_enabled': true,
        'stripe_details_submitted': true,
      }, SetOptions(merge: true));

      if (!mounted) return;
      setState(() => _success = true);
      await Future.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      setState(() {
        _step = 1;
        _success = false;
        _forceSetup = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('stripeError')), backgroundColor: _D.rejClr),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.uid.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('registration')
          .doc(widget.uid)
          .snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data() ?? {};
        final connected =
            data['stripe_charges_enabled'] == true &&
                data['stripe_details_submitted'] == true;
        final showConnected = connected && !_forceSetup;
        final accountId = (data['stripe_account_id'] ?? '').toString();

        return RefreshIndicator(
          onRefresh: widget.onRefreshAll,
          color: _D.refreshGreen,
          backgroundColor: Colors.white,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _buildHeader(connected, accountId),
              const SizedBox(height: 16),
              _buildSandboxBanner(),
              const SizedBox(height: 18),
              if (showConnected)
                _buildConnectedCard(accountId)
              else ...[
                _buildProgress(),
                const SizedBox(height: 16),
                _buildStepCard(),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(bool connected, String accountId) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _D.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: _D.border),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 12,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFF635BFF).withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.credit_card_rounded,
            size: 21,
            color: Color(0xFF635BFF),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _t('stripeTitle'),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: _D.textPri,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _t('stripeSub'),
                style: const TextStyle(
                  fontSize: 12,
                  color: _D.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (accountId.isNotEmpty) ...[
                const SizedBox(height: 7),
                Text(
                  accountId,
                  style: const TextStyle(
                    fontSize: 11,
                    color: _D.textDim,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
        _Badge(
          label: connected ? _t('stripeConnected') : _t('stripeIncomplete'),
          icon: connected ? Icons.check_circle_rounded : Icons.schedule_rounded,
          color: connected ? _D.apprvClr : _D.pendClr,
          bg: connected ? _D.apprvBg : _D.pendBg,
        ),
      ],
    ),
  );

  Widget _buildSandboxBanner() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF8E1),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFFFECB3)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: _D.pendClr.withOpacity(0.12),
            borderRadius: BorderRadius.circular(11),
          ),
          child: const Icon(
            Icons.warning_amber_rounded,
            size: 19,
            color: _D.pendClr,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _t('stripeSimulation'),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: _D.pendClr,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _t('stripeSimulationBody'),
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: _D.textSec,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _buildConnectedCard(String accountId) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: _D.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _D.accentBdr),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 14,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: _D.apprvBg,
            shape: BoxShape.circle,
            border: Border.all(color: _D.accentBdr),
          ),
          child: const Icon(Icons.check_rounded, size: 34, color: _D.apprvClr),
        ),
        const SizedBox(height: 14),
        Text(
          _t('stripeConnected'),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: _D.textPri,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          _t('stripeConnectedBody'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            height: 1.4,
            color: _D.textMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (accountId.isNotEmpty) ...[
          const SizedBox(height: 14),
          _MetaChip(icon: Icons.tag_rounded, label: accountId),
        ],
        const SizedBox(height: 18),
        _ActionButton(
          icon: Icons.refresh_rounded,
          label: _t('stripeRetry'),
          color: const Color(0xFF635BFF),
          outlined: true,
          onTap: () => setState(() {
            _step = 1;
            _forceSetup = true;
          }),
        ),
      ],
    ),
  );

  Widget _buildProgress() {
    final labels = [
      _t('stripeStepConnect'),
      _t('stripeStepDetails'),
      _t('stripeStepPayouts'),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: _D.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _D.border),
      ),
      child: Row(
        children: List.generate(3, (i) {
          final step = i + 1;
          final active = _step == step;
          final done = _step > step;
          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        width: 34,
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: done
                              ? _D.apprvClr
                              : active
                              ? const Color(0xFF635BFF)
                              : _D.rowBg,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: done || active
                                ? Colors.transparent
                                : _D.border,
                          ),
                        ),
                        child: done
                            ? const Icon(
                          Icons.check_rounded,
                          size: 17,
                          color: Colors.white,
                        )
                            : Text(
                          '$step',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: active ? Colors.white : _D.textDim,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        labels[i],
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: active ? _D.textPri : _D.textDim,
                        ),
                      ),
                    ],
                  ),
                ),
                if (i < 2)
                  Container(
                    width: 22,
                    height: 2,
                    margin: const EdgeInsets.only(bottom: 20),
                    color: _step > step ? _D.apprvClr : _D.border,
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStepCard() => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: _D.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _D.border),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 14,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Stack(
      children: [
        AbsorbPointer(
          absorbing: _success,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: _step == 1
                ? _buildConnectStep()
                : _step == 2
                ? _buildDetailsStep()
                : _buildPayoutStep(),
          ),
        ),
        if (_success)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: _D.white.withOpacity(0.96),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: _D.apprvBg,
                      shape: BoxShape.circle,
                      border: Border.all(color: _D.accentBdr),
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 31,
                      color: _D.apprvClr,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _t('stripeSuccess'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: _D.textPri,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _t('stripeSuccessBody'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: _D.textMuted),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );

  Widget _buildConnectStep() => Column(
    key: const ValueKey('stripe-connect'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _stepTitle(
        Icons.link_rounded,
        'Link Pikuru App to Stripe',
        'Register a simulated Express payout profile to start charging fees.',
      ),
      const SizedBox(height: 18),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _brandBox('P', _D.accent),
          const SizedBox(width: 12),
          const Icon(Icons.more_horiz_rounded, color: Color(0xFF635BFF)),
          const SizedBox(width: 12),
          _brandBox('S', const Color(0xFF635BFF)),
        ],
      ),
      const SizedBox(height: 20),
      Text(
        _t('stripeAccountType'),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: _D.textMuted,
        ),
      ),
      const SizedBox(height: 9),
      Row(
        children: [
          Expanded(
            child: _accountTypeCard(
              value: 'individual',
              title: _t('stripeIndividual'),
              subtitle: _t('stripeIndividualSub'),
              icon: Icons.person_rounded,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _accountTypeCard(
              value: 'company',
              title: _t('stripeCompany'),
              subtitle: _t('stripeCompanySub'),
              icon: Icons.business_rounded,
            ),
          ),
        ],
      ),
      const SizedBox(height: 18),
      _ActionButton(
        icon: Icons.arrow_forward_rounded,
        label: _t('stripeGetStarted'),
        color: const Color(0xFF635BFF),
        onTap: () => setState(() => _step = 2),
      ),
    ],
  );

  Widget _buildDetailsStep() => Column(
    key: const ValueKey('stripe-details'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _stepTitle(
        Icons.badge_rounded,
        'Representative & Business Info',
        'Mock identity details for the sandbox onboarding flow.',
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(child: _stripeField(_t('stripeFirstName'), _firstNameCtrl)),
          const SizedBox(width: 10),
          Expanded(child: _stripeField(_t('stripeLastName'), _lastNameCtrl)),
        ],
      ),
      const SizedBox(height: 12),
      _stripeField(
        _t('stripeEmail'),
        _emailCtrl,
        keyboardType: TextInputType.emailAddress,
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(child: _stripeField(_t('stripeDob'), _dobCtrl)),
          const SizedBox(width: 10),
          Expanded(
            child: _stripeField(_t('stripeBusinessName'), _businessNameCtrl),
          ),
        ],
      ),
      const SizedBox(height: 18),
      _buttonRow(
        back: () => setState(() => _step = 1),
        next: _canContinueDetails ? () => setState(() => _step = 3) : null,
        nextLabel: _t('stripeContinue'),
      ),
    ],
  );

  Widget _buildPayoutStep() => Column(
    key: const ValueKey('stripe-payouts'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _stepTitle(
        Icons.account_balance_rounded,
        'Bank Payout Information',
        'Mock bank account where Stripe would send event fee payouts.',
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(child: _stripeField(_t('stripeBankName'), _bankNameCtrl)),
          const SizedBox(width: 10),
          Expanded(
            child: _stripeField(
              _t('stripeBranchCode'),
              _branchCodeCtrl,
              keyboardType: TextInputType.number,
              maxLength: 3,
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: _stripeField(
              _t('stripeAccountNumber'),
              _accountNumberCtrl,
              keyboardType: TextInputType.number,
              maxLength: 7,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _stripeField(_t('stripeAccountHolder'), _accountHolderCtrl),
          ),
        ],
      ),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _D.rowBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _D.border),
        ),
        child: const Row(
          children: [
            Icon(Icons.lock_rounded, size: 15, color: _D.textMuted),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Sandbox only. No real bank details are sent to Stripe.',
                style: TextStyle(
                  fontSize: 11,
                  color: _D.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      _buttonRow(
        back: () => setState(() => _step = 2),
        next: _canComplete ? _completeMockOnboarding : null,
        nextLabel: _submitting ? _t('stripeCompleting') : _t('stripeComplete'),
        nextIcon: _submitting ? null : Icons.check_rounded,
        loading: _submitting,
      ),
    ],
  );

  Widget _stepTitle(IconData icon, String title, String subtitle) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFF635BFF).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 18, color: const Color(0xFF635BFF)),
      ),
      const SizedBox(width: 11),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: _D.textPri,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                height: 1.35,
                color: _D.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _brandBox(String label, Color color) => Container(
    width: 54,
    height: 54,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: color.withOpacity(0.09),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: color.withOpacity(0.22)),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color),
    ),
  );

  Widget _accountTypeCard({
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final selected = _businessType == value;
    return GestureDetector(
      onTap: () => setState(() => _businessType = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF635BFF).withOpacity(0.06)
              : _D.rowBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? const Color(0xFF635BFF) : _D.border,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? const Color(0xFF635BFF) : _D.textMuted,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: selected ? _D.textPri : _D.textSec,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 11,
                height: 1.25,
                color: _D.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stripeField(
      String label,
      TextEditingController ctrl, {
        TextInputType keyboardType = TextInputType.text,
        int? maxLength,
      }) => TextField(
    controller: ctrl,
    keyboardType: keyboardType,
    maxLength: maxLength,
    onChanged: (_) => setState(() {}),
    inputFormatters: keyboardType == TextInputType.number
        ? [FilteringTextInputFormatter.digitsOnly]
        : null,
    style: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: _D.textPri,
    ),
    decoration: InputDecoration(
      labelText: label,
      counterText: '',
      labelStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: _D.textMuted,
      ),
      filled: true,
      fillColor: _D.rowBg,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _D.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _D.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF635BFF), width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    ),
  );

  Widget _buttonRow({
    required VoidCallback back,
    required VoidCallback? next,
    required String nextLabel,
    IconData? nextIcon = Icons.arrow_forward_rounded,
    bool loading = false,
  }) => Row(
    children: [
      Expanded(
        child: _OutlineBtn(
          label: _t('stripeBack'),
          color: _D.textMuted,
          onTap: back,
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        flex: 2,
        child: GestureDetector(
          onTap: loading ? null : next,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 120),
            opacity: next == null ? 0.45 : 1,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF635BFF),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (loading)
                    const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  else if (nextIcon != null)
                    Icon(nextIcon, size: 16, color: Colors.white),
                  if (loading || nextIcon != null) const SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      nextLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ],
  );
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
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 36, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

class _Badge extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color, bg;
  const _Badge({
    required this.label,
    required this.icon,
    required this.color,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.25)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
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
      color: _D.rowBg,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: _D.border),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Colors.grey.shade500),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    ),
  );
}

class _MetricPill extends StatelessWidget {
  final IconData icon;
  final int value;
  final String label;
  final Color color;
  const _MetricPill({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$value',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ],
    ),
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
        border: outlined ? Border.all(color: color, width: 1.5) : null,
      ),
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: outlined ? color : Colors.white),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: outlined ? color : Colors.white,
            ),
          ),
        ],
      ),
    ),
  );
}

class _OutlineBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _OutlineBtn({
    required this.label,
    required this.color,
    required this.onTap,
  });

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
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
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
      border: Border.all(color: border.withOpacity(0.4)),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color),
    ),
  );
}

class _FilterTab extends StatelessWidget {
  final String label, value, current;
  final ValueChanged<String> onTap;
  const _FilterTab({
    required this.label,
    required this.value,
    required this.current,
    required this.onTap,
  });

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
          border: Border.all(color: selected ? _D.tabSelBdr : _D.tabUnselBdr),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: selected ? _D.accent : _D.textMuted,
          ),
        ),
      ),
    );
  }
}

class _ABtn extends StatelessWidget {
  final String label;
  final Color color, bg;
  final VoidCallback onTap;
  const _ABtn({
    required this.label,
    required this.color,
    required this.bg,
    required this.onTap,
  });

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
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
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
      Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade600,
        ),
      ),
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
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.primary, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
        ),
      ),
    ],
  );
}
