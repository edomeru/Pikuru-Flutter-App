import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pikuru/theme/material.dart';
import 'package:pikuru/providers/providers.dart';
import 'package:pikuru/utils/date_formatter.dart';
import 'package:pikuru/modal/join_group_modal.dart';
import 'package:pikuru/modal/mark_interested_modal.dart';
import 'package:pikuru/modal/share_group_modal.dart';

// ── Data helpers ──────────────────────────────────────────────────────────────

bool _isTruthy(dynamic v) {
  if (v == null) return false;
  if (v is bool) return v;
  if (v is num)  return v != 0;
  final s = v.toString().toLowerCase().trim();
  return s == 'true' || s == '1' || s == 't' || s == 'yes';
}

// ── Lang-aware resolvers ──────────────────────────────────────────────────────

/// Pick JP field first when lang == 'ja', fall back to EN field.
String _field(Map<String, dynamic> g, String enKey, String jpKey, String lang) {
  if (lang == 'ja') {
    final jp = (g[jpKey] ?? '').toString().trim();
    if (jp.isNotEmpty && jp != 'null') return jp;
  }
  return (g[enKey] ?? '').toString().trim();
}

String _resolveSkillLevel(Map<String, dynamic> g, String lang) {
  final existing = (g['org_skill_level'] ?? '').toString().trim();
  if (existing.isNotEmpty && existing != 'null') {
    return lang == 'ja'
        ? existing
        .replaceAll('Beginner',     '初級')
        .replaceAll('Intermediate', '中級')
        .replaceAll('Advanced',     '上級')
        : existing;
  }
  final b  = lang == 'ja' ? '初級'  : 'Beginner';
  final im = lang == 'ja' ? '中級'  : 'Intermediate';
  final a  = lang == 'ja' ? '上級'  : 'Advanced';
  final levels = <String>[];
  if (_isTruthy(g['org_skill_beginner']))     levels.add(b);
  if (_isTruthy(g['org_skill_intermediate'])) levels.add(im);
  if (_isTruthy(g['org_skill_advance']))      levels.add(a);
  if (levels.isNotEmpty) return levels.join(' | ');
  final type = (g['org_type'] ?? '').toString();
  return type == 'Professional'
      ? (lang == 'ja' ? 'プロ | アマチュア' : 'Pro | Amateur')
      : (lang == 'ja' ? '全レベル' : 'All levels');
}

String _resolveAgeGroups(Map<String, dynamic> g, String lang) {
  final existing = (g['org_age_groups'] ?? '').toString().trim();
  if (existing.isNotEmpty && existing != 'null') {
    return lang == 'ja'
        ? existing
        .replaceAll('Juniors',  'ジュニア')
        .replaceAll('Students', '学生')
        .replaceAll('Adults',   '大人')
        .replaceAll('Seniors',  'シニア')
        : existing;
  }
  String j(String en, String ja) => lang == 'ja' ? ja : en;
  final ages = <String>[];
  if (_isTruthy(g['org_age_juniors']))  ages.add(j('Juniors',  'ジュニア'));
  if (_isTruthy(g['org_age_students'])) ages.add(j('Students', '学生'));
  if (_isTruthy(g['org_age_adult']))    ages.add(j('Adults',   '大人'));
  if (_isTruthy(g['org_age_seniors']))  ages.add(j('Seniors',  'シニア'));
  return ages.isEmpty ? (lang == 'ja' ? '全年齢' : 'All ages') : ages.join(' | ');
}

String _resolveSchedule(Map<String, dynamic> g, String lang) {
  final existing = (g['org_schedule'] ?? g['org_meetup_time'] ?? '').toString().trim();
  if (existing.isNotEmpty && existing != 'null') {
    return lang == 'ja'
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
  String j(String en, String ja) => lang == 'ja' ? ja : en;
  final dayMap = {
    'org_meetup_sun':   j('Sun', '日'), 'org_meetup_mon':   j('Mon', '月'),
    'org_meetup_tues':  j('Tue', '火'), 'org_meetup_weds':  j('Wed', '水'),
    'org_meetup_thurs': j('Thu', '木'), 'org_meetup_fri':   j('Fri', '金'),
    'org_meetup_sat':   j('Sat', '土'),
  };
  final days = dayMap.entries.where((e) => _isTruthy(g[e.key])).map((e) => e.value).toList();
  final times = <String>[
    if (_isTruthy(g['org_meetup_time_mornings']))   j('Mornings',   '午前'),
    if (_isTruthy(g['org_meetup_time_afternoons'])) j('Afternoons', '午後'),
    if (_isTruthy(g['org_meetup_time_evenings']))   j('Evenings',   '夜間'),
  ];
  if (days.isEmpty && times.isEmpty) return lang == 'ja' ? '柔軟なスケジュール' : 'Flexible schedule';
  if (days.isEmpty)  return times.join(' | ');
  if (times.isEmpty) return days.join(' | ');
  return '${days.join(' | ')}  ·  ${times.join(' | ')}';
}

String _resolveDescription(Map<String, dynamic> g, String lang) {
  // Prefer JP description field when lang == 'ja'
  final d = _field(g, 'org_description', 'org_description_jp', lang);
  if (d.isNotEmpty && d != 'null') return d;
  // Fallback copy — in JP when needed
  final name = _field(g, 'org_name', 'org_name_jp', lang);
  if (lang == 'ja') {
    switch ((g['org_type'] ?? '').toString()) {
      case 'Professional':
        return '$name のプロレベルのトーナメント情報や最新ニュースをチェック！';
      case 'Gym/Club':
        return '$name — 全レベル対応のオープンプレイやレッスンが楽しめる施設です。';
      case 'Local Group':
        return '誰でも参加できるフレンドリーな地元ピックルボールグループです。ぜひご参加ください！';
      default:
        return '$name に参加して、ピックルボールコミュニティとつながりましょう。初心者から上級者まで大歓迎！';
    }
  }
  switch ((g['org_type'] ?? '').toString()) {
    case 'Professional':
      return 'Follow $name for professional-level pickleball tournaments, '
          'top-tier competition, and the latest tour news.';
    case 'Gym/Club':
      return 'Join $name — a dedicated pickleball facility offering '
          'open play, lessons, and a welcoming community for all skill levels.';
    case 'Local Group':
      return 'A friendly local pickleball group open to all. '
          'Come out, rally with neighbours, and enjoy the game!';
    default:
      return 'Join $name and connect with the pickleball community. '
          'Whether you\'re a beginner or a seasoned player, everyone is welcome.';
  }
}

/// Resolve the display location from _resolved_location (pre-built by GroupsScreen)
/// or fall back to _jp fields directly.
String _resolveLocationLabel(Map<String, dynamic> g, String lang, String providerLocation) {
  // If the card was opened from GroupsScreen, _resolved_location is already correct
  final pre = (g['_resolved_location'] ?? '').toString().trim();
  if (pre.isNotEmpty) return pre;

  // Manual resolution using _jp fields
  if (lang == 'ja') {
    final city = (g['org_city_jp'] ?? g['org_city'] ?? '').toString().trim();
    final pref = (g['org_prefecture_jp'] ?? g['org_prefecture'] ?? '').toString().trim();
    final country = (g['org_country'] ?? '').toString().trim();
    if (city.isNotEmpty && pref.isNotEmpty) return '$city, $pref';
    if (city.isNotEmpty) return country.isNotEmpty ? '$city, $country' : city;
    if (pref.isNotEmpty) return pref;
    return providerLocation.isNotEmpty ? providerLocation : country;
  }

  return providerLocation.isNotEmpty
      ? providerLocation
      : (g['org_country'] ?? '').toString().trim();
}

// ── Screen ────────────────────────────────────────────────────────────────────

class GroupDetailScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> group;
  const GroupDetailScreen({super.key, required this.group});

  @override
  ConsumerState<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends ConsumerState<GroupDetailScreen>
    with SingleTickerProviderStateMixin {
  bool? _isJoined;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  // ── Language state — inherit from incoming group map if set ───────────────
  late String _lang;

  @override
  void initState() {
    super.initState();
    // If opened from GroupsScreen the map already has '_lang'; default to 'en'.
    _lang = (widget.group['_lang'] ?? 'en').toString();
    _checkJoinStatus();
    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 550));
    _fadeAnim =
        CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _checkJoinStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) { setState(() => _isJoined = false); return; }
    final joined = await JoinGroupModal.isAlreadyJoined(user.uid, widget.group);
    if (mounted) setState(() => _isJoined = joined);
  }

  Future<void> _launchUrl(String url) async {
    if (url.isEmpty) return;
    final raw = url.startsWith('http') ? url : 'https://$url';
    final uri = Uri.tryParse(raw);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String get _orgId =>
      (widget.group['org_id'] ??
          widget.group['org_ID'] ??
          widget.group['_doc_id'] ??
          '').toString();

  // Convenience: pick EN or JP string
  String _t(String en, String ja) => _lang == 'ja' ? ja : en;

  @override
  Widget build(BuildContext context) {
    final g = widget.group;

    // Location from provider (used as fallback when _resolved_location absent)
    final orgLocId      = (g['org_loc_id'] ?? '').toString();
    final locationAsync = ref.watch(locationResolverProvider(orgLocId));
    final providerLoc   = locationAsync.when(
      data:    (l) => l,
      loading: () => '',
      error:   (_, __) => '',
    );

    // ── All display strings resolved once here ────────────────────────────
    final locationLabel = _resolveLocationLabel(g, _lang, providerLoc).let((l) =>
    l.isNotEmpty ? l : (g['org_country'] ?? _t('Unknown location', '不明な場所')).toString());

    final displayName   = _field(g, 'org_name',        'org_name_jp',        _lang).let((v) => v.isNotEmpty ? v : _t('Unnamed Group', '名称不明'));
    final description   = _resolveDescription(g, _lang);
    final skillLabel    = _resolveSkillLevel(g, _lang);
    final ageLabel      = _resolveAgeGroups(g, _lang);
    final scheduleLabel = _resolveSchedule(g, _lang);

    // Prefecture / city row (below the grid)
    final city       = _field(g, 'org_city',       'org_city_jp',       _lang);
    final prefecture = _field(g, 'org_prefecture', 'org_prefecture_jp', _lang);
    final social     = (g['org_social'] ?? '').toString().trim();

    final imageUrl     = (g['org_image'] ?? g['org_pic'] ?? '').toString();
    final website      = (g['org_website'] ?? '').toString().trim();
    final websiteLabel = website
        .replaceFirst(RegExp(r'^https?://'), '')
        .replaceFirst(RegExp(r'/$'), '');

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [

          // ── Hero App Bar ──────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            stretch: true,
            backgroundColor: AppColors.primary,
            systemOverlayStyle: SystemUiOverlayStyle.light,
            automaticallyImplyLeading: false,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: _GlassButton(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: () => Navigator.pop(context),
              ),
            ),
            actions: [
              // ── EN / JP toggle ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                child: _LangPill(
                  lang: _lang,
                  onChanged: (l) => setState(() => _lang = l),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: _GlassButton(
                  icon: Icons.ios_share_rounded,
                  onTap: () => ShareGroupModal.show(context, group: g),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [
                StretchMode.zoomBackground,
                StretchMode.blurBackground,
              ],
              background: Stack(
                fit: StackFit.expand,
                children: [
                  imageUrl.isNotEmpty
                      ? Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    loadingBuilder: (ctx, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        color: AppColors.primary.withOpacity(0.15),
                        child: const Center(
                          child: CircularProgressIndicator(color: Colors.white54, strokeWidth: 2),
                        ),
                      );
                    },
                    errorBuilder: (_, __, ___) => Container(
                      color: AppColors.primary.withOpacity(0.2),
                      child: const Icon(Icons.group, size: 80, color: Colors.white38),
                    ),
                  )
                      : Container(
                    color: AppColors.primary.withOpacity(0.2),
                    child: const Icon(Icons.group, size: 80, color: Colors.white38),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withOpacity(0.58)],
                        stops: const [0.4, 1.0],
                      ),
                    ),
                  ),
                  // Type badge + org name (always updates with lang)
                  Positioned(
                    left: 20, right: 20, bottom: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if ((g['org_type'] ?? '').toString().isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withOpacity(0.3)),
                            ),
                            child: Text(
                              g['org_type'].toString(),
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.4),
                            ),
                          ),
                        Text(
                          displayName,           // ← JP name when lang == 'ja'
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.5,
                            height: 1.15,
                            shadows: [Shadow(color: Colors.black38, blurRadius: 10, offset: Offset(0, 2))],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Body ─────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),

                    // Description — JP when lang == 'ja'
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        description,
                        style: const TextStyle(fontSize: 15, color: Colors.black87, height: 1.6),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Info Grid (2 × 2) ─────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          Row(children: [
                            Expanded(child: _buildInfoItem(Icons.location_on, locationLabel)),
                            const SizedBox(width: 16),
                            Expanded(child: _buildInfoItem(Icons.people, ageLabel)),
                          ]),
                          const SizedBox(height: 16),
                          Row(children: [
                            Expanded(child: _buildInfoItem(Icons.calendar_month, scheduleLabel)),
                            const SizedBox(width: 16),
                            Expanded(child: _buildInfoItem(Icons.sports, skillLabel)),
                          ]),

                          // Website
                          if (websiteLabel.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            GestureDetector(
                              onTap: () => _launchUrl(website),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Icon(Icons.language_rounded, color: AppColors.primary, size: 22),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      websiteLabel,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w500,
                                        decoration: TextDecoration.underline,
                                        decorationColor: AppColors.primary.withOpacity(0.5),
                                        height: 1.4,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Icon(Icons.open_in_new_rounded, size: 14, color: AppColors.primary.withOpacity(0.6)),
                                ],
                              ),
                            ),
                          ],

                          // Prefecture / city / social — JP when lang == 'ja'
                          if (prefecture.isNotEmpty || city.isNotEmpty || social.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (prefecture.isNotEmpty || city.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 12),
                                      child: _buildInfoItem(
                                        Icons.map_outlined,
                                        [city, prefecture].where((s) => s.isNotEmpty).join(', '),
                                      ),
                                    ),
                                  if (social.isNotEmpty)
                                    GestureDetector(
                                      onTap: () => _launchUrl(social),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          Icon(Icons.link_rounded, color: AppColors.primary, size: 22),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              social
                                                  .replaceFirst(RegExp(r'^https?://'), '')
                                                  .replaceFirst(RegExp(r'/$'), ''),
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: AppColors.primary,
                                                fontWeight: FontWeight.w500,
                                                decoration: TextDecoration.underline,
                                                decorationColor: AppColors.primary.withOpacity(0.5),
                                                height: 1.4,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Icon(Icons.open_in_new_rounded, size: 14, color: AppColors.primary.withOpacity(0.6)),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // ── Join & Interested Buttons ─────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          Row(children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _isJoined == true
                                    ? null
                                    : () async {
                                  await JoinGroupModal.show(context, widget.group);
                                  _checkJoinStatus();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isJoined == true
                                      ? Colors.grey.shade300
                                      : AppColors.primary,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                                child: Text(
                                  _isJoined == true
                                      ? _t('Joined ✓', '参加済み ✓')
                                      : _t('Join', '参加'),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: _isJoined == true ? Colors.grey.shade600 : Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => MarkInterestedModal.show(context, widget.group),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  side: const BorderSide(color: AppColors.primary, width: 2),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: Text(
                                  _t('Interested', '興味あり'),
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary),
                                ),
                              ),
                            ),
                          ]),

                          if (_isJoined == true) ...[
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(children: [
                                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                                const SizedBox(width: 10),
                                Text(
                                  _t('You have already joined this group', 'このグループにはすでに参加しています'),
                                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                                ),
                              ]),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // ── Upcoming Events ───────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _t('Upcoming Events', '今後のイベント'),
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _t('View all', 'すべて見る'),
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),
                    _buildUpcomingEventsList(),
                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primary, size: 22),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.4)),
        ),
      ],
    );
  }

  Widget _buildUpcomingEventsList() {
    if (_orgId.isEmpty) return _buildEmptyEvents();
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('events')
          .where('event_org_id', isEqualTo: _orgId)
          .where('event_active', isEqualTo: true)
          .where('event_date', isGreaterThanOrEqualTo: Timestamp.fromDate(today))
          .orderBy('event_date')
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
              child: Center(
                child: Text('Error loading events.\n${snapshot.error}',
                    style: const TextStyle(fontSize: 13, color: Colors.black54), textAlign: TextAlign.center),
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()));
        }
        final events = snapshot.data!.docs;
        if (events.isEmpty) return _buildEmptyEvents();
        return Column(
          children: events.take(3).map((doc) => _buildEventItem(doc.data() as Map<String, dynamic>)).toList(),
        );
      },
    );
  }

  Widget _buildEmptyEvents() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
        child: Center(
          child: Text(
            _t('No upcoming events yet', 'まだ予定されているイベントはありません'),
            style: const TextStyle(fontSize: 14, color: Colors.black54),
          ),
        ),
      ),
    );
  }

  Widget _buildEventItem(Map<String, dynamic> event) {
    final Timestamp? dateTs = event['event_date'] ?? event['event_start_date'];
    final Timestamp? timeTs = event['event_start_time'] ?? event['event_date'];
    if (dateTs == null) return const SizedBox.shrink();
    final date       = dateTs.toDate();
    final time       = timeTs?.toDate() ?? date;
    final eventLocId = (event['event_loc_id'] ?? '').toString();

    final eventWithGroup = {
      ...event,
      'group_id':    widget.group['_doc_id'] ?? widget.group['org_id'] ?? widget.group['group_id'] ?? '',
      'group_image': widget.group['group_image'] ?? widget.group['org_image'] ?? '',
      'group_name':  widget.group['group_name'] ?? widget.group['org_name'] ?? '',
    };

    // Event title — use JP field if available and lang == 'ja'
    final eventTitle = _lang == 'ja'
        ? ((event['event_title_jp'] ?? event['event_name_jp'] ?? event['event_title'] ?? event['event_name'] ?? _t('Untitled Event', '無題のイベント')).toString())
        : ((event['event_title'] ?? event['event_name'] ?? 'Untitled Event').toString());

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20).copyWith(bottom: 12),
      child: GestureDetector(
        onTap: () => MarkInterestedModal.show(context, eventWithGroup),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 14, offset: const Offset(0, 4))],
          ),
          child: Row(
            children: [
              // Date badge
              Container(
                width: 62,
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Text(
                      DateFormatter.month(date.month).substring(0, 3).toUpperCase(),
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 2),
                    Text('${date.day}',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.primary, height: 1.1)),
                    const SizedBox(height: 2),
                    Text('${date.year}',
                        style: const TextStyle(fontSize: 10, color: Colors.black38, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              // Event details
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        eventTitle,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1A1D23)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 5),
                      Row(children: [
                        const Icon(Icons.access_time_rounded, size: 12, color: Colors.black38),
                        const SizedBox(width: 4),
                        Text('${time.hour}:${time.minute.toString().padLeft(2, '0')}',
                            style: const TextStyle(fontSize: 12, color: Colors.black45)),
                        const SizedBox(width: 10),
                        const Icon(Icons.location_on_rounded, size: 12, color: Colors.black38),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Consumer(
                            builder: (context, ref, _) {
                              final loc = ref.watch(locationResolverProvider(eventLocId));
                              return loc.when(
                                data:    (l) => Text(l, style: const TextStyle(fontSize: 12, color: Colors.black45), maxLines: 1, overflow: TextOverflow.ellipsis),
                                loading: () => const Text('...', style: TextStyle(fontSize: 12)),
                                error:   (_, __) => const Text('Unknown', style: TextStyle(fontSize: 12)),
                              );
                            },
                          ),
                        ),
                      ]),
                    ],
                  ),
                ),
              ),
              // Arrow
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(9)),
                  child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Extension helper ──────────────────────────────────────────────────────────
extension _Let<T> on T {
  R let<R>(R Function(T) block) => block(this);
}

// ── Lang pill widget ──────────────────────────────────────────────────────────
class _LangPill extends StatelessWidget {
  final String lang;
  final ValueChanged<String> onChanged;
  const _LangPill({required this.lang, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.28),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _pill('EN', lang == 'en'),
        _pill('JP', lang == 'ja'),
      ]),
    );
  }

  Widget _pill(String label, bool selected) {
    return GestureDetector(
      onTap: () => onChanged(label == 'EN' ? 'en' : 'ja'),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? Colors.white.withOpacity(0.25) : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : Colors.white.withOpacity(0.55),
          ),
        ),
      ),
    );
  }
}

// ── Glass back/share button ───────────────────────────────────────────────────
class _GlassButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _GlassButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.28),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
      ),
      child: Icon(icon, color: Colors.white, size: 18),
    ),
  );
}